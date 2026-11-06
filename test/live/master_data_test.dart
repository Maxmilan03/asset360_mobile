import 'package:asset360_mobile/core/scanning/scan_service.dart';
import 'package:asset360_mobile/data/api/api_client.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/master_data/master_data_repository.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/models/asset_registration.dart';
import 'package:dio/dio.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_asset_backend.dart';

/// Master Data Management (port 5500): contract-shaped parsing, the repository's status filter and
/// offline cache, and location scans resolved through the Master Data tree.
void main() {
  group('parsing (contract-shaped JSON)', () {
    test('categories: name = categoryName, parent reference, inactive dropped', () {
      final l = mdParseList(mdCategories, MdCategory.fromJson);
      expect(l.map((c) => c.name), ['Machinery & Equipment', 'HVAC', 'Diesel Sets']);
      expect(l.first.id, 'md-cat-1');
      expect(l.first.code, 'MCH');
      expect(l.first.isTopLevel, isTrue);
      final child = l.last;
      expect(child.isTopLevel, isFalse);
      expect(child.parentCategory?.id, 'md-cat-1');
      expect(child.parentCategory?.name, 'Machinery & Equipment');
    });

    test('sub categories: subCategoryId / subCategoryName / categoryId and the free-text assetType', () {
      final l = mdParseList(mdSubCategories, MdSubCategory.fromJson);
      expect(
        [for (final s in l) (s.id, s.name, s.categoryId, s.assetType)],
        [('md-sub-1', 'Power Generation', 'md-cat-1', null), ('md-sub-2', 'Pumping', 'md-cat-1', 'Pump')],
      );
    });

    test('asset types: assetTypeName and the category reference; models link type + manufacturer', () {
      final types = mdParseList(mdAssetTypes, MdAssetType.fromJson);
      expect(types.first.name, 'Generator');
      expect(types.first.category?.id, 'md-cat-1');
      expect(types.first.defaultLifetime, 10);
      final model = mdParseList(mdAssetModels, MdAssetModel.fromJson).single;
      expect(
        [model.name, model.code, model.manufacturer?.name, model.assetType?.id],
        ['C500 D5', 'C500', 'Cummins', 'md-type-1'],
      );
    });

    test('simple lists: employees (record id vs employee number), conditions (default flag), uoms', () {
      final e = mdParseList(mdEmployees, MdEmployee.fromJson).single;
      expect(e.id, '6650a1b2c3d4e5f600000e01');
      expect(e.employeeCode, 'EMP-0042');
      expect(e.name, 'Sara Ali');
      expect(e.department?.name, 'Facilities Management');
      expect(e.phone, '+971500000001');
      final conditions = mdParseList(mdConditions, MdCondition.fromJson);
      expect(conditions.where((c) => c.isDefault).single.name, 'Good');
      expect(conditions.first.healthScore, 95);
      expect(mdParseList(mdUoms, MdUom.fromJson).map((u) => (u.name, u.symbol)), [('Each', 'ea'), ('Set', 'set')]);
    });

    test('null-safe: wrong types and missing fields never throw; empty and nameless rows are skipped', () {
      final l = mdParseList([
        {'id': 7, 'departmentName': null},
        {'id': 'd1', 'departmentName': 'Ops', 'businessUnit': 'not a map', 'status': null},
        'garbage',
        {'id': 'd2', 'departmentName': 'Old', 'status': 'inactive'},
      ], MdDepartment.fromJson);
      expect(l.map((d) => d.name), ['Ops']);
      expect(l.single.businessUnit, isNull);
      expect(mdParseList({'unexpected': true}, MdDepartment.fromJson), isEmpty);
      expect(mdParseList(null, MdDepartment.fromJson), isEmpty);
    });

    test('location tree: levels by depth, lookups by id and code, path written as ids + names', () {
      final index = MdLocationIndex(MdLocationNode.parseTree(mdLocationTree));
      expect(index.length, 7);
      final room = index.byCode('r101')!; // codes match case-insensitively
      final path = index.pathTo(room);
      expect(path.level, MdLocationLevel.room);
      expect(path.label, 'UAE > Main Site > Block A > Ground > Zone 1 > Room 101');
      expect(path.at(MdLocationLevel.floor)?.name, 'Ground');
      expect(index.childrenOf(index.byId('loc-ba')).map((n) => n.name), ['Ground', 'First']);

      // Picking a level clears the levels below.
      final building = path.pick(MdLocationLevel.building, index.byId('loc-ba'));
      expect(building.label, 'UAE > Main Site > Block A');

      final l = AssetLocation(zoneName: 'old zone', roomName: 'old room');
      path.writeTo(l);
      expect(l.toJson(), {
        'projectId': null,
        'countryId': 'loc-ae',
        'countryName': 'UAE',
        'siteId': 'loc-ms',
        'siteName': 'Main Site',
        'buildingId': 'loc-ba',
        'buildingName': 'Block A',
        'floorId': 'loc-gf',
        'floorName': 'Ground',
        'zoneId': 'loc-z1',
        'zoneName': 'Zone 1',
        'roomId': 'loc-r101',
        'roomName': 'Room 101',
        'locationPath': 'UAE > Main Site > Block A > Ground > Zone 1 > Room 101',
        'latitude': null,
        'longitude': null,
      });
      building.writeTo(l);
      expect([l.floorId, l.zoneName, l.roomName], [null, null, null]);

      // A saved registration is found again by its ids, or by its names under the parents.
      expect(
        index.pathOf(AssetLocation(countryId: 'loc-ae', siteId: 'loc-ms', floorId: 'loc-f1')).label,
        'UAE > Main Site > Block A > First',
      );
      expect(
        index.pathOf(AssetLocation(countryName: 'UAE', siteName: 'Main Site', buildingName: 'Block A')).deepest?.id,
        'loc-ba',
      );
      expect(index.pathOf(AssetLocation(siteId: 'local-code')).isEmpty, isTrue);
    });
  });

  group('repository', () {
    late FakeAssetBackend backend;
    late AppDatabase db;
    late MasterDataRepository repo;

    setUp(() {
      backend = FakeAssetBackend();
      db = AppDatabase(NativeDatabase.memory());
      repo = MasterDataRepository(
        MasterDataApi(
          ApiClient(
            Dio(BaseOptions(baseUrl: 'http://md.test:5500'))..httpClientAdapter = backend,
            checkConfig: false,
            service: BackendService.masterData,
          ),
        ),
        db,
      );
    });
    tearDown(() => db.close());

    test('asks for status=Active and the link filter; inactive rows never reach the app', () async {
      final types = await repo.list(
        MasterDataApi.assetTypes,
        MdAssetType.fromJson,
        query: {...MasterDataApi.active, 'categoryId': 'md-cat-2'},
      );
      expect(types.map((t) => t.name), ['Chiller']);
      expect(backend.calls('GET', MasterDataApi.assetTypes).single.uri.queryParameters, {
        'status': 'Active',
        'categoryId': 'md-cat-2',
      });
      final cats = await repo.list(MasterDataApi.categories, MdCategory.fromJson);
      expect(cats.map((c) => c.name), isNot(contains('Retired Category')));
    });

    test('offline: the last good reply comes from CachedResponses; other errors are passed on', () async {
      expect((await repo.list(MasterDataApi.departments, MdDepartment.fromJson)).length, 2);
      final saved = await db.cachedResponse('${MasterDataApi.departments}?status=Active');
      expect(saved, isNotNull);

      // No network → the saved copy.
      backend.on(
        'GET',
        MasterDataApi.departments,
        (_) => throw DioException.connectionError(
          requestOptions: RequestOptions(path: MasterDataApi.departments),
          reason: 'offline',
        ),
      );
      final offline = await repo.list(MasterDataApi.departments, MdDepartment.fromJson);
      expect(offline.map((d) => d.name), ['Facilities Management', 'Production']);

      // No network and nothing saved → the error.
      backend.on(
        'GET',
        MasterDataApi.teams,
        (_) => throw DioException.connectionError(
          requestOptions: RequestOptions(path: MasterDataApi.teams),
          reason: 'offline',
        ),
      );
      await expectLater(
        repo.list(MasterDataApi.teams, MdTeam.fromJson),
        throwsA(isA<ApiException>().having((e) => e.kind, 'kind', ApiErrorKind.noNetwork)),
      );

      // A server error is shown, not hidden behind the cache.
      backend.on('GET', MasterDataApi.departments, (_) => const FakeReply(500, {'message': 'boom'}));
      await expectLater(repo.list(MasterDataApi.departments, MdDepartment.fromJson), throwsA(isA<ApiException>()));
    });

    test('an empty server list is an empty list (the screens say "No … on the server yet")', () async {
      backend.on('GET', MasterDataApi.shifts, (_) => const FakeReply(200, []));
      expect(await repo.list(MasterDataApi.shifts, MdShift.fromJson), isEmpty);
    });
  });

  group('location scans (API mode)', () {
    late FakeAssetBackend backend;
    late ProviderContainer c;

    setUp(() {
      debugApiMode = true;
      backend = FakeAssetBackend();
      c = ProviderContainer(retry: (_, _) => null, overrides: backend.overrides);
    });
    tearDown(() {
      c.dispose();
      debugApiMode = null;
    });

    ScanEvent qr(String v) => ScanEvent(value: v, format: 'qr', source: ScanSource.camera);

    test('"LOC:<code>" resolves through the Master Data location code', () async {
      final r = (await c.read(scanServiceProvider).submit(qr('LOC:BLD-A-GF')))!;
      expect(r.matchType, MatchType.location);
      expect(r.matchId, 'loc-gf');
      expect(r.masterLocation?.label, 'UAE > Main Site > Block A > Ground');
      expect(r.location, isNull, reason: 'no local Locations row in API mode');
      expect(backend.calls('GET', MasterDataApi.locationTree).single.uri.queryParameters, {'status': 'Active'});
    });

    test('an unknown code is not a location; a tag linked to a location stores and resolves its real id', () async {
      final service = c.read(scanServiceProvider);
      final r = await service.resolve(qr('LOC:NOPE'));
      expect(r.matchType, isNot(MatchType.location));

      final unknown = (await service.submit(qr('STICKER-77')))!;
      final tree = await c.read(mdLocationTreeProvider.future);
      final linked = await service.linkToMasterLocation(unknown, tree.pathTo(tree.byId('loc-z1')));
      expect(linked.matchId, 'loc-z1');
      final link = await c.read(appDatabaseProvider).linkByKey('STICKER-77');
      expect([link?.targetType, link?.targetId], [LinkTarget.location, 'loc-z1']);

      final again = await service.resolve(qr('STICKER-77'));
      expect(again.viaLink, isTrue);
      expect(again.masterLocation?.label, 'UAE > Main Site > Block A > Ground > Zone 1');
    });

    test('Master Data unreachable: the scan reports the problem instead of a wrong match', () async {
      backend.on('GET', MasterDataApi.locationTree, (_) => const FakeReply(503, {'message': 'down'}));
      final r = await c.read(scanServiceProvider).resolve(qr('LOC:BLD-A-GF'));
      expect(r.matchType, MatchType.none);
      expect(r.problem, startsWith('Could not load the locations'));
    });
  });
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/assets_mock.dart';
import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/common.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/data/models/sync_item.dart';

class AssetsNotifier extends Notifier<List<Asset>> {
  @override
  List<Asset> build() => seedAssets();

  String get _me => ref.read(currentUserProvider).name;

  Asset? byId(String id) => state.firstWhereOrNull((a) => a.id == id);

  void _update(String id, Asset Function(Asset) f) => state = replaceWhere(state, id, (a) => a.id, f);

  /// Offline: the change also goes into the sync queue ("Asset Updates").
  void _q(String id, String change) => ref.queueOffline(SyncKind.asset, id, change, refId: id);

  LogEntry _event(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  /// Adds a registered asset (also counted in the org summary and in this session's registrations).
  void add(Asset asset) {
    state = [
      asset.copyWith(events: [_event('Asset registered', asset.location), ...asset.events]),
      ...state,
    ];
    ref.read(orgSummaryProvider.notifier).addAsset(asset.status);
    ref.read(assetBreakdownProvider.notifier).addAsset(asset);
    ref.read(sessionRegistrationsProvider.notifier).record(asset.id);
    _q(asset.id, 'Asset Registered');
  }

  /// The asset that already uses [value] as its ID, tag or barcode (case-insensitive), if any.
  Asset? ownerOf(String value) {
    final v = value.trim().toUpperCase();
    if (v.isEmpty) return null;
    return state.firstWhereOrNull(
      (a) => a.id.toUpperCase() == v || a.tagId?.toUpperCase() == v || a.barcode?.toUpperCase() == v,
    );
  }

  /// ID prefix for an asset type: from the register ("Electric Motor" → MTR), else [extraAssetTypes].
  String prefixFor(String type) =>
      state.firstWhereOrNull((a) => a.type == type)?.id.split('-').first ?? extraAssetTypes[type]?.$1 ?? 'AST';

  String nextAssetId(String prefix) => nextId('$prefix-', state.map((a) => a.id), width: 5);

  void update(Asset updated) {
    _update(updated.id, (_) => updated);
    _q(updated.id, 'Asset Update');
  }

  void setStatus(String id, String status, {String? note}) {
    final old = byId(id);
    if (old == null || old.status == status) return;
    _update(id, (a) => a.copyWith(status: status, events: [_event('Status changed to $status', note), ...a.events]));
    ref.read(orgSummaryProvider.notifier).move(old.status, status);
    _q(id, 'Status Update');
  }

  /// Criticality picked directly or from the Assess sheet ([note] = e.g. "Assessed: score 3.4 / 5").
  void setCriticality(String id, String level, {String? note}) {
    final old = byId(id);
    if (old == null || (old.criticality == level && note == null)) return;
    _update(id, (a) => a.copyWith(criticality: level, events: [_event('Criticality set to $level', note), ...a.events]));
    _q(id, 'Criticality Update');
  }

  /// Key Information "Edit → Save". Status and location go through [setStatus] / [setLocation]
  /// so the org summary and location history stay in step.
  void editKeyInfo(
    String id, {
    required String status,
    required String condition,
    String? criticality,
    required String operationalStatus,
    required String location,
    required String custodian,
    required DateTime purchaseDate,
    DateTime? commissionedDate,
    required DateTime warrantyExpiry,
    String? amc,
  }) {
    final old = byId(id);
    if (old == null) return;
    setStatus(id, status);
    if (location != old.location) setLocation(id, location);
    if (custodian != old.custodian) setCustodian(id, custodian);
    _update(
      id,
      (a) => a.copyWith(
        condition: condition,
        criticality: criticality,
        operationalStatus: operationalStatus,
        purchaseDate: purchaseDate,
        commissionedDate: commissionedDate,
        warrantyExpiry: warrantyExpiry,
        amc: amc,
        clearAmc: amc == null,
        events: [_event('Key information updated'), ...a.events],
      ),
    );
    _q(id, 'Asset Details Update');
  }

  /// Copies the asset under the next free ID of its prefix (e.g. CNC-00124). Returns the new ID.
  String duplicate(String id) {
    final src = byId(id)!;
    final prefix = src.id.split('-').first;
    final newId = nextAssetId(prefix);
    add(
      src.copyWith(
        id: newId,
        serialNo: '${src.serialNo ?? newId}-COPY',
        tagId: 'RFID-$newId',
        barcode: newId,
        favorite: false,
        photos: const [],
        videos: const [],
        conditionHistory: const [],
        events: const [],
        locationHistory: [LocationRecord(at: DemoClock.now, location: src.location, by: _me)],
      ),
    );
    addEvent(id, 'Duplicated as $newId');
    return newId;
  }

  void linkIot(String id, IotDevice device) {
    _update(
      id,
      (a) => a.copyWith(
        iot: device,
        events: [_event('IoT device linked', '${device.model} · IMEI ${device.imei}'), ...a.events],
      ),
    );
    _q(id, 'IoT Device Linked');
  }

  /// Contracts & Warranty → Renew (warranty).
  void renewWarranty(String id, {required DateTime until, required double cost, required String vendor}) {
    _update(
      id,
      (a) => a.copyWith(
        warrantyExpiry: until,
        events: [
          _event('Warranty renewed until ${DemoClock.formatDate(until)}', '$vendor · AED ${cost.toStringAsFixed(0)}'),
          ...a.events,
        ],
      ),
    );
    _q(id, 'Warranty Renewed');
  }

  /// Contracts & Warranty → Renew (AMC): new end date, yearly cost and vendor.
  void renewAmc(String id, {required DateTime until, required double cost, required String vendor}) {
    _update(
      id,
      (a) => a.copyWith(
        amc: vendor,
        amcCost: cost,
        amcExpiry: until,
        events: [
          _event('AMC renewed until ${DemoClock.formatDate(until)}', '$vendor · AED ${cost.toStringAsFixed(0)}/yr'),
          ...a.events,
        ],
      ),
    );
    _q(id, 'AMC Renewed');
  }

  /// ☆ on the list / detail. A new favorite goes into the first group ("My Assets").
  void toggleFavorite(String id) => _update(
    id,
    (a) => a.copyWith(favorite: !a.favorite, favoriteGroup: a.favoriteGroup ?? defaultFavoriteGroups.first),
  );

  /// More Actions → Add to Favorites → Save.
  void setFavorite(String id, {required bool favorite, required String group, String? note}) {
    _update(
      id,
      (a) => a.copyWith(
        favorite: favorite,
        favoriteGroup: group,
        favoriteNote: note ?? '',
        events: [_event(favorite ? 'Added to Favorites ($group)' : 'Removed from Favorites', note), ...a.events],
      ),
    );
    _q(id, 'Favorites Update');
  }

  /// More Actions → Update Condition: sets the condition and adds a [ConditionRecord].
  void updateCondition(
    String id, {
    required String condition,
    required DateTime date,
    String? comments,
    List<String> photos = const [],
  }) {
    _update(
      id,
      (a) => a.copyWith(
        condition: condition,
        photos: [...a.photos, ...photos],
        conditionHistory: [
          ConditionRecord(
            at: date,
            condition: condition,
            previous: a.condition,
            by: _me,
            comments: comments,
            photos: photos,
          ),
          ...a.conditionHistory,
        ],
        events: [_event('Condition changed from ${a.condition} to $condition', comments), ...a.events],
      ),
    );
    _q(id, 'Condition Update');
    for (final p in photos) {
      ref.queueOffline(SyncKind.photo, syncFileName(p), 'Condition Photo', refId: id);
    }
  }

  /// More Actions → Add Photo / Video → Save Video.
  void addVideo(String id, String path, {String? caption}) {
    _update(
      id,
      (a) => a.copyWith(
        videos: [
          ...a.videos,
          AssetVideo(path: path, at: DemoClock.now, by: _me, caption: caption),
        ],
        events: [_event('Video added', caption), ...a.events],
      ),
    );
    ref.queueOffline(SyncKind.photo, syncFileName(path), 'Asset Video', refId: id);
  }

  void setCustodian(String id, String custodian) {
    _update(
      id,
      (a) => a.copyWith(custodian: custodian, events: [_event('Custodian changed to $custodian'), ...a.events]),
    );
    _q(id, 'Custodian Update');
  }

  void setLocation(String id, String location) {
    final from = byId(id)?.location;
    _update(
      id,
      (a) => a.copyWith(
        location: location,
        locationHistory: [
          LocationRecord(at: DemoClock.now, location: location, by: _me),
          ...a.locationHistory,
        ],
        events: [_event('Moved to $location'), ...a.events],
      ),
    );
    _q(id, 'Asset Location Update');
    if (from != null && from != location) {
      ref.read(issuesProvider.notifier).followAsset(id, from, location);
      ref.read(alertsProvider.notifier).followAsset(id, from, location);
    }
  }

  void addPhoto(String id, String path, {String? caption}) {
    _update(id, (a) => a.copyWith(photos: [...a.photos, path], events: [_event('Photo added', caption), ...a.events]));
    ref.queueOffline(SyncKind.photo, syncFileName(path), 'Asset Photo', refId: id);
  }

  void addEvent(String id, String title, {String? note}) =>
      _update(id, (a) => a.copyWith(events: [_event(title, note), ...a.events]));

  /// Small random walk of telemetry values (IoT tab "live" feel); the device's Last Seen moves to now.
  void setTelemetry(String id, List<TelemetryReading> readings) => _update(
    id,
    (a) => a.copyWith(
      telemetry: readings,
      iot: a.iot?.copyWith(lastSeen: DemoClock.now),
    ),
  );

  void delete(String id) {
    final old = byId(id);
    if (old == null) return;
    state = state.where((a) => a.id != id).toList();
    ref.read(orgSummaryProvider.notifier).removeAsset(old.status);
    ref.read(assetBreakdownProvider.notifier).removeAsset(old);
    _q(id, 'Asset Deleted');
  }
}

final assetsProvider = NotifierProvider<AssetsNotifier, List<Asset>>(AssetsNotifier.new);

/// Assets registered since the app started (Registration "Recent Scans" → "New").
class SessionRegistrationsNotifier extends Notifier<List<LogEntry>> {
  @override
  List<LogEntry> build() => const [];

  void record(String assetId) => state = [LogEntry(at: DemoClock.now, title: assetId), ...state];
}

final sessionRegistrationsProvider = NotifierProvider<SessionRegistrationsNotifier, List<LogEntry>>(
  SessionRegistrationsNotifier.new,
);

/// Favorite groups (More Actions → Add to Favorites; "New group…" adds one in memory).
class FavoriteGroupsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => defaultFavoriteGroups;

  /// Returns false when the name is empty or already exists (case-insensitive).
  bool add(String name) {
    final n = name.trim();
    if (n.isEmpty || state.any((g) => g.toLowerCase() == n.toLowerCase())) return false;
    state = [...state, n];
    return true;
  }
}

final favoriteGroupsProvider = NotifierProvider<FavoriteGroupsNotifier, List<String>>(FavoriteGroupsNotifier.new);

/// Store devices not yet paired with any asset.
final unlinkedIotDevicesProvider = Provider<List<IotDevice>>((ref) {
  final linked = ref.watch(assetsProvider).map((a) => a.iot?.imei).whereType<String>().toSet();
  return seedSpareIotDevices().where((d) => !linked.contains(d.imei)).toList();
});

/// Administration → Master Data: categories, asset types (→ category) and manufacturers.
/// Seeded from the register and [extraAssetTypes]; "+ Add" extends it in memory.
class MasterData {
  const MasterData({required this.categories, required this.types, required this.manufacturers});

  final List<String> categories;
  final Map<String, String> types;
  final List<String> manufacturers;

  MasterData copyWith({List<String>? categories, Map<String, String>? types, List<String>? manufacturers}) =>
      MasterData(
        categories: categories ?? this.categories,
        types: types ?? this.types,
        manufacturers: manufacturers ?? this.manufacturers,
      );
}

class MasterDataNotifier extends Notifier<MasterData> {
  @override
  MasterData build() {
    final assets = seedAssets();
    final types = <String, String>{for (final a in assets) a.type: a.category};
    for (final e in extraAssetTypes.entries) {
      types.putIfAbsent(e.key, () => e.value.$2);
    }
    return MasterData(
      categories: _sorted(types.values),
      types: types,
      manufacturers: _sorted(assets.map((a) => a.manufacturer).where((m) => m != '—')),
    );
  }

  static List<String> _sorted(Iterable<String> v) => {...v}.toList()..sort();

  /// Returns false when the name already exists.
  bool addCategory(String name) {
    if (state.categories.contains(name)) return false;
    state = state.copyWith(categories: _sorted([...state.categories, name]));
    return true;
  }

  bool addType(String name, String category) {
    if (state.types.containsKey(name)) return false;
    state = state.copyWith(types: {...state.types, name: category});
    return true;
  }

  bool addManufacturer(String name) {
    if (state.manufacturers.contains(name)) return false;
    state = state.copyWith(manufacturers: _sorted([...state.manufacturers, name]));
    return true;
  }
}

final masterDataProvider = NotifierProvider<MasterDataNotifier, MasterData>(MasterDataNotifier.new);

/// Asset types → category (master data plus any type registered since), sorted by type.
final assetTypesProvider = Provider<Map<String, String>>((ref) {
  final m = {...ref.watch(masterDataProvider).types};
  for (final a in ref.watch(assetsProvider)) {
    m.putIfAbsent(a.type, () => a.category);
  }
  return Map.fromEntries(m.entries.toList()..sort((a, b) => a.key.compareTo(b.key)));
});

final assetByIdProvider = Provider.family<Asset?, String>(
  (ref, id) => ref.watch(assetsProvider).firstWhereOrNull((a) => a.id == id),
);

/// Org-wide summary figures; kept in step when detailed assets change status.
class OrgSummaryNotifier extends Notifier<OrgSummary> {
  @override
  OrgSummary build() => seedOrgSummary();

  void _bump(String status, int by) {
    if (!state.statusCounts.containsKey(status)) return;
    state = state.copyWith(statusCounts: {...state.statusCounts, status: state.statusCounts[status]! + by});
  }

  void addAsset(String status) => _bump(status, 1);
  void removeAsset(String status) => _bump(status, -1);

  void move(String from, String to) {
    _bump(from, -1);
    _bump(to, 1);
  }
}

final orgSummaryProvider = NotifierProvider<OrgSummaryNotifier, OrgSummary>(OrgSummaryNotifier.new);

/// "My Assets": the user is the custodian, or has an active work order on the asset.
final myAssetsProvider = Provider<List<Asset>>((ref) {
  final me = ref.watch(currentUserProvider);
  final woAssets = ref.watch(workOrdersProvider).mine(me.id).map((w) => w.assetId).toSet();
  return ref.watch(assetsProvider).where((a) => a.custodian.startsWith(me.name) || woAssets.contains(a.id)).toList();
});

extension AssetQueries on List<Asset> {
  List<Asset> withStatus(String s) => where((a) => a.status == s).toList();
  List<Asset> get favorites => where((a) => a.favorite).toList();

  /// Favorites in [group] (null = every group).
  List<Asset> favoritesIn(String? group) =>
      where((a) => a.favorite && (group == null || (a.favoriteGroup ?? defaultFavoriteGroups.first) == group)).toList();
  List<Asset> atSite(String site) => site == 'All Sites' ? this : where((a) => a.site == site).toList();

  /// "Nearby" = in the Main Plant (the demo user is on the factory floor).
  List<Asset> get nearby => where((a) => a.location.startsWith('Main Plant')).toList();

  List<Asset> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return this;
    return where(
      (a) =>
          a.id.toLowerCase().contains(s) ||
          a.name.toLowerCase().contains(s) ||
          (a.serialNo?.toLowerCase().contains(s) ?? false) ||
          a.location.toLowerCase().contains(s),
    ).toList();
  }

  /// Match a scanned code: asset ID, barcode, serial or tag.
  Asset? byCode(String code) {
    final c = code.trim().toUpperCase();
    return firstWhereOrNull(
      (a) =>
          a.id.toUpperCase() == c ||
          a.barcode?.toUpperCase() == c ||
          a.serialNo?.toUpperCase() == c ||
          a.tagId?.toUpperCase() == c,
    );
  }
}

/// Age, depreciation and total cost of ownership (straight-line, from [DemoClock]).
extension AssetFinance on Asset {
  double get ageYears => DemoClock.yearsSince(purchaseDate);

  /// "3.7 Years".
  String get ageLabel => '${ageYears.toStringAsFixed(1)} ${ageYears >= 1 && ageYears < 1.05 ? 'Year' : 'Years'}';

  double get depreciationPerYear => (purchaseCost - salvageValue) / usefulLifeYears;
  double get accumulatedDepreciation => (depreciationPerYear * ageYears).clamp(0, purchaseCost - salvageValue);
  double get bookValue => purchaseCost - accumulatedDepreciation;

  /// Whole years of AMC paid so far (from commissioning).
  double get amcCostToDate {
    if (amc == null || amcCost == null) return 0;
    final years = DemoClock.yearsSince(commissionedDate ?? purchaseDate).ceil();
    return amcCost! * years;
  }

  /// Resale at end of life = salvage value (expected resale).
  double get resaleValue => salvageValue;

  /// TCO = acquisition + maintenance + spares + labour + energy − resale.
  double get tco => purchaseCost + costs.total - resaleValue;

  int get warrantyDaysLeft => DemoClock.daysUntil(warrantyExpiry);
  bool get warrantyExpired => warrantyDaysLeft < 0;

  /// Red when under 180 days (or expired).
  bool get warrantyWarning => warrantyDaysLeft < 180;
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/assets_mock.dart';
import '../mock/registration_mock.dart';
import '../models/asset.dart';
import '../models/common.dart';
import 'maintenance_repository.dart';
import 'repo_utils.dart';
import 'session_repository.dart';

class AssetsNotifier extends Notifier<List<Asset>> {
  @override
  List<Asset> build() => seedAssets();

  String get _me => ref.read(currentUserProvider).name;

  Asset? byId(String id) => state.firstWhereOrNull((a) => a.id == id);

  void _update(String id, Asset Function(Asset) f) => state = replaceWhere(state, id, (a) => a.id, f);

  LogEntry _event(String title, [String? note]) => LogEntry(at: DemoClock.now, title: title, by: _me, note: note);

  /// Adds a registered asset (also counted in the org summary and in this session's registrations).
  void add(Asset asset) {
    state = [
      asset.copyWith(events: [_event('Asset registered', asset.location), ...asset.events]),
      ...state,
    ];
    ref.read(orgSummaryProvider.notifier).addAsset(asset.status);
    ref.read(sessionRegistrationsProvider.notifier).record(asset.id);
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

  void update(Asset updated) => _update(updated.id, (_) => updated);

  void setStatus(String id, String status, {String? note}) {
    final old = byId(id);
    if (old == null || old.status == status) return;
    _update(id, (a) => a.copyWith(status: status, events: [_event('Status changed to $status', note), ...a.events]));
    ref.read(orgSummaryProvider.notifier).move(old.status, status);
  }

  /// Key Information "Edit → Save". Status and location go through [setStatus] / [setLocation]
  /// so the org summary and location history stay in step.
  void editKeyInfo(
    String id, {
    required String status,
    required String condition,
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
        operationalStatus: operationalStatus,
        purchaseDate: purchaseDate,
        commissionedDate: commissionedDate,
        warrantyExpiry: warrantyExpiry,
        amc: amc,
        clearAmc: amc == null,
        events: [_event('Key information updated'), ...a.events],
      ),
    );
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
        events: const [],
        locationHistory: [LocationRecord(at: DemoClock.now, location: src.location, by: _me)],
      ),
    );
    addEvent(id, 'Duplicated as $newId');
    return newId;
  }

  void linkIot(String id, IotDevice device) => _update(
    id,
    (a) => a.copyWith(
      iot: device,
      events: [_event('IoT device linked', '${device.model} · IMEI ${device.imei}'), ...a.events],
    ),
  );

  void toggleFavorite(String id) => _update(id, (a) => a.copyWith(favorite: !a.favorite));

  void setCustodian(String id, String custodian) => _update(
    id,
    (a) => a.copyWith(custodian: custodian, events: [_event('Custodian changed to $custodian'), ...a.events]),
  );

  void setLocation(String id, String location) => _update(
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

  void addPhoto(String id, String path) =>
      _update(id, (a) => a.copyWith(photos: [...a.photos, path], events: [_event('Photo added'), ...a.events]));

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

/// Store devices not yet paired with any asset.
final unlinkedIotDevicesProvider = Provider<List<IotDevice>>((ref) {
  final linked = ref.watch(assetsProvider).map((a) => a.iot?.imei).whereType<String>().toSet();
  return seedSpareIotDevices().where((d) => !linked.contains(d.imei)).toList();
});

/// Asset types → category, from the register plus [extraAssetTypes].
final assetTypesProvider = Provider<Map<String, String>>((ref) {
  final m = <String, String>{for (final a in ref.watch(assetsProvider)) a.type: a.category};
  for (final e in extraAssetTypes.entries) {
    m.putIfAbsent(e.key, () => e.value.$2);
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

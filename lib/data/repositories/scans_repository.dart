import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/mock/scans_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/scan_record.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/inventory_repository.dart';
import 'package:asset360_mobile/data/repositories/repo_utils.dart';

/// What a scanned code points at: an asset ID, a part number or a location path.
typedef ScanTarget = ({ScanKind kind, String refId});

class ScanHistoryNotifier extends Notifier<List<ScanRecord>> {
  @override
  List<ScanRecord> build() => seedScans();

  /// Every scan in the app goes to the top of the history.
  void add(ScanKind kind, String refId, {String method = 'QR'}) => state = [
    ScanRecord(
      id: nextId('SCN-', state.map((s) => s.id), width: 3),
      kind: kind,
      refId: refId,
      at: DemoClock.now,
      method: method,
    ),
    ...state,
  ];

  void remove(String id) => state = state.where((s) => s.id != id).toList();
  void clear() => state = const [];

  /// Restores a removed row at its old position (SnackBar "Undo").
  void restore(ScanRecord record, int index) => state = [...state]..insert(index.clamp(0, state.length), record);

  /// Matches a scanned code against assets (ID, tag, barcode, serial), parts (part number)
  /// and locations ("LOC:Building / Floor – Zone" or the bare path). Null when unknown.
  ScanTarget? resolve(String code) {
    final c = code.trim();
    if (c.isEmpty) return null;
    final asset = ref.read(assetsProvider).byCode(c);
    if (asset != null) return (kind: ScanKind.asset, refId: asset.id);
    final part = ref.read(inventoryProvider).parts.firstWhereOrNull((p) => p.id.toUpperCase() == c.toUpperCase());
    if (part != null) return (kind: ScanKind.part, refId: part.id);
    final path = c.toUpperCase().startsWith(locationCodePrefix) ? c.substring(locationCodePrefix.length).trim() : c;
    final location = scanLocations.firstWhereOrNull((l) => l.toLowerCase() == path.toLowerCase());
    if (location != null) return (kind: ScanKind.location, refId: location);
    return null;
  }
}

final scanHistoryProvider = NotifierProvider<ScanHistoryNotifier, List<ScanRecord>>(ScanHistoryNotifier.new);

extension ScanQueries on List<ScanRecord> {
  List<ScanRecord> ofKind(ScanKind kind) => where((s) => s.kind == kind).toList();
  int count(ScanKind kind) => where((s) => s.kind == kind).length;
}

/// Every taggable location, "Building / Floor – Zone" (from the registration location tree).
final List<String> scanLocations = [
  for (final buildings in locationTree.values)
    for (final MapEntry(key: building, value: floors) in buildings.entries)
      for (final MapEntry(key: floor, value: zones) in floors.entries)
        for (final zone in zones) '$building / $floor – $zone',
];

/// Beacons the simulated BLE scan finds, with their assets (strongest signal first).
final nearbyBeaconsProvider = Provider<List<(Asset, BleBeacon)>>((ref) {
  final assets = ref.watch(assetsProvider);
  return [
    for (final b in seedBeacons)
      if (assets.firstWhereOrNull((a) => a.id == b.assetId) case final a?) (a, b),
  ];
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/mock/more_actions_mock.dart';
import 'package:asset360_mobile/data/mock/registration_mock.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

final _count = NumberFormat('#,###');
final _aed = NumberFormat('#,##0');

/// "12,458".
String formatCount(num n) => _count.format(n);

/// "AED 685,000".
String formatAed(num v) => 'AED ${_aed.format(v.round())}';

/// Icon for an asset's category / type (list tags, fallback thumbnails).
IconData assetIcon(Asset a) {
  final t = '${a.type} ${a.category}'.toLowerCase();
  if (t.contains('cnc') || t.contains('production')) return Icons.precision_manufacturing_outlined;
  if (t.contains('generator') || t.contains('power') || t.contains('electrical')) return Icons.bolt_rounded;
  if (t.contains('hvac') || t.contains('air') || t.contains('chiller')) return Icons.ac_unit_rounded;
  if (t.contains('forklift') || t.contains('material handling')) return Icons.forklift;
  if (t.contains('fire') || t.contains('safety')) return Icons.local_fire_department_outlined;
  if (t.contains('laptop') || t.contains('it equipment') || t.contains('projector') || t.contains('camera')) {
    return Icons.laptop_mac_rounded;
  }
  if (t.contains('pump')) return Icons.water_drop_outlined;
  if (t.contains('tool') || t.contains('drill')) return Icons.handyman_outlined;
  if (t.contains('lift')) return Icons.elevator_outlined;
  if (t.contains('storage') || t.contains('cold')) return Icons.kitchen_outlined;
  return Icons.inventory_2_outlined;
}

/// Short kind for list tags: the category when short ("HVAC", "IT Equipment"),
/// otherwise the last word of the type ("Machine", "Generator", "Forklift").
String shortAssetKind(Asset a) => a.category.length <= 12 ? a.category : a.type.split(' ').last;

/// First part of a location path: "Main Plant / Production Floor 1" → "Main Plant".
String locationArea(String location) => location.split(RegExp(r' / | – |, ')).first.trim();

/// Location path as breadcrumb parts: site first, then each level.
List<String> locationParts(Asset a) => [a.site, ...a.location.split(RegExp(r' / | – ')).map((s) => s.trim())];

const operationalStatuses = ['Running', 'Idle', 'Stopped', 'Under Repair', 'Not Starting'];

/// Everyone and every department that can hold an asset ("Ramesh Kumar (Production)", "Facilities" …).
List<String> custodianOptions(WidgetRef ref) {
  final people = ref.read(peopleProvider).map((p) => p.labelWithRole);
  final current = ref.read(assetsProvider).map((a) => a.custodian);
  return {...people, ...current, 'Unassigned'}.toList();
}

/// Every location already used by an asset.
List<String> locationOptions(WidgetRef ref) => {...ref.read(assetsProvider).map((a) => a.location)}.toList()..sort();

/// The asset's pin on a floor plan: its live tag when tracked, else a fixed spot derived
/// from the ID (so it stays put between visits).
TrackedEntity assetFloorPin(Asset asset, TrackedEntity? tracked) {
  if (tracked != null) return tracked;
  final h = asset.id.codeUnits.fold<int>(7, (s, c) => (s * 31 + c) % 997);
  return TrackedEntity(
    id: asset.id,
    label: asset.id,
    kind: TrackedKind.equipment,
    x: .40 + (h % 28) / 100,
    y: .32 + (h % 38) / 100,
    zone: locationArea(asset.location),
    assetId: asset.id,
  );
}

/// Building, floor and the building's floors for an asset, matched from the location tree
/// (the longest name found in the asset's location wins).
({String building, String floor, List<String> floors}) assetFloor(Asset a) {
  final site = locationTree[a.site] ?? const {};
  String? best(Iterable<String> names) {
    String? found;
    for (final n in names) {
      if (a.location.contains(n) && (found == null || n.length > found.length)) found = n;
    }
    return found;
  }

  final building = best(site.keys) ?? site.keys.firstOrNull ?? locationArea(a.location);
  final floors = site[building]?.keys.toList() ?? const ['Ground Floor'];
  return (building: building, floor: best(floors) ?? floors.first, floors: floors);
}

/// The asset's department: registered department, else the one in the custodian label
/// ("Ramesh Kumar (Production)" → Production).
String assetDepartment(Asset a) {
  if (a.department != null) return a.department!;
  final m = RegExp(r'\(([^)]+)\)$').firstMatch(a.custodian);
  return m?.group(1) ?? '—';
}

/// Postal address of the asset's site.
String siteAddress(Asset a) => siteAddresses[a.site] ?? a.site;

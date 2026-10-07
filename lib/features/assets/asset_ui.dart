import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/data/models/asset.dart';
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

const assetConditions = ['Excellent', 'Good', 'Fair', 'Poor'];
const operationalStatuses = ['Running', 'Idle', 'Stopped', 'Under Repair', 'Not Starting'];
const criticalities = ['Critical', 'High', 'Medium', 'Low'];

/// Everyone and every department that can hold an asset ("Ramesh Kumar (Production)", "Facilities" …).
List<String> custodianOptions(WidgetRef ref) {
  final people = ref.read(peopleProvider).map((p) => p.labelWithRole);
  final current = ref.read(assetsProvider).map((a) => a.custodian);
  return {...people, ...current, 'Unassigned'}.toList();
}

/// Every location already used by an asset.
List<String> locationOptions(WidgetRef ref) => {...ref.read(assetsProvider).map((a) => a.location)}.toList()..sort();

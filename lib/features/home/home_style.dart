import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/data/models/asset.dart';
import 'package:asset360_mobile/data/models/home_insights.dart';

/// Colours and formats shared by the Home cards and their drill-downs.

const healthColors = {
  'Condition': AppColors.green,
  'Utilization': Color(0xFF34C77B),
  'Maintenance': Color(0xFFF5B800),
  'Inspection': Color(0xFFC04BE8),
  'IoT Status': Color(0xFF2563EB),
};

String healthLabel(int pct) => pct >= 80 ? 'Good' : (pct >= 60 ? 'Fair' : 'Poor');

const costColors = [
  Color(0xFF2F80ED),
  Color(0xFF22B35E),
  Color(0xFFF5B800),
  Color(0xFFB74CE8),
  Color(0xFFF2711C),
  Color(0xFF7C8595),
];

/// "1.25M", "480K".
String compactAed(int v) {
  if (v >= 1000000) {
    final s = (v / 1000000).toStringAsFixed(2).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return '${s}M';
  }
  if (v >= 1000) return '${(v / 1000).round()}K';
  return '$v';
}

const assetStatusColors = {
  AssetStatus.active: Color(0xFF22B35E),
  AssetStatus.underMaintenance: Color(0xFFF5B800),
  // A darker amber, so the two amber statuses stay apart in the donut.
  AssetStatus.inRepair: Color(0xFFE08A00),
  AssetStatus.disposed: Color(0xFFEF4444),
  AssetStatus.other: Color(0xFF7C8595),
};

const healthBandColors = {
  HealthBand.healthy: Color(0xFF22B35E),
  HealthBand.warning: Color(0xFFF5B800),
  HealthBand.critical: Color(0xFFEF4444),
};

/// Planned / Unplanned / Overdue work orders (Maintenance Performance).
const plannedColor = Color(0xFF6C3CE9);
const unplannedColor = Color(0xFFF2994A);
const overdueColor = Color(0xFFEF4444);

const costGroupColors = {
  CostGroup.maintenance: Color(0xFF2F80ED),
  CostGroup.operations: Color(0xFF22B35E),
  CostGroup.spareParts: Color(0xFFF5B800),
};

/// Icon, tile tone and dot colour of an Upcoming Activities row.
(IconData, TileTone, Color) activityLook(ActivityKind k) => switch (k) {
  ActivityKind.workOrder => (Icons.build_rounded, TileTone.sky, AppColors.iconBlue),
  ActivityKind.inspection => (Icons.description_rounded, TileTone.mint, AppColors.iconGreen),
  ActivityKind.audit => (Icons.view_in_ar_rounded, TileTone.lavender, AppColors.iconViolet),
  ActivityKind.approval => (Icons.check_box_rounded, TileTone.peach, AppColors.iconOrange),
};

/// Icon of a breakdown asset type (`homeAssetTypes`).
IconData assetTypeIcon(String type) => switch (type) {
  'IT Equipment' => Icons.computer_rounded,
  'HVAC' => Icons.ac_unit_rounded,
  'Generator' => Icons.bolt_rounded,
  'Fire Safety' => Icons.local_fire_department_rounded,
  'Electrical' => Icons.electrical_services_rounded,
  'Plumbing' => Icons.plumbing_rounded,
  'Production Equipment' => Icons.precision_manufacturing_rounded,
  'Vehicles' => Icons.local_shipping_rounded,
  _ => Icons.category_rounded,
};

/// Icon of an asset status (Asset Overview "By Status").
IconData assetStatusIcon(String status) => switch (status) {
  AssetStatus.active => Icons.check_circle_rounded,
  AssetStatus.underMaintenance => Icons.build_circle_rounded,
  AssetStatus.inRepair => Icons.handyman_rounded,
  AssetStatus.disposed => Icons.delete_rounded,
  _ => Icons.more_horiz_rounded,
};

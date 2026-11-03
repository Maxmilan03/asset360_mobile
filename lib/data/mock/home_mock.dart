import 'package:asset360_mobile/data/models/home_insights.dart';

/// Quick actions on Home, in default order. The first 7 enabled ones are shown,
/// followed by "More Actions". Customize can reorder and toggle them.
const defaultQuickActions = [
  ('scan', true),
  ('reportIssue', true),
  ('moveAsset', true),
  ('createWorkOrder', true),
  ('startInspection', true),
  ('assetAudit', true),
  ('inventoryIssue', true),
  ('registerAsset', false),
  ('trackAsset', false),
  ('documents', false),
  ('offlineSync', false),
];

/// Assets the user opened recently (Home "Recent Assets"), newest first.
const seedRecentAssetIds = ['CNC-00123', 'GEN-00045'];

/// Last 6 months of the maintenance KPIs (Apr … Sep 2026); the last value is the current one.
const kpiMonths = ['Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep'];
const kpiTrends = {
  'pm': [86.0, 88.0, 87.0, 90.0, 91.0, 92.0],
  'mttr': [2.6, 2.4, 2.3, 2.1, 1.9, 1.8],
  'closure': [93.0, 94.0, 96.0, 95.0, 97.0, 98.0],
  'downtime': [19.0, 17.0, 16.0, 15.0, 13.0, 12.0],
};

// ---------------------------------------------------------------- Home drill-downs
//
// Org-wide breakdowns of the 12,458 assets (summary figures). Each list sums to the org
// total and the health bands sum to the org health counts (Data check → "Home drill-downs").

/// Asset types of the Asset Overview / Health / Cost breakdowns, in display order.
const homeAssetTypes = [
  'IT Equipment',
  'HVAC',
  'Generator',
  'Fire Safety',
  'Electrical',
  'Plumbing',
  'Production Equipment',
  'Vehicles',
  'Others',
];

/// Assets per type, split Healthy / Warning / Critical (sums to 12,458; 10,838 / 1,245 / 375).
const seedAssetsByType = [
  AssetGroupStat('IT Equipment', healthy: 2840, warning: 250, critical: 30),
  AssetGroupStat('HVAC', healthy: 857, warning: 140, critical: 48),
  AssetGroupStat('Generator', healthy: 225, warning: 52, critical: 35),
  AssetGroupStat('Fire Safety', healthy: 1718, warning: 120, critical: 22),
  AssetGroupStat('Electrical', healthy: 1230, warning: 150, critical: 40),
  AssetGroupStat('Plumbing', healthy: 732, warning: 95, critical: 38),
  AssetGroupStat('Production Equipment', healthy: 1884, warning: 260, critical: 92),
  AssetGroupStat('Vehicles', healthy: 334, warning: 58, critical: 26),
  AssetGroupStat('Others', healthy: 1018, warning: 120, critical: 44),
];

/// Assets per site / building (same totals as [seedAssetsByType]).
const seedAssetsByLocation = [
  AssetGroupStat('Dubai Factory · Main Plant', healthy: 3420, warning: 420, critical: 140),
  AssetGroupStat('Dubai Factory · Building A', healthy: 980, warning: 190, critical: 70),
  AssetGroupStat('Dubai Factory · Building B', healthy: 815, warning: 110, critical: 35),
  AssetGroupStat('Dubai Factory · Main Warehouse', healthy: 1865, warning: 230, critical: 55),
  AssetGroupStat('Dubai Office · Head Office', healthy: 2420, warning: 160, critical: 30),
  AssetGroupStat('Education City · Admin Block', healthy: 908, warning: 85, critical: 25),
  AssetGroupStat('Education City · Admin Building', healthy: 430, warning: 50, critical: 20),
];

/// Why a detailed asset is in "Top Assets with Critical Health" (from its alerts / open work).
const healthReasons = {
  'GEN-00046': 'Low Oil Pressure',
  'GEN-00045': 'High Temperature',
  'MTR-007': 'High Vibration',
  'AHU-03': 'Filter Blocked',
  'CR-001': 'High Temperature',
  'FL-015': 'Battery Low',
  'CNC-021': 'High Vibration',
};

// Maintenance: work orders per month, Oct 2025 – Sep 2026 (the last 6 months total
// 236 planned / 24 unplanned / 11 overdue = 87% / 9% / 4%).
final maintenanceMonthStarts = [for (var i = 0; i < 12; i++) DateTime(2025, 10 + i)];
const _plannedPerMonth = [33, 34, 32, 35, 34, 36, 37, 38, 39, 40, 41, 41];
const _unplannedPerMonth = [6, 6, 7, 6, 5, 5, 5, 4, 4, 4, 4, 3];
const _overduePerMonth = [3, 3, 3, 3, 2, 3, 2, 2, 2, 2, 2, 1];

/// Mean time to repair (hours) and between failures (days) per month; the last value is current.
const mttrPerMonth = [3.1, 3.0, 2.9, 2.9, 2.8, 2.7, 2.6, 2.4, 2.3, 2.1, 1.9, 1.8];
const mtbfPerMonth = [88.0, 90.0, 93.0, 95.0, 97.0, 99.0, 101.0, 103.0, 104.0, 105.0, 107.0, 120.0];

// How each month's work orders spread over asset types and sites (weights).
const _plannedTypeWeights = [14, 16, 6, 9, 10, 5, 26, 8, 6];
const _unplannedTypeWeights = [6, 18, 12, 4, 10, 8, 28, 10, 4];
const _siteWeights = {'Dubai Factory': 70, 'Dubai Office': 18, 'Education City': 12};

/// Splits [total] by [weights] (largest remainder), so the parts always sum to [total].
List<int> splitByWeights(int total, List<int> weights) {
  final sum = weights.fold(0, (a, b) => a + b);
  final exact = [for (final w in weights) total * w / sum];
  final parts = [for (final e in exact) e.floor()];
  final order = List.generate(weights.length, (i) => i)
    ..sort((a, b) => (exact[b] - parts[b]).compareTo(exact[a] - parts[a]));
  final missing = total - parts.fold(0, (a, b) => a + b);
  for (var k = 0; k < missing; k++) {
    parts[order[k]]++;
  }
  return parts;
}

List<MaintenanceMonth> seedMaintenanceMonths() {
  final sites = _siteWeights.keys.toList();
  final siteW = _siteWeights.values.toList();
  return [
    for (var m = 0; m < 12; m++)
      for (final (planned, unplanned, overdue) in [
        (
          splitByWeights(_plannedPerMonth[m], _plannedTypeWeights),
          splitByWeights(_unplannedPerMonth[m], _unplannedTypeWeights),
          splitByWeights(_overduePerMonth[m], _unplannedTypeWeights),
        ),
      ])
        for (var t = 0; t < homeAssetTypes.length; t++)
          for (final (p, u, o) in [
            (splitByWeights(planned[t], siteW), splitByWeights(unplanned[t], siteW), splitByWeights(overdue[t], siteW)),
          ])
            for (var s = 0; s < sites.length; s++)
              if (p[s] + u[s] + o[s] > 0)
                MaintenanceMonth(
                  month: maintenanceMonthStarts[m],
                  site: sites[s],
                  type: homeAssetTypes[t],
                  planned: p[s],
                  unplanned: u[s],
                  overdue: o[s],
                ),
  ];
}

// Cost Summary (AED). YTD 2026 uses the org summary's six categories (1.25M).
const _k = 1000;

/// 2025 full year: Maintenance 610K, Operations 730K (Labor + Energy + Contracts / AMC + Others), Spare Parts 300K.
const costCategories2025 = {
  'Maintenance': 610 * _k,
  'Spare Parts': 300 * _k,
  'Labor': 235 * _k,
  'Energy': 215 * _k,
  'Contracts / AMC': 170 * _k,
  'Others': 110 * _k,
};

final costMonthly2026 = {
  CostGroup.maintenance: [
    for (final v in const [50, 52, 48, 55, 54, 56, 53, 57, 55]) v * _k,
  ],
  CostGroup.operations: [
    for (final v in const [60, 58, 62, 61, 63, 59, 62, 64, 61]) v * _k,
  ],
  CostGroup.spareParts: [
    for (final v in const [24, 22, 26, 23, 25, 24, 27, 25, 24]) v * _k,
  ],
};

final costMonthly2025 = {
  CostGroup.maintenance: [
    for (final v in const [52, 50, 53, 51, 50, 49, 52, 51, 50, 49, 51, 52]) v * _k,
  ],
  CostGroup.operations: [
    for (final v in const [62, 60, 61, 60, 62, 61, 60, 59, 61, 60, 62, 62]) v * _k,
  ],
  CostGroup.spareParts: [
    for (final v in const [25, 24, 26, 25, 24, 26, 25, 24, 25, 25, 26, 25]) v * _k,
  ],
};

const costByType2026 = {
  'IT Equipment': 140 * _k,
  'HVAC': 210 * _k,
  'Generator': 155 * _k,
  'Fire Safety': 75 * _k,
  'Electrical': 120 * _k,
  'Plumbing': 60 * _k,
  'Production Equipment': 330 * _k,
  'Vehicles': 95 * _k,
  'Others': 65 * _k,
};

const costByType2025 = {
  'IT Equipment': 180 * _k,
  'HVAC': 270 * _k,
  'Generator': 205 * _k,
  'Fire Safety': 95 * _k,
  'Electrical': 160 * _k,
  'Plumbing': 80 * _k,
  'Production Equipment': 430 * _k,
  'Vehicles': 130 * _k,
  'Others': 90 * _k,
};

/// 2024 full-year total (2025's "vs last year").
const costTotal2024 = 1580 * _k;

// Asset Location (Live): floors of the map and where each detailed asset sits on them.

const mapFloors = [
  MapFloor(id: 'wh', site: 'Dubai Factory', name: 'Main Warehouse · Ground Floor', variant: 0, youAreHere: (.34, .96)),
  MapFloor(
    id: 'pf1',
    site: 'Dubai Factory',
    name: 'Main Plant · Production Floor 1',
    variant: 1,
    youAreHere: (.66, .96),
  ),
  MapFloor(id: 'bla', site: 'Dubai Factory', name: 'Building A & B · Ground Floor', variant: 0, youAreHere: (.34, .04)),
  MapFloor(id: 'ho', site: 'Dubai Office', name: 'Head Office · Building A', variant: 2, youAreHere: (.50, .96)),
  MapFloor(id: 'ec', site: 'Education City', name: 'Admin Block · 2nd Floor', variant: 2, youAreHere: (.02, .48)),
];

/// Asset → (floor id, x, y). Tracked assets (FL-012, FL-015, CR-001, CAB-011) follow their live
/// tracking position on the warehouse floor instead.
const mapPins = {
  'FL-012': ('wh', .58, .36),
  'FL-015': ('wh', .66, .62),
  'CR-001': ('wh', .18, .62),
  'CAB-011': ('wh', .44, .82),
  'DRL-0043': ('bla', .80, .24),
  'CNC-00123': ('pf1', .20, .30),
  'CNC-021': ('pf1', .30, .62),
  'MTR-00123': ('pf1', .52, .40),
  'MTR-007': ('pf1', .55, .70),
  'AHU-02': ('pf1', .86, .22),
  'CH-00021': ('pf1', .88, .78),
  'GEN-00045': ('bla', .14, .24),
  'GEN-00046': ('bla', .24, .34),
  'AHU-03': ('bla', .52, .30),
  'FE-0042': ('bla', .60, .66),
  'FP-0021': ('bla', .86, .60),
  'LAP-0098': ('ho', .20, .22),
  'CAM-0044': ('ho', .80, .74),
  'TL-034': ('ec', .26, .72),
  'PRJ-0042': ('ec', .74, .24),
  'LFT-01': ('ec', .84, .74),
};

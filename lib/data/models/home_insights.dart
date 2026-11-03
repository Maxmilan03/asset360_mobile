/// Models behind the Home drill-downs (Asset Overview, Maintenance Performance,
/// Asset Health, Cost Summary, Upcoming Activities). Org-wide figures are summary
/// numbers; every breakdown sums to its total (Data check → "Home drill-downs").
library;

/// Health bands of `Asset.healthScore`.
enum HealthBand {
  healthy('Healthy'),
  warning('Warning'),
  critical('Critical');

  const HealthBand(this.label);

  final String label;

  /// Healthy ≥ 80, Warning 60–79, Critical < 60.
  static HealthBand of(int score) => score >= 80 ? healthy : (score >= 60 ? warning : critical);
}

/// Org-wide asset count of one asset type or one site / building, split by health band.
class AssetGroupStat {
  const AssetGroupStat(this.name, {required this.healthy, required this.warning, required this.critical});

  final String name;
  final int healthy;
  final int warning;
  final int critical;

  int get total => healthy + warning + critical;

  int count(HealthBand b) => switch (b) {
    HealthBand.healthy => healthy,
    HealthBand.warning => warning,
    HealthBand.critical => critical,
  };

  AssetGroupStat bump(HealthBand b, int by) => AssetGroupStat(
    name,
    healthy: healthy + (b == HealthBand.healthy ? by : 0),
    warning: warning + (b == HealthBand.warning ? by : 0),
    critical: critical + (b == HealthBand.critical ? by : 0),
  );
}

/// Work orders raised in one month at one site for one asset type.
class MaintenanceMonth {
  const MaintenanceMonth({
    required this.month,
    required this.site,
    required this.type,
    required this.planned,
    required this.unplanned,
    required this.overdue,
  });

  /// First day of the month.
  final DateTime month;
  final String site;
  final String type;
  final int planned;
  final int unplanned;
  final int overdue;

  int get total => planned + unplanned + overdue;
}

/// Planned / unplanned / overdue totals of a set of [MaintenanceMonth] records.
class WoMix {
  const WoMix(this.planned, this.unplanned, this.overdue);

  final int planned;
  final int unplanned;
  final int overdue;

  int get total => planned + unplanned + overdue;
  double pct(int v) => total == 0 ? 0 : v * 100 / total;

  static WoMix of(Iterable<MaintenanceMonth> rows) {
    var p = 0, u = 0, o = 0;
    for (final r in rows) {
      p += r.planned;
      u += r.unplanned;
      o += r.overdue;
    }
    return WoMix(p, u, o);
  }
}

/// The three cost cards of the Cost Summary.
enum CostGroup {
  maintenance('Maintenance'),
  operations('Operations'),
  spareParts('Spare Parts');

  const CostGroup(this.label);

  final String label;

  /// Cost categories of the org summary that make up each card.
  static CostGroup of(String category) => switch (category) {
    'Maintenance' => maintenance,
    'Spare Parts' => spareParts,
    _ => operations, // Labor, Energy, Contracts / AMC, Others
  };
}

/// One year of the Cost Summary (AED).
class CostYear {
  const CostYear({
    required this.label,
    required this.year,
    required this.categories,
    required this.monthly,
    required this.byType,
    required this.previousTotal,
  });

  /// "YTD 2026" or "2025".
  final String label;
  final int year;

  /// The six cost categories (Maintenance, Spare Parts, Labor, Energy, Contracts / AMC, Others).
  final Map<String, int> categories;

  /// Per card, one value per month from January (Jan–Sep for YTD, Jan–Dec for a full year).
  final Map<CostGroup, List<int>> monthly;
  final Map<String, int> byType;

  /// The same months of the year before (for "vs last year").
  final int previousTotal;

  int get total => categories.values.fold(0, (a, b) => a + b);
  int get months => monthly.values.first.length;

  int groupTotal(CostGroup g) =>
      categories.entries.where((e) => CostGroup.of(e.key) == g).fold(0, (a, e) => a + e.value);
  int monthTotal(int i) => monthly.values.fold(0, (a, l) => a + l[i]);
  double pct(int v) => total == 0 ? 0 : v * 100 / total;

  /// Change vs the year before, in percent (positive = costs went up).
  double get changePct => previousTotal == 0 ? 0 : (total - previousTotal) * 100 / previousTotal;
}

/// Kinds of row in Upcoming Activities.
enum ActivityKind {
  workOrder('Work Order'),
  inspection('Inspection'),
  audit('Audit'),
  approval('Approval');

  const ActivityKind(this.label);

  final String label;
}

/// One scheduled item in Upcoming Activities, built from a real record.
class PlannedActivity {
  const PlannedActivity({
    required this.kind,
    required this.refId,
    required this.title,
    required this.start,
    required this.end,
    required this.status,
    required this.route,
    this.assetId,
    this.location,
  });

  final ActivityKind kind;
  final String refId;
  final String title;
  final String? assetId;
  final String? location;
  final DateTime start;

  /// Always after [start].
  final DateTime end;

  /// Planned, Scheduled, Pending, In Progress or Completed.
  final String status;

  /// The screen that opens the record.
  final String route;
}

/// One floor of the live map: [variant] picks the FloorPlan layout.
class MapFloor {
  const MapFloor({
    required this.id,
    required this.site,
    required this.name,
    required this.variant,
    required this.youAreHere,
  });

  final String id;
  final String site;

  /// "Main Warehouse · Ground Floor".
  final String name;
  final int variant;

  /// "You are here" marker (0–1 fractions of the plan).
  final (double, double) youAreHere;

  /// Metres across the plan (for "Get Directions").
  double get widthMetres => variant == 2 ? 40 : 80;
}

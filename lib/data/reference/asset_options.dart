/// The one place for asset status, condition and criticality values, shared with the web app
/// and the backend. Every screen reads these lists; nothing else hard-codes them.
///
/// Sources: docs/api_samples/condition_ratings.json and docs/api_samples/criticality_options.json
/// (GET /api/asset-condition-assessments/ratings, GET /api/asset-criticality/options).
library;

/// Asset status values (basicInformation.status).
///
/// PROVISIONAL: the backend's GET /api/asset-registrations `summary` counts active /
/// underMaintenance / inRepair / disposed / other, so it stores these four strings; any other
/// value (e.g. "Inactive", "Retired") is kept as entered, shows as a grey chip and counts as
/// [other]. Change the strings here when the backend confirms them.
abstract final class AssetStatus {
  static const active = 'Active';
  static const underMaintenance = 'Under Maintenance';
  static const inRepair = 'In Repair';
  static const disposed = 'Disposed';

  /// Summary bucket for every other value; never stored on an asset.
  static const other = 'Other';

  /// Raw values the register already holds that count as [other].
  static const inactive = 'Inactive';
  static const retired = 'Retired';

  /// The values a user can pick (status dropdowns, registration, import).
  static const values = [active, underMaintenance, inRepair, disposed];

  /// Summary keys, in legend order (Home donut, filters, org summary).
  static const all = [...values, other];

  /// The summary key of a stored status: itself for one of [values], else [other].
  static String bucketOf(String status) => values.contains(status) ? status : other;
}

/// Colour group of an option value; [ChipTone.forAsset] turns it into a chip colour.
enum OptionTone { green, amber, red, grey }

abstract final class AssetOptions {
  /// Status dropdowns (see [AssetStatus]).
  static const statuses = AssetStatus.values;

  /// condition_ratings.json, best first.
  static const conditions = ['Excellent', 'Good', 'Fair', 'Poor', 'Critical'];

  /// criticality_options.json → criticalityLevels, lowest first.
  static const criticalityLevels = ['Low', 'Medium', 'High', 'Critical'];

  /// criticality_options.json → likelihoodRatings.
  static const likelihoodRatings = ['Very Low', 'Low', 'Medium', 'High', 'Very High'];

  /// criticality_options.json → consequenceRatings.
  static const consequenceRatings = ['Very Low', 'Low', 'Medium', 'High', 'Very High'];

  /// criticality_options.json → criteria (weights add up to 100).
  static const criteria = [
    CriticalityCriterion('Operational Impact', 25),
    CriticalityCriterion('Safety Impact', 20),
    CriticalityCriterion('Financial Impact', 20),
    CriticalityCriterion('Compliance / Regulatory', 15),
    CriticalityCriterion('Environmental Impact', 10),
    CriticalityCriterion('Reputation Impact', 10),
  ];

  /// Tagging Method (AssetClassificationDto.taggingMethod).
  static const taggingMethods = ['Barcode', 'RFID', 'BLE', 'QR Code'];

  /// AssetWarrantyDto.warrantyPeriodUnit.
  static const warrantyPeriodUnits = PeriodUnit.all;

  // ---- TEMP until Master Data API: values read off design/web_registration/*.png. Each web
  // dropdown shows only its selected value (listed first); the other values are guesses.

  /// TEMP until Master Data API. Web: "In Use".
  static const lifecycleStages = ['In Use', 'Planning', 'Procurement', 'Commissioning', 'Decommissioning', 'Disposed'];

  /// TEMP until Master Data API. Web: "Backup Power".
  static const functionPurposes = [
    'Backup Power',
    'Primary Power',
    'Production',
    'Material Handling',
    'Cooling & Ventilation',
    'Fire Protection',
    'IT & Communication',
    'Transport',
    'General Use',
  ];

  /// TEMP until Master Data API. Web: "Facilities Management" (Department and Custodian /
  /// Department use the same list).
  static const departments = [
    'Facilities Management',
    'Production',
    'Maintenance',
    'Warehouse',
    'Operations',
    'IT',
    'Finance',
    'Marketing',
    'Admin',
  ];

  /// TEMP until Master Data API. Web: "FM-001 - Building Operations".
  static const costCenters = [
    'FM-001 - Building Operations',
    'PR-001 - Production',
    'MT-001 - Maintenance',
    'WH-001 - Warehouse',
    'IT-001 - IT Services',
    'AD-001 - Administration',
  ];

  /// TEMP until Master Data API. Web: "Head Office".
  static const businessUnits = ['Head Office', 'Manufacturing', 'Facilities Management', 'Logistics', 'Corporate IT'];

  /// TEMP until Master Data API. Web: "Safety Critical Equipment".
  static const complianceCategories = [
    'Safety Critical Equipment',
    'Fire & Life Safety',
    'Electrical Safety',
    'Environmental',
    'Statutory Inspection',
    'Not Applicable',
  ];

  /// TEMP until Master Data API. Web: "Company Owned".
  static const ownershipTypes = ['Company Owned', 'Leased', 'Rented', 'Customer Owned'];

  /// TEMP until Master Data API. Web: "MEP Team".
  static const responsibleTeams = [
    'MEP Team',
    'Electrical Team',
    'Mechanical Team',
    'HVAC Team',
    'IT Support',
    'Facilities Team',
    'Production Team',
  ];

  /// TEMP until Master Data API. Web: "Unit(s)".
  static const quantityUnits = ['Unit(s)', 'Set(s)', 'Lot(s)', 'Piece(s)'];

  /// TEMP until Master Data API. Stored value = ISO code (the web shows "AED - UAE Dirham" and
  /// "Purchase Cost (AED)").
  static const currencies = {
    'AED': 'AED - UAE Dirham',
    'USD': 'USD - US Dollar',
    'EUR': 'EUR - Euro',
    'SAR': 'SAR - Saudi Riyal',
  };

  /// TEMP until Master Data API. Web: "30 Days".
  static const paymentTerms = ['30 Days', 'Immediate', '15 Days', '45 Days', '60 Days', '90 Days', 'Advance Payment'];

  /// TEMP until Master Data API. Web: "Direct Purchase".
  static const procurementMethods = ['Direct Purchase', 'Quotation (RFQ)', 'Tender', 'Framework Agreement', 'Lease'];

  /// TEMP until Master Data API. Web: "Manufacturer Warranty".
  static const warrantyTypes = ['Manufacturer Warranty', 'Extended Warranty', 'Vendor Warranty', 'No Warranty'];

  /// TEMP until Master Data API. Web: "24x7".
  static const supportCoverages = ['24x7', 'Business Hours', 'Parts & Labour', 'Parts Only', 'Labour Only'];

  /// TEMP until Master Data API. Web: "Caterpillar (UAE)".
  static const serviceProviders = [
    'Caterpillar (UAE)',
    'ABC Engineering',
    'Al Futtaim Engineering',
    'Siemens LLC',
    'Dell Gulf',
  ];

  /// TEMP until Master Data API. Web: "24x7".
  static const operatingShifts = ['24x7', 'Day Shift', 'Night Shift', '2 Shifts'];

  /// TEMP until Master Data API. Web: "Primary".
  static const utilizations = ['Primary', 'Standby', 'Backup', 'Occasional'];

  /// TEMP until Master Data API. Web: "Hours" (Operating Hours (Per Day) unit).
  static const operatingHoursUnits = ['Hours'];

  /// TEMP until Master Data API. Web: "Hours" (Maintenance Frequency unit).
  static const maintenanceFrequencyUnits = ['Hours', PeriodUnit.days, 'Week(s)', PeriodUnit.months, PeriodUnit.years];

  /// TEMP until Master Data API. Web: "ISO 8528", "UAE Civil Defence", "Manufacturer Standard".
  static const complianceStandards = [
    'ISO 8528',
    'UAE Civil Defence',
    'Manufacturer Standard',
    'ISO 9001',
    'ISO 14001',
    'ISO 45001',
    'NFPA 20',
    'NFPA 110',
    'IEC 60034',
    'ASHRAE 62.1',
  ];

  /// TEMP until Master Data API. Web: "mm", "kg", "Year(s)".
  static const dimensionUnits = ['mm', 'cm', 'm'];
  static const weightUnits = ['kg', 't'];
  static const lifespanUnits = [PeriodUnit.years, PeriodUnit.months];

  /// AssetCustomFieldDto.fieldType.
  static const customFieldTypes = CustomFieldType.all;

  /// One colour per value: green Active / Excellent / Good / Low, amber Fair / Under Maintenance /
  /// In Repair / Medium, red Poor / Critical / Disposed / High, grey Other and anything unknown.
  static OptionTone toneOf(String value) => switch (value) {
    AssetStatus.active || 'Excellent' || 'Good' || 'Low' => OptionTone.green,
    'Fair' || AssetStatus.underMaintenance || AssetStatus.inRepair || 'Medium' => OptionTone.amber,
    'Poor' || 'Critical' || AssetStatus.disposed || 'High' => OptionTone.red,
    _ => OptionTone.grey,
  };
}

/// Day(s) / Month(s) / Year(s) (warrantyPeriodUnit; also lifespan and maintenance units).
abstract final class PeriodUnit {
  static const days = 'Day(s)';
  static const months = 'Month(s)';
  static const years = 'Year(s)';
  static const all = [days, months, years];

  /// The server's WarrantyPeriodUnits: "day", "Days", "Day(s)" … (any case) → "Day(s)"; null
  /// when not a warranty period unit.
  static String? normalize(String? unit) => switch (unit?.trim().toLowerCase()) {
    'day' || 'days' || 'day(s)' => days,
    'month' || 'months' || 'month(s)' => months,
    'year' || 'years' || 'year(s)' => years,
    _ => null,
  };
}

/// Custom field types (Add Field).
abstract final class CustomFieldType {
  static const text = 'Text';
  static const number = 'Number';
  static const date = 'Date';
  static const dropdown = 'Dropdown';

  /// Only in the server's list (GET /api/asset-registrations/options → customFieldTypes).
  static const yesNo = 'Yes/No';

  /// The local list (mock mode); API mode uses the server's.
  static const all = [text, number, date, dropdown];
}

class CriticalityCriterion {
  const CriticalityCriterion(this.name, this.weight);

  final String name;

  /// Percent of the criteria score.
  final int weight;
}

/// Result of [assessCriticality].
class CriticalityResult {
  const CriticalityResult({required this.score, required this.level});

  /// 1.0 (all Very Low) … 5.0 (all Very High).
  final double score;

  /// One of [AssetOptions.criticalityLevels].
  final String level;
}

/// Criticality from a Likelihood × Consequence rating and the weighted criteria.
///
/// criticality_options.json lists the ratings, levels and weights but not how they combine, so
/// this is a simple stand-in until the backend says (open question in the report):
/// - each rating counts 1 (Very Low) … 5 (Very High); criteria are rated on the consequence scale;
/// - criteria score = weighted average of the rated criteria (unrated ones are left out);
/// - score = 50% criteria score + 25% likelihood + 25% consequence (the parts given, re-weighted);
/// - level: below 2.0 Low, below 3.0 Medium, below 4.0 High, otherwise Critical.
/// Returns null until at least one rating is given.
CriticalityResult? assessCriticality({
  String? likelihood,
  String? consequence,
  Map<String, String> criteria = const {},
}) {
  int? points(String? rating, [List<String> scale = AssetOptions.consequenceRatings]) {
    final i = rating == null ? -1 : scale.indexOf(rating);
    return i < 0 ? null : i + 1;
  }

  var weightSum = 0, weighted = 0;
  for (final c in AssetOptions.criteria) {
    final p = points(criteria[c.name]);
    if (p == null) continue;
    weightSum += c.weight;
    weighted += p * c.weight;
  }
  final parts = <(double value, double weight)>[
    if (weightSum > 0) (weighted / weightSum, .5),
    if (points(likelihood, AssetOptions.likelihoodRatings) case final l?) (l.toDouble(), .25),
    if (points(consequence) case final c?) (c.toDouble(), .25),
  ];
  if (parts.isEmpty) return null;
  final totalWeight = parts.fold<double>(0, (s, p) => s + p.$2);
  final score = parts.fold<double>(0, (s, p) => s + p.$1 * p.$2) / totalWeight;
  final level = score < 2
      ? 'Low'
      : score < 3
      ? 'Medium'
      : score < 4
      ? 'High'
      : 'Critical';
  return CriticalityResult(score: score, level: level);
}

/// Ratings picked in the Assess sheet; shaped like CreateAssetCriticalityRequest
/// (likelihood, consequence, criteria[name, weight, score]) for POST /api/asset-criticality later.
class CriticalityAssessment {
  const CriticalityAssessment({this.likelihood, this.consequence, this.criteria = const {}});

  final String? likelihood;
  final String? consequence;

  /// Criterion name → rating (consequence scale).
  final Map<String, String> criteria;

  CriticalityResult? get result =>
      assessCriticality(likelihood: likelihood, consequence: consequence, criteria: criteria);

  Map<String, dynamic> toJson() => {
    'likelihood': likelihood,
    'consequence': consequence,
    'criteria': [
      for (final c in AssetOptions.criteria)
        if (criteria[c.name] case final r?)
          {'name': c.name, 'weight': c.weight, 'score': AssetOptions.consequenceRatings.indexOf(r) + 1},
    ],
  };

  static CriticalityAssessment? fromJson(Object? json) {
    if (json is! Map) return null;
    final criteria = <String, String>{};
    for (final c in json['criteria'] is List ? json['criteria'] as List : const []) {
      final score = (c is Map ? c['score'] : null) as num?;
      if (c is Map && c['name'] is String && score != null && score >= 1 && score <= 5) {
        criteria[c['name'] as String] = AssetOptions.consequenceRatings[score.toInt() - 1];
      }
    }
    return CriticalityAssessment(
      likelihood: json['likelihood'] as String?,
      consequence: json['consequence'] as String?,
      criteria: criteria,
    );
  }
}

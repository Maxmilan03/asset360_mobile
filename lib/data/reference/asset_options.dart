/// The one place for asset status, condition and criticality values, shared with the web app
/// and the backend. Every screen reads these lists; nothing else hard-codes them.
///
/// Sources: docs/api_samples/condition_ratings.json and docs/api_samples/criticality_options.json
/// (GET /api/asset-condition-assessments/ratings, GET /api/asset-criticality/options).
library;

/// Asset status values.
///
/// PROVISIONAL: taken from the `summary` keys of GET /api/asset-registrations
/// (active / underMaintenance / inRepair / disposed / other). The backend has not confirmed the
/// exact strings it stores yet; change them here when it does.
abstract final class AssetStatus {
  static const active = 'Active';
  static const underMaintenance = 'Under Maintenance';
  static const inRepair = 'In Repair';
  static const disposed = 'Disposed';
  static const other = 'Other';

  /// Every status, in legend order (also the org summary keys).
  static const all = [active, underMaintenance, inRepair, disposed, other];
}

/// Colour group of an option value; [ChipTone.forAsset] turns it into a chip colour.
enum OptionTone { green, amber, red, grey }

abstract final class AssetOptions {
  static const statuses = AssetStatus.all;

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

  /// One colour per value: green Active / Excellent / Good / Low, amber Fair / Under Maintenance /
  /// In Repair / Medium, red Poor / Critical / Disposed / High, grey Other and anything unknown.
  static OptionTone toneOf(String value) => switch (value) {
    AssetStatus.active || 'Excellent' || 'Good' || 'Low' => OptionTone.green,
    'Fair' || AssetStatus.underMaintenance || AssetStatus.inRepair || 'Medium' => OptionTone.amber,
    'Poor' || 'Critical' || AssetStatus.disposed || 'High' => OptionTone.red,
    _ => OptionTone.grey,
  };
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
CriticalityResult? assessCriticality({String? likelihood, String? consequence, Map<String, String> criteria = const {}}) {
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

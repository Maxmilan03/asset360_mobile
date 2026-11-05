/// Null-safe JSON readers for the Asset service models: a missing or wrongly typed value never
/// throws, it reads as null / empty.
library;

String? jStr(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
int? jInt(Object? v) => v is num ? v.toInt() : (v is String ? int.tryParse(v) : null);
double? jNum(Object? v) => v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null);
bool jBool(Object? v, {bool orElse = false}) => v is bool ? v : orElse;

/// ISO dates; a value without a zone ("2026-09-01T00:00:00") is the server's UTC calendar date.
DateTime? jDate(Object? v) => v is String ? DateTime.tryParse(v) : null;
Map<String, dynamic> jMap(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
List<Object?> jList(Object? v) => v is List ? v : const [];
List<String> jStrings(Object? v) => [for (final s in jList(v)) ?jStr(s)];

/// Items of a list reply: a bare array, or `{items: [...]}`.
List<Object?> jItems(Object? body) => body is List ? body : jList(jMap(body)['items']);

/// A calendar date as the server stores it ("2026-09-25").
String? jDay(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

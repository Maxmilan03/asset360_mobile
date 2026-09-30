/// Next ID in a series, e.g. nextId('WO-2026-', ids) → 'WO-2026-0143'.
String nextId(String prefix, Iterable<String> existing, {int width = 4}) {
  var max = 0;
  for (final id in existing) {
    if (!id.startsWith(prefix)) continue;
    final n = int.tryParse(id.substring(prefix.length));
    if (n != null && n > max) max = n;
  }
  return '$prefix${(max + 1).toString().padLeft(width, '0')}';
}

/// Replaces the item whose [idOf] equals [id] with [update] applied.
List<T> replaceWhere<T>(List<T> list, String id, String Function(T) idOf, T Function(T) update) => [
  for (final x in list) idOf(x) == id ? update(x) : x,
];

extension FirstWhereOrNullX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final x in this) {
      if (test(x)) return x;
    }
    return null;
  }
}

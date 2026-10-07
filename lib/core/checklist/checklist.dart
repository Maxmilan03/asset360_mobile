/// Reusable checklist engine: the item / section model shared by inspections and work-order tasks.
/// Widgets live in `checklist_widgets.dart`.
library;

/// Item types the engine can render.
enum CheckType {
  /// A checkbox ("Check oil level"), optionally with a number reading ([CheckItem.unit]).
  tick,

  /// Radio chips; the first option is the good answer ("Good" / "Minor Issue" / "Major Issue").
  choice,

  /// Two radio chips; the first option is the good answer ("No" leakage, "Yes" guards in place).
  yesNo,

  /// Number with a unit and an optional normal range ([CheckItem.min] – [CheckItem.max]).
  number,

  /// Free text.
  text,

  /// One or more photos.
  photo,

  /// A finger-drawn signature.
  signature,
}

/// A point of a signature stroke, as 0–1 fractions of the pad.
typedef SignaturePoint = (double, double);

class CheckItem {
  const CheckItem({
    required this.code,
    required this.label,
    required this.type,
    this.options = const [],
    this.unit,
    this.min,
    this.max,
    this.value,
    this.reading,
    this.photos = const [],
    this.signature = const [],
    this.required = true,
  });

  /// "1.1", "2.3" or an ID such as "WO45-T2-4".
  final String code;
  final String label;
  final CheckType type;

  /// For choice / yesNo. The first option is the good answer; the others are negative.
  final List<String> options;
  final String? unit;
  final double? min;
  final double? max;

  /// The answer: chosen option, number or text; "Done" for a ticked [CheckType.tick].
  final String? value;

  /// Number reading of a tick item with a unit ("2.3" mm/s).
  final String? reading;
  final List<String> photos;
  final List<List<SignaturePoint>> signature;

  /// Required items must be answered before the checklist is complete.
  final bool required;

  static const done = 'Done';

  bool get answered => switch (type) {
    CheckType.photo => photos.isNotEmpty,
    CheckType.signature => signature.isNotEmpty,
    _ => value != null && value!.trim().isNotEmpty,
  };

  bool get hasRange => min != null && max != null;

  /// The number checked against the range: the answer of a number item, the reading of a tick item.
  String? get _number => type == CheckType.number ? value : (type == CheckType.tick ? reading : null);

  /// Inside the normal range? Null when there is no range or no number yet.
  bool? get inRange {
    if (!hasRange) return null;
    final v = double.tryParse((_number ?? '').trim().replaceAll(',', '.'));
    if (v == null) return null;
    return v >= min! && v <= max!;
  }

  /// A bad answer: a non-first option, or a number outside the normal range.
  bool get negative => switch (type) {
    CheckType.choice || CheckType.yesNo => answered && options.isNotEmpty && value != options.first,
    CheckType.number || CheckType.tick => inRange == false,
    _ => false,
  };

  /// Counts towards the score: answered and not negative.
  bool get passed => answered && !negative;

  String? get rangeLabel => hasRange ? '${_n(min!)} – ${_n(max!)} ${unit ?? ''}'.trim() : null;

  static String _n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  CheckItem copyWith({
    String? value,
    bool clearValue = false,
    String? reading,
    List<String>? photos,
    List<List<SignaturePoint>>? signature,
  }) => CheckItem(
    code: code,
    label: label,
    type: type,
    options: options,
    unit: unit,
    min: min,
    max: max,
    value: clearValue ? null : value ?? this.value,
    reading: reading ?? this.reading,
    photos: photos ?? this.photos,
    signature: signature ?? this.signature,
    required: required,
  );

  /// Same item with its answer, reading, photos and signature removed (a fresh copy for a new record).
  CheckItem get blank => CheckItem(
    code: code,
    label: label,
    type: type,
    options: options,
    unit: unit,
    min: min,
    max: max,
    required: required,
  );
}

class CheckSection {
  const CheckSection({required this.title, required this.items, this.notes = '', this.photos = const []});

  final String title;
  final List<CheckItem> items;
  final String notes;
  final List<String> photos;

  int get answered => items.where((q) => q.answered).length;
  int get passed => items.where((q) => q.passed).length;
  bool get complete => items.where((q) => q.required).every((q) => q.answered);

  CheckSection copyWith({List<CheckItem>? items, String? notes, List<String>? photos}) =>
      CheckSection(title: title, items: items ?? this.items, notes: notes ?? this.notes, photos: photos ?? this.photos);

  CheckSection get blank => CheckSection(title: title, items: [for (final i in items) i.blank]);
}

extension ChecklistX on List<CheckSection> {
  int get totalItems => fold(0, (s, e) => s + e.items.length);
  int get answeredItems => fold(0, (s, e) => s + e.answered);
  int get passedItems => fold(0, (s, e) => s + e.passed);
  bool get complete => every((s) => s.complete);

  CheckItem? item(String code) {
    for (final s in this) {
      for (final i in s.items) {
        if (i.code == code) return i;
      }
    }
    return null;
  }

  /// Copy with the item [code] replaced by [f] of it.
  List<CheckSection> updateItem(String code, CheckItem Function(CheckItem) f) => [
    for (final s in this) s.copyWith(items: [for (final i in s.items) i.code == code ? f(i) : i]),
  ];
}

extension CheckItemsX on List<CheckItem> {
  int get answered => where((i) => i.answered).length;
  bool get complete => where((i) => i.required).every((i) => i.answered);
}

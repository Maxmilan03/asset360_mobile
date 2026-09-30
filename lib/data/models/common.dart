/// One line in a history / timeline / status log.
class LogEntry {
  const LogEntry({required this.at, required this.title, this.by, this.note});

  final DateTime at;
  final String title;
  final String? by;
  final String? note;

  LogEntry copyWith({DateTime? at, String? title, String? by, String? note}) =>
      LogEntry(at: at ?? this.at, title: title ?? this.title, by: by ?? this.by, note: note ?? this.note);
}

/// A chart point: x is hours since midnight (0–24) unless stated otherwise.
class TrendPoint {
  const TrendPoint(this.x, this.y);

  final double x;
  final double y;
}

/// A file attached to a record.
class Attachment {
  const Attachment({required this.name, required this.sizeKb, this.path});

  final String name;
  final int sizeKb;

  /// Local file path or bundled asset path, when there is something to open.
  final String? path;

  String get sizeLabel => sizeKb >= 1024 ? '${(sizeKb / 1024).toStringAsFixed(1)} MB' : '$sizeKb KB';
}

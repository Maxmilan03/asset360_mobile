import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// The demo's "now". The app always starts at Friday 25 Sep 2026, 10:30 AM
/// (Asia/Dubai) and then runs forward in real time, so countdowns such as
/// "1h 20m remaining" tick. Never use DateTime.now() for business logic.
abstract final class DemoClock {
  static final DateTime start = DateTime(2026, 9, 25, 10, 30);
  static final Stopwatch _elapsed = Stopwatch()..start();

  /// When true (tests, Data check), [now] stays at [start].
  static bool frozen = false;

  static DateTime get now => frozen ? start : start.add(_elapsed.elapsed);

  static DateTime get today => DateTime(now.year, now.month, now.day);

  static bool isToday(DateTime d) => d.year == now.year && d.month == now.month && d.day == now.day;

  static bool isOverdue(DateTime due) => due.isBefore(now);

  /// "Just now", "5 mins ago", "1 hour ago", "Yesterday", "3 days ago", "12 Sep 2026".
  static String timeAgo(DateTime t) {
    final d = now.difference(t);
    if (d.isNegative || d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} ${d.inMinutes == 1 ? 'min' : 'mins'} ago';
    if (d.inHours < 24) return '${d.inHours} ${d.inHours == 1 ? 'hour' : 'hours'} ago';
    final days = today.difference(DateTime(t.year, t.month, t.day)).inDays;
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    return formatDate(t);
  }

  /// Compact duration between now and [due]: "1h 20m", "45m", "2d 3h". Always positive.
  static String timeLeft(DateTime due) => formatDuration(due.difference(now).abs());

  static String formatDuration(Duration d) {
    if (d.inDays >= 1) {
      final h = d.inHours % 24;
      return h == 0 ? '${d.inDays}d' : '${d.inDays}d ${h}h';
    }
    if (d.inHours >= 1) {
      final m = d.inMinutes % 60;
      return m == 0 ? '${d.inHours}h' : '${d.inHours}h ${m}m';
    }
    return '${d.inMinutes < 1 ? 1 : d.inMinutes}m';
  }

  /// "Due in 1h 20m" or "Overdue by 2h 10m".
  static String dueLabel(DateTime due) => isOverdue(due) ? 'Overdue by ${timeLeft(due)}' : 'Due in ${timeLeft(due)}';

  /// "25 Sep 2026".
  static String formatDate(DateTime d) => DateFormat('d MMM yyyy').format(d);

  /// "10:24 AM".
  static String formatTime(DateTime d) => DateFormat('hh:mm a').format(d);

  /// "29 Sep 2026 10:24 AM".
  static String formatDateTime(DateTime d) => '${formatDate(d)} ${formatTime(d)}';

  /// "25 Sep 2026 10:24:36 AM" (live "Last Updated" bars).
  static String formatStamp(DateTime d) => DateFormat('d MMM yyyy hh:mm:ss a').format(d);

  /// "29 Sep".
  static String formatShort(DateTime d) => DateFormat('d MMM').format(d);

  /// "Fri, 25 Sep 2026".
  static String formatLong(DateTime d) => DateFormat('EEE, d MMM yyyy').format(d);

  /// Whole days from now until [d] (negative when past).
  static int daysUntil(DateTime d) => DateTime(d.year, d.month, d.day).difference(today).inDays;

  /// Years between [from] and now, one decimal, e.g. 3.7.
  static double yearsSince(DateTime from) => now.difference(from).inDays / 365.25;
}

/// Emits every 30 seconds so time-based labels ("Due in …") refresh.
final clockTickProvider = StreamProvider<DateTime>((ref) {
  final controller = StreamController<DateTime>();
  controller.add(DemoClock.now);
  final timer = Timer.periodic(const Duration(seconds: 30), (_) => controller.add(DemoClock.now));
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

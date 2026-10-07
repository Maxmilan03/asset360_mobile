import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/demo_clock.dart';
import '../mock/alerts_mock.dart';
import '../models/alert.dart';
import '../models/common.dart';
import 'repo_utils.dart';
import 'session_repository.dart';

class AlertsNotifier extends Notifier<List<AlertItem>> {
  @override
  List<AlertItem> build() => seedAlerts();

  String get _me => ref.read(currentUserProvider).name;
  void _update(String id, AlertItem Function(AlertItem) f) => state = replaceWhere(state, id, (a) => a.id, f);

  void acknowledge(String id, {String? note}) => _update(
    id,
    (a) => a.copyWith(
      status: AlertStatus.acknowledged,
      history: [
        ...a.history,
        LogEntry(at: DemoClock.now, title: 'Acknowledged', by: _me, note: note),
      ],
    ),
  );

  /// A work order was created from the alert.
  void linkWorkOrder(String id, String woId) => _update(
    id,
    (a) => a.copyWith(
      workOrderId: woId,
      history: [
        ...a.history,
        LogEntry(at: DemoClock.now, title: 'Work order $woId created', by: _me),
      ],
    ),
  );

  int _live = 0;

  /// The simulated "live" alert (every 60 s while Alerts is open), cycling through [liveAlertTemplates].
  AlertItem raiseLive() {
    final t = liveAlertTemplates[_live++ % liveAlertTemplates.length];
    return raise(type: t.$1, severity: t.$2, assetId: t.$3, message: t.$4, location: t.$5);
  }

  /// The asset moved: unresolved alerts that showed its old location show the new one.
  void followAsset(String assetId, String from, String to) => state = [
    for (final a in state) a.assetId == assetId && !a.isResolved && a.location == from ? a.copyWith(location: to) : a,
  ];

  void resolve(String id, {String? note}) => _update(
    id,
    (a) => a.copyWith(
      status: AlertStatus.resolved,
      history: [
        ...a.history,
        LogEntry(at: DemoClock.now, title: 'Resolved', by: _me, note: note),
      ],
    ),
  );

  void addHistory(String id, String title, {String? note}) => _update(
    id,
    (a) => a.copyWith(
      history: [
        ...a.history,
        LogEntry(at: DemoClock.now, title: title, by: _me, note: note),
      ],
    ),
  );

  /// A new "live" alert (Alerts screen simulation). Also posts a notification.
  AlertItem raise({
    required String type,
    required String severity,
    required String assetId,
    required String message,
    required String location,
  }) {
    final alert = AlertItem(
      id: nextId('ALT-2026-', state.map((a) => a.id)),
      description: message,
      type: type,
      severity: severity,
      assetId: assetId,
      message: message,
      at: DemoClock.now,
      location: location,
    );
    state = [alert, ...state];
    ref
        .read(notificationsProvider.notifier)
        .post(kind: 'alert', title: type, message: '$assetId: $message', refType: 'alert', refId: alert.id);
    return alert;
  }
}

final alertsProvider = NotifierProvider<AlertsNotifier, List<AlertItem>>(AlertsNotifier.new);

final alertByIdProvider = Provider.family<AlertItem?, String>(
  (ref, id) => ref.watch(alertsProvider).firstWhereOrNull((a) => a.id == id),
);

extension AlertQueries on List<AlertItem> {
  List<AlertItem> withSeverity(String s) => where((a) => a.severity == s).toList();

  /// Home "Critical Alert – Requires Action": critical and not yet acknowledged.
  List<AlertItem> get criticalRequiringAction =>
      where((a) => a.severity == Severity.critical && a.requiresAction).toList();
  List<AlertItem> forAsset(String assetId) => where((a) => a.assetId == assetId).toList();

  /// Search by asset ID, type, message or location.
  List<AlertItem> search(String q) {
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return this;
    return where((a) => '${a.assetId} ${a.type} ${a.message} ${a.location}'.toLowerCase().contains(s)).toList();
  }

  /// Earlier occurrences of the same alert type on the same asset (Alert Details → History).
  List<AlertItem> earlierOf(AlertItem a) =>
      where((x) => x.id != a.id && x.assetId == a.assetId && x.type == a.type && x.at.isBefore(a.at)).toList()
        ..sort((x, y) => y.at.compareTo(x.at));

  /// Other assets in the same location with active (not resolved) alerts (Alert Details → Related Assets).
  List<AlertItem> relatedTo(AlertItem a) =>
      where((x) => x.assetId != a.assetId && x.location == a.location && !x.isResolved).toList();

  /// Newest first.
  List<AlertItem> get latest => [...this]..sort((a, b) => b.at.compareTo(a.at));
}

class NotificationsNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [...seedNotifications()]..sort((a, b) => b.at.compareTo(a.at));

  void markRead(String id) => state = replaceWhere(state, id, (n) => n.id, (n) => n.copyWith(read: true));
  void markUnread(String id) => state = replaceWhere(state, id, (n) => n.id, (n) => n.copyWith(read: false));
  void markAllRead() => state = [for (final n in state) n.copyWith(read: true)];
  void remove(String id) => state = state.where((n) => n.id != id).toList();

  /// Puts a removed notification back at its old position (SnackBar "Undo").
  void restore(AppNotification n, int index) => state = [...state]..insert(index.clamp(0, state.length), n);

  void post({
    required String kind,
    required String title,
    required String message,
    Set<String> categories = const {NotificationCategory.system},
    String? refType,
    String? refId,
  }) {
    state = [
      AppNotification(
        id: nextId('N-', state.map((n) => n.id), width: 3),
        kind: kind,
        title: title,
        message: message,
        at: DemoClock.now,
        categories: {NotificationCategory.system, ...categories},
        refType: refType,
        refId: refId,
      ),
      ...state,
    ];
  }
}

class NotificationSettingsNotifier extends Notifier<NotificationSettings> {
  @override
  NotificationSettings build() => const NotificationSettings();

  void setCategory(String key, bool on) => state = state.copyWith(categories: {...state.categories, key: on});
  void setQuietHours(bool on) => state = state.copyWith(quietHours: on);
  void setQuietFrom(({int h, int m}) t) => state = state.copyWith(quietFrom: t);
  void setQuietTo(({int h, int m}) t) => state = state.copyWith(quietTo: t);
}

final notificationSettingsProvider = NotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  NotificationSettingsNotifier.new,
);

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

/// The bell badge.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);

extension NotificationQueries on List<AppNotification> {
  List<AppNotification> get unread => where((n) => !n.read).toList();
  List<AppNotification> inCategory(String c) => where((n) => n.categories.contains(c)).toList();
}

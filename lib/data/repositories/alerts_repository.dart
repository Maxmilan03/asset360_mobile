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

  void acknowledge(String id) => _update(
    id,
    (a) => a.copyWith(
      status: AlertStatus.acknowledged,
      history: [
        ...a.history,
        LogEntry(at: DemoClock.now, title: 'Acknowledged', by: _me),
      ],
    ),
  );

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
        .post(kind: 'alert', title: type, message: message, refType: 'alert', refId: alert.id);
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

final notificationsProvider = NotifierProvider<NotificationsNotifier, List<AppNotification>>(NotificationsNotifier.new);

/// The bell badge.
final unreadNotificationCountProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => !n.read).length,
);

extension NotificationQueries on List<AppNotification> {
  List<AppNotification> get unread => where((n) => !n.read).toList();
  List<AppNotification> inCategory(String c) => where((n) => n.categories.contains(c)).toList();
}

import 'common.dart';

abstract final class Severity {
  static const critical = 'Critical';
  static const high = 'High';
  static const medium = 'Medium';
  static const low = 'Low';

  static const all = [critical, high, medium, low];
}

abstract final class AlertStatus {
  static const newAlert = 'New';
  static const acknowledged = 'Acknowledged';
  static const resolved = 'Resolved';
}

class AlertItem {
  const AlertItem({
    required this.id,
    required this.type,
    required this.severity,
    required this.assetId,
    required this.message,
    required this.at,
    required this.location,
    this.status = AlertStatus.newAlert,
    this.threshold,
    this.value,
    this.reportedBy = 'System (IoT Sensor)',
    this.description = '',
    this.trend = const [],
    this.trendLabel,
    this.history = const [],
  });

  final String id;

  /// Low Battery, Maintenance Due, Temperature Out of Range …
  final String type;
  final String severity;
  final String assetId;
  final String message;
  final DateTime at;
  final String location;
  final String status;
  final String? threshold;
  final String? value;
  final String reportedBy;
  final String description;

  /// 24-hour trend (x = hours since midnight).
  final List<TrendPoint> trend;
  final String? trendLabel;
  final List<LogEntry> history;

  bool get requiresAction => status == AlertStatus.newAlert;

  AlertItem copyWith({String? status, List<LogEntry>? history}) => AlertItem(
    id: id,
    type: type,
    severity: severity,
    assetId: assetId,
    message: message,
    at: at,
    location: location,
    status: status ?? this.status,
    threshold: threshold,
    value: value,
    reportedBy: reportedBy,
    description: description,
    trend: trend,
    trendLabel: trendLabel,
    history: history ?? this.history,
  );
}

abstract final class NotificationCategory {
  static const system = 'System';
  static const workOrders = 'Work Orders';
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.message,
    required this.at,
    required this.categories,
    this.read = false,
    this.refType,
    this.refId,
  });

  final String id;

  /// Icon hint: lowBattery, woAssigned, maintenanceDue, temperature, assetMoved,
  /// woCompleted, vibration, stockLow, approval, issue, sync, audit, document.
  final String kind;
  final String title;
  final String message;
  final DateTime at;

  /// A notification can be in several categories (System, Work Orders).
  final Set<String> categories;
  final bool read;

  /// What tapping opens: alert, workOrder, asset, part, movement, issue …
  final String? refType;
  final String? refId;

  AppNotification copyWith({bool? read}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    message: message,
    at: at,
    categories: categories,
    read: read ?? this.read,
    refType: refType,
    refId: refId,
  );
}

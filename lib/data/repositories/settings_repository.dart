import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'alerts_repository.dart';
import 'assets_repository.dart';
import 'audits_repository.dart';
import 'documents_repository.dart';
import 'home_repository.dart';
import 'inspections_repository.dart';
import 'inventory_repository.dart';
import 'issues_repository.dart';
import 'maintenance_repository.dart';
import 'movements_repository.dart';
import 'network_repository.dart';
import 'scans_repository.dart';
import 'session_repository.dart';
import 'sync_repository.dart';
import 'tracking_repository.dart';
import 'wip_repository.dart';

/// Default tab of the Scan screen (Settings → Scanning). Names match `ScanMode`.
enum DefaultScanMode {
  qr('QR / Barcode'),
  nfc('NFC'),
  rfid('RFID'),
  ble('BLE');

  const DefaultScanMode(this.label);
  final String label;
}

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.light,
    this.scanMode = DefaultScanMode.qr,
    this.beep = true,
    this.vibrate = true,
    this.language = 'English',
  });

  /// Light / Dark / System (Settings → Appearance).
  final ThemeMode themeMode;
  final DefaultScanMode scanMode;

  /// Beep and vibrate when a scan is recognised.
  final bool beep;
  final bool vibrate;
  final String language;

  AppSettings copyWith({
    ThemeMode? themeMode,
    DefaultScanMode? scanMode,
    bool? beep,
    bool? vibrate,
    String? language,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    scanMode: scanMode ?? this.scanMode,
    beep: beep ?? this.beep,
    vibrate: vibrate ?? this.vibrate,
    language: language ?? this.language,
  );
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setThemeMode(ThemeMode m) => state = state.copyWith(themeMode: m);
  void setScanMode(DefaultScanMode m) => state = state.copyWith(scanMode: m);
  void setBeep(bool v) => state = state.copyWith(beep: v);
  void setVibrate(bool v) => state = state.copyWith(vibrate: v);
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

/// Developer → Reset demo data: every repository goes back to its seed (the user stays signed in).
void resetDemoData(WidgetRef ref) {
  for (final p in [
    assetsProvider,
    orgSummaryProvider,
    masterDataProvider,
    sessionRegistrationsProvider,
    workOrdersProvider,
    pmSchedulesProvider,
    inspectionsProvider,
    issuesProvider,
    alertsProvider,
    notificationsProvider,
    notificationSettingsProvider,
    inventoryProvider,
    movementsProvider,
    wipProvider,
    documentsProvider,
    auditsProvider,
    syncProvider,
    scanHistoryProvider,
    trackingProvider,
    peopleProvider,
    quickActionsProvider,
    recentAssetsProvider,
    networkProvider,
  ]) {
    ref.invalidate(p);
  }
}

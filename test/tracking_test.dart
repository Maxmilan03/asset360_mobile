import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/tracking/tracking_hub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

/// Opens [route] and returns the app's container.
Future<ProviderContainer> _open(WidgetTester tester, String route, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedIn.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
  c.read(routerProvider).go(route);
  await tester.pumpAndSettle();
  return c;
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('FL-012 drives its route there and back; zone changes log activity and history', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(trackingProvider.notifier);
    final start = c.read(trackingProvider);
    final v = start.vehicle('FL-012')!;
    expect(start.entityFor('FL-012')!.x, v.position!.x);
    final activity = start.activity.length;
    final seen = <String>{};
    for (var i = 0; i < v.loopLength; i++) {
      n.advance('FL-012');
      final s = c.read(trackingProvider);
      final p = s.vehicle('FL-012')!.position!;
      expect(s.entityFor('FL-012')!.x, p.x);
      seen.add(s.vehicle('FL-012')!.zone);
    }
    final end = c.read(trackingProvider);
    // A full loop returns to the start and visits Storage, Zone B and Dispatch.
    expect(end.vehicle('FL-012')!.routeIndex, v.routeIndex);
    expect(seen, containsAll(['Storage', 'Zone B', 'Dispatch']));
    expect(end.activity.length, greaterThan(activity));
    expect(end.zoneHistory('FL-012').first.entered, isTrue);
  });

  test('telemetry history ends at the current value and changes with the range', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final asset = c.read(assetsProvider).firstWhere((a) => a.id == 'FL-012');
    final metrics = metricsFor(asset, c.read(trackingProvider).vehicle('FL-012'));
    expect(metrics.map((m) => m.label), [
      'Battery Level',
      'Operating Hours',
      'Motor Temperature',
      'Voltage',
      'Current',
      'Load',
      'Speed',
      'Location',
      'Signal Strength',
    ]);
    expect(metrics[2].display, '42 °C');
    final battery = metrics.first;
    final day = telemetryHistory('FL-012', battery, TelemetryRange.day);
    final hour = telemetryHistory('FL-012', battery, TelemetryRange.hour);
    expect(day.last.value, 78);
    expect(hour.last.value, 78);
    expect(day.length, 49);
    expect(hour.length, 13);
    expect(day.every((p) => p.value >= 0 && p.value <= 100), isTrue);
    expect(telemetryHistory('FL-012', battery, TelemetryRange.day).map((p) => p.value), day.map((p) => p.value));

    final sensors = c.read(sensorsProvider);
    expect(sensors.firstWhere((s) => s.def.id == 'SN-T01').alert, isTrue); // cold room 12 °C > 8
    expect(sensors.firstWhere((s) => s.def.id == 'SN-B02').alert, isFalse); // FL-012 78 %
  });

  testWidgets('hub: counters, chips, callout → Asset Tracking; live sim moves FL-012', (tester) async {
    final c = await _open(tester, Routes.tracking);
    expect(find.text('Tracking & IoT'), findsOneWidget);
    expect(find.text('166'), findsOneWidget);
    expect(find.text('All Assets (178)'), findsOneWidget);
    expect(find.text('Equipment (142)'), findsOneWidget);
    expect(find.text('Forklift FL-012'), findsWidgets); // callout + activity

    final before = c.read(trackingProvider).vehicle('FL-012')!.routeIndex;
    await tester.pump(liveStep);
    expect(c.read(trackingProvider).vehicle('FL-012')!.routeIndex, before + 1);

    // People chip hides the forklift and its callout.
    await tester.tap(find.text('People (24)'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Forklift FL-012'), findsNothing);
    expect(find.bySemanticsLabel('Rakesh Kumar'), findsOneWidget);
    await tester.tap(find.text('All Assets (178)'));
    await tester.pumpAndSettle();

    // Alerts counter leaves only the alert pins.
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Tool Box TL-034'), findsOneWidget);
    expect(find.bySemanticsLabel('Rakesh Kumar'), findsNothing);
    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();

    // Tap a pin → its callout; the callout opens Asset Tracking.
    await tester.tap(find.bySemanticsLabel('Tool Box TL-034'));
    await tester.pumpAndSettle();
    expect(find.text('Unauthorized Area'), findsOneWidget);
    await tester.tap(find.text('Tool Box TL-034'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.trackAsset('TL-034'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Layers: switch People off.
    await tester.tap(find.byTooltip('Layers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('People'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Rakesh Kumar'), findsNothing);

    await tester.tap(find.byTooltip('Switch to 3D'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Switch to 2D'), findsOneWidget);
    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pumpAndSettle();
  });

  testWidgets('hub tabs: Asset List, Sensors → chart, Geofencing toggles and Add Zone', (tester) async {
    final c = await _open(tester, Routes.tracking);
    await tester.tap(find.text(HubTab.list.label));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('of 178 tracked'), findsOneWidget);
    await tester.tap(find.text('FL-012'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.path, Routes.trackAsset('FL-012'));

    c.read(routerProvider).go(Routes.trackingTab('sensors'));
    await tester.pumpAndSettle();
    expect(find.text('Cold Room Temperature'), findsOneWidget);
    await tester.ensureVisible(find.text('Cold Room Temperature'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cold Room Temperature'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.toString(), Routes.trackChart('CR-001', 'temperature'));
    expect(find.text('Now'), findsOneWidget);

    c.read(routerProvider).go(Routes.trackingTab('zones'));
    await tester.pumpAndSettle();
    expect(find.text('Admin Block – Restricted'), findsOneWidget);
    await tester.tap(find.text('Alert on entry').first);
    await tester.pumpAndSettle();
    expect(c.read(trackingProvider).geofences.first.alertOnEntry, isTrue);
    await tester.pump(const Duration(seconds: 5)); // let the SnackBar go
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Zone'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save Zone'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a zone name'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Loading Bay');
    final plan = tester.getRect(find.byKey(const ValueKey('zone-canvas')));
    await tester.dragFrom(plan.topLeft + const Offset(30, 30), const Offset(120, 90));
    await tester.pumpAndSettle();
    expect(find.textContaining('Zone covers'), findsOneWidget);
    await tester.tap(find.text('Save Zone'));
    await tester.pumpAndSettle();
    expect(c.read(trackingProvider).geofences.map((g) => g.name), contains('Loading Bay'));
  });

  testWidgets('Asset Tracking FL-012: tiles, tabs, telemetry range, history playback, WO', (tester) async {
    final c = await _open(tester, Routes.trackAsset('FL-012'));
    expect(find.text('Asset Tracking'), findsOneWidget);
    expect(find.text('Assigned to: Rakesh Kumar'), findsOneWidget);
    expect(find.text('Loaded'), findsOneWidget);
    expect(find.text('-62 dBm'), findsOneWidget);
    expect(find.textContaining('Last Updated:'), findsOneWidget);

    await tester.drag(find.byType(ListView).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('View History'));
    await tester.pumpAndSettle();
    expect(find.text('Route History · FL-012'), findsOneWidget);
    await tester.tap(find.byTooltip('Play'));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Pause'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(20, 60));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView).first, const Offset(0, 600));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Telemetry'));
    await tester.tap(find.text('Telemetry'));
    await tester.pumpAndSettle();
    expect(find.text('Motor Temperature'), findsOneWidget);
    expect(find.text('42 °C'), findsOneWidget);
    expect(find.text('Battery Level (%)'), findsOneWidget);
    await tester.tap(find.text('Voltage'));
    await tester.pumpAndSettle();
    expect(find.text('Voltage (V)'), findsOneWidget);
    await tester.tap(find.text('Last 24 Hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Last 7 Days').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View All'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.toString(), Routes.trackChart('FL-012', 'voltage', range: 'week'));
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    for (final tab in ['History', 'Geofence', 'Details']) {
      await tester.ensureVisible(find.text(tab));
      await tester.tap(find.text(tab));
      await tester.pumpAndSettle();
    }
    expect(find.text('Open Asset 360°'), findsOneWidget);
    await tester.ensureVisible(find.text('Geofence'));
    await tester.tap(find.text('Geofence'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Admin Block – Restricted'));
    await tester.pumpAndSettle();
    expect(c.read(trackingProvider).isAllowed('FL-012', 'GF-03'), isTrue);
    await tester.pump(const Duration(seconds: 5)); // let the SnackBar go
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Live Tracking'));
    await tester.tap(find.text('Live Tracking'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Create Work Order'));
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create Work Order'));
    await tester.pumpAndSettle();
    expect(c.read(routerProvider).state.uri.toString(), Routes.createWorkOrder(assetId: 'FL-012'));
  });

  for (final (name, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$name phone: every tracking screen and tab lays out without overflow', (tester) async {
      final c = await _open(tester, Routes.tracking, size: size);
      final router = c.read(routerProvider);
      for (final route in [
        for (final t in HubTab.values) Routes.trackingTab(t.name),
        for (final t in ['live', 'details', 'telemetry', 'history', 'geofence']) Routes.trackAsset('FL-012', tab: t),
        Routes.trackAsset('CNC-00123', tab: 'telemetry'),
        Routes.trackAsset('CAB-011'),
        Routes.trackChart('FL-012', 'battery'),
        Routes.trackingActivity,
        Routes.addGeofence,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
      // Add Zone with the keyboard up: the form scrolls instead of overflowing.
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * .42);
      addTearDown(tester.view.resetViewInsets);
      await tester.showKeyboard(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'Add Zone with keyboard');
    });
  }
}

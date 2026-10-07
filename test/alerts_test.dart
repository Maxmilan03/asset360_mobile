import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/models/alert.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/maintenance_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/more/alerts/alerts_screen.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _alt = 'ALT-2026-0245';

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

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Scrolls the page until the tab [label] is built and visible, then taps it.
Future<void> _showTab(WidgetTester tester, String label) async {
  final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
  await tester.scrollUntilVisible(find.text(label), 150, scrollable: page);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).first);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => DemoClock.frozen = true);

  test('counts, live alerts, history / related, and critical issues create alerts', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final alerts = c.read(alertsProvider);
    expect(alerts.length, 45);
    expect([for (final s in Severity.all) alerts.withSeverity(s).length], [8, 12, 18, 7]);
    expect(c.read(unreadNotificationCountProvider), 12);

    final low = alerts.firstWhere((a) => a.id == _alt);
    expect(alerts.earlierOf(low).every((a) => a.type == 'Low Battery' && a.assetId == 'FL-015'), isTrue);
    expect(alerts.relatedTo(low).every((a) => a.location == low.location && a.assetId != 'FL-015'), isTrue);

    c.read(alertsProvider.notifier).raiseLive();
    expect(c.read(alertsProvider).length, 46);
    expect(c.read(unreadNotificationCountProvider), 13);

    c
        .read(issuesProvider.notifier)
        .report(
          assetId: 'GEN-00045',
          title: 'Fuel leak',
          type: 'Leakage',
          priority: 'Critical',
          description: 'Diesel dripping from the return line.',
          location: 'Main Plant / Building A',
        );
    expect(c.read(alertsProvider).latest.first.type, 'Critical Issue Reported');
    expect(c.read(unreadNotificationCountProvider), 14);
  });

  testWidgets('Alerts: tiles pick tabs, swipe acknowledges, multi-select resolves, live banner', (tester) async {
    final c = await _open(tester, Routes.alerts);
    expect(find.text('All (45)'), findsOneWidget);
    await _tap(tester, find.text('Critical').first);
    expect(find.text('Critical (8)'), findsOneWidget);
    expect(find.text('Maintenance Due'), findsNothing);

    // Swipe left on the Low Battery alert → acknowledged.
    await tester.drag(find.text('Low Battery').first, const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(alertByIdProvider(_alt))!.status, AlertStatus.acknowledged);

    // Long-press → select two → Resolve.
    await tester.longPress(find.text('Low Battery').first);
    await tester.pumpAndSettle();
    await _tap(tester, find.text('High Temperature').first);
    expect(find.text('2 selected'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // the swipe's SnackBar goes away
    await tester.pumpAndSettle();
    await _tap(tester, find.widgetWithText(FilledButton, 'Resolve'));
    expect(c.read(alertByIdProvider(_alt))!.status, AlertStatus.resolved);
    expect(c.read(alertByIdProvider('ALT-2026-0244'))!.status, AlertStatus.resolved);

    // A live alert arrives after 60 s: banner + bell badge.
    final unread = c.read(unreadNotificationCountProvider);
    for (var s = 0; s <= liveAlertEvery.inSeconds && find.textContaining('New high alert').evaluate().isEmpty; s++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(find.textContaining('New high alert'), findsOneWidget);
    expect(c.read(unreadNotificationCountProvider), unread + 1);
    await tester.pump(const Duration(seconds: 9));
    await tester.pumpAndSettle();
  });

  testWidgets('Alert Details: reading, Acknowledge → Resolve, Create Work Order links the alert', (tester) async {
    final c = await _open(tester, Routes.alertDetail(_alt));
    expect(find.text('Battery Level'), findsOneWidget);
    expect(find.text('18%'), findsOneWidget);
    expect(find.textContaining('10:25 AM (alert time)'), findsOneWidget);

    await _tap(tester, find.text('Acknowledge'));
    await tester.enterText(find.byType(TextField), 'Charger connected');
    await _tap(tester, find.widgetWithText(FilledButton, 'Acknowledge'));
    expect(c.read(alertByIdProvider(_alt))!.status, AlertStatus.acknowledged);
    expect(find.text('Resolve'), findsOneWidget);

    await _tap(tester, find.text('Actions'));
    expect(find.textContaining('Charger connected'), findsOneWidget);

    await _tap(tester, find.text('Create Work Order'));
    final wos = c.read(workOrdersProvider).length;
    await _tap(tester, find.widgetWithText(FilledButton, 'Create Work Order'));
    expect(c.read(workOrdersProvider).length, wos + 1);
    expect(c.read(alertByIdProvider(_alt))!.workOrderId, isNotNull);
  });

  testWidgets('Notifications: bell opens it, tap marks read and deep-links, mark all, delete + undo', (tester) async {
    final c = await _open(tester, Routes.home);
    await _tap(tester, find.byTooltip('Notifications'));
    expect(find.text('Unread (12)'), findsOneWidget);

    await _tap(tester, find.text('Low Battery Alert'));
    expect(c.read(unreadNotificationCountProvider), 11);
    expect(c.read(routerProvider).state.uri.path, Routes.alertDetail(_alt));
    await _tap(tester, find.byTooltip('Back'));
    expect(c.read(notificationsProvider).unread.length, 11);

    final total = c.read(notificationsProvider).length;
    await tester.drag(find.text('Low Battery Alert'), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(c.read(notificationsProvider).length, total - 1);
    await _tap(tester, find.text('Undo'));
    expect(c.read(notificationsProvider).length, total);

    await tester.drag(find.byWidgetPredicate((w) => w is ScrollView).first, const Offset(0, 800));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip('More options'));
    await _tap(tester, find.text('Mark all as read'));
    expect(c.read(unreadNotificationCountProvider), 0);

    await _tap(tester, find.byTooltip('More options'));
    await _tap(tester, find.text('Notification settings'));
    await _tap(tester, find.text('Stock levels'));
    expect(c.read(notificationSettingsProvider).isOn('stock'), isFalse);
  });

  for (final (label, size) in [('small 360x640', const Size(1080, 1920)), ('large 430x932', const Size(1290, 2796))]) {
    testWidgets('$label phone: alert screens lay out without overflow', (tester) async {
      final c = await _open(tester, Routes.alerts, size: size);
      for (final route in [
        Routes.alerts,
        Routes.alertDetail(_alt),
        Routes.alertDetail('ALT-2026-0242'),
        Routes.notificationsFrom(Routes.more),
        Routes.notificationSettingsFrom(Routes.more),
      ]) {
        c.read(routerProvider).go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
        if (!route.startsWith(Routes.alertDetail(''))) continue;
        for (final t in ['History', 'Actions', 'Related Assets', 'Details']) {
          await _showTab(tester, t);
          expect(tester.takeException(), isNull, reason: '$route · $t');
        }
      }
    });
  }
}

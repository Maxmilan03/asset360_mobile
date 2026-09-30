import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pumpApp(WidgetTester tester, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(SignedInSession.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
}

/// Starts the app already signed in (with "Remember me"), so the splash goes to Home.
class SignedInSession extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Finder _navLabel(String label) => find.bySemanticsLabel(label);

void main() {
  testWidgets('bottom bar switches between all five tabs', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Home'), findsWidgets);

    await tester.tap(_navLabel('Assets'));
    await tester.pumpAndSettle();
    expect(find.text('Search, scan or filter assets'), findsOneWidget);

    await tester.tap(_navLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Identify'), findsOneWidget);

    await tester.tap(_navLabel('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Your work orders, inspections, issues and operations'), findsOneWidget);

    await tester.tap(_navLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('Modules, account and app settings'), findsOneWidget);
  });

  testWidgets('every Work hub tile opens its module and back returns', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_navLabel('Work'));
    await tester.pumpAndSettle();

    const modules = {
      'Maintenance': 'Manage work orders, preventive maintenance and asset service',
      'Inspection': 'Conduct inspections, checklists and compliance',
      'Issues / Defects': 'Report, track and resolve asset issues',
      'WIP / Operations': 'Track production orders and units through each station',
      'Movement & Custody': 'Transfer, assign and track asset movement',
      'Asset Audit': 'Verify assets physically against the register',
    };
    for (final entry in modules.entries) {
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget, reason: entry.key);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Your work orders, inspections, issues and operations'), findsOneWidget);
    }
  });

  testWidgets('every More item navigates', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_navLabel('More'));
    await tester.pumpAndSettle();

    const items = {
      'Tracking & IoT': 'Real-time location, sensors and telemetry',
      'Inventory / Spare Parts': 'Manage stock, spare parts and consumables',
      'Documents': 'Manuals, certificates, warranties and reports',
      'Asset Registration': 'Register a new asset in the system',
      'Alerts & Notifications': 'Monitor alarms, thresholds and messages',
      'Offline Sync': 'Work offline and sync your changes later',
      'Profile': 'Your details, role and password',
      'Settings': 'Language, notifications and preferences',
      'Help & Support': 'FAQs, contact support and report a bug',
    };
    for (final entry in items.entries) {
      await tester.scrollUntilVisible(find.text(entry.key), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text(entry.key));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsWidgets, reason: entry.key);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
    }

    await tester.scrollUntilVisible(find.text('Logout'), 100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to log out of Asset360?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('header bell and avatar open Notifications and Profile in the current tab', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_navLabel('Work'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('Stay updated with alerts and messages'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('Your details, role and password'), findsOneWidget);
  });

  testWidgets('small 360 dp phone lays out every tab without overflow', (tester) async {
    await _pumpApp(tester, size: const Size(1080, 2220));
    for (final tab in ['Assets', 'Scan', 'Work', 'More', 'Home']) {
      await tester.tap(_navLabel(tab));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
  });

  testWidgets('More → Settings → Developer → Data check shows all checks passing', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_navLabel('More'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Logout'), 100, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Data check'));
    await tester.pumpAndSettle();
    expect(find.text('All checks passed'), findsOneWidget);
    expect(find.text('Assets'), findsWidgets);
  });

  testWidgets('bell badge shows the unread notification count', (tester) async {
    await _pumpApp(tester);
    expect(find.text('12'), findsWidgets);
  });
}

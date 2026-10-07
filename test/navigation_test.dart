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

    // Scan opens on top of the current screen; back returns there.
    await tester.tap(_navLabel('Scan'));
    await tester.pumpAndSettle();
    expect(find.text('Scan & Identify'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Search, scan or filter assets'), findsOneWidget);

    await tester.tap(_navLabel('Work'));
    await tester.pumpAndSettle();
    expect(find.text('Your work orders, inspections, issues and operations'), findsOneWidget);

    // More opens the All Modules sheet over the current screen; ✕ closes it.
    await tester.tap(_navLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('All Modules'), findsOneWidget);
    expect(find.text('Your work orders, inspections, issues and operations'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('All Modules'), findsNothing);
  });

  testWidgets('every Work hub tile opens its module and back returns', (tester) async {
    await _pumpApp(tester);
    await tester.tap(_navLabel('Work'));
    await tester.pumpAndSettle();

    const modules = {
      'Maintenance': 'Manage work orders, preventive maintenance and asset service',
      'Inspection': 'Conduct inspections, checklists and compliance',
      'Issues / Defects': 'Report and track asset issues, breakdowns and incidents',
      'WIP / Operations': 'Track production flow, WIP assets and operations in real-time',
      'Movement & Custody': 'Transfer, assign and track asset movement',
      'Asset Audit': 'Physical verification and reconciliation of assets',
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

  testWidgets('every All Modules tile navigates, keeps the bar, and Logout confirms', (tester) async {
    await _pumpApp(tester);
    const items = {
      'Assets': 'Search, scan or filter assets',
      'Tracking & IoT': 'Real-time location, telemetry and asset monitoring',
      'Movement & Custody': 'Transfer, assign and track asset movement',
      'Maintenance': 'Manage work orders, preventive maintenance and asset service',
      'Inspection': 'Conduct inspections, checklists and compliance',
      'Inventory': 'Manage spare parts, stock levels and procurement',
      'WIP / Operations': 'Track production flow, WIP assets and operations in real-time',
      'Audit & Compliance': 'Physical verification and reconciliation of assets',
      'Contracts & Warranty': 'Warranties and maintenance contracts',
      'Financial': 'Costs, asset value and depreciation',
      'Reports & Analytics': 'Charts and exports for every module',
      'Administration': 'Users, roles, sites and master data',
      'Issues / Defects': 'Report and track asset issues, breakdowns and incidents',
      'Alerts & Notifications': 'Stay updated with real-time asset events and actions',
      'Documents': 'Manage all asset related documents and files',
      'Asset Registration': 'Register a new asset in the system',
      'Offline Sync': 'Work offline and sync your data when connected',
      'Profile': 'Your details, role and password',
      'Settings': 'Appearance, notifications and preferences',
      'Help & Support': 'FAQs, contact support and report a bug',
      'Dashboard': 'Quick Actions',
    };
    final sheetScroll = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable));
    for (final entry in items.entries) {
      await tester.tap(_navLabel('More'));
      await tester.pumpAndSettle();
      final tile = find.descendant(of: find.byType(BottomSheet), matching: find.text(entry.key));
      await tester.scrollUntilVisible(tile, 120, scrollable: sheetScroll.first);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing, reason: entry.key);
      expect(find.text(entry.value), findsWidgets, reason: entry.key);
      expect(_navLabel('Scan'), findsOneWidget, reason: entry.key);
      expect(tester.takeException(), isNull, reason: entry.key);
    }

    await tester.tap(_navLabel('More'));
    await tester.pumpAndSettle();
    final logout = find.descendant(of: find.byType(BottomSheet), matching: find.text('Logout'));
    await tester.scrollUntilVisible(logout, 120, scrollable: sheetScroll.first);
    await tester.tap(logout);
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
    expect(find.text('All your recent asset related notifications'), findsOneWidget);
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
    final settings = find.descendant(of: find.byType(BottomSheet), matching: find.text('Settings'));
    await tester.scrollUntilVisible(
      settings,
      120,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
    );
    await tester.tap(settings);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Data check'), 300, scrollable: find.byType(Scrollable).first);
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

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/feature_flags.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Starts the app already signed in (with "Remember me"), so the splash goes to Home.
class _SignedInSession extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

Future<ProviderContainer> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(overrides: [sessionProvider.overrideWith(_SignedInSession.new)], child: const Asset360App()),
  );
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(Asset360App)));
}

String _location(ProviderContainer c) => c.read(routerProvider).routerDelegate.currentConfiguration.uri.path;

void main() {
  testWidgets('client demo: Home is inert, More shows 13 inert tiles + Logout', (tester) async {
    final c = await _pumpApp(tester);
    expect(_location(c), '/home');

    // Inert controls: nothing navigates and no SnackBar appears.
    for (final f in [
      find.text('Work Orders').first,
      find.text('Customize'),
      find.bySemanticsLabel('Assets'),
      find.bySemanticsLabel('Work'),
      find.byTooltip('Notifications'),
    ]) {
      await tester.tap(f, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(_location(c), '/home');
      expect(find.byType(SnackBar), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    }

    await tester.tap(find.bySemanticsLabel('More'));
    await tester.pumpAndSettle();
    expect(find.text('All Modules'), findsOneWidget);
    expect(find.text('Administration'), findsOneWidget);
    expect(find.text('Offline Sync'), findsNothing); // the "More" grid is hidden
    await tester.tap(find.text('Maintenance').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('All Modules'), findsOneWidget);
    expect(_location(c), '/home');

    // Logout row → confirm → Login.
    final logout = find.descendant(of: find.byType(BottomSheet), matching: find.text('Logout'));
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    await tester.tap(logout);
    await tester.pumpAndSettle();
    expect(find.text('Are you sure you want to log out of Asset360?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(_location(c), '/login');
  }, skip: !kClientDemo);
}

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _start(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ProviderScope(child: Asset360App()));
  expect(find.text('Asset360'), findsOneWidget); // splash
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
}

/// The code screen has a blinking cursor, so pumpAndSettle would never finish.
Future<void> _frames(WidgetTester tester, [int ms = 1200]) async {
  for (var t = 0; t < ms; t += 100) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _field(String hint) => find.widgetWithText(TextFormField, hint);

Future<void> _signIn(WidgetTester tester, String user, String pass) async {
  await tester.enterText(_field('Username'), user);
  await tester.enterText(_field('Password'), pass);
  await tester.tap(find.text('Sign In'));
  await _frames(tester);
}

void main() {
  testWidgets('splash → login; empty fields show inline errors', (tester) async {
    await _start(tester);
    expect(find.text('Access your assets, operations and insights'), findsOneWidget);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your username or email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('full path: login → authenticator (wrong code, then 123456) → Home', (tester) async {
    await _start(tester);
    await _signIn(tester, 'rex.kumar', 'Asset@360');
    expect(find.text('Enter Authenticator Code'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '111111');
    await _frames(tester);
    expect(find.text('Invalid code. 4 attempts left'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '123456');
    await _frames(tester);
    expect(find.byTooltip('Notifications'), findsOneWidget); // Home header
  });

  testWidgets('email login works; wrong password shows error; 5 wrong tries lock for 30 s', (tester) async {
    await _start(tester);
    await _signIn(tester, 'rex.kumar', 'wrong');
    expect(find.textContaining('Invalid username or password'), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await _signIn(tester, 'rex.kumar', 'wrong');
    }
    expect(find.text('Try again in 30s'), findsOneWidget);
    for (var i = 0; i < 31; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    await _signIn(tester, 'REX.KUMAR@purpleiq.ae', 'Asset@360');
    expect(find.text('Enter Authenticator Code'), findsOneWidget);
  });

  testWidgets('5 wrong codes return to Login with a message', (tester) async {
    await _start(tester);
    await _signIn(tester, 'rex.kumar', 'Asset@360');
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField).last, '000000');
      await _frames(tester);
    }
    expect(find.text('Too many invalid codes. Please sign in again.'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Google sign-in shows the connecting dialog then the code screen', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Sign in with Google'));
    await tester.pump();
    expect(find.text('Connecting to Google…'), findsOneWidget);
    await _frames(tester, 2200);
    expect(find.text('Enter Authenticator Code'), findsOneWidget);
  });

  testWidgets('forgot password validates email and shows the success sheet', (tester) async {
    await _start(tester);
    await tester.tap(find.text('Forgot Username or Password?'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'not-an-email');
    await tester.tap(find.text('Send Instructions'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address'), findsOneWidget);

    await tester.tap(find.text('Recover my username'));
    await tester.enterText(find.byType(TextFormField), 'rex.kumar@purpleiq.ae');
    await tester.tap(find.text('Send Instructions'));
    await tester.pump(const Duration(milliseconds: 1200));
    await tester.pumpAndSettle();
    expect(find.text('Check your inbox'), findsOneWidget);
    expect(find.textContaining('r***@purpleiq.ae'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Back to Login'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('admin contact sheet and language picker', (tester) async {
    await _start(tester);
    await tester.ensureVisible(find.textContaining('Contact your administrator'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Contact your administrator'));
    await tester.pumpAndSettle();
    expect(find.text('admin@purpleiq.ae'), findsOneWidget);
    expect(find.text('+971 4 000 0000'), findsOneWidget);
    await tester.tap(find.text('Copy').first);
    await tester.pump();
    expect(find.text('Email copied'), findsOneWidget);
    Navigator.of(tester.element(find.text('admin@purpleiq.ae'))).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('English'), -100, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('العربية'));
    await tester.pumpAndSettle();
    expect(find.text('Arabic will be available in a later release'), findsOneWidget);
  });
}

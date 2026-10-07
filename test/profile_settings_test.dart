import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/repositories/home_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/settings_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:asset360_mobile/features/more/account/help_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _small = Size(1080, 1920); // 360 x 640 dp
const _large = Size(1290, 2796); // 430 x 932 dp

/// Starts the app signed in and returns its container (disposed on tear-down).
Future<ProviderContainer> _start(WidgetTester tester, {Size size = const Size(1170, 2532)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
  _container = c;
  await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const Asset360App()));
  await tester.pump(SplashScreen.duration);
  await tester.pumpAndSettle();
  return c;
}

ProviderContainer? _container;

/// testWidgets that unmounts the app and disposes the container at the end (stops the
/// clock / live timers before the binding checks for pending timers).
void _testApp(String description, Future<void> Function(WidgetTester tester) body) {
  testWidgets(description, (tester) async {
    await body(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    _container?.dispose();
    _container = null;
  });
}

Future<void> _go(WidgetTester tester, ProviderContainer c, String path) async {
  c.read(routerProvider).go(path);
  await tester.pumpAndSettle();
}

/// The page's main vertical list (the AppScaffold body).
Finder get _page => find.byType(Scrollable).first;

/// Scrolls [f] into view (to the top of the page, clear of the bottom bar) and taps it.
Future<void> _tap(WidgetTester tester, Finder f, {bool settle = true}) async {
  if (f.evaluate().isEmpty) await tester.scrollUntilVisible(f, 200, scrollable: _page);
  await tester.ensureVisible(f);
  // A SnackBar from the previous step can sit over the target.
  for (final m in tester.stateList<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))) {
    m.removeCurrentSnackBar();
  }
  await tester.pumpAndSettle();
  await tester.tap(f);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

/// Captures Clipboard.setData calls.
String? _clipboard;
void _mockClipboard(WidgetTester tester) {
  _clipboard = null;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') _clipboard = (call.arguments as Map)['text'] as String?;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
}

void main() {
  setUp(() => DemoClock.frozen = true);

  const screens = [
    Routes.work,
    Routes.more,
    '/more/${Routes.profileSegment}',
    Routes.settings,
    Routes.dataCheck,
    Routes.demoTags,
    Routes.help,
    Routes.reportBug,
    Routes.contracts,
    Routes.financial,
    Routes.reports,
    '/more/reports/maintenance',
    '/more/reports/asset-status',
    Routes.admin,
    '${Routes.admin}?tab=roles',
    '${Routes.admin}?tab=sites',
    '${Routes.admin}?tab=master',
    '/more/admin/users/rex',
  ];

  for (final (name, size) in [('small 360x640', _small), ('large 430x932', _large)]) {
    _testApp('$name: profile, settings, help and More screens lay out without overflow', (tester) async {
      final c = await _start(tester, size: size);
      for (final p in screens) {
        await _go(tester, c, p);
        expect(tester.takeException(), isNull, reason: p);
        // Scroll to the end so lazily built rows are laid out too.
        final lists = find.byType(Scrollable);
        if (lists.evaluate().isNotEmpty) {
          await tester.fling(lists.first, const Offset(0, -4000), 4000);
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull, reason: '$p (scrolled)');
      }
    });
  }

  _testApp('Change Password: wrong current rejected, rules enforced, Asset@360 accepted', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, '/more/${Routes.profileSegment}');
    expect(find.text('Rex Kumar'), findsWidgets);
    await _tap(tester, find.text('Change Password'));

    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField));
    Future<void> submit() async {
      await tester.tap(find.text('Update Password'));
      await tester.pumpAndSettle();
    }

    await tester.enterText(fields.at(0), 'wrong-pass');
    await tester.enterText(fields.at(1), 'NewPass#2026');
    await tester.enterText(fields.at(2), 'NewPass#2026');
    await submit();
    expect(find.text('The current password is not correct'), findsOneWidget);

    await tester.enterText(fields.at(0), 'Asset@360');
    await tester.enterText(fields.at(1), 'weakpass');
    await tester.enterText(fields.at(2), 'weakpass');
    await submit();
    expect(find.text('The password does not meet every rule'), findsOneWidget);
    expect(find.text('Weak'), findsOneWidget);

    await tester.enterText(fields.at(1), 'NewPass#2026');
    await tester.enterText(fields.at(2), 'NewPass#2027');
    await submit();
    expect(find.text('The passwords do not match'), findsOneWidget);

    await tester.enterText(fields.at(2), 'NewPass#2026');
    await tester.pump();
    expect(find.text('Strong'), findsOneWidget);
    await submit();
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.textContaining('Password changed'), findsOneWidget);
    expect(c.read(sessionProvider).password, 'NewPass#2026');
  });

  _testApp('Edit Profile saves the name; Logout confirms and returns to Sign In', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, '/more/${Routes.profileSegment}');
    await _tap(tester, find.text('Edit Profile'));
    final fields = find.descendant(of: find.byType(BottomSheet), matching: find.byType(TextFormField));
    await tester.enterText(fields.at(0), 'Rex K. Kumar');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Profile updated'), findsOneWidget);
    expect(find.text('Rex K. Kumar'), findsWidgets);

    final logout = find.ancestor(of: find.text('Logout'), matching: find.bySubtype<OutlinedButton>());
    await _tap(tester, logout);
    expect(find.text('Are you sure you want to log out of Asset360?'), findsOneWidget);
    // Cancel keeps the session.
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(c.read(sessionProvider).loggedIn, isTrue);

    await _tap(tester, logout);
    await tester.tap(find.widgetWithText(FilledButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
    expect(c.read(sessionProvider).loggedIn, isFalse);
  });

  _testApp('Settings: Dark theme uses navy background and #1E1A3A cards; Arabic is coming soon', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, Routes.settings);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).themeMode, ThemeMode.dark);
    expect(Theme.of(tester.element(find.text('Appearance'.toUpperCase()))).brightness, Brightness.dark);
    expect(AppColors.surface, const Color(0xFF1E1A3A));
    expect(AppColors.headerTop, const Color(0xFF2B1270)); // purple header kept
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(c.read(appSettingsProvider).themeMode, ThemeMode.light);
    expect(AppColors.surface, Colors.white);

    await _tap(tester, find.text('العربية'), settle: false);
    expect(find.text('Arabic (العربية) is coming soon'), findsOneWidget);
    expect(c.read(appSettingsProvider).language, 'English');
  });

  _testApp('Settings toggles and Developer → Reset demo data (confirm) reloads the seed', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, Routes.settings);

    final beep = c.read(appSettingsProvider).beep;
    await _tap(tester, find.text('Beep on scan'));
    expect(c.read(appSettingsProvider).beep, !beep);

    final people = c.read(peopleProvider);
    final p = people.first;
    c.read(peopleProvider.notifier).update(p.copyWith(role: 'Changed Role'));
    expect(c.read(peopleProvider).first.role, 'Changed Role');

    await _tap(tester, find.text('Reset demo data'));
    expect(find.text('Reset demo data?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Demo data reset'), findsOneWidget);
    expect(c.read(peopleProvider).first.role, p.role);
    expect(c.read(sessionProvider).loggedIn, isTrue);
  });

  _testApp('Help: FAQ search filters, empty state clears, copy buttons copy', (tester) async {
    _mockClipboard(tester);
    final c = await _start(tester);
    await _go(tester, c, Routes.help);
    expect(find.text('Frequently Asked Questions (${helpFaqs.length})'), findsOneWidget);
    expect(helpFaqs.length, 8);

    final offline = helpFaqs.where((f) => '${f.$1} ${f.$2}'.toLowerCase().contains('offline')).length;
    await tester.enterText(find.byType(TextField).first, 'offline');
    await tester.pumpAndSettle();
    expect(find.text('Frequently Asked Questions ($offline)'), findsOneWidget);
    expect(offline, lessThan(helpFaqs.length));

    // Accordion opens.
    final q = helpFaqs.firstWhere((f) => '${f.$1} ${f.$2}'.toLowerCase().contains('offline'));
    await _tap(tester, find.text(q.$1));
    expect(find.text(q.$2), findsOneWidget);

    await tester.fling(_page, const Offset(0, 3000), 3000); // back to the search field
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pumpAndSettle();
    expect(find.text('No answers found'), findsOneWidget);
    await _tap(tester, find.text('Clear search'));
    expect(find.text('Frequently Asked Questions (${helpFaqs.length})'), findsOneWidget);

    await _tap(tester, find.byTooltip('Copy Email'), settle: false);
    expect(_clipboard, supportEmail);
    await _tap(tester, find.byTooltip('Copy Phone'), settle: false);
    expect(_clipboard, supportPhone);
    expect(find.text('Phone copied: $supportPhone'), findsOneWidget);
  });

  _testApp('Report a bug validates and shows the success sheet', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, Routes.help);
    await _tap(tester, find.text('Report a bug'));
    expect(find.text('Attach Screenshot'), findsOneWidget);

    await tester.tap(find.text('Send Report'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the problem in a few words'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'Sync stops at 50%');
    await _tap(tester, find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.text('Offline Sync').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Send Report'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Bug report sent'), findsOneWidget);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    // Back on Help & Support (scrolled to the Report a bug card).
    expect(find.text('Send Report'), findsNothing);
    expect(find.text('Report a bug'), findsOneWidget);
  });

  _testApp('Work hub My Tasks shows the same tasks as Home', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, Routes.work);
    final home = c.read(homeDataProvider);
    await tester.scrollUntilVisible(find.text('All (${home.allTasks.length})'), 200, scrollable: _page);
    expect(find.text('Work Orders (${home.workOrderTasks.length})'), findsOneWidget);
    expect(find.text('No tasks to show yet'), findsNothing);
  });

  _testApp('Reports: Export → Copy summary copies the report figures', (tester) async {
    _mockClipboard(tester);
    final c = await _start(tester);
    await _go(tester, c, '/more/reports/maintenance');
    await tester.tap(find.byTooltip('Export'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy summary'));
    await tester.pumpAndSettle();
    expect(_clipboard, contains('Active WOs'));
    expect(find.textContaining('summary copied'), findsOneWidget);
  });

  _testApp('Contracts filter chips filter the list', (tester) async {
    final c = await _start(tester);
    await _go(tester, c, Routes.contracts);
    final expired = find.textContaining(RegExp(r'^Expired \(\d+\)$'));
    expect(expired, findsOneWidget);
    await tester.tap(expired);
    await tester.pumpAndSettle();
    expect(find.text('Active'), findsNothing); // no Active status chips in the Expired filter
    expect(tester.takeException(), isNull);
  });
}

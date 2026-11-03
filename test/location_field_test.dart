import 'package:asset360_mobile/core/scanning/hardware_scan_listener.dart';
import 'package:asset360_mobile/core/scanning/scan_dispatch.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A form with a LocationField and an asset field, under the HHT listener (keyboard mode).
class _Form extends StatefulWidget {
  const _Form();

  @override
  State<_Form> createState() => _FormState();
}

class _FormState extends State<_Form> {
  LocationValue value = LocationValue.empty;
  String? asset;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Text('Asset: ${asset ?? '-'}'),
      LocationField(
        value: value,
        onChanged: (v) => setState(() => value = v),
        onAsset: (id) => setState(() => asset = id),
      ),
      Text('Path: ${value.path ?? '-'}'),
    ],
  );
}

final _nav = GlobalKey<NavigatorState>();
var _now = DateTime(2026, 10, 12, 9);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final c = ProviderContainer(
    overrides: [
      // Controllable clock for the 2-second duplicate guard.
      scanServiceProvider.overrideWith(
        (ref) => ScanService(
          ref.watch(appDatabaseProvider),
          clock: () => _now,
          findAsset: (code) => switch (ref.read(assetsProvider).byCode(code)) {
            final a? => (id: a.id, label: '${a.id} – ${a.name}'),
            null => null,
          },
        ),
      ),
    ],
  );
  addTearDown(c.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        navigatorKey: _nav,
        home: HardwareScanListener(
          navigatorContext: () => _nav.currentContext,
          child: const Scaffold(body: _Form()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return c;
}

/// A keyboard-wedge scanner: characters back to back, then Enter.
Future<void> _wedge(WidgetTester tester, String code) async {
  for (final ch in code.split('')) {
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA, character: ch);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _now = DateTime(2026, 10, 12, 9));
  tearDown(() async {
    await _nav.currentState?.maybePop();
  });

  testWidgets('HHT trigger on a form: a LOC: label fills Site / Building / Floor; an asset tag fills the asset', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('Path: -'), findsOneWidget);

    await _wedge(tester, 'LOC:BLD-A-F2');
    expect(find.text('Path: Building A / Floor 2'), findsOneWidget);
    expect(find.text('Dubai Factory'), findsOneWidget);
    expect(find.text('Location filled from tag: Floor 2 – Building A'), findsOneWidget);

    // A room label fills all four levels.
    _now = _now.add(const Duration(seconds: 3));
    await _wedge(tester, 'LOC:BLD-B-GF-WORK');
    expect(find.text('Path: Building B / Ground Floor – Workshop'), findsOneWidget);

    _now = _now.add(const Duration(seconds: 3));
    await _wedge(tester, 'CNC-00123');
    expect(find.text('Asset: CNC-00123'), findsOneWidget);
  });

  testWidgets('unknown tag → Link to a location → the form fills; the same tag then resolves instantly', (
    tester,
  ) async {
    final c = await _pump(tester);
    await _wedge(tester, 'TAG-777');
    expect(find.text("This tag isn't linked yet"), findsOneWidget);
    expect(find.text('TAG-777'), findsOneWidget);
    await tester.tap(find.text('Link to a location'));
    await tester.pumpAndSettle();
    expect(find.text('Site › Building › Floor › Room (optional)'), findsOneWidget);
    // The sheet's dropdowns come after the form's.
    for (final option in ['Dubai Factory', 'Building A', 'Floor 2']) {
      await tester.tap(find.text('Select').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text(option).last);
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Path: Building A / Floor 2'), findsOneWidget);

    final link = (await tester.runAsync(() => c.read(appDatabaseProvider).linkByKey('TAG-777')))!;
    expect((link.targetType, link.targetId, link.label), (LinkTarget.location, 'BLD-A-F2', 'Floor 2 – Building A'));
    final saved = (await tester.runAsync(() => c.read(appDatabaseProvider).watchScans().first))!;
    expect(
      (saved.single.value, saved.single.matchType, saved.single.source),
      ('TAG-777', MatchType.location, ScanSource.hht),
    );

    // Within 2 s the same read is ignored; afterwards it resolves through the link, no sheet.
    await _wedge(tester, 'TAG-777');
    expect((await tester.runAsync(() => c.read(appDatabaseProvider).watchScans().first))!.length, 1);
    _now = _now.add(const Duration(seconds: 3));
    await tester.tap(find.text('Building A'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Building B').last);
    await tester.pumpAndSettle();
    expect(find.text('Path: Building B'), findsOneWidget);
    await _wedge(tester, 'TAG-777');
    expect(find.text("This tag isn't linked yet"), findsNothing);
    expect(find.text('Path: Building A / Floor 2'), findsOneWidget);
  });

  testWidgets('typing into a normal text field is not taken as a scan', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          navigatorKey: _nav,
          home: HardwareScanListener(
            navigatorContext: () => _nav.currentContext,
            child: const Scaffold(body: TextField()),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await _wedge(tester, 'LOC:BLD-A-F2');
    expect(find.text("This tag isn't linked yet"), findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });
}

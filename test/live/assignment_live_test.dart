import 'dart:convert';

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/token_store.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_asset_backend.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

const _assignments = '/api/asset-assignments';
const _saraId = '6650a1b2c3d4e5f600000e01';

/// API mode Assign Custodian / Check Out (POST /api/asset-assignments with the Master Data
/// employee) and Move Asset (Master Data location pickers, no move endpoint yet).
void main() {
  late FakeAssetBackend backend;

  setUp(() {
    backend = FakeAssetBackend()
      ..on(
        'POST',
        _assignments,
        (o) => FakeReply(201, {
          'id': 'asg-db-1',
          'assignmentNumber': 'ASG-000001',
          'status': 'Active',
          'assignedToName': (o.data as Map)['employee']?['employeeName'],
        }),
      );
    debugApiMode = true;
    NetworkNotifier.listenToDevice = false;
  });

  tearDown(() {
    debugApiMode = null;
    NetworkNotifier.listenToDevice = true;
  });

  Future<void> open(WidgetTester tester, String route) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        retry: (_, _) => null,
        overrides: [
          ...backend.overrides,
          sessionProvider.overrideWith(_SignedIn.new),
          tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        ],
        child: const Asset360App(),
      ),
    );
    await tester.pump(SplashScreen.duration);
    await tester.pumpAndSettle();
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    // Start on the asset, then open the form on top (so it can pop back after saving).
    c.read(routerProvider).go('/assets/detail/AR000001');
    await tester.pumpAndSettle();
    c.read(routerProvider).push(route);
    await tester.pumpAndSettle();
  }

  Finder button(String label) =>
      find.ancestor(of: find.text(label), matching: find.byWidgetPredicate((w) => w is FilledButton)).last;

  Future<void> tap(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.pumpAndSettle();
    await tester.tap(f);
    await tester.pumpAndSettle();
  }

  Future<void> pickSara(WidgetTester tester) async {
    await tap(tester, find.text('Search by name or employee ID'));
    expect(find.textContaining('EMP-0042'), findsOneWidget, reason: 'Master Data employees');
    await tester.tap(find.text('Sara Ali').last);
    await tester.pumpAndSettle();
  }

  Map<String, dynamic> sent() =>
      jsonDecode(jsonEncode(backend.calls('POST', _assignments).single.data)) as Map<String, dynamic>;

  testWidgets('Assign Custodian: employee required; posts an Employee assignment with the Master Data employee', (
    tester,
  ) async {
    await open(tester, Routes.moreActionFrom('/assets', 'assign-custodian', 'AR000001'));
    expect(find.text('Assign Custodian'), findsWidgets);
    await tap(tester, button('Assign Custodian'));
    expect(find.text('Choose the custodian'), findsOneWidget);
    expect(backend.calls('POST', _assignments), isEmpty);

    await pickSara(tester);
    expect(find.text('Employee Details'), findsOneWidget);
    expect(find.text('Facilities Technician'), findsOneWidget);
    await tap(tester, button('Assign Custodian'));
    final body = sent();
    expect(body['assetRegistrationIds'], ['AR000001']);
    expect([body['selectionMode'], body['assignTo'], body['assignmentType']], ['Single', 'Employee', 'Custodian']);
    expect(body['isOpenEnded'], isTrue);
    expect(body['toDate'], isNull);
    expect(body['fromDate'], isNotNull);
    expect(body['employee'], {
      'employeeId': _saraId,
      'employeeCode': 'EMP-0042',
      'employeeName': 'Sara Ali',
      'designation': 'Facilities Technician',
      'departmentId': 'md-dep-1',
      'departmentName': 'Facilities Management',
      'manager': null,
    });
    expect(find.textContaining('custodian set to Sara Ali (ASG-000001)'), findsOneWidget);
    expect(find.text('Assign Custodian'), findsNothing, reason: 'back on the asset');
  });

  testWidgets('Check Out: posts a "Check Out" assignment with the return date; Check In is not available yet; '
      'a server error stays on the form', (tester) async {
    await open(tester, Routes.moreActionFrom('/assets', 'check-in-out', 'AR000001'));
    await tap(tester, find.descendant(of: find.byType(SegmentTabs), matching: find.text('Check In')));
    expect(find.text(notAvailableYetMessage), findsOneWidget);
    await tap(tester, find.descendant(of: find.byType(SegmentTabs), matching: find.text('Check Out')));

    await pickSara(tester);
    backend.on(
      'POST',
      _assignments,
      (_) => const FakeReply(400, {
        'title': 'One or more validation errors occurred.',
        'status': 400,
        'errors': {
          'AssetRegistrationIds': ['AR000001 is already assigned'],
        },
      }),
    );
    await tap(tester, button('Check Out'));
    expect(find.byType(SegmentTabs), findsOneWidget, reason: 'the form stays open');
    expect(backend.calls('POST', _assignments), hasLength(1));

    backend.on('POST', _assignments, (o) => const FakeReply(201, {'id': 'x', 'assignmentNumber': 'ASG-000002'}));
    await tap(tester, button('Check Out'));
    final body = jsonDecode(jsonEncode(backend.calls('POST', _assignments).last.data)) as Map<String, dynamic>;
    expect(body['assignmentType'], 'Check Out');
    expect((body['employee'] as Map)['employeeId'], _saraId);
    expect(body['isOpenEnded'], isTrue, reason: 'no return date chosen');
    expect(find.textContaining('checked out to Sara Ali'), findsOneWidget);
  });

  testWidgets('AssignTo comes from /api/asset-assignments/options; without it nothing is sent', (tester) async {
    backend.on('GET', '/api/asset-assignments/options', (_) => const FakeReply(503, {'message': 'down'}));
    await open(tester, Routes.moreActionFrom('/assets', 'assign-custodian', 'AR000001'));
    expect(find.textContaining('Could not load the assignment options'), findsOneWidget);
    await pickSara(tester);
    await tap(tester, button('Assign Custodian'));
    expect(backend.calls('POST', _assignments), isEmpty);

    // The server's own spelling is sent back.
    backend.on(
      'GET',
      '/api/asset-assignments/options',
      (_) => const FakeReply(200, {
        'assignTo': ['EMPLOYEE', 'Department'],
      }),
    );
    await tap(tester, find.text('Retry'));
    expect(find.textContaining('Could not load the assignment options'), findsNothing);
    await tap(tester, button('Assign Custodian'));
    expect(sent()['assignTo'], 'EMPLOYEE');
  });
}

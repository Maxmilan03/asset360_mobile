// Renders the designed screens to PNG with the real fonts, for design reviews.
//   flutter test tool/shots_test.dart                  (light, all designs)
//   SHOTS=03,08 DARK=1 flutter test tool/shots_test.dart
// Output: build/shots/<design>_<n>_<name>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:asset360_mobile/app/app.dart';
import 'package:asset360_mobile/app/router/app_router.dart';
import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/data/repositories/network_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/data/repositories/settings_repository.dart';
import 'package:asset360_mobile/data/repositories/sync_repository.dart';
import 'package:asset360_mobile/features/auth/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedIn extends SessionNotifier {
  @override
  SessionState build() => super.build().copyWith(loggedIn: true, rememberMe: true);
}

class _Dark extends AppSettingsNotifier {
  @override
  AppSettings build() => const AppSettings(themeMode: ThemeMode.dark);
}

/// design number → (name, route); null route = special setup.
final Map<String, List<(String, String)>> _designs = {
  '01': [('login', Routes.login), ('forgot', Routes.forgotPassword), ('authenticator', Routes.authenticator)],
  '02': [('home', Routes.home), ('home_tasks', Routes.myTasks), ('approvals', Routes.approvals)],
  '03': [
    ('assets', Routes.assets),
    ('asset_detail', Routes.assetDetail('CNC-00123')),
    ('asset_iot', Routes.assetDetail('CNC-00123', tab: 'iot')),
  ],
  '04': [('registration', Routes.registration), ('register_step1', Routes.newRegistration)],
  '05': [
    ('scan', Routes.scan),
    ('scan_result', Routes.scanResultFrom(Routes.home, 'MTR-00123')),
    ('scan_history', Routes.scanHistory),
  ],
  '06': [
    ('tracking', Routes.tracking),
    ('track_asset', Routes.trackAsset('FL-012')),
    ('track_list', Routes.trackingTab('list')),
  ],
  '07': [
    ('movement', Routes.movement),
    ('transfer', Routes.transferAsset),
    ('move_request', Routes.movementRequest('MOV-2026-0045')),
  ],
  '08': [
    ('maintenance', Routes.maintenance),
    ('work_order', Routes.workOrder('WO-2026-0045')),
    ('wo_tasks', Routes.workOrderTab('WO-2026-0045', 'tasks')),
  ],
  '09': [
    ('inspection', Routes.inspection),
    ('inspection_detail', Routes.inspectionDetail('INS-2026-0045')),
    ('inspection_checklist', Routes.inspectionDetail('INS-2026-0045', tab: 'checklist')),
  ],
  '10': [('issues', Routes.issues), ('report_issue', Routes.reportIssue), ('issue', Routes.issueDetail('ISS-2026-0056'))],
  '11': [
    ('alerts', Routes.alerts),
    ('alert', Routes.alertDetail('ALT-2026-0245')),
    ('notifications', Routes.notificationsFrom(Routes.home)),
  ],
  '12': [('inventory', Routes.inventory), ('part', Routes.partDetail('BR-6205')), ('stock', Routes.partStock('BR-6205'))],
  '13': [('wip', Routes.wip), ('wip_unit', Routes.wipUnit('PCB-A-4587')), ('order', Routes.productionOrder('MO-2026-0018'))],
  '14': [
    ('documents', Routes.documents),
    ('document', Routes.documentDetail('DOC-2026-0045')),
    ('add_document', Routes.addDocument),
  ],
  '15': [
    ('audit', Routes.audit),
    ('audit_session', Routes.auditSession('AUD-2026-001')),
    ('asset_found', Routes.auditAsset('AUD-2026-001', 'GEN-00045', method: 'QR')),
  ],
  '16': [('offline_sync', Routes.offlineSync), ('pending_sync', Routes.pendingSync), ('syncing', Routes.syncProgress)],
  '19': [
    ('profile', Routes.profileFrom(Routes.more)),
    ('settings', Routes.settings),
    ('help', Routes.help),
  ],
};

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    inter.addFont(rootBundle.load('assets/fonts/Inter-$w.ttf'));
  }
  await inter.load();
  final root = Platform.environment['FLUTTER_ROOT'] ?? '${Platform.environment['HOME']}/flutter';
  final fonts = '$root/bin/cache/artifacts/material_fonts';
  final icons = FontLoader('MaterialIcons')
    ..addFont(Future.value(ByteData.sublistView(File('$fonts/MaterialIcons-Regular.otf').readAsBytesSync())));
  await icons.load();
  final roboto = FontLoader('Roboto')
    ..addFont(Future.value(ByteData.sublistView(File('$fonts/Roboto-Regular.ttf').readAsBytesSync())));
  await roboto.load();
}

void main() {
  final only = Platform.environment['SHOTS']?.split(',').toSet();
  final dark = Platform.environment['DARK'] == '1';
  setUpAll(_loadFonts);
  setUp(() {
    DemoClock.frozen = true;
    NetworkNotifier.listenToDevice = false;
  });

  for (final MapEntry(key: design, value: screens) in _designs.entries) {
    if (only != null && !only.contains(design)) continue;
    testWidgets('design $design', (tester) async {
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final key = GlobalKey();
      final auth = design == '01';
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: ProviderScope(
            overrides: [
              if (!auth) sessionProvider.overrideWith(_SignedIn.new),
              if (dark) appSettingsProvider.overrideWith(_Dark.new),
            ],
            child: const Asset360App(),
          ),
        ),
      );
      await tester.pump(SplashScreen.duration);
      await tester.pumpAndSettle();
      final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
      for (final (i, (name, route)) in screens.indexed) {
        if (design == '16' && name == 'syncing') {
          c.read(syncProvider.notifier).startRun();
        }
        if (design == '01' && name == 'authenticator') {
          c.read(sessionProvider.notifier).signIn('rex.kumar', 'Asset@360', rememberMe: false);
        }
        c.read(routerProvider).go(route);
        for (var t = 0; t < 12; t++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        await tester.runAsync(() async {
          for (final e in find.byType(Image).evaluate()) {
            await precacheImage((e.widget as Image).image, e);
          }
        });
        await tester.pump(const Duration(milliseconds: 200));
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final bytes = await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
        });
        final dir = Directory('build/shots')..createSync(recursive: true);
        File('${dir.path}/${design}_${i + 1}_$name${dark ? '_dark' : ''}.png').writeAsBytesSync(bytes!);
      }
      if (design == '16') {
        c.read(syncProvider.notifier).cancelRun();
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  }
}

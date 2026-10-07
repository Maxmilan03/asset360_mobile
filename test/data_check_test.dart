import 'package:asset360_mobile/data/data_check.dart';
import 'package:asset360_mobile/data/models/tracking.dart';
import 'package:asset360_mobile/data/repositories/alerts_repository.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/issues_repository.dart';
import 'package:asset360_mobile/data/repositories/tracking_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('seed data passes every Data check', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final groups = runDataChecks(container.read);
    final failures = [
      for (final g in groups)
        for (final c in g.checks.where((c) => !c.ok)) '${g.title} › ${c.label}: ${c.actual} (expected ${c.expected})',
    ];
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  // Screens look assets up by ID, so name and status are single-sourced; these are the records that copy
  // asset details and must agree with the asset.
  test('every asset ID shows the same name, location and status everywhere', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final assets = {for (final a in c.read(assetsProvider)) a.id: a};
    final bad = <String>[
      for (final i in c.read(issuesProvider))
        if (i.location != assets[i.assetId]!.location) '${i.id} location "${i.location}"',
      for (final a in c.read(alertsProvider))
        if (a.location != assets[a.assetId]!.location) '${a.id} location "${a.location}"',
      for (final e in c.read(trackingProvider).entities)
        if (e.assetId != null && e.kind != TrackedKind.alert)
          if (e.label != '${assets[e.assetId]!.name.split(' – ').first} ${e.assetId}') '${e.id} label "${e.label}"',
      for (final a in c.read(trackedAssetsProvider))
        if (!identical(a, assets[a.id])) '${a.id} tracked copy differs',
    ];
    expect(bad, isEmpty, reason: bad.join('\n'));
  });

  test('moving an asset carries its open issues and active alerts to the new location', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(assetsProvider.notifier).setLocation('CR-001', 'Main Warehouse / Zone C');
    for (final i in c.read(issuesProvider).where((i) => i.assetId == 'CR-001' && i.isOpen)) {
      expect(i.location, 'Main Warehouse / Zone C', reason: i.id);
    }
    for (final a in c.read(alertsProvider).where((a) => a.assetId == 'CR-001' && !a.isResolved)) {
      expect(a.location, 'Main Warehouse / Zone C', reason: a.id);
    }
    expect(c.read(assetByIdProvider('CR-001'))!.location, 'Main Warehouse / Zone C');
  });
}

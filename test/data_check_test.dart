import 'package:asset360_mobile/data/data_check.dart';
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
}

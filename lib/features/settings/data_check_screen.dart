import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';
import '../../data/data_check.dart';

/// Debug-only: lists every count computed from lib/data and confirms that
/// tab totals add up (More → Settings → Developer → Data check).
class DataCheckScreen extends ConsumerStatefulWidget {
  const DataCheckScreen({super.key});

  @override
  ConsumerState<DataCheckScreen> createState() => _DataCheckScreenState();
}

class _DataCheckScreenState extends ConsumerState<DataCheckScreen> {
  late List<DataCheckGroup> _groups = runDataChecks(ref.read);
  bool _failuresOnly = false;

  void _rerun() {
    setState(() => _groups = runDataChecks(ref.read));
    final f = _groups.fold<int>(0, (s, g) => s + g.failures);
    context.showSnack(f == 0 ? 'Data check passed' : 'Data check: $f item(s) differ from the seed');
  }

  @override
  Widget build(BuildContext context) {
    final total = _groups.fold<int>(0, (s, g) => s + g.checks.length);
    final failures = _groups.fold<int>(0, (s, g) => s + g.failures);
    final ok = failures == 0;
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Data check',
            subtitle: 'Counts computed from the mock repositories',
            help:
                'Each row is computed from lib/data. Rows with an expected value compare against the seed '
                'figures of Prompt 02, checked at the demo start time (25 Sep 2026 10:30 AM). '
                'Rules such as "All = sum of tabs" must always pass. After you change data in the app, '
                'seed comparisons can differ; that is expected.',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                Icon(
                  ok ? Icons.verified_rounded : Icons.error_rounded,
                  color: ok ? AppColors.green : AppColors.red,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ok ? 'All checks passed' : '$failures of $total checks differ', style: AppText.cardTitle),
                      const SizedBox(height: 2),
                      Text('$total checks in ${_groups.length} modules', style: AppText.caption),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _rerun,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Run again'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PillChip(
                label: 'All checks',
                selected: !_failuresOnly,
                onTap: () => setState(() => _failuresOnly = false),
              ),
              PillChip(
                label: 'Differences ($failures)',
                selected: _failuresOnly,
                onTap: () => setState(() => _failuresOnly = true),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final g in _groups)
            if (!_failuresOnly || g.failures > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SectionCard(
                  title: g.title,
                  actionLabel: g.failures == 0 ? 'OK' : '${g.failures} differ',
                  actionIcon: g.failures == 0 ? Icons.check_circle_rounded : Icons.error_rounded,
                  onAction: () => context.showSnack(
                    g.failures == 0
                        ? '${g.title}: all ${g.checks.length} checks passed'
                        : '${g.title}: ${g.failures} check(s) differ',
                  ),
                  child: Column(
                    children: [
                      for (final c in g.checks)
                        if (!_failuresOnly || !c.ok) _CheckRow(check: c),
                    ],
                  ),
                ),
              ),
          if (_failuresOnly && ok)
            const EmptyState(icon: Icons.verified_rounded, title: 'No differences', message: 'Every count matches.'),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final DataCheck check;

  @override
  Widget build(BuildContext context) {
    final c = check;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              c.expected == null && c.ok
                  ? Icons.circle_outlined
                  : (c.ok ? Icons.check_circle_rounded : Icons.cancel_rounded),
              size: 16,
              color: c.expected == null && c.ok ? AppColors.textMuted : (c.ok ? AppColors.green : AppColors.red),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(c.label, style: AppText.body.copyWith(fontSize: 13))),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(c.actual, textAlign: TextAlign.right, style: AppText.bodyStrong.copyWith(fontSize: 13)),
                if (c.expected != null && !c.ok)
                  Text('expected ${c.expected}', style: AppText.caption.copyWith(color: AppColors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

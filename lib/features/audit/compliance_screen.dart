import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/document.dart';
import '../../data/models/inspection.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/documents_repository.dart';
import '../../data/repositories/inspections_repository.dart';

/// Certificates that expired or expire within this many days are listed under Compliance.
const complianceWindowDays = 90;

/// Documents with an expiry inside the compliance window (expired first).
final expiringCertificatesProvider = Provider<List<AssetDocument>>((ref) {
  ref.watch(clockTickProvider);
  return ref
      .watch(documentsProvider)
      .docs
      .where((d) => d.expiry != null && DemoClock.daysUntil(d.expiry!) <= complianceWindowDays)
      .toList()
    ..sort((a, b) => a.expiry!.compareTo(b.expiry!));
});

/// Open inspections that are overdue or due within 7 days.
final complianceInspectionsProvider = Provider<List<Inspection>>((ref) {
  ref.watch(clockTickProvider);
  return ref.watch(inspectionsProvider).where((i) => !i.isCompleted && DemoClock.daysUntil(i.dueAt) <= 7).toList()
    ..sort((a, b) => a.dueAt.compareTo(b.dueAt));
});

/// Compliance: certificates that expire soon and inspections that are due (opened from Asset Audit).
class ComplianceScreen extends ConsumerWidget {
  const ComplianceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final certs = ref.watch(expiringCertificatesProvider);
    final inspections = ref.watch(complianceInspectionsProvider);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Compliance',
            subtitle: 'Certificates and inspections that need attention',
            help:
                'Certificates that have expired or expire within 90 days, and inspections that are overdue '
                'or due within 7 days.',
          ),
          const SizedBox(height: 12),
          LoadingGate(
            rows: 5,
            child: _Compliance(certs: certs, inspections: inspections),
          ),
        ],
      ),
    );
  }
}

class _Compliance extends ConsumerWidget {
  const _Compliance({required this.certs, required this.inspections});

  final List<AssetDocument> certs;
  final List<Inspection> inspections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expired = certs.where((d) => DemoClock.daysUntil(d.expiry!) < 0).length;
    final overdue = inspections.where((i) => DemoClock.isOverdue(i.dueAt)).length;
    Widget stat(String v, String l, Color c) => Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(v, style: AppText.kpiNumber.copyWith(color: c, fontSize: 20)),
            Text(l, textAlign: TextAlign.center, style: AppText.caption),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            stat('$expired', 'Expired\ncertificates', AppColors.red),
            const SizedBox(width: 8),
            stat('${certs.length - expired}', 'Expiring in\n$complianceWindowDays days', AppColors.amber),
            const SizedBox(width: 8),
            stat('$overdue', 'Overdue\ninspections', AppColors.red),
          ],
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Certificates (${certs.length})',
          actionLabel: 'Documents',
          onAction: () => context.go(Routes.documents),
          child: certs.isEmpty
              ? Text('No certificates expire in the next 90 days.', style: AppText.secondary)
              : Column(
                  children: [
                    for (final d in certs)
                      _ComplianceRow(
                        icon: Icons.workspace_premium_outlined,
                        title: d.name,
                        subtitle:
                            '${d.assetId} · ${ref.watch(assetByIdProvider(d.assetId))?.name ?? ''} · '
                            'expires ${DemoClock.formatDate(d.expiry!)}',
                        due: d.expiry!,
                        lateLabel: 'Expired',
                        onTap: () => context.push(Routes.documentDetail(d.id)),
                      ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Inspections (${inspections.length})',
          actionLabel: 'Inspection',
          onAction: () => context.go(Routes.inspection),
          child: inspections.isEmpty
              ? Text('No inspections are overdue or due this week.', style: AppText.secondary)
              : Column(
                  children: [
                    for (final i in inspections)
                      _ComplianceRow(
                        icon: Icons.fact_check_outlined,
                        title: '${i.id} · ${i.title}',
                        subtitle: '${i.type} · ${DemoClock.dueLabel(i.dueAt)}',
                        due: i.dueAt,
                        onTap: () => context.push(Routes.inspectionDetail(i.id)),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _ComplianceRow extends StatelessWidget {
  const _ComplianceRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.due,
    required this.onTap,
    this.lateLabel = 'Overdue',
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime due;
  final VoidCallback onTap;

  /// Chip text once [due] has passed ("Expired" for certificates).
  final String lateLabel;

  @override
  Widget build(BuildContext context) {
    final days = DemoClock.daysUntil(due);
    final late = DemoClock.isOverdue(due);
    final chip = late
        ? StatusChip(lateLabel, tone: ChipTone.red)
        : StatusChip(days == 0 ? 'Today' : 'In $days d', tone: ChipTone.amber);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconSquare(icon: icon, tone: late ? TileTone.pink : TileTone.peach, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyStrong.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.caption),
                ],
              ),
            ),
            const SizedBox(width: 6),
            chip,
            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/models/audit.dart';
import 'package:asset360_mobile/data/repositories/audits_repository.dart';
import 'package:asset360_mobile/features/assets/asset_ui.dart';

/// Icon and colours for an audit result (tiles, action cards, lists).
({IconData icon, Color color, TileTone tone}) auditResultLook(String result) => switch (result) {
  AuditResult.verified => (icon: Icons.check_circle_rounded, color: AppColors.green, tone: TileTone.mint),
  AuditResult.wrongLocation => (icon: Icons.location_on_rounded, color: AppColors.orange, tone: TileTone.peach),
  AuditResult.notFound => (icon: Icons.cancel_rounded, color: AppColors.red, tone: TileTone.pink),
  _ => (icon: Icons.add_box_rounded, color: AppColors.iconViolet, tone: TileTone.lavender),
};

/// "01 Sep – 30 Sep 2026" (both years when they differ).
String auditDateRange(Audit a) => a.start.year == a.end.year
    ? '${DateFormat('dd MMM').format(a.start)} – ${DateFormat('dd MMM yyyy').format(a.end)}'
    : '${DemoClock.formatDate(a.start)} – ${DemoClock.formatDate(a.end)}';

/// Splits "Main Plant / Building A (Generator Room GR-01)" or "Building / Floor – Zone" into two lines.
(String, String?) locationLines(String location) {
  final paren = location.indexOf(' (');
  if (paren > 0 && location.endsWith(')')) {
    return (location.substring(0, paren), location.substring(paren + 2, location.length - 1));
  }
  final dash = location.lastIndexOf(' – ');
  if (dash > 0) return (location.substring(0, dash), location.substring(dash + 3));
  return (location, null);
}

/// "10:12 AM" today, else "24 Sep 2026 10:12 AM".
String auditTime(DateTime d) => DemoClock.isToday(d) ? DemoClock.formatTime(d) : DemoClock.formatDateTime(d);

/// Audit list card (design 15, left).
class AuditCard extends ConsumerWidget {
  const AuditCard({super.key, required this.audit});

  final Audit audit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = audit;
    final pct = (a.progress * 100).round();
    final done = a.status == AuditStatus.completed;
    return InkWell(
      onTap: () => context.push(Routes.auditSession(a.id)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 68,
                height: 68,
                child: a.imagePath == null
                    ? ColoredBox(
                        color: AppColors.greyBg,
                        child: Icon(Icons.apartment_rounded, color: AppColors.textSecondary),
                      )
                    : Image.asset(a.imagePath!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(a.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyStrong),
                      ),
                      const SizedBox(width: 6),
                      StatusChip(a.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  IconLine(icon: Icons.location_on_outlined, text: a.site),
                  const SizedBox(height: 2),
                  IconLine(icon: Icons.calendar_today_outlined, text: auditDateRange(a)),
                  const SizedBox(height: 4),
                  Text('Total Assets ${formatCount(a.totalAssets)}', style: AppText.caption),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: a.progress,
                            minHeight: 6,
                            color: done ? AppColors.green : AppColors.primary,
                            backgroundColor: AppColors.divider,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('$pct%', style: AppText.caption.copyWith(color: AppColors.text)),
                    ],
                  ),
                  if (a.status == AuditStatus.pending || a.status == AuditStatus.paused) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 34,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () {
                          ref.read(auditsProvider.notifier).start(a.id);
                          context.showSnack(
                            '${a.name} ${a.status == AuditStatus.paused ? 'resumed' : 'started'} – now In Progress',
                          );
                        },
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: Text(a.status == AuditStatus.paused ? 'Resume Audit' : 'Start Audit'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

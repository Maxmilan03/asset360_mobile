import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/person.dart';
import '../../data/models/work_order.dart';
import '../../data/repositories/assets_repository.dart';
import '../assets/asset_ui.dart';

/// Hub row: photo, priority chip, WO number, asset + problem, location, status chip and date.
class WoRow extends ConsumerWidget {
  const WoRow({super.key, required this.wo});

  final WorkOrder wo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(wo.assetId));
    return AssetListTile(
      title: wo.id,
      titleLeading: PriorityChip(wo.priority),
      subtitle: wo.title,
      location: asset?.location ?? wo.assetId,
      imagePath: asset?.imagePath,
      fallbackIcon: asset == null ? Icons.build_outlined : assetIcon(asset),
      trailingTop: StatusChip(wo.status),
      trailingBottom: DemoClock.formatDate(wo.dueAt),
      // design/08: work-order rows have no chevron.
      showChevron: false,
      onTap: () => context.push(Routes.workOrder(wo.id)),
    );
  }
}

/// Live red "1h 20m remaining" / "Overdue by 2h" chip; ticks with [clockTickProvider].
class DueCountdownChip extends ConsumerWidget {
  const DueCountdownChip({super.key, required this.dueAt});

  final DateTime dueAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clockTickProvider);
    final overdue = DemoClock.isOverdue(dueAt);
    final text = overdue ? 'Overdue by ${DemoClock.timeLeft(dueAt)}' : '${DemoClock.timeLeft(dueAt)} remaining';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: AppColors.red, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: AppText.chip.copyWith(color: Colors.white)),
    );
  }
}

/// Initials avatar, name and role ("Mohammed Rafi / Maintenance Technician").
class PersonLine extends StatelessWidget {
  const PersonLine({super.key, required this.person});

  final Person? person;

  @override
  Widget build(BuildContext context) {
    final p = person;
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primarySoft,
          child: Text(
            p?.initials ?? '?',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                p?.name ?? 'Unassigned',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.bodyStrong.copyWith(fontSize: 12.5),
              ),
              if (p != null)
                Text(
                  p.role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption.copyWith(fontSize: 10.5),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/demo_clock.dart';
import '../../core/widgets/widgets.dart';
import '../../data/models/movement.dart';
import '../../data/repositories/assets_repository.dart';
import '../../data/repositories/movements_repository.dart';
import '../../data/repositories/session_repository.dart';

/// Movement requests waiting for the signed-in user's approval.
class MyApprovalsScreen extends ConsumerWidget {
  const MyApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).id;
    final pending = ref.watch(movementsProvider).toApprove(me);
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            title: 'My Approvals',
            subtitle: pending.isEmpty
                ? 'Nothing is waiting for you'
                : '${pending.length} requests waiting for your approval',
            help:
                'Asset movement requests where you are the approver. Approve to let the move go ahead, '
                'or reject with a reason. The Home "Approvals" tile updates immediately.',
          ),
          const SizedBox(height: 16),
          if (pending.isEmpty)
            AppCard(
              child: EmptyState(
                icon: Icons.verified_rounded,
                title: 'All caught up',
                message: 'There are no requests waiting for your approval.',
                actionLabel: 'Open Movement & Custody',
                onAction: () => context.go(Routes.movement),
              ),
            )
          else
            for (final m in pending)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ApprovalCard(request: m),
              ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({required this.request});

  final MovementRequest request;

  Future<void> _reject(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setD) => AlertDialog(
            title: Text('Reject ${request.id}?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tell the requester why this request is rejected.'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(hintText: 'Reason (required)', errorText: error),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.red, minimumSize: const Size(96, 44)),
                onPressed: () {
                  final r = controller.text.trim();
                  if (r.isEmpty) {
                    setD(() => error = 'Please enter a reason');
                  } else {
                    Navigator.pop(ctx, r);
                  }
                },
                child: const Text('Reject'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (reason == null || !context.mounted) return;
    ref.read(movementsProvider.notifier).reject(request.id, reason);
    context.showSnack('${request.id} rejected');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(request.assetId));
    final requester = ref.watch(personByIdProvider(request.requesterId));
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AssetThumb(imagePath: asset?.imagePath, size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.id, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      '${request.assetId} – ${asset?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusChip(request.status),
            ],
          ),
          const SizedBox(height: 10),
          InfoRow(label: 'Type', value: request.type, labelWidth: 96),
          InfoRow(label: 'From', value: request.from.name, labelWidth: 96),
          InfoRow(label: 'To', value: request.to.name, labelWidth: 96),
          InfoRow(label: 'Requested by', value: requester?.labelWithRole ?? '—', labelWidth: 96),
          InfoRow(label: 'Submitted', value: DemoClock.formatDateTime(request.createdAt), labelWidth: 96),
          if (request.reason != null) InfoRow(label: 'Reason', value: request.reason!, labelWidth: 96),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  onPressed: () => _reject(context, ref),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(movementsProvider.notifier).approve(request.id);
                    context.showSnack('${request.id} approved');
                  },
                  child: const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

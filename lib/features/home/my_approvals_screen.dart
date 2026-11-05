import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/demo_clock.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/models/disposal.dart';
import 'package:asset360_mobile/data/models/movement.dart';
import 'package:asset360_mobile/data/repositories/assets_repository.dart';
import 'package:asset360_mobile/data/repositories/disposals_repository.dart';
import 'package:asset360_mobile/data/repositories/movements_repository.dart';
import 'package:asset360_mobile/features/work/movement/movement_widgets.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';

/// Movement requests waiting for the signed-in user's approval.
class MyApprovalsScreen extends ConsumerWidget {
  const MyApprovalsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // API mode: movement and disposal approvals (asset-assignments / asset-disposals) are not in this phase.
    if (apiMode) {
      return AppScaffold(
        body: ListView(
          padding: context.pagePadding,
          children: const [
            PageTitle(title: 'My Approvals', subtitle: 'Movement and disposal requests'),
            SizedBox(height: 16),
            AppCard(child: NotAvailableYet(feature: 'Approvals', icon: Icons.verified_outlined)),
          ],
        ),
      );
    }
    final me = ref.watch(currentUserProvider).id;
    final pending = ref.watch(movementsProvider).toApprove(me);
    final disposals = ref.watch(disposalsProvider).toApprove(me);
    final total = pending.length + disposals.length;
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          PageTitle(
            title: 'My Approvals',
            subtitle: total == 0 ? 'Nothing is waiting for you' : '$total requests waiting for your approval',
            help:
                'Asset movement and disposal requests where you are the approver. Approve to let the move '
                'go ahead (or dispose of the asset), or reject with a reason. The Home "Approvals" tile '
                'updates immediately.',
          ),
          const SizedBox(height: 16),
          if (total == 0)
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
            LoadingGate(
              rows: 2,
              child: Column(
                children: [
                  for (final d in disposals)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DisposalCard(request: d),
                    ),
                  for (final m in pending)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ApprovalCard(request: m),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends ConsumerWidget {
  const _ApprovalCard({required this.request});

  final MovementRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = ref.watch(assetByIdProvider(request.assetId));
    final requester = ref.watch(personByIdProvider(request.requesterId));
    return AppCard(
      onTap: () => context.push(Routes.movementRequest(request.id)),
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
                    Text(request.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
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
                  onPressed: () => rejectMovement(context, ref, request),
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

/// A disposal request: Approve → the asset becomes Disposed; Reject asks for a reason.
class _DisposalCard extends ConsumerWidget {
  const _DisposalCard({required this.request});

  final DisposalRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = request;
    final asset = ref.watch(assetByIdProvider(d.assetId));
    final requester = ref.watch(personByIdProvider(d.requesterId));
    return AppCard(
      onTap: () => context.push(Routes.assetDetail(d.assetId)),
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
                    Text(d.id, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                    const SizedBox(height: 2),
                    Text(
                      '${d.assetId} – ${asset?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusChip(d.status),
            ],
          ),
          const SizedBox(height: 10),
          const InfoRow(label: 'Type', value: 'Disposal', labelWidth: 96),
          InfoRow(label: 'Reason', value: d.reason, labelWidth: 96),
          InfoRow(label: 'Requested for', value: DemoClock.formatDate(d.requestedDate), labelWidth: 96),
          InfoRow(label: 'Requested by', value: requester?.labelWithRole ?? '—', labelWidth: 96),
          InfoRow(label: 'Submitted', value: DemoClock.formatDateTime(d.createdAt), labelWidth: 96),
          if (d.notes != null) InfoRow(label: 'Notes', value: d.notes!, labelWidth: 96),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                  ),
                  onPressed: () async {
                    final reason = await showReasonDialog(
                      context,
                      title: 'Reject ${d.id}?',
                      message: 'Tell the requester why ${d.assetId} should not be disposed.',
                    );
                    if (reason == null || !context.mounted) return;
                    ref.read(disposalsProvider.notifier).reject(d.id, reason);
                    context.showSnack('${d.id} rejected');
                  },
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final ok = await showConfirmDialog(
                      context,
                      title: 'Approve ${d.id}?',
                      message: '${d.assetId} will be marked Disposed.',
                      confirmLabel: 'Approve',
                    );
                    if (!ok || !context.mounted) return;
                    ref.read(disposalsProvider.notifier).approve(d.id);
                    context.showSnack('${d.id} approved – ${d.assetId} is now Disposed');
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

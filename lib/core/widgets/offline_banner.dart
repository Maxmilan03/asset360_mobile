import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../data/repositories/network_repository.dart';
import '../../data/repositories/sync_repository.dart';

/// Slim bar under every header: offline (tap → Offline Sync) or a sync running in the background.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(isOfflineProvider);
    final sync = ref.watch(syncProvider);
    if (!offline && !sync.running) return const SizedBox.shrink();
    final path = GoRouterState.of(context).uri.path;
    final target = offline ? Routes.offlineSync : Routes.syncProgress;
    // Syncing Data already shows the run.
    if (!offline && path == target) return const SizedBox.shrink();
    final pending = sync.pending.length;
    final run = sync.run;
    final done = run == null ? 0 : run.ids.where((id) => sync.item(id)?.syncedAt != null).length;
    return Material(
      color: offline ? const Color(0xFF3B2F63) : AppColors.primary,
      child: InkWell(
        onTap: path == target ? null : () => context.push(target),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Icon(offline ? Icons.cloud_off_rounded : Icons.cloud_upload_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  offline
                      ? "You're offline – changes will sync later"
                      : 'Syncing… $done of ${run?.ids.length ?? 0} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w500),
                ),
              ),
              if (offline && pending > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(color: AppColors.amber, borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    '$pending',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              if (path != target) const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/demo_guard.dart';
import 'package:asset360_mobile/data/db/db_providers.dart';

/// "Saved on this device: N scans ›" → Local Data (or [onTap]). Counts live from ScanLog.
class LocalDataBadge extends ConsumerWidget {
  const LocalDataBadge({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(scanStatsProvider).value?.total ?? 0;
    return Material(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? DemoGuard.push(context, Routes.localData),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
          child: Row(
            children: [
              Icon(Icons.storage_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Saved on this device: $total scan${total == 1 ? '' : 's'}',
                  style: AppText.body.copyWith(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}

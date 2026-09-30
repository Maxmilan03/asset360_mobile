import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../core/widgets/widgets.dart';

/// Settings. The full screen (language, notifications, preferences …) is built
/// in Prompt 19; the Developer section is available in debug builds now.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      body: ListView(
        padding: context.pagePadding,
        children: [
          const PageTitle(
            title: 'Settings',
            subtitle: 'Language, notifications and preferences',
            help:
                'App preferences. The Developer section appears only in debug builds and holds demo tools '
                'such as the Data check.',
          ),
          const SizedBox(height: 16),
          AppCard(
            child: Row(
              children: [
                const IconSquare(icon: Icons.construction_rounded, tone: TileTone.lavender),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Language, notification and display settings are built in Prompt 19.',
                    style: AppText.secondary.copyWith(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text('DEVELOPER', style: AppText.caption.copyWith(fontWeight: FontWeight.w600, letterSpacing: .6)),
            ),
            AppCard(
              padding: EdgeInsets.zero,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: const IconSquare(icon: Icons.fact_check_outlined, tone: TileTone.mint),
                title: const Text('Data check', style: AppText.bodyStrong),
                subtitle: const Text('Every count and total in the mock data', style: AppText.caption),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                onTap: () => context.push(Routes.dataCheck),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

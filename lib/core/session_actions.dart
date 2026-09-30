import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/router/routes.dart';
import '../app/theme/app_colors.dart';
import '../data/repositories/session_repository.dart';
import 'widgets/dialogs.dart';
import 'widgets/feedback.dart';

/// Asks for confirmation, then signs out and returns to Login.
Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final ok = await showConfirmDialog(
    context,
    title: 'Logout',
    message: 'Are you sure you want to log out of Asset360?',
    confirmLabel: 'Logout',
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  ref.read(sessionProvider.notifier).logout();
  context.go(Routes.login);
}

/// Bottom sheet with the user's sites; the choice is kept in the session.
Future<void> showSwitchSiteSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(sessionProvider).site;
  final sites = ref.read(sitesProvider);
  final picked = await showModalBottomSheet<String>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text('Switch Site', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          for (final site in sites)
            ListTile(
              leading: Icon(
                site == current ? Icons.radio_button_checked : Icons.radio_button_off,
                color: site == current ? AppColors.primary : AppColors.textMuted,
              ),
              title: Text(site, style: const TextStyle(fontWeight: FontWeight.w500)),
              onTap: () => Navigator.pop(context, site),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  ref.read(sessionProvider.notifier).switchSite(picked);
  context.showSnack('Switched to $picked');
}

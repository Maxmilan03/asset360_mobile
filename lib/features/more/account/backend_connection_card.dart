import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';
import 'package:asset360_mobile/data/repositories/connection_repository.dart';

/// Administration → Backend API: the run-time settings (USE_API, AUTH / API / MEDIA base URLs),
/// which token the Asset and Media services get, and Test connection (GET /health on all four).
class BackendConnectionCard extends ConsumerWidget {
  const BackendConnectionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final test = ref.watch(connectionTestProvider);
    final signedIn = ref.watch(authProvider) is AuthSignedIn;
    // Never shows any part of a token.
    final token = signedIn
        ? 'Signed-in user (refreshed automatically)'
        : (kDevToken.isEmpty ? 'None (sign in first)' : 'DEV_TOKEN override');
    return SectionCard(
      title: 'Backend API',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InfoRow(
            label: 'Data source',
            value: apiMode ? 'Backend (USE_API=true)' : 'Demo mock data (USE_API off)',
            labelWidth: 96,
          ),
          for (final s in BackendService.values)
            InfoRow(label: s.label, value: s.baseUrl.isEmpty ? 'Not set' : s.baseUrl, labelWidth: 96),
          InfoRow(label: 'Token', value: token, labelWidth: 96),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: test.isLoading ? null : () => ref.read(connectionTestProvider.notifier).run(),
            icon: test.isLoading
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                  )
                : const Icon(Icons.wifi_tethering_rounded, size: 20),
            label: Text(test.isLoading ? 'Testing…' : 'Test connection'),
          ),
          const SizedBox(height: 10),
          switch (test) {
            AsyncData(value: final results?) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final r in results) ...[
                  _Result(
                    ok: r.ok,
                    title: '${r.service.code} – ${r.ok ? 'Connected' : 'Failed'}',
                    message: r.ok
                        ? 'GET ${r.url} → ${r.statusCode} in ${r.elapsed!.inMilliseconds} ms'
                              '${r.status == null ? '' : ' · ${r.status}'}'
                        : '${r.url.isEmpty ? '' : 'GET ${r.url}\n'}${r.error}',
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
            AsyncLoading() => Text(
              'Calling ${ConnectionTestNotifier.healthPath} on AUTH, ASSET, MEDIA, MASTER DATA and DASHBOARD …',
              style: AppText.caption,
            ),
            _ => Text(
              'Calls GET ${ConnectionTestNotifier.healthPath} on the login, Asset, Media and Master Data services.',
              style: AppText.caption,
            ),
          },
        ],
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.ok, required this.title, required this.message});

  final bool ok;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final color = ok ? AppColors.green : AppColors.red;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: ok ? AppColors.greenBg : AppColors.redBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ok ? Icons.check_circle_rounded : Icons.error_outline_rounded, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.bodyStrong.copyWith(color: color)),
                const SizedBox(height: 2),
                Text(message, style: AppText.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/auth_models.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';
import 'package:asset360_mobile/features/auth/auth_widgets.dart';

/// API mode, first sign-in (login replied setupRequired = true): add Asset360 to an authenticator
/// app. The user is usually on this same phone, so the setup key comes first; the QR code is for
/// "another device". Next → the code screen (verify-totp).
class AuthenticatorSetupScreen extends ConsumerWidget {
  const AuthenticatorSetupScreen({super.key});

  void _leave(BuildContext context, WidgetRef ref) {
    ref.read(authProvider.notifier).cancelSecondFactor();
    context.go(Routes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(authProvider);
    final p = s is AuthTwoFactorPending ? s : null;
    final key = p?.manualEntryKey;
    final qr = decodeDataUri(p?.qrCodeImage);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave(context, ref);
      },
      child: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed: () => _leave(context, ref),
                          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 20),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 48),
                        child: FittedBox(fit: BoxFit.scaleDown, child: BrandMark(size: 46)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Set up your Authenticator',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heroNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your account needs 2-step sign-in. Add Asset360 to Google Authenticator on this phone, then enter '
                  'the 6-digit code it shows.',
                  style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 20),
                Text('Your setup key', style: AppText.bodyStrong),
                const SizedBox(height: 8),
                if (key == null)
                  const IconLine(
                    icon: Icons.error_outline_rounded,
                    color: AppColors.red,
                    text: 'No setup key received – see Auth diagnostics',
                  )
                else
                  _KeyPill(setupKey: key),
                const SizedBox(height: 18),
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () async {
                            final opened = await AppLauncher.openAuthenticator();
                            if (!opened && context.mounted) {
                              context.showSnack('Install Google Authenticator from the Play Store, then come back');
                            }
                          },
                          child: const _Step(
                            n: 1,
                            text: 'Open Google Authenticator',
                            trailing: AuthenticatorMark(size: 22),
                          ),
                        ),
                      ),
                      const _Step(n: 2, text: 'Tap +'),
                      const _Step(n: 3, text: 'Choose "Enter a setup key"'),
                      _Step(
                        n: 4,
                        text:
                            'Paste the key. Account name: Asset360${p == null ? '' : ' – ${p.userName}'}. '
                            'Type of key: Time based',
                      ),
                      const _Step(n: 5, text: 'Come back here and tap Next'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Text('Using another device? Scan this QR', style: AppText.bodyStrong),
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: qr == null
                        ? SizedBox.square(
                            dimension: 168,
                            child: Center(
                              child: Text('QR code not available', textAlign: TextAlign.center, style: AppText.caption),
                            ),
                          )
                        : Image.memory(qr, width: 168, height: 168, gaplessPlayback: true),
                  ),
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: p == null ? null : () => context.push(Routes.authenticator),
                    child: const ArrowLabel('Next'),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => showContactAdminSheet(
                      context,
                      message: 'Your administrator can reset your authenticator or send you a new setup key.',
                    ),
                    child: const Text('Need help? Contact your administrator'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The setup key in groups of 4, with Copy (copies the key without spaces).
class _KeyPill extends StatelessWidget {
  const _KeyPill({required this.setupKey});

  final String setupKey;

  @override
  Widget build(BuildContext context) {
    final clean = setupKey.replaceAll(' ', '');
    final grouped = [
      for (var i = 0; i < clean.length; i += 4) clean.substring(i, (i + 4).clamp(0, clean.length)),
    ].join(' ');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.primary.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              grouped,
              style: TextStyle(
                fontSize: 15,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                color: AppColors.primary,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: clean));
              context.showSnack('Setup key copied');
            },
            style: FilledButton.styleFrom(minimumSize: const Size(0, 40), shape: const StadiumBorder()),
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text, this.trailing});

  final int n;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColors.primary,
          child: Text(
            '$n',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.body)),
        ?trailing,
      ],
    ),
  );
}

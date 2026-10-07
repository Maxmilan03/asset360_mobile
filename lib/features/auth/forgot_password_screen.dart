import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text.dart';
import '../../data/repositories/session_repository.dart';
import 'auth_widgets.dart';

enum _HelpWith { password, username }

final _emailPattern = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)+$');

/// Forgot Username or Password? (design/01_login_security.jpg, middle).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  _HelpWith _helpWith = _HelpWith.password;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _backToLogin() => context.canPop() ? context.pop() : context.go(Routes.login);

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sending = true);
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    if (!mounted) return;
    setState(() => _sending = false);
    final masked = maskEmail(_email.text.trim());
    final what = _helpWith == _HelpWith.password ? 'reset your password' : 'recover your username';
    final back = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(Icons.mark_email_read_rounded, color: AppColors.primary, size: 40),
              ),
              const SizedBox(height: 16),
              Text('Check your inbox', style: AppText.pageTitle),
              const SizedBox(height: 8),
              Text(
                'We sent instructions to $masked to $what.',
                textAlign: TextAlign.center,
                style: AppText.pageSubtitle.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 6),
              Text(
                "Didn't get it? Check your spam folder or try again in a few minutes.",
                textAlign: TextAlign.center,
                style: AppText.caption,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Back to Login')),
              ),
            ],
          ),
        ),
      ),
    );
    if (back == true && mounted) _backToLogin();
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                          onPressed: _backToLogin,
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
                const SizedBox(height: 18),
                const Center(child: ForgotIllustration()),
                const SizedBox(height: 26),
                const FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Forgot Username or Password?',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heroNavy),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter your registered email address and we will send you instructions to reset your username or password.',
                  style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.send,
                  autofillHints: const [AutofillHints.email],
                  onFieldSubmitted: (_) => _sending ? null : _send(),
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Enter your email address';
                    if (!_emailPattern.hasMatch(t)) return 'Enter a valid email address';
                    return null;
                  },
                  decoration: InputDecoration(
                    hintText: 'Enter your email address',
                    prefixIcon: Icon(Icons.mail_outline_rounded, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 18),
                Text('I need help with:', style: TextStyle(fontSize: 13, color: AppColors.text)),
                const SizedBox(height: 8),
                _RadioCard(
                  label: 'Reset my password',
                  selected: _helpWith == _HelpWith.password,
                  onTap: () => setState(() => _helpWith = _HelpWith.password),
                ),
                const SizedBox(height: 10),
                _RadioCard(
                  label: 'Recover my username',
                  selected: _helpWith == _HelpWith.username,
                  onTap: () => setState(() => _helpWith = _HelpWith.username),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _sending ? null : _send,
                    child: ArrowLabel('Send Instructions', loading: _sending),
                  ),
                ),
                const SizedBox(height: 26),
                Center(
                  child: TextButton.icon(
                    onPressed: _backToLogin,
                    icon: const Icon(Icons.chevron_left_rounded),
                    label: const Text('Back to Login', style: TextStyle(fontSize: 14)),
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

class _RadioCard extends StatelessWidget {
  const _RadioCard({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: selected ? AppColors.primary.withValues(alpha: .5) : AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primary : AppColors.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, color: AppColors.text),
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

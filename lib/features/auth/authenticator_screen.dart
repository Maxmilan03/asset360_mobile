import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/platform/app_launcher.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/mock/people_mock.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/auth_api.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/auth_widgets.dart';

/// Enter Authenticator Code (design/01_login_security.jpg, right).
class AuthenticatorScreen extends ConsumerStatefulWidget {
  const AuthenticatorScreen({super.key});

  @override
  ConsumerState<AuthenticatorScreen> createState() => _AuthenticatorScreenState();
}

class _AuthenticatorScreenState extends ConsumerState<AuthenticatorScreen> with SingleTickerProviderStateMixin {
  static const _length = 6;
  final _code = TextEditingController();
  final _focus = FocusNode();
  late final _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
  String? _error;
  bool _verifying = false;

  /// API mode: the login step this code belongs to (method, masked email, expiry).
  AuthTwoFactorPending? _pending;
  Timer? _ticker;
  Duration _left = Duration.zero;

  @override
  void initState() {
    super.initState();
    if (apiMode) {
      final s = ref.read(authProvider);
      if (s is AuthTwoFactorPending) {
        _pending = s;
        _tick();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
      }
    }
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  /// Countdown from otpExpiresInSeconds; at zero: "Code expired – sign in again" → Login.
  void _tick() {
    final p = _pending;
    if (p == null || !mounted) return;
    final left = p.expiresAt.difference(DateTime.now());
    if (left <= Duration.zero) {
      _ticker?.cancel();
      ref.read(authProvider.notifier).expireCode(); // Login shows the notice
      context.go(Routes.login);
      return;
    }
    setState(() => _left = left);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _code.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  void _leave() {
    if (apiMode) {
      ref.read(authProvider.notifier).cancelSecondFactor();
    } else {
      ref.read(sessionProvider.notifier).cancelSecondFactor();
    }
    context.go(Routes.login);
  }

  /// API mode: verify-totp or verify-otp; a wrong code shows the server's message and shakes.
  Future<void> _verifyApi() async {
    final auth = ref.read(authProvider.notifier);
    try {
      await auth.verifyCode(_code.text);
      if (!mounted) return;
      _ticker?.cancel();
      HapticFeedback.lightImpact();
      await showSignInSuccess(context);
      auth.enterApp();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.kind == ApiErrorKind.expired) {
        context.go(Routes.login);
        return;
      }
      _wrongCode(e.message);
    } catch (_) {
      if (mounted) _wrongCode(AuthApi.unrecognisedMessage);
    }
  }

  void _wrongCode(String message) {
    HapticFeedback.heavyImpact();
    setState(() {
      _verifying = false;
      _error = message;
      _code.clear();
    });
    _shake.forward(from: 0);
    _focus.requestFocus();
  }

  Future<void> _verify() async {
    if (_verifying) return;
    if (_code.text.length < _length) {
      setState(() => _error = 'Enter all 6 digits');
      _shake.forward(from: 0);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    if (apiMode) return _verifyApi();
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    final result = ref.read(sessionProvider.notifier).verifyCode(_code.text);
    switch (result) {
      case CodeResult.ok:
        HapticFeedback.lightImpact();
        context.go(Routes.home);
      case CodeResult.wrong:
        HapticFeedback.heavyImpact();
        final left = ref.read(sessionProvider).codeAttemptsLeft;
        setState(() {
          _verifying = false;
          _error = 'Invalid code. $left ${left == 1 ? 'attempt' : 'attempts'} left';
          _code.clear();
        });
        _shake.forward(from: 0);
        _focus.requestFocus();
      case CodeResult.locked:
        context.go(Routes.login); // the router also redirects; Login shows the session notice
    }
  }

  bool get _emailOtp => _pending?.isEmailOtp ?? false;

  Future<void> _openAuthenticator() async {
    final opened = await AppLauncher.openAuthenticator();
    if (!opened && mounted) context.showSnack('Open your authenticator app and find Purple IQ – Asset360');
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (data?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      if (mounted) context.showSnack('The clipboard has no code to paste');
      return;
    }
    _code.text = digits.substring(0, math.min(_length, digits.length));
    _onChanged(_code.text);
  }

  void _onChanged(String v) {
    setState(() => _error = null);
    if (v.length == _length) _verify();
  }

  void _otherMethod() {
    if (apiMode) {
      showContactAdminSheet(
        context,
        message:
            "Switching to another sign-in method isn't available yet. Your administrator can reset your "
            'authenticator or send you a new setup key.',
      );
      return;
    }
    final email = maskEmail(ref.read(currentUserProvider).email);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Use a different method', style: AppText.sectionTitle),
            ),
            ListTile(
              leading: IconSquare(icon: Icons.mail_outline_rounded, tone: TileTone.lavender, size: 40),
              title: Text('Send code by email', style: AppText.bodyStrong),
              subtitle: Text('We will email a one-time code to $email', style: AppText.caption),
              onTap: () {
                Navigator.pop(ctx);
                context.showSnack('Code sent to $email (demo: use 123456)');
              },
            ),
            ListTile(
              leading: IconSquare(icon: Icons.key_rounded, tone: TileTone.peach, size: 40),
              title: Text('Use a backup code', style: AppText.bodyStrong),
              subtitle: Text(
                'One of the 8-digit codes you saved when you set up 2-step sign-in',
                style: AppText.caption,
              ),
              onTap: () {
                Navigator.pop(ctx);
                _backupCode();
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _backupCode() async {
    final controller = TextEditingController();
    String? error;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Use a backup code'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Enter one of your backup codes (demo: $mockBackupCode).'),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(hintText: 'XXXX-XXXX', errorText: error),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(96, 44)),
              onPressed: () {
                if (ref.read(sessionProvider.notifier).useBackupCode(controller.text)) {
                  Navigator.pop(ctx, true);
                } else {
                  setD(() => error = 'This backup code is not valid');
                }
              },
              child: const Text('Verify'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (ok == true && mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
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
                          onPressed: _leave,
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
                const Center(child: ShieldIllustration()),
                const SizedBox(height: 30),
                Text(
                  _emailOtp ? 'Enter Verification Code' : 'Enter Authenticator Code',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.heroNavy),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailOtp
                      ? 'Code sent to ${_pending?.maskedEmail ?? 'your email'}. Enter it to complete the sign in.'
                      : 'Enter the 6-digit code from your Google Authenticator app to complete the sign in.',
                  style: TextStyle(fontSize: 14.5, color: AppColors.textSecondary, height: 1.4),
                ),
                if (_pending != null) ...[const SizedBox(height: 10), _ExpiryChip(left: _left)],
                const SizedBox(height: 22),
                if (!_emailOtp)
                  Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: AppColors.border),
                    ),
                    child: InkWell(
                      onTap: _openAuthenticator,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.divider),
                              ),
                              child: const Center(child: AuthenticatorMark(size: 26)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Open Google Authenticator',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 2),
                                  Text('Enter the 6-digit code for Purple IQ – Asset360', style: AppText.caption),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _shake,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
                    child: child,
                  ),
                  child: _CodeBoxes(
                    controller: _code,
                    focusNode: _focus,
                    length: _length,
                    error: _error != null,
                    onChanged: _onChanged,
                    onPaste: _paste,
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  child: _error == null
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                              ),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _verifying ? null : _verify,
                    child: ArrowLabel('Verify Code', loading: _verifying),
                  ),
                ),
                const SizedBox(height: 22),
                Center(
                  child: Text(
                    "Can't access your authenticator?",
                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                ),
                Center(
                  child: TextButton(
                    onPressed: _otherMethod,
                    child: Text(
                      'Use a different method',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary,
                      ),
                    ),
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

/// Six boxes drawn over one transparent input, so the numeric keyboard,
/// backspace, SMS/one-time-code autofill and paste all behave natively.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.length,
    required this.error,
    required this.onChanged,
    required this.onPaste,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool error;
  final ValueChanged<String> onChanged;
  final VoidCallback onPaste;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        final active = focusNode.hasFocus ? math.min(text.length, length - 1) : -1;
        return Semantics(
          label: 'Authenticator code, ${text.length} of $length digits entered',
          child: GestureDetector(
            onLongPress: onPaste,
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (var i = 0; i < length; i++)
                      _Box(
                        digit: i < text.length ? text[i] : null,
                        active: i == active && text.length < length,
                        error: error,
                      ),
                  ],
                ),
                Positioned.fill(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: length,
                    showCursor: false,
                    enableInteractiveSelection: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(color: Colors.transparent, fontSize: 1),
                    decoration: const InputDecoration(
                      counterText: '',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.digit, required this.active, required this.error});

  final String? digit;
  final bool active;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = error ? AppColors.red : (active ? AppColors.primary : AppColors.border);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 52,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: active || error ? 1.6 : 1.2),
      ),
      child: digit != null
          ? Text(
              digit!,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.text),
            )
          : active
          ? const _BlinkingCursor()
          : null,
    );
  }
}

class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _c,
    child: Container(width: 2, height: 24, color: AppColors.primary),
  );
}

/// "Code expires in 4:32" (red in the last 30 seconds).
class _ExpiryChip extends StatelessWidget {
  const _ExpiryChip({required this.left});

  final Duration left;

  @override
  Widget build(BuildContext context) {
    final s = left.inSeconds;
    final text = '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    return StatusChip(
      'Code expires in $text',
      tone: s <= 30 ? ChipTone.red : ChipTone.purple,
      icon: Icons.timer_outlined,
    );
  }
}

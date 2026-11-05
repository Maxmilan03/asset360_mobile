import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/app/theme/app_text.dart';
import 'package:asset360_mobile/core/widgets/widgets.dart';
import 'package:asset360_mobile/data/api/api_config.dart';
import 'package:asset360_mobile/data/api/api_exception.dart';
import 'package:asset360_mobile/data/api/auth_api.dart';
import 'package:asset360_mobile/data/repositories/auth_repository.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/auth_widgets.dart';

/// Sign in (design/01_login_security.jpg, left).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _passFocus = FocusNode();
  bool _obscure = true;
  bool _remember = true;
  bool _loading = false;
  String? _error;
  Timer? _lockTimer;

  /// Seconds left on the sign-in lock (0 = not locked).
  int _lockSeconds = 0;

  @override
  void initState() {
    super.initState();
    _remember = ref.read(sessionProvider).rememberMe;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notice = ref.read(sessionProvider.notifier).takeNotice();
      if (notice != null) setState(() => _error = notice);
    });
    _startLockTickerIfNeeded();
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    _user.dispose();
    _pass.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _startLockTickerIfNeeded() {
    final left = ref.read(sessionProvider.notifier).lockRemaining;
    if (left == null) return;
    _lockSeconds = left.inSeconds + 1;
    _lockTimer?.cancel();
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _lockSeconds--);
      if (_lockSeconds <= 0) {
        t.cancel();
        ref.read(sessionProvider.notifier).clearLock();
        setState(() => _error = null);
      }
    });
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    if (apiMode) return _signInApi();
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    final session = ref.read(sessionProvider.notifier);
    final ok = session.signIn(_user.text, _pass.text, rememberMe: _remember);
    setState(() => _loading = false);
    if (ok) {
      context.push(Routes.authenticator);
      return;
    }
    if (ref.read(sessionProvider.notifier).lockRemaining != null) {
      setState(() => _error = 'Too many failed attempts. Try again in 30 seconds.');
      _startLockTickerIfNeeded();
    } else {
      final left = SessionState.maxAttempts - ref.read(sessionProvider).failedLogins;
      setState(() => _error = 'Invalid username or password${left <= 3 ? ' ($left attempts left)' : ''}');
    }
  }

  /// API mode: POST /api/auth/login. The server decides about lockouts; its message is shown.
  Future<void> _signInApi() async {
    setState(() => _loading = true);
    final auth = ref.read(authProvider.notifier);
    try {
      final step = await auth.login(_user.text, _pass.text, rememberMe: _remember);
      if (!mounted) return;
      setState(() => _loading = false);
      switch (step) {
        case LoginStep.setupAuthenticator:
          context.push(Routes.authenticatorSetup);
        case LoginStep.enterCode:
          context.push(Routes.authenticator);
        case LoginStep.signedIn:
          await showSignInSuccess(context);
          auth.enterApp();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (_) {
      // Anything unexpected in the reply: never crash, point to Auth diagnostics.
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AuthApi.unrecognisedMessage;
      });
    }
  }

  void _forgot() => apiMode
      ? showContactAdminSheet(context, message: 'Contact your administrator to reset your password.')
      : context.push(Routes.forgotPassword);

  Future<void> _signInWith(String provider) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(dimension: 26, child: CircularProgressIndicator(strokeWidth: 2.6)),
              const SizedBox(width: 18),
              Expanded(child: Text('Connecting to $provider…', style: AppText.bodyStrong)),
            ],
          ),
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    ref.read(sessionProvider.notifier).signInWithProvider();
    context.push(Routes.authenticator);
  }

  void _pickLanguage() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Language', style: AppText.sectionTitle),
            const SizedBox(height: 8),
            ListTile(
              leading: const Text('🇬🇧', style: TextStyle(fontSize: 22)),
              title: const Text('English'),
              trailing: Icon(Icons.check_circle_rounded, color: AppColors.primary),
              onTap: () => Navigator.pop(ctx),
            ),
            ListTile(
              leading: const Text('🇦🇪', style: TextStyle(fontSize: 22)),
              title: const Text('العربية'),
              subtitle: const Text('Arabic'),
              onTap: () {
                Navigator.pop(ctx);
                context.showSnack('Arabic will be available in a later release');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _contactAdmin() => showContactAdminSheet(context);

  @override
  Widget build(BuildContext context) {
    ref.watch(sessionProvider); // rebuild on lock changes
    // Login may stay alive under the Authenticator screen, so listen for new notices too.
    ref.listen(sessionProvider.select((s) => s.notice), (_, notice) {
      if (notice == null) return;
      ref.read(sessionProvider.notifier).takeNotice();
      _pass.clear();
      setState(() => _error = notice);
    });
    final locked = _lockSeconds > 0;
    final width = MediaQuery.sizeOf(context).width;
    // Card top sits ~408 pt below the status bar (design); the photo fills the band above it.
    final heroImageH = width / 1.925; // login_hero.jpg is 385×200, shown full width
    final top = MediaQuery.paddingOf(context).top;

    return AuthBackground(
      wash: false,
      child: SingleChildScrollView(
        child: Column(
          children: [
            SizedBox(
              height: top + 408,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(left: 0, right: 0, bottom: -24, height: heroImageH, child: const _HeroImage()),
                  Padding(
                    padding: EdgeInsets.fromLTRB(22, top + 14, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: BrandMark(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            _LanguagePill(onTap: _pickLanguage),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(
                                text: 'Asset',
                                style: TextStyle(color: AppColors.heroNavy, fontWeight: FontWeight.w800),
                              ),
                              TextSpan(
                                text: '360',
                                style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          style: const TextStyle(fontSize: 46, height: 1.05, letterSpacing: -1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Track   |   Manage   |   Optimize',
                          style: TextStyle(fontSize: 17, color: AppColors.primary, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 10),
                        const SizedBox(
                          width: 250,
                          child: Text(
                            'Complete Asset Lifecycle Management in your hands.',
                            style: TextStyle(fontSize: 13.5, color: AppColors.heroNavy, height: 1.35),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              padding: EdgeInsets.fromLTRB(20, 18, 20, 12 + MediaQuery.paddingOf(context).bottom),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [BoxShadow(color: Color(0x142B1270), blurRadius: 20, offset: Offset(0, -4))],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Sign in to Asset'),
                          TextSpan(
                            text: '360',
                            style: TextStyle(color: AppColors.primary),
                          ),
                        ],
                      ),
                      style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: AppColors.heroNavy),
                    ),
                    const SizedBox(height: 4),
                    Text('Access your assets, operations and insights', style: AppText.pageSubtitle),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _user,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      keyboardType: TextInputType.emailAddress,
                      onFieldSubmitted: (_) => _passFocus.requestFocus(),
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Enter your username or email' : null,
                      decoration: InputDecoration(
                        hintText: 'Username',
                        contentPadding: _fieldPadding,
                        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 42),
                        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 42),
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _pass,
                      focusNode: _passFocus,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => !locked && !_loading ? _signIn() : null,
                      validator: (v) => (v ?? '').isEmpty ? 'Enter your password' : null,
                      decoration: InputDecoration(
                        hintText: 'Password',
                        contentPadding: _fieldPadding,
                        prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 42),
                        suffixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 42),
                        prefixIcon: Icon(Icons.lock_outline_rounded, color: AppColors.textSecondary),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Checkbox(
                            value: _remember,
                            activeColor: AppColors.primary,
                            onChanged: (v) => setState(() => _remember = v ?? false),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => setState(() => _remember = !_remember),
                          child: Text('Remember me', style: TextStyle(fontSize: 12.5, color: AppColors.text)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                minimumSize: const Size(0, 36),
                              ),
                              onPressed: _forgot,
                              child: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Forgot Username or Password?', style: TextStyle(fontSize: 12.5)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(top: 4, bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(color: AppColors.redBg, borderRadius: BorderRadius.circular(10)),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppColors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!, style: const TextStyle(color: AppColors.red, fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    else
                      const SizedBox(height: 8),
                    SizedBox(
                      height: 44,
                      child: FilledButton(
                        onPressed: _loading || locked ? null : _signIn,
                        child: locked
                            ? Text('Try again in ${_lockSeconds}s')
                            : ArrowLabel('Sign In', loading: _loading),
                      ),
                    ),
                    // Google / Microsoft: no backend support yet, hidden in API mode.
                    if (!apiMode) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('or', textAlign: TextAlign.center, style: AppText.caption),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: _SocialButton(
                              mark: const GoogleMark(),
                              label: 'Sign in with Google',
                              onTap: () => _signInWith('Google'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _SocialButton(
                              mark: const MicrosoftMark(),
                              label: 'Sign in with Microsoft',
                              onTap: () => _signInWith('Microsoft'),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    Center(
                      child: InkWell(
                        onTap: _contactAdmin,
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                          child: Text(
                            'New to Asset360?  Contact your administrator.',
                            style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                    if (apiMode) Center(child: DiagnosticsLink(onTap: () => context.push(Routes.authDiagnostics))),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _fieldPadding = EdgeInsets.symmetric(horizontal: 14, vertical: 9);

/// Hero photo with its left and top edges faded into the background.
class _HeroImage extends StatelessWidget {
  const _HeroImage();

  @override
  Widget build(BuildContext context) {
    Shader fade(Rect r, Alignment begin, Alignment end, List<double> stops) => LinearGradient(
      begin: begin,
      end: end,
      stops: stops,
      colors: const [Colors.transparent, Colors.black],
    ).createShader(r);
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (r) => fade(r, Alignment.topCenter, Alignment.bottomCenter, const [0, .28]),
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (r) => fade(r, Alignment.centerLeft, Alignment.centerRight, const [0, .22]),
        child: Image.asset('assets/images/login_hero.webp', fit: BoxFit.cover, alignment: Alignment.bottomCenter),
      ),
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const StadiumBorder(),
      elevation: 1.5,
      shadowColor: const Color(0x332B1270),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.language_rounded, size: 18, color: AppColors.text),
              const SizedBox(width: 6),
              Text(
                'English',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.text),
              ),
              Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: AppColors.text),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({required this.mark, required this.label, required this.onTap});

  final Widget mark;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 40),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mark,
          const SizedBox(width: 7),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}

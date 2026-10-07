import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:asset360_mobile/app/router/routes.dart';
import 'package:asset360_mobile/app/theme/app_colors.dart';
import 'package:asset360_mobile/data/repositories/session_repository.dart';
import 'package:asset360_mobile/features/auth/auth_widgets.dart';

/// Continues the native splash: logo on lavender for ~1 s, then Login
/// (or Home when the user is still signed in with "Remember me" ticked).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const duration = Duration(milliseconds: 1000);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(SplashScreen.duration, () {
      if (!mounted) return;
      final s = ref.read(sessionProvider);
      context.go(s.loggedIn && s.rememberMe ? Routes.home : Routes.login);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackground(
      wash: false,
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .85, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutBack,
          builder: (_, s, child) => Transform.scale(scale: s, child: child),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipOval(
                child: Image.asset('assets/images/logo_on_light.png', width: 110, height: 110, fit: BoxFit.cover),
              ),
              const SizedBox(height: 16),
              const Text(
                'Purple IQ',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.brandText),
              ),
              const SizedBox(height: 4),
              Text(
                'Asset360',
                style: TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

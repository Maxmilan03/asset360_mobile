import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/settings_repository.dart';
import 'router/app_router.dart';
import 'theme/app_colors.dart';
import 'theme/app_theme.dart';

class Asset360App extends ConsumerStatefulWidget {
  const Asset360App({super.key});

  @override
  ConsumerState<Asset360App> createState() => _Asset360AppState();
}

class _Asset360AppState extends ConsumerState<Asset360App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Appearance "System" follows the phone's dark mode.
  @override
  void didChangePlatformBrightness() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    final platformDark = WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    final dark = mode == ThemeMode.dark || (mode == ThemeMode.system && platformDark);
    // Colors are read from AppColors while building, so a change of appearance rebuilds the
    // whole tree (the key); the router keeps the current location and all data stays.
    AppColors.dark = dark;
    return MaterialApp.router(
      key: ValueKey(dark),
      title: 'Asset360',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.current,
      routerConfig: ref.watch(routerProvider),
    );
  }
}

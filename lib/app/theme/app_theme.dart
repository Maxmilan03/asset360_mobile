import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

abstract final class AppRadius {
  static const card = 14.0;
  static const button = 10.0;
  static const tile = 12.0;
  static const sheet = 22.0;
  static const chip = 6.0;
}

abstract final class AppShadows {
  static List<BoxShadow> get card => [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: const Offset(0, 3))];
}

abstract final class AppTheme {
  static SystemUiOverlayStyle get headerOverlay => SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: AppColors.surface,
    systemNavigationBarIconBrightness: AppColors.dark ? Brightness.light : Brightness.dark,
  );

  /// The theme for the current [AppColors.dark] flag (light, or dark navy with the purple header kept).
  static ThemeData get current {
    final scheme = ColorScheme.fromSeed(
      brightness: AppColors.dark ? Brightness.dark : Brightness.light,
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.red,
    );
    const buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(AppRadius.button)));
    const buttonText = TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w600);
    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
      borderSide: BorderSide(color: c, width: w),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: AppColors.dark ? Brightness.dark : Brightness.light,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.divider,
      dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
      appBarTheme: AppBarTheme(systemOverlayStyle: headerOverlay),
      textTheme: const TextTheme().apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      iconTheme: IconThemeData(color: AppColors.text),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: .4),
          disabledForegroundColor: Colors.white,
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(64, 48),
          shape: buttonShape,
          side: BorderSide(color: AppColors.primary, width: 1.2),
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: buttonText.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13.5),
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.primary, 1.4),
        errorBorder: inputBorder(AppColors.red),
        focusedErrorBorder: inputBorder(AppColors.red, 1.4),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        side: BorderSide(color: AppColors.textMuted, width: 1.4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.border,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.text,
        ),
        contentTextStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.textSecondary, height: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13.5, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.tile)),
        textStyle: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.text),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: AppColors.primary, linearTrackColor: AppColors.divider),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

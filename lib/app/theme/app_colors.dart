import 'package:flutter/material.dart';

/// Every color in the app. Values were sampled from the images in design/
/// (median of small pixel regions), then rounded to clean brand values.
abstract final class AppColors {
  /// Dark appearance (Settings → Appearance). The app tree is rebuilt when it changes.
  static bool dark = false;

  // Brand
  static Color get primary =>
      dark ? const Color(0xFF8A6BF7) : const Color(0xFF5A23EC); // buttons, FAB, active tab, links
  static const primaryDark = Color(0xFF4A15D6); // pressed / Scan button gradient end
  static Color get primarySoft =>
      dark ? const Color(0xFF2C2260) : const Color(0xFFEFE8FD); // selected rows, active section bg

  // Header (slight vertical gradient)
  static const headerTop = Color(0xFF2B1270);
  static const headerBottom = Color(0xFF3B1B8C);
  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [headerTop, headerBottom],
  );

  // Sign-in screens
  static const authBackground = Color(0xFFF7F8FD); // matches the logo_on_light.png background
  static const authTop = Color(0xFFE8DEFD); // lavender wash at the top of Forgot / Authenticator
  static const brandText = Color(0xFF3A1C8E); // "Purple IQ" word mark on light backgrounds
  static const heroNavy = Color(0xFF110D42); // "Asset" in the login hero
  static const illustration = Color(0xFFA285F9); // soft violet of the envelope / clouds

  // Surfaces
  static Color get background => dark ? const Color(0xFF120F2A) : const Color(0xFFF6F5FB);
  static Color get surface => dark ? const Color(0xFF1E1A3A) : Colors.white;
  static Color get border => dark ? const Color(0xFF34305A) : const Color(0xFFE6E4EF);
  static Color get divider => dark ? const Color(0xFF2B2650) : const Color(0xFFEFEEF4);
  static Color get shadow => dark ? const Color(0x40000000) : const Color(0x142B1270);

  // Text
  static Color get text => dark ? const Color(0xFFECEAF7) : const Color(0xFF1A1446);
  static Color get textSecondary => dark ? const Color(0xFFB4AFCB) : const Color(0xFF6B6880);
  static Color get textMuted => dark ? const Color(0xFF8782A6) : const Color(0xFF9A98AC);
  static const onDark = Colors.white;
  static const onDarkMuted = Color(0xFFCFC6EC);

  // Bottom bar
  static Color get navInactive => dark ? const Color(0xFFC9C4E6) : const Color(0xFF2A2750);

  // Status (foreground on pale background)
  static const green = Color(0xFF1E9E5A);
  static Color get greenBg => dark ? const Color(0xFF16382A) : const Color(0xFFDDF7E9);
  static const amber = Color(0xFFC98506);
  static Color get amberBg => dark ? const Color(0xFF3D3015) : const Color(0xFFFFF1D3);
  static const orange = Color(0xFFE0701A);
  static Color get orangeBg => dark ? const Color(0xFF3F2A17) : const Color(0xFFFDEBD7);
  static const red = Color(0xFFE03A3A);
  static Color get redBg => dark ? const Color(0xFF421E25) : const Color(0xFFFFE1DD);
  static const blue = Color(0xFF2F6BD8);
  static Color get blueBg => dark ? const Color(0xFF1B2C4E) : const Color(0xFFE1EDFF);
  static const purple = Color(0xFF7A3FE4);
  static Color get purpleBg => dark ? const Color(0xFF2E2158) : const Color(0xFFEFE4FE);
  static Color get grey => dark ? const Color(0xFFA9A6C2) : const Color(0xFF5B5A74);
  static Color get greyBg => dark ? const Color(0xFF2A2745) : const Color(0xFFEFF0F5);

  static const badge = Color(0xFFEF3B3B); // bell count badge

  // Soft tile backgrounds (Home quick actions, hub tiles)
  static Color get tileLavender => dark ? const Color(0xFF2B2358) : const Color(0xFFEFE8FD);
  static Color get tileMint => dark ? const Color(0xFF173A30) : const Color(0xFFE2F8EE);
  static Color get tilePeach => dark ? const Color(0xFF3D2D1A) : const Color(0xFFFEF3E2);
  static Color get tileSky => dark ? const Color(0xFF19304B) : const Color(0xFFE6F2FC);
  static Color get tilePink => dark ? const Color(0xFF3E1F2B) : const Color(0xFFFDEEF1);
  static Color get tileCyan => dark ? const Color(0xFF153936) : const Color(0xFFE4F8F7);
  static Color get tileGrey => dark ? const Color(0xFF26233F) : const Color(0xFFF1F3F7);

  // Icon colors used on the soft tiles
  static const iconViolet = Color(0xFF5B2BE0);
  static const iconBlue = Color(0xFF2F7DE1);
  static const iconGreen = Color(0xFF22A565);
  static const iconOrange = Color(0xFFF08A1C);
  static const iconRed = Color(0xFFE5484D);
  static const iconTeal = Color(0xFF14A89A);
}

/// A soft background + matching icon color, used by tiles.
class TileTone {
  const TileTone(this.background, this.foreground);
  final Color background;
  final Color foreground;

  static TileTone get lavender => TileTone(AppColors.tileLavender, AppColors.iconViolet);
  static TileTone get mint => TileTone(AppColors.tileMint, AppColors.iconGreen);
  static TileTone get peach => TileTone(AppColors.tilePeach, AppColors.iconOrange);
  static TileTone get sky => TileTone(AppColors.tileSky, AppColors.iconBlue);
  static TileTone get pink => TileTone(AppColors.tilePink, AppColors.iconRed);
  static TileTone get cyan => TileTone(AppColors.tileCyan, AppColors.iconTeal);
  static TileTone get grey => TileTone(AppColors.tileGrey, AppColors.grey);
}

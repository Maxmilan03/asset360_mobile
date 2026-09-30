import 'package:flutter/material.dart';

/// Every color in the app. Values were sampled from the images in design/
/// (median of small pixel regions), then rounded to clean brand values.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF5A23EC); // buttons, FAB, active tab, links
  static const primaryDark = Color(0xFF4A15D6); // pressed / Scan button gradient end
  static const primarySoft = Color(0xFFEFE8FD); // selected rows, active section bg

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
  static const background = Color(0xFFF6F5FB);
  static const surface = Colors.white;
  static const border = Color(0xFFE6E4EF);
  static const divider = Color(0xFFEFEEF4);
  static const shadow = Color(0x142B1270);

  // Text
  static const text = Color(0xFF1A1446);
  static const textSecondary = Color(0xFF6B6880);
  static const textMuted = Color(0xFF9A98AC);
  static const onDark = Colors.white;
  static const onDarkMuted = Color(0xFFCFC6EC);

  // Bottom bar
  static const navInactive = Color(0xFF2A2750);

  // Status (foreground on pale background)
  static const green = Color(0xFF1E9E5A);
  static const greenBg = Color(0xFFDDF7E9);
  static const amber = Color(0xFFC98506);
  static const amberBg = Color(0xFFFFF1D3);
  static const orange = Color(0xFFE0701A);
  static const orangeBg = Color(0xFFFDEBD7);
  static const red = Color(0xFFE03A3A);
  static const redBg = Color(0xFFFFE1DD);
  static const blue = Color(0xFF2F6BD8);
  static const blueBg = Color(0xFFE1EDFF);
  static const purple = Color(0xFF7A3FE4);
  static const purpleBg = Color(0xFFEFE4FE);
  static const grey = Color(0xFF5B5A74);
  static const greyBg = Color(0xFFEFF0F5);

  static const badge = Color(0xFFEF3B3B); // bell count badge

  // Soft tile backgrounds (Home quick actions, hub tiles)
  static const tileLavender = Color(0xFFEFE8FD);
  static const tileMint = Color(0xFFE2F8EE);
  static const tilePeach = Color(0xFFFEF3E2);
  static const tileSky = Color(0xFFE6F2FC);
  static const tilePink = Color(0xFFFDEEF1);
  static const tileCyan = Color(0xFFE4F8F7);
  static const tileGrey = Color(0xFFF1F3F7);

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

  static const lavender = TileTone(AppColors.tileLavender, AppColors.iconViolet);
  static const mint = TileTone(AppColors.tileMint, AppColors.iconGreen);
  static const peach = TileTone(AppColors.tilePeach, AppColors.iconOrange);
  static const sky = TileTone(AppColors.tileSky, AppColors.iconBlue);
  static const pink = TileTone(AppColors.tilePink, AppColors.iconRed);
  static const cyan = TileTone(AppColors.tileCyan, AppColors.iconTeal);
  static const grey = TileTone(AppColors.tileGrey, AppColors.grey);
}

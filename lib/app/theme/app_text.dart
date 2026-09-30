import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Text styles measured against design/ (phone width ≈ 390 logical px).
abstract final class AppText {
  static const pageTitle = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.2);
  static const pageSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.35,
  );
  static const sectionTitle = TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text);
  static const cardTitle = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.text);
  static const bodyStrong = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text);
  static const secondary = TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const caption = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static const link = TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary);
  static const chip = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static const kpiNumber = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text);
}

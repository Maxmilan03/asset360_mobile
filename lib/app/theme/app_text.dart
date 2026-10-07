import 'package:flutter/material.dart';

import 'package:asset360_mobile/app/theme/app_colors.dart';

/// Text styles measured against design/ (phone width ≈ 390 logical px).
abstract final class AppText {
  static TextStyle get pageTitle =>
      TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.2);
  static TextStyle get pageSubtitle =>
      TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.35);
  static TextStyle get sectionTitle => TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get cardTitle => TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get body => TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: AppColors.text);
  static TextStyle get bodyStrong => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text);
  static TextStyle get secondary =>
      TextStyle(fontSize: 12.5, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get caption =>
      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w400, color: AppColors.textSecondary);
  static TextStyle get link => TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.primary);
  static const chip = TextStyle(fontSize: 12, fontWeight: FontWeight.w500);
  static TextStyle get kpiNumber => TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.text);
}

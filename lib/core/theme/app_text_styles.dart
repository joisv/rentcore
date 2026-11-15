import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Centralized typography tokens extracted from the baseline "Daftar Aset"
/// and "Pengaturan" page headers.
class AppTextStyles {
  AppTextStyles._();

  static const double pageHeaderToolbarHeight = kToolbarHeight;
  static const double pageHeaderHorizontalPadding = 16.0;

  static const TextStyle pageHeader = TextStyle(
    color: AppColors.obsidian,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
  );
}

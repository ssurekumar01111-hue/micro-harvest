import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle displayLarge = GoogleFonts.playfairDisplay(
    fontSize: 57,
    fontWeight: FontWeight.w400,
    color: AppColors.bark,
  );

  static TextStyle displayMedium = GoogleFonts.playfairDisplay(
    fontSize: 45,
    fontWeight: FontWeight.w400,
    color: AppColors.bark,
  );

  static TextStyle headlineLarge = GoogleFonts.playfairDisplay(
    fontSize: 32,
    fontWeight: FontWeight.w400,
    color: AppColors.bark,
  );

  static TextStyle titleLarge = GoogleFonts.dmSans(
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.bark,
  );

  static TextStyle bodyLarge = GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.bark,
  );

  static TextStyle bodyMedium = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.bark,
  );

  static TextStyle labelLarge = GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.bark,
  );
}

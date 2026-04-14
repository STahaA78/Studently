import 'package:flutter/material.dart';

class AppStyle {
  AppStyle._(); // Private constructor to prevent instantiation

  static const String appName = 'Studently';
  static const double defaultPadding = 16.0;
  
  // --- 1. Colors ---
  static const Color blue = Color(0xFF0F74C7);
  static const Color white = Colors.white;
  // --- 2. Dimensions ---
  static const double logoSize = 50.0;      
  static const double titleFontSize = 36.0;  // Studently Title Size
  static const signUpPageTitleLeftPadding = 30.0;
  static const backButtonLeftPadding = 20.0;
  static const backButtonBottomPadding = 20.0;
  static const double signUpPageHeadingFontSize = 35.0; // Headings
  //Small Helper Text
  static const double smallFontSize = 18.0;
  static const FontWeight smallFontWeight = FontWeight.w500;

  static const double formFieldBorderSize = 1.0;
  static const double formFieldRadius = 16.0;   

  // --- 3. Spacing ---
  static const double verticalSpacingNormal = 16.0;
  static const double verticalSpacingLarge = 24.0;
  static const double verticalSpacingSmall = 14.0;
  static const EdgeInsets normalVerticalHorizontalPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 10);
  static const EdgeInsets normalVerticalPadding = EdgeInsets.symmetric(vertical: 10);
}
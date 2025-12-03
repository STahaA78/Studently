import 'package:flutter/material.dart';

class AppStyle {
  AppStyle._(); // Private constructor to prevent instantiation

  static const String appName = 'Studently';
  static const double defaultPadding = 16.0;
  
  // --- 1. Colors ---
  static const Color blue = Color(0xFF0F74C7);
  static const Color white = Colors.white;
  // --- 2. Dimensions (Your Specific Requests) ---
  static const double logoSize = 45.0;       
  static const double titleFontSize = 36.0;  
  //Small Helper Text
  static const double smallFontSize = 18.0;
  static const FontWeight smallFontWeight = FontWeight.w500;

  static const double formFieldBorderSize = 2.0;
  static const double formFieldRadius = 16.0;   

  // --- 3. Spacing ---
  static const double verticalSpacingNormal = 16.0;
  static const double verticalSpacingLarge = 24.0;
  static const double verticalSpacingSmall = 10.0;
  static const EdgeInsets normalVerticalHorizontalPadding = EdgeInsets.symmetric(horizontal: 8, vertical: 16);
  static const EdgeInsets normalVerticalPadding = EdgeInsets.symmetric(vertical: 16);
}
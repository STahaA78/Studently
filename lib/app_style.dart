import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppStyle {
  AppStyle._(); // Private constructor to prevent instantiation

  static const String appName = 'Studently';
  static const double defaultPadding = 16.0;

  // --- 1. Colors ---
  static const Color primaryBlue = Colors.blue; // Instagram-like action blue
  static const Color primaryDark = Color(0xFF1877F2); // Facebook-like dark blue
  static const Color backgroundLight = Color.fromARGB(255, 250, 250, 251);

  static const Color pureWhite = Colors.white;
  static const Color textPrimary = Color(0xFF262626); // Clean dark gray/black
  static const Color textSecondary = Color(
    0xFF8E8E8E,
  ); // Instagram helper text gray
  static const Color borderLight = Color(
    0xFFDBDBDB,
  ); // Classic subtle border color
  static const Color errorRed = Color(0xFFED4956); // Instagram error red

  static const Color blue = primaryBlue;
  static const Color white = pureWhite;

  // --- 2. Dimensions ---
  static const double logoSize = 50.0;
  static const double titleFontSize = 36.0; // Studently Title Size
  static const double signUpPageTitleLeftPadding = 30.0;
  static const double backButtonLeftPadding = 20.0;
  static const double backButtonBottomPadding = 20.0;
  static const double signUpPageHeadingFontSize = 35.0; // Headings

  // Font Sizes
  static const double heading1Size = 28.0;
  static const double heading2Size = 22.0;
  static const double bodyTextSize = 16.0;
  static const double smallFontSize = 14.0;
  static const FontWeight smallFontWeight = FontWeight.w500;
  static const double lineHeight = 1.4; // Clean, readable line height

  static const double formFieldBorderSize = 1.0;
  static const double formFieldRadius = 12.0; // Modern slightly softer radius

  // --- 3. Spacing ---
  static const double verticalSpacingNormal = 16.0;
  static const double verticalSpacingLarge = 24.0;
  static const double verticalSpacingSmall = 14.0;
  static const EdgeInsets normalVerticalHorizontalPadding =
      EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets normalVerticalPadding = EdgeInsets.symmetric(
    vertical: 12,
  );
  
  // --- 4. Theme ---
  static ThemeData get theme {
    var baseTheme = ThemeData.light();
    return ThemeData(
      primaryColor: primaryBlue,
      scaffoldBackgroundColor: pureWhite,
      hoverColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        error: errorRed,
        surface: pureWhite,
      ),
      textTheme: GoogleFonts.interTextTheme(baseTheme.textTheme).copyWith(
        bodyLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: bodyTextSize,
          height: lineHeight,
        ),
        bodyMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: bodyTextSize,
          height: lineHeight,
        ),
        bodySmall: GoogleFonts.inter(
          color: textSecondary,
          fontSize: smallFontSize,
          height: lineHeight,
        ),
        titleLarge: GoogleFonts.inter(
          color: textPrimary,
          fontSize: heading1Size,
          fontWeight: FontWeight.bold,
          height: 1.2,
        ),
        titleMedium: GoogleFonts.inter(
          color: textPrimary,
          fontSize: heading2Size,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pureWhite,
        elevation: 0,
        scrolledUnderElevation: 0, // Flat clean look
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: GoogleFonts.inter(color: textSecondary, fontSize: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(formFieldRadius),
          borderSide: const BorderSide(
            color: borderLight,
            width: formFieldBorderSize,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(formFieldRadius),
          borderSide: const BorderSide(
            color: borderLight,
            width: formFieldBorderSize,
          ), // Keep borders clean
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(formFieldRadius),
          borderSide: const BorderSide(
            color: errorRed,
            width: formFieldBorderSize,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(formFieldRadius),
          borderSide: const BorderSide(
            color: errorRed,
            width: formFieldBorderSize,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: pureWhite,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              8,
            ), // Standard clean button shape
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: pureWhite,
          foregroundColor: textPrimary,
          side: const BorderSide(
            color: borderLight,
            width: formFieldBorderSize,
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
  // custom search decoration for search fields
  static InputDecoration searchDecoration(String hint) {
  return InputDecoration(
    hintText: hint,
    prefixIcon: Icon(
      Icons.search,
      color: Colors.grey.shade700, // 👈 icon color
    ),
    filled: true,
    fillColor: backgroundLight,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide.none,
    ),
  );
}
}

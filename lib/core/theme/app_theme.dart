import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static TextStyle _safeFont({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = Colors.white,
    double? letterSpacing,
  }) {
    try {
      return GoogleFonts.inter(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
      );
    } catch (_) {
      return TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        letterSpacing: letterSpacing,
        fontFamily: 'Segoe UI',
      );
    }
  }

  static ThemeData get darkTheme {
    GoogleFonts.config.allowRuntimeFetching = true;

    TextTheme baseTextTheme;
    try {
      baseTextTheme = GoogleFonts.interTextTheme(ThemeData.dark().textTheme);
    } catch (_) {
      baseTextTheme = ThemeData.dark().textTheme;
    }

    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppConstants.darkBackground, // #050B18 Level 1
      primaryColor: AppConstants.primaryBlue,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.primaryBlue,
        secondary: AppConstants.accentCyan,
        surface: AppConstants.darkSurface,
        error: AppConstants.colorCritical,
      ),
      cardTheme: CardThemeData(
        color: AppConstants.darkCardBackground, // Glass Level 3 rgba(20, 35, 60, 0.55)
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.0),
          side: const BorderSide(color: AppConstants.darkCardBorder, width: 1.0),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppConstants.darkBackground,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _safeFont(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xCC081225), // Glass Level 2
        selectedItemColor: AppConstants.accentCyan,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      textTheme: baseTextTheme.copyWith(
        displayLarge: _safeFont(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
        titleLarge: _safeFont(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
        bodyLarge: _safeFont(fontSize: 16, color: Colors.white70),
        bodyMedium: _safeFont(fontSize: 14, color: Colors.white60),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppConstants.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.darkCardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.darkCardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppConstants.accentCyan, width: 1.5),
        ),
        labelStyle: const TextStyle(color: Colors.white70),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppConstants.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: _safeFont(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}


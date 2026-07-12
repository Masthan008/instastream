import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LiquidGlassTheme {
  // Brand Colors
  static const Color primaryGreen = Color(0xFF10B981); // Emerald Green
  static const Color primaryBlue = Color(0xFF06B6D4);  // Teal Blue
  static const Color secondaryGreen = Color(0xFF34D399);
  static const Color secondaryBlue = Color(0xFF22D3EE);

  // Neutral Colors (Light Theme)
  static const Color backgroundStart = Color(0xFFF5F8FA);
  static const Color backgroundEnd = Color(0xFFEBF1F5);
  static const Color textDark = Color(0xFF1E293B);      // Slate 800
  static const Color textLight = Color(0xFF64748B);     // Slate 500
  static const Color cardBg = Color(0xA6FFFFFF);        // White with 65% opacity for frosted glass
  static const Color borderLight = Color(0x66FFFFFF);   // Border with 40% opacity
  static const Color shadowColor = Color(0x1F06B6D4);   // Soft Blue shadow

  // Neutral Colors (Dark Theme)
  static const Color darkBackgroundStart = Color(0xFF0B0F19);
  static const Color darkBackgroundEnd = Color(0xFF020617);
  static const Color darkTextDark = Color(0xFFF8FAFC);     // Slate 50
  static const Color darkTextLight = Color(0xFF94A3B8);    // Slate 400
  static const Color darkCardBg = Color(0x26FFFFFF);       // White with 15% opacity for dark frosted glass
  static const Color darkBorderLight = Color(0x1AFFFFFF);  // White with 10% opacity for dark border
  static const Color darkShadowColor = Color(0x3D000000);  // Darker drop shadow

  // Linear Gradients
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryGreen, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundStart, backgroundEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient darkBackgroundGradient = LinearGradient(
    colors: [darkBackgroundStart, darkBackgroundEnd],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Frosted Glass Decoration Helper
  static BoxDecoration glassDecoration({
    double radius = 24.0,
    Color? color,
    bool showBorder = true,
    bool isDark = false,
  }) {
    final activeColor = color ?? (isDark ? darkCardBg : cardBg);
    final activeBorderColor = isDark ? darkBorderLight : borderLight;
    final activeShadowColor = isDark ? darkShadowColor : shadowColor;
    return BoxDecoration(
      color: activeColor,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius * 0.75), // slightly organic/asymmetric liquid shape
        bottomLeft: Radius.circular(radius * 0.75),
        bottomRight: Radius.circular(radius),
      ),
      border: showBorder ? Border.all(color: activeBorderColor, width: 1.5) : null,
      boxShadow: [
        BoxShadow(
          color: activeShadowColor,
          blurRadius: 20,
          spreadRadius: 1,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  // ThemeData getter
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: primaryBlue,
        background: backgroundStart,
      ),
      scaffoldBackgroundColor: Colors.transparent, // transparency allows gradient background to show through
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textDark,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: textDark,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: textLight,
          fontSize: 14,
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryGreen,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryGreen,
        primary: primaryGreen,
        secondary: primaryBlue,
        brightness: Brightness.dark,
        background: darkBackgroundStart,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: GoogleFonts.outfitTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: darkTextDark,
          fontWeight: FontWeight.bold,
          fontSize: 32,
        ),
        titleLarge: GoogleFonts.outfit(
          color: darkTextDark,
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
        bodyLarge: GoogleFonts.outfit(
          color: darkTextDark,
          fontSize: 16,
        ),
        bodyMedium: GoogleFonts.outfit(
          color: darkTextLight,
          fontSize: 14,
        ),
      ),
    );
  }
}

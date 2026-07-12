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

  // Frosted Glass Decoration Helper
  static BoxDecoration glassDecoration({
    double radius = 24.0,
    Color color = cardBg,
    bool showBorder = true,
  }) {
    return BoxDecoration(
      color: color,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(radius),
        topRight: Radius.circular(radius * 0.75), // slightly organic/asymmetric liquid shape
        bottomLeft: Radius.circular(radius * 0.75),
        bottomRight: Radius.circular(radius),
      ),
      border: showBorder ? Border.all(color: borderLight, width: 1.5) : null,
      boxShadow: [
        BoxShadow(
          color: shadowColor,
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
}

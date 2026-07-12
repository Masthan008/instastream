import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';

class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseGradient = isDark ? LiquidGlassTheme.darkBackgroundGradient : LiquidGlassTheme.backgroundGradient;
    final topGlowColor = isDark ? const Color(0xFF7C3AED).withOpacity(0.18) : LiquidGlassTheme.primaryGreen.withOpacity(0.18);
    final bottomGlowColor = isDark ? const Color(0xFF6366F1).withOpacity(0.15) : LiquidGlassTheme.primaryBlue.withOpacity(0.15);
    final centerGlowColor = isDark ? const Color(0xFFEC4899).withOpacity(0.08) : LiquidGlassTheme.secondaryGreen.withOpacity(0.08);

    return Stack(
      children: [
        // 1. Background base gradient
        Container(
          decoration: BoxDecoration(
            gradient: baseGradient,
          ),
        ),
        
        // 2. Liquid glowing blob - Green (Top Left)
        Positioned(
          top: -100,
          left: -50,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: topGlowColor,
            ),
          ),
        ),

        // 3. Liquid glowing blob - Blue (Bottom Right)
        Positioned(
          bottom: -120,
          right: -60,
          child: Container(
            width: 350,
            height: 350,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bottomGlowColor,
            ),
          ),
        ),

        // 4. Liquid glowing blob - Mint (Center Left)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: -150,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: centerGlowColor,
            ),
          ),
        ),

        // 5. Foreground Content
        SafeArea(
          child: child,
        ),
      ],
    );
  }
}

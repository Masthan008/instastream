import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';

class LiquidBackground extends StatelessWidget {
  final Widget child;

  const LiquidBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Background base gradient
        Container(
          decoration: const BoxDecoration(
            gradient: LiquidGlassTheme.backgroundGradient,
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
              color: LiquidGlassTheme.primaryGreen.withOpacity(0.18),
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
              color: LiquidGlassTheme.primaryBlue.withOpacity(0.15),
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
              color: LiquidGlassTheme.secondaryGreen.withOpacity(0.08),
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

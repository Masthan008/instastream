import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/constants/theme.dart';

class GlassmorphicCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final bool showBorder;

  const GlassmorphicCard({
    Key? key,
    required this.child,
    this.radius = 24.0,
    this.padding,
    this.margin,
    this.color,
    this.showBorder = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius * 0.75),
          bottomLeft: Radius.circular(radius * 0.75),
          bottomRight: Radius.circular(radius),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16.0),
            decoration: LiquidGlassTheme.glassDecoration(
              radius: radius,
              color: color ?? LiquidGlassTheme.cardBg,
              showBorder: showBorder,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

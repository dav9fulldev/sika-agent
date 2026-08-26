import 'dart:ui';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SikaGlassCard extends StatelessWidget {
  final Widget child;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final BorderRadiusGeometry? borderRadius;
  final Color? borderColor;

  const SikaGlassCard({
    super.key,
    required this.child,
    this.blur = 20.0,
    this.opacity = 0.2,
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = BorderRadius.circular(20);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surface;
    final defaultBorderColor = isDark 
        ? AppColors.brandPrimary.withValues(alpha: 0.15) 
        : AppColors.brandPrimary.withValues(alpha: 0.08);

    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: borderRadius ?? defaultRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: glassColor.withValues(alpha: opacity),
              borderRadius: borderRadius ?? defaultRadius,
              border: Border.all(
                color: borderColor ?? defaultBorderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

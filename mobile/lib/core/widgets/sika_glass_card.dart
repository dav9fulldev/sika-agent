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
    this.opacity = 0.2, // Default optimized for Dark Mode
    this.padding = const EdgeInsets.all(16.0),
    this.margin = EdgeInsets.zero,
    this.borderRadius,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final defaultRadius = BorderRadius.circular(20);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // In light mode, we need higher opacity for the glass effect to be visible
    // and provide enough contrast against the background.
    final effectiveOpacity = isDark ? opacity : (opacity + 0.5).clamp(0.0, 1.0);
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
              color: glassColor.withValues(alpha: effectiveOpacity),
              borderRadius: borderRadius ?? defaultRadius,
              border: Border.all(
                color: borderColor ?? defaultBorderColor,
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
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


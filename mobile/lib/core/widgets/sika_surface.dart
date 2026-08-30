import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';

/// SikaSurface — Le composant fondamental (Figma-first) de SIKA V2.0.
/// Remplace l'abus de Glassmorphism.
/// 
/// En Light Mode : Fond blanc pur avec une ombre très douce (Glow).
/// En Dark Mode : Fond "Surface" sombre avec une bordure très subtile (pas d'ombre).
class SikaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final BorderRadiusGeometry? borderRadius;
  final VoidCallback? onTap;

  const SikaSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.margin,
    this.width,
    this.height,
    this.borderRadius,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = borderRadius ?? AppSpacing.borderRadiusLg;

    final decoration = BoxDecoration(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      borderRadius: radius,
      border: isDark 
          ? Border.all(color: AppColors.darkBorderSubtle, width: 1)
          : null,
      boxShadow: isDark ? null : AppSpacing.lightShadow,
    );

    Widget content = Container(
      width: width,
      height: height,
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: child,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius as BorderRadius,
          splashColor: (isDark ? AppColors.darkPrimarySoft : AppColors.lightPrimarySoft).withValues(alpha: 0.2),
          highlightColor: Colors.transparent,
          child: content,
        ),
      );
    }

    return content;
  }
}

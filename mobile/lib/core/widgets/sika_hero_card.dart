import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';
import 'sika_surface.dart';

/// SikaHeroCard — Le composant "Hero" (Figma-first) de SIKA V2.0.
/// Conçu spécifiquement pour afficher le solde principal ou des métriques vitales
/// avec une hiérarchie visuelle extrêmement forte et élégante.
class SikaHeroCard extends StatelessWidget {
  final String title;
  final String amount;
  final String? subtitle;
  final String? pctChange;
  final bool isPositiveChange;
  final Widget? trailingWidget;

  const SikaHeroCard({
    super.key,
    required this.title,
    required this.amount,
    this.subtitle,
    this.pctChange,
    this.isPositiveChange = true,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SikaSurface(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: AppTypography.h3.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              if (trailingWidget != null) trailingWidget!,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            amount,
            style: AppTypography.display.copyWith(
              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
            ),
          ),
          if (subtitle != null || pctChange != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (pctChange != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
                    decoration: BoxDecoration(
                      color: isPositiveChange 
                          ? (isDark ? AppColors.successSoftDark : AppColors.successSoft)
                          : (isDark ? AppColors.errorSoftDark : AppColors.errorSoft),
                      borderRadius: AppSpacing.borderRadiusXs,
                    ),
                    child: Text(
                      pctChange!,
                      style: AppTypography.caption.copyWith(
                        color: isPositiveChange ? AppColors.success : AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (pctChange != null && subtitle != null) 
                  const SizedBox(width: AppSpacing.sm),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

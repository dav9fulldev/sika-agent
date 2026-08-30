import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SikaBudgetProgress extends StatelessWidget {
  final String title;
  final double currentAmount;
  final double targetAmount;
  final String currentAmountFormatted;
  final String targetAmountFormatted;
  final Color? trackColor;
  final Color? progressColor;
  final Widget? icon;

  const SikaBudgetProgress({
    super.key,
    required this.title,
    required this.currentAmount,
    required this.targetAmount,
    required this.currentAmountFormatted,
    required this.targetAmountFormatted,
    this.trackColor,
    this.progressColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final double ratio = targetAmount > 0 
        ? (currentAmount / targetAmount).clamp(0.0, 1.0) 
        : 0.0;
    
    final bool isGoalReached = ratio >= 1.0;
    final Color effectiveProgressColor = progressColor ?? (isGoalReached ? AppColors.success : AppColors.brandSecondary);
    final Color effectiveTrackColor = trackColor ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  icon!,
                  const SizedBox(width: 8),
                ],
                Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            Text(
              '${(ratio * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                color: effectiveProgressColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Track
            Container(
              height: 8,
              decoration: BoxDecoration(
                color: effectiveTrackColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            // Progress
            FractionallySizedBox(
              widthFactor: ratio,
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: effectiveProgressColor,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    if (ratio > 0.1)
                      BoxShadow(
                        color: effectiveProgressColor.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              currentAmountFormatted,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              targetAmountFormatted,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

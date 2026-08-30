import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'sika_premium_button.dart';

class SikaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? buttonText;
  final VoidCallback? onActionPressed;

  const SikaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.buttonText,
    this.onActionPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                ),
              ),
              child: Icon(
                icon,
                size: 48,
                color: AppColors.textMuted,
              ),
            ).animate().fade().scale(delay: 100.ms, duration: 400.ms),
            
            const SizedBox(height: AppSpacing.lg),
            
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
            
            const SizedBox(height: AppSpacing.sm),
            
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
            
            if (buttonText != null && onActionPressed != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: SikaPremiumButton(
                  onPressed: onActionPressed,
                  text: buttonText!,
                  isSecondary: true,
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

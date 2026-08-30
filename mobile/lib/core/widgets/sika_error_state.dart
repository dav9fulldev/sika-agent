import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import 'sika_premium_button.dart';

class SikaErrorState extends StatelessWidget {
  final String title;
  final String message;
  final String? retryText;
  final VoidCallback? onRetryPressed;

  const SikaErrorState({
    super.key,
    this.title = 'Une erreur est survenue',
    required this.message,
    this.retryText = 'Réessayer',
    this.onRetryPressed,
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
                color: isDark ? AppColors.errorSoftDark : AppColors.errorSoft,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
            ).animate().fade().scale(delay: 100.ms, duration: 400.ms, curve: Curves.elasticOut),
            
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
            
            if (onRetryPressed != null) ...[
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: SikaPremiumButton(
                  onPressed: onRetryPressed,
                  text: retryText ?? 'Réessayer',
                  prefixWidget: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                ),
              ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
            ],
          ],
        ),
      ),
    );
  }
}

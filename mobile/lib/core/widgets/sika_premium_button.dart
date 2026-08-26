import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SikaPremiumButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final String text;
  final Widget? prefixWidget;
  final bool isLoading;
  final bool isSecondary;
  final double height;
  final double width;

  const SikaPremiumButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.prefixWidget,
    this.isLoading = false,
    this.isSecondary = false,
    this.height = 56.0,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryGradient = LinearGradient(
      colors: [AppColors.brandPrimary, AppColors.brandSecondary],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final secondaryGradient = LinearGradient(
      colors: isDark 
          ? [Colors.white.withValues(alpha: 0.1), Colors.white.withValues(alpha: 0.05)]
          : [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.02)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isDisabled = onPressed == null || isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: height,
      width: width,
      decoration: BoxDecoration(
        gradient: isSecondary ? secondaryGradient : primaryGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isDisabled || isSecondary
            ? []
            : [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
        border: isSecondary 
            ? Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1))
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: InkWell(
            onTap: isDisabled ? null : onPressed,
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.white.withValues(alpha: 0.2),
            highlightColor: Colors.white.withValues(alpha: 0.1),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (prefixWidget != null) ...[
                          prefixWidget!,
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: isSecondary 
                                ? Theme.of(context).colorScheme.onSurface 
                                : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

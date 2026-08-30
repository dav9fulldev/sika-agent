import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

class SikaPremiumButton extends StatefulWidget {
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
  State<SikaPremiumButton> createState() => _SikaPremiumButtonState();
}

class _SikaPremiumButtonState extends State<SikaPremiumButton> {
  bool _isPressed = false;

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
          ? [AppColors.darkSurfaceElevated, AppColors.darkSurface]
          : [AppColors.lightSurface, AppColors.lightBorderSubtle],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    final isDisabled = widget.onPressed == null || widget.isLoading;
    final scale = _isPressed && !isDisabled ? 0.96 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 100),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          gradient: widget.isSecondary ? secondaryGradient : primaryGradient,
          borderRadius: AppSpacing.borderRadiusMd,
          boxShadow: isDisabled || widget.isSecondary || _isPressed
              ? []
              : [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
          border: widget.isSecondary 
              ? Border.all(color: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderStrong)
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: Opacity(
            opacity: isDisabled ? 0.5 : 1.0,
            child: InkWell(
              onTap: isDisabled ? null : widget.onPressed,
              onHighlightChanged: (isHighlight) {
                if (!isDisabled) {
                  setState(() {
                    _isPressed = isHighlight;
                  });
                }
              },
              borderRadius: AppSpacing.borderRadiusMd,
              splashColor: Colors.white.withValues(alpha: 0.2),
              highlightColor: Colors.white.withValues(alpha: 0.1),
              child: Center(
                child: widget.isLoading
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
                          if (widget.prefixWidget != null) ...[
                            widget.prefixWidget!,
                            const SizedBox(width: 8),
                          ],
                          Text(
                            widget.text,
                            style: AppTypography.bodyLarge.copyWith(
                              color: widget.isSecondary 
                                  ? Theme.of(context).colorScheme.onSurface 
                                  : Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

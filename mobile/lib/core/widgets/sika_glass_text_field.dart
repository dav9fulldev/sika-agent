import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_spacing.dart';
import '../constants/app_typography.dart';

class SikaGlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLines;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;

  const SikaGlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.onSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final bgColor = isDark 
        ? AppColors.darkSurfaceElevated 
        : AppColors.lightSurface;

    final borderColor = isDark 
        ? AppColors.darkBorderStrong
        : AppColors.lightBorderStrong;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(color: borderColor),
      ),
      child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            onSubmitted: onSubmitted,
            style: AppTypography.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTypography.bodyMedium.copyWith(
                color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary,
              ),
              prefixIcon: prefixIcon != null 
                  ? Icon(prefixIcon, color: AppColors.brandSecondary) 
                  : null,
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
    );
  }
}


import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SikaGlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLines;

  const SikaGlassTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      decoration: BoxDecoration(
        color: (isDark ? AppColors.darkSurface : Theme.of(context).colorScheme.surface).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: (isDark ? Colors.white : AppColors.brandPrimary).withValues(alpha: 0.1),
        ),
      ),
      child: TextField(
            controller: controller,
            obscureText: obscureText,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)
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

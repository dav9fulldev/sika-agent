import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SikaFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const SikaFloatingButton({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.mic_rounded,
          color: Theme.of(context).colorScheme.onSurface,
          size: 28,
        ),
      ),
    );
  }
}

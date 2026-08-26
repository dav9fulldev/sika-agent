import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class SikaServiceToggle extends StatelessWidget {
  final bool isRunning;
  final ValueChanged<bool> onChanged;

  const SikaServiceToggle({
    super.key,
    required this.isRunning,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      value: isRunning,
      onChanged: onChanged,
      activeThumbColor: AppColors.success,
      activeTrackColor: AppColors.success.withValues(alpha: 0.2),
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.border,
      title: Text(
        'Service Vocal SIKA (Wake-word)',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        isRunning ? 'Service natif actif (écoute "Sika")' : 'Service inactif',
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_colors.dart';
import '../providers/language_provider.dart';

class SikaServiceToggle extends ConsumerWidget {
  final bool isRunning;
  final ValueChanged<bool> onChanged;

  const SikaServiceToggle({
    super.key,
    required this.isRunning,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    return SwitchListTile(
      value: isRunning,
      onChanged: onChanged,
      activeThumbColor: AppColors.success,
      activeTrackColor: AppColors.success.withValues(alpha: 0.2),
      inactiveThumbColor: AppColors.textSecondary,
      inactiveTrackColor: AppColors.border,
      title: Text(
        langNotifier.tr(
          'Service Vocal SIKA (Wake-word)',
          'SIKA Voice Service (Wake-word)',
        ),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        isRunning
            ? langNotifier.tr(
                'Service natif actif (écoute "Sika")',
                'Native service active (listening for "Sika")',
              )
            : langNotifier.tr('Service inactif', 'Service inactive'),
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
      ),
    );
  }
}

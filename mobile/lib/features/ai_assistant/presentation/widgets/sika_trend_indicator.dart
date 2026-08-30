import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SikaTrendIndicator extends ConsumerWidget {
  final double currentAmount;
  final double previousAmount;

  const SikaTrendIndicator({
    super.key,
    required this.currentAmount,
    required this.previousAmount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    // Si pas de données précédentes, on ne peut pas comparer.
    if (previousAmount <= 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          langNotifier.tr('Aucune donnée précédente', 'No previous data'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    // Calcul de la tendance
    final difference = currentAmount - previousAmount;
    final double percentage = (difference / previousAmount) * 100;
    
    final bool isIncrease = percentage > 0;
    final bool isStable = percentage.abs() < 1.0;

    // Couleurs et icônes
    // Attention : pour les dépenses, une baisse (négatif) est positif (vert), une hausse est négatif (ambre/rouge) ou informatif.
    Color color;
    IconData icon;
    String text;

    if (isStable) {
      color = AppColors.info;
      icon = Icons.trending_flat_rounded;
      text = langNotifier.tr('Dépenses stables', 'Stable expenses');
    } else if (isIncrease) {
      // Les dépenses ont augmenté
      color = AppColors.warning;
      icon = Icons.trending_up_rounded;
      text = langNotifier.tr(
        '+${percentage.abs().toStringAsFixed(1)}% vs période préc.',
        '+${percentage.abs().toStringAsFixed(1)}% vs prev. period'
      );
    } else {
      // Les dépenses ont diminué
      color = AppColors.success;
      icon = Icons.trending_down_rounded;
      text = langNotifier.tr(
        '-${percentage.abs().toStringAsFixed(1)}% vs période préc.',
        '-${percentage.abs().toStringAsFixed(1)}% vs prev. period'
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

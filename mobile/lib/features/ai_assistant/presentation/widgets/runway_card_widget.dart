import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';

/// RunwayCardWidget — Module Cœur SIKA: Indicateur d'Autonomie Financière (Financial Runway)
class RunwayCardWidget extends ConsumerWidget {
  final double totalBalanceFcfa;
  final double dailyBurnRateFcfa;

  const RunwayCardWidget({
    super.key,
    this.totalBalanceFcfa = 45000.0,
    this.dailyBurnRateFcfa = 2500.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);

    final int estimatedDays = (totalBalanceFcfa / dailyBurnRateFcfa).round();
    final Color badgeColor = estimatedDays > 15
        ? const Color(0xFF10B981) // Safely green
        : estimatedDays > 7
            ? const Color(0xFFF59E0B) // Amber warning
            : const Color(0xFFEF4444); // Red danger

    final String statusLabel = estimatedDays > 15
        ? langNotifier.tr('Sain', 'Healthy')
        : estimatedDays > 7
            ? langNotifier.tr('Attention', 'Warning')
            : langNotifier.tr('Critique', 'Critical');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1329),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.timer_outlined, color: Color(0xFF38BDF8), size: 16),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    langNotifier.tr('Autonomie financière (Runway)', 'Financial Runway'),
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.6)),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$estimatedDays',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                langNotifier.tr('jours d\'autonomie restante', 'days remaining'),
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Text(
            langNotifier.tr(
              'Basé sur un rythme moyen de ${currNotifier.format(dailyBurnRateFcfa)} / jour.',
              'Based on an average daily spend of ${currNotifier.format(dailyBurnRateFcfa)} / day.',
            ),
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../providers/sika_provider.dart';

/// SavingsBoosterCard — Module Cœur SIKA: Booster d'Épargne Autonome
class SavingsBoosterCard extends ConsumerWidget {
  final VoidCallback? onBoostConfirmed;

  const SavingsBoosterCard({
    super.key,
    this.onBoostConfirmed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);
    final sikaNotifier = ref.read(sikaProvider.notifier);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1329),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 16,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langNotifier.tr('Booster d\'Épargne Autonome', 'Autonomous Savings Booster'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text(
            langNotifier.tr(
              'En mettant de côté ${currNotifier.format(500)} aujourd\'hui, vous atteindrez votre objectif de ${currNotifier.format(80000)} avec 5 jours d\'avance !',
              'By putting aside ${currNotifier.format(500)} today, you will reach your ${currNotifier.format(80000)} target 5 days earlier!',
            ),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    sikaNotifier.sendTextMessage(
                      langNotifier.tr(
                        'Ajouter ${currNotifier.format(500)} à mon objectif d\'épargne.',
                        'Add ${currNotifier.format(500)} to my savings goal.',
                      ),
                    );
                    if (onBoostConfirmed != null) onBoostConfirmed!();
                  },
                  icon: const Icon(Icons.savings_outlined, color: Colors.white, size: 18),
                  label: Text(
                    langNotifier.tr('Épargner ${currNotifier.format(500)} maintenant', 'Boost ${currNotifier.format(500)} now'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

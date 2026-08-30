import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../providers/sika_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';

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

    final walletState = ref.watch(walletProvider);
    final firstCoffre =
        walletState.coffres.isNotEmpty ? walletState.coffres.first : null;
    final double targetAmount = firstCoffre != null && firstCoffre.objectif > 0
        ? firstCoffre.objectif
        : 500000.0;
    final String coffreName =
        firstCoffre?.nom ?? langNotifier.tr('Épargne', 'Savings');

    return SikaGlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                child: const Icon(Icons.trending_up_rounded,
                    color: Color(0xFF10B981), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langNotifier.tr('Booster d\'Épargne Autonome',
                      'Autonomous Savings Booster'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            langNotifier.tr(
              'En mettant de côté ${currNotifier.format(500)} aujourd\'hui, vous atteindrez votre coffre "$coffreName" (${currNotifier.format(targetAmount)}) avec 5 jours d\'avance !',
              'By putting aside ${currNotifier.format(500)} today, you will reach your "$coffreName" target (${currNotifier.format(targetAmount)}) 5 days earlier!',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: SikaPremiumButton(
              onPressed: () {
                sikaNotifier.sendTextMessage(
                  langNotifier.tr(
                    'Ajouter ${currNotifier.format(500)} à mon objectif d\'épargne.',
                    'Add ${currNotifier.format(500)} to my savings goal.',
                  ),
                );
                if (onBoostConfirmed != null) onBoostConfirmed!();
              },
              prefixWidget: Icon(Icons.savings_outlined,
                  color: Theme.of(context).colorScheme.onSurface, size: 18),
              text: langNotifier.tr(
                  'Épargner ${currNotifier.format(500)} maintenant',
                  'Boost ${currNotifier.format(500)} now'),
            ),
          ),
        ],
      ),
    );
  }
}


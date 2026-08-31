import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../providers/sika_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';

/// WalletRebalanceCard — Module Cœur SIKA: Équilibrage Intelligent Multi-Portefeuilles
class WalletRebalanceCard extends ConsumerWidget {
  final String? sourceWallet;
  final String? targetWallet;
  final double? sourceBalance;
  final double? recommendedAmount;
  final VoidCallback? onRebalanceConfirmed;

  const WalletRebalanceCard({
    super.key,
    this.sourceWallet,
    this.targetWallet,
    this.sourceBalance,
    this.recommendedAmount,
    this.onRebalanceConfirmed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);
    final sikaNotifier = ref.read(sikaProvider.notifier);

    if (sourceWallet == null ||
        targetWallet == null ||
        sourceBalance == null ||
        recommendedAmount == null) {
      return const SizedBox.shrink();
    }

    return SikaGlassCard(
      padding: const EdgeInsets.all(18),
      borderColor: const Color(0xFF635BFF).withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF635BFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz_rounded,
                    color: Color(0xFF635BFF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langNotifier.tr('Équilibrage Multi-Portefeuilles',
                      'Smart Wallet Auto-Balancer'),
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
              'Votre compte $targetWallet (${currNotifier.format(sourceBalance!)}) risque d\'être insuffisant pour vos dépenses de fin de semaine. SIKA suggère de transférer ${currNotifier.format(recommendedAmount!)} depuis $sourceWallet.',
              'Your $targetWallet account (${currNotifier.format(sourceBalance!)}) might fall short for weekend bills. SIKA suggests transferring ${currNotifier.format(recommendedAmount!)} from $sourceWallet.',
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
                    'Transférer ${currNotifier.format(recommendedAmount!)} de $sourceWallet vers $targetWallet pour rééquilibrer mes portefeuilles.',
                    'Transfer ${currNotifier.format(recommendedAmount!)} from $sourceWallet to $targetWallet to rebalance my wallets.',
                  ),
                );
                if (onRebalanceConfirmed != null) onRebalanceConfirmed!();
              },
              prefixWidget: Icon(Icons.bolt_rounded,
                  color: Theme.of(context).colorScheme.onSurface, size: 18),
              text: langNotifier.tr(
                  'Rééquilibrer en 1 Clic', 'Auto-Rebalance in 1 Tap'),
            ),
          ),
        ],
      ),
    );
  }
}

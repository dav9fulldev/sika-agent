import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../providers/sika_provider.dart';

/// WalletRebalanceCard — Module Cœur SIKA: Équilibrage Intelligent Multi-Portefeuilles
class WalletRebalanceCard extends ConsumerWidget {
  final VoidCallback? onRebalanceConfirmed;

  const WalletRebalanceCard({
    super.key,
    this.onRebalanceConfirmed,
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
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF635BFF).withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF635BFF).withValues(alpha: 0.15),
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
                  color: const Color(0xFF635BFF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF635BFF), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  langNotifier.tr('Équilibrage Multi-Portefeuilles', 'Smart Wallet Auto-Balancer'),
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
              'Votre compte Wave (${currNotifier.format(15000)}) risque d\'être insuffisant pour vos dépenses de fin de semaine. SIKA suggère de transférer ${currNotifier.format(7000)} depuis Orange Money.',
              'Your Wave account (${currNotifier.format(15000)}) might fall short for weekend bills. SIKA suggests transferring ${currNotifier.format(7000)} from Orange Money.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF94A3B8),
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
                        'Transférer ${currNotifier.format(7000)} de Orange Money vers Wave pour rééquilibrer mes portefeuilles.',
                        'Transfer ${currNotifier.format(7000)} from Orange Money to Wave to rebalance my wallets.',
                      ),
                    );
                    if (onRebalanceConfirmed != null) onRebalanceConfirmed!();
                  },
                  icon: Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.onSurface, size: 18),
                  label: Text(
                    langNotifier.tr('Rééquilibrer en 1 Clic', 'Auto-Rebalance in 1 Tap'),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF635BFF),
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

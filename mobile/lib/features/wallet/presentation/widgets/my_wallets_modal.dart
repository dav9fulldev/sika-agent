import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_images.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../providers/wallet_provider.dart';
import 'connect_wallet_modal.dart';

class MyWalletsModal extends ConsumerWidget {
  const MyWalletsModal({super.key});

  static Future<void> show(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const MyWalletsModal(),
    );
  }

  String _getProviderLogo(String provider) {
    final lower = provider.toLowerCase();
    if (lower.contains('wave')) return AppImages.waveci;
    if (lower.contains('orange')) return AppImages.orange;
    if (lower.contains('mtn')) return AppImages.mtn;
    if (lower.contains('paymechap')) return AppImages.paymechap;
    return AppImages.logo;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);

    final walletState = ref.watch(walletProvider);
    final wallets = walletState.wallets;

    return Container(
      height: MediaQuery.of(context).size.height * 0.65,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDarker,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppColors.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                langNotifier.tr('Mes portefeuilles', 'My Wallets'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white70, size: 24),
                    tooltip: langNotifier.tr('Actualiser les soldes', 'Refresh Balances'),
                    onPressed: () {
                      ref.read(walletProvider.notifier).syncAllWallets();
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: AppColors.cyan, size: 28),
                    tooltip: langNotifier.tr('Connecter un portefeuille', 'Connect Wallet'),
                    onPressed: () {
                      Navigator.pop(context);
                      ConnectWalletModal.show(context);
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            langNotifier.tr(
              'Consultez et gérez vos comptes Mobile Money connectés.',
              'View and manage your connected Mobile Money accounts.',
            ),
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: wallets.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: Colors.white38, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          langNotifier.tr('Aucun portefeuille connecté', 'No wallet connected'),
                          style: const TextStyle(color: Colors.white70, fontSize: 15),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            ConnectWalletModal.show(context);
                          },
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: Text(
                            langNotifier.tr('Connecter un compte', 'Connect Account'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    itemCount: wallets.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, index) {
                      final item = wallets[index];
                      final logo = _getProviderLogo(item.provider);

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.asset(
                                logo,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => const Icon(
                                  Icons.account_balance_wallet,
                                  color: AppColors.cyan,
                                  size: 32,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.provider,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.accountNumber,
                                    style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  currNotifier.format(item.balance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.emerald.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    langNotifier.tr('Actif', 'Active'),
                                    style: const TextStyle(
                                      color: AppColors.emerald,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../ai_assistant/presentation/pages/settings_screen.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../wallet/presentation/widgets/my_wallets_modal.dart';
import 'personal_information_screen.dart';
import 'payment_methods_screen.dart';
import 'kyc_verification_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref, LanguageNotifier langNotifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          langNotifier.tr('Déconnexion', 'Log Out'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
        ),
        content: Text(
          langNotifier.tr(
            'Êtes-vous sûr de vouloir vous déconnecter de votre compte SIKA ?',
            'Are you sure you want to log out of your SIKA account?',
          ),
          style: const TextStyle(color: Color(0xFF94A3B8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              langNotifier.tr('Annuler', 'Cancel'),
              style: const TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.rose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              langNotifier.tr('Déconnexion', 'Log Out'),
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMovementsModal(BuildContext context, WidgetRef ref, LanguageNotifier langNotifier) {
    String selectedProviderFilter = 'ALL';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          final walletState = ref.watch(walletProvider);
          final currency = ref.watch(currencyProvider);
          final movements = walletState.movements;
          final connectedWallets = walletState.wallets;

          final List<WalletMovementItem> filteredMovements = selectedProviderFilter == 'ALL'
              ? movements
              : movements.where((m) {
                  final p = m.walletProvider.toLowerCase();
                  final target = selectedProviderFilter.toLowerCase();
                  return p.contains(target) || target.contains(p);
                }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      langNotifier.tr('Historique des Mouvements', 'Transactions & History'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.cyan),
                      onPressed: () async {
                        await ref.read(walletProvider.notifier).fetchMovements();
                        setModalState(() {});
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  langNotifier.tr(
                    'Synchronisation automatique en temps réel de vos portefeuilles connectés.',
                    'Real-time automated sync across your connected wallets.',
                  ),
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                ),
                const SizedBox(height: 16),

                // DROPDOWN FILTER BY WALLET
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProviderFilter,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).cardColor,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.cyan),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 13, fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'ALL',
                          child: Text(
                            '${langNotifier.tr('Tous les comptes', 'All Accounts')} (${movements.length})',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...connectedWallets.map((w) {
                          final label = '${w.provider} (${w.accountNumber})';
                          return DropdownMenuItem<String>(
                            value: w.provider,
                            child: Text(
                              label,
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                            ),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedProviderFilter = val;
                          });
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: filteredMovements.isEmpty
                      ? Center(
                          child: Text(
                            langNotifier.tr('Aucun mouvement trouvé', 'No movements found'),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredMovements.length,
                          separatorBuilder: (ctx, i) => const Divider(color: AppColors.border),
                          itemBuilder: (ctx, index) {
                            final item = filteredMovements[index];
                            final isDeposit = item.type == 'deposit';
                            final amountVal = (item.amount * currency.rateFromFcfa).toStringAsFixed(
                              currency == AppCurrency.fcfa ? 0 : 2,
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isDeposit
                                    ? AppColors.emerald.withValues(alpha: 0.15)
                                    : AppColors.rose.withValues(alpha: 0.15),
                                child: Icon(
                                  isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isDeposit ? AppColors.emerald : AppColors.rose,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item.recipient.isNotEmpty ? item.recipient : item.description,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${item.walletProvider} • ${item.category}',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${isDeposit ? "+" : "-"}$amountVal ${currency.symbol}',
                                    style: TextStyle(
                                      color: isDeposit ? AppColors.emerald : Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      item.status,
                                      style: const TextStyle(
                                        color: AppColors.cyan,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
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
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = user?.name ?? 'Utilisateur';
    final userEmail = user?.email ?? '';
    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final isKycVerified = user?.isKycVerified ?? false;

    final walletState = ref.watch(walletProvider);
    final connectedCount = walletState.wallets.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        title: Text(
          langNotifier.tr('Profil & Compte', 'Profile & Account'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.cyan),
            tooltip: langNotifier.tr('Paramètres', 'Settings'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // USER PROFILE HEADER CARD
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.emerald,
                  child: Text(
                    initialLetter,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.amber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.amber),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star, size: 10, color: AppColors.amber),
                                SizedBox(width: 2),
                                Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: AppColors.amber,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (isKycVerified) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.verified, color: AppColors.emerald, size: 16),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // MENU OPTIONS (LISTE ÉPURÉE ET INTERACTIVE)
          _buildMenuItem(context,
            icon: Icons.person_outline,
            title: langNotifier.tr('Informations personnelles', 'Personal Information'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PersonalInformationScreen()),
              );
            },
          ),
          _buildMenuItem(context,
            icon: Icons.verified_user_outlined,
            title: langNotifier.tr('Vérification d\'Identité (KYC)', 'Identity Verification (KYC)'),
            trailingText: isKycVerified 
                ? langNotifier.tr('Vérifié', 'Verified') 
                : langNotifier.tr('Non vérifié', 'Unverified'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const KycVerificationScreen()),
              );
            },
          ),
          _buildMenuItem(context,
            icon: Icons.account_balance_wallet_outlined,
            title: langNotifier.tr('Mes portefeuilles', 'My Wallets'),
            trailingText: '$connectedCount ${langNotifier.tr('connectés', 'connected')}',
            onTap: () {
              MyWalletsModal.show(context);
            },
          ),
          _buildMenuItem(context,
            icon: Icons.credit_card_outlined,
            title: langNotifier.tr('Méthodes de paiement', 'Payment Methods'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const PaymentMethodsScreen()),
              );
            },
          ),
          _buildMenuItem(context,
            icon: Icons.history,
            title: langNotifier.tr('Historique des transactions', 'Transaction History'),
            trailingText: '${walletState.movements.length} ${langNotifier.tr('mouvements', 'movements')}',
            onTap: () {
              _showMovementsModal(context, ref, langNotifier);
            },
          ),

          const SizedBox(height: 32),

          // LOGOUT BUTTON (DÉCONNEXION EFFECTIVE)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () => _showLogoutDialog(context, ref, langNotifier),
              icon: const Icon(Icons.logout, color: AppColors.rose),
              label: Text(
                langNotifier.tr('Déconnexion', 'Log Out'),
                style: const TextStyle(color: AppColors.rose, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.rose),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: AppColors.cyan),
          title: Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null)
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

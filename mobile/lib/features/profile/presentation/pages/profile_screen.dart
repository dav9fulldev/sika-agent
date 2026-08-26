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

  void _showLogoutDialog(
      BuildContext context, WidgetRef ref, LanguageNotifier langNotifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          langNotifier.tr('Déconnexion', 'Log Out'),
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold),
        ),
        content: Text(
          langNotifier.tr(
            'Êtes-vous sûr de vouloir vous déconnecter de votre compte SIKA ?',
            'Are you sure you want to log out of your SIKA account?',
          ),
          style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              langNotifier.tr('Annuler', 'Cancel'),
              style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
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
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              langNotifier.tr('Déconnexion', 'Log Out'),
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showMovementsModal(
      BuildContext context, WidgetRef ref, LanguageNotifier langNotifier) {
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

          final List<WalletMovementItem> filteredMovements =
              selectedProviderFilter == 'ALL'
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
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      langNotifier.tr('Historique des Mouvements',
                          'Transactions & History'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppColors.cyan),
                      onPressed: () async {
                        await ref
                            .read(walletProvider.notifier)
                            .fetchMovements();
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
                  style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      fontSize: 12),
                ),
                const SizedBox(height: 16),

                // DROPDOWN FILTER BY WALLET
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedProviderFilter,
                      isExpanded: true,
                      dropdownColor: Theme.of(context).cardColor,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.cyan),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                      items: [
                        DropdownMenuItem<String>(
                          value: 'ALL',
                          child: Text(
                            '${langNotifier.tr('Tous les comptes', 'All Accounts')} (${movements.length})',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...connectedWallets.map((w) {
                          final label = '${w.provider} (${w.accountNumber})';
                          return DropdownMenuItem<String>(
                            value: w.provider,
                            child: Text(
                              label,
                              style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface),
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
                            langNotifier.tr(
                                'Aucun mouvement trouvé', 'No movements found'),
                            style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.54)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: filteredMovements.length,
                          separatorBuilder: (ctx, i) =>
                              const Divider(color: AppColors.border),
                          itemBuilder: (ctx, index) {
                            final item = filteredMovements[index];
                            final isDeposit = item.type == 'deposit';
                            final amountVal =
                                (item.amount * currency.rateFromFcfa)
                                    .toStringAsFixed(
                              currency == AppCurrency.fcfa ? 0 : 2,
                            );

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: isDeposit
                                    ? AppColors.emerald.withValues(alpha: 0.15)
                                    : AppColors.rose.withValues(alpha: 0.15),
                                child: Icon(
                                  isDeposit
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isDeposit
                                      ? AppColors.emerald
                                      : AppColors.rose,
                                  size: 18,
                                ),
                              ),
                              title: Text(
                                item.recipient.isNotEmpty
                                    ? item.recipient
                                    : item.description,
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                              subtitle: Text(
                                '${item.walletProvider} • ${item.category}',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.7),
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
                                      color: isDeposit
                                          ? AppColors.emerald
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
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
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPrimary, AppColors.brandSecondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.2), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: Text(
                      initialLetter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color:
                                      AppColors.warning.withValues(alpha: 0.5)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.star_rounded,
                                    size: 12, color: AppColors.warning),
                                SizedBox(width: 4),
                                Text(
                                  'Premium',
                                  style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                  ),
                            ),
                          ),
                          if (isKycVerified) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.verified_rounded,
                                  color: AppColors.success, size: 14),
                            ),
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
          _buildMenuItem(
            context,
            icon: Icons.person_outline,
            title: langNotifier.tr(
                'Informations personnelles', 'Personal Information'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PersonalInformationScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.verified_user_outlined,
            title: langNotifier.tr('Vérification d\'Identité (KYC)',
                'Identity Verification (KYC)'),
            trailingText: isKycVerified
                ? langNotifier.tr('Vérifié', 'Verified')
                : langNotifier.tr('Non vérifié', 'Unverified'),
            onTap: () {
              if (isKycVerified) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(langNotifier.tr('Identité déjà vérifiée.',
                        'Identity already verified.')),
                    backgroundColor: AppColors.emerald,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const KycVerificationScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.account_balance_wallet_outlined,
            title: langNotifier.tr('Mes portefeuilles', 'My Wallets'),
            trailingText:
                '$connectedCount ${langNotifier.tr('connectés', 'connected')}',
            onTap: () {
              MyWalletsModal.show(context);
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.credit_card_outlined,
            title: langNotifier.tr('Méthodes de paiement', 'Payment Methods'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const PaymentMethodsScreen()),
              );
            },
          ),
          _buildMenuItem(
            context,
            icon: Icons.history,
            title: langNotifier.tr(
                'Historique des transactions', 'Transaction History'),
            trailingText:
                '${walletState.movements.length} ${langNotifier.tr('mouvements', 'movements')}',
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
                style: const TextStyle(
                    color: AppColors.rose, fontWeight: FontWeight.bold),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: AppColors.brandPrimary, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (trailingText != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    trailingText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

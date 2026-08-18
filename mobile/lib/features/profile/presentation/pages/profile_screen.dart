import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../ai_assistant/presentation/pages/settings_screen.dart';
import '../../../auth/presentation/pages/login_screen.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../wallet/presentation/widgets/connect_wallet_modal.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  void _showLogoutDialog(BuildContext context, WidgetRef ref, LanguageNotifier langNotifier) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0B1329),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          langNotifier.tr('Déconnexion', 'Log Out'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = user?.name ?? 'David YAO';
    final userEmail = user?.email ?? 'david.yao@email.com';
    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'D';

    final walletState = ref.watch(walletProvider);
    final connectedCount = walletState.wallets.length;

    return Scaffold(
      backgroundColor: AppColors.surfaceDarker,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          langNotifier.tr('Profil & Compte', 'Profile & Account'),
          style: const TextStyle(
            color: AppColors.textPrimary,
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
              color: AppColors.surface,
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
                    style: const TextStyle(
                      color: Colors.white,
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
                              style: const TextStyle(
                                color: AppColors.textPrimary,
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
                      Text(
                        userEmail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
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
            icon: Icons.person_outline,
            title: langNotifier.tr('Informations personnelles', 'Personal Information'),
            onTap: () {},
          ),
          _buildMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: langNotifier.tr('Mes portefeuilles', 'My Wallets'),
            trailingText: '$connectedCount ' + langNotifier.tr('connectés', 'connected'),
            onTap: () {
              ConnectWalletModal.show(context);
            },
          ),
          _buildMenuItem(
            icon: Icons.credit_card_outlined,
            title: langNotifier.tr('Méthodes de paiement', 'Payment Methods'),
            onTap: () {},
          ),
          _buildMenuItem(
            icon: Icons.history,
            title: langNotifier.tr('Historique des transactions', 'Transaction History'),
            onTap: () {},
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

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
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
            style: const TextStyle(
              color: AppColors.textPrimary,
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

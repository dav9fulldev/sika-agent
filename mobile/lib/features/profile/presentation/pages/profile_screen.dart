import '../../../paypal/presentation/pages/subscription_screen.dart';
import '../../../paypal/presentation/pages/agent_authorization_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_typography.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../ai_assistant/presentation/pages/settings_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_history_screen.dart';
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
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        title: Text(
          langNotifier.tr('Déconnexion', 'Log Out'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        content: Text(
          langNotifier.tr(
            'Êtes-vous sûr de vouloir vous déconnecter de votre compte SIKA ?',
            'Are you sure you want to log out of your SIKA account?',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
              ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              langNotifier.tr('Annuler', 'Cancel'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SizedBox(
            width: 130,
            child: SikaPremiumButton(
              onPressed: () {
                Navigator.pop(ctx);
                ref.read(authProvider.notifier).logout();
                // Le routeur de main.dart affiche l'écran suivant selon l'état d'authentification
      Navigator.of(context).popUntil((route) => route.isFirst);
              },
              text: langNotifier.tr('Déconnexion', 'Log Out'),
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
    final userName = user?.name ?? 'Utilisateur';
    final userEmail = user?.email ?? '';
    final initialLetter = userName.isNotEmpty ? userName[0].toUpperCase() : 'U';
    final isKycVerified = user?.isKycVerified ?? false;


    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          langNotifier.tr('Profil & Compte', 'Profile & Account'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
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
      body: Stack(
        children: [
          // HALO D'AMBIANCE DE FOND
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.5),
                radius: 1.0,
                colors: [
                  Color(0x0a3f8cff),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          
          ListView(
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
                          style: AppTypography.h1.copyWith(
                            color: Colors.white,
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
                                child: Row(
                                  children: [
                                    const Icon(Icons.star_rounded,
                                        size: 12, color: AppColors.warning),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Premium',
                                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                            color: AppColors.warning,
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

              // MENU OPTIONS (GROUPED IN A GLASS CARD)
              SikaGlassCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
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
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
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
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
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
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                    _buildMenuItem(
                      context,
                      icon: Icons.autorenew_rounded,
                      title: langNotifier.tr('Mes abonnements', 'My subscriptions'),
                      onTap: () => MySubscriptionsScreen.open(context),
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                    _buildMenuItem(
                      context,
                      icon: Icons.auto_awesome_outlined,
                      title: langNotifier.tr('Autorisation de SIKA', 'SIKA authorization'),
                      onTap: () => AgentAuthorizationScreen.open(context),
                    ),
                    Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05), height: 1),
                    _buildMenuItem(
                      context,
                      icon: Icons.history,
                      title: langNotifier.tr('Historique SIKA Pay', 'SIKA Pay history'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const SikaPayHistoryScreen()),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // LOGOUT BUTTON
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _showLogoutDialog(context, ref, langNotifier),
                  icon: const Icon(Icons.logout, color: AppColors.rose),
                  label: Text(
                    langNotifier.tr('Déconnexion', 'Log Out'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.rose,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: AppColors.rose.withValues(alpha: 0.05),
                    side: BorderSide(color: AppColors.rose.withValues(alpha: 0.3), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
    );
  }
}

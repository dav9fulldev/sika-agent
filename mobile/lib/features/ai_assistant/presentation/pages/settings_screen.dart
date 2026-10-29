import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/app_setup_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../paypal/presentation/pages/agent_authorization_screen.dart';
import '../../../paypal/presentation/pages/price_alerts_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_history_screen.dart';
import '../../../paypal/presentation/pages/subscription_screen.dart';
import '../../../paypal/presentation/widgets/sika_list.dart';
import '../../../paypal/providers/paypal_checkout_provider.dart';
import '../../../profile/presentation/pages/kyc_verification_screen.dart';

/// Réglages de SIKA Pay : contrôle de l'agent, sécurité, affichage.
/// Chaque ligne agit réellement : aucun interrupteur décoratif.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _logout(LanguageNotifier lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('Se déconnecter ?', 'Log out?')),
        content: Text(lang.tr('Vous devrez vous reconnecter pour utiliser SIKA Pay.', 'You will need to sign in again to use SIKA Pay.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.tr('Annuler', 'Cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(lang.tr('Se déconnecter', 'Log out'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await ref.read(authProvider.notifier).logout();
    // Le routeur de main.dart affiche l'écran de connexion selon l'état d'authentification
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _setBiometric(bool value, LanguageNotifier lang) async {
    if (value) {
      final bio = ref.read(biometricServiceProvider);
      if (!await bio.isBiometricsAvailable()) {
        _snack(lang.tr('Aucune empreinte ni visage enregistré sur cet appareil.', 'No fingerprint or face is enrolled on this device.'));
        return;
      }
      final ok = await bio.authenticate(
          localizedReason: lang.tr('Confirmez pour activer le déverrouillage biométrique.', 'Confirm to turn on biometric unlock.'));
      if (!ok) return;
    }
    await ref.read(appSetupProvider.notifier).setBiometric(enabled: value);
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  void _push(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  void _chooseLanguage(LanguageNotifier lang, AppLanguage current) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final l in AppLanguage.values)
            ListTile(
              title: Text(l.displayName),
              trailing: current == l ? const Icon(Icons.check_rounded, color: AppColors.brandPrimary) : null,
              onTap: () {
                lang.setLanguage(l);
                Navigator.pop(sheet);
              },
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLang = ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final setup = ref.watch(appSetupProvider);
    final isDark = ref.watch(themeProvider) == ThemeMode.dark;
    final kyc = ref.watch(authProvider).user?.kycStatus ?? 'none';
    final authorization = ref.watch(agentAuthorizationProvider).valueOrNull;
    final authorized = authorization?['active'] == true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Réglages', 'Settings'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, 32 + MediaQuery.of(context).padding.bottom), children: [
        SikaListSection(lang.tr("Paiements et agent", 'Payments and agent'), [
          SikaListRow(
            icon: Icons.tune_rounded,
            title: lang.tr('Autorisation de SIKA', 'SIKA authorization'),
            subtitle: authorized
                ? lang.tr('SIKA peut confirmer jusqu\'à ${authorization!['max_per_purchase']} USD par achat',
                    'SIKA can confirm up to ${authorization['max_per_purchase']} USD per purchase')
                : lang.tr('Vous confirmez chaque achat', 'You confirm every purchase'),
            onTap: () => AgentAuthorizationScreen.open(context),
          ),
          SikaListRow(
            icon: Icons.autorenew_rounded,
            title: lang.tr('Mes abonnements', 'My subscriptions'),
            onTap: () => MySubscriptionsScreen.open(context),
          ),
          SikaListRow(
            icon: Icons.notifications_active_outlined,
            title: lang.tr('Alertes de prix', 'Price alerts'),
            onTap: () => PriceAlertsScreen.open(context),
          ),
          SikaListRow(
            icon: Icons.receipt_long_outlined,
            title: lang.tr('Historique des paiements', 'Payment history'),
            onTap: () => _push(const SikaPayHistoryScreen()),
          ),
        ]),
        SikaListSection(lang.tr('Sécurité', 'Security'), [
          SikaListSwitch(
            icon: Icons.fingerprint_rounded,
            title: lang.tr('Déverrouillage biométrique', 'Biometric unlock'),
            subtitle: lang.tr("Demandé à l'ouverture de l'app et avant chaque paiement",
                'Asked when the app opens and before each payment'),
            value: setup.biometricEnabled,
            onChanged: (v) => _setBiometric(v, lang),
          ),
          SikaListRow(
            icon: kyc == 'paypal' ? Icons.verified_rounded : Icons.badge_outlined,
            title: lang.tr('Identité', 'Identity'),
            subtitle: kyc == 'paypal'
                ? lang.tr('Vérifiée par PayPal', 'Verified by PayPal')
                : kyc == 'submitted'
                    ? lang.tr('Vérification en attente', 'Verification pending')
                    : lang.tr('Non vérifiée', 'Not verified'),
            onTap: kyc == 'none' ? () => _push(const KycVerificationScreen()) : null,
          ),
        ]),
        SikaListSection(lang.tr('Affichage', 'Display'), [
          SikaListRow(
            icon: Icons.language_rounded,
            title: lang.tr('Langue', 'Language'),
            trailing: currentLang.displayName,
            onTap: () => _chooseLanguage(lang, currentLang),
          ),
          SikaListSwitch(
            icon: Icons.dark_mode_outlined,
            title: lang.tr('Thème sombre', 'Dark theme'),
            value: isDark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ]),
        SikaListSection(lang.tr('À propos', 'About'), const [
          SikaListRow(icon: Icons.info_outline_rounded, title: 'SIKA Pay', trailing: 'v${AppConfig.appVersion}'),
        ]),
        SikaListSection(lang.tr('Compte', 'Account'), [
          SikaListRow(
            icon: Icons.logout_rounded,
            title: lang.tr('Se déconnecter', 'Log out'),
            onTap: () => _logout(lang),
          ),
        ]),
      ]),
    );
  }
}

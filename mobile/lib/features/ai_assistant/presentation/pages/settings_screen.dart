import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/app_setup_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../../paypal/presentation/pages/agent_authorization_screen.dart';
import '../../../paypal/presentation/pages/price_alerts_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_history_screen.dart';
import '../../../paypal/presentation/pages/subscription_screen.dart';
import '../../../paypal/presentation/widgets/sika_pay_ui.dart';
import '../../../paypal/providers/paypal_checkout_provider.dart';
import '../../../profile/presentation/pages/kyc_verification_screen.dart';

/// Réglages de SIKA Pay : contrôle de l'agent, sécurité, assistant vocal, affichage.
/// Chaque ligne agit réellement : aucun interrupteur décoratif.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  static const _wakeWordKey = 'wake_word_enabled';
  bool _wakeWord = false;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((prefs) {
      if (mounted) setState(() => _wakeWord = prefs.getBool(_wakeWordKey) ?? false);
    });
  }

  Future<void> _setWakeWord(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wakeWordKey, value);
    setState(() => _wakeWord = value);
    value ? SikaNativeService.startSikaService() : SikaNativeService.stopSikaService();
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
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        _Section(lang.tr("Paiements et agent", 'Payments and agent'), [
          _Row(
            icon: Icons.auto_awesome_outlined,
            title: lang.tr('Autorisation de SIKA', 'SIKA authorization'),
            subtitle: authorized
                ? lang.tr('SIKA peut confirmer jusqu\'à ${authorization!['max_per_purchase']} USD par achat',
                    'SIKA can confirm up to ${authorization['max_per_purchase']} USD per purchase')
                : lang.tr('Vous confirmez chaque achat', 'You confirm every purchase'),
            onTap: () => AgentAuthorizationScreen.open(context),
          ),
          _Row(
            icon: Icons.autorenew_rounded,
            title: lang.tr('Mes abonnements', 'My subscriptions'),
            onTap: () => MySubscriptionsScreen.open(context),
          ),
          _Row(
            icon: Icons.notifications_active_outlined,
            title: lang.tr('Alertes de prix', 'Price alerts'),
            onTap: () => PriceAlertsScreen.open(context),
          ),
          _Row(
            icon: Icons.receipt_long_outlined,
            title: lang.tr('Historique des paiements', 'Payment history'),
            onTap: () => _push(const SikaPayHistoryScreen()),
          ),
        ]),
        _Section(lang.tr('Sécurité', 'Security'), [
          _Switch(
            icon: Icons.fingerprint_rounded,
            title: lang.tr('Déverrouillage biométrique', 'Biometric unlock'),
            subtitle: lang.tr("Demandé à l'ouverture de l'app et avant chaque paiement",
                'Asked when the app opens and before each payment'),
            value: setup.biometricEnabled,
            onChanged: (v) => _setBiometric(v, lang),
          ),
          _Row(
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
        _Section(lang.tr('Assistant vocal', 'Voice assistant'), [
          _Switch(
            icon: Icons.mic_none_rounded,
            title: lang.tr('Activation par la voix', 'Voice activation'),
            subtitle: lang.tr('Dites « SIKA » pour parler à l\'assistant, même app fermée',
                'Say "SIKA" to talk to the assistant, even when the app is closed'),
            value: _wakeWord,
            onChanged: _setWakeWord,
          ),
        ]),
        _Section(lang.tr('Affichage', 'Display'), [
          _Row(
            icon: Icons.language_rounded,
            title: lang.tr('Langue', 'Language'),
            trailing: currentLang.displayName,
            onTap: () => _chooseLanguage(lang, currentLang),
          ),
          _Switch(
            icon: Icons.dark_mode_outlined,
            title: lang.tr('Thème sombre', 'Dark theme'),
            value: isDark,
            onChanged: (_) => ref.read(themeProvider.notifier).toggleTheme(),
          ),
        ]),
        _Section(lang.tr('À propos', 'About'), const [
          _Row(icon: Icons.info_outline_rounded, title: 'SIKA Pay', trailing: 'v${AppConfig.appVersion}'),
        ]),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _Section(this.title, this.rows);

  @override
  Widget build(BuildContext context) {
    final divider = Divider(height: 1, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06));
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
        ),
        SikaPayCard(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (var i = 0; i < rows.length; i++) ...[if (i > 0) divider, rows[i]],
          ]),
        ),
      ]),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailing;
  final VoidCallback? onTap;
  const _Row({required this.icon, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: Icon(icon, color: AppColors.brandPrimary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle == null ? null : Text(subtitle!, style: TextStyle(fontSize: 12.5, color: muted)),
      trailing: trailing != null
          ? Text(trailing!, style: TextStyle(color: muted, fontWeight: FontWeight.w600))
          : (onTap != null ? Icon(Icons.chevron_right_rounded, color: muted) : null),
      onTap: onTap,
    );
  }
}

class _Switch extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _Switch({required this.icon, required this.title, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      secondary: Icon(icon, color: AppColors.brandPrimary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!,
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55))),
      value: value,
      activeThumbColor: AppColors.brandPrimary,
      activeTrackColor: AppColors.brandPrimary.withValues(alpha: 0.3),
      onChanged: onChanged,
    );
  }
}

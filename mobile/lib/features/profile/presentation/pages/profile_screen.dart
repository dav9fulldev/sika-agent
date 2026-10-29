import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../../../ai_assistant/presentation/pages/settings_screen.dart';
import '../../../paypal/presentation/pages/agent_authorization_screen.dart';
import '../../../paypal/presentation/pages/sika_pay_history_screen.dart';
import '../../../paypal/presentation/pages/subscription_screen.dart';
import '../../../paypal/presentation/widgets/sika_list.dart';
import '../../../paypal/providers/paypal_checkout_provider.dart';
import 'kyc_verification_screen.dart';
import 'payment_methods_screen.dart';
import 'personal_information_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref, LanguageNotifier lang) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.tr('Se déconnecter ?', 'Log out?')),
        content: Text(lang.tr('Vous devrez vous reconnecter pour utiliser SIKA Pay.',
            'You will need to sign in again to use SIKA Pay.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(lang.tr('Annuler', 'Cancel'))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.tr('Se déconnecter', 'Log out'), style: const TextStyle(color: SikaBrand.danger)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(authProvider.notifier).logout();
    // Le routeur de main.dart affiche l'écran de connexion selon l'état d'authentification
    if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _push(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final user = ref.watch(authProvider).user;
    final authorization = ref.watch(agentAuthorizationProvider).valueOrNull;
    final saved = ref.watch(savedPayPalProvider).valueOrNull ?? const {};

    final name = (user?.name ?? '').trim();
    final email = user?.email ?? '';
    final kyc = user?.kycStatus ?? 'none';
    final verified = kyc == 'paypal' || (user?.isKycVerified ?? false);
    final authorized = authorization?['active'] == true;
    final linked = saved['linked'] == true;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final muted = onSurface.withValues(alpha: 0.55);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(lang.tr('Profil', 'Profile'), style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: onSurface.withValues(alpha: 0.7)),
            tooltip: lang.tr('Réglages', 'Settings'),
            onPressed: () => _push(context, const SettingsScreen()),
          ),
        ],
      ),
      body: ListView(
        // Marge basse : la barre de navigation flottante ne doit pas recouvrir « Se déconnecter »
        padding: EdgeInsets.fromLTRB(16, 8, 16, 140 + MediaQuery.of(context).padding.bottom),
        children: [
          Row(children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: SikaBrand.royal.withValues(alpha: 0.08),
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(color: SikaBrand.royal, fontSize: 24, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name.isNotEmpty ? name : lang.tr('Votre compte', 'Your account'),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: muted, fontSize: 14)),
                ],
              ]),
            ),
          ]),
          SikaListSection(lang.tr('Compte', 'Account'), [
            SikaListRow(
              icon: Icons.person_outline_rounded,
              title: lang.tr('Informations personnelles', 'Personal information'),
              onTap: () => _push(context, const PersonalInformationScreen()),
            ),
            SikaListRow(
              icon: verified ? Icons.verified_outlined : Icons.badge_outlined,
              title: lang.tr('Identité', 'Identity'),
              subtitle: verified
                  ? lang.tr('Vérifiée par PayPal', 'Verified by PayPal')
                  : kyc == 'submitted'
                      ? lang.tr('Vérification en attente', 'Verification pending')
                      : lang.tr('Non vérifiée', 'Not verified'),
              onTap: kyc == 'none' && !verified ? () => _push(context, const KycVerificationScreen()) : null,
            ),
            SikaListRow(
              icon: Icons.account_balance_wallet_outlined,
              title: lang.tr('Moyen de paiement', 'Payment method'),
              subtitle: linked
                  ? 'PayPal · ${saved['payer_email'] ?? lang.tr('compte relié', 'linked account')}'
                  : lang.tr('PayPal, approuvé à chaque paiement', 'PayPal, approved for each payment'),
              onTap: () => _push(context, const PaymentMethodsScreen()),
            ),
          ]),
          SikaListSection(lang.tr('Paiements', 'Payments'), [
            SikaListRow(
              icon: Icons.tune_rounded,
              title: lang.tr('Autorisation de SIKA', 'SIKA authorization'),
              subtitle: authorized
                  ? lang.tr('Jusqu\'à ${authorization!['max_per_purchase']} USD par achat',
                      'Up to ${authorization['max_per_purchase']} USD per purchase')
                  : lang.tr('Vous confirmez chaque achat', 'You confirm every purchase'),
              onTap: () => AgentAuthorizationScreen.open(context),
            ),
            SikaListRow(
              icon: Icons.autorenew_rounded,
              title: lang.tr('Abonnements', 'Subscriptions'),
              onTap: () => MySubscriptionsScreen.open(context),
            ),
            SikaListRow(
              icon: Icons.receipt_long_outlined,
              title: lang.tr('Historique des paiements', 'Payment history'),
              onTap: () => _push(context, const SikaPayHistoryScreen()),
            ),
          ]),
          SikaListSection(lang.tr('Session', 'Session'), [
            SikaListRow(
              icon: Icons.logout_rounded,
              title: lang.tr('Se déconnecter', 'Log out'),
              color: SikaBrand.danger,
              onTap: () => _logout(context, ref, lang),
            ),
          ]),
        ],
      ),
    );
  }
}

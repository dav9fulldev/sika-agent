import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../paypal/presentation/widgets/sika_pay_ui.dart';

/// Moyen de paiement : PayPal uniquement. SIKA ne stocke aucune carte ; chaque paiement est approuvé sur PayPal.
class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final user = ref.watch(authProvider).user;
    final linked = user?.paypalLinked ?? false;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    Widget point(IconData icon, String text) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: AppColors.brandPrimary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.4))),
          ]),
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Moyen de paiement', 'Payment method'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        SikaPayCard(
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(color: SikaPayColors.paypalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.account_balance_wallet_rounded, color: SikaPayColors.paypalNavy),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PayPal', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 3),
                Text(
                  linked
                      ? lang.tr('Compte PayPal relié à SIKA Pay', 'PayPal account linked to SIKA Pay')
                      : lang.tr('Choisi à chaque paiement, sur PayPal', 'Chosen at each payment, on PayPal'),
                  style: TextStyle(fontSize: 12.5, color: muted),
                ),
              ]),
            ),
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
          ]),
        ),
        const SizedBox(height: 18),
        SikaPayCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lang.tr('Comment SIKA paie', 'How SIKA pays'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
            const SizedBox(height: 6),
            point(Icons.credit_card_off_outlined,
                lang.tr("SIKA ne stocke jamais vos cartes ni vos identifiants PayPal.", 'SIKA never stores your cards or PayPal credentials.')),
            point(Icons.how_to_reg_outlined,
                lang.tr('Vous approuvez chaque paiement et chaque abonnement sur PayPal.', 'You approve every payment and subscription on PayPal.')),
            point(Icons.account_balance_outlined,
                lang.tr('Votre solde, vos cartes et vos comptes bancaires restent gérés par PayPal.',
                    'Your balance, cards and bank accounts stay managed by PayPal.')),
          ]),
        ),
      ]),
    );
  }
}

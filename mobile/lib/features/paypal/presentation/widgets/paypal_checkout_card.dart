import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../pages/paypal_checkout_screen.dart';
import 'sika_pay_ui.dart';

/// Carte de checkout affichée dans la conversation, juste après la préparation par l'agent.
/// Elle reflète en direct le statut vérifié par le backend et ouvre l'écran de paiement.
class PayPalCheckoutCard extends ConsumerStatefulWidget {
  final Map<String, dynamic> initialCheckout;
  const PayPalCheckoutCard({super.key, required this.initialCheckout});

  @override
  ConsumerState<PayPalCheckoutCard> createState() => _PayPalCheckoutCardState();
}

class _PayPalCheckoutCardState extends ConsumerState<PayPalCheckoutCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(paypalCheckoutsProvider.notifier).seed(widget.initialCheckout);
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.read(languageProvider.notifier);
    ref.watch(languageProvider);
    final id = widget.initialCheckout['checkout_id']?.toString() ?? '';
    final v = ref.watch(paypalCheckoutsProvider)[id] ?? PayPalCheckoutView(data: widget.initialCheckout);
    final item = v.item;
    final budget = v.budget;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final inactive = v.isTerminal && v.status != 'COMPLETED';

    return Opacity(
      opacity: inactive ? 0.6 : 1,
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: SikaPayCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const PayPalWordmark(size: 14),
              const Spacer(),
              StatusChip(status: v.status, lang: lang),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(categoryIcon(item['category']?.toString()), color: AppColors.brandPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 3),
                  Text('${v.quantity} × ${v.unitAmount} ${v.currency}  ·  ${v.merchant['name']}',
                      style: TextStyle(fontSize: 12, color: onSurface.withValues(alpha: 0.55))),
                ]),
              ),
              Text('${v.total} ${v.currency}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            ]),
            const SizedBox(height: 10),
            Wrap(spacing: 6, runSpacing: 6, children: [
              if (budget['limit'] != null)
                _reason(
                  budget['within_budget'] == true ? Icons.check_circle_rounded : Icons.warning_rounded,
                  budget['within_budget'] == true
                      ? lang.tr('Dans votre budget (${budget['limit']} ${budget['currency']})',
                          'Within your budget (${budget['limit']} ${budget['currency']})')
                      : lang.tr('Hors budget', 'Over budget'),
                  budget['within_budget'] == true ? AppColors.success : AppColors.error,
                ),
              // Le prix vient du catalogue côté serveur, jamais du texte généré par l'IA
              if ((v.provenance['verified'] as List?)?.isNotEmpty ?? false)
                _reason(Icons.verified_rounded, lang.tr('Prix vérifié', 'Price verified'), AppColors.brandPrimary),
              if (v.data['confirmed_by'] == 'AGENT')
                _reason(Icons.auto_awesome_rounded, lang.tr('Confirmé par SIKA (votre autorisation)', 'Confirmed by SIKA (your authorization)'),
                    SikaPayColors.paypalBlue),
              if (v.data['payment_method'] == 'SAVED_PAYPAL')
                _reason(Icons.account_balance_wallet_outlined,
                    lang.tr('Payé avec votre compte PayPal relié', 'Paid with your linked PayPal account'), SikaPayColors.paypalBlue),
            ]),
            if (v.status == 'CANCELLED' && v.lastError?['code'] == 'REPLACED_BY_NEW_REQUEST') ...[
              const SizedBox(height: 8),
              Text(lang.tr('Remplacé par une demande plus récente.', 'Replaced by a newer request.'),
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: onSurface.withValues(alpha: 0.6))),
            ],
            if (!inactive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: SikaPayColors.paypalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  onPressed: id.isEmpty
                      ? null
                      : () {
                          // Achat confirmé (par vous ou par SIKA) : l'étape suivante est l'approbation sur PayPal
                          if (v.status == 'AWAITING_PAYPAL_APPROVAL') ref.read(paypalCheckoutsProvider.notifier).openApproval(id);
                          PayPalCheckoutScreen.open(context, id);
                        },
                  child: Text(
                    v.status == 'COMPLETED'
                        ? lang.tr('Voir le reçu', 'View receipt')
                        : v.status == 'AWAITING_USER_CONFIRMATION'
                            ? lang.tr('Voir le récapitulatif', 'Review summary')
                            : v.status == 'AWAITING_PAYPAL_APPROVAL'
                                ? lang.tr('Approuver sur PayPal', 'Approve on PayPal')
                                : lang.tr('Continuer le paiement', 'Continue payment'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _reason(IconData icon, String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.09), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ]),
      );
}

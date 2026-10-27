import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/services/biometric_service.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';

/// Parcours de paiement SIKA Pay piloté uniquement par les statuts renvoyés par le backend :
/// détails -> confirmation -> approbation sur PayPal -> paiement final -> résultat vérifié.
class PayPalCheckoutScreen extends ConsumerStatefulWidget {
  final String checkoutId;
  const PayPalCheckoutScreen({super.key, required this.checkoutId});

  static Future<void> open(BuildContext context, String checkoutId) {
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => PayPalCheckoutScreen(checkoutId: checkoutId)));
  }

  @override
  ConsumerState<PayPalCheckoutScreen> createState() => _PayPalCheckoutScreenState();
}

class _PayPalCheckoutScreenState extends ConsumerState<PayPalCheckoutScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Toujours partir du statut vérifié par le serveur
    WidgetsBinding.instance.addPostFrameCallback((_) => _notifier.refresh(widget.checkoutId));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  PayPalCheckoutsNotifier get _notifier => ref.read(paypalCheckoutsProvider.notifier);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour depuis le navigateur PayPal : revérification immédiate auprès de PayPal
    if (state == AppLifecycleState.resumed) {
      final v = ref.read(paypalCheckoutsProvider)[widget.checkoutId];
      if (v != null && const ['AWAITING_PAYPAL_APPROVAL', 'APPROVED', 'UNKNOWN_RESULT', 'PENDING'].contains(v.status)) {
        _notifier.refresh(widget.checkoutId);
      }
    }
  }

  Future<void> _confirm(LanguageNotifier lang) async {
    final bio = ref.read(biometricServiceProvider);
    if (await bio.isBiometricsAvailable()) {
      final ok = await bio.authenticate(
        localizedReason: lang.tr('Confirmez pour créer la commande PayPal.', 'Confirm to create the PayPal order.'),
      );
      if (!ok) {
        // aucune commande créée sans authentification réussie
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(lang.tr("Identité non confirmée : aucune commande n'a été créée.",
                'Identity not confirmed: no order was created.')),
            behavior: SnackBarBehavior.floating,
          ));
        }
        return;
      }
    }
    await _notifier.confirmAndOpenPayPal(widget.checkoutId);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.read(languageProvider.notifier);
    ref.watch(languageProvider);
    final v = ref.watch(paypalCheckoutsProvider)[widget.checkoutId];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(_title(v?.status, lang), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
              ),
      body: v == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () => _notifier.refresh(widget.checkoutId),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                children: [
                  if (v.status == 'COMPLETED') ..._result(v, lang) else ..._flow(v, lang),
                  if (v.errorMessage != null) _errorBanner(v, lang),
                  const SizedBox(height: 16),
                  _actions(v, lang),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(lang.tr('Mode test : aucun argent réel', 'Test mode: no real money'),
                        style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.45))),
                  ),
                ],
              ),
            ),
    );
  }

  String _title(String? status, LanguageNotifier lang) {
    if (const ['COMPLETED', 'DECLINED', 'CANCELLED', 'EXPIRED', 'FAILED'].contains(status)) return lang.tr('Résultat', 'Result');
    if (status == 'AWAITING_PAYPAL_APPROVAL' || status == 'APPROVED' || status == 'CAPTURING') return 'PayPal';
    if (status == 'AWAITING_USER_CONFIRMATION') return lang.tr('Récapitulatif', 'Summary');
    return lang.tr('Détails du paiement', 'Payment details');
  }

  // ---------------------------------------------------------------------------
  // Étapes en cours
  // ---------------------------------------------------------------------------

  List<Widget> _flow(PayPalCheckoutView v, LanguageNotifier lang) {
    final item = v.item;
    final budget = v.budget;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final waitingPayPal = v.status == 'AWAITING_PAYPAL_APPROVAL' || v.status == 'CREATING_ORDER';

    return [
      if (waitingPayPal || v.status == 'APPROVED' || v.status == 'CAPTURING' || v.status == 'UNKNOWN_RESULT' || v.status == 'PENDING')
        _statusHero(v, lang),
      if (!waitingPayPal) ...[
        SikaPayCard(
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(categoryIcon(item['category']?.toString()), color: AppColors.brandPrimary, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 4),
                Text('${v.merchant['name']} · ${lang.tr('boutique de démonstration', 'demo store')}',
                    style: TextStyle(fontSize: 12.5, color: onSurface.withValues(alpha: 0.55))),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SikaPayCard(
          child: Column(children: [
            InfoRow(label: lang.tr("Prix de l'article", 'Item price'), value: '${v.unitAmount} ${v.currency}'),
            InfoRow(label: lang.tr('Quantité', 'Quantity'), value: '${v.quantity}'),
            InfoRow(label: lang.tr('Frais de livraison', 'Shipping'), value: lang.tr('Gratuit (produit numérique)', 'Free (digital product)')),
            const Divider(height: 18),
            InfoRow(label: 'Total', value: '${v.total} ${v.currency}', strong: true),
            if (budget['limit'] != null)
              InfoRow(
                label: lang.tr('Votre budget', 'Your budget'),
                value: '',
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(budget['within_budget'] == true ? Icons.check_circle_rounded : Icons.warning_rounded,
                      size: 16, color: budget['within_budget'] == true ? AppColors.success : AppColors.error),
                  const SizedBox(width: 6),
                  Text('${budget['limit']} ${budget['currency']} · ${lang.tr('reste', 'left')} ${budget['remaining_after_purchase']}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 12),
        if (v.status == 'AWAITING_USER_CONFIRMATION') ...[
          _paymentMethod(lang),
          const SizedBox(height: 12),
        ],
      ],
      _paypalBox(v, lang),
      const SizedBox(height: 12),
      _provenance(v, lang),
    ];
  }

  Widget _statusHero(PayPalCheckoutView v, LanguageNotifier lang) {
    final busy = v.busy != null || v.status == 'CREATING_ORDER' || v.status == 'CAPTURING';
    String title;
    String body;
    switch (v.status) {
      case 'APPROVED':
        title = lang.tr('Approuvé sur PayPal', 'Approved on PayPal');
        body = lang.tr('PayPal confirme votre approbation. SIKA finalise le paiement…',
            'PayPal confirms your approval. SIKA is completing the payment…');
        break;
      case 'CAPTURING':
        title = lang.tr('Paiement en cours', 'Completing payment');
        body = lang.tr('SIKA finalise le paiement auprès de PayPal…', 'SIKA is completing the payment with PayPal…');
        break;
      case 'UNKNOWN_RESULT':
        title = lang.tr('Résultat à vérifier', 'Result to verify');
        body = v.lastError?['message']?.toString() ??
            lang.tr('Vérifiez le statut auprès de PayPal avant toute nouvelle tentative.', 'Verify with PayPal before any retry.');
        break;
      case 'PENDING':
        title = lang.tr('Capture en attente', 'Capture pending');
        body = v.lastError?['message']?.toString() ?? '';
        break;
      default:
        title = lang.tr('Approuvez sur PayPal', 'Approve on PayPal');
        body = v.data['confirmed_by'] == 'AGENT'
            ? lang.tr('SIKA a confirmé cet achat avec votre autorisation. Approuvez-le sur PayPal : le paiement se termine ensuite tout seul.',
                'SIKA confirmed this purchase with your authorization. Approve it on PayPal: the payment then completes on its own.')
            : lang.tr('Approuvez la commande sur PayPal. Le paiement se termine ensuite tout seul.',
                'Approve the order on PayPal. The payment then completes on its own.');
    }
    final st = statusStyle(v.status);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: SikaPayCard(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          if (busy)
            const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, color: SikaPayColors.paypalBlue))
          else
            Icon(st.icon, color: st.color, size: 42),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(body,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65))),
          const SizedBox(height: 16),
          CheckoutStepper(status: v.status, lang: lang),
        ]),
      ).animate().fade(duration: 250.ms),
    );
  }

  /// Seul moyen de paiement disponible : il est affiché sélectionné, sans fausse alternative.
  Widget _paymentMethod(LanguageNotifier lang) {
    return SikaPayCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(lang.tr('Moyen de paiement', 'Payment method'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: SikaPayColors.paypalBlue, width: 1.5),
          ),
          child: Row(children: [
            const PayPalWordmark(size: 15),
            const Spacer(),
            Semantics(
              label: lang.tr('Sélectionné', 'Selected'),
              child: const Icon(Icons.radio_button_checked_rounded, color: SikaPayColors.paypalBlue),
            ),
          ]),
        ),
        const SizedBox(height: 8),
        Text(
          lang.tr("Vous approuverez ensuite le paiement sur PayPal. Rien n'est débité avant votre confirmation finale.",
              'You will then approve the payment on PayPal. Nothing is charged before your final confirmation.'),
          style: TextStyle(fontSize: 12, height: 1.35, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ]),
    );
  }

  Widget _paypalBox(PayPalCheckoutView v, LanguageNotifier lang) {
    final p = v.paypal;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SikaPayColors.paypalBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SikaPayColors.paypalBlue.withValues(alpha: 0.18)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const PayPalWordmark(size: 16),
          const Spacer(),
          StatusChip(status: v.status, lang: lang),
        ]),
        const SizedBox(height: 6),
        Text(lang.tr('Paiement sécurisé via PayPal', 'Secure payment via PayPal'),
            style: const TextStyle(fontSize: 12.5, color: SikaPayColors.paypalBlue, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InfoRow(label: lang.tr('Bénéficiaire', 'Payee'), value: '${v.merchant['name']}'),
        InfoRow(label: lang.tr('Devise', 'Currency'), value: v.currency),
        InfoRow(label: lang.tr('Méthode', 'Method'), value: 'PayPal'),
        if (p['order_id'] != null) InfoRow(label: lang.tr('ID de commande PayPal', 'PayPal order ID'), value: p['order_id'].toString()),
        if (p['order_status'] != null) InfoRow(label: lang.tr('Statut PayPal', 'PayPal status'), value: p['order_status'].toString()),
      ]),
    );
  }

  Widget _provenance(PayPalCheckoutView v, LanguageNotifier lang) {
    final prov = v.provenance;
    List<String> list(String k) => (prov[k] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    Widget section(IconData icon, Color color, String title, List<String> lines) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(icon, size: 16, color: color), const SizedBox(width: 6), Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13))]),
            ...lines.map((l) => Padding(padding: const EdgeInsets.only(left: 22, top: 4), child: Text('• $l', style: const TextStyle(fontSize: 12.5, height: 1.35)))),
          ]),
        );
    return SikaPayCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.auto_awesome_rounded, color: AppColors.brandPrimary),
          title: Text(lang.tr('Ce que SIKA a vérifié', 'What SIKA verified'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          children: [
            section(Icons.verified_rounded, AppColors.success, lang.tr('Vérifié', 'Verified'), list('verified')),
            section(Icons.person_rounded, AppColors.brandPrimary, lang.tr('Fourni par vous', 'Provided by you'), list('user_provided')),
            section(Icons.lightbulb_outline_rounded, AppColors.warning, lang.tr('Hypothèses', 'Assumptions'), list('assumptions')),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Résultat (statut capturé réellement renvoyé par PayPal)
  // ---------------------------------------------------------------------------

  List<Widget> _result(PayPalCheckoutView v, LanguageNotifier lang) {
    final p = v.paypal;
    final updated = DateTime.tryParse(v.data['updated_at']?.toString() ?? '')?.toLocal();
    return [
      const SizedBox(height: 12),
      Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 44),
        ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
      ),
      const SizedBox(height: 16),
      Center(
          child: Text(
              isRefunded(p) ? lang.tr('Paiement remboursé', 'Payment refunded') : lang.tr('Paiement réussi', 'Payment successful'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      Center(
        child: Text(
          isRefunded(p)
              ? lang.tr('PayPal a encaissé puis remboursé ce paiement.', 'PayPal captured then refunded this payment.')
              : lang.tr('PayPal a confirmé le paiement.', 'PayPal confirmed the payment.'),
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
        ),
      ),
      const SizedBox(height: 20),
      SikaPayCard(
        child: Column(children: [
          const Row(children: [PayPalWordmark(size: 16)]),
          const SizedBox(height: 8),
          InfoRow(label: lang.tr('Article', 'Item'), value: v.item['name']?.toString() ?? ''),
          InfoRow(label: lang.tr('Montant capturé', 'Captured amount'), value: '${p['captured_amount']} ${p['captured_currency']}'),
          InfoRow(label: lang.tr('Statut', 'Status'), value: '', trailing: StatusChip(status: v.status, lang: lang)),
          InfoRow(label: lang.tr('Statut capture PayPal', 'PayPal capture status'), value: '${p['capture_status']}'),
          InfoRow(label: lang.tr('ID de commande', 'Order ID'), value: '${p['order_id']}'),
          InfoRow(label: lang.tr('ID de capture', 'Capture ID'), value: '${p['capture_id']}'),
          if (updated != null) InfoRow(label: 'Date', value: DateFormat('d MMM yyyy, HH:mm').format(updated)),
        ]),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Actions (une action réelle par bouton)
  // ---------------------------------------------------------------------------

  Widget _actions(PayPalCheckoutView v, LanguageNotifier lang) {
    final busy = v.busy != null;
    final id = widget.checkoutId;

    Widget primary(String label, VoidCallback? onTap, {Color color = SikaPayColors.paypalBlue}) => SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: busy ? null : onTap,
            child: busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        );
    Widget secondary(String label, VoidCallback? onTap) => SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
                foregroundColor: SikaPayColors.paypalBlue,
                side: const BorderSide(color: SikaPayColors.paypalBlue),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: busy ? null : onTap,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );
    const gap = SizedBox(height: 10);

    switch (v.status) {
      case 'AWAITING_USER_CONFIRMATION':
        return Column(children: [
          primary(lang.tr('Confirmer et payer', 'Confirm and pay'), () => _confirm(lang)),
          gap,
          secondary(lang.tr('Annuler', 'Cancel'), () => _notifier.cancel(id)),
        ]);
      case 'AWAITING_PAYPAL_APPROVAL':
        return Column(children: [
          primary(lang.tr('Ouvrir PayPal', 'Open PayPal'), () => _notifier.openApproval(id)),
          gap,
          secondary(lang.tr("J'ai approuvé — vérifier", "I've approved — check"), () => _notifier.refresh(id)),
          gap,
          TextButton(onPressed: busy ? null : () => _notifier.cancel(id), child: Text(lang.tr('Annuler le paiement', 'Cancel payment'))),
        ]);
      case 'APPROVED':
        return Column(children: [
          primary(lang.tr('Finaliser le paiement', 'Complete the payment'), () => _notifier.capture(id), color: AppColors.success),
          gap,
          secondary(lang.tr('Annuler', 'Cancel'), () => _notifier.cancel(id)),
        ]);
      case 'UNKNOWN_RESULT':
      case 'PENDING':
        return primary(lang.tr('Vérifier auprès de PayPal', 'Verify with PayPal'), () => _notifier.refresh(id));
      case 'COMPLETED':
        return Column(children: [
          primary(lang.tr('Voir la commande', 'View order'), () => _showTimeline(v, lang)),
          gap,
          secondary(lang.tr("Retour à l'accueil", 'Back to home'), () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ]);
      case 'CREATING_ORDER':
      case 'CAPTURING':
        return const SizedBox.shrink();
      default:
        return Column(children: [
          SikaPayCard(
            child: Row(children: [
              Icon(statusStyle(v.status).icon, color: statusStyle(v.status).color),
              const SizedBox(width: 10),
              Expanded(child: Text(v.lastError != null
                  ? paypalErrorText(v.lastError!['code']?.toString(), v.lastError!['message']?.toString(), lang)
                  : statusShortLabel(v.status, lang))),
            ]),
          ),
          gap,
          secondary(lang.tr("Retour à l'accueil", 'Back to home'), () => Navigator.of(context).popUntil((r) => r.isFirst)),
        ]);
    }
  }

  Widget _errorBanner(PayPalCheckoutView v, LanguageNotifier lang) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(paypalErrorText(v.errorCode, v.errorMessage, lang), style: const TextStyle(fontSize: 13, height: 1.35))),
      ]),
    );
  }

  void _showTimeline(PayPalCheckoutView v, LanguageNotifier lang) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Text(lang.tr('Votre commande', 'Your order'), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 8),
            InfoRow(label: lang.tr('Article', 'Item'), value: v.item['name']?.toString() ?? ''),
            InfoRow(label: 'Total', value: '${v.total} ${v.currency}'),
            if (v.paypal['order_id'] != null) InfoRow(label: lang.tr('Référence PayPal', 'PayPal reference'), value: '${v.paypal['order_id']}'),
            const Divider(height: 24),
            Text(lang.tr('Historique du paiement', 'Payment history'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 4),
            ...v.events.where((e) => eventLabel(e, lang) != null).map((e) {
              final at = DateTime.tryParse(e['created_at']?.toString() ?? '')?.toLocal();
              final st = statusStyle(e['new_status']?.toString() ?? '');
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(st.icon, color: st.color),
                title: Text(eventLabel(e, lang)!, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: at != null ? Text(DateFormat('d MMM, HH:mm:ss').format(at)) : null,
              );
            }),
          ],
        ),
      ),
    );
  }
}

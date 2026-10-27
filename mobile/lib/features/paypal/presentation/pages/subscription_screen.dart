import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';

/// Libellé et couleur d'un statut d'abonnement (statut renvoyé par PayPal via le serveur).
(String, Color, IconData) subscriptionStatus(String status, LanguageNotifier lang) {
  switch (status) {
    case 'AWAITING_USER_CONFIRMATION':
      return (lang.tr('À confirmer', 'To confirm'), AppColors.brandPrimary, Icons.fact_check_rounded);
    case 'CREATING':
    case 'AWAITING_PAYPAL_APPROVAL':
      return (lang.tr('En attente PayPal', 'Awaiting PayPal'), SikaPayColors.paypalBlue, Icons.hourglass_top_rounded);
    case 'APPROVED':
      return (lang.tr('Activation…', 'Activating…'), SikaPayColors.paypalBlue, Icons.hourglass_top_rounded);
    case 'ACTIVE':
      return (lang.tr('Actif', 'Active'), AppColors.success, Icons.check_circle_rounded);
    case 'SUSPENDED':
      return (lang.tr('Suspendu', 'Suspended'), AppColors.warning, Icons.pause_circle_rounded);
    case 'CANCELLED':
      return (lang.tr('Résilié', 'Cancelled'), const Color(0xFF64748B), Icons.block_rounded);
    case 'EXPIRED':
      return (lang.tr('Expiré', 'Expired'), const Color(0xFF64748B), Icons.block_rounded);
    default:
      return (lang.tr('Échec', 'Failed'), AppColors.error, Icons.error_rounded);
  }
}

/// Récapitulatif d'un abonnement : confirmation par l'utilisateur, approbation sur PayPal, puis gestion (résiliation).
class SubscriptionScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> initial;
  const SubscriptionScreen({super.key, required this.initial});

  static Future<void> open(BuildContext context, Map<String, dynamic> subscription) => Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => SubscriptionScreen(initial: subscription)));

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> with WidgetsBindingObserver {
  late Map<String, dynamic> _sub = widget.initial;
  bool _busy = false;
  String? _error;

  String get _ref => _sub['subscription_ref'].toString();
  String get _status => _sub['status']?.toString() ?? '';
  ApiService get _api => ref.read(apiServiceProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour depuis PayPal : statut revérifié auprès de PayPal
    if (state == AppLifecycleState.resumed && const ['AWAITING_PAYPAL_APPROVAL', 'APPROVED'].contains(_status)) _refresh();
  }

  Future<void> _run(Future<Map<String, dynamic>> Function() call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final data = await call();
      if (mounted) setState(() => _sub = data);
      ref.invalidate(subscriptionsProvider);
    } on PayPalApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = ref.read(languageProvider.notifier).tr('Pas de réponse du serveur SIKA.', 'No answer from the SIKA server.'));
      }
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _refresh() => _run(() => _api.getSubscription(_ref));

  Future<void> _confirm(LanguageNotifier lang) async {
    final bio = ref.read(biometricServiceProvider);
    if (await bio.isBiometricsAvailable()) {
      final ok = await bio.authenticate(
          localizedReason: lang.tr('Confirmez pour créer cet abonnement PayPal.', 'Confirm to create this PayPal subscription.'));
      if (!ok) {
        setState(() => _error = lang.tr("Identité non confirmée : rien n'a été souscrit.", 'Identity not confirmed: nothing was set up.'));
        return;
      }
    }
    await _run(() => _api.confirmSubscription(_ref));
    await _openPayPal();
  }

  Future<void> _openPayPal() async {
    final url = (_sub['paypal'] as Map?)?['approve_url']?.toString();
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https' || !uri.host.endsWith('.paypal.com')) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _cancel(LanguageNotifier lang) async {
    final active = const ['ACTIVE', 'SUSPENDED', 'APPROVED'].contains(_status);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dlg) => AlertDialog(
        title: Text(active ? lang.tr("Résilier l'abonnement ?", 'Cancel the subscription?') : lang.tr('Abandonner ?', 'Discard?')),
        content: Text(active
            ? lang.tr('PayPal arrêtera les prochains prélèvements de ${_sub['name']}.',
                'PayPal will stop the next payments for ${_sub['name']}.')
            : lang.tr("Rien n'a été prélevé.", 'Nothing was charged.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlg, false), child: Text(lang.tr('Garder', 'Keep'))),
          FilledButton(onPressed: () => Navigator.pop(dlg, true), child: Text(lang.tr('Résilier', 'Cancel it'))),
        ],
      ),
    );
    if (ok == true) await _run(() => _api.cancelSubscription(_ref));
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final (label, color, icon) = subscriptionStatus(_status, lang);
    final paypal = Map<String, dynamic>.from(_sub['paypal'] as Map? ?? const {});
    final next = DateTime.tryParse(paypal['next_billing_time']?.toString() ?? '')?.toLocal();
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Abonnement', 'Subscription'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
          SikaPayCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(color: AppColors.brandPrimary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.autorenew_rounded, color: AppColors.brandPrimary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(_sub['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(lang.tr('SIKA Demo Store · abonnement mensuel', 'SIKA Demo Store · monthly plan'),
                        style: TextStyle(fontSize: 12.5, color: muted)),
                  ]),
                ),
                Icon(icon, color: color),
              ]),
              const Divider(height: 24),
              InfoRow(label: lang.tr('Prix', 'Price'), value: '${_sub['price']} ${_sub['currency']} / ${lang.tr('mois', 'month')}', strong: true),
              InfoRow(label: lang.tr('Statut', 'Status'), value: label),
              InfoRow(label: lang.tr('Moyen de paiement', 'Payment method'), value: 'PayPal'),
              if (next != null) InfoRow(label: lang.tr('Prochain prélèvement', 'Next payment'), value: DateFormat('d MMM yyyy').format(next)),
              if (paypal['subscription_id'] != null) InfoRow(label: lang.tr('ID PayPal', 'PayPal ID'), value: paypal['subscription_id'].toString()),
            ]),
          ),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.verified_rounded, size: 16, color: AppColors.success),
            const SizedBox(width: 6),
            Expanded(
              child: Text(lang.tr('Prix vérifié auprès de PayPal. Résiliable à tout moment.', 'Price verified with PayPal. Cancel anytime.'),
                  style: TextStyle(fontSize: 12.5, color: muted)),
            ),
          ]),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
          ],
          const SizedBox(height: 20),
          ..._actions(lang),
        ]),
      ),
    );
  }

  List<Widget> _actions(LanguageNotifier lang) {
    Widget primary(String text, VoidCallback onTap) => SizedBox(
          height: 52,
          child: FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: SikaPayColors.paypalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : onTap,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
        );
    Widget secondary(String text, VoidCallback onTap) => SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
            onPressed: _busy ? null : onTap,
            child: Text(text),
          ),
        );
    switch (_status) {
      case 'AWAITING_USER_CONFIRMATION':
        return [
          primary(lang.tr("S'abonner avec PayPal", 'Subscribe with PayPal'), () => _confirm(lang)),
          const SizedBox(height: 10),
          secondary(lang.tr('Annuler', 'Cancel'), () => _cancel(lang)),
        ];
      case 'AWAITING_PAYPAL_APPROVAL':
        return [
          primary(lang.tr('Approuver sur PayPal', 'Approve on PayPal'), _openPayPal),
          const SizedBox(height: 10),
          secondary(lang.tr("J'ai approuvé — vérifier", "I've approved — check"), _refresh),
        ];
      case 'ACTIVE':
      case 'SUSPENDED':
      case 'APPROVED':
        return [secondary(lang.tr("Résilier l'abonnement", 'Cancel subscription'), () => _cancel(lang))];
      default:
        return [secondary(lang.tr("Retour à l'accueil", 'Back to home'), () => Navigator.of(context).popUntil((r) => r.isFirst))];
    }
  }
}

/// Carte d'abonnement dans la conversation (préparé par l'agent, ou listé).
class SubscriptionCard extends ConsumerWidget {
  final Map<String, dynamic> subscription;
  const SubscriptionCard({super.key, required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final status = subscription['status']?.toString() ?? '';
    final (label, color, icon) = subscriptionStatus(status, lang);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SikaPayCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const PayPalWordmark(size: 14),
            const Spacer(),
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.autorenew_rounded, color: AppColors.brandPrimary),
            const SizedBox(width: 10),
            Expanded(child: Text(subscription['name']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5))),
            Text('${subscription['price']} ${subscription['currency']}/${lang.tr('mois', 'mo')}',
                style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.verified_rounded, size: 14, color: AppColors.success),
            const SizedBox(width: 5),
            Text(lang.tr('Prix vérifié auprès de PayPal', 'Price verified with PayPal'),
                style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
          ]),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: SikaPayColors.paypalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              onPressed: () => SubscriptionScreen.open(context, subscription),
              child: Text(
                status == 'AWAITING_USER_CONFIRMATION'
                    ? lang.tr("Voir l'abonnement", 'Review subscription')
                    : lang.tr('Gérer', 'Manage'),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Liste « Mes abonnements » (depuis Plus ou le profil).
class MySubscriptionsScreen extends ConsumerWidget {
  const MySubscriptionsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MySubscriptionsScreen()));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final data = ref.watch(subscriptionsProvider);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Mes abonnements', 'My subscriptions'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(subscriptionsProvider),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            Padding(padding: const EdgeInsets.all(32), child: Text(lang.tr('Serveur SIKA injoignable.', 'SIKA server unreachable.'))),
          ]),
          data: (subs) => subs.isEmpty
              ? ListView(padding: const EdgeInsets.all(32), children: [
                  Text(
                    lang.tr("Aucun abonnement. Demandez à SIKA : « Abonne-moi au streaming vidéo le moins cher sous 10 dollars ».",
                        'No subscriptions yet. Ask SIKA: "Subscribe me to the cheapest video streaming plan under 10 dollars."'),
                    textAlign: TextAlign.center,
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: subs.map((s) => SubscriptionCard(subscription: s)).toList(),
                ),
        ),
      ),
    );
  }
}

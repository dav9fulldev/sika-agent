import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../ai_assistant/providers/sika_provider.dart';
import '../../../profile/presentation/pages/kyc_verification_screen.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../widgets/sika_pay_ui.dart';
import 'agent_authorization_screen.dart';
import 'price_alerts_screen.dart';
import 'subscription_screen.dart';
import 'paypal_checkout_screen.dart';

/// Accueil SIKA Pay : accès direct à l'agent de paiement et au compte PayPal sandbox.
/// Aucun solde n'est affiché : l'API Orders v2 ne fournit pas de solde, SIKA n'en invente pas.
class SikaPayHomeScreen extends ConsumerWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenProfile;
  const SikaPayHomeScreen({super.key, required this.onOpenChat, required this.onOpenHistory, required this.onOpenProfile});

  /// Ouvre le chat avec une phrase commencée : l'utilisateur la complète (aucune demande envoyée d'office).
  void _draft(WidgetRef ref, String start) {
    onOpenChat();
    ref.read(chatDraftProvider.notifier).state = start;
  }

  void _ask(WidgetRef ref, String prompt) {
    onOpenChat();
    ref.read(sikaProvider.notifier).sendTextMessage(prompt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageProvider.notifier);
    ref.watch(languageProvider);
    final user = ref.watch(authProvider).user;
    final name = (user?.name ?? '').trim().split(' ').first;
    final kycStatus = user?.kycStatus ?? 'none';
    final unseenAlerts = (ref.watch(priceWatchesProvider).valueOrNull?['unseen'] as num?)?.toInt() ?? 0;
    final status = ref.watch(paypalStatusProvider);
    final history = ref.watch(paypalHistoryProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paypalStatusProvider);
            ref.invalidate(paypalHistoryProvider);
            ref.invalidate(priceWatchesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(children: [
                const SikaPayLogo(size: 30),
                const SizedBox(width: 8),
                const SikaPayWordmark(fontSize: 21),
                const Spacer(),
                IconButton(
                  tooltip: lang.tr('Alertes de prix', 'Price alerts'),
                  icon: Badge(
                    isLabelVisible: unseenAlerts > 0,
                    label: Text('$unseenAlerts'),
                    child: const Icon(Icons.notifications_none_rounded),
                  ),
                  onPressed: () async {
                    await PriceAlertsScreen.open(context);
                    ref.invalidate(priceWatchesProvider);
                  },
                ),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onOpenProfile,
                  child: Semantics(
                    button: true,
                    label: lang.tr('Mon profil', 'My profile'),
                    child: CircleAvatar(
                      radius: 17,
                      backgroundColor: SikaBrand.action,
                      child: Text(
                        name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 22),
              Text('${lang.tr('Bonjour', 'Hello')}${name.isNotEmpty ? ' $name' : ''}',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text(lang.tr('Votre agent IA de paiement, toujours sous votre contrôle.', 'Your AI payment agent, always under your control.'),
                  style: TextStyle(color: onSurface.withValues(alpha: 0.6), fontSize: 14.5)),
              const SizedBox(height: 20),

              // Carte héro PayPal
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: onOpenChat,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: const LinearGradient(colors: [SikaPayColors.heroStart, SikaPayColors.heroEnd]),
                    boxShadow: [BoxShadow(color: SikaPayColors.heroStart.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(lang.tr('Demandez à SIKA', 'Ask SIKA'),
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(lang.tr('Acheter, comparer les prix, vous abonner ou suivre un paiement. SIKA vérifie et prépare, vous décidez.',
                                'Buy, compare prices, subscribe or track a payment. SIKA checks and prepares, you decide.'),
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4)),
                      ]),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                    ),
                  ]),
                ),
              ).animate().fade(duration: 300.ms).slideY(begin: 0.05),
              const SizedBox(height: 20),

              // Actions rapides
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                _quick(context, Icons.shopping_bag_rounded, lang.tr('Acheter', 'Buy'), AppColors.success,
                    () => _draft(ref, lang.tr('Je veux acheter ', 'I want to buy '))),
                _quick(context, Icons.compare_arrows_rounded, lang.tr('Comparer', 'Compare'), SikaPayColors.paypalBlue,
                    () => _draft(ref, lang.tr('Compare les prix en ligne pour ', 'Compare prices online for '))),
                _quick(context, Icons.autorenew_rounded, lang.tr('Abonnements', 'Subscriptions'), AppColors.brandPrimary,
                    () => MySubscriptionsScreen.open(context)),
                _quick(context, Icons.more_horiz_rounded, lang.tr('Plus', 'More'), AppColors.warning,
                    () => _showMore(context, ref, lang, kycStatus)),
              ]),
              const SizedBox(height: 26),

              // Comptes : affichés seulement s'il y a quelque chose à faire (PayPal indisponible, identité à vérifier)
              ..._accountsNeedingAction(context, lang, status, kycStatus),

              // Derniers paiements
              Row(children: [
                Text(lang.tr('Derniers paiements', 'Recent payments'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(onPressed: onOpenHistory, child: Text(lang.tr('Voir tout', 'See all'))),
              ]),
              history.when(
                loading: () => const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator())),
                error: (_, __) => const SizedBox.shrink(),
                data: (rows) => rows.isEmpty
                    ? Text(lang.tr('Aucun paiement pour le moment.', 'No payment yet.'), style: TextStyle(color: onSurface.withValues(alpha: 0.5)))
                    : Column(
                        children: rows.take(3).map((c) {
                          final item = Map<String, dynamic>.from(c['item'] as Map? ?? {});
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(statusStyle(c['status'].toString()).icon, color: statusStyle(c['status'].toString()).color),
                            title: Text(item['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: StatusChipRow(status: c['status'].toString(), lang: lang),
                            trailing: Text('${c['total_amount']} ${c['currency']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            onTap: () {
                              ref.read(paypalCheckoutsProvider.notifier).seed(c);
                              PayPalCheckoutScreen.open(context, c['checkout_id'].toString());
                            },
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMore(BuildContext context, WidgetRef ref, LanguageNotifier lang, String kycStatus) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
              leading: Icon(icon, color: SikaBrand.action),
              title: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(sheet);
                onTap();
              },
            );
        return SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            item(Icons.fact_check_rounded, lang.tr('Statut de mon dernier paiement', 'Status of my last payment'),
                () => _ask(ref, lang.tr('Où en est mon dernier paiement ?', 'What is the status of my last payment?'))),
            item(Icons.autorenew_rounded, lang.tr('Mes abonnements', 'My subscriptions'), () => MySubscriptionsScreen.open(context)),
            item(Icons.auto_awesome_rounded, lang.tr('Autoriser SIKA à confirmer mes achats', 'Let SIKA confirm my purchases'),
                () => AgentAuthorizationScreen.open(context)),
            item(Icons.person_outline_rounded, lang.tr('Mon profil', 'My profile'), onOpenProfile),
            if (kycStatus == 'none')
              item(Icons.badge_outlined, lang.tr('Vérifier mon identité', 'Verify my identity'),
                  () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycVerificationScreen()))),
            const SizedBox(height: 8),
          ]),
        );
      },
    );
  }

  List<Widget> _accountsNeedingAction(
      BuildContext context, LanguageNotifier lang, AsyncValue<Map<String, dynamic>> status, String kycStatus) {
    final paypalDown = status.hasError || (status.hasValue && status.value?['configured'] != true);
    final identityTodo = kycStatus != 'paypal';
    if (!paypalDown && !identityTodo) return const [];
    return [
      Text(lang.tr('À faire', 'To do'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      if (paypalDown)
        SikaPayCard(
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, color: AppColors.warning),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                status.hasError
                    ? lang.tr('Serveur SIKA injoignable. Vérifiez votre connexion.', 'SIKA server unreachable. Check your connection.')
                    : lang.tr('Paiements PayPal momentanément indisponibles.', 'PayPal payments are temporarily unavailable.'),
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
          ]),
        ),
      if (paypalDown && identityTodo) const SizedBox(height: 10),
      if (identityTodo) _IdentityCard(kycStatus: kycStatus, lang: lang),
      const SizedBox(height: 24),
    ];
  }

  Widget _quick(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: SizedBox(
        width: 76,
        child: Column(children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

class StatusChipRow extends StatelessWidget {
  final String status;
  final LanguageNotifier lang;
  const StatusChipRow({super.key, required this.status, required this.lang});

  @override
  Widget build(BuildContext context) =>
      Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.only(top: 4), child: StatusChip(status: status, lang: lang)));
}

/// Statut d'identité tel que le serveur le connaît : vérifié par PayPal, en attente, ou à faire.
class _IdentityCard extends StatelessWidget {
  final String kycStatus;
  final LanguageNotifier lang;
  const _IdentityCard({required this.kycStatus, required this.lang});

  @override
  Widget build(BuildContext context) {
    final verified = kycStatus == 'paypal';
    final pending = kycStatus == 'submitted';
    final color = verified ? AppColors.success : (pending ? AppColors.warning : SikaBrand.action);
    return SikaPayCard(
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(verified ? Icons.verified_rounded : (pending ? Icons.hourglass_top_rounded : Icons.badge_outlined), color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lang.tr('Identité', 'Identity'), style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(
              verified
                  ? lang.tr('Vérifiée par PayPal', 'Verified by PayPal')
                  : pending
                      ? lang.tr('Documents envoyés, vérification en attente', 'Documents sent, verification pending')
                      : lang.tr('Non vérifiée', 'Not verified'),
              style: TextStyle(fontSize: 12.5, color: color),
            ),
          ]),
        ),
        if (!verified && !pending)
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycVerificationScreen())),
            child: Text(lang.tr('Vérifier', 'Verify')),
          ),
      ]),
    );
  }
}

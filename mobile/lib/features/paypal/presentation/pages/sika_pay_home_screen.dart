import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../ai_assistant/providers/sika_provider.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';
import 'paypal_checkout_screen.dart';

/// Accueil SIKA Pay : accès direct à l'agent de paiement et au compte PayPal sandbox.
/// Aucun solde n'est affiché : l'API Orders v2 ne fournit pas de solde, SIKA n'en invente pas.
class SikaPayHomeScreen extends ConsumerWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenHistory;
  const SikaPayHomeScreen({super.key, required this.onOpenChat, required this.onOpenHistory});

  void _ask(WidgetRef ref, String prompt) {
    onOpenChat();
    ref.read(sikaProvider.notifier).sendTextMessage(prompt);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageProvider.notifier);
    ref.watch(languageProvider);
    final name = (ref.watch(authProvider).user?.name ?? '').trim().split(' ').first;
    final status = ref.watch(paypalStatusProvider);
    final history = ref.watch(paypalHistoryProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final assistedPrompt = lang.tr('Aide-moi à acheter un cours Excel sans dépasser 50 dollars.',
        'Help me buy an Excel course without going over 50 dollars.');

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paypalStatusProvider);
            ref.invalidate(paypalHistoryProvider);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            children: [
              Row(children: [
                Image.asset('assets/images/sika_logo.png', width: 30, height: 30),
                const SizedBox(width: 8),
                const Text('SIKA ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                const Text('Pay', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: SikaPayColors.paypalBlue)),
                const Spacer(),
                const SandboxBadge(compact: true),
              ]),
              const SizedBox(height: 22),
              Text('${lang.tr('Bonjour', 'Hello')}${name.isNotEmpty ? ' $name' : ''} 👋',
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
              const SizedBox(height: 4),
              Text(lang.tr('Votre agent IA de paiement, toujours sous votre contrôle.', 'Your AI payment agent, always under your control.'),
                  style: TextStyle(color: onSurface.withValues(alpha: 0.6), fontSize: 14.5)),
              const SizedBox(height: 20),

              // Carte héro PayPal
              InkWell(
                borderRadius: BorderRadius.circular(22),
                onTap: () => _ask(ref, assistedPrompt),
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
                        const PayPalWordmark(size: 18, color: Colors.white),
                        const SizedBox(height: 10),
                        Text(lang.tr('Dites ce que vous voulez acheter et votre budget. SIKA vérifie, prépare, et vous décidez.',
                                'Say what you want to buy and your budget. SIKA checks, prepares, and you decide.'),
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
                _quick(context, Icons.payments_rounded, lang.tr('Payer', 'Pay'), SikaPayColors.paypalBlue, onOpenChat),
                _quick(context, Icons.shopping_bag_rounded, lang.tr('Achat assisté', 'Assisted buy'), AppColors.success,
                    () => _ask(ref, assistedPrompt)),
                _quick(context, Icons.receipt_long_rounded, lang.tr('Historique', 'History'), AppColors.brandPrimary, onOpenHistory),
                _quick(context, Icons.fact_check_rounded, lang.tr('Statut', 'Status'), AppColors.warning,
                    () => _ask(ref, lang.tr('Où en est mon dernier paiement ?', 'What is the status of my last payment?'))),
              ]),
              const SizedBox(height: 26),

              // Compte PayPal sandbox (état réel de la configuration serveur, sans solde inventé)
              Text(lang.tr('Vos comptes', 'Your accounts'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SikaPayCard(
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: SikaPayColors.paypalBlue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.account_balance_wallet_rounded, color: SikaPayColors.paypalNavy),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('PayPal (Sandbox)', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      status.when(
                        loading: () => Text(lang.tr('Vérification…', 'Checking…'), style: const TextStyle(fontSize: 12.5)),
                        error: (_, __) => Text(lang.tr('Serveur SIKA injoignable', 'SIKA server unreachable'),
                            style: const TextStyle(fontSize: 12.5, color: AppColors.error)),
                        data: (s) => Text(
                          s['configured'] == true
                              ? lang.tr('Connecté au sandbox · compte de test', 'Connected to sandbox · test account')
                              : lang.tr('Identifiants sandbox manquants sur le serveur', 'Sandbox credentials missing on the server'),
                          style: TextStyle(fontSize: 12.5, color: s['configured'] == true ? AppColors.success : AppColors.warning),
                        ),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 24),

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

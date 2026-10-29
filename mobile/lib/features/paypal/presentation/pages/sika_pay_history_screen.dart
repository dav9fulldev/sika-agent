import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/providers/language_provider.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';
import 'paypal_checkout_screen.dart';

/// Onglet "Transactions" : historique SIKA Pay tel qu'enregistré par le backend.
class SikaPayHistoryScreen extends ConsumerWidget {
  const SikaPayHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.read(languageProvider.notifier);
    ref.watch(languageProvider);
    final history = ref.watch(paypalHistoryProvider);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => ref.invalidate(paypalHistoryProvider),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            children: [
              Row(children: [
                Text(lang.tr('Transactions', 'Transactions'), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                const Spacer(),
              ]),
              const SizedBox(height: 4),
              Text(lang.tr('Paiements PayPal préparés par SIKA', 'PayPal payments prepared by SIKA'),
                  style: TextStyle(color: onSurface.withValues(alpha: 0.55))),
              const SizedBox(height: 18),
              history.when(
                loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
                error: (_, __) => SikaPayCard(
                  child: Text(lang.tr('Historique indisponible : serveur SIKA injoignable. Tirez pour réessayer.',
                      'History unavailable: SIKA server unreachable. Pull to retry.')),
                ),
                data: (rows) => rows.isEmpty
                    ? SikaPayCard(
                        child: Column(children: [
                          Icon(Icons.receipt_long_rounded, size: 40, color: onSurface.withValues(alpha: 0.3)),
                          const SizedBox(height: 10),
                          Text(lang.tr('Aucun paiement pour le moment.', 'No payment yet.'), style: const TextStyle(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(lang.tr("Demandez à SIKA de vous aider à acheter quelque chose.", 'Ask SIKA to help you buy something.'),
                              textAlign: TextAlign.center, style: TextStyle(color: onSurface.withValues(alpha: 0.55))),
                        ]),
                      )
                    : Column(children: rows.map((c) => _row(context, ref, c, lang)).toList()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, WidgetRef ref, Map<String, dynamic> c, LanguageNotifier lang) {
    final status = c['status']?.toString() ?? '';
    final item = Map<String, dynamic>.from(c['item'] as Map? ?? {});
    final created = DateTime.tryParse(c['created_at']?.toString() ?? '')?.toLocal();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          ref.read(paypalCheckoutsProvider.notifier).seed(c);
          PayPalCheckoutScreen.open(context, c['checkout_id'].toString());
        },
        child: SikaPayCard(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Icon(statusStyle(status).icon, color: statusStyle(status).color, size: 26),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 3),
                Text(created != null ? DateFormat('d MMM yyyy, HH:mm').format(created) : '',
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${c['total_amount']} ${c['currency']}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              StatusChip(status: status, lang: lang),
            ]),
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';

/// Alertes de prix sur des produits du web : déclenchées par les notifications Channel3, jamais d'achat automatique.
class PriceAlertsScreen extends ConsumerStatefulWidget {
  const PriceAlertsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PriceAlertsScreen()));

  @override
  ConsumerState<PriceAlertsScreen> createState() => _PriceAlertsScreenState();
}

class _PriceAlertsScreenState extends ConsumerState<PriceAlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Ouvrir l'écran vaut lecture des alertes déclenchées
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(apiServiceProvider).markPriceWatchesSeen();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final data = ref.watch(priceWatchesProvider);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Alertes de prix', 'Price alerts'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(priceWatchesProvider),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            Padding(padding: const EdgeInsets.all(32), child: Text(lang.tr('Serveur SIKA injoignable.', 'SIKA server unreachable.'))),
          ]),
          data: (d) {
            final watches = (d['watches'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (watches.isEmpty) {
              return ListView(padding: const EdgeInsets.all(32), children: [
                Icon(Icons.notifications_none_rounded, size: 48, color: muted),
                const SizedBox(height: 12),
                Text(
                  lang.tr("Aucune alerte. Demandez à SIKA : « Préviens-moi quand ce casque passe sous 50 dollars ».",
                      'No alerts yet. Ask SIKA: "Tell me when these headphones drop below 50 dollars."'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: watches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _AlertTile(watch: watches[i], lang: lang),
            );
          },
        ),
      ),
    );
  }
}

class _AlertTile extends ConsumerWidget {
  final Map<String, dynamic> watch;
  final LanguageNotifier lang;
  const _AlertTile({required this.watch, required this.lang});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final triggered = watch['status'] == 'triggered';
    final target = watch['target_price']?.toString();
    final cur = watch['currency']?.toString() ?? 'USD';
    final color = triggered ? AppColors.success : SikaPayColors.paypalBlue;
    final subtitle = triggered
        ? (target != null
            ? lang.tr('Prix atteint : ${watch['last_price']} $cur chez ${watch['last_merchant']}',
                'Target reached: ${watch['last_price']} $cur at ${watch['last_merchant']}')
            : lang.tr('De retour en stock chez ${watch['last_merchant']}', 'Back in stock at ${watch['last_merchant']}'))
        : (target != null
            ? lang.tr('Alerte sous $target $cur · actuellement ${watch['last_price'] ?? '—'} $cur',
                'Alert below $target $cur · now ${watch['last_price'] ?? '—'} $cur')
            : lang.tr('Alerte de retour en stock', 'Back-in-stock alert'));
    return SikaPayCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(triggered ? Icons.local_offer_rounded : Icons.notifications_active_outlined, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(watch['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 12.5, color: color, fontWeight: FontWeight.w600)),
          ]),
        ),
        IconButton(
          tooltip: lang.tr("Arrêter l'alerte", 'Stop alert'),
          icon: const Icon(Icons.close_rounded),
          onPressed: () async {
            try {
              await ref.read(apiServiceProvider).deletePriceWatch((watch['watch_id'] as num).toInt());
            } catch (_) {}
            ref.invalidate(priceWatchesProvider);
          },
        ),
      ]),
    );
  }
}

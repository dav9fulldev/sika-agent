import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';
import 'price_alerts_screen.dart';

/// Changements que SIKA a remarqués sur les produits suivis. SIKA prévient, il n'achète jamais tout seul.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Ouvrir l'écran vaut lecture : le badge de la cloche disparaît au retour
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await ref.read(apiServiceProvider).markNotificationsRead();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final data = ref.watch(notificationsProvider);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Notifications', 'Notifications'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        actions: [
          TextButton(
            onPressed: () => PriceAlertsScreen.open(context),
            child: Text(lang.tr('Produits suivis', 'Followed')),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(notificationsProvider),
        child: data.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => ListView(children: [
            Padding(padding: const EdgeInsets.all(32), child: Text(lang.tr('Serveur SIKA injoignable.', 'SIKA server unreachable.'))),
          ]),
          data: (d) {
            final items = (d['notifications'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
            if (items.isEmpty) {
              return ListView(padding: const EdgeInsets.all(32), children: [
                Icon(Icons.notifications_none_rounded, size: 48, color: muted),
                const SizedBox(height: 12),
                Text(
                  lang.tr(
                      'Aucun changement pour le moment. SIKA suit pendant 30 jours les produits qu\'il vous montre et vous prévient si leur prix ou leur stock change.',
                      'No changes yet. SIKA follows the products it shows you for 30 days and tells you when their price or stock changes.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: muted, height: 1.4),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _NotificationTile(item: items[i], lang: lang),
            );
          },
        ),
      ),
    );
  }
}

/// Titre et texte d'une notification, dans la langue de l'app.
(String, String) notificationText(Map<String, dynamic> n, LanguageNotifier lang) {
  final cur = n['currency']?.toString() ?? 'USD';
  String money(Object? v) => v == null ? '' : '$v $cur';
  final title = n['title']?.toString() ?? '';
  final merchant = n['merchant']?.toString() ?? lang.tr('un marchand', 'a merchant');
  final price = money(n['price']);
  final previous = money(n['previous_price']);
  switch (n['kind']) {
    case 'target_reached':
      return (lang.tr('Prix cible atteint', 'Target price reached'), lang.tr('$title est maintenant à $price chez $merchant.', '$title is now $price at $merchant.'));
    case 'price_drop':
      return (lang.tr('Baisse de prix', 'Price drop'),
          lang.tr('$title est maintenant à $price chez $merchant (avant : $previous).', '$title is now $price at $merchant (was $previous).'));
    case 'price_rise':
      return (lang.tr('Hausse de prix', 'Price increase'),
          lang.tr('$title est passé à $price chez $merchant (avant : $previous).', '$title went up to $price at $merchant (was $previous).'));
    case 'back_in_stock':
      return (lang.tr('De retour en stock', 'Back in stock'),
          lang.tr('$title est de nouveau disponible chez $merchant.', '$title is available again at $merchant.'));
    case 'out_of_stock':
      return (lang.tr('En rupture de stock', 'Out of stock'),
          lang.tr("$title n'est plus disponible chez $merchant.", '$title is no longer available at $merchant.'));
    case 'new_offer':
      return (lang.tr('Offre moins chère', 'Cheaper offer'),
          lang.tr('$merchant vend maintenant $title à $price (meilleur prix : $previous).', '$merchant now sells $title for $price (best was $previous).'));
    case 'offer_removed':
      return (lang.tr('Offre retirée', 'Offer removed'), lang.tr('$merchant ne vend plus $title.', '$merchant no longer sells $title.'));
    default:
      return (title, '');
  }
}

/// « il y a 5 min », « il y a 3 h », « il y a 2 j ».
String timeAgo(String? iso, LanguageNotifier lang, {DateTime? now}) {
  final at = DateTime.tryParse(iso ?? '');
  if (at == null) return '';
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return lang.tr("à l'instant", 'just now');
  if (d.inHours < 1) return lang.tr('il y a ${d.inMinutes} min', '${d.inMinutes} min ago');
  if (d.inDays < 1) return lang.tr('il y a ${d.inHours} h', '${d.inHours} h ago');
  return lang.tr('il y a ${d.inDays} j', '${d.inDays} d ago');
}

class _NotificationTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final LanguageNotifier lang;
  const _NotificationTile({required this.item, required this.lang});

  @override
  Widget build(BuildContext context) {
    final (title, body) = notificationText(item, lang);
    final kind = item['kind']?.toString() ?? '';
    final good = const {'target_reached', 'price_drop', 'back_in_stock', 'new_offer'}.contains(kind);
    final color = good ? AppColors.success : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7);
    final icon = switch (kind) {
      'price_drop' || 'target_reached' => Icons.trending_down_rounded,
      'price_rise' => Icons.trending_up_rounded,
      'back_in_stock' => Icons.inventory_2_outlined,
      'new_offer' => Icons.storefront_outlined,
      _ => Icons.remove_shopping_cart_outlined,
    };
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return SikaPayCard(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: good ? color : null))),
              Text(timeAgo(item['created_at']?.toString(), lang), style: TextStyle(fontSize: 12, color: muted)),
            ]),
            const SizedBox(height: 4),
            Text(body, style: const TextStyle(fontSize: 13.5, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

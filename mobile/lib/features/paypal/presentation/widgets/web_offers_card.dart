import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import 'sika_pay_ui.dart';

/// Produits trouvés chez de vrais marchands en ligne (Channel3).
/// SIKA compare les offres ; le paiement se fait sur le site du marchand, jamais dans l'app.
class WebOffersCard extends ConsumerWidget {
  final Map<String, dynamic> data;
  const WebOffersCard({super.key, required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final products = (data['products'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ...products.map((p) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _ProductTile(product: p, lang: lang))),
        Row(children: [
          Icon(Icons.public_rounded, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              lang.tr('Vrais marchands en ligne · le paiement se fait sur leur site', 'Real online merchants · you pay on their site'),
              style: TextStyle(fontSize: 11.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55)),
            ),
          ),
        ]),
      ]),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Map<String, dynamic> product;
  final LanguageNotifier lang;
  const _ProductTile({required this.product, required this.lang});

  @override
  Widget build(BuildContext context) {
    final best = product['best_offer'] is Map ? Map<String, dynamic>.from(product['best_offer'] as Map) : null;
    final offers = (product['offers'] as List? ?? []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    final shown = best ?? (offers.isNotEmpty ? offers.first : null);
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final count = (product['offer_count'] as num?)?.toInt() ?? offers.length;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showOffers(context, product, offers, best, lang),
      child: SikaPayCard(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _ProductImage(url: product['image_url']?.toString()),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(product['title']?.toString() ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
              if (product['brand'] != null) ...[
                const SizedBox(height: 2),
                Text(product['brand'].toString(), style: TextStyle(fontSize: 12.5, color: onSurface.withValues(alpha: 0.55))),
              ],
              const SizedBox(height: 6),
              if (shown != null)
                Text('${shown['price']} ${shown['currency']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
              const SizedBox(height: 2),
              if (shown != null)
                Text(
                  best == null
                      ? lang.tr('Hors budget ou indisponible', 'Over budget or unavailable')
                      : count > 1
                          ? lang.tr('Disponible chez ${shown['merchant']} · meilleur prix sur $count marchands',
                              'Available at ${shown['merchant']} · best of $count merchants')
                          : lang.tr('Disponible chez ${shown['merchant']}', 'Available at ${shown['merchant']}'),
                  style: TextStyle(fontSize: 12, color: best == null ? AppColors.warning : SikaPayColors.paypalBlue, fontWeight: FontWeight.w600),
                ),
            ]),
          ),
          Icon(Icons.chevron_right_rounded, color: onSurface.withValues(alpha: 0.4)),
        ]),
      ),
    );
  }

  static void _showOffers(BuildContext context, Map<String, dynamic> product, List<Map<String, dynamic>> offers,
      Map<String, dynamic>? best, LanguageNotifier lang) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Row(children: [
              _ProductImage(url: product['image_url']?.toString(), size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Text(product['title']?.toString() ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ]),
            const SizedBox(height: 16),
            Text(lang.tr('Offres des marchands', 'Merchant offers'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 6),
            ...offers.map((o) {
              final isBest = best != null && o['url'] == best['url'];
              final inStock = o['availability'] == 'InStock' || o['availability'] == 'LimitedAvailability';
              final condition = o['condition']?.toString();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(isBest ? Icons.workspace_premium_rounded : Icons.storefront_rounded,
                    color: isBest ? AppColors.success : SikaPayColors.paypalNavy),
                title: Text(o['merchant']?.toString() ?? '', style: TextStyle(fontWeight: isBest ? FontWeight.w800 : FontWeight.w600)),
                subtitle: Text([
                  inStock ? lang.tr('En stock', 'In stock') : lang.tr('Rupture', 'Out of stock'),
                  if (condition != null && condition != 'new') condition == 'used' ? lang.tr('occasion', 'used') : lang.tr('reconditionné', 'refurbished'),
                  if (isBest) lang.tr('meilleur prix', 'best price'),
                ].join(' · ')),
                trailing: Text('${o['price']} ${o['currency']}', style: const TextStyle(fontWeight: FontWeight.w800)),
                onTap: () => _open(o['url']?.toString()),
              );
            }),
            const SizedBox(height: 12),
            if (best != null)
              SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: SikaPayColors.paypalBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  onPressed: () => _open(best['url']?.toString()),
                  child: Text(lang.tr('Ouvrir chez ${best['merchant']}', 'Open at ${best['merchant']}'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            const SizedBox(height: 10),
            Text(
              lang.tr(
                  "Vous payez sur le site du marchand (avec PayPal s'il le propose). SIKA ne paie pas à votre place sur ces sites et ne peut pas vérifier cet achat.",
                  "You pay on the merchant's site (with PayPal if offered). SIKA does not pay on these sites and cannot verify that purchase."),
              style: TextStyle(fontSize: 12, height: 1.4, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _open(String? url) async {
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return; // liens HTTPS uniquement
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  final double size;
  const _ProductImage({required this.url, this.size = 72});

  @override
  Widget build(BuildContext context) {
    final placeholder = Icon(Icons.shopping_bag_rounded, color: AppColors.brandPrimary.withValues(alpha: 0.6));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: const Color(0xFFF2F4F8), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: url == null || !url!.startsWith('https://')
          ? placeholder
          : Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/network_error.dart';
import '../../../../core/widgets/sika_pay_brand.dart';

/// Ouvre le tableau de bord web : un code à usage unique (10 minutes) à saisir sur l'ordinateur.
/// Le tableau de bord est en lecture seule : il ne peut pas payer.
class WebDashboardSheet extends ConsumerStatefulWidget {
  const WebDashboardSheet({super.key});

  static Future<void> open(BuildContext context) => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => const WebDashboardSheet(),
      );

  @override
  ConsumerState<WebDashboardSheet> createState() => _WebDashboardSheetState();
}

class _WebDashboardSheetState extends ConsumerState<WebDashboardSheet> {
  Map<String, dynamic>? _link;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newCode();
  }

  Future<void> _newCode() async {
    setState(() {
      _link = null;
      _error = null;
    });
    final lang = ref.read(languageProvider.notifier);
    try {
      final res = await ref.read(apiServiceProvider).createDashboardCode();
      if (mounted) setState(() => _link = res);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = isNetworkError(e)
          ? lang.tr('Pas de connexion au serveur SIKA. Réessayez.', 'No connection to the SIKA server. Try again.')
          : lang.tr("Le code n'a pas pu être créé. Réessayez.", 'The code could not be created. Try again.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);
    final link = _link;
    final url = link?['url']?.toString() ?? '';
    final code = link?['code']?.toString() ?? '';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(lang.tr('Tableau de bord web', 'Web dashboard'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            lang.tr('Vos paiements et les prix suivis, sur un ordinateur. Lecture seule : aucun paiement depuis le web.',
                'Your payments and followed prices, on a computer. Read-only: no payment from the web.'),
            style: TextStyle(color: muted, height: 1.4),
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[
            Text(_error!, style: const TextStyle(color: SikaBrand.danger)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _newCode, child: Text(lang.tr('Réessayer', 'Try again'))),
          ] else if (link == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else ...[
            Text(lang.tr('1. Sur votre ordinateur, ouvrez :', '1. On your computer, open:'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: SelectableText(url, style: const TextStyle(color: SikaBrand.action, fontSize: 14))),
              IconButton(
                tooltip: lang.tr('Copier le lien', 'Copy link'),
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () => Clipboard.setData(ClipboardData(text: url)),
              ),
            ]),
            const SizedBox(height: 12),
            Text(lang.tr('2. Saisissez ce code :', '2. Enter this code:'), style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: SikaBrand.action.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SelectableText(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 4, color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            const SizedBox(height: 8),
            Text(lang.tr('Valable une fois, pendant 10 minutes.', 'Works once, for 10 minutes.'), style: TextStyle(color: muted, fontSize: 13)),
            const SizedBox(height: 16),
            Row(children: [
              TextButton(onPressed: _newCode, child: Text(lang.tr('Nouveau code', 'New code'))),
              const Spacer(),
              TextButton(
                // Sur le téléphone : le code voyage dans le fragment de l'URL, jamais envoyé au serveur
                onPressed: () => launchUrl(Uri.parse('$url#code=$code'), mode: LaunchMode.externalApplication),
                child: Text(lang.tr('Ouvrir sur ce téléphone', 'Open on this phone')),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

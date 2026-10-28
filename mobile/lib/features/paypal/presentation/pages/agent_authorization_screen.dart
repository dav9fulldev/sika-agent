import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/biometric_service.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../../providers/paypal_checkout_provider.dart';
import '../widgets/sika_pay_ui.dart';

/// Mode hybride : l'utilisateur choisit s'il confirme lui-même chaque achat (par défaut)
/// ou s'il autorise SIKA à confirmer pour lui, dans des limites qu'il fixe et qu'il peut retirer à tout moment.
/// S'il relie aussi son compte PayPal (approuvé une fois sur PayPal), SIKA paie ces achats sans redirection ;
/// sinon, chaque paiement reste approuvé sur PayPal.
class AgentAuthorizationScreen extends ConsumerStatefulWidget {
  const AgentAuthorizationScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgentAuthorizationScreen()));

  @override
  ConsumerState<AgentAuthorizationScreen> createState() => _AgentAuthorizationScreenState();
}

class _AgentAuthorizationScreenState extends ConsumerState<AgentAuthorizationScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour de PayPal après la liaison du compte : on relit l'état vérifié par le serveur
    if (state == AppLifecycleState.resumed) ref.invalidate(savedPayPalProvider);
  }

  static const _perPurchaseOptions = [10, 25, 50, 100];
  static const _dailyOptions = [25, 50, 100, 200];
  static const _durations = [24, 24 * 7, 24 * 30];

  int _perPurchase = 50;
  int _daily = 100;
  int _hours = 24;
  bool _busy = false;
  String? _error;

  Future<void> _run(Future<Map<String, dynamic>> Function(ApiService api) call) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await call(ref.read(apiServiceProvider));
      ref.invalidate(agentAuthorizationProvider);
      ref.invalidate(savedPayPalProvider);
    } on PayPalApiException catch (e) {
      _error = e.message;
    } catch (_) {
      _error = ref.read(languageProvider.notifier).tr("La demande n'a pas abouti. Réessayez.", 'The request failed. Try again.');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _grant() async {
    final lang = ref.read(languageProvider.notifier);
    final bio = ref.read(biometricServiceProvider);
    if (await bio.isBiometricsAvailable()) {
      final ok = await bio.authenticate(
        localizedReason: lang.tr('Confirmez pour autoriser SIKA à confirmer vos achats.', 'Confirm to let SIKA confirm your purchases.'),
      );
      if (!ok) {
        setState(() => _error = lang.tr("Identité non confirmée : rien n'a été autorisé.", 'Identity not confirmed: nothing was authorized.'));
        return;
      }
    }
    await _run((api) => api.setAgentAuthorization(
          maxPerPurchase: '$_perPurchase',
          dailyLimit: '$_daily',
          durationHours: _hours,
        ));
  }

  Future<void> _linkPayPal() async {
    final lang = ref.read(languageProvider.notifier);
    await _run((api) async {
      final res = await api.startSavedPayPalLink();
      final url = Uri.tryParse(res['approve_url']?.toString() ?? '');
      if (url == null || !await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw PayPalApiException('OPEN_FAILED', lang.tr("Impossible d'ouvrir PayPal.", 'Could not open PayPal.'), 0);
      }
      return res;
    });
  }

  String _durationLabel(int hours, LanguageNotifier lang) {
    if (hours == 24) return lang.tr('24 heures', '24 hours');
    if (hours == 24 * 7) return lang.tr('7 jours', '7 days');
    return lang.tr('30 jours', '30 days');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final auth = ref.watch(agentAuthorizationProvider);
    final saved = ref.watch(savedPayPalProvider).valueOrNull ?? const {};
    final linked = saved['linked'] == true;
    final muted = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(lang.tr('Autorisation de SIKA', 'SIKA authorization'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      body: auth.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(lang.tr('Serveur SIKA injoignable.', 'SIKA server unreachable.'))),
        data: (a) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              lang.tr(
                  'Par défaut, vous confirmez vous-même chaque achat. Vous pouvez aussi autoriser SIKA à confirmer pour vous quand vous lui demandez d’acheter, dans les limites ci-dessous.',
                  'By default, you confirm every purchase yourself. You can also let SIKA confirm for you when you ask it to buy, within the limits below.'),
              style: TextStyle(color: muted, fontSize: 14.5, height: 1.45),
            ),
            const SizedBox(height: 16),
            SikaPayCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                linked
                    ? _bullet(Icons.account_balance_wallet_outlined,
                        lang.tr('SIKA paie avec votre compte PayPal relié, sans redirection.', 'SIKA pays with your linked PayPal account, without redirection.'))
                    : _bullet(Icons.lock_outline_rounded,
                        lang.tr('Vous approuvez chaque paiement sur PayPal.', 'You approve each payment on PayPal.')),
                _bullet(Icons.shield_outlined,
                    lang.tr('Les limites sont vérifiées par le serveur, pas par l’IA.', 'Limits are enforced by the server, not by the AI.')),
                _bullet(Icons.undo_rounded, lang.tr('Vous pouvez retirer l’autorisation à tout moment.', 'You can withdraw the authorization at any time.')),
              ]),
            ),
            const SizedBox(height: 20),
            if (a['active'] == true) ..._active(a, lang) else ..._form(lang),
            const SizedBox(height: 28),
            ..._savedPayPal(saved, lang, muted),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: SikaBrand.danger, fontSize: 13.5)),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _active(Map<String, dynamic> a, LanguageNotifier lang) {
    final expires = DateTime.tryParse(a['expires_at']?.toString() ?? '')?.toLocal();
    final cur = a['currency']?.toString() ?? 'USD';
    return [
      SikaPayCard(
        child: Column(children: [
          Row(children: [
            const Icon(Icons.auto_awesome_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Text(lang.tr('SIKA peut confirmer vos achats', 'SIKA can confirm your purchases'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 8),
          InfoRow(label: lang.tr('Maximum par achat', 'Maximum per purchase'), value: '${a['max_per_purchase']} $cur'),
          InfoRow(label: lang.tr('Maximum par jour', 'Maximum per day'), value: '${a['daily_limit']} $cur'),
          InfoRow(label: lang.tr('Reste aujourd’hui', 'Left today'), value: '${a['remaining_today']} $cur'),
          if (expires != null) InfoRow(label: lang.tr('Jusqu’au', 'Until'), value: DateFormat('d MMM yyyy, HH:mm').format(expires)),
        ]),
      ),
      const SizedBox(height: 20),
      SikaOutlineButton(
        label: lang.tr('Retirer l’autorisation', 'Withdraw authorization'),
        onPressed: _busy ? null : () => _run((api) => api.revokeAgentAuthorization()),
      ),
    ];
  }

  List<Widget> _form(LanguageNotifier lang) {
    return [
      _choiceTitle(lang.tr('Maximum par achat', 'Maximum per purchase')),
      _chips<int>(_perPurchaseOptions, _perPurchase, (v) => '$v USD', (v) {
        _perPurchase = v;
        if (_daily < v) _daily = _dailyOptions.firstWhere((d) => d >= v, orElse: () => _dailyOptions.last);
      }),
      _choiceTitle(lang.tr('Maximum par jour', 'Maximum per day')),
      _chips<int>(_dailyOptions.where((d) => d >= _perPurchase).toList(), _daily, (v) => '$v USD', (v) => _daily = v),
      _choiceTitle(lang.tr('Durée', 'Duration')),
      _chips<int>(_durations, _hours, (v) => _durationLabel(v, lang), (v) => _hours = v),
      const SizedBox(height: 24),
      SikaPrimaryButton(label: lang.tr('Autoriser SIKA', 'Authorize SIKA'), loading: _busy, onPressed: _grant),
    ];
  }

  /// Libre choix : relier son compte PayPal pour que SIKA paie sans redirection, ou approuver chaque paiement sur PayPal.
  List<Widget> _savedPayPal(Map<String, dynamic> saved, LanguageNotifier lang, Color muted) {
    final linked = saved['linked'] == true;
    return [
      Text(lang.tr('Compte PayPal enregistré', 'Saved PayPal account'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
      const SizedBox(height: 6),
      Text(
        lang.tr(
            'Facultatif. Reliez votre compte PayPal une fois : les achats que SIKA confirme pour vous sont alors payés sans passer par PayPal, toujours dans vos limites. Sans compte relié, vous approuvez chaque paiement sur PayPal.',
            'Optional. Link your PayPal account once: purchases SIKA confirms for you are then paid without leaving SIKA, always within your limits. Without a linked account, you approve each payment on PayPal.'),
        style: TextStyle(color: muted, fontSize: 13.5, height: 1.45),
      ),
      const SizedBox(height: 12),
      if (linked) ...[
        SikaPayCard(
          child: Row(children: [
            const Icon(Icons.verified_rounded, color: AppColors.success),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lang.tr('Compte PayPal relié', 'PayPal account linked'), style: const TextStyle(fontWeight: FontWeight.w700)),
                if (saved['payer_email'] != null)
                  Text(saved['payer_email'].toString(), style: TextStyle(color: muted, fontSize: 12.5)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        SikaOutlineButton(
          label: lang.tr('Délier le compte PayPal', 'Unlink PayPal account'),
          onPressed: _busy ? null : () => _run((api) => api.unlinkSavedPayPal()),
        ),
      ] else
        SikaOutlineButton(
          label: lang.tr('Relier mon compte PayPal', 'Link my PayPal account'),
          onPressed: _busy ? null : _linkPayPal,
        ),
    ];
  }

  Widget _bullet(IconData icon, String text) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: SikaBrand.action),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13.5, height: 1.35))),
        ]),
      );

  Widget _choiceTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 8),
        child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
      );

  Widget _chips<T>(List<T> options, T selected, String Function(T) label, void Function(T) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options
          .map((o) => ChoiceChip(
                label: Text(label(o)),
                selected: o == selected,
                selectedColor: SikaBrand.action.withValues(alpha: 0.14),
                labelStyle: TextStyle(
                    color: o == selected ? SikaBrand.action : SikaBrand.ink, fontWeight: o == selected ? FontWeight.w700 : FontWeight.w500),
                onSelected: _busy ? null : (_) => setState(() => onSelect(o)),
              ))
          .toList(),
    );
  }
}

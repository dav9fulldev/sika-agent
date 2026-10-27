import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
class AgentAuthorizationScreen extends ConsumerStatefulWidget {
  const AgentAuthorizationScreen({super.key});

  static Future<void> open(BuildContext context) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AgentAuthorizationScreen()));

  @override
  ConsumerState<AgentAuthorizationScreen> createState() => _AgentAuthorizationScreenState();
}

class _AgentAuthorizationScreenState extends ConsumerState<AgentAuthorizationScreen> {
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
                _bullet(Icons.lock_outline_rounded, lang.tr('Vous approuvez toujours le paiement sur PayPal.', 'You always approve the payment on PayPal.')),
                _bullet(Icons.shield_outlined,
                    lang.tr('Les limites sont vérifiées par le serveur, pas par l’IA.', 'Limits are enforced by the server, not by the AI.')),
                _bullet(Icons.undo_rounded, lang.tr('Vous pouvez retirer l’autorisation à tout moment.', 'You can withdraw the authorization at any time.')),
              ]),
            ),
            const SizedBox(height: 20),
            if (a['active'] == true) ..._active(a, lang) else ..._form(lang),
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

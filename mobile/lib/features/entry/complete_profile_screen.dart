import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/widgets/sika_pay_brand.dart';
import '../profile/presentation/pages/kyc_verification_screen.dart';

/// Pays proposés (code ISO → nom affiché).
const Map<String, String> kSikaCountries = {
  'CI': "Côte d'Ivoire", 'SN': 'Sénégal', 'ML': 'Mali', 'BF': 'Burkina Faso', 'BJ': 'Bénin', 'TG': 'Togo',
  'NE': 'Niger', 'GN': 'Guinée', 'CM': 'Cameroun', 'GH': 'Ghana', 'NG': 'Nigeria', 'FR': 'France',
  'BE': 'Belgique', 'CA': 'Canada', 'US': 'États-Unis', 'GB': 'Royaume-Uni',
};

String countryLabel(String? code) => code == null ? '' : (kSikaCountries[code.toUpperCase()] ?? code);

/// Finalisation du profil — affichée seulement si le mode de connexion n'a pas fourni toutes les
/// informations nécessaires (nom, pays). Seuls les champs manquants sont demandés.
class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  late final TextEditingController _name;
  String _country = 'CI';
  bool _busy = false;
  String? _error;

  String _initialName() {
    final name = ref.read(authProvider).user?.name ?? '';
    return name == 'David YAO' ? '' : name;
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _initialName());
    final current = ref.read(authProvider).user?.country;
    if (current != null && kSikaCountries.containsKey(current.toUpperCase())) _country = current.toUpperCase();
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> missing) async {
    final lang = ref.read(languageProvider.notifier);
    final name = _name.text.trim();
    if (missing.contains('full_name') && name.length < 2) {
      setState(() => _error = lang.tr('Indiquez votre nom complet.', 'Enter your full name.'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).updateProfile(
            name: missing.contains('full_name') ? name : (ref.read(authProvider).user?.name ?? name),
            country: missing.contains('country') ? _country : null,
          );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = lang.tr("Votre profil n'a pas pu être enregistré. Vérifiez votre connexion et réessayez.",
            'Your profile could not be saved. Check your connection and try again.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    final user = ref.watch(authProvider).user;
    final missing = user?.missingFields ?? const <String>[];

    return SikaEntryScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 40),
        Text(lang.tr('Finalisez votre profil', 'Complete your profile'),
            textAlign: TextAlign.center, style: const TextStyle(color: SikaBrand.ink, fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          lang.tr('Il nous manque quelques informations pour sécuriser vos paiements.',
              'We need a few details to keep your payments secure.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: SikaBrand.muted, fontSize: 14.5, height: 1.45),
        ),
        const SizedBox(height: 30),
        if (missing.contains('full_name')) ...[
          SikaField(
            controller: _name,
            label: lang.tr('Nom complet', 'Full name'),
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.name],
          ),
          const SizedBox(height: 16),
        ],
        if (missing.contains('country'))
          DropdownButtonFormField<String>(
            initialValue: _country,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: SikaBrand.muted),
            dropdownColor: Colors.white,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: SikaBrand.ink, fontSize: 15.5, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              labelText: lang.tr('Pays de résidence', 'Country of residence'),
              labelStyle: const TextStyle(color: SikaBrand.muted, fontSize: 14.5),
              prefixIcon: const Icon(Icons.public_rounded, color: SikaBrand.muted, size: 21),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SikaBrand.line)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: SikaBrand.action, width: 1.6)),
            ),
            items: kSikaCountries.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
            onChanged: (v) => setState(() => _country = v ?? _country),
          ),
        const SizedBox(height: 24),
        _IdentityStatus(kycStatus: user?.kycStatus ?? 'none', lang: lang),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: const TextStyle(color: SikaBrand.danger, fontSize: 13.5)),
        ],
        const SizedBox(height: 40),
        SikaPrimaryButton(label: lang.tr('Continuer', 'Continue'), loading: _busy, onPressed: () => _save(missing)),
      ]),
    );
  }
}

/// Statut d'identité affiché tel que le serveur le connaît (jamais supposé par l'application).
class _IdentityStatus extends StatelessWidget {
  final String kycStatus;
  final LanguageNotifier lang;
  const _IdentityStatus({required this.kycStatus, required this.lang});

  @override
  Widget build(BuildContext context) {
    final verified = kycStatus == 'paypal';
    final pending = kycStatus == 'submitted';
    final color = verified ? const Color(0xFF0E9F6E) : (pending ? const Color(0xFFB45309) : SikaBrand.action);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(verified ? Icons.verified_rounded : (pending ? Icons.hourglass_top_rounded : Icons.badge_outlined), color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              verified
                  ? lang.tr('Identité vérifiée par PayPal', 'Identity verified by PayPal')
                  : pending
                      ? lang.tr('Vérification en attente', 'Verification pending')
                      : lang.tr('Identité non vérifiée', 'Identity not verified'),
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              verified
                  ? lang.tr('Votre compte PayPal vérifié suffit : rien à refaire chez nous.',
                      'Your verified PayPal account is enough: nothing to redo here.')
                  : lang.tr('Connectez un compte PayPal vérifié, ou envoyez vos documents depuis votre profil.',
                      'Connect a verified PayPal account, or send your documents from your profile.'),
              style: const TextStyle(color: SikaBrand.muted, fontSize: 13, height: 1.4),
            ),
            if (!verified && !pending)
              TextButton(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KycVerificationScreen())),
                child: Text(lang.tr('Vérifier mon identité', 'Verify my identity'),
                    style: const TextStyle(color: SikaBrand.action, fontWeight: FontWeight.w600)),
              ),
          ]),
        ),
      ]),
    );
  }
}

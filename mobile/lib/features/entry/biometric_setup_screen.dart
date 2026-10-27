import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_setup_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/sika_pay_brand.dart';

/// Étape 3 — Sécurisation, proposée une seule fois et seulement si l'appareil le permet.
/// L'activation est confirmée par une vraie authentification ; « Plus tard » est toujours possible.
class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() => _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _checking = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final available = await ref.read(biometricServiceProvider).isBiometricsAvailable();
      if (!mounted) return;
      if (!available) {
        // Rien à configurer sur cet appareil : l'étape n'apparaît pas
        await ref.read(appSetupProvider.notifier).setBiometric(enabled: false);
      } else {
        setState(() => _checking = false);
      }
    });
  }

  Future<void> _enable() async {
    final lang = ref.read(languageProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(biometricServiceProvider).authenticate(
          localizedReason: lang.tr('Confirmez pour activer la biométrie sur SIKA Pay.', 'Confirm to turn on biometrics for SIKA Pay.'),
        );
    if (!mounted) return;
    if (ok) {
      await ref.read(appSetupProvider.notifier).setBiometric(enabled: true);
    } else {
      setState(() {
        _busy = false;
        _error = lang.tr("La biométrie n'a pas été confirmée. Réessayez ou choisissez « Plus tard ».",
            'Biometrics were not confirmed. Try again or choose "Later".');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    if (_checking) {
      return const Scaffold(backgroundColor: Colors.white, body: Center(child: CircularProgressIndicator(color: SikaBrand.action)));
    }

    return SikaEntryScaffold(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 120),
        const Icon(Icons.fingerprint_rounded, size: 84, color: SikaBrand.royal),
        const SizedBox(height: 28),
        Text(
          lang.tr('Utiliser la biométrie pour vous connecter et autoriser vos paiements ?',
              'Use biometrics to sign in and authorise your payments?'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: SikaBrand.ink, fontSize: 21, fontWeight: FontWeight.w700, height: 1.3),
        ),
        const SizedBox(height: 12),
        Text(
          lang.tr("C'est plus rapide, et personne d'autre ne pourra payer depuis votre téléphone.",
              "It's quicker, and no one else can pay from your phone."),
          textAlign: TextAlign.center,
          style: const TextStyle(color: SikaBrand.muted, fontSize: 15, height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SikaBrand.danger, fontSize: 13.5)),
        ],
        const SizedBox(height: 110),
        SikaPrimaryButton(label: lang.tr('Activer la biométrie', 'Turn on biometrics'), loading: _busy, onPressed: _enable),
        const SizedBox(height: 12),
        SikaOutlineButton(
          label: lang.tr('Plus tard', 'Later'),
          onPressed: _busy ? null : () => ref.read(appSetupProvider.notifier).setBiometric(enabled: false),
        ),
      ]),
    );
  }
}

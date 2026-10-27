import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/app_setup_provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/providers/language_provider.dart';
import '../../core/services/biometric_service.dart';
import '../../core/widgets/sika_pay_brand.dart';

/// Déverrouillage d'une session restaurée, uniquement si l'utilisateur a activé la biométrie.
/// Sans capteur ni verrouillage d'écran sur l'appareil, l'étape est passée.
class BiometricLockScreen extends ConsumerStatefulWidget {
  const BiometricLockScreen({super.key});

  @override
  ConsumerState<BiometricLockScreen> createState() => _BiometricLockScreenState();
}

class _BiometricLockScreenState extends ConsumerState<BiometricLockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final available = await ref.read(biometricServiceProvider).isBiometricsAvailable();
      if (!mounted) return;
      if (!available) {
        ref.read(appSetupProvider.notifier).unlock();
      } else {
        _authenticate();
      }
    });
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    final lang = ref.read(languageProvider.notifier);
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await ref.read(biometricServiceProvider).authenticate(
          localizedReason: lang.tr('Confirmez votre identité pour ouvrir SIKA Pay.', 'Confirm your identity to open SIKA Pay.'),
        );
    if (!mounted) return;
    if (ok) {
      ref.read(appSetupProvider.notifier).unlock();
    } else {
      setState(() {
        _busy = false;
        _error = lang.tr('Identité non confirmée. Réessayez ou utilisez votre mot de passe.',
            'Identity not confirmed. Try again or use your password.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    return SikaEntryScaffold(
      child: Column(children: [
        const SizedBox(height: 24),
        Text(lang.tr('SIKA Pay est verrouillé', 'SIKA Pay is locked'),
            style: const TextStyle(color: SikaBrand.ink, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 56),
        Semantics(
          button: true,
          label: lang.tr("Utiliser l'empreinte", 'Use fingerprint'),
          child: GestureDetector(
            onTap: _authenticate,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: SikaBrand.royal,
                borderRadius: BorderRadius.circular(34),
                boxShadow: [BoxShadow(color: SikaBrand.cyan.withValues(alpha: 0.55), blurRadius: 28, spreadRadius: 2)],
                border: Border.all(color: SikaBrand.cyan, width: 2),
              ),
              child: const Icon(Icons.fingerprint_rounded, color: SikaBrand.cyan, size: 82),
            ),
          ),
        ),
        const SizedBox(height: 44),
        Text(lang.tr('Confirmez votre identité', 'Confirm your identity'),
            style: const TextStyle(color: SikaBrand.ink, fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          lang.tr('Utilisez votre empreinte digitale\npour accéder à votre compte.', 'Use your fingerprint\nto access your account.'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: SikaBrand.muted, fontSize: 15, height: 1.45),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: SikaBrand.danger, fontSize: 13.5)),
        ],
        const SizedBox(height: 56),
        SikaOutlineButton(
          label: lang.tr("Utiliser l'empreinte", 'Use fingerprint'),
          leading: const Icon(Icons.fingerprint_rounded, size: 22),
          onPressed: _busy ? null : _authenticate,
        ),
        const SizedBox(height: 10),
        TextButton(
          // Le mot de passe passe par l'écran de connexion : la session restaurée est fermée.
          onPressed: () => ref.read(authProvider.notifier).logout(),
          child: Text(lang.tr('Utiliser le mot de passe', 'Use password'),
              style: const TextStyle(color: SikaBrand.action, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}

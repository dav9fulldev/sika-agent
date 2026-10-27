import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/language_provider.dart';

import '../../core/widgets/sika_pay_brand.dart';

/// Écran 2 — Chargement : affiché pendant la restauration de la session.
class SikaLoadingScreen extends ConsumerWidget {
  const SikaLoadingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            const Spacer(flex: 4),
            const SikaPayLogo(size: 84),
            const SizedBox(height: 20),
            const SikaPayWordmark(fontSize: 32),
            const SizedBox(height: 34),
            Text(lang.tr('Chargement de votre assistant IA…', 'Loading your AI assistant…'),
                style: const TextStyle(color: SikaBrand.muted, fontSize: 15)),
            const SizedBox(height: 22),
            const SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: SikaBrand.action, strokeCap: StrokeCap.round),
            ),
            const Spacer(flex: 5),
            Text(
              lang.tr('Une expérience de paiement plus simple avec PayPal.', 'A simpler way to pay with PayPal.'),
              textAlign: TextAlign.center,
              style: const TextStyle(color: SikaBrand.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

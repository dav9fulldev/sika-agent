import 'package:flutter/material.dart';

import '../../core/widgets/sika_pay_brand.dart';

/// Écran 2 — Chargement : affiché pendant la restauration de la session.
class SikaLoadingScreen extends StatelessWidget {
  const SikaLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32),
          child: Column(children: [
            Spacer(flex: 4),
            SikaPayLogo(size: 84),
            SizedBox(height: 20),
            SikaPayWordmark(fontSize: 32),
            SizedBox(height: 34),
            Text('Chargement de votre assistant IA…', style: TextStyle(color: SikaBrand.muted, fontSize: 15)),
            SizedBox(height: 22),
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(strokeWidth: 3, color: SikaBrand.action, strokeCap: StrokeCap.round),
            ),
            Spacer(flex: 5),
            Text(
              'Une expérience de paiement plus simple avec PayPal.',
              textAlign: TextAlign.center,
              style: TextStyle(color: SikaBrand.muted, fontSize: 13),
            ),
            SizedBox(height: 20),
          ]),
        ),
      ),
    );
  }
}

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/sika_pay_brand.dart';

/// Écran 1 — Démarrage : logo, nom et promesse de SIKA Pay.
/// Le seul mouvement est la vague du bas, qui reprend les traits de vitesse du logo.
class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _wave =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) widget.onFinish();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduceMotion) {
      _wave.stop();
    } else if (!_wave.isAnimating) {
      _wave.repeat();
    }
  }

  @override
  void dispose() {
    _wave.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(children: [
        const Positioned.fill(
          child: Column(children: [
            Spacer(flex: 5),
            SikaPayLogo(size: 104),
            SizedBox(height: 26),
            SikaPayWordmark(fontSize: 40),
            SizedBox(height: 12),
            Text(
              'Your AI. Your Money. Your Control.',
              style: TextStyle(color: SikaBrand.ink, fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: 0.1),
            ),
            Spacer(flex: 7),
          ]),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: MediaQuery.of(context).size.height * 0.30,
          child: AnimatedBuilder(
            animation: _wave,
            builder: (context, _) => CustomPaint(painter: _WavePainter(_wave.value)),
          ),
        ),
      ]),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t;
  _WavePainter(this.t);

  Path _wave(Size size, double baseline, double amplitude, double phase) {
    final path = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 4) {
      final y = baseline + amplitude * math.sin((x / size.width * 2 * math.pi) + phase);
      path.lineTo(x, y);
    }
    return path
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final phase = t * 2 * math.pi;
    final rect = Offset.zero & size;

    canvas.drawPath(
      _wave(size, size.height * 0.32, size.height * 0.10, phase),
      Paint()
        ..shader = LinearGradient(
          colors: [SikaBrand.cyan.withValues(alpha: 0.35), SikaBrand.action.withValues(alpha: 0.30)],
        ).createShader(rect),
    );
    canvas.drawPath(
      _wave(size, size.height * 0.52, size.height * 0.12, -phase + 1.2),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SikaBrand.cyan, SikaBrand.action, SikaBrand.royal],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t;
}

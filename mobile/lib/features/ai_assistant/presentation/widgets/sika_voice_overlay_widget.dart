import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';

/// SikaVoiceOverlayWidget — Siri-style animated voice listening overlay.
/// Placed inside a global Stack above IndexedStack in SikaMainNavigationPage.
class SikaVoiceOverlayWidget extends ConsumerStatefulWidget {
  const SikaVoiceOverlayWidget({super.key});

  @override
  ConsumerState<SikaVoiceOverlayWidget> createState() =>
      _SikaVoiceOverlayWidgetState();
}

class _SikaVoiceOverlayWidgetState extends ConsumerState<SikaVoiceOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _waveController;
  late Animation<double> _orbPulseAnimation;

  @override
  void initState() {
    super.initState();

    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _orbPulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(
        parent: _orbController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _orbController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    final langNotifier = ref.read(languageProvider.notifier);

    final bool isActive = sikaData.state == SikaState.listening ||
        sikaData.state == SikaState.processing ||
        sikaData.state == SikaState.speaking;

    final String recognizedText = sikaData.currentText ?? '';

    // L'overlay vocal ne doit s'afficher que si on est en mode vocal !
    if (!sikaData.isVoiceMode || !isActive) return const SizedBox.shrink();

    String titleText = '';
    String subText = '';
    bool hasSubText = false;

    if (sikaData.state == SikaState.listening) {
      titleText = langNotifier.tr('Sika écoute...', 'Sika listening...');
      subText = recognizedText.isNotEmpty
          ? recognizedText
          : langNotifier.tr('Parlez maintenant', 'Speak now');
      hasSubText = recognizedText.isNotEmpty;
    } else if (sikaData.state == SikaState.processing) {
      titleText = langNotifier.tr('Sika réfléchit...', 'Sika is thinking...');
      subText = recognizedText.isNotEmpty ? recognizedText : '';
      hasSubText = true;
    } else if (sikaData.state == SikaState.speaking) {
      titleText =
          ''; // L'utilisateur ne veut voir AUCUN texte, juste l'animation vocale.
      subText = '';
      hasSubText = false;
    }

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: Theme.of(context)
                .scaffoldBackgroundColor
                .withValues(alpha: 0.90),
            child: SafeArea(
              child: Column(
                children: [
                  // 1. BARRE SUPÉRIEURE (BOUTON RETOUR)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
                              size: 28),
                          onPressed: () async {
                            await sikaNotifier.stopListening();
                            sikaNotifier.clearConversation();
                          },
                        ).animate().fade().scale(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. TITRE DE L'ÉCROUTE SIKA
                  Text(
                    titleText,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                  ).animate().fade().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 10),

                  // RECONNAISSANCE VOCALE EN DIRECT OU INSTRUCTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      maxLines: 5,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: hasSubText
                                ? Theme.of(context).colorScheme.onSurface
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                            fontWeight: hasSubText
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ),
                  ).animate().fade(delay: 200.ms),

                  const Spacer(),

                  // 3. SPHÈRE / ORBE ANIMÉE STYLE SIRI (NEON SPHERE)
                  GestureDetector(
                    onTap: () async {
                      if (sikaData.state == SikaState.listening) {
                        await sikaNotifier.stopListening();
                      } else if (sikaData.state == SikaState.speaking) {
                        sikaNotifier.stopSpeaking();
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _orbPulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _orbPulseAnimation.value,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const RadialGradient(
                                colors: [
                                  Color(0xFF38BDF8),
                                  Color(0xFF635BFF),
                                  Color(0xFFA855F7),
                                  Colors.transparent,
                                ],
                                stops: [0.1, 0.45, 0.8, 1.0],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF38BDF8)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 45,
                                  spreadRadius: 10,
                                ),
                                BoxShadow(
                                  color: const Color(0xFF635BFF)
                                      .withValues(alpha: 0.6),
                                  blurRadius: 60,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      blurRadius: 16,
                                      spreadRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                      .animate()
                      .fade(duration: 800.ms)
                      .scale(delay: 100.ms, duration: 400.ms),

                  const Spacer(),

                  // 4. ONDES AUDIO VISUELLES (SOUNDWAVE PAINTER)
                  SizedBox(
                    height: 80,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter:
                              _SiriWavePainter(progress: _waveController.value),
                        );
                      },
                    ),
                  ).animate().fade(delay: 300.ms),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SiriWavePainter extends CustomPainter {
  final double progress;

  _SiriWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;
    final width = size.width;

    // 1. ONDE BLEUE PRINCIPALE
    final paintBlue = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final pathBlue = Path();
    pathBlue.moveTo(0, midY);

    for (double x = 0; x <= width; x += 1) {
      final normalizedX = x / width;
      final envelope = math.sin(normalizedX * math.pi);
      final y = midY +
          math.sin((normalizedX * 4 * math.pi) + (progress * 2 * math.pi)) *
              16 *
              envelope;
      pathBlue.lineTo(x, y);
    }
    canvas.drawPath(pathBlue, paintBlue);

    // 2. ONDE VIOLETTE EN DÉCALAGE DE PHASE
    final paintPurple = Paint()
      ..color = const Color(0xFFA855F7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final pathPurple = Path();
    pathPurple.moveTo(0, midY);

    for (double x = 0; x <= width; x += 1) {
      final normalizedX = x / width;
      final envelope = math.sin(normalizedX * math.pi);
      final y = midY +
          math.sin((normalizedX * 3 * math.pi) - (progress * 2 * math.pi)) *
              12 *
              envelope;
      pathPurple.lineTo(x, y);
    }
    canvas.drawPath(pathPurple, paintPurple);
  }

  @override
  bool shouldRepaint(covariant _SiriWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

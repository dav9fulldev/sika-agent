import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';

/// SikaVoiceOverlayWidget — Siri-style animated voice listening overlay.
/// Placed inside a global Stack above IndexedStack in SikaMainNavigationPage.
class SikaVoiceOverlayWidget extends ConsumerStatefulWidget {
  const SikaVoiceOverlayWidget({super.key});

  @override
  ConsumerState<SikaVoiceOverlayWidget> createState() => _SikaVoiceOverlayWidgetState();
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

    final bool isListening = sikaData.state == SikaState.listening;
    final String recognizedText = sikaData.currentText ?? '';

    if (!isListening) return const SizedBox.shrink();

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            color: const Color(0xF2020614), // Dark translucent backdrop (95% opacity)
            child: SafeArea(
              child: Column(
                children: [
                  // 1. BARRE SUPÉRIEURE (BOUTON RETOUR ET TITRE)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
                          onPressed: () async {
                            await sikaNotifier.stopListening();
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 2. TITRE DE L'ÉCROUTE SIKA
                  Text(
                    langNotifier.tr('Sika écoute...', 'Sika listening...'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // RECONNAISSANCE VOCALE EN DIRECT OU INSTRUCTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      recognizedText.isNotEmpty
                          ? recognizedText
                          : langNotifier.tr('Parlez maintenant', 'Speak now'),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: recognizedText.isNotEmpty
                            ? Colors.white
                            : const Color(0xFF94A3B8),
                        fontSize: recognizedText.isNotEmpty ? 17 : 14,
                        fontWeight: recognizedText.isNotEmpty
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),

                  const Spacer(),

                  // 3. SPHÈRE / ORBE ANIME STYLE SIRI (NEON SPHERE)
                  AnimatedBuilder(
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
                                Color(0xFF38BDF8), // Cyan center
                                Color(0xFF635BFF), // Sika Violet
                                Color(0xFFA855F7), // Purple glow
                                Colors.transparent,
                              ],
                              stops: [0.1, 0.45, 0.8, 1.0],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.5),
                                blurRadius: 45,
                                spreadRadius: 10,
                              ),
                              BoxShadow(
                                color: const Color(0xFF635BFF).withValues(alpha: 0.6),
                                blurRadius: 60,
                                spreadRadius: 20,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white,
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

                  const Spacer(),

                  // 4. ONDES AUDIO VISUELLES (SOUNDWAVE PAINTER)
                  SizedBox(
                    height: 60,
                    width: double.infinity,
                    child: AnimatedBuilder(
                      animation: _waveController,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: _SiriWavePainter(progress: _waveController.value),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 5. BOUTON MICROPHONE ET BOUTON ANNULER
                  Column(
                    children: [
                      // BOUTON MICROPHONE CENTRÉ
                      GestureDetector(
                        onTap: () async {
                          await sikaNotifier.stopListening();
                        },
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF0B1329),
                            border: Border.all(
                              color: const Color(0xFF10B981),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 16,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // BOUTON ANNULER
                      SizedBox(
                        width: 140,
                        height: 44,
                        child: TextButton(
                          onPressed: () async {
                            await sikaNotifier.stopListening();
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22),
                            ),
                          ),
                          child: Text(
                            langNotifier.tr('Annuler', 'Cancel'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

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

/// Custom painter for smooth animated Siri-style audio soundwaves
class _SiriWavePainter extends CustomPainter {
  final double progress;

  _SiriWavePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;

    final Paint cyanPaint = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final Paint purplePaint = Paint()
      ..color = const Color(0xFFA855F7).withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final Path path1 = Path();
    final Path path2 = Path();

    path1.moveTo(0, midY);
    path2.moveTo(0, midY);

    for (double x = 0; x <= size.width; x += 4) {
      final double normX = x / size.width;
      // Envelope curve so waves taper at left and right edges
      final double envelope = math.sin(normX * math.pi);

      final double y1 = midY + math.sin(normX * math.pi * 6 + progress * math.pi * 2) * 18 * envelope;
      final double y2 = midY + math.cos(normX * math.pi * 4 - progress * math.pi * 2) * 14 * envelope;

      path1.lineTo(x, y1);
      path2.lineTo(x, y2);
    }

    canvas.drawPath(path1, cyanPaint);
    canvas.drawPath(path2, purplePaint);
  }

  @override
  bool shouldRepaint(covariant _SiriWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

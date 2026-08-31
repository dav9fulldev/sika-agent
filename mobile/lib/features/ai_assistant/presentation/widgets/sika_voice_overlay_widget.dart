import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';

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
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final String recognizedText = sikaData.currentText ?? '';

    // L'overlay vocal ne doit s'afficher que si on est en mode vocal !
    if (!sikaData.isVoiceMode) return const SizedBox.shrink();

    String titleText = '';
    String subText = '';
    bool hasSubText = false;
    bool showError = false;

    if (sikaData.state == SikaState.idle) {
      titleText = langNotifier.tr('En attente...', 'Waiting...');
      subText = langNotifier.tr('Appuyez sur l\'orbe pour parler', 'Tap the orb to speak');
      hasSubText = true;
    } else if (sikaData.state == SikaState.listening) {
      titleText = langNotifier.tr('Je vous écoute', 'I\'m listening');
      subText = langNotifier.tr('Parlez maintenant...', 'Speak now...');
      hasSubText = true;
    } else if (sikaData.state == SikaState.processing) {
      titleText = langNotifier.tr('SIKA analyse votre demande', 'SIKA is analyzing your request');
      subText = '';
      hasSubText = false;
    } else if (sikaData.state == SikaState.speaking) {
      titleText = langNotifier.tr('SIKA parle', 'SIKA is speaking');
      subText = '';
      hasSubText = false;
    } else if (sikaData.state == SikaState.waitingVoiceConfirmation) {
      titleText = langNotifier.tr('Confirmation requise', 'Confirmation required');
      subText = langNotifier.tr('Veuillez confirmer l\'opération vocale.', 'Please confirm the voice operation.');
      hasSubText = true;
    } else if (sikaData.state == SikaState.securityValidation) {
      titleText = langNotifier.tr('Validation de sécurité', 'Security validation');
      subText = langNotifier.tr('SIKA sécurise la transaction...', 'SIKA is securing the transaction...');
      hasSubText = true;
    } else if (sikaData.state == SikaState.error) {
      titleText = langNotifier.tr('Une erreur est survenue', 'An error occurred');
      subText = sikaData.errorMessage ?? langNotifier.tr('SIKA n\'a pas pu répondre.', 'SIKA could not respond.');
      hasSubText = true;
      showError = true;
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: isDark 
                ? AppColors.darkBackground.withValues(alpha: 0.85)
                : AppColors.lightBackground.withValues(alpha: 0.90),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  
                  // 1. IDENTITÉ SIKA (Petite icône haut)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.brandPrimary.withValues(alpha: 0.4),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text('✦', style: TextStyle(fontSize: 22, color: Colors.white)),
                    ),
                  ).animate().fade().slideY(begin: -0.2, end: 0),
                  
                  const SizedBox(height: 32),

                  // 2. ÉTAT ACTUEL (Titre)
                  Text(
                    titleText,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: showError ? AppColors.error : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                  ).animate().fade().slideY(begin: 0.1, end: 0),
                  
                  const SizedBox(height: 16),

                  // 3. TRANSCRIPTION
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: hasSubText
                          ? Text(
                              subText,
                              key: ValueKey<String>(subText),
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: showError
                                        ? AppColors.error.withValues(alpha: 0.8)
                                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontWeight: recognizedText.isNotEmpty ? FontWeight.w500 : FontWeight.normal,
                                    fontStyle: recognizedText.isNotEmpty ? FontStyle.italic : FontStyle.normal,
                                    height: 1.4,
                                  ),
                            )
                          : const SizedBox(height: 28),
                    ),
                  ),

                  const Spacer(),

                  // 4. ANIMATION VOCALE & ORBE
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ondes Audio
                        if (sikaData.state == SikaState.listening || sikaData.state == SikaState.speaking)
                          Positioned.fill(
                            child: AnimatedBuilder(
                              animation: _waveController,
                              builder: (context, child) {
                                return CustomPaint(
                                  painter: _SiriWavePainter(progress: _waveController.value),
                                );
                              },
                            ),
                          ).animate().fade(duration: 600.ms),
                          
                        // Orbe Central
                        GestureDetector(
                          onTap: () async {
                            if (sikaData.state == SikaState.listening) {
                              await sikaNotifier.stopListening();
                            } else if (sikaData.state == SikaState.speaking) {
                              sikaNotifier.stopSpeaking(resetState: false);
                            } else if (sikaData.state == SikaState.idle || sikaData.state == SikaState.error) {
                              sikaNotifier.startListening();
                            }
                          },
                          child: AnimatedBuilder(
                            animation: _orbPulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: (sikaData.state == SikaState.listening || sikaData.state == SikaState.speaking) ? _orbPulseAnimation.value : 1.0,
                                child: Container(
                                  width: 140,
                                  height: 140,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: RadialGradient(
                                      colors: [
                                        showError ? AppColors.error : const Color(0xFF38BDF8),
                                        showError ? AppColors.error.withValues(alpha: 0.5) : const Color(0xFF635BFF),
                                        Colors.transparent,
                                      ],
                                      stops: const [0.1, 0.5, 1.0],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (showError ? AppColors.error : AppColors.brandPrimary).withValues(alpha: 0.4),
                                        blurRadius: 40,
                                        spreadRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isDark ? AppColors.darkSurfaceHighlight : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ).animate().fade(duration: 800.ms).scale(),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 5. BOUTON D'ACTION (Annuler / Réessayer / Fermer)
                  GestureDetector(
                    onTap: () async {
                      if (showError) {
                        sikaNotifier.clearConversation();
                      } else {
                        await sikaNotifier.stopListening();
                        sikaNotifier.clearConversation();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        showError
                            ? langNotifier.tr('Fermer', 'Close')
                            : langNotifier.tr('Annuler', 'Cancel'),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ).animate().fade().slideY(begin: 0.2, end: 0),
                  
                  const SizedBox(height: 40),
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

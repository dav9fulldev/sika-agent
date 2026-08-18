import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';

/// SecurityAnimation — Screen 3 Hero Visual (Bilingual English & French)
class SecurityAnimation extends ConsumerStatefulWidget {
  const SecurityAnimation({super.key});

  @override
  ConsumerState<SecurityAnimation> createState() => _SecurityAnimationState();
}

class _SecurityAnimationState extends ConsumerState<SecurityAnimation>
    with TickerProviderStateMixin {
  late AnimationController _tiltController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _tiltAnimation;

  @override
  void initState() {
    super.initState();
    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _tiltAnimation = Tween<double>(begin: -0.15, end: 0.15).animate(
      CurvedAnimation(
        parent: _tiltController,
        curve: Curves.easeInOut,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _tiltController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    return AnimatedBuilder(
      animation: Listenable.merge([_tiltController, _pulseController]),
      builder: (context, child) {
        return SizedBox(
          height: 300,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. AURA DU BOUCLIER DE SÉCURITÉ ÉMERAUDE
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.emerald.withValues(alpha: 0.3),
                      AppColors.cyan.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. ANNEAUX DE SÉCURITÉ EN PULSATION
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.emerald.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // 3. BOUCLIER ET CADENAS CENTRAL AVEC INCLINAISON 3D
              Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001)
                  ..rotateY(_tiltAnimation.value),
                alignment: Alignment.center,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.emerald, AppColors.cyan],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.emerald.withValues(alpha: 0.6),
                        blurRadius: 25,
                        spreadRadius: 3,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 52,
                    ),
                  ),
                ),
              ),

              // 4. BADGES FLOTTANTS DE SÉCURITÉ AUTOUR DU BOUCLIER
              Positioned(
                top: 50,
                right: 80,
                child: _buildBadge(
                  Icons.fingerprint,
                  langNotifier.tr('Biométrie', 'Biometrics'),
                  AppColors.emerald,
                ),
              ),
              Positioned(
                bottom: 60,
                left: 70,
                child: _buildBadge(
                  Icons.lock_outline_rounded,
                  langNotifier.tr('Contrôle Humain', 'Human-in-the-Loop'),
                  AppColors.cyan,
                ),
              ),
              Positioned(
                top: 50,
                left: 65,
                child: _buildBadge(
                  Icons.verified_user_rounded,
                  langNotifier.tr('Sécurisé', 'Secured'),
                  AppColors.amber,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 20,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

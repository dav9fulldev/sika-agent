import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// FinancialAnimation — Écran 2 Amélioré avec textes dynamiques textuels
class FinancialAnimation extends StatefulWidget {
  const FinancialAnimation({super.key});

  @override
  State<FinancialAnimation> createState() => _FinancialAnimationState();
}

class _FinancialAnimationState extends State<FinancialAnimation> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Rotation orbitale fluide (12 secondes pour faire un tour complet)
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Effet de pulsation continue pour le cœur central
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        // L'angle global actuel de l'orbite (entre 0 et 2*pi)
        final double globalAngle = _rotationController.value * 2 * math.pi;

        return SizedBox(
          height: 360, // Ajusté à 360 pour donner de l'espace aux bulles de texte
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. Halo lumineux central ambiant
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withValues(alpha: 0.20),
                      AppColors.indigo.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. Ligne orbitale en anneau discret
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
              ),

              // 3. Cœur central Sika avec sa pulsation magique
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.indigo],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.5),
                        blurRadius: 25,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 38,
                    ),
                  ),
                ),
              ),

              // 4. Les nœuds financiers en mouvement ET leurs messages respectifs
              ..._buildOrbitingNodesAndMessages(globalAngle),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildOrbitingNodesAndMessages(double currentGlobalAngle) {
    final nodes = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.cyan,
        'message': 'Suivi du portefeuille en temps réel',
        'offsetAngle': 0.0,
      },
      {
        'icon': Icons.bar_chart_rounded,
        'color': AppColors.emerald,
        'message': 'Analyses prédictives de vos dépenses',
        'offsetAngle': (2 * math.pi) / 4,
      },
      {
        'icon': Icons.notifications_active_rounded,
        'color': AppColors.rose,
        'message': 'Alertes instantanées en cas d\'anomalie',
        'offsetAngle': (4 * math.pi) / 4,
      },
      {
        'icon': Icons.savings_rounded,
        'color': AppColors.amber,
        'message': 'Optimisation automatique de l\'épargne',
        'offsetAngle': (6 * math.pi) / 4,
      },
    ];

    const double radius = 110.0;

    return nodes.map((node) {
      final double totalAngle = currentGlobalAngle + (node['offsetAngle'] as double);

      final double dx = radius * math.cos(totalAngle);
      final double dy = radius * math.sin(totalAngle);

      final Color color = node['color'] as Color;
      final IconData icon = node['icon'] as IconData;
      final String message = node['message'] as String;

      final double angleNormalized = totalAngle % (2 * math.pi);

      double activationFactor = -math.sin(angleNormalized);
      activationFactor = activationFactor.clamp(0.0, 1.0);

      final double opacityValue = math.pow(activationFactor, 2.5).toDouble();
      final double scaleValue = 0.7 + (opacityValue * 0.3);

      return Stack(
        alignment: Alignment.center,
        children: [
          // A) LA BULLE DE TEXTE DYNAMIQUE
          if (opacityValue > 0.05)
            Transform.translate(
              offset: Offset(dx, dy - 48),
              child: Opacity(
                opacity: opacityValue,
                child: Transform.scale(
                  scale: scaleValue,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xff1e293b).withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // B) L'ICÔNE FINANCIÈRE EN ROTATION
          Transform.translate(
            offset: Offset(dx, dy),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: const Color(0xff090d1a),
                shape: BoxShape.circle,
                border: Border.all(
                  color: opacityValue > 0.5 ? color : color.withValues(alpha: 0.5),
                  width: opacityValue > 0.5 ? 2.0 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: opacityValue > 0.5 ? 0.4 : 0.2),
                    blurRadius: opacityValue > 0.5 ? 14 : 8,
                    spreadRadius: opacityValue > 0.5 ? 1 : 0,
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: color,
                size: 22,
              ),
            ),
          ),
        ],
      );
    }).toList();
  }
}

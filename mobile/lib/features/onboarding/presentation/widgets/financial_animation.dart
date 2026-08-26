import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';

/// FinancialAnimation — Écran 2 Amélioré avec textes dynamiques multilingues
class FinancialAnimation extends ConsumerStatefulWidget {
  const FinancialAnimation({super.key});

  @override
  ConsumerState<FinancialAnimation> createState() => _FinancialAnimationState();
}

class _FinancialAnimationState extends ConsumerState<FinancialAnimation> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

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
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    return AnimatedBuilder(
      animation: Listenable.merge([_rotationController, _pulseController]),
      builder: (context, child) {
        final double globalAngle = _rotationController.value * 2 * math.pi;

        return SizedBox(
          height: 360,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. ANNEAU D'ORBITE LUMINEUX ACCENTUÉ
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),

              // 2. CŒUR INTEL SIKA REHAUSSÉ
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0xff38bdf8),
                        Color(0xff3b82f6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff38bdf8).withValues(alpha: 0.6),
                        blurRadius: 28,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Theme.of(context).colorScheme.onSurface,
                      size: 44,
                    ),
                  ),
                ),
              ),

              // 3. NODES ET BULLES DYNAMIQUES DU SYSTÈME SIKA
              ..._buildOrbitingNodesWithMessages(globalAngle, langNotifier),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildOrbitingNodesWithMessages(double currentGlobalAngle, LanguageNotifier langNotifier) {
    final List<Map<String, dynamic>> nodes = [
      {
        'icon': Icons.insights_rounded,
        'color': AppColors.emerald,
        'message': langNotifier.tr('Analyses prédictives de vos dépenses', 'Predictive spending analysis'),
        'offsetAngle': 0.0,
      },
      {
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.cyan,
        'message': langNotifier.tr('Gestion multi-portefeuilles Wave & OM', 'Multi-wallet Wave & OM management'),
        'offsetAngle': math.pi / 2,
      },
      {
        'icon': Icons.notifications_active_rounded,
        'color': AppColors.rose,
        'message': langNotifier.tr('Alertes instantanées en cas d\'anomalie', 'Instant anomaly alerts'),
        'offsetAngle': math.pi,
      },
      {
        'icon': Icons.savings_rounded,
        'color': AppColors.amber,
        'message': langNotifier.tr('Optimisation automatique de l\'épargne', 'Autonomous savings booster'),
        'offsetAngle': (3 * math.pi) / 2,
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
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),

          Transform.translate(
            offset: Offset(dx, dy),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xff0b1329),
                border: Border.all(color: color, width: 1.8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22),
            ),
          ),
        ],
      );
    }).toList();
  }
}

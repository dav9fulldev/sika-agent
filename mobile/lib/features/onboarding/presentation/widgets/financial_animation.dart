import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../../../core/constants/app_colors.dart';

/// FinancialAnimation — Screen 2 Hero Visual
/// Financial ecosystem around SIKA core: orbiting nodes, growing charts, and glowing connections
class FinancialAnimation extends StatefulWidget {
  const FinancialAnimation({super.key});

  @override
  State<FinancialAnimation> createState() => _FinancialAnimationState();
}

class _FinancialAnimationState extends State<FinancialAnimation>
    with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    // Continuous orbital rotation
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Pulse loop
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.15).animate(
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
        final double angle = _rotationController.value * 2 * math.pi;

        return SizedBox(
          height: 280,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. BACKGROUND GLOWING PULSE
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.cyan.withValues(alpha: 0.25),
                      AppColors.indigo.withValues(alpha: 0.1),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),

              // 2. CONNECTING DASHED LINES & ORBITAL RING
              Container(
                width: 210,
                height: 210,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.cyan.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),

              // 3. CENTER SIKA CORE NODE
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [AppColors.cyan, AppColors.indigo],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.cyan.withValues(alpha: 0.6),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ),
              ),

              // 4. ORBITING FINANCIAL NODES
              ..._buildOrbitingNodes(angle),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildOrbitingNodes(double currentAngle) {
    final nodes = [
      {
        'icon': Icons.account_balance_wallet_rounded,
        'color': AppColors.cyan,
        'label': 'Portefeuille',
        'offsetAngle': 0.0,
      },
      {
        'icon': Icons.bar_chart_rounded,
        'color': AppColors.emerald,
        'label': 'Analyses',
        'offsetAngle': (2 * math.pi) / 4,
      },
      {
        'icon': Icons.notifications_active_rounded,
        'color': AppColors.rose,
        'label': 'Alertes',
        'offsetAngle': (4 * math.pi) / 4,
      },
      {
        'icon': Icons.savings_rounded,
        'color': AppColors.amber,
        'label': 'Épargne',
        'offsetAngle': (6 * math.pi) / 4,
      },
    ];

    const double radius = 105.0;

    return nodes.map((node) {
      final double totalAngle = currentAngle + (node['offsetAngle'] as double);
      final double dx = radius * math.cos(totalAngle);
      final double dy = radius * math.sin(totalAngle);
      final Color color = node['color'] as Color;
      final IconData icon = node['icon'] as IconData;

      return Transform.translate(
        offset: Offset(dx, dy),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color,
            size: 22,
          ),
        ),
      );
    }).toList();
  }
}

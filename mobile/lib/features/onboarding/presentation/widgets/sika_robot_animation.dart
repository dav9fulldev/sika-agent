import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../../../../core/constants/app_colors.dart';

/// SikaRobotAnimation — Screen 1 Hero Visual with Integrated Lottie Animation
/// Smooth floating robot with breathing halo, pulsing platform, and micro-animated JSON movements
class SikaRobotAnimation extends StatefulWidget {
  const SikaRobotAnimation({super.key});

  @override
  State<SikaRobotAnimation> createState() => _SikaRobotAnimationState();
}

class _SikaRobotAnimationState extends State<SikaRobotAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _floatAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _platformScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    // Smooth floating translation
    _floatAnimation = Tween<double>(begin: -10.0, end: 10.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Breathing glow animation
    _glowAnimation = Tween<double>(begin: 0.25, end: 0.55).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // Platform scale animation
    _platformScaleAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return SizedBox(
          height: 380,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // 1. BREATHING RADIANT HALO
              Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.indigo.withValues(alpha: _glowAnimation.value),
                      AppColors.cyan
                          .withValues(alpha: _glowAnimation.value * 0.5),
                      Colors.transparent,
                    ],
                    stops: const [0.2, 0.6, 1.0],
                  ),
                ),
              ),

              // 2. PULSING PLATFORM UNDER ROBOT
              Positioned(
                bottom: 25,
                child: Transform.scale(
                  scaleX: _platformScaleAnimation.value,
                  scaleY: 0.5,
                  child: Container(
                    width: 200,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyan.withValues(alpha: 0.6),
                          blurRadius: 25,
                          spreadRadius: 5,
                        ),
                        BoxShadow(
                          color: AppColors.indigo.withValues(alpha: 0.8),
                          blurRadius: 45,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. ENTIRELY ANIMATED LOTTIE ROBOT
              Transform.translate(
                offset: Offset(0, _floatAnimation.value),
                child: Lottie.asset(
                  'assets/images/robot.json',
                  height: 320,
                  fit: BoxFit.contain,
                  animate: true,
                  repeat: true,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.indigo.withValues(alpha: 0.3),
                      border: Border.all(color: AppColors.cyan, width: 2),
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      color: AppColors.cyan,
                      size: 100,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

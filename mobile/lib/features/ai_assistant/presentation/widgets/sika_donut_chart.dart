import 'dart:math' as math;
import 'package:flutter/material.dart';

class SikaDonutChart extends StatelessWidget {
  final List<double> percentages;
  final List<Color> colors;
  final double size;
  final double strokeWidth;
  final Widget? centerContent;

  const SikaDonutChart({
    super.key,
    required this.percentages,
    required this.colors,
    this.size = 180,
    this.strokeWidth = 24.0,
    this.centerContent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark 
        ? Colors.white.withValues(alpha: 0.05) 
        : Colors.black.withValues(alpha: 0.05);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _SikaDonutPainter(
              percentages: percentages,
              colors: colors,
              backgroundColor: backgroundColor,
              strokeWidth: strokeWidth,
            ),
          ),
          if (centerContent != null) centerContent!,
        ],
      ),
    );
  }
}

class _SikaDonutPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;
  final Color backgroundColor;
  final double strokeWidth;

  _SikaDonutPainter({
    required this.percentages,
    required this.colors,
    required this.backgroundColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (size.width - strokeWidth) / 2;

    final Paint backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = backgroundColor;

    // Draw background track
    canvas.drawCircle(center, radius, backgroundPaint);

    if (percentages.isEmpty || percentages.every((p) => p <= 0)) {
      return;
    }

    double startAngle = -math.pi / 2;
    // Ajout d'un petit espacement entre les segments si on le souhaite, 
    // mais pour le moment on laisse classique.
    
    for (int i = 0; i < percentages.length; i++) {
      final sweepAngle = 2 * math.pi * percentages[i];
      if (sweepAngle > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = colors[i % colors.length];

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        // Add a slight overlap or gap ? Let's just add it sequentially
        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SikaDonutPainter oldDelegate) {
    return oldDelegate.percentages != percentages ||
           oldDelegate.colors != colors ||
           oldDelegate.backgroundColor != backgroundColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}

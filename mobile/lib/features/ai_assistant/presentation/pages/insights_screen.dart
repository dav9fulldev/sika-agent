import 'dart:math' as math;
import 'package:flutter/material.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  String _selectedPeriod = 'Ce mois';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff020614),
      appBar: AppBar(
        backgroundColor: const Color(0xff020614),
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Insights',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1329),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  dropdownColor: const Color(0xFF0B1329),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  items: <String>['Ce mois', 'Mois dernier', '3 mois'].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _selectedPeriod = newValue);
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. LE GRAND BLOC PRINCIPAL DES DÉPENSES TOTALES
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1329),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF635BFF).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFF635BFF), size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Dépenses totales',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: const TextSpan(
                                children: [
                                  TextSpan(
                                    text: '120 000 ',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 30,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(
                                    text: 'FCFA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              '+12% vs mois dernier',
                              style: TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildCategoryRow('Alimentation', '72%', const Color(0xFF38BDF8)),
                            const SizedBox(height: 10),
                            _buildCategoryRow('Transport', '15%', const Color(0xFF10B981)),
                            const SizedBox(height: 10),
                            _buildCategoryRow('Loisirs', '8%', const Color(0xFFF59E0B)),
                            const SizedBox(height: 10),
                            _buildCategoryRow('Autres', '5%', const Color(0xFF635BFF)),
                          ],
                        ),
                      ),

                      Expanded(
                        flex: 4,
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CustomPaint(
                                  painter: _BuildCustomDonut(),
                                ),
                              ),
                              const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '72%',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 2. LE BLOC DE L'OBJECTIF D'ÉPARGNE
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0B1329),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.savings_outlined, color: Color(0xFF10B981), size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Objectif d\'épargne',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      RichText(
                        text: const TextSpan(
                          children: [
                            TextSpan(
                              text: '80 000 ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: 'FCFA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        '60%',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: const SizedBox(
                      height: 10,
                      child: LinearProgressIndicator(
                        value: 0.60,
                        backgroundColor: Color(0xFF1E293B),
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    '48 000 / 80 000 FCFA',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryRow(String name, String percentage, Color dotColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              name,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          percentage,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _BuildCustomDonut extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    const double thickness = 8.0;

    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    paint.color = const Color(0xFF635BFF);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * 0.72,
      false,
      paint,
    );

    paint.color = const Color(0xFF10B981);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (-math.pi / 2) + (2 * math.pi * 0.72),
      2 * math.pi * 0.15,
      false,
      paint,
    );

    paint.color = const Color(0xFF38BDF8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      (-math.pi / 2) + (2 * math.pi * 0.87),
      2 * math.pi * 0.13,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

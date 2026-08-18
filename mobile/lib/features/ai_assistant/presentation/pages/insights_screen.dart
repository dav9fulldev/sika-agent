import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _selectedPeriodKey = 'Ce mois';

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);

    final walletState = ref.watch(walletProvider);
    final movements = walletState.movements;

    // Filter expense movements only (exclude deposits / income)
    final expenseMovements = movements.where((m) {
      final t = m.type.toLowerCase();
      final cat = m.category.toLowerCase();
      return t != 'deposit' && cat != 'dépôt' && cat != 'depot' && (t == 'payment' || t == 'transfer' || t == 'withdrawal' || t == 'expense');
    }).toList();

    final double totalExpenseFcfa = expenseMovements.fold(0.0, (sum, m) => sum + m.amount);

    // Dynamic category breakdown if real movements exist
    Map<String, double> categoryTotals = {};
    if (totalExpenseFcfa > 0) {
      for (var m in expenseMovements) {
        final cat = m.category.isEmpty ? 'Autres' : m.category;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + m.amount;
      }
    }

    final List<Map<String, dynamic>> categoryDisplay = [];
    final List<Color> categoryColors = [
      const Color(0xFF38BDF8), // Food / Blue
      const Color(0xFF10B981), // Transport / Green
      const Color(0xFFF59E0B), // Leisure / Orange
      const Color(0xFF635BFF), // Others / Purple
    ];

    if (totalExpenseFcfa > 0) {
      int colorIdx = 0;
      categoryTotals.forEach((cat, amt) {
        final double pct = amt / totalExpenseFcfa;
        categoryDisplay.add({
          'name': cat,
          'pctValue': pct,
          'pctString': '${(pct * 100).toStringAsFixed(0)}%',
          'color': categoryColors[colorIdx % categoryColors.length],
        });
        colorIdx++;
      });
    }

    final Map<String, String> periodLabels = {
      'Ce mois': langNotifier.tr('Ce mois', 'This month'),
      'Mois dernier': langNotifier.tr('Mois dernier', 'Last month'),
      '3 mois': langNotifier.tr('3 mois', '3 months'),
    };

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
                  value: _selectedPeriodKey,
                  dropdownColor: const Color(0xFF0B1329),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF94A3B8), size: 18),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  items: periodLabels.keys.map((String key) {
                    return DropdownMenuItem<String>(
                      value: key,
                      child: Text(periodLabels[key]!),
                    );
                  }).toList(),
                  onChanged: (newValue) {
                    if (newValue != null) {
                      setState(() => _selectedPeriodKey = newValue);
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
            // 1. DÉPENSES TOTALES DYNAMIQUES
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
                      Text(
                        langNotifier.tr('Dépenses totales', 'Total Expenses'),
                        style: const TextStyle(
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
                            Text(
                              currNotifier.format(totalExpenseFcfa),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              totalExpenseFcfa > 0
                                  ? langNotifier.tr('Basé sur vos transactions récentes', 'Based on recent transactions')
                                  : langNotifier.tr('Aucune dépense enregistrée', 'No expenses recorded'),
                              style: TextStyle(
                                color: totalExpenseFcfa > 0 ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 20),

                            if (categoryDisplay.isNotEmpty) ...[
                              for (var cat in categoryDisplay) ...[
                                _buildCategoryRow(
                                  cat['name'] as String,
                                  cat['pctString'] as String,
                                  cat['color'] as Color,
                                ),
                                const SizedBox(height: 10),
                              ],
                            ] else ...[
                              Text(
                                langNotifier.tr('Aucune catégorie disponible', 'No categories available'),
                                style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
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
                                  painter: _BuildCustomDonut(
                                    percentages: categoryDisplay.map((e) => e['pctValue'] as double).toList(),
                                    colors: categoryDisplay.map((e) => e['color'] as Color).toList(),
                                  ),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    categoryDisplay.isNotEmpty ? categoryDisplay.first['pctString'] as String : '0%',
                                    style: const TextStyle(
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

            // 2. OBJECTIF D'ÉPARGNE DYNAMIQUE (COFFRES D'ÉPARGNE)
            Builder(
              builder: (context) {
                final firstCoffre = walletState.coffres.isNotEmpty ? walletState.coffres.first : null;
                final String coffreNom = firstCoffre?.nom ?? langNotifier.tr("Épargne", "Savings");
                final double targetSavingsGoal = firstCoffre?.objectif ?? 0.0;
                final double currentSaved = firstCoffre?.solde ?? 0.0;
                final double progressRatio = targetSavingsGoal > 0 ? (currentSaved / targetSavingsGoal).clamp(0.0, 1.0) : 0.0;
                final String pctString = (progressRatio * 100).toStringAsFixed(1);

                return Container(
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                              Text(
                                '${langNotifier.tr("Objectif d'épargne", "Savings Goal")} • $coffreNom',
                                style: const TextStyle(
                                  color: Color(0xFF64748B),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              langNotifier.tr('Coffre Actif', 'Active Vault'),
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
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
                          Text(
                            currNotifier.format(targetSavingsGoal),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '$pctString%',
                            style: const TextStyle(
                              color: Color(0xFF10B981),
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 10,
                          child: LinearProgressIndicator(
                            value: progressRatio,
                            backgroundColor: const Color(0xFF1E293B),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Text(
                        '${currNotifier.format(currentSaved)} / ${currNotifier.format(targetSavingsGoal)} ' +
                            langNotifier.tr('épargnés dans ce coffre', 'saved in this vault'),
                        style: const TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              },
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
  final List<double> percentages;
  final List<Color> colors;

  _BuildCustomDonut({
    required this.percentages,
    required this.colors,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    const double thickness = 8.0;

    final Paint backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = const Color(0xFF1E293B);

    canvas.drawCircle(center, radius, backgroundPaint);

    if (percentages.isEmpty || percentages.every((p) => p == 0)) {
      return;
    }

    double startAngle = -math.pi / 2;

    for (int i = 0; i < percentages.length; i++) {
      final sweepAngle = 2 * math.pi * percentages[i];
      if (sweepAngle > 0) {
        final paint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = thickness
          ..strokeCap = StrokeCap.round
          ..color = colors[i % colors.length];

        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          startAngle,
          sweepAngle,
          false,
          paint,
        );
        startAngle += sweepAngle;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BuildCustomDonut oldDelegate) => true;
}

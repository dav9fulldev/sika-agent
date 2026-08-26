import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
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
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(walletProvider.notifier).fetchCoffres();
      ref.read(walletProvider.notifier).fetchMovements();
      ref.read(walletProvider.notifier).fetchWallets();
    });
  }

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
      return t != 'deposit' &&
          cat != 'dépôt' &&
          cat != 'depot' &&
          (t == 'payment' ||
              t == 'transfer' ||
              t == 'withdrawal' ||
              t == 'expense');
    }).toList();

    final double totalExpenseFcfa =
        expenseMovements.fold(0.0, (sum, m) => sum + m.amount);

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
      backgroundColor: Colors.transparent, // Laisse voir le gradient global
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Insights',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0, top: 10, bottom: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriodKey,
                  dropdownColor: Theme.of(context).cardColor,
                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                      size: 18),
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
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
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(walletProvider.notifier).syncAllWallets();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. DÉPENSES TOTALES DYNAMIQUES
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color:
                                const Color(0xFF635BFF).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.show_chart_rounded,
                              color: Color(0xFF635BFF), size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          langNotifier.tr('Dépenses totales', 'Total Expenses'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          flex: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                currNotifier.format(totalExpenseFcfa),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -1,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                totalExpenseFcfa > 0
                                    ? langNotifier.tr('Analyse de ce mois',
                                        'This month analysis')
                                    : langNotifier.tr(
                                        'Aucune dépense', 'No expenses'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: totalExpenseFcfa > 0
                                          ? AppColors.success
                                          : Colors.white.withValues(alpha: 0.4),
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const SizedBox(height: 28),
                              if (categoryDisplay.isNotEmpty) ...[
                                for (var cat in categoryDisplay) ...[
                                  _buildCategoryRow(
                                    cat['name'] as String,
                                    cat['pctString'] as String,
                                    cat['color'] as Color,
                                  ),
                                  const SizedBox(height: 12),
                                ],
                              ] else ...[
                                Text(
                                  langNotifier.tr('Aucune donnée', 'No data'),
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 13),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Lueur derrière le donut
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF635BFF)
                                            .withValues(alpha: 0.2),
                                        blurRadius: 40,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  height: 120,
                                  child: CustomPaint(
                                    painter: _BuildCustomDonut(
                                      percentages: categoryDisplay
                                          .map((e) => e['pctValue'] as double)
                                          .toList(),
                                      colors: categoryDisplay
                                          .map((e) => e['color'] as Color)
                                          .toList(),
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.02),
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      categoryDisplay.isNotEmpty
                                          ? categoryDisplay.first['pctString']
                                              as String
                                          : '0%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
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
              )
                  .animate()
                  .fade(duration: 500.ms, delay: 100.ms)
                  .slideY(begin: 0.05, curve: Curves.easeOutCubic),

              const SizedBox(height: 20),

              // 2. OBJECTIF D'ÉPARGNE DYNAMIQUE (COFFRES D'ÉPARGNE)
              Builder(
                builder: (context) {
                  final firstCoffre = walletState.coffres.isNotEmpty
                      ? walletState.coffres.first
                      : null;
                  final String coffreNom =
                      firstCoffre?.nom ?? langNotifier.tr("Épargne", "Savings");
                  final double targetSavingsGoal = firstCoffre?.objectif ?? 0.0;
                  final double currentSaved = firstCoffre?.solde ?? 0.0;
                  final double progressRatio = targetSavingsGoal > 0
                      ? (currentSaved / targetSavingsGoal).clamp(0.0, 1.0)
                      : 0.0;
                  final String pctString =
                      (progressRatio * 100).toStringAsFixed(1);

                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.savings_rounded,
                                      color: Color(0xFF10B981), size: 18),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  '${langNotifier.tr("Objectif d'épargne", "Savings Goal")} • $coffreNom',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.6),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                langNotifier.tr('Actif', 'Active'),
                                style: const TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              currNotifier.format(targetSavingsGoal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                            ),
                            Text(
                              '$pctString%',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Stack(
                          children: [
                            // Piste de progression
                            Container(
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            // Barre de progression
                            FractionallySizedBox(
                              widthFactor: progressRatio,
                              child: Container(
                                height: 12,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF10B981).withValues(alpha: 0.5),
                                      const Color(0xFF10B981),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981)
                                          .withValues(alpha: 0.4),
                                      blurRadius: 10,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          '${currNotifier.format(currentSaved)} / ${currNotifier.format(targetSavingsGoal)} ${langNotifier.tr('épargnés dans ce coffre', 'saved in this vault')}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                      ],
                    ),
                  )
                      .animate()
                      .fade(duration: 500.ms, delay: 200.ms)
                      .slideY(begin: 0.05, curve: Curves.easeOutCubic);
                },
              ),
            ],
          ),
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
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          percentage,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
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
  final Color backgroundColor;

  _BuildCustomDonut({
    required this.percentages,
    required this.colors,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = size.width / 2;
    const double thickness = 8.0;

    final Paint backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..color = backgroundColor;

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

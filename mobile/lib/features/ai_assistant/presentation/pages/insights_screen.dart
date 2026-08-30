import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../widgets/sika_period_selector.dart';
import '../widgets/sika_trend_indicator.dart';
import '../widgets/sika_donut_chart.dart';
import '../widgets/sika_budget_progress.dart';
import '../widgets/sika_insight_card.dart';
import '../../../../core/widgets/sika_empty_state.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  String _selectedPeriodKey = 'Mois';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter properties
    final now = DateTime.now();
    DateTime currentPeriodStart;
    DateTime previousPeriodStart;
    DateTime previousPeriodEnd;

    switch (_selectedPeriodKey) {
      case 'Semaine':
        currentPeriodStart = now.subtract(const Duration(days: 7));
        previousPeriodEnd = currentPeriodStart.subtract(const Duration(seconds: 1));
        previousPeriodStart = previousPeriodEnd.subtract(const Duration(days: 7));
        break;
      case '3 Mois':
        currentPeriodStart = DateTime(now.year, now.month - 3, now.day);
        previousPeriodEnd = currentPeriodStart.subtract(const Duration(seconds: 1));
        previousPeriodStart = DateTime(previousPeriodEnd.year, previousPeriodEnd.month - 3, previousPeriodEnd.day);
        break;
      case 'Mois':
      default:
        currentPeriodStart = DateTime(now.year, now.month - 1, now.day);
        previousPeriodEnd = currentPeriodStart.subtract(const Duration(seconds: 1));
        previousPeriodStart = DateTime(previousPeriodEnd.year, previousPeriodEnd.month - 1, previousPeriodEnd.day);
        break;
    }

    // Process movements
    final expenseMovements = walletState.movements.where((m) {
      final t = m.type.toLowerCase();
      final cat = m.category.toLowerCase();
      return t != 'deposit' &&
          cat != 'dépôt' &&
          cat != 'depot' &&
          (t == 'payment' || t == 'transfer' || t == 'withdrawal' || t == 'expense');
    }).toList();

    double currentTotal = 0.0;
    double previousTotal = 0.0;
    Map<String, double> categoryTotals = {};

    for (var m in expenseMovements) {
      DateTime mDate;
      try {
        mDate = DateTime.parse(m.timestamp);
      } catch (e) {
        continue;
      }

      if (mDate.isAfter(currentPeriodStart) && mDate.isBefore(now.add(const Duration(days: 1)))) {
        currentTotal += m.amount;
        final cat = m.category.isEmpty ? 'Autres' : m.category;
        categoryTotals[cat] = (categoryTotals[cat] ?? 0.0) + m.amount;
      } else if (mDate.isAfter(previousPeriodStart) && mDate.isBefore(previousPeriodEnd)) {
        previousTotal += m.amount;
      }
    }

    // Chart Data Preparation
    final List<Map<String, dynamic>> categoryDisplay = [];
    final List<Color> categoryColors = [
      AppColors.chartIndigo,
      AppColors.chartCyan,
      AppColors.chartEmerald,
      AppColors.chartAmber,
      AppColors.chartCoral,
      AppColors.chartPurple,
    ];

    if (currentTotal > 0) {
      // Sort categories by amount descending
      var sortedKeys = categoryTotals.keys.toList(growable: false)
        ..sort((k1, k2) => categoryTotals[k2]!.compareTo(categoryTotals[k1]!));
      
      int colorIdx = 0;
      for (var cat in sortedKeys) {
        final double amt = categoryTotals[cat]!;
        final double pct = amt / currentTotal;
        categoryDisplay.add({
          'name': cat,
          'amount': amt,
          'pctValue': pct,
          'pctString': '${(pct * 100).toStringAsFixed(0)}%',
          'color': categoryColors[colorIdx % categoryColors.length],
        });
        colorIdx++;
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // Uses global gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Insights',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
        ),
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
              // Hero Analytics Area (Étape 1 - Où en suis-je ?)
              Center(
                child: SikaPeriodSelector(
                  selectedPeriod: _selectedPeriodKey,
                  periods: const ['Semaine', 'Mois', '3 Mois'],
                  periodLabels: {
                    'Semaine': langNotifier.tr('Semaine', 'Week'),
                    'Mois': langNotifier.tr('Mois', 'Month'),
                    '3 Mois': langNotifier.tr('3 Mois', '3 Months'),
                  },
                  onPeriodChanged: (p) => setState(() => _selectedPeriodKey = p),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      langNotifier.tr('Dépenses totales', 'Total Expenses'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currNotifier.format(currentTotal),
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).colorScheme.onSurface,
                            letterSpacing: -1,
                            fontSize: 42,
                          ),
                    ),
                    const SizedBox(height: 12),
                    SikaTrendIndicator(
                      currentAmount: currentTotal,
                      previousAmount: previousTotal,
                    ),
                  ],
                ),
              ).animate().fade(duration: 500.ms, delay: 100.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),
              
              const SizedBox(height: 32),

              // Spending Breakdown (Étape 2 - Où va mon argent ?)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  ),
                  boxShadow: isDark ? null : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
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
                            color: AppColors.chartIndigo.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.pie_chart_rounded, color: AppColors.chartIndigo, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          langNotifier.tr('Répartition', 'Breakdown'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (currentTotal > 0 && categoryDisplay.isNotEmpty) ...[
                      // Chart
                      Center(
                        child: SikaDonutChart(
                          percentages: categoryDisplay.map((e) => e['pctValue'] as double).toList(),
                          colors: categoryDisplay.map((e) => e['color'] as Color).toList(),
                          size: 160,
                          strokeWidth: 20,
                          centerContent: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                categoryDisplay.first['pctString'] as String,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                categoryDisplay.first['name'] as String,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Legend List
                      ...categoryDisplay.map((cat) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: cat['color'] as Color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    cat['name'] as String,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currNotifier.format(cat['amount'] as double),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    cat['pctString'] as String,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      // Empty state for chart
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 32.0),
                        child: SikaEmptyState(
                          icon: Icons.query_stats_rounded,
                          title: langNotifier.tr('Aucune dépense', 'No expenses'),
                          message: langNotifier.tr('Aucune dépense sur cette période.', 'No expenses for this period.'),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fade(duration: 500.ms, delay: 200.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

              const SizedBox(height: 24),

              // SIKA Insights Area (Étape 4 - Qu'est-ce que SIKA me recommande ?)
              Builder(
                builder: (context) {
                  String insightTitle = langNotifier.tr('Analyse SIKA', 'SIKA Analysis');
                  String insightMessage = langNotifier.tr(
                    'Vos données sont en cours de consolidation. Continuez à utiliser SIKA pour obtenir des recommandations personnalisées.',
                    'Your data is being consolidated. Keep using SIKA to get personalized recommendations.'
                  );
                  IconData insightIcon = Icons.auto_awesome_rounded;

                  if (currentTotal > 0 && categoryDisplay.isNotEmpty) {
                    final topCategory = categoryDisplay.first;
                    final topCatName = topCategory['name'] as String;
                    final topCatPct = topCategory['pctString'] as String;

                    if (previousTotal > 0) {
                      final difference = currentTotal - previousTotal;
                      final double percentage = (difference / previousTotal) * 100;
                      
                      if (percentage > 10) {
                        insightTitle = langNotifier.tr('Attention aux dépenses', 'Watch your spending');
                        insightMessage = langNotifier.tr(
                          'Vos dépenses ont augmenté de ${percentage.abs().toStringAsFixed(1)}%. La catégorie $topCatName représente à elle seule $topCatPct du total. Envisagez de revoir ce budget.',
                          'Your expenses increased by ${percentage.abs().toStringAsFixed(1)}%. $topCatName alone accounts for $topCatPct of the total. Consider reviewing this budget.'
                        );
                        insightIcon = Icons.trending_up_rounded;
                      } else if (percentage < -10) {
                        insightTitle = langNotifier.tr('Excellente gestion !', 'Great management!');
                        insightMessage = langNotifier.tr(
                          'Vos dépenses ont diminué de ${percentage.abs().toStringAsFixed(1)}%. Vous êtes sur la bonne voie. Pensez à placer cet excédent dans un coffre d\'épargne.',
                          'Your expenses decreased by ${percentage.abs().toStringAsFixed(1)}%. You are on the right track. Consider putting this surplus in a savings vault.'
                        );
                        insightIcon = Icons.trending_down_rounded;
                      } else {
                        insightTitle = langNotifier.tr('Dépenses maîtrisées', 'Spending controlled');
                        insightMessage = langNotifier.tr(
                          'Vos dépenses sont stables. Le poste principal reste $topCatName ($topCatPct).',
                          'Your expenses are stable. The main category remains $topCatName ($topCatPct).'
                        );
                      }
                    } else {
                      insightTitle = langNotifier.tr('Tendances de la période', 'Period trends');
                      insightMessage = langNotifier.tr(
                        'Vos dépenses principales sont concentrées sur $topCatName ($topCatPct).',
                        'Your main expenses are concentrated in $topCatName ($topCatPct).'
                      );
                    }
                  } else if (currentTotal == 0 && previousTotal > 0) {
                     insightTitle = langNotifier.tr('Aucune dépense', 'No expenses');
                     insightMessage = langNotifier.tr(
                        'Vous n\'avez encore rien dépensé sur cette période. Continuez comme ça !',
                        'You haven\'t spent anything this period yet. Keep it up!'
                      );
                  }

                  return SikaInsightCard(
                    title: insightTitle,
                    message: insightMessage,
                    icon: insightIcon,
                  );
                },
              ).animate().fade(duration: 500.ms, delay: 300.ms).slideY(begin: 0.05, curve: Curves.easeOutCubic),

              const SizedBox(height: 24),

              // Savings Goals (Étape 3 - Est-ce que je progresse ?)
              if (walletState.coffres.isNotEmpty) ...[
                Text(
                  langNotifier.tr('Objectifs d\'épargne', 'Savings Goals'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
                const SizedBox(height: 16),
                ...walletState.coffres.map((coffre) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceElevated : AppColors.lightSurfaceElevated,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                      ),
                      boxShadow: isDark ? null : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SikaBudgetProgress(
                      title: coffre.nom.isEmpty ? langNotifier.tr('Épargne', 'Savings') : coffre.nom,
                      currentAmount: coffre.solde,
                      targetAmount: coffre.objectif,
                      currentAmountFormatted: currNotifier.format(coffre.solde),
                      targetAmountFormatted: currNotifier.format(coffre.objectif),
                      icon: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.savings_rounded, color: AppColors.success, size: 14),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 100), // Spacing for bottom nav
            ],
          ),
        ),
      ),
    );
  }
}

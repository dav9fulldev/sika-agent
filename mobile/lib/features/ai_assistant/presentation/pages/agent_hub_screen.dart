import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../providers/sika_provider.dart';
import '../widgets/proactive_alert_card.dart';
import '../widgets/proactive_analysis_sheet.dart';
import '../widgets/human_confirmation_card.dart';
import '../widgets/runway_card_widget.dart';
import '../widgets/wallet_rebalance_card.dart';
import '../widgets/savings_booster_card.dart';
import '../../../../core/constants/app_images.dart';
import '../../../wallet/presentation/widgets/connect_wallet_modal.dart';
import '../../../wallet/providers/wallet_provider.dart';
import '../../../../core/widgets/sika_glass_text_field.dart';

class AgentHubScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenChat;
  final VoidCallback onOpenInsights;

  const AgentHubScreen({
    super.key,
    required this.onOpenChat,
    required this.onOpenInsights,
  });

  @override
  ConsumerState<AgentHubScreen> createState() => _AgentHubScreenState();
}

class _AgentHubScreenState extends ConsumerState<AgentHubScreen>
    with TickerProviderStateMixin {
  late AnimationController _orbController;
  late AnimationController _shimmerController;
  final TextEditingController _inputController = TextEditingController();
  bool _showAlert = false;
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..repeat(reverse: true);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _orbController.dispose();
    _shimmerController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  void _submitQuery(String query, SikaNotifier notifier) {
    if (query.trim().isEmpty) return;
    notifier.sendTextMessage(query.trim());
    _inputController.clear();
    widget.onOpenChat();
  }

  void _openAnalysisSheet(SikaNotifier notifier) {
    ProactiveAnalysisSheet.show(
      context,
      onDismiss: () {},
      onViewExpenses: () {
        widget.onOpenInsights();
      },
      onSetLimit: () {
        notifier.sendTextMessage(
            'Définir une limite de budget sur la restauration.');
        widget.onOpenChat();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sikaNotifier = ref.read(sikaProvider.notifier);
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);
    ref.watch(currencyProvider);
    final currNotifier = ref.read(currencyProvider.notifier);
    final walletState = ref.watch(walletProvider);
    final sikaData = ref.watch(sikaProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Fond propre sans gradients lourds pour un style minimaliste.

          // CONTENU PRINCIPAL
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // =========================================================
                // HERO HEADER — SOLDE + STATUT SIKA
                // =========================================================
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),

                        // TOP BAR
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    langNotifier.tr('Bonjour 👋', 'Hello 👋'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                          letterSpacing: 0.3,
                                        ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'SIKA Hub',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                  ),
                                ],
                              ),
                                // Suppression du bouton notifications lourd
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.notifications_outlined,
                                    color: Theme.of(context).colorScheme.onSurface,
                                    size: 20,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── HERO CARD SOLDE ──────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildHeroBalanceCard(
                            context,
                            walletState,
                            currNotifier,
                            langNotifier,
                          ),
                        ).animate().fade(duration: 500.ms).slideY(
                            begin: 0.08, end: 0, curve: Curves.easeOutCubic),

                        const SizedBox(height: 16),

                        // ── QUICK ACTIONS GRID ───────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildQuickActions(
                              context, langNotifier, sikaNotifier),
                        ).animate().fade(delay: 100.ms, duration: 400.ms),

                        const SizedBox(height: 20),

                        // ── SIKA AI STATUS ───────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: _buildSikaStatusCard(
                              context, langNotifier, sikaNotifier, sikaData),
                        ).animate().fade(delay: 150.ms).slideY(
                            begin: 0.08, end: 0, curve: Curves.easeOutCubic),

                        const SizedBox(height: 16),

                        // ── RUNWAY (INDICE AUTONOMIE) ────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: RunwayCardWidget(
                            totalBalanceFcfa: walletState.totalBalanceFcfa,
                            dailyBurnRateFcfa: walletState.movements.isEmpty
                                ? 0.0
                                : (walletState.movements.fold<double>(
                                        0.0, (sum, m) => sum + m.amount) /
                                    30.0),
                          ),
                        ).animate().fade(delay: 200.ms).slideY(
                            begin: 0.08, end: 0, curve: Curves.easeOutCubic),

                        const SizedBox(height: 16),

                        // ── WALLET REBALANCE (si >= 2 comptes) ───────────
                        if (walletState.wallets.length >= 2) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: WalletRebalanceCard(
                              onRebalanceConfirmed: () => widget.onOpenChat(),
                            ),
                          ).animate().fade(delay: 250.ms).slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 16),
                        ],

                        // ── SAVINGS BOOSTER (si >= 1 compte) ─────────────
                        if (walletState.wallets.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: SavingsBoosterCard(
                              onBoostConfirmed: () => widget.onOpenChat(),
                            ),
                          ).animate().fade(delay: 300.ms).slideY(
                              begin: 0.08, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 16),
                        ],

                        // ── ALERT ────────────────────────────────────────
                        if (_showAlert)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: ProactiveAlertCard(
                              amountText: currNotifier.format(30000),
                              message: langNotifier.tr(
                                'Dépense de ${currNotifier.format(30000)} détectée. Cela consomme 2/3 de votre budget restant.',
                                'A ${currNotifier.format(30000)} expense detected. This uses 2/3 of your remaining budget.',
                              ),
                              onExamine: () => _openAnalysisSheet(sikaNotifier),
                              onDismiss: () =>
                                  setState(() => _showAlert = false),
                            ),
                          ).animate().fade().scale(),

                        // ── HUMAN CONFIRMATION ───────────────────────────
                        if (sikaData.pendingActionId != null &&
                            sikaData.state == SikaState.securityValidation) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Builder(builder: (context) {
                              final actionData =
                                  sikaData.pendingActionData ?? {};
                              final recipient =
                                  actionData['recipient']?.toString() ??
                                      actionData['destinataire']?.toString() ??
                                      'Destinataire';
                              final amountVal = (actionData['amount'] is num)
                                  ? (actionData['amount'] as num).toDouble()
                                  : 0.0;
                              return HumanConfirmationCard(
                                actionId: sikaData.pendingActionId,
                                actionTitle: langNotifier.tr(
                                    'Validation requise',
                                    'Confirmation Required'),
                                recipientText: recipient,
                                amountText: amountVal > 0
                                    ? currNotifier.format(amountVal)
                                    : '---',
                                sourceAccount: actionData['source_wallet']?.toString() ?? 'Portefeuille Principal',
                                feeText: actionData['fee'] != null ? '${actionData['fee']} FCFA' : '0 FCFA',
                                platformText: actionData['platform']?.toString() ?? 'PayMeChap / Direct',
                                onConfirm: () => sikaNotifier
                                    .executeSecurityValidationAndConfirm(
                                        sikaData.pendingActionId!),
                                onCancel: () =>
                                    sikaNotifier.cancelPendingAction(),
                              );
                            }),
                          ).animate().fade().scale(),
                          const SizedBox(height: 16),
                        ],

                        // ── SUGGESTIONS SECTION ──────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.brandPrimary,
                                          AppColors.brandSecondary
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    langNotifier.tr(
                                        'Demandez à SIKA', 'Ask SIKA'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.2,
                                        ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildSuggestionChip(
                                context,
                                icon: Icons.account_balance_wallet_rounded,
                                text: langNotifier.tr(
                                    'Quel est mon solde total ?',
                                    'What is my total balance?'),
                                color: AppColors.brandPrimary,
                                onTap: () => _submitQuery(
                                    langNotifier.tr(
                                        'Quel est mon solde total ?',
                                        'What is my total balance?'),
                                    sikaNotifier),
                                delay: 400,
                              ),
                              const SizedBox(height: 10),
                              _buildSuggestionChip(
                                context,
                                icon: Icons.savings_rounded,
                                text: langNotifier.tr(
                                    'État de mon objectif d\'épargne ?',
                                    'My savings goal status?'),
                                color: AppColors.success,
                                onTap: () => _submitQuery(
                                    langNotifier.tr(
                                        'Comment progresse mon objectif d\'épargne ?',
                                        'How is my savings goal progressing?'),
                                    sikaNotifier),
                                delay: 450,
                              ),
                              const SizedBox(height: 10),
                              _buildSuggestionChip(
                                context,
                                icon: Icons.bar_chart_rounded,
                                text: langNotifier.tr(
                                    'Analyser mes dépenses récentes',
                                    'Analyze my recent expenses'),
                                color: AppColors.brandSecondary,
                                onTap: () => _submitQuery(
                                    langNotifier.tr(
                                        'Analyser mes dépenses récentes',
                                        'Analyze my recent expenses'),
                                    sikaNotifier),
                                delay: 500,
                              ),
                              const SizedBox(height: 10),
                              _buildSuggestionChip(
                                context,
                                icon: Icons.bolt_rounded,
                                text: langNotifier.tr(
                                    'Puis-je dépenser 15 000 FCFA ?',
                                    'Can I spend 15,000 FCFA today?'),
                                color: AppColors.warning,
                                onTap: () => _submitQuery(
                                    langNotifier.tr(
                                        'Est-ce que je peux dépenser 15000 FCFA aujourd\'hui ?',
                                        'Can I spend 15000 FCFA today?'),
                                    sikaNotifier),
                                delay: 550,
                              ),
                            ],
                          ),
                        ),

                        // Espace pour la barre d'input
                        const SizedBox(height: 140),
                      ],
                    ),
                  ),
                ),

                // =========================================================
                // INPUT BAR ÉPURÉE — GLASSMORPHISME
                // =========================================================
                _buildInputBar(context, sikaNotifier, langNotifier),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroBalanceCard(
    BuildContext context,
    dynamic walletState,
    dynamic currNotifier,
    dynamic langNotifier,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                langNotifier.tr('Solde total consolidé', 'Total Consolidated Balance'),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                  textBaseline: TextBaseline.alphabetic,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            currNotifier.format(walletState.totalBalanceFcfa),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 44,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.0,
              height: 1.1,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      walletState.wallets.isEmpty
                          ? langNotifier.tr('Aucun wallet', 'No wallet')
                          : langNotifier.tr(
                              '${walletState.wallets.length} wallet(s)',
                              '${walletState.wallets.length} wallet(s)',
                            ),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => ConnectWalletModal.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.add_rounded,
                        color: AppColors.brandPrimary,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        langNotifier.tr('Ajouter', 'Add'),
                        style: const TextStyle(
                          color: AppColors.brandPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, dynamic langNotifier, SikaNotifier notifier) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget buildBentoAction(IconData icon, String label, Color color, VoidCallback onTap, int delayMs) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 90,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ).animate().fade(delay: delayMs.ms).scaleXY(begin: 0.95, end: 1.0, curve: Curves.easeOut),
        ),
      );
    }

    return Row(
      children: [
        buildBentoAction(Icons.donut_small_rounded, langNotifier.tr('Analyser', 'Analyze'), AppColors.brandSecondary, widget.onOpenInsights, 200),
        const SizedBox(width: 12),
        buildBentoAction(Icons.history_rounded, langNotifier.tr('Activité', 'Activity'), Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), () {}, 250),
      ],
    );
  }

  Widget _buildSikaStatusCard(BuildContext context, dynamic langNotifier,
      SikaNotifier sikaNotifier, SikaData sikaData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          // SIKA AI ICON
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brandPrimary.withValues(alpha: 0.1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                AppImages.bienv,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      langNotifier.tr('SIKA AI', 'SIKA AI'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: AppColors.brandPrimary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  langNotifier.tr(
                    'Analyse en temps réel de votre portefeuille.',
                    'Real-time portfolio analysis active.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: widget.onOpenChat,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.arrow_forward_rounded,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(
    BuildContext context, {
    required IconData icon,
    required String text,
    required Color color,
    required VoidCallback onTap,
    required int delay,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.9),
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              size: 20,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fade(delay: delay.ms)
        .slideX(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  Widget _buildInputBar(
      BuildContext context, SikaNotifier notifier, dynamic langNotifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SikaGlassTextField(
        controller: _inputController,
        focusNode: _inputFocus,
        hintText: langNotifier.tr('Posez une question...', 'Ask a question...'),
        prefixIcon: Icons.auto_awesome_rounded,
        onSubmitted: (val) => _submitQuery(val, notifier),
        suffixIcon: GestureDetector(
          onTap: () => _submitQuery(_inputController.text, notifier),
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.brandPrimary, Color(0xFF635BFF)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.brandPrimary.withValues(alpha: 0.4),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Icon(Icons.arrow_upward_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }
}

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
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
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
  late Animation<double> _orbFloat;
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
    _orbFloat = Tween<double>(begin: -5.0, end: 5.0).animate(
      CurvedAnimation(parent: _orbController, curve: Curves.easeInOut),
    );
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

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: Stack(
        children: [
          // FOND GRADIENT MESH PREMIUM
          Positioned(
            top: -60,
            right: -80,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.18),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandSecondary.withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

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
                                          color: AppColors.darkTextSecondary,
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
                              // Bouton notifications
                              Container(
                                width: 42,
                                height: 42,
                                decoration: BoxDecoration(
                                  color: AppColors.darkSurfaceHighlight,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.darkTextSecondary,
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
                                actionTitle: langNotifier.tr(
                                    'Validation requise',
                                    'Confirmation Required'),
                                recipientText: recipient,
                                amountText: amountVal > 0
                                    ? currNotifier.format(amountVal)
                                    : '---',
                                onConfirm: () => sikaNotifier
                                    .executeSecurityValidationAndConfirm(
                                        sikaData.pendingActionId!),
                                onCancel: () =>
                                    sikaNotifier.clearConversation(),
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.darkSurfaceHighlight.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.success.withValues(alpha: 0.5),
                          blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  langNotifier.tr('Solde consolidé', 'Consolidated Balance'),
                  style: const TextStyle(
                    color: AppColors.darkTextSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Massive Balance Text
          Text(
            currNotifier.format(walletState.totalBalanceFcfa),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 48, // Much larger!
              fontWeight: FontWeight.w800,
              letterSpacing: -1.5,
              height: 1.1,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            walletState.wallets.isEmpty
                ? langNotifier.tr('Aucun portefeuille', 'No wallets')
                : langNotifier.tr(
                    '${walletState.wallets.length} portefeuille(s)',
                    '${walletState.wallets.length} wallet(s)',
                  ),
            style: const TextStyle(
              color: AppColors.brandPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 32),
          // Connection CTA
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: SikaPremiumButton(
              onPressed: () => ConnectWalletModal.show(context),
              text: langNotifier.tr('Ajouter un compte', 'Add Account'),
              prefixWidget: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(
      BuildContext context, dynamic langNotifier, SikaNotifier notifier) {
    final actions = [
      (
        Icons.send_rounded,
        langNotifier.tr('Envoyer', 'Send'),
        AppColors.brandPrimary
      ),
      (
        Icons.download_rounded,
        langNotifier.tr('Recevoir', 'Receive'),
        AppColors.success
      ),
      (
        Icons.bar_chart_rounded,
        langNotifier.tr('Analyser', 'Analyze'),
        AppColors.brandSecondary
      ),
      (
        Icons.settings_rounded,
        langNotifier.tr('Réglages', 'Settings'),
        AppColors.darkTextMuted
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          const SizedBox(width: 20),
          ...actions.asMap().entries.map((entry) {
            final i = entry.key;
            final action = entry.value;
            return Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () {
                  if (i == 2) widget.onOpenInsights();
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.darkSurface.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.brandPrimary.withValues(alpha: 0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: (action.$3).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(action.$1,
                            color: action.$3, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        action.$2 as String,
                        style: const TextStyle(
                          color: AppColors.darkTextPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: (i * 80).ms).slideX(begin: 0.1, end: 0),
              ),
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSikaStatusCard(BuildContext context, dynamic langNotifier,
      SikaNotifier sikaNotifier, SikaData sikaData) {
    return SikaGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(28),
      blur: 24.0,
      opacity: 0.2,
      child: Stack(
        children: [
          // Background Glow
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.3),
                      blurRadius: 40),
                ],
              ),
            ),
          ),
          Row(
            children: [
              // SIKA AI ORB
              AnimatedBuilder(
                animation: _orbFloat,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, _orbFloat.value),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.asset(
                          AppImages.bienv,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  );
                },
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
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color:
                                AppColors.brandPrimary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.brandPrimary
                                    .withValues(alpha: 0.5)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: AppColors.brandPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  color: AppColors.brandPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.5),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white.withValues(alpha: 0.15)),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.darkSurface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.9),
                      letterSpacing: 0.2,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white.withValues(alpha: 0.4),
                size: 14,
              ),
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

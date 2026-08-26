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
    with SingleTickerProviderStateMixin {
  late AnimationController _robotAnimationController;
  late Animation<double> _robotFloatAnimation;
  final TextEditingController _inputController = TextEditingController();

  bool _showAlert = false;

  @override
  void initState() {
    super.initState();
    _robotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _robotFloatAnimation =
        Tween<double>(begin: -6.0, end: 6.0).animate(CurvedAnimation(
          parent: _robotAnimationController,
          curve: Curves.easeInOut,
        ));
  }

  @override
  void dispose() {
    _robotAnimationController.dispose();
    _inputController.dispose();
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
        notifier.sendTextMessage('Définir une limite de budget sur la restauration.');
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
      appBar: AppBar(
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIKA Hub',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Autonomous Financial Agent',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 15),

                    // 1. BLOC SOLDE TOTAL
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              langNotifier.tr('Solde total', 'Total Balance'),
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              currNotifier.format(walletState.totalBalanceFcfa),
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              walletState.wallets.isEmpty
                                  ? langNotifier.tr('Aucun portefeuille connecté', 'No wallets connected')
                                  : langNotifier.tr('sur ${walletState.wallets.length} portefeuille(s)', 'across ${walletState.wallets.length} wallet(s)'),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ConnectWalletModal.show(context);
                                },
                                icon: const Icon(Icons.add_circle_outline, size: 20),
                                label: Text(langNotifier.tr('Connecter mes comptes', 'Connect my Wallets')),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brandSecondary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(duration: 400.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 16),

                    // 2. MODULE CŒUR 1: INDICE D'AUTONOMIE FINANCIÈRE (RUNWAY) DYNAMIQUE
                    RunwayCardWidget(
                      totalBalanceFcfa: walletState.totalBalanceFcfa,
                      dailyBurnRateFcfa: walletState.movements.isEmpty 
                          ? 0.0 
                          : (walletState.movements.fold<double>(0.0, (sum, m) => sum + m.amount) / 30.0),
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 16),

                    // 3. BLOC ÉTAT DE SIKA (ROBOT EN LÉVITATION)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    langNotifier.tr('État de Sika', 'Sika Status'),
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    langNotifier.tr('Actif et à l\'écoute', 'Active & Listening'),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    langNotifier.tr('Je veille sur vos finances', 'Watching over your finances'),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            AnimatedBuilder(
                              animation: _robotAnimationController,
                              builder: (context, child) {
                                return Transform.translate(
                                  offset: Offset(0, _robotFloatAnimation.value),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.asset(
                                      AppImages.bienv,
                                      width: 82,
                                      height: 82,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 16),

                    // 4. MODULE CŒUR 2: ÉQUILIBRAGE MULTI-PORTEFEUILLES (Si au moins 2 comptes connectes)
                    if (walletState.wallets.length >= 2) ...[
                      WalletRebalanceCard(
                        onRebalanceConfirmed: () => widget.onOpenChat(),
                      ).animate().fade(delay: 300.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 16),
                    ],

                    // 5. MODULE CŒUR 3: BOOSTER D'ÉPARGNE AUTONOME (Si au moins 1 compte connecte)
                    if (walletState.wallets.isNotEmpty) ...[
                      SavingsBoosterCard(
                        onBoostConfirmed: () => widget.onOpenChat(),
                      ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
                      const SizedBox(height: 16),
                    ],

                    // PROACTIVE ALERT BANNER (Si active)
                    if (_showAlert)
                      ProactiveAlertCard(
                        amountText: currNotifier.format(30000),
                        message: langNotifier.tr(
                          'Une dépense de ${currNotifier.format(30000)} vient d\'être détectée. Selon vos dépenses récentes et votre objectif d\'épargne, cette dépense consomme deux tiers de votre budget restant.',
                          'A ${currNotifier.format(30000)} expense was just detected. Based on your recent spending and savings target, this single expense consumes about two-thirds of your remaining budget.',
                        ),
                        onExamine: () => _openAnalysisSheet(sikaNotifier),
                        onDismiss: () {
                          setState(() => _showAlert = false);
                        },
                      ).animate().fade().scale(),

                    // HUMAN CONFIRMATION BANNER (Pilote par l'action reelle de SIKA)
                    if (sikaData.pendingActionId != null && sikaData.state == SikaState.securityValidation) ...[
                      Builder(builder: (context) {
                        final actionData = sikaData.pendingActionData ?? {};
                        final recipient = actionData['recipient']?.toString() ??
                            actionData['destinataire']?.toString() ??
                            actionData['account_number']?.toString() ??
                            'Destinataire';
                        final amountVal = (actionData['amount'] is num)
                            ? (actionData['amount'] as num).toDouble()
                            : (actionData['montant'] is num ? (actionData['montant'] as num).toDouble() : 0.0);
                        final amountDisplay = amountVal > 0 ? currNotifier.format(amountVal) : '---';

                        return HumanConfirmationCard(
                          actionTitle: langNotifier.tr('Validation requise pour le transfert', 'Transfer Confirmation Required'),
                          recipientText: recipient,
                          amountText: amountDisplay,
                          onConfirm: () {
                            sikaNotifier.executeSecurityValidationAndConfirm(sikaData.pendingActionId!);
                          },
                          onCancel: () {
                            sikaNotifier.clearConversation();
                          },
                        );
                      }).animate().fade().scale(),
                      const SizedBox(height: 16),
                    ],

                    // TEXTE SECTION SUGGESTIONS
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Text(
                        langNotifier.tr('Suggestions pour vous', 'Suggestions for you'),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ).animate().fade(delay: 500.ms),

                    _buildSuggestionPill(
                      iconData: Icons.account_balance_wallet_outlined,
                      text: langNotifier.tr('Combien d\'argent ai-je au total ?', 'How much money do I have in total?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Combien d\'argent ai-je au total ?', 'How much money do I have in total?'),
                        sikaNotifier,
                      ),
                      delayMs: 600,
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.track_changes_rounded,
                      text: langNotifier.tr('Comment progresse mon objectif d\'épargne ?', 'How is my savings goal progressing?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Comment progresse mon objectif d\'épargne ?', 'How is my savings goal progressing?'),
                        sikaNotifier,
                      ),
                      delayMs: 650,
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.bar_chart_rounded,
                      text: langNotifier.tr('Quel est mon solde Mobile Money total ?', 'What is my total Mobile Money balance?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Quel est mon solde Mobile Money total ?', 'What is my total Mobile Money balance?'),
                        sikaNotifier,
                      ),
                      delayMs: 700,
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.bolt_rounded,
                      text: langNotifier.tr('Analyser mes dépenses récentes', 'Analyze my recent expenses'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Analyser mes dépenses récentes', 'Analyze my recent expenses'),
                        sikaNotifier,
                      ),
                      delayMs: 750,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // FLOATING INPUT BAR ÉPURÉE
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: langNotifier.tr('Demander à SIKA...', 'Ask SIKA...'),
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 15),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          fillColor: Colors.transparent,
                        ),
                        onSubmitted: (val) => _submitQuery(val, sikaNotifier),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () => _submitQuery(_inputController.text, sikaNotifier),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
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

  Widget _buildSuggestionPill({
    required IconData iconData,
    required String text,
    required VoidCallback onTap,
    required int delayMs,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Icon(iconData, color: AppColors.brandSecondary, size: 20),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(delay: delayMs.ms).slideX(begin: 0.1, end: 0);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIKA Hub',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Autonomous Financial Agent',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                fontSize: 12,
                fontWeight: FontWeight.w400,
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

                    // 1. BLOC SOLDE TOTAL AVEC LOGOS OFFICIELS WAVE, ORANGE MONEY & MTN MOMO
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            langNotifier.tr('Solde total', 'Total Balance'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currNotifier.format(walletState.totalBalanceFcfa),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            walletState.wallets.isEmpty
                                ? langNotifier.tr('Aucun portefeuille connecté', 'No wallets connected')
                                : langNotifier.tr('sur ${walletState.wallets.length} portefeuille(s)', 'across ${walletState.wallets.length} wallet(s)'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                ConnectWalletModal.show(context);
                              },
                              icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.onSurface, size: 20),
                              label: Text(
                                langNotifier.tr('Connecter mes comptes', 'Connect my Wallets'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF00B4D8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. MODULE CŒUR 1: INDICE D'AUTONOMIE FINANCIÈRE (RUNWAY) DYNAMIQUE
                    RunwayCardWidget(
                      totalBalanceFcfa: walletState.totalBalanceFcfa,
                      dailyBurnRateFcfa: walletState.movements.isEmpty 
                          ? 0.0 
                          : (walletState.movements.fold<double>(0.0, (sum, m) => sum + m.amount) / 30.0),
                    ),
                    const SizedBox(height: 16),

                    // 3. BLOC ÉTAT DE SIKA (ROBOT EN LÉVITATION)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  langNotifier.tr('État de Sika', 'Sika Status'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  langNotifier.tr('Actif et à l\'écoute', 'Active & Listening'),
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  langNotifier.tr('Je veille sur vos finances', 'Watching over your finances'),
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                    fontSize: 13,
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
                    const SizedBox(height: 16),

                    // 4. MODULE CŒUR 2: ÉQUILIBRAGE MULTI-PORTEFEUILLES (Si au moins 2 comptes connectes)
                    if (walletState.wallets.length >= 2) ...[
                      WalletRebalanceCard(
                        onRebalanceConfirmed: () => widget.onOpenChat(),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 5. MODULE CŒUR 3: BOOSTER D'ÉPARGNE AUTONOME (Si au moins 1 compte connecte)
                    if (walletState.wallets.isNotEmpty) ...[
                      SavingsBoosterCard(
                        onBoostConfirmed: () => widget.onOpenChat(),
                      ),
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
                      ),

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
                      }),
                      const SizedBox(height: 16),
                    ],

                    // TEXTE SECTION SUGGESTIONS
                    Text(
                      langNotifier.tr('Suggestions pour vous', 'Suggestions for you'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildSuggestionPill(
                      iconData: Icons.account_balance_wallet_outlined,
                      text: langNotifier.tr('Combien d\'argent ai-je au total ?', 'How much money do I have in total?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Combien d\'argent ai-je au total ?', 'How much money do I have in total?'),
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.track_changes_rounded,
                      text: langNotifier.tr('Comment progresse mon objectif d\'épargne ?', 'How is my savings goal progressing?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Comment progresse mon objectif d\'épargne ?', 'How is my savings goal progressing?'),
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.bar_chart_rounded,
                      text: langNotifier.tr('Quel est mon solde Mobile Money total ?', 'What is my total Mobile Money balance?'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Quel est mon solde Mobile Money total ?', 'What is my total Mobile Money balance?'),
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      iconData: Icons.bolt_rounded,
                      text: langNotifier.tr('Analyser mes dépenses récentes', 'Analyze my recent expenses'),
                      onTap: () => _submitQuery(
                        langNotifier.tr('Analyser mes dépenses récentes', 'Analyze my recent expenses'),
                        sikaNotifier,
                      ),
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
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.04)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: langNotifier.tr('Poser une question à SIKA...', 'Ask SIKA anything...'),
                          hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) => _submitQuery(val, sikaNotifier),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _submitQuery(_inputController.text, sikaNotifier),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF3B82F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.arrow_upward_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 22,
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
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.03)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(iconData, color: const Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

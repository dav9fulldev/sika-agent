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

  bool _showAlert = true;
  bool _showConfirmation = false;

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

    return Scaffold(
      backgroundColor: const Color(0xff020614),
      appBar: AppBar(
        backgroundColor: const Color(0xff020614),
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SIKA Hub',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Autonomous Financial Agent',
              style: TextStyle(
                color: Color(0xFF64748B),
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

                    // 1. BLOC SOLDE TOTAL (SANS EMOJIS - AVEC ICÔNES FLUTTER PROPREMENT DÉSIGNÉES)
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
                          Text(
                            langNotifier.tr('Solde total', 'Total Balance'),
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currNotifier.format(45000),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            langNotifier.tr('sur 3 portefeuilles', 'across 3 wallets'),
                            style: const TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildWalletCard('Wave', currNotifier.format(15000), Colors.blue, Icons.water_drop_rounded),
                              const SizedBox(width: 8),
                              _buildWalletCard('Orange Money', currNotifier.format(22000), Colors.orange, Icons.phone_android_rounded),
                              const SizedBox(width: 8),
                              _buildWalletCard('MTN MoMo', currNotifier.format(8000), Colors.amber, Icons.account_balance_wallet_rounded),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 2. MODULE CŒUR 1: INDICE D'AUTONOMIE FINANCIÈRE (RUNWAY)
                    const RunwayCardWidget(
                      totalBalanceFcfa: 45000.0,
                      dailyBurnRateFcfa: 2500.0,
                    ),
                    const SizedBox(height: 16),

                    // 3. BLOC ÉTAT DE SIKA (ROBOT EN LÉVITATION)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1329),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  langNotifier.tr('Actif et à l\'écoute', 'Active & Listening'),
                                  style: const TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  langNotifier.tr('Je veille sur vos finances', 'Watching over your finances'),
                                  style: const TextStyle(
                                    color: Color(0xFF475569),
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

                    // 4. MODULE CŒUR 2: ÉQUILIBRAGE MULTI-PORTEFEUILLES (AUTO-BALANCER)
                    WalletRebalanceCard(
                      onRebalanceConfirmed: () => widget.onOpenChat(),
                    ),
                    const SizedBox(height: 16),

                    // 5. MODULE CŒUR 3: BOOSTER D'ÉPARGNE AUTONOME
                    SavingsBoosterCard(
                      onBoostConfirmed: () => widget.onOpenChat(),
                    ),
                    const SizedBox(height: 16),

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

                    // HUMAN CONFIRMATION BANNER (Si active)
                    if (_showConfirmation)
                      HumanConfirmationCard(
                        actionTitle: langNotifier.tr('Préparation du transfert', 'Transfer Preparation'),
                        recipientText: 'Kouamé (Wave)',
                        amountText: currNotifier.format(10000),
                        onConfirm: () {
                          sikaNotifier.sendTextMessage(langNotifier.tr('Je confirme le transfert de ${currNotifier.format(10000)}.', 'I confirm the transfer of ${currNotifier.format(10000)}.'));
                          setState(() => _showConfirmation = false);
                        },
                        onCancel: () {
                          setState(() => _showConfirmation = false);
                        },
                      ),

                    const SizedBox(height: 16),

                    // TEXTE SECTION SUGGESTIONS
                    Text(
                      langNotifier.tr('Suggestions pour vous', 'Suggestions for you'),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
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
                color: const Color(0xFF0B1329),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
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
                        color: const Color(0xff020614),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: langNotifier.tr('Poser une question à SIKA...', 'Ask SIKA anything...'),
                          hintStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14),
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
                      child: const Icon(
                        Icons.arrow_upward_rounded,
                        color: Colors.white,
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

  Widget _buildWalletCard(String name, String amount, Color brandColor, IconData iconData) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xff020614).withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: brandColor.withValues(alpha: 0.12), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(iconData, color: brandColor, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
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
        color: const Color(0xFF0B1329),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
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
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Color(0xFF475569),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

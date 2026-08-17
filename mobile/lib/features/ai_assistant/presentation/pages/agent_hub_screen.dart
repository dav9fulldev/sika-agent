import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sika_provider.dart';
import '../widgets/proactive_alert_card.dart';
import '../widgets/proactive_analysis_sheet.dart';
import '../widgets/human_confirmation_card.dart';
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

                    // 1. BLOC SOLDE TOTAL
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
                          const Text(
                            'Solde total',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 6),
                          RichText(
                            text: const TextSpan(
                              children: [
                                TextSpan(
                                  text: '45 000 ',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text: 'FCFA',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'sur 3 portefeuilles',
                            style: TextStyle(
                              color: Color(0xFF475569),
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              _buildWalletCard('Wave', '15 000 FCFA', Colors.blue, '🌊'),
                              const SizedBox(width: 8),
                              _buildWalletCard('Orange Money', '22 000 FCFA', Colors.orange, '🍊'),
                              const SizedBox(width: 8),
                              _buildWalletCard('MTN MoMo', '8 000 FCFA', Colors.amber, '🟡'),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // 2. BLOC ÉTAT DE SIKA (AVEC EFFET DE MOUVEMENT CONTINU)
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
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'État de Sika',
                                  style: TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Actif et à l\'écoute',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Je veille sur vos finances',
                                  style: TextStyle(
                                    color: Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // LE ROBOT ANIMÉ EN LÉVITATION
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
                    const SizedBox(height: 24),
                    // PROACTIVE ALERT BANNER (Si active)
                    if (_showAlert)
                      ProactiveAlertCard(
                        message:
                        'A 30,000 FCFA expense was just detected. Based on your recent spending and savings target, this single expense consumes about two-thirds of your remaining budget.',
                        onExamine: () => _openAnalysisSheet(sikaNotifier),
                        onDismiss: () {
                          setState(() => _showAlert = false);
                        },
                      ),

                    // HUMAN CONFIRMATION BANNER (Si active)
                    if (_showConfirmation)
                      HumanConfirmationCard(
                        actionTitle: 'Transfer Preparation',
                        recipientText: 'Kouamé (Wave)',
                        amountText: '10 000 FCFA',
                        onConfirm: () {
                          sikaNotifier.sendTextMessage('I confirm the transfer of 10,000 FCFA.');
                          setState(() => _showConfirmation = false);
                        },
                        onCancel: () {
                          setState(() => _showConfirmation = false);
                        },
                      ),

                    const SizedBox(height: 16),

                    // TEXTE SECTION SUGGESTIONS
                    const Text(
                      'Suggestions pour vous',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),

                    const SizedBox(height: 12),

                    _buildSuggestionPill(
                      icon: '💰',
                      text: 'How much money do I have in total?',
                      onTap: () => _submitQuery(
                        'How much money do I have in total?',
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      icon: '🎯',
                      text: 'How is my savings goal progressing?',
                      onTap: () => _submitQuery(
                        'How is my savings goal progressing?',
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      icon: '📊',
                      text: 'What is my total Mobile Money balance?',
                      onTap: () => _submitQuery(
                        'What is my total Mobile Money balance?',
                        sikaNotifier,
                      ),
                    ),

                    _buildSuggestionPill(
                      icon: '⚡',
                      text: 'Analyze my recent expenses',
                      onTap: () => _submitQuery(
                        'Analyze my recent expenses',
                        sikaNotifier,
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // FLOATING INPUT BAR ÉPURÉE (Uniquement le champ et le bouton d'envoi fléché)
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
                        decoration: const InputDecoration(
                          hintText: 'Ask SIKA anything...',
                          hintStyle: TextStyle(color: Color(0xFF475569), fontSize: 14),
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

  // COMPOSANT D'AIDE : LES CARTES DE COMPTES PORTEFEUILLES
  Widget _buildWalletCard(String name, String amount, Color brandColor, String emoji) {
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
                Text(emoji, style: const TextStyle(fontSize: 12)),
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
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // COMPOSANT D'AIDE : LES PILLULES DE SUGGESTION
  Widget _buildSuggestionPill({
    required String icon,
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
              Text(icon, style: const TextStyle(fontSize: 18)),
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

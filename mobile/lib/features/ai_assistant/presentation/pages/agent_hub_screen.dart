import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sika_provider.dart';
import '../widgets/agent_orb_widget.dart';
import '../widgets/proactive_alert_card.dart';
import '../widgets/proactive_analysis_sheet.dart';
import '../widgets/human_confirmation_card.dart';

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

class _AgentHubScreenState extends ConsumerState<AgentHubScreen> {
  final TextEditingController _inputController = TextEditingController();
  bool _showAlert = true;
  bool _showConfirmation = false;

  @override
  void dispose() {
    _inputController.dispose();
    super.dispose();
  }

  void _submitQuery(String query, SikaNotifier notifier) {
    if (query.trim().isEmpty) return;
    notifier.sendTextMessage(query);
    _inputController.clear();
    widget.onOpenChat();
  }

  void _openAnalysisSheet(SikaNotifier notifier) {
    ProactiveAnalysisSheet.show(
      context,
      onDismiss: () {
        setState(() => _showAlert = false);
      },
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
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour David 👋',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Your Personal AI Financial Agent',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_outlined, color: Colors.white70),
            onPressed: widget.onOpenInsights,
            tooltip: 'Insights',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // MAIN TITLE
                    const Text(
                      'How can I help you?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // SOLDE TOTAL MULTI-WALLET CARD (Screen 3 from Design Specs)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF334155)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Solde total',
                                style: TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  '3 portefeuilles',
                                  style: TextStyle(
                                    color: Color(0xFF10B981),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '45 000 FCFA',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              _buildWalletChip('Wave', '15 000 FCFA', const Color(0xFF38BDF8)),
                              const SizedBox(width: 6),
                              _buildWalletChip('Orange Money', '22 000 FCFA', const Color(0xFFF59E0B)),
                              const SizedBox(width: 6),
                              _buildWalletChip('MTN MoMo', '8 000 FCFA', const Color(0xFFEAB308)),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // QUICK ACTIONS ROW (Screen 3 from Design Specs)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildQuickActionButton(Icons.send, 'Envoyer', () {
                          _submitQuery('Préparer un transfert', sikaNotifier);
                        }),
                        _buildQuickActionButton(Icons.account_balance_wallet, 'Retirer', () {
                          _submitQuery('Combien ai-je au total ?', sikaNotifier);
                        }),
                        _buildQuickActionButton(Icons.receipt_long, 'Payer', () {
                          _submitQuery('Voir mes factures à payer', sikaNotifier);
                        }),
                        _buildQuickActionButton(Icons.qr_code_scanner, 'Scanner', () {}),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // AGENT ORB HERO
                    AgentOrbWidget(
                      state: sikaData.state,
                      onTap: () => sikaNotifier.toggleListening(),
                    ),

                    const SizedBox(height: 24),

                    // PROACTIVE ALERT BANNER (If Active)
                    if (_showAlert)
                      ProactiveAlertCard(
                        message:
                            'A 30,000 FCFA expense was just detected. Based on your recent spending and savings target, this single expense consumes about two-thirds of your remaining budget.',
                        onExamine: () => _openAnalysisSheet(sikaNotifier),
                        onDismiss: () {
                          setState(() => _showAlert = false);
                        },
                      ),

                    // HUMAN CONFIRMATION BANNER (If Active)
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

                    const SizedBox(height: 12),

                    // SUGGESTIONS FOR YOU (Inspired directly by reference photo 3)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Suggestions for You',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
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

            // FLOATING INPUT BAR (Inspired by reference photos 3 & 4)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: const Color(0xFF334155)),
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
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFF334155)),
                      ),
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Ask SIKA anything...',
                          hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 14),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (val) => _submitQuery(val, sikaNotifier),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => sikaNotifier.toggleListening(),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: sikaData.state == SikaState.listening
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981).withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        sikaData.state == SikaState.listening ? Icons.mic_off : Icons.mic,
                        color: sikaData.state == SikaState.listening
                            ? Colors.white
                            : const Color(0xFF10B981),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _submitQuery(_inputController.text, sikaNotifier),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
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

  Widget _buildWalletChip(String name, String amount, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Icon(icon, color: const Color(0xFF38BDF8), size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionPill({
    required String icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF334155)),
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
                color: Color(0xFF64748B),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

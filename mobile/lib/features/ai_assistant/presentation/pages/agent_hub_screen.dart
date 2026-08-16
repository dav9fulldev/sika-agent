import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/sika_provider.dart';
import '../widgets/agent_orb_widget.dart';
import '../widgets/proactive_alert_card.dart';
import '../widgets/human_confirmation_card.dart';
import '../widgets/insight_card_widget.dart';

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
  bool _showAlert = true;
  bool _showConfirmation = true;

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark slate background
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF0EA5E9)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('🤖', style: TextStyle(fontSize: 20)),
              ),
            ),
            const SizedBox(width: 12),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIKA',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  'Your Personal Financial Agent',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_outlined, size: 14, color: Color(0xFF10B981)),
                SizedBox(width: 4),
                Text(
                  'Agent Active',
                  style: TextStyle(
                    color: Color(0xFF10B981),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // HERO AGENT ORB WIDGET
            AgentOrbWidget(
              state: sikaData.state,
              onTap: () => sikaNotifier.toggleListening(),
            ),

            const SizedBox(height: 24),

            // INTERACTION MODALITIES (VOICE & CHAT BUTTONS)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => sikaNotifier.toggleListening(),
                      icon: Icon(
                        sikaData.state == SikaState.listening ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                      ),
                      label: Text(
                        sikaData.state == SikaState.listening ? 'Stop Listening' : '🎙️ Voice',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sikaData.state == SikaState.listening
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onOpenChat,
                      icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8)),
                      label: const Text(
                        '💬 Chat',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // PROACTIVE FINANCIAL ALERT CARD (Intervention Proactive)
            if (_showAlert)
              ProactiveAlertCard(
                message:
                    'Une dépense de 30 000 FCFA vient d\'être détectée. D\'après tes dépenses récentes et ton objectif d\'épargne, cette dépense risque de compromettre ton objectif du mois.',
                onExamine: () {
                  sikaNotifier.sendTextMessage('Analyse la dépense de 30 000 FCFA détectée.');
                  widget.onOpenChat();
                },
                onDismiss: () {
                  setState(() => _showAlert = false);
                },
              ),

            // HUMAN-IN-THE-LOOP CONFIRMATION CARD
            if (_showConfirmation)
              HumanConfirmationCard(
                actionTitle: 'Préparation de Transfert',
                recipientText: 'Kouamé (Wave)',
                amountText: '10 000 FCFA',
                onConfirm: () {
                  sikaNotifier.sendTextMessage('Je confirme le transfert de 10 000 FCFA.');
                  setState(() => _showConfirmation = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Action confirmée par l\'utilisateur.'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                },
                onCancel: () {
                  setState(() => _showConfirmation = false);
                },
              ),

            const SizedBox(height: 16),

            // RECENT INSIGHTS SECTION
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent Insights',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onOpenInsights,
                    child: const Text(
                      'View All',
                      style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            InsightCardWidget(
              iconEmoji: '💡',
              title: 'Dépenses plus élevées cette semaine',
              description: 'Tes dépenses ont augmenté de 15% par rapport à la semaine dernière.',
              accentColor: const Color(0xFFF59E0B),
              onTap: widget.onOpenInsights,
            ),

            InsightCardWidget(
              iconEmoji: '🎯',
              title: 'Objectif d\'épargne en bonne voie',
              description: 'Tu as atteint 75% de ton objectif d\'épargne du mois.',
              accentColor: const Color(0xFF10B981),
              onTap: widget.onOpenInsights,
            ),

            InsightCardWidget(
              iconEmoji: '📊',
              title: 'Nouveau contexte financier analysé',
              description: 'SIKA surveille tes 3 portefeuilles Mobile Money en arrière-plan.',
              accentColor: const Color(0xFF38BDF8),
              onTap: widget.onOpenInsights,
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

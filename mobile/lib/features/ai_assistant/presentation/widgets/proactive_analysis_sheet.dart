import 'package:flutter/material.dart';

class ProactiveAnalysisSheet extends StatelessWidget {
  final VoidCallback onDismiss;
  final VoidCallback onViewExpenses;
  final VoidCallback onSetLimit;

  const ProactiveAnalysisSheet({
    super.key,
    required this.onDismiss,
    required this.onViewExpenses,
    required this.onSetLimit,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onDismiss,
    required VoidCallback onViewExpenses,
    required VoidCallback onSetLimit,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ProactiveAnalysisSheet(
        onDismiss: () {
          Navigator.pop(ctx);
          onDismiss();
        },
        onViewExpenses: () {
          Navigator.pop(ctx);
          onViewExpenses();
        },
        onSetLimit: () {
          Navigator.pop(ctx);
          onSetLimit();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B), // Dark slate surface
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: Color(0xFFF59E0B), width: 2), // Amber accent top border
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // HANDLE BAR
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF475569),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),

          // HEADER
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  color: Color(0xFFF59E0B),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'SIKA Analysis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Proactive SIKA Intervention',
                      style: TextStyle(
                        color: Color(0xFFF59E0B),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF94A3B8)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // DETECTED TRANSACTION METRICS CARD
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF334155)),
            ),
            child: Column(
              children: [
                _buildMetricRow('💰 Expense Detected', '30 000 FCFA', isHighlight: true),
                const Divider(color: Color(0xFF1E293B), height: 16),
                _buildMetricRow('Category', 'Dining / Restaurant'),
                const SizedBox(height: 6),
                _buildMetricRow('Similar spending this week', '12 500 FCFA'),
                const SizedBox(height: 6),
                _buildMetricRow('Remaining budget', '45 000 FCFA'),
                const SizedBox(height: 6),
                _buildMetricRow('Monthly savings goal', '50 000 FCFA'),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // REASONING SECTION ("Why am I alerting you?")
          const Text(
            'Why am I alerting you?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
            ),
            child: const Text(
              'This single expense consumes about two-thirds of your remaining budget (45,000 FCFA) and threatens your 50,000 FCFA savings target.',
              style: TextStyle(
                color: Color(0xFFE2E8F0),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ACTION CHOICES ("What would you like to do?")
          const Text(
            'What would you like to do?',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDismiss,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF94A3B8),
                    side: const BorderSide(color: Color(0xFF475569)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Ignore'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: onViewExpenses,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('View Spending', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: onSetLimit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Définir une limite', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isHighlight ? Colors.white : const Color(0xFF94A3B8),
            fontSize: isHighlight ? 14 : 12.5,
            fontWeight: isHighlight ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? const Color(0xFFF59E0B) : Colors.white,
            fontSize: isHighlight ? 15 : 12.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

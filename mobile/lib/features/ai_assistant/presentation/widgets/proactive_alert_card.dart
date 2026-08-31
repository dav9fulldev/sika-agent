import 'package:flutter/material.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';

class ProactiveAlertCard extends StatelessWidget {
  final String title;
  final String message;
  final String amountText;
  final VoidCallback onExamine;
  final VoidCallback onDismiss;

  const ProactiveAlertCard({
    super.key,
    this.title = 'Financial Alert',
    required this.message,
    this.amountText = '—',
    required this.onExamine,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SikaGlassCard(
        borderColor: const Color(0xFFF59E0B).withValues(alpha: 0.4),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFF59E0B),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚠️ $title',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: const Color(0xFFF59E0B),
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                      Text(
                        'Proactive SIKA Intervention',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF94A3B8) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    amountText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFE2E8F0),
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Expanded(
                  child: SikaPremiumButton(
                    onPressed: onDismiss,
                    text: 'Ignore',
                    isSecondary: true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SikaPremiumButton(
                    onPressed: onExamine,
                    prefixWidget: const Icon(Icons.analytics_outlined, size: 16),
                    text: 'Review',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


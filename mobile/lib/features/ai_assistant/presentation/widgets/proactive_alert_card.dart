import 'dart:ui';
import 'package:flutter/material.dart';

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
    this.amountText = '30 000 FCFA',
    required this.onExamine,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: 0.6), // Dark semi-transparent
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.4), // Amber border
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Padding(
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
                                          color: const Color(0xFF94A3B8),
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
                        TextButton(
                          onPressed: onDismiss,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF94A3B8),
                          ),
                          child: const Text('Ignore'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: onExamine,
                          icon: const Icon(Icons.analytics_outlined, size: 16),
                          label: const Text('Review'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF59E0B),
                            foregroundColor: Colors.black,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

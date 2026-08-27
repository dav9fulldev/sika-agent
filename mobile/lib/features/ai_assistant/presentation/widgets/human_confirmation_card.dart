import 'dart:ui';
import 'package:flutter/material.dart';

class HumanConfirmationCard extends StatelessWidget {
  final String actionTitle;
  final String recipientText;
  final String amountText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const HumanConfirmationCard({
    super.key,
    this.actionTitle = 'Validation requise par l\'humain',
    this.recipientText = 'Kouamé (Wave)',
    this.amountText = '10 000 FCFA',
    required this.onConfirm,
    required this.onCancel,
  });

  void _showBiometricModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFF334155),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Color(0xFF10B981),
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Authentification Biométrique',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Confirmez avec Face ID ou votre empreinte digitale pour autoriser le transfert de $amountText vers $recipientText.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF94A3B8),
                    ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined,
                        color: Color(0xFF10B981), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Validation Partenaire SIKA',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Code Secret / Empreinte requis (comme sur l\'application officielle)',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: const Color(0xFF94A3B8),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    onConfirm();
                  },
                  icon: const Icon(Icons.fingerprint, size: 22),
                  label: Text(
                    'Scanner l\'empreinte / Face ID',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Annuler la transaction',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: const Color(0xFF94A3B8)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

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
                color: const Color(0xFF10B981).withValues(alpha: 0.4), // Emerald border
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
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
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Validation requise par l\'humain',
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          'Sika attend votre confirmation par empreinte ou Face ID',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: const Color(0xFF94A3B8),
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).cardColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          actionTitle,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        Text(
                          amountText,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: const Color(0xFF10B981),
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    Divider(color: Theme.of(context).cardColor, height: 16),
                    _buildDetailRow(context, 'Destinataire', recipientText),
                    const SizedBox(height: 4),
                    _buildDetailRow(context, 'Plateforme', 'PayMeChap / Wave'),
                    const SizedBox(height: 4),
                    _buildDetailRow(context, 'Frais', '0 FCFA'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '🎙️ Sika vous a ré-dicté les informations vocalement. Validez par Face ID / Empreinte.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onCancel,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF94A3B8),
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: () => _showBiometricModal(context),
                    icon: const Icon(Icons.fingerprint, size: 18),
                    label: const Text('Valider (Face ID / Empreinte)'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
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

  Widget _buildDetailRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

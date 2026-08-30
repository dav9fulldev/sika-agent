import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';

/// ReconciliationStatusCard — SIKA Financial Assistant Reassuring Status Card
/// 
/// Displayed when a transaction result is uncertain (UNKNOWN_RESULT / REQUIRES_RECONCILIATION).
/// Strictly adheres to:
/// - Reassuring, calm blue/indigo financial design (never red or alarming yellow).
/// - Clear anti-duplicate instruction: "Pour éviter un doublon, ne relancez pas cette opération."
/// - Single-action read-only status verification with built-in debouncing.
/// - Full accessibility and dark/light mode compatibility.
class ReconciliationStatusCard extends StatefulWidget {
  final String actionId;
  final Future<void> Function(String actionId) onReconcile;

  const ReconciliationStatusCard({
    super.key,
    required this.actionId,
    required this.onReconcile,
  });

  @override
  State<ReconciliationStatusCard> createState() =>
      _ReconciliationStatusCardState();
}

class _ReconciliationStatusCardState extends State<ReconciliationStatusCard>
    with SingleTickerProviderStateMixin {
  bool _isChecking = false;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  Future<void> _handleReconcile() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });
    _rotationController.repeat();

    try {
      await widget.onReconcile(widget.actionId);
    } finally {
      if (mounted) {
        _rotationController.stop();
        _rotationController.reset();
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      label:
          'Vérification du statut de la transaction en cours. Ne relancez pas l\'opération pour éviter un doublon.',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SikaGlassCard(
          borderColor: AppColors.info.withValues(alpha: 0.35),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER WITH SHIELD / SYNC ICON ────────────────────────
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: _isChecking
                        ? RotationTransition(
                            turns: _rotationController,
                            child: const Icon(
                              Icons.sync_rounded,
                              color: AppColors.info,
                              size: 20,
                            ),
                          )
                        : const Icon(
                            Icons.shield_outlined,
                            color: AppColors.info,
                            size: 20,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.info.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'VÉRIFICATION EN COURS',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.info,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.5,
                                      fontSize: 10,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Nous confirmons le statut de votre opération auprès de PayMeChap.',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.lightTextSecondary,
                                fontSize: 12,
                                height: 1.3,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── 2. ANTI-DUPLICATE REASSURING NOTICE ──────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurfaceHighlight
                      : AppColors.lightSurfaceHighlight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: 0.05),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pour éviter un doublon, ne relancez pas cette opération.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.lightTextSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // ── 3. VERIFY ACTION BUTTON ──────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  button: true,
                  label: 'Vérifier le statut de la transaction en direct',
                  child: SikaPremiumButton(
                    onPressed: _isChecking ? null : _handleReconcile,
                    prefixWidget: _isChecking
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    text: _isChecking
                        ? 'Vérification en direct...'
                        : 'Vérifier le statut',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: -0.05, end: 0);
  }
}

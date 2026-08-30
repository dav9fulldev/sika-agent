import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/widgets/sika_glass_card.dart';
import '../../../../core/widgets/sika_premium_button.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/sika_provider.dart';

/// HumanConfirmationCard — SIKA Financial Assistant Human-in-the-Loop Confirmation Card
/// 
/// Strictly adheres to:
/// - Explicit distinction: "ACTION PRÉPARÉE" vs "ACTION EXÉCUTÉE".
/// - Prominent security disclaimer: "Votre argent n'a pas encore été transféré."
/// - Handles all states: active (waiting confirmation), security validation, executing, completed, obsolete, cancelled.
/// - Double-click / double-tap prevention (both locally and in the Provider).
/// - Accessible biometric bottom sheet with clear identity authorization description.
class HumanConfirmationCard extends ConsumerStatefulWidget {
  final String? actionId;
  final String actionTitle;
  final String recipientText;
  final String amountText;
  final String? sourceAccount;
  final String? feeText;
  final String? platformText;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const HumanConfirmationCard({
    super.key,
    this.actionId,
    this.actionTitle = 'Transfert d\'argent',
    this.recipientText = 'Destinataire',
    this.amountText = '---',
    this.sourceAccount,
    this.feeText,
    this.platformText,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  ConsumerState<HumanConfirmationCard> createState() =>
      _HumanConfirmationCardState();
}

class _HumanConfirmationCardState extends ConsumerState<HumanConfirmationCard> {
  bool _isSubmittingLocally = false;

  void _handleConfirmTap() {
    if (_isSubmittingLocally) return;
    _showBiometricModal(context);
  }

  void _showBiometricModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkBackground
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Biometric Icon Badge
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.brandAccent.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      color: AppColors.brandAccent,
                      size: 48,
                    ),
                  ),
                  const SizedBox(height: 16),

                  Text(
                    'Authentification Biométrique',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const SizedBox(height: 8),

                  Semantics(
                    label: 'Explication de la confirmation biométrique',
                    child: Text(
                      'Confirmez votre identité avec Face ID ou votre empreinte digitale pour autoriser le transfert de ${widget.amountText} vers ${widget.recipientText}.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            height: 1.4,
                          ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // SIKA Security Guarantee
                  SikaGlassCard(
                    padding: const EdgeInsets.all(14),
                    borderColor: AppColors.brandAccent.withValues(alpha: 0.3),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_user_outlined,
                          color: AppColors.brandAccent,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Autorisation sécurisée SIKA',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Votre confirmation biométrique signe définitivement cette transaction.',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Confirm button with debouncing
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      button: true,
                      label: 'Confirmer votre identité avec la biométrie pour autoriser cette opération',
                      child: SikaPremiumButton(
                        onPressed: _isSubmittingLocally
                            ? null
                            : () {
                                setModalState(() => _isSubmittingLocally = true);
                                setState(() => _isSubmittingLocally = true);
                                Navigator.pop(ctx);
                                widget.onConfirm();
                              },
                        prefixWidget: _isSubmittingLocally
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.fingerprint, size: 22),
                        text: _isSubmittingLocally
                            ? 'Validation en cours...'
                            : 'Scanner l\'empreinte / Face ID',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Cancel button
                  SizedBox(
                    width: double.infinity,
                    child: Semantics(
                      button: true,
                      label: 'Annuler cette opération préparée',
                      child: SikaPremiumButton(
                        onPressed: _isSubmittingLocally
                            ? null
                            : () {
                                Navigator.pop(ctx);
                                widget.onCancel();
                              },
                        text: 'Annuler l\'opération',
                        isSecondary: true,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sikaData = ref.watch(sikaProvider);

    // Determine state of this specific card
    final bool isObsolete = (widget.actionId != null &&
            sikaData.obsoleteActionIds.contains(widget.actionId)) ||
        (widget.actionId != null &&
            sikaData.activeActionId != null &&
            sikaData.activeActionId != widget.actionId);

    final bool isExecuting = sikaData.state == SikaState.executingAction &&
        (widget.actionId == null || widget.actionId == sikaData.activeActionId);

    final bool isCompleted = sikaData.state == SikaState.completed &&
        (widget.actionId == null || widget.actionId == sikaData.activeActionId);

    return Opacity(
      opacity: isObsolete ? 0.55 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SikaGlassCard(
          borderColor: isObsolete
              ? (isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle)
              : (isExecuting
                  ? AppColors.brandPrimary.withValues(alpha: 0.6)
                  : AppColors.brandAccent.withValues(alpha: 0.4)),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 1. HEADER BADGE & STATUS ─────────────────────────────────
              _buildHeaderBadge(context, isDark, isObsolete, isExecuting, isCompleted),
              const SizedBox(height: 12),

              // ── 2. SECURITY DISCLAIMER ──────────────────────────────────
              if (!isObsolete && !isExecuting && !isCompleted)
                _buildSecurityDisclaimer(context, isDark),

              const SizedBox(height: 12),

              // ── 3. TRANSACTION DETAILS CARD ─────────────────────────────
              _buildDetailsCard(context, isDark, isObsolete),

              const SizedBox(height: 12),

              // ── 4. ACTION BUTTONS ───────────────────────────────────────
              _buildActionButtons(context, isObsolete, isExecuting, isCompleted),
            ],
          ),
        ),
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildHeaderBadge(BuildContext context, bool isDark, bool isObsolete,
      bool isExecuting, bool isCompleted) {
    Color badgeBg;
    Color badgeTextColor;
    String badgeText;
    String statusSubtitle;
    IconData badgeIcon;

    if (isObsolete) {
      badgeBg = isDark
          ? AppColors.darkSurfaceHighlight
          : AppColors.lightSurfaceHighlight;
      badgeTextColor = isDark
          ? AppColors.darkTextTertiary
          : AppColors.lightTextTertiary;
      badgeText = 'REMPLACÉE';
      statusSubtitle = 'Cette préparation a été remplacée par une nouvelle demande.';
      badgeIcon = Icons.history_rounded;
    } else if (isExecuting) {
      badgeBg = AppColors.brandPrimary.withValues(alpha: 0.15);
      badgeTextColor = AppColors.brandPrimary;
      badgeText = 'EXÉCUTION SÉCURISÉE';
      statusSubtitle = 'Transfert en cours de finalisation sur PayMeChap...';
      badgeIcon = Icons.sync_rounded;
    } else if (isCompleted) {
      badgeBg = AppColors.brandAccent.withValues(alpha: 0.15);
      badgeTextColor = AppColors.brandAccent;
      badgeText = 'TRANSACTION EFFECTUÉE';
      statusSubtitle = 'L\'opération a été confirmée et traitée avec succès.';
      badgeIcon = Icons.check_circle_outline_rounded;
    } else {
      badgeBg = AppColors.brandAccent.withValues(alpha: 0.15);
      badgeTextColor = AppColors.brandAccent;
      badgeText = 'ACTION PRÉPARÉE';
      statusSubtitle = 'En attente de votre confirmation biométrique';
      badgeIcon = Icons.shield_outlined;
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: badgeBg,
            shape: BoxShape.circle,
          ),
          child: Icon(
            badgeIcon,
            color: badgeTextColor,
            size: 22,
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
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      badgeText,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: badgeTextColor,
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
                statusSubtitle,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.lightTextSecondary,
                      fontSize: 11,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityDisclaimer(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.brandAccent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.brandAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.brandAccent,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Votre argent n\'a pas encore été transféré.',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.lightTextPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard(
      BuildContext context, bool isDark, bool isObsolete) {
    return SikaGlassCard(
      padding: const EdgeInsets.all(14),
      borderColor: isDark ? AppColors.darkBorderSubtle : AppColors.lightBorderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount & Title
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                widget.actionTitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                widget.amountText,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: isObsolete
                          ? (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.lightTextTertiary)
                          : AppColors.brandAccent,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ],
          ),
          Divider(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.08),
            height: 18,
          ),
          _buildDetailRow(context, isDark, 'Destinataire', widget.recipientText),
          const SizedBox(height: 6),
          _buildDetailRow(
              context, isDark, 'Compte source', widget.sourceAccount ?? 'Portefeuille Principal'),
          const SizedBox(height: 6),
          _buildDetailRow(context, isDark, 'Frais SIKA', widget.feeText ?? '0 FCFA'),
          const SizedBox(height: 6),
          _buildDetailRow(
              context, isDark, 'Plateforme', widget.platformText ?? 'PayMeChap / Direct'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, bool isDark, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextSecondary
                : AppColors.lightTextSecondary,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: isDark
                ? AppColors.darkTextPrimary
                : AppColors.lightTextPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isObsolete,
      bool isExecuting, bool isCompleted) {
    if (isObsolete) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        child: Text(
          '⛔ Action désactivée (remplacée par une demande plus récente)',
          style: TextStyle(
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
            fontSize: 11,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    if (isExecuting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.brandPrimary,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'Exécution sécurisée en cours...',
              style: TextStyle(
                color: AppColors.brandPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, color: AppColors.brandAccent, size: 18),
            SizedBox(width: 8),
            Text(
              'Opération confirmée et exécutée avec succès',
              style: TextStyle(
                color: AppColors.brandAccent,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Annuler cette opération préparée',
            child: SikaPremiumButton(
              onPressed: _isSubmittingLocally ? null : widget.onCancel,
              text: 'Annuler',
              isSecondary: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Semantics(
            button: true,
            label: 'Confirmer votre identité avec la biométrie',
            child: SikaPremiumButton(
              onPressed: _isSubmittingLocally ? null : _handleConfirmTap,
              prefixWidget: const Icon(Icons.fingerprint, size: 18),
              text: 'Confirmer (Biométrie)',
            ),
          ),
        ),
      ],
    );
  }
}

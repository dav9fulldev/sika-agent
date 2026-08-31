import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/services/biometric_service.dart';
import '../../providers/sika_provider.dart';

/// HumanConfirmationCard — SIKA Financial Assistant High-End Confirmation Card
/// 
/// Designed by UI/UX & Security Engineers:
/// - Distinctive Deep Midnight & Indigo Glassmorphism (High-contrast on light chat backgrounds).
/// - Instant Native Biometric Prompt on "Valider par Empreinte" (Zero redundant intermediate bottom sheets).
/// - Seamless PayMeChap 4-Digit PIN modal fallback.
/// - Clear security disclaimer and financial audit details.
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
    required this.actionTitle,
    required this.recipientText,
    required this.amountText,
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
  bool _hasAutoPrompted = false;

  @override
  void initState() {
    super.initState();
    // Auto-prompt biometrics once after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasAutoPrompted) {
        _hasAutoPrompted = true;
        _handleBiometricConfirmTap(isAuto: true);
      }
    });
  }

  Future<void> _handleBiometricConfirmTap({bool isAuto = false}) async {
    if (_isSubmittingLocally) return;

    final biometricService = ref.read(biometricServiceProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final bool isAvailable = await biometricService.isBiometricsAvailable();
    if (!isAvailable) {
      if (!isAuto && mounted) {
        _showPinModal(context);
      }
      return;
    }

    try {
      final bool authenticated = await biometricService.authenticate(
        localizedReason: langNotifier.tr(
          'Authentifiez-vous pour sécuriser PayMeChap et valider ce transfert.',
          'Authenticate to secure PayMeChap and validate this transfer.',
        ),
      );

      if (authenticated && mounted) {
        setState(() => _isSubmittingLocally = true);
        widget.onConfirm();
      } else if (!isAuto && mounted) {
        _showPinModal(context);
      }
    } catch (_) {
      if (!isAuto && mounted) {
        _showPinModal(context);
      }
    }
  }

  void _showPinModal(BuildContext context) {
    final langNotifier = ref.read(languageProvider.notifier);
    final apiService = ref.read(apiServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String pinInput = '';
    String? pinError;
    bool isVerifyingPin = false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(modalCtx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  border: Border.all(
                    color: AppColors.brandPrimary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Icon & Title
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.pin_rounded,
                        color: AppColors.brandPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      langNotifier.tr('Code PIN PayMeChap', 'PayMeChap PIN Code'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),

                    Text(
                      langNotifier.tr(
                        'Entrez votre code secret PayMeChap (4 chiffres) pour signer le transfert de ${widget.amountText}.',
                        'Enter your 4-digit PayMeChap PIN to sign the transfer of ${widget.amountText}.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : Colors.black54,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // PIN Input
                    Container(
                      width: 220,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: pinError != null ? AppColors.error : AppColors.brandPrimary.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        maxLength: 4,
                        obscureText: true,
                        obscuringCharacter: '●',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 14,
                        ),
                        decoration: const InputDecoration(
                          counterText: '',
                          border: InputBorder.none,
                          hintText: '••••',
                          hintStyle: TextStyle(
                            fontSize: 26,
                            letterSpacing: 14,
                            color: Colors.grey,
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          setModalState(() {
                            pinInput = val.trim();
                            pinError = null;
                          });
                        },
                      ),
                    ),

                    if (pinError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        pinError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Submit PIN Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: (pinInput.length < 4 || isVerifyingPin || _isSubmittingLocally)
                            ? null
                            : () async {
                                setModalState(() {
                                  isVerifyingPin = true;
                                  pinError = null;
                                });
                                try {
                                  await apiService.verifyWalletPin(pin: pinInput);
                                  setModalState(() => _isSubmittingLocally = true);
                                  setState(() => _isSubmittingLocally = true);
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  widget.onConfirm();
                                } catch (err) {
                                  setModalState(() {
                                    isVerifyingPin = false;
                                    pinError = langNotifier.tr(
                                      'Code PIN PayMeChap incorrect.',
                                      'Incorrect PayMeChap PIN code.',
                                    );
                                  });
                                }
                              },
                        child: isVerifyingPin
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                langNotifier.tr('Confirmer le transfert', 'Confirm transfer'),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Cancel
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        langNotifier.tr('Retour', 'Back'),
                        style: TextStyle(
                          color: isDark ? Colors.white60 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sikaData = ref.watch(sikaProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final bool isObsolete = (widget.actionId != null &&
            sikaData.obsoleteActionIds.contains(widget.actionId)) ||
        (widget.actionId != null &&
            sikaData.activeActionId != null &&
            sikaData.activeActionId != widget.actionId);

    final bool isExecuting = sikaData.state == SikaState.executingAction &&
        (widget.actionId == null || widget.actionId == sikaData.activeActionId);

    final bool isCompleted = sikaData.state == SikaState.completed &&
        (widget.actionId == null || widget.actionId == sikaData.activeActionId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF1E1B4B), // Indigo 950
            Color(0xFF0B132B), // Midnight Blue
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isExecuting
              ? const Color(0xFF6366F1)
              : const Color(0xFF10B981).withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 1. HEADER BADGE & STATUS ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        langNotifier.tr('ACTION PRÉPARÉE', 'ACTION PREPARED'),
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  widget.platformText ?? 'PayMeChap / Direct',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── 2. SECURITY DISCLAIMER ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF064E3B).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF34D399),
                    size: 15,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      langNotifier.tr(
                        'Votre argent n\'a pas encore été transféré.',
                        'Your funds have not been transferred yet.',
                      ),
                      style: const TextStyle(
                        color: Color(0xFFE2E8F0),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── 3. FINANCIAL SUMMARY ──
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        langNotifier.tr('Montant à transférer', 'Amount to transfer'),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        widget.amountText,
                        style: const TextStyle(
                          color: Color(0xFF34D399),
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 16),
                  _buildDarkDetailRow('Destinataire', widget.recipientText, Icons.person_outline_rounded),
                  const SizedBox(height: 6),
                  _buildDarkDetailRow('Compte source', widget.sourceAccount ?? 'PayMeChap', Icons.account_balance_wallet_outlined),
                  const SizedBox(height: 6),
                  _buildDarkDetailRow('Frais SIKA', widget.feeText ?? 'Gratuit', Icons.check_circle_outline_rounded),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── 4. ACTION BUTTONS ──
            if (isExecuting) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Validation PayMeChap en cours...',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ] else if (isCompleted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Transfert effectué avec succès',
                      style: TextStyle(color: Color(0xFF34D399), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ] else if (isObsolete) ...[
              Center(
                child: Text(
                  langNotifier.tr('Demande expirée ou remplacée', 'Request expired or replaced'),
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ] else ...[
              Row(
                children: [
                  // Cancel
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmittingLocally ? null : widget.onCancel,
                        child: Text(
                          langNotifier.tr('Annuler', 'Cancel'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // PIN Option
                  SizedBox(
                    height: 46,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _isSubmittingLocally ? null : () => _showPinModal(context),
                      icon: const Icon(Icons.pin_rounded, size: 16),
                      label: Text(
                        langNotifier.tr('Code PIN', 'PIN Code'),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Biometrics Primary
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isSubmittingLocally ? null : () => _handleBiometricConfirmTap(isAuto: false),
                        icon: const Icon(Icons.fingerprint_rounded, size: 18),
                        label: Text(
                          langNotifier.tr('Valider', 'Authorize'),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildDarkDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.white54),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white60, fontSize: 12),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

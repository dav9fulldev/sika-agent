import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';

/// AgentProgressWidget — Displays observable SIKA agent execution steps
/// 
/// Strictly adheres to:
/// - No internal chain of thought, reasoning, or system prompts.
/// - In-flight mode: Displays honest, generic activity while processing.
/// - Confirmed mode: Displays real observable `agent_steps` returned by the backend.
/// - Supports status: pending (○), active (●), completed (✓), failed (✕).
class AgentProgressWidget extends StatefulWidget {
  final List<Map<String, dynamic>>? steps;
  final bool isWorking;
  final String? initialWorkingText;

  const AgentProgressWidget({
    super.key,
    this.steps,
    this.isWorking = false,
    this.initialWorkingText,
  });

  @override
  State<AgentProgressWidget> createState() => _AgentProgressWidgetState();
}

class _AgentProgressWidgetState extends State<AgentProgressWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  int _workingPhase = 0;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // If in-flight working mode, advance generic phase gently after 2.5s
    if (widget.isWorking) {
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && widget.isWorking) {
          setState(() {
            _workingPhase = 1;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (widget.isWorking && (widget.steps == null || widget.steps!.isEmpty)) {
      return _buildInFlightWorkingIndicator(context, isDark);
    }

    if (widget.steps != null && widget.steps!.isNotEmpty) {
      return _buildConfirmedStepsCard(context, isDark, widget.steps!);
    }

    return const SizedBox.shrink();
  }

  /// In-flight mode: generic honest observable activity
  Widget _buildInFlightWorkingIndicator(BuildContext context, bool isDark) {
    final String currentText = widget.initialWorkingText ??
        (_workingPhase == 0
            ? 'SIKA analyse votre demande...'
            : 'SIKA prépare votre réponse...');

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceHighlight : AppColors.lightSurfaceHighlight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing animated active pulse dot
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandPrimary.withValues(alpha: _pulseAnimation.value),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandPrimary.withValues(alpha: _pulseAnimation.value * 0.5),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(width: 12),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                currentText,
                key: ValueKey(currentText),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms).slideY(begin: 0.05, end: 0);
  }

  /// Confirmed steps card: Displays observable completed/failed steps returned by backend
  Widget _buildConfirmedStepsCard(
      BuildContext context, bool isDark, List<Map<String, dynamic>> steps) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurface.withValues(alpha: 0.8)
            : AppColors.lightSurfaceHighlight.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header / subtle badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.task_alt_rounded,
                size: 14,
                color: AppColors.brandPrimary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 6),
              Consumer(
                builder: (context, ref, _) => Text(
                  ref.watch(languageProvider) == AppLanguage.french ? 'Étapes réalisées' : 'Steps completed',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.brandPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // List of steps
          ...steps.map((step) => _buildStepRow(context, isDark, step)),
        ],
      ),
    ).animate().fade(duration: 350.ms).slideY(begin: 0.04, end: 0);
  }

  Widget _buildStepRow(
      BuildContext context, bool isDark, Map<String, dynamic> step) {
    final String status = step['status']?.toString().toLowerCase() ?? 'completed';
    final String label = step['label']?.toString() ?? 'Opération';

    IconData iconData;
    Color iconColor;

    switch (status) {
      case 'active':
        iconData = Icons.radio_button_checked_rounded;
        iconColor = AppColors.brandPrimary;
        break;
      case 'pending':
        iconData = Icons.radio_button_unchecked_rounded;
        iconColor = isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary;
        break;
      case 'failed':
        iconData = Icons.cancel_rounded;
        iconColor = AppColors.error;
        break;
      case 'completed':
      default:
        iconData = Icons.check_circle_rounded;
        iconColor = AppColors.brandAccent;
        break;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            iconData,
            size: 14,
            color: iconColor,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: status == 'pending' ? 0.45 : 0.85),
                    fontSize: 12,
                    fontWeight: status == 'active' ? FontWeight.w600 : FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


import '../../../../core/widgets/sika_pay_brand.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';

class SikaInputBar extends ConsumerWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isListening;
  final bool isSpeaking;
  final VoidCallback onMicTap;
  final VoidCallback onSendTap;
  final ValueChanged<String> onSubmitted;

  const SikaInputBar({
    super.key,
    required this.controller,
    this.focusNode,
    required this.isListening,
    required this.isSpeaking,
    required this.onMicTap,
    required this.onSendTap,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);
    final hint = langNotifier.tr('Demander à SIKA...', 'Ask SIKA...');

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 8,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.75)
                  : Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Mic Button
                GestureDetector(
                  onTap: onMicTap,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 2),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isListening || isSpeaking)
                          ? SikaBrand.action.withValues(alpha: 0.1)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isListening
                          ? Icons.mic_rounded
                          : (isSpeaking ? Icons.stop_rounded : Icons.mic_none_rounded),
                      color: (isListening || isSpeaking)
                          ? SikaBrand.action
                          : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text Field
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                    child: Center(
                      child: TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 15,
                            ),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            fontSize: 15,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onSubmitted: onSubmitted,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send Button
                GestureDetector(
                  onTap: onSendTap,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 2),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: SikaBrand.action,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: SikaBrand.action.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

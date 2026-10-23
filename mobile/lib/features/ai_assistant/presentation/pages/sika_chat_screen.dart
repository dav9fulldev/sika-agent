import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/providers/language_provider.dart';
import '../../providers/sika_provider.dart';
import '../widgets/sika_prompt_suggestion.dart';
import '../widgets/sika_thinking_indicator.dart';
import '../widgets/sika_chat_bubble.dart';
import '../widgets/sika_input_bar.dart';

class SikaChatScreen extends ConsumerStatefulWidget {
  final VoidCallback? onBackPressed;

  const SikaChatScreen({super.key, this.onBackPressed});

  @override
  ConsumerState<SikaChatScreen> createState() => _SikaChatScreenState();
}

class _SikaChatScreenState extends ConsumerState<SikaChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSend(SikaNotifier notifier) {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      notifier.sendTextMessage(text);
      _textController.clear();
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<SikaData>(sikaProvider, (previous, next) {
      if (next.state == SikaState.listening &&
          next.currentText != null &&
          next.currentText!.isNotEmpty) {
        if (previous?.currentText != next.currentText) {
          _textController.text = next.currentText!;
        }
      } else if (previous?.state == SikaState.listening &&
          next.state != SikaState.listening) {
        if (next.currentText == null || next.currentText!.isEmpty) {
          _textController.clear();
        }
      }

      // Auto-scroll when confirmation card appears/disappears
      if (previous?.state != next.state &&
          (next.state == SikaState.securityValidation ||
           previous?.state == SikaState.securityValidation)) {
        _scrollToBottom();
      }

      if (previous?.messages.length != next.messages.length) {
        _scrollToBottom();
      }
    });

    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    ref.watch(languageProvider);
    final langNotifier = ref.read(languageProvider.notifier);

    final bool isProcessing = sikaData.state == SikaState.processing ||
        sikaData.state == SikaState.agentWorking;

    // Lock input when confirmation is waiting
    final bool isAwaitingConfirmation = sikaData.pendingActionId != null &&
        (sikaData.state == SikaState.securityValidation ||
            sikaData.state == SikaState.waitingVoiceConfirmation ||
            sikaData.state == SikaState.executingAction);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: _buildAppBar(context, isDark, isProcessing, sikaNotifier, langNotifier),
      body: Column(
        children: [
          // MESSAGES OR EMPTY STATE
          Expanded(
            child: sikaData.messages.isEmpty
                ? _buildWelcomeState(context, sikaNotifier, langNotifier)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 24),
                    itemCount: sikaData.messages.length + (isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isProcessing && index == sikaData.messages.length) {
                        return const SikaThinkingIndicator();
                      }
                      final message = sikaData.messages[index];
                      return SikaChatBubble(message: message)
                          .animate()
                          .fade(duration: 300.ms)
                          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
                    },
                  ),
          ),

          // ERROR STATE
          if (sikaData.state == SikaState.error && sikaData.pendingActionId == null)
            _buildConnectionError(context, sikaData.errorMessage, langNotifier),

          // INPUT BAR — disabled while waiting for biometric confirmation
          IgnorePointer(
            ignoring: isAwaitingConfirmation,
            child: AnimatedOpacity(
              opacity: isAwaitingConfirmation ? 0.4 : 1.0,
              duration: const Duration(milliseconds: 250),
              child: SikaInputBar(
                controller: _textController,
                isListening: sikaData.state == SikaState.listening,
                isSpeaking: sikaData.state == SikaState.speaking,
                onMicTap: () {
                  if (sikaData.state == SikaState.speaking) {
                    sikaNotifier.stopSpeaking();
                  } else {
                    sikaNotifier.toggleListening();
                  }
                },
                onSendTap: () => _handleSend(sikaNotifier),
                onSubmitted: (_) => _handleSend(sikaNotifier),
              ),
            ),
          ).animate().slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, bool isDark, bool isProcessing, SikaNotifier sikaNotifier, LanguageNotifier langNotifier) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8), size: 20),
        onPressed: () {
          if (widget.onBackPressed != null) {
            widget.onBackPressed!();
          } else if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
      automaticallyImplyLeading: false,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: const Center(
                child: Text('✦', style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SIKA',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isProcessing ? AppColors.brandSecondary : AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isProcessing
                          ? langNotifier.tr('En train de réfléchir...', 'Thinking...')
                          : langNotifier.tr('Assistant actif', 'Active assistant'),
                      style: TextStyle(
                        color: isProcessing ? AppColors.brandSecondary : AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 22),
              onPressed: () => sikaNotifier.clearConversation(),
              tooltip: langNotifier.tr('Nouvelle conversation', 'New conversation'),
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
        ),
      ),
    );
  }

  Widget _buildWelcomeState(BuildContext context, SikaNotifier sikaNotifier, LanguageNotifier langNotifier) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Visual Identity
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  AppColors.brandPrimary.withValues(alpha: 0.15),
                  Colors.transparent,
                ],
                radius: 0.8,
              ),
            ),
            child: Center(
              child: Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: const Center(
                  child: Text('✦', style: TextStyle(fontSize: 22, color: Colors.white)),
                ),
              ),
            ),
          ).animate().fade(duration: 600.ms).scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          
          Text(
            langNotifier.tr('Bonjour 👋', 'Hello 👋'),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 12),
          
          Text(
            langNotifier.tr(
              'Je suis SIKA Pay. Dites-moi ce que vous voulez acheter et votre budget :\nje vérifie, je prépare le paiement PayPal (sandbox) et vous décidez.',
              'I am SIKA Pay. Tell me what you want to buy and your budget:\nI check, prepare the PayPal (sandbox) payment, and you decide.',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
          ).animate().fade(delay: 400.ms).slideY(begin: 0.1, end: 0),
          const SizedBox(height: 40),
          
          // Suggestions SIKA Pay
          SikaPromptSuggestion(
            text: langNotifier.tr('Acheter un cours Excel à moins de 50 \$', 'Buy an Excel course under \$50'),
            icon: Icons.shopping_bag_outlined,
            delay: 500.ms,
            onTap: () => sikaNotifier.sendTextMessage(langNotifier.tr(
                'Aide-moi à acheter un cours Excel sans dépasser 50 dollars.',
                'Help me buy an Excel course without going over 50 dollars.')),
          ),
          const SizedBox(height: 12),
          SikaPromptSuggestion(
            text: langNotifier.tr('Du stockage cloud, budget 40 \$', 'Cloud storage, \$40 budget'),
            icon: Icons.cloud_outlined,
            delay: 600.ms,
            onTap: () => sikaNotifier.sendTextMessage(langNotifier.tr(
                'Je veux acheter du stockage cloud, mon budget est de 40 dollars.',
                'I want to buy cloud storage, my budget is 40 dollars.')),
          ),
          const SizedBox(height: 12),
          SikaPromptSuggestion(
            text: langNotifier.tr('Où en est mon dernier paiement ?', 'Did my last payment go through?'),
            icon: Icons.fact_check_outlined,
            delay: 700.ms,
            onTap: () => sikaNotifier.sendTextMessage(langNotifier.tr(
                'Où en est mon dernier paiement ?', 'Did my last payment go through?')),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionError(BuildContext context, String? errorMessage, LanguageNotifier langNotifier) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  langNotifier.tr('SIKA n\'a pas pu répondre pour le moment.', 'SIKA was unable to answer right now.'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  errorMessage ?? langNotifier.tr('Une erreur réseau est survenue.', 'A network error occurred.'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fade().slideY();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/sika_provider.dart';

class SikaChatScreen extends ConsumerStatefulWidget {
  const SikaChatScreen({super.key});

  @override
  ConsumerState<SikaChatScreen> createState() => _SikaChatScreenState();
}

class _SikaChatScreenState extends ConsumerState<SikaChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late AnimationController _typingController;
  late Animation<double> _typingAnim;

  @override
  void initState() {
    super.initState();
    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _typingAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _typingController.dispose();
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
    });

    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);
    final bool isProcessing = sikaData.state == SikaState.processing;

    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        backgroundColor: AppColors.darkBackground,
        elevation: 0,
        titleSpacing: 0,
        leading: null,
        automaticallyImplyLeading: false,
        title: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              // Avatar SIKA
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('✦',
                      style: TextStyle(fontSize: 18, color: Colors.white)),
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
                          letterSpacing: -0.3,
                        ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isProcessing
                              ? AppColors.brandSecondary
                              : AppColors.success,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isProcessing
                            ? 'En train de réfléchir...'
                            : 'Agent actif',
                        style: TextStyle(
                          color: isProcessing
                              ? AppColors.brandSecondary
                              : AppColors.success,
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
                icon: const Icon(Icons.refresh_rounded,
                    color: AppColors.darkTextSecondary, size: 22),
                onPressed: () => sikaNotifier.clearConversation(),
                tooltip: 'Nouvelle conversation',
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 0.5,
            color: Colors.white.withValues(alpha: 0.06),
          ),
        ),
      ),
      body: Column(
        children: [
          // BANNER DE TRAITEMENT
          if (isProcessing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.08),
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.brandPrimary.withValues(alpha: 0.15),
                  ),
                ),
              ),
              child: Row(
                children: [
                  _buildThinkingDots(),
                  const SizedBox(width: 12),
                  const Text(
                    '✦  Analyse de votre contexte financier...',
                    style: TextStyle(
                      color: AppColors.brandSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: -0.3, end: 0),

          // RECONCILIATION BANNER
          if (sikaData.pendingActionId != null &&
              sikaData.state == SikaState.error)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AppColors.warning, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Statut incertain. Vérifiez l\'opération.',
                      style:
                          TextStyle(color: AppColors.warning, fontSize: 12.5),
                    ),
                  ),
                  TextButton(
                    onPressed: () => sikaNotifier
                        .executeActionReconciliation(sikaData.pendingActionId!),
                    child: const Text('Vérifier',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ).animate().fade().scale(),

          // MESSAGES
          Expanded(
            child: sikaData.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    itemCount:
                        sikaData.messages.length + (isProcessing ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isProcessing && index == sikaData.messages.length) {
                        return _buildTypingIndicator();
                      }
                      final message = sikaData.messages[index];
                      return _buildChatBubble(message)
                          .animate()
                          .fade(duration: 300.ms)
                          .slideX(begin: message.isUser ? 0.08 : -0.08, end: 0);
                    },
                  ),
          ),

          // INPUT BAR
          _buildInputBar(sikaData, sikaNotifier),
        ],
      ),
    );
  }

  Widget _buildThinkingDots() {
    return AnimatedBuilder(
      animation: _typingAnim,
      builder: (context, child) {
        return Row(
          children: List.generate(3, (i) {
            final delay = i * 0.25;
            final value = (_typingAnim.value + delay) % 1.0;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.brandSecondary.withValues(alpha: value),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16, right: 80),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceHighlight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(20),
          ),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThinkingDots(),
            const SizedBox(width: 8),
            const Text(
              'SIKA réfléchit',
              style: TextStyle(
                color: AppColors.darkTextSecondary,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ).animate().fade(duration: 300.ms);
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  colors: [
                    AppColors.brandPrimary.withValues(alpha: 0.25),
                    AppColors.brandPrimary.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                margin: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandPrimary.withValues(alpha: 0.4),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('✦',
                      style: TextStyle(fontSize: 26, color: Colors.white)),
                ),
              ),
            ).animate().fade(duration: 700.ms).scale(delay: 200.ms),
            const SizedBox(height: 28),
            Text(
              'Posez une question à SIKA',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.15, end: 0),
            const SizedBox(height: 12),
            Text(
              '« Puis-je dépenser 15 000 FCFA aujourd\'hui ? »',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.darkTextSecondary,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
            ).animate().fade(delay: 600.ms),
            const SizedBox(height: 32),
            // Quick prompts
            _buildQuickPrompt('💳  Mon solde disponible ?'),
            const SizedBox(height: 10),
            _buildQuickPrompt('📊  Mes dépenses ce mois ?'),
            const SizedBox(height: 10),
            _buildQuickPrompt('🎯  Progression de mon épargne ?'),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickPrompt(String text) {
    return GestureDetector(
      onTap: () {
        final sikaNotifier = ref.read(sikaProvider.notifier);
        sikaNotifier
            .sendTextMessage(text.replaceAll(RegExp(r'^[^\s]+\s*'), '').trim());
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.darkSurfaceHighlight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.darkTextSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    ).animate().fade(delay: 800.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildChatBubble(SikaMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isUser ? 60 : 0,
          right: isUser ? 0 : 60,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        decoration: BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isUser ? null : AppColors.darkSurfaceHighlight,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser
              ? null
              : Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            if (isUser)
              BoxShadow(
                color: AppColors.brandPrimary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isUser)
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text(
                      '✦ SIKA',
                      style: TextStyle(
                        color: AppColors.brandSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              message.text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser ? Colors.white : AppColors.darkTextPrimary,
                    height: 1.55,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(SikaData data, SikaNotifier notifier) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.darkSurface,
        border: Border(
          top: BorderSide(
              color: Colors.white.withValues(alpha: 0.06), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Bouton micro
          GestureDetector(
            onTap: () {
              if (data.state == SikaState.speaking) {
                notifier.stopSpeaking();
              } else {
                notifier.toggleListening();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (data.state == SikaState.listening ||
                        data.state == SikaState.speaking)
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.darkSurfaceHighlight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: (data.state == SikaState.listening)
                      ? AppColors.error.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Icon(
                data.state == SikaState.listening
                    ? Icons.mic_off_rounded
                    : (data.state == SikaState.speaking
                        ? Icons.stop_circle_outlined
                        : Icons.mic_rounded),
                color: (data.state == SikaState.listening ||
                        data.state == SikaState.speaking)
                    ? AppColors.error
                    : AppColors.darkTextSecondary,
                size: 20,
              ),
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.darkSurfaceHighlight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: TextField(
                controller: _textController,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.darkTextPrimary,
                    ),
                decoration: const InputDecoration(
                  hintText: 'Demande à SIKA...',
                  hintStyle:
                      TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onSubmitted: (_) => _handleSend(notifier),
                maxLines: 3,
                minLines: 1,
              ),
            ),
          ),

          const SizedBox(width: 10),

          GestureDetector(
            onTap: () => _handleSend(notifier),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF635BFF), Color(0xFF4F46E5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(Icons.north_rounded,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

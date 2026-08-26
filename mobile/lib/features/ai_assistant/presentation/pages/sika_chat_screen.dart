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
      if (next.state == SikaState.listening && next.currentText != null && next.currentText!.isNotEmpty) {
        if (previous?.currentText != next.currentText) {
          _textController.text = next.currentText!;
        }
      } else if (previous?.state == SikaState.listening && next.state != SikaState.listening) {
        if (next.currentText == null || next.currentText!.isEmpty) {
          _textController.clear();
        }
      }
    });

    final sikaData = ref.watch(sikaProvider);
    final sikaNotifier = ref.read(sikaProvider.notifier);

    _scrollToBottom();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: <Widget>[
            const CircleAvatar(
              backgroundColor: AppColors.brandPrimary,
              radius: 18,
              child: Text('🤖', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'SIKA Conversation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Agent Active & Contextual',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.70)),
            onPressed: () => sikaNotifier.clearConversation(),
            tooltip: 'Nouvelle conversation',
          ),
        ],
      ),
      body: Column(
        children: [
          // USER-FRIENDLY AGENT REASONING STATE BANNER
          if (sikaData.state == SikaState.processing)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.brandSecondary.withValues(alpha: 0.1),
                border: Border(bottom: BorderSide(color: AppColors.brandSecondary.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(AppColors.brandSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '✦ Analyzing your financial context...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.brandSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ).animate().fade().slideY(begin: -0.2, end: 0),

          // RECONCILIATION PROMPT BANNER (UNKNOWN_RESULT / REQUIRES_RECONCILIATION)
          if (sikaData.pendingActionId != null && sikaData.state == SikaState.error)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Statut incertain. Vérifiez l\'opération avant de réessayer.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      sikaNotifier.executeActionReconciliation(sikaData.pendingActionId!);
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Vérifier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.warning,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ),
            ).animate().fade().scale(),

          // MESSAGES LIST
          Expanded(
            child: sikaData.messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(20),
                    itemCount: sikaData.messages.length,
                    itemBuilder: (context, index) {
                      final message = sikaData.messages[index];
                      return _buildChatBubble(message).animate().fade().slideX(
                        begin: message.isUser ? 0.1 : -0.1, end: 0,
                      );
                    },
                  ),
          ),

          // INPUT BAR
          _buildInputBar(sikaData, sikaNotifier),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brandPrimary.withValues(alpha: 0.1),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Text('💬', style: TextStyle(fontSize: 48)),
            ).animate().fade(duration: 600.ms).scale(delay: 200.ms),
            const SizedBox(height: 24),
            Text(
              'Pose une question à SIKA',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ).animate().fade(delay: 400.ms).slideY(begin: 0.2, end: 0),
            const SizedBox(height: 12),
            Text(
              '« Est-ce que je peux dépenser 15 000 FCFA aujourd\'hui ? »',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            ).animate().fade(delay: 600.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildChatBubble(SikaMessage message) {
    final isUser = message.isUser;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.brandPrimary : Theme.of(context).cardColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          boxShadow: [
            if (!isUser)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Text(
          message.text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(SikaData data, SikaNotifier notifier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                data.state == SikaState.listening
                    ? Icons.mic_off
                    : (data.state == SikaState.speaking ? Icons.stop_circle_outlined : Icons.mic),
                color: (data.state == SikaState.listening || data.state == SikaState.speaking)
                    ? AppColors.error
                    : AppColors.brandPrimary,
              ),
              onPressed: () {
                if (data.state == SikaState.speaking) {
                  notifier.stopSpeaking();
                } else {
                  notifier.toggleListening();
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05)),
                ),
                child: TextField(
                  controller: _textController,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Demande à SIKA...',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 15),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    fillColor: Colors.transparent,
                  ),
                  onSubmitted: (_) => _handleSend(notifier),
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: () => _handleSend(notifier),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: AppColors.brandPrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

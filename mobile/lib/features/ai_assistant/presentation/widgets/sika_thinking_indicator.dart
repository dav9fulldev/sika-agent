import 'package:flutter/material.dart';
import 'agent_progress_widget.dart';

/// SikaThinkingIndicator — Backward-compatible wrapper delegating to AgentProgressWidget
class SikaThinkingIndicator extends StatelessWidget {
  /// Texte imposé ; sinon le texte suit la langue de l'app (voir AgentProgressWidget)
  final String? text;

  const SikaThinkingIndicator({super.key, this.text});

  @override
  Widget build(BuildContext context) {
    return AgentProgressWidget(
      isWorking: true,
      initialWorkingText: text,
    );
  }
}

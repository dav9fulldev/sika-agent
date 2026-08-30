import 'package:flutter/material.dart';
import 'agent_progress_widget.dart';

/// SikaThinkingIndicator — Backward-compatible wrapper delegating to AgentProgressWidget
class SikaThinkingIndicator extends StatelessWidget {
  final String text;

  const SikaThinkingIndicator({
    super.key,
    this.text = 'SIKA analyse votre demande...',
  });

  @override
  Widget build(BuildContext context) {
    return AgentProgressWidget(
      isWorking: true,
      initialWorkingText: text,
    );
  }
}

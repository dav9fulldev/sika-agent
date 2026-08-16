import 'package:flutter/material.dart';
import 'package:avatar_glow/avatar_glow.dart';
import '../../providers/sika_provider.dart';

class AgentOrbWidget extends StatelessWidget {
  final SikaState state;
  final VoidCallback onTap;

  const AgentOrbWidget({
    super.key,
    required this.state,
    required this.onTap,
  });

  Color _getOrbColor() {
    switch (state) {
      case SikaState.listening:
        return const Color(0xFF10B981); // Emerald / Teal glowing
      case SikaState.processing:
        return const Color(0xFF6366F1); // Indigo / Thinking
      case SikaState.speaking:
        return const Color(0xFF38BDF8); // Cyan
      case SikaState.error:
        return const Color(0xFFEF4444); // Red error
      case SikaState.idle:
        return const Color(0xFF3B82F6); // Soft Blue
    }
  }

  String _getStatusText() {
    switch (state) {
      case SikaState.listening:
        return 'Listening...';
      case SikaState.processing:
        return 'Analyzing your financial context...';
      case SikaState.speaking:
        return 'SIKA is responding...';
      case SikaState.error:
        return 'Connection issue';
      case SikaState.idle:
        return 'Tap to speak or say "Sika"';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orbColor = _getOrbColor();
    final isGlowing = state == SikaState.listening || state == SikaState.processing || state == SikaState.speaking;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: AvatarGlow(
            animate: isGlowing,
            glowColor: orbColor,
            duration: const Duration(milliseconds: 2000),
            repeat: true,
            child: Material(
              elevation: 8,
              shape: const CircleBorder(),
              color: Colors.transparent,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      orbColor.withValues(alpha: 0.85),
                      orbColor.withValues(alpha: 0.35),
                      const Color(0xFF1E293B),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.4),
                      blurRadius: 36,
                      spreadRadius: 6,
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      state == SikaState.listening
                          ? Icons.mic
                          : state == SikaState.processing
                              ? Icons.auto_awesome
                              : state == SikaState.speaking
                                  ? Icons.volume_up
                                  : Icons.mic_none_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            _getStatusText(),
            key: ValueKey(state),
            style: TextStyle(
              color: orbColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }
}

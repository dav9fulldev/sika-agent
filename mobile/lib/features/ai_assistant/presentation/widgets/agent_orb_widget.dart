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
        return const Color(0xFF3B82F6); // Electric Blue
      case SikaState.error:
        return const Color(0xFFEF4444); // Red error
      case SikaState.idle:
        return const Color(0xFF0EA5E9); // Cyan / Blue
    }
  }

  String _getOrbText() {
    switch (state) {
      case SikaState.listening:
        return '◉ Listening...';
      case SikaState.processing:
        return '✦ SIKA is analyzing...';
      case SikaState.speaking:
        return '🔊 SIKA is responding...';
      case SikaState.error:
        return '⚠️ Connection issue';
      case SikaState.idle:
        return '« Dis Sika... »';
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
              elevation: 12,
              shape: const CircleBorder(),
              color: Colors.transparent,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      orbColor.withValues(alpha: 0.9),
                      orbColor.withValues(alpha: 0.4),
                      const Color(0xFF0F172A),
                    ],
                    stops: const [0.3, 0.7, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: orbColor.withValues(alpha: 0.5),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    state == SikaState.listening
                        ? Icons.mic
                        : state == SikaState.processing
                            ? Icons.auto_awesome
                            : state == SikaState.speaking
                                ? Icons.volume_up
                                : Icons.graphic_eq,
                    size: 56,
                    color: Colors.white,
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
            _getOrbText(),
            key: ValueKey(state),
            style: TextStyle(
              color: orbColor,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

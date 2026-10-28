import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/language_provider.dart';
import '../../../../core/widgets/sika_pay_brand.dart';
import '../../providers/sika_provider.dart';

/// Panneau vocal. En conversation directe (Gemini Live), l'échange se fait de voix à voix : aucune transcription
/// à l'écran, seulement une sphère qui suit la voix de l'utilisateur puis celle de SIKA (le fil reste dans le chat).
/// Pas de bouton « envoyer » : l'utilisateur parle naturellement et peut couper SIKA en parlant. Quand SIKA prépare
/// un achat ou un abonnement, le panneau s'efface pour montrer la carte, qui porte la confirmation.
/// Hors conversation directe (dictée du téléphone), la transcription reste l'élément principal.
class SikaVoiceOverlayWidget extends ConsumerStatefulWidget {
  const SikaVoiceOverlayWidget({super.key});

  @override
  ConsumerState<SikaVoiceOverlayWidget> createState() => _SikaVoiceOverlayWidgetState();
}

class _SikaVoiceOverlayWidgetState extends ConsumerState<SikaVoiceOverlayWidget> with SingleTickerProviderStateMixin {
  static const _bars = 28;
  final List<double> _levels = List.filled(_bars, 0.04);
  late final AnimationController _ticker = AnimationController(vsync: this, duration: const Duration(milliseconds: 90))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        _pushLevel();
        _ticker.forward(from: 0);
      }
    })
    ..forward();
  final _rand = math.Random(7);
  int _tick = 0;

  /// Historique glissant : niveau réel du micro en écoute, enveloppe douce quand SIKA parle.
  void _pushLevel() {
    final data = ref.read(sikaProvider);
    double v;
    _tick++;
    if (data.state == SikaState.processing) {
      v = 0.18 + 0.12 * math.sin(_tick / 4);
    } else if (data.state == SikaState.listening) {
      v = 0.06 + data.soundLevel * 0.94;
    } else if (data.state == SikaState.speaking) {
      v = 0.25 + _rand.nextDouble() * 0.5;
    } else {
      v = 0.04;
    }
    setState(() {
      _levels.removeAt(0);
      _levels.add(v);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(sikaProvider);
    final sika = ref.read(sikaProvider.notifier);
    ref.watch(languageProvider);
    final lang = ref.read(languageProvider.notifier);

    if (!data.isVoiceMode) return const SizedBox.shrink();
    final lastSika = data.messages.where((m) => !m.isUser).toList();
    final lastHasCard = lastSika.isNotEmpty && lastSika.last.suggestedTransaction != null;
    final replyHasCard = data.voiceLive
        // En direct : la carte reste visible tant que l'utilisateur ne reprend pas la parole
        ? lastHasCard && data.state != SikaState.processing && (data.currentText ?? '').trim().isEmpty
        : lastHasCard && data.state != SikaState.listening && data.state != SikaState.processing;
    if (replyHasCard) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111A2E) : Colors.white;
    final ink = isDark ? Colors.white : SikaBrand.ink;
    final muted = isDark ? Colors.white60 : SikaBrand.muted;

    final (label, color) = switch (data.state) {
      SikaState.listening when data.micMuted => (lang.tr('Micro en pause', 'Microphone paused'), muted),
      SikaState.listening => (lang.tr('À l\'écoute', 'Listening'), SikaBrand.cyan),
      SikaState.processing => (lang.tr('SIKA réfléchit', 'SIKA is thinking'), SikaBrand.action),
      SikaState.speaking => (lang.tr('SIKA répond', 'SIKA is answering'), SikaBrand.action),
      SikaState.error => (lang.tr('Réessayez', 'Try again'), SikaBrand.danger),
      _ => (lang.tr('Prêt', 'Ready'), muted),
    };

    final userText = (data.currentText ?? '').trim();
    final reply = data.voiceLive ? (data.liveReply ?? '') : (lastSika.isNotEmpty ? lastSika.last.text : '');
    final String mainText;
    final bool placeholder;
    if (data.state == SikaState.error) {
      mainText = data.errorMessage ?? lang.tr("SIKA n'a pas pu vous entendre.", 'SIKA could not hear you.');
      placeholder = false;
    } else if (data.state == SikaState.speaking && reply.isNotEmpty) {
      mainText = reply;
      placeholder = false;
    } else if (userText.isNotEmpty) {
      mainText = userText;
      placeholder = false;
    } else if (data.voiceLive) {
      // Conversation naturelle : aucune consigne, seulement ce qui est dit
      mainText = '';
      placeholder = true;
    } else {
      mainText =
          lang.tr('Dites ce que vous voulez acheter, comparer ou payer.', 'Say what you want to buy, compare or pay.');
      placeholder = true;
    }

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.32),
        child: Column(children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _close(sika),
            ),
          ),
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(24, 14, 24, 24 + MediaQuery.of(context).padding.bottom),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 30, offset: const Offset(0, -6))
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration:
                        BoxDecoration(color: muted.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 18),
              Row(children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13.5, letterSpacing: 0.2)),
              ]),
              if (data.voiceLive) ...[
                SizedBox(
                  height: 220,
                  child: CustomPaint(size: Size.infinite, painter: _VoiceOrb(_levels.last, color: color)),
                ),
                const SizedBox(height: 8),
              ] else ...[
                const SizedBox(height: 14),
                ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 84, maxHeight: 220),
                  child: SingleChildScrollView(
                    reverse: true,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Text(
                        mainText,
                        key: ValueKey(placeholder ? 'p' : mainText.length ~/ 12),
                        style: TextStyle(
                          fontSize: data.state == SikaState.speaking ? 18 : 23,
                          height: 1.32,
                          fontWeight: placeholder ? FontWeight.w400 : FontWeight.w600,
                          color: placeholder ? muted : ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 44,
                  child: data.state == SikaState.processing
                      ? Center(
                          child: SizedBox(
                            width: 160,
                            child: LinearProgressIndicator(
                              minHeight: 3,
                              borderRadius: BorderRadius.circular(2),
                              color: SikaBrand.action,
                              backgroundColor: SikaBrand.action.withValues(alpha: 0.12),
                            ),
                          ),
                        )
                      : CustomPaint(size: Size.infinite, painter: _LevelBars(_levels, color: color)),
                ),
              ],
              const SizedBox(height: 18),
              _actions(data, sika, lang, ink, muted),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _close(SikaNotifier sika) async {
    if (ref.read(sikaProvider).voiceLive) {
      await sika.stopLiveVoice();
      return;
    }
    final state = ref.read(sikaProvider).state;
    if (state == SikaState.listening) await sika.cancelListening();
    if (state == SikaState.speaking) await sika.stopSpeaking(resetState: false);
    sika.exitVoiceMode();
  }

  Widget _actions(SikaData data, SikaNotifier sika, LanguageNotifier lang, Color ink, Color muted) {
    Widget textButton(String text, VoidCallback onTap) => TextButton(
          onPressed: onTap,
          child: Text(text, style: TextStyle(color: muted, fontWeight: FontWeight.w600, fontSize: 15)),
        );
    Widget round(IconData icon, String semantic, VoidCallback? onTap, {Color bg = SikaBrand.action}) => Semantics(
          button: true,
          label: semantic,
          child: Material(
            color: onTap == null ? bg.withValues(alpha: 0.35) : bg,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(width: 60, height: 60, child: Icon(icon, color: Colors.white, size: 26)),
            ),
          ),
        );

    final hasText = (data.currentText ?? '').trim().isNotEmpty;
    if (data.voiceLive) {
      return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        textButton(lang.tr('Terminer', 'End'), () => _close(sika)),
        switch (data.state) {
          SikaState.speaking => round(
              Icons.stop_rounded, lang.tr('Couper SIKA', 'Stop SIKA'), () => sika.stopSpeaking(),
              bg: SikaBrand.ink),
          SikaState.processing => round(Icons.more_horiz_rounded, lang.tr('En cours', 'Working'), null),
          _ => data.micMuted
              ? round(Icons.mic_off_rounded, lang.tr('Reprendre le micro', 'Unmute'), sika.toggleMicMuted,
                  bg: SikaBrand.muted)
              : round(Icons.mic_rounded, lang.tr('Mettre le micro en pause', 'Mute'), sika.toggleMicMuted),
        },
        const SizedBox(width: 64),
      ]);
    }
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      textButton(lang.tr('Fermer', 'Close'), () => _close(sika)),
      switch (data.state) {
        SikaState.listening =>
          round(Icons.arrow_upward_rounded, lang.tr('Envoyer', 'Send'), hasText ? sika.stopListening : null),
        SikaState.processing => round(Icons.more_horiz_rounded, lang.tr('En cours', 'Working'), null),
        SikaState.speaking => round(
            Icons.stop_rounded, lang.tr('Arrêter', 'Stop'), () => sika.stopSpeaking(resetState: true),
            bg: SikaBrand.ink),
        _ => round(Icons.mic_rounded, lang.tr('Parler', 'Talk'), () => sika.startVoice()),
      },
      const SizedBox(width: 64),
    ]);
  }
}

/// Barres de niveau symétriques, arrondies, les plus récentes à droite.
class _LevelBars extends CustomPainter {
  final List<double> levels;
  final Color color;
  _LevelBars(this.levels, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final n = levels.length;
    final gap = size.width / n;
    final w = math.min(4.0, gap * 0.55);
    final mid = size.height / 2;
    for (var i = 0; i < n; i++) {
      final h = math.max(4.0, levels[i] * size.height);
      final paint = Paint()..color = color.withValues(alpha: 0.35 + 0.65 * (i / n));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(gap * (i + 0.5), mid), width: w, height: h), Radius.circular(w)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LevelBars old) => true;
}

/// Sphère vocale : son rayon et son halo suivent le niveau de la voix (utilisateur ou SIKA).
class _VoiceOrb extends CustomPainter {
  final double level;
  final Color color;
  _VoiceOrb(this.level, {required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = math.min(size.width, size.height) * 0.26;
    final r = base * (1 + level.clamp(0.0, 1.0) * 0.35);
    for (var i = 3; i >= 1; i--) {
      canvas.drawCircle(
          center, r + i * 14 * (0.4 + level), Paint()..color = color.withValues(alpha: 0.06 + 0.05 * (3 - i)));
    }
    final rect = Rect.fromCircle(center: center, radius: r);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.3, -0.35),
          colors: [Color.lerp(color, Colors.white, 0.45)!, color, SikaBrand.royal],
          stops: const [0, 0.6, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _VoiceOrb old) => old.level != level || old.color != color;
}

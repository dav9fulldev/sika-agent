import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_pcm_sound/flutter_pcm_sound.dart';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';

/// Événement de la conversation vocale envoyé par le backend (transcriptions, étapes, cartes).
typedef LiveVoiceEvent = Map<String, dynamic>;

/// Conversation vocale en langage naturel avec SIKA (Gemini Live via le backend).
///
/// Le micro part en continu en PCM 16 kHz ; la voix de SIKA revient en PCM 24 kHz et est jouée au fil de l'eau.
/// La détection de fin de parole et les interruptions sont gérées par le modèle : l'utilisateur parle
/// naturellement, sans bouton « envoyer ». L'annulation d'écho du téléphone évite que SIKA s'entende.
class SikaLiveVoice {
  static const _inputRate = 16000;
  static const _outputRate = 24000;

  final void Function(LiveVoiceEvent event) onEvent;
  final void Function(double level) onMicLevel;
  final void Function(bool playing) onPlayback;

  SikaLiveVoice({required this.onEvent, required this.onMicLevel, required this.onPlayback});

  final AudioRecorder _recorder = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription<Uint8List>? _micSub;
  StreamSubscription? _wsSub;
  bool _playing = false;
  bool _muted = false;
  bool _closed = false;

  bool get isOpen => _channel != null && !_closed;

  static Uri socketUri() {
    final base = Uri.parse(AppConfig.baseUrl);
    return base.replace(scheme: base.scheme == 'https' ? 'wss' : 'ws', path: '/api/v1/sika/voice/live');
  }

  /// Ouvre la conversation. Lève une exception si le micro est refusé ou si le serveur ne répond pas.
  Future<void> start({required String token, required String lang, required String firstname}) async {
    if (!await _recorder.hasPermission()) {
      throw const LiveVoiceException('MIC_PERMISSION');
    }
    _closed = false;
    final channel = WebSocketChannel.connect(socketUri());
    _channel = channel;
    await channel.ready.timeout(const Duration(seconds: 10));
    // Jeton dans le premier message, jamais dans l'URL (journaux)
    channel.sink.add(jsonEncode({'type': 'start', 'token': token, 'lang': lang, 'firstname': firstname}));

    final ready = Completer<void>();
    _wsSub = channel.stream.listen(
      (data) {
        if (data is List<int>) {
          _play(Uint8List.fromList(data));
          return;
        }
        final event = Map<String, dynamic>.from(jsonDecode(data as String) as Map);
        if (event['type'] == 'ready' && !ready.isCompleted) {
          ready.complete();
          return;
        }
        if (event['type'] == 'error' && !ready.isCompleted) {
          ready.completeError(LiveVoiceException(event['code']?.toString() ?? 'VOICE_UNAVAILABLE'));
          return;
        }
        if (event['type'] == 'interrupted') _flushPlayback();
        onEvent(event);
      },
      onError: (e) {
        if (!ready.isCompleted) ready.completeError(const LiveVoiceException('VOICE_UNAVAILABLE'));
        _closedByServer();
      },
      onDone: () {
        if (!ready.isCompleted) ready.completeError(const LiveVoiceException('VOICE_UNAVAILABLE'));
        _closedByServer();
      },
    );
    await ready.future.timeout(const Duration(seconds: 15));

    await FlutterPcmSound.setLogLevel(LogLevel.none);
    await FlutterPcmSound.setup(sampleRate: _outputRate, channelCount: 1);
    await FlutterPcmSound.setFeedThreshold(_outputRate ~/ 10);
    FlutterPcmSound.setFeedCallback((remaining) {
      if (remaining == 0 && _playing) {
        _playing = false;
        onPlayback(false);
      }
    });

    final mic = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: _inputRate,
      numChannels: 1,
      echoCancel: true,
      noiseSuppress: true,
      autoGain: true,
      androidConfig: AndroidRecordConfig(
        audioSource: AndroidAudioSource.voiceCommunication,
        audioManagerMode: AudioManagerMode.modeInCommunication,
        speakerphone: true,
      ),
    ));
    _micSub = mic.listen((chunk) {
      if (_closed) return;
      onMicLevel(_muted ? 0 : _rms(chunk));
      // En pause, on envoie du silence : le modèle garde la session sans entendre la pièce
      _channel?.sink.add(_muted ? Uint8List(chunk.length) : chunk);
    });
  }

  /// Coupe le micro sans fermer la conversation.
  void setMuted(bool muted) => _muted = muted;
  bool get muted => _muted;

  /// Coupe SIKA pendant qu'elle parle (le modèle s'arrête aussi s'il entend l'utilisateur).
  Future<void> interrupt() => _flushPlayback();

  Future<void> stop() async {
    if (_closed) return;
    _closed = true;
    try {
      _channel?.sink.add(jsonEncode({'type': 'stop'}));
    } catch (_) {}
    await _micSub?.cancel();
    _micSub = null;
    try {
      await _recorder.stop();
    } catch (_) {}
    await _wsSub?.cancel();
    _wsSub = null;
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;
    await _flushPlayback();
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
  }

  void _closedByServer() {
    if (_closed) return;
    onEvent({'type': 'closed'});
    stop();
  }

  void _play(Uint8List pcm) {
    if (_closed || pcm.isEmpty) return;
    if (!_playing) {
      _playing = true;
      onPlayback(true);
    }
    FlutterPcmSound.feed(PcmArrayInt16(bytes: ByteData.sublistView(pcm)));
  }

  /// Vide la file audio : seul moyen fiable avec AudioTrack est de recréer le lecteur.
  Future<void> _flushPlayback() async {
    if (_playing) {
      _playing = false;
      onPlayback(false);
    }
    try {
      await FlutterPcmSound.release();
      if (!_closed) {
        await FlutterPcmSound.setup(sampleRate: _outputRate, channelCount: 1);
        await FlutterPcmSound.setFeedThreshold(_outputRate ~/ 10);
      }
    } catch (e) {
      debugPrint('[SIKA LIVE] Playback reset failed: $e');
    }
  }

  /// Niveau du micro entre 0 et 1 (RMS, échelle perceptive).
  static double _rms(Uint8List chunk) {
    final samples = ByteData.sublistView(chunk);
    final n = chunk.length ~/ 2;
    if (n == 0) return 0;
    double sum = 0;
    for (var i = 0; i < n; i++) {
      final s = samples.getInt16(i * 2, Endian.little) / 32768.0;
      sum += s * s;
    }
    final rms = math.sqrt(sum / n);
    return (math.log(1 + rms * 60) / math.log(61)).clamp(0.0, 1.0);
  }
}

class LiveVoiceException implements Exception {
  final String code;
  const LiveVoiceException(this.code);

  @override
  String toString() => 'LiveVoiceException($code)';
}

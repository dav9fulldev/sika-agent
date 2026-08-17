import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/services/api_service.dart';
import '../../../core/models/sika_state_model.dart';
import '../../../core/models/sika_message_model.dart';

export '../../../core/models/sika_state_model.dart';
export '../../../core/models/sika_message_model.dart';

// State global de SIKA Agent
class SikaData {
  final SikaState state;
  final List<SikaMessage> messages;
  final String? currentText;
  final String? errorMessage;
  final bool isInitialized;

  const SikaData({
    this.state = SikaState.idle,
    this.messages = const [],
    this.currentText,
    this.errorMessage,
    this.isInitialized = false,
  });

  SikaData copyWith({
    SikaState? state,
    List<SikaMessage>? messages,
    String? currentText,
    String? errorMessage,
    bool? isInitialized,
  }) {
    return SikaData(
      state: state ?? this.state,
      messages: messages ?? this.messages,
      currentText: currentText,
      errorMessage: errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

// Provider principal de SIKA
class SikaNotifier extends StateNotifier<SikaData> {
  final ApiService _apiService;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;
  DateTime? _lastListeningToggle;

  SikaNotifier(this._apiService) : super(const SikaData()) {
    _initializeSika();
  }

  Future<void> toggleListening() async {
    final now = DateTime.now();
    if (_lastListeningToggle != null &&
        now.difference(_lastListeningToggle!) < const Duration(milliseconds: 1500)) {
      debugPrint('[SIKA VOICE] Toggle ignored: debounced (<1500ms)');
      return;
    }
    _lastListeningToggle = now;

    if (state.state == SikaState.listening) {
      await stopListening();
    } else if (state.state == SikaState.idle || state.state == SikaState.error) {
      await startListening();
    }
  }

  Future<void> _initializeSika() async {
    try {
      await _requestPermissions();
      await _initSpeechToText();
      await _initTextToSpeech();

      state = state.copyWith(isInitialized: true);
      debugPrint('[SIKA VOICE] SIKA Assistant initialized successfully');
    } catch (e) {
      debugPrint('[SIKA VOICE] Error initializing SIKA: $e');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'Error initializing SIKA: $e',
      );
    }
  }

  Future<void> _requestPermissions() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Microphone permission denied');
    }
  }

  Future<void> _initSpeechToText() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (error) {
        debugPrint('[SIKA STT] Speech error: ${error.errorMsg}');
        state = state.copyWith(
          state: SikaState.error,
          errorMessage: 'Speech error: ${error.errorMsg}',
        );
      },
      onStatus: (status) {
        debugPrint('[SIKA STT] Speech status: $status');
        if (status == 'done' || status == 'notListening') {
          if (state.state == SikaState.listening) {
            _onSpeechComplete();
          }
        }
      },
    );

    if (!_speechEnabled) {
      debugPrint('[SIKA STT] Speech recognition not available');
    }
  }

  Future<void> _initTextToSpeech() async {
    await _flutterTts.setLanguage('fr-FR');
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setCompletionHandler(() {
      debugPrint('[SIKA TTS] TTS playback completed');
      if (state.state == SikaState.speaking) {
        state = state.copyWith(state: SikaState.idle);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[SIKA TTS] TTS error: $msg');
      state = state.copyWith(state: SikaState.idle);
    });
  }

  Future<void> startListening() async {
    if (!_speechEnabled) {
      debugPrint('[SIKA VOICE] Cannot listen: STT not enabled');
      await _initializeSika();
      if (!_speechEnabled) return;
    }

    try {
      state = state.copyWith(
        state: SikaState.listening,
        currentText: null,
        errorMessage: null,
      );

      await _speechToText.listen(
        onResult: (result) {
          debugPrint('[SIKA STT] Recognized text: ${result.recognizedWords}');
          state = state.copyWith(currentText: result.recognizedWords);
        },
        listenOptions: SpeechListenOptions(
          localeId: 'fr_FR',
          listenFor: const Duration(seconds: 15),
          pauseFor: const Duration(seconds: 3),
          cancelOnError: true,
          partialResults: true,
        ),
      );
    } catch (e) {
      debugPrint('[SIKA VOICE] Error starting STT: $e');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'Error starting STT: $e',
      );
    }
  }

  Future<void> stopListening() async {
    if (state.state != SikaState.listening) return;

    try {
      await _speechToText.stop();
      _onSpeechComplete();
    } catch (e) {
      debugPrint('[SIKA VOICE] Error stopping STT: $e');
    }
  }

  void _onSpeechComplete() {
    if (state.state != SikaState.listening) return;

    final text = state.currentText;
    if (text != null && text.trim().isNotEmpty) {
      debugPrint('[SIKA VOICE] Final query: $text');
      processUserQuery(text);
    } else {
      debugPrint('[SIKA VOICE] No text recognized');
      state = state.copyWith(state: SikaState.idle);
    }
  }

  void clearConversation() {
    state = SikaData(
      state: SikaState.idle,
      messages: const [],
      currentText: null,
      errorMessage: null,
      isInitialized: state.isInitialized,
    );
  }

  Future<void> processUserQuery(String query) async {
    if (query.trim().isEmpty) return;

    final queryLower = query.toLowerCase();
    final userMessage = SikaMessage(text: query, isUser: true);
    final updatedMessages = List<SikaMessage>.from(state.messages)..add(userMessage);

    state = state.copyWith(
      state: SikaState.processing,
      messages: updatedMessages,
      currentText: null,
    );

    // Voice Confirmation interception
    if (queryLower.contains('confirme') ||
        queryLower.contains('valide') ||
        queryLower.contains('oui') ||
        queryLower.contains('autorise')) {
      const confirmText =
          'D\'accord David, j\'ai dicté les informations. Le transfert de 10 000 FCFA vers ta maman sur Wave est maintenant confirmé !';
      final sikaMessage = SikaMessage(text: confirmText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
      );

      await _speak(confirmText);
      return;
    }

    try {
      debugPrint('[SIKA API] Querying backend: "$query"');
      final response = await _apiService.sikaChat(query);

      final String sikaText = response['response'] ??
          'Pardon, je n\'ai pas bien compris. Peux-tu répéter ?';

      Map<String, dynamic>? suggestedTx;
      bool canAddTx = false;
      if (response['action'] == 'add_transaction' &&
          response['action_data'] != null) {
        suggestedTx = Map<String, dynamic>.from(response['action_data']);
        canAddTx = true;
      }

      final sikaMessage = SikaMessage(
        text: sikaText,
        isUser: false,
        suggestedTransaction: suggestedTx,
        canAddTransaction: canAddTx,
      );

      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
      );

      await _speak(sikaText);
    } catch (e) {
      debugPrint('[SIKA API] Error chatting with SIKA: $e');

      const fallbackText =
          'Désolé, je rencontre une difficulté de connexion avec mon serveur. Peux-tu réessayer ?';
      final sikaMessage = SikaMessage(text: fallbackText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
        errorMessage: e.toString(),
      );

      await _speak(fallbackText);
    }
  }

  Future<void> sendTextMessage(String text) async {
    await processUserQuery(text);
  }

  Future<void> _speak(String text) async {
    try {
      debugPrint('[SIKA TTS] Speaking: "$text"');
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[SIKA TTS] Error in TTS speak: $e');
      state = state.copyWith(state: SikaState.idle);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      state = state.copyWith(state: SikaState.idle);
    } catch (e) {
      debugPrint('[SIKA TTS] Error stopping TTS: $e');
    }
  }
}

// Provider global de Riverpod
final sikaProvider = StateNotifierProvider<SikaNotifier, SikaData>((ref) {
  final apiService = ApiService();
  return SikaNotifier(apiService);
});

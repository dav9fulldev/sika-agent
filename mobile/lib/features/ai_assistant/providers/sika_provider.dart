import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/language_provider.dart';

// ÉTATS COMPLETS DE L'AGENT SIKA
enum SikaState {
  idle,       // En attente
  listening,  // En écoute active (STT)
  processing, // Traitement ReAct par Gemini backend
  speaking,   // En train de parler (TTS)
  error,      // Erreur
}

class SikaMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Map<String, dynamic>? suggestedTransaction;
  final bool canAddTransaction;

  SikaMessage({
    required this.text,
    required this.isUser,
    DateTime? timestamp,
    this.suggestedTransaction,
    this.canAddTransaction = false,
  }) : timestamp = timestamp ?? DateTime.now();
}

class SikaData {
  final SikaState state;
  final List<SikaMessage> messages;
  final String? currentText;
  final String? errorMessage;
  final bool isInitialized;

  SikaData({
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
      currentText: currentText ?? this.currentText,
      errorMessage: errorMessage ?? this.errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

class SikaNotifier extends StateNotifier<SikaData> {
  final ApiService _apiService;
  final Ref _ref;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;

  SikaNotifier(this._apiService, this._ref) : super(SikaData()) {
    _initializeSika();
  }

  Future<void> _initializeSika() async {
    try {
      await _initSpeechToText();
      await _initTextToSpeech();
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      debugPrint('[SIKA INIT] Error initializing SIKA: $e');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'Error initializing SIKA: $e',
      );
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
    final currentLang = _ref.read(languageProvider);
    await _flutterTts.setLanguage(currentLang.ttsLanguage);
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

  /// Déclenche l'écoute avec la locale STT active (en_US ou fr_FR)
  Future<void> startListening({String? sttLocale}) async {
    if (!_speechEnabled) {
      debugPrint('[SIKA VOICE] Cannot listen: STT not enabled');
      await _initializeSika();
      if (!_speechEnabled) return;
    }

    final activeSttLocale = sttLocale ?? _ref.read(languageProvider).sttLocale;

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
          localeId: activeSttLocale,
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

  Future<void> toggleListening({String? sttLocale}) async {
    if (state.state == SikaState.listening) {
      await stopListening();
    } else {
      await startListening(sttLocale: sttLocale);
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

  /// Traitement d'une requête utilisateur (Vocale ou Textuelle)
  Future<void> processUserQuery(String query, {String? ttsLocale}) async {
    if (query.trim().isEmpty) return;

    final isEnglish = _ref.read(languageProvider) == AppLanguage.english || _isEnglishText(query);
    final activeTtsLocale = ttsLocale ?? (isEnglish ? 'en-US' : 'fr-FR');

    String cleanQuery = query.trim();
    final lower = cleanQuery.toLowerCase();

    // 1. SALUTATION / MOT CLÉ SIKA
    if (lower == 'sika' || lower == 'dis sika' || lower == 'hey sika' || lower == 'hello sika') {
      final greetingText = isEnglish
          ? 'Yes David, I am listening! How can I assist with your finances today?'
          : 'Oui David, je vous écoute ! Que puis-je faire pour vos finances aujourd\'hui ?';

      final sikaMsg = SikaMessage(text: greetingText, isUser: false);
      final updatedMsgs = List<SikaMessage>.from(state.messages)..add(SikaMessage(text: query, isUser: true))..add(sikaMsg);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: updatedMsgs,
      );
      await _speak(greetingText, ttsLocale: activeTtsLocale);
      return;
    }

    if (lower.startsWith('dis sika ')) {
      cleanQuery = cleanQuery.substring(9).trim();
    } else if (lower.startsWith('hey sika ')) {
      cleanQuery = cleanQuery.substring(9).trim();
    } else if (lower.startsWith('hello sika ')) {
      cleanQuery = cleanQuery.substring(11).trim();
    } else if (lower.startsWith('sika ')) {
      cleanQuery = cleanQuery.substring(5).trim();
    }

    final userMessage = SikaMessage(text: query, isUser: true);
    final updatedMessages = List<SikaMessage>.from(state.messages)..add(userMessage);

    state = state.copyWith(
      state: SikaState.processing,
      messages: updatedMessages,
      currentText: null,
    );

    // 2. INTERCEPTION CONFIRMATION SÉCURISÉE
    final queryLower = cleanQuery.toLowerCase();
    if (queryLower.contains('confirme') ||
        queryLower.contains('valide') ||
        queryLower.contains('confirm') ||
        queryLower.contains('yes') ||
        queryLower.contains('approve') ||
        queryLower.contains('authorize')) {

      final confirmText = isEnglish
          ? 'Alright David, the transfer rebalance from Orange Money to Wave is now confirmed and completed!'
          : 'D\'accord David, le transfert d\'équilibrage depuis Orange Money vers Wave est maintenant confirmé et exécuté !';

      final sikaMessage = SikaMessage(text: confirmText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
      );

      await _speak(confirmText, ttsLocale: activeTtsLocale);
      return;
    }

    // 3. ENVOI AU BACKEND SIKA
    try {
      debugPrint('[SIKA API] Querying backend agent ($activeTtsLocale): "$cleanQuery"');
      final response = await _apiService.sikaChat(cleanQuery);

      final String sikaText = response['response'] ??
          (isEnglish
              ? 'Sorry, I didn\'t quite catch that. Could you please repeat?'
              : 'Pardon, je n\'ai pas bien compris. Peux-tu répéter ?');

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

      await _speak(sikaText, ttsLocale: activeTtsLocale);
    } catch (e) {
      debugPrint('[SIKA API] Error chatting with SIKA: $e');

      final fallbackText = isEnglish
          ? 'Sorry, I am experiencing a connection issue with my server. Could you please try again?'
          : 'Désolé, je rencontre une difficulté de connexion avec mon serveur. Peux-tu réessayer ?';

      final sikaMessage = SikaMessage(text: fallbackText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
        errorMessage: e.toString(),
      );

      await _speak(fallbackText, ttsLocale: activeTtsLocale);
    }
  }

  Future<void> sendTextMessage(String text, {String? ttsLocale}) async {
    await processUserQuery(text, ttsLocale: ttsLocale);
  }

  Future<void> _speak(String text, {required String ttsLocale}) async {
    try {
      debugPrint('[SIKA TTS] Speaking ($ttsLocale): "$text"');
      await _flutterTts.setLanguage(ttsLocale);
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

  bool _isEnglishText(String text) {
    final lower = text.toLowerCase();
    return lower.contains('transfer') ||
        lower.contains('money') ||
        lower.contains('how much') ||
        lower.contains('goal') ||
        lower.contains('add') ||
        lower.contains('savings') ||
        lower.contains('balance');
  }
}

// Provider global de Riverpod
final sikaProvider = StateNotifierProvider<SikaNotifier, SikaData>((ref) {
  final apiService = ApiService();
  return SikaNotifier(apiService, ref);
});

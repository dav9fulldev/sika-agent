import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/api_service.dart';

enum SikaState { idle, listening, processing, speaking, error }

class SikaMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? suggestedTransaction;
  final bool canAddTransaction;

  SikaMessage({
    required this.text,
    required this.isUser,
    this.suggestedTransaction,
    this.canAddTransaction = false,
  });
}

class SikaData {
  final SikaState state;
  final List<SikaMessage> messages;
  final String? currentText;
  final String? errorMessage;
  final bool isInitialized;

  SikaData({
    required this.state,
    required this.messages,
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

  SikaNotifier(this._apiService, this._ref)
      : super(SikaData(
          state: SikaState.idle,
          messages: const [],
          isInitialized: false,
        )) {
    _initializeSika();
  }

  Future<void> _initializeSika() async {
    try {
      await _initSpeechToText();
      await _initTextToSpeech();
      state = state.copyWith(isInitialized: true);
    } catch (e) {
      debugPrint('[SIKA INIT] Error initializing SIKA services: $e');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'Failed to initialize SIKA: $e',
        isInitialized: false,
      );
    }
  }

  Future<void> _initSpeechToText() async {
    _speechEnabled = await _speechToText.initialize(
      onError: (val) {
        debugPrint('[SIKA STT] Speech error: ${val.errorMsg}');
        state = state.copyWith(
          state: SikaState.error,
          errorMessage: val.errorMsg,
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

  /// Traitement d'une requête utilisateur (Vocale ou Textuelle) avec reconnaissance de l'utilisateur et de sa devise active
  Future<void> processUserQuery(String query, {String? ttsLocale}) async {
    if (query.trim().isEmpty) return;

    final isEnglish = _isEnglishText(query);
    final activeTtsLocale = ttsLocale ?? (isEnglish ? 'en-US' : 'fr-FR');

    // Récupération dynamique du prénom de l'utilisateur connecté
    final authState = _ref.read(authProvider);
    final rawName = authState.user?.name ?? 'David';
    final userFirstName = rawName.trim().isNotEmpty ? rawName.trim().split(' ').first : 'David';

    // Récupération dynamique de la devise active de l'utilisateur
    final activeCurrency = _ref.read(currencyProvider);
    final currencyCode = activeCurrency.code;
    final currencySymbol = activeCurrency.symbol;

    String cleanQuery = query.trim();
    final lower = cleanQuery.toLowerCase();

    // 1. SALUTATION / MOT CLÉ SIKA
    if (lower == 'sika' || lower == 'dis sika' || lower == 'hey sika' || lower == 'hello sika') {
      final greetingText = isEnglish
          ? 'Yes $userFirstName, I am listening! How can I assist with your finances today?'
          : 'Oui $userFirstName, je vous écoute ! Que puis-je faire pour vos finances aujourd\'hui ?';

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
          ? 'Alright $userFirstName, the transfer rebalance from Orange Money to Wave is now confirmed and completed!'
          : 'D\'accord $userFirstName, le transfert d\'équilibrage depuis Orange Money vers Wave est maintenant confirmé et exécuté !';

      final sikaMessage = SikaMessage(text: confirmText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
      );

      await _speak(confirmText, ttsLocale: activeTtsLocale);
      return;
    }

    // 3. ENVOI AU BACKEND SIKA AVEC PRÉNOM ET DEVISE ACTIVE
    try {
      debugPrint('[SIKA API] Querying backend agent ($userFirstName, $currencyCode, $activeTtsLocale): "$cleanQuery"');
      final response = await _apiService.sikaChat(
        cleanQuery,
        userFirstName: userFirstName,
        currencyCode: currencyCode,
        currencySymbol: currencySymbol,
      );

      final String sikaText = (response['message'] as String?) ??
          (response['response'] as String?) ??
          (isEnglish
              ? 'Sorry $userFirstName, I didn\'t quite catch that. Could you please repeat?'
              : 'Pardon $userFirstName, je n\'ai pas bien compris. Peux-tu répéter ?');

      final action = response['intent'] ?? response['action'];

      Map<String, dynamic>? suggestedTx;
      bool canAddTx = false;
      if (action == 'add_transaction' &&
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

      final String? audioB64 = response['audio_base64'] as String?;
      await _speak(sikaText, ttsLocale: activeTtsLocale, audioBase64: audioB64);
    } catch (e) {
      debugPrint('[SIKA API] Error chatting with SIKA: $e');

      final fallbackText = isEnglish
          ? 'Sorry $userFirstName, I am experiencing a connection issue with my server. Could you please try again?'
          : 'Désolé $userFirstName, je rencontre une difficulté de connexion avec mon serveur. Peux-tu réessayer ?';

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

  final AudioPlayer _audioPlayer = AudioPlayer();

  Future<void> _speak(String text, {required String ttsLocale, String? audioBase64}) async {
    try {
      debugPrint('[SIKA TTS] Preparing speech output ($ttsLocale)');
      String? b64 = audioBase64;

      // 1. Si aucun audio base64 n'est fourni, tenter la génération GCP TTS via le backend SIKA
      if (b64 == null || b64.isEmpty) {
        try {
          final ttsRes = await _apiService.fetchGcpTtsAudio(text);
          if (ttsRes['success'] == true && ttsRes['audio_base64'] != null) {
            b64 = ttsRes['audio_base64'] as String;
          }
        } catch (e) {
          debugPrint('[GCP TTS] Impossible d\'obtenir l\'audio du backend: $e. Basculement sur flutter_tts.');
        }
      }

      // 2. MOTEUR PRINCIPAL : Lecture de l'audio MP3 haute-fidélité Google Cloud Text-to-Speech
      if (b64 != null && b64.isNotEmpty) {
        debugPrint('[GCP TTS] 🔊 Lecture de l\'audio MP3 Google Cloud Text-to-Speech (Taille: ${b64.length} caractères)');
        final bytes = base64Decode(b64);
        await _audioPlayer.stop();
        await _audioPlayer.play(BytesSource(bytes));

        _audioPlayer.onPlayerComplete.first.then((_) {
          if (state.state == SikaState.speaking) {
            state = state.copyWith(state: SikaState.idle);
          }
        });
        return; // UN SEUL MOTEUR AUDIO EXÉCUTÉ - AUCUN DOUBLON
      }

      // 3. STRATÉGIE DE FALLBACK : Utilisation de flutter_tts si GCP TTS est indisponible
      debugPrint('[FLUTTER TTS FALLBACK] 🔊 Élocution via la synthèse vocale locale du téléphone');
      await _flutterTts.setLanguage(ttsLocale);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[SIKA TTS] Error in TTS speak: $e');
      state = state.copyWith(state: SikaState.idle);
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      state = state.copyWith(state: SikaState.idle);
    } catch (e) {
      debugPrint('[SIKA TTS] Error stopping TTS: $e');
    }
  }

  bool _isEnglishText(String text) {
    final lower = text.toLowerCase();

    final frenchIndicators = [
      'bonjour', 'salut', 'coucou', 'bonsoir', 'comment', 'vas', 'va', 'ça va', 'ca va',
      'solde', 'combien', 'portefeuille', 'dépense', 'depense', 'épargne', 'epargne',
      'transfert', 'transférer', 'argent', 'merci', 'oui', 'non', 'je', 'tu', 'moi', 'toi',
      'suis', 'vais', 'bien', 'comment tu vas'
    ];
    final englishIndicators = [
      'hello', 'hi', 'hey', 'how are you', 'say hello', 'good morning', 'thanks', 'thank',
      'how much', 'money', 'total', 'balance', 'transfer', 'rebalance',
      'save', 'savings', 'add', 'goal', 'how is my', 'what is my',
      'analyze', 'recent', 'expenses', 'spend', 'wallet', 'dollars', 'usd',
      'are you okay', 'are you fine', 'are you good', 'you okay', 'doing', 'okay', 'ok'
    ];

    int frCount = 0;
    for (final kw in frenchIndicators) {
      if (lower.contains(kw)) frCount++;
    }

    int enCount = 0;
    for (final kw in englishIndicators) {
      if (lower.contains(kw)) enCount++;
    }

    if (frCount > enCount) return false;
    if (enCount > frCount) return true;

    return _ref.read(languageProvider) == AppLanguage.english;
  }
}

// Provider global de Riverpod
final sikaProvider = StateNotifierProvider<SikaNotifier, SikaData>((ref) {
  final apiService = ApiService();
  return SikaNotifier(apiService, ref);
});

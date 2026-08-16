import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../data/services/api_service.dart';


// État de Sika
/// Différents états possibles pour l'assistant Sika.
/// Guide l'UI pour afficher l'animation appropriée (écoute, traitement, parole).
enum SikaState {
  idle, // En attente : prêt à être activé
  listening, // Écoute en cours : capture de la voix de l'utilisateur
  processing, // Traitement : appel à l'API IA
  speaking, // Sika parle : restitution vocale de la réponse
  error, // Erreur : problème réseau ou vocal
}

// Message dans la conversation
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

// État global de Sika
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

// Provider principal de Sika
/// Cerveau de l'assistant Sika côté Frontend.
/// Orchestre la reconnaissance vocale (STT) et la synthèse vocale (TTS).
class SikaNotifier extends StateNotifier<SikaData> {
  final ApiService _apiService;
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;
  DateTime? _lastListeningToggle;

  SikaNotifier(this._apiService) : super(const SikaData()) {
    _initializeSika();
  }

  /// Bascule de manière atomique l'état d'écoute avec garde anti-rebond de 1500 ms
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
      debugPrint('[SIKA STT] initialize started');

      // Vérification permission micro
      var micStatus = await Permission.microphone.status;
      debugPrint('[SIKA VOICE] Permission microphone = $micStatus');
      if (!micStatus.isGranted) {
        micStatus = await Permission.microphone.request();
        debugPrint('[SIKA VOICE] Permission requested result = $micStatus');
      }
      debugPrint('[SIKA VOICE] Permission granted = ${micStatus.isGranted}');

      // Initialiser Speech-to-Text
      _speechEnabled = await _speechToText.initialize(
        onError: (error) {
          debugPrint('[SIKA STT] error = $error');
          if (state.state == SikaState.listening) {
            if (state.currentText != null && state.currentText!.trim().isNotEmpty) {
              _processQuery(state.currentText!);
            } else {
              debugPrint('[SIKA STT] STT error on emulator (no speech captured): ${error.errorMsg}');
              state = state.copyWith(
                state: SikaState.idle,
                errorMessage: 'Aucun son capturé. Tapez votre message ou vérifiez le micro.',
              );
            }
          }
        },
        onStatus: (status) {
          debugPrint('[SIKA STT] status = $status');
          if (status == 'done' || status == 'notListening') {
            if (state.state == SikaState.listening) {
              if (state.currentText != null && state.currentText!.trim().isNotEmpty) {
                _processQuery(state.currentText!);
              } else {
                state = state.copyWith(state: SikaState.idle);
              }
            }
          }
        },
      );

      debugPrint('[SIKA STT] initialize result = $_speechEnabled');

      if (_speechEnabled) {
        final sysLoc = await _speechToText.systemLocale();
        debugPrint('[SIKA STT] systemLocale = ${sysLoc?.localeId}');
        final locs = await _speechToText.locales();
        debugPrint('[SIKA STT] available locales count = ${locs.length}');
        for (var l in locs) {
          debugPrint('[SIKA STT] locale = ${l.localeId} (${l.name})');
        }
      }

      // Configurer Text-to-Speech
      await _flutterTts.setLanguage('fr-FR');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setCompletionHandler(() {
        if (state.state == SikaState.speaking) {
          state = state.copyWith(state: SikaState.idle);
        }
      });

      // Message de bienvenue
      final welcomeMessage = SikaMessage(
        text: "Salut ! Je suis Sika, ton assistant financier. "
            "Appuie sur le micro et parle-moi de tes dépenses !",
        isUser: false,
      );

      state = state.copyWith(
        isInitialized: true,
        messages: [welcomeMessage],
      );

      debugPrint('Sika initialized. Speech enabled: $_speechEnabled');
    } catch (e) {
      debugPrint('Failed to initialize Sika: $e');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'Impossible d\'initialiser Sika',
      );
    }
  }

  // Démarrer l'écoute
  Future<void> startListening() async {
    debugPrint('[SIKA VOICE] microphone button pressed');
    debugPrint('[SIKA VOICE] starting listening');

    if (!_speechEnabled) {
      debugPrint('[SIKA STT] SpeechToText not enabled, attempting re-initialization');
      await _initializeSika();
    }

    if (!_speechEnabled) {
      debugPrint('[SIKA STT] SpeechToText still disabled after retry');
      state = state.copyWith(
        state: SikaState.error,
        errorMessage: 'La reconnaissance vocale n\'est pas disponible',
      );
      return;
    }

    state = state.copyWith(
      state: SikaState.listening,
      currentText: '',
    );
    debugPrint('[SIKA VOICE] listening started');

    await _speechToText.listen(
      onResult: (result) {
        debugPrint('[SIKA STT] recognizedWords = "${result.recognizedWords}"');
        debugPrint('[SIKA STT] finalResult = ${result.finalResult}');
        debugPrint('[SIKA STT] confidence = ${result.confidence}');

        if (result.recognizedWords.isNotEmpty) {
          state = state.copyWith(
            currentText: result.recognizedWords,
          );
        }

        if (result.finalResult && result.recognizedWords.trim().isNotEmpty) {
          _processQuery(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        localeId: 'fr_FR',
        listenMode: ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
      ),
    );
  }

  // Arrêter l'écoute
  Future<void> stopListening() async {
    debugPrint('[SIKA VOICE] stopListening requested');
    await _speechToText.stop();

    if (state.currentText != null && state.currentText!.trim().isNotEmpty) {
      _processQuery(state.currentText!);
    } else {
      state = state.copyWith(state: SikaState.idle);
    }
  }

  /// Traitement manuel d'une requête textuelle.
  /// Pédagogie : Sika peut être utilisé par clavier si l'environnement est bruyant.
  Future<void> sendTextMessage(String text) async {
    if (text.trim().isEmpty) return;
    await _processQuery(text);
  }

  // Traiter la requête
  Future<void> _processQuery(String query) async {
    if (query.trim().isEmpty) {
      state = state.copyWith(state: SikaState.idle);
      return;
    }

    debugPrint('[SIKA VOICE] sending recognized text = "$query"');

    // Ajouter le message de l'utilisateur
    final userMessage = SikaMessage(text: query, isUser: true);
    state = state.copyWith(
      state: SikaState.processing,
      messages: [...state.messages, userMessage],
      currentText: null,
    );

    try {
      debugPrint('[SIKA API] request sent');
      // Appeler l'API Sika
      final response = await _apiService.sikaChat(query);

      // Créer le message de réponse
      final sikaMessage = SikaMessage(
        text:
            response['message'] ?? "Je n'ai pas compris, peux-tu reformuler ?",
        isUser: false,
        suggestedTransaction: response['suggested_transaction'],
        canAddTransaction: response['can_add_transaction'] ?? false,
      );

      state = state.copyWith(
        messages: [...state.messages, sikaMessage],
      );

      // Faire parler Sika
      await _speak(sikaMessage.text);
    } catch (e) {
      debugPrint('Sika API error: $e');

      final errorMessage = SikaMessage(
        text: "Oups ! Je n'arrive pas à me connecter au serveur. "
            "Vérifie ta connexion internet.",
        isUser: false,
      );

      state = state.copyWith(
        state: SikaState.error,
        messages: [...state.messages, errorMessage],
        errorMessage: e.toString(),
      );
    }
  }

  // Confirmer une transaction suggérée
  Future<void> confirmTransaction(Map<String, dynamic> transaction) async {
    state = state.copyWith(state: SikaState.processing);

    try {
      final response = await _apiService.sikaConfirmTransaction(
        amount: transaction['amount'],
        category: transaction['category'],
        description: transaction['description'],
      );

      final confirmMessage = SikaMessage(
        text: response['message'] ?? "Transaction enregistrée !",
        isUser: false,
      );

      state = state.copyWith(
        state: SikaState.idle,
        messages: [...state.messages, confirmMessage],
      );

      await _speak(confirmMessage.text);
    } catch (e) {
      debugPrint('Transaction confirmation error: $e');

      final errorMessage = SikaMessage(
        text: "Désolé, je n'ai pas pu enregistrer la transaction. "
            "Réessaie plus tard.",
        isUser: false,
      );

      state = state.copyWith(
        state: SikaState.error,
        messages: [...state.messages, errorMessage],
      );
    }
  }

  // Annuler une transaction suggérée
  void cancelTransaction() {
    final cancelMessage = SikaMessage(
      text: "D'accord, j'annule. Dis-moi si tu as besoin d'autre chose !",
      isUser: false,
    );

    state = state.copyWith(
      messages: [...state.messages, cancelMessage],
    );

    _speak(cancelMessage.text);
  }

  // Faire parler Sika
  Future<void> _speak(String text) async {
    state = state.copyWith(state: SikaState.speaking);
    await _flutterTts.speak(text);
  }

  // Arrêter Sika de parler
  Future<void> stopSpeaking() async {
    await _flutterTts.stop();
    state = state.copyWith(state: SikaState.idle);
  }

  // Effacer la conversation
  void clearConversation() {
    final welcomeMessage = SikaMessage(
      text: "Conversation effacée ! Comment puis-je t'aider ?",
      isUser: false,
    );

    state = state.copyWith(
      messages: [welcomeMessage],
      state: SikaState.idle,
    );
  }

  @override
  void dispose() {
    _speechToText.cancel();
    _flutterTts.stop();
    super.dispose();
  }
}

// Provider
final sikaProvider = StateNotifierProvider<SikaNotifier, SikaData>((ref) {
  return SikaNotifier(ApiService());
});

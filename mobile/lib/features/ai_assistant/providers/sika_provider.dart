import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/providers/language_provider.dart';
import '../../../../core/providers/currency_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/api_service_provider.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/services/sika_native_service.dart';
import '../../wallet/providers/wallet_provider.dart';

enum SikaState {
  idle,
  listening,
  processing,
  agentWorking,  // SIKA executes ReAct steps
  speaking,
  waitingVoiceConfirmation,
  ambiguityAsked,
  securityValidation,
  executingAction,
  reconciling,   // UNKNOWN_RESULT — transaction status being verified
  completed,
  cancelled,
  error,
}

class SikaMessage {
  final String text;
  final bool isUser;
  final Map<String, dynamic>? suggestedTransaction;
  final bool canAddTransaction;
  final List<Map<String, dynamic>>? agentSteps;

  SikaMessage({
    required this.text,
    required this.isUser,
    this.suggestedTransaction,
    this.canAddTransaction = false,
    this.agentSteps,
  });
}

class SikaData {
  final SikaState state;
  final List<SikaMessage> messages;
  final String? currentText;
  final String? errorMessage;
  final bool isInitialized;
  final bool isVoiceMode;
  final SikaState? pendingNextState;
  final String? pendingActionId;
  final Map<String, dynamic>? pendingActionData;
  // NEW: Track observable agent steps from backend
  final List<Map<String, dynamic>> agentSteps;
  // NEW: Track the single active confirmable action and obsolete ones
  final String? activeActionId;
  final Set<String> obsoleteActionIds;

  SikaData({
    required this.state,
    required this.messages,
    this.currentText,
    this.errorMessage,
    this.isInitialized = false,
    this.isVoiceMode = false,
    this.pendingNextState,
    this.pendingActionId,
    this.pendingActionData,
    this.agentSteps = const [],
    this.activeActionId,
    this.obsoleteActionIds = const {},
  });

  SikaData copyWith({
    SikaState? state,
    List<SikaMessage>? messages,
    String? currentText,
    String? errorMessage,
    bool? isInitialized,
    bool? isVoiceMode,
    SikaState? pendingNextState,
    String? pendingActionId,
    Map<String, dynamic>? pendingActionData,
    bool clearActionData = false,
    List<Map<String, dynamic>>? agentSteps,
    String? activeActionId,
    Set<String>? obsoleteActionIds,
    bool clearActiveAction = false,
  }) {
    return SikaData(
      state: state ?? this.state,
      messages: messages ?? this.messages,
      currentText: currentText ?? this.currentText,
      errorMessage: errorMessage ?? this.errorMessage,
      isInitialized: isInitialized ?? this.isInitialized,
      isVoiceMode: isVoiceMode ?? this.isVoiceMode,
      pendingNextState: pendingNextState ?? this.pendingNextState,
      pendingActionId:
          clearActionData ? null : (pendingActionId ?? this.pendingActionId),
      pendingActionData: clearActionData
          ? null
          : (pendingActionData ?? this.pendingActionData),
      agentSteps: agentSteps ?? this.agentSteps,
      activeActionId: clearActiveAction ? null : (activeActionId ?? this.activeActionId),
      obsoleteActionIds: obsoleteActionIds ?? this.obsoleteActionIds,
    );
  }
}

class SikaNotifier extends StateNotifier<SikaData> {
  final ApiService _apiService;
  final Ref _ref;

  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool _speechEnabled = false;
  int _activeSpeechRequestId = 0;

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
        if (val.errorMsg == 'error_speech_timeout') {
          // Timeout normal (l'utilisateur n'a rien dit)
          state = state.copyWith(state: SikaState.idle);
        } else {
          final isEn = _ref.read(languageProvider).code == 'en';
          String friendlyError = isEn
              ? "Speech recognition error (${val.errorMsg})"
              : "Erreur de reconnaissance vocale (${val.errorMsg})";
          if (val.errorMsg.contains('permission')) {
            friendlyError = isEn
                ? "Please allow microphone access in settings."
                : "Veuillez autoriser l'accès au microphone.";
          } else if (val.errorMsg == 'error_network' || val.errorMsg.contains('network')) {
            friendlyError = isEn
                ? "SIKA cannot connect to the network."
                : "SIKA n'arrive pas à se connecter au réseau.";
          }
          state = state.copyWith(
            state: SikaState.error,
            errorMessage: friendlyError,
          );
        }
      },
      onStatus: (status) {
        debugPrint('[SIKA STT] Speech status changed to: $status');
        if (status == 'done' || status == 'notListening') {
          // Délai pour éviter de couper onResult si le résultat final arrive en même temps que le statut
          Future.delayed(const Duration(milliseconds: 500), () {
            if (state.state == SikaState.listening) {
              debugPrint(
                  '[SIKA STT] Triggering _onSpeechComplete as fallback because status is $status');
              _onSpeechComplete();
            }
          });
        }
      },
    );
    debugPrint(
        '[SIKA STT] Initialization finished. _speechEnabled = $_speechEnabled');

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
      debugPrint('[SIKA TTS] Fallback flutter_tts playback completed');
      if (state.state == SikaState.speaking) {
        _onSpeechPlaybackFinished(_activeSpeechRequestId);
      }
    });

    _flutterTts.setErrorHandler((msg) {
      debugPrint('[SIKA TTS] TTS error: $msg');
      state = state.copyWith(state: SikaState.idle);
    });
  }

  /// Déclenche l'écoute avec la locale STT active (en_US ou fr_FR)
  Future<void> startListening({String? sttLocale}) async {
    debugPrint(
        '[SIKA VOICE] startListening called. Current state: ${state.state}');
    // INTERRUPTION DE LA VOIX (Comme Gemini Live) : Si Sika parlait, on l'arrête immédiatement
    if (state.state == SikaState.speaking) {
      debugPrint('[SIKA VOICE] Interrupting Sika speech...');
      await stopSpeaking(resetState: false);
    }

    if (!_speechEnabled) {
      debugPrint(
          '[SIKA VOICE] Cannot listen: STT not enabled. Re-initializing...');
      await _initializeSika();
      if (!_speechEnabled) {
        debugPrint('[SIKA VOICE] Initialization failed again, aborting.');
        return;
      }
    }

    // Mettre en pause le service Wake Word natif pour libérer le micro
    await SikaNativeService.pauseSikaService();

    final activeSttLocale = sttLocale ?? _ref.read(languageProvider).sttLocale;
    debugPrint('[SIKA VOICE] Using locale: $activeSttLocale');

    try {
      state = state.copyWith(
        state: SikaState.listening,
        currentText: null,
        errorMessage: null,
        isVoiceMode: true,
      );

      await _speechToText.listen(
        onResult: (result) {
          debugPrint(
              '[SIKA STT RESULT] isFinal: ${result.finalResult}, recognizedWords: "${result.recognizedWords}"');
          state = state.copyWith(currentText: result.recognizedWords);
          if (result.finalResult) {
            debugPrint(
                '[SIKA STT] Triggering _onSpeechComplete because isFinal is true');
            _onSpeechComplete();
          }
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 5),
          localeId: activeSttLocale,
          cancelOnError: false,
          partialResults: true,
        ),
      );
      debugPrint('[SIKA VOICE] _speechToText.listen() executed successfully.');
    } catch (e) {
      debugPrint('[SIKA VOICE EXCEPTION] Error starting STT: $e');
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

  Future<void> clearConversation() async {
    state = SikaData(
      state: SikaState.idle,
      messages: const [],
      currentText: null,
      errorMessage: null,
      isInitialized: state.isInitialized,
      isVoiceMode: false,
    );
    // Relancer le service Wake Word natif en arrière-plan UNIQUEMENT s'il est activé
    final prefs = await SharedPreferences.getInstance();
    final isEnabled = prefs.getBool('wake_word_enabled') ?? true;
    if (isEnabled) {
      SikaNativeService.resumeSikaService();
    }
  }

  /// Traitement d'une requête utilisateur (Vocale ou Textuelle) avec reconnaissance de l'utilisateur et de sa devise active
  Future<void> processUserQuery(String query, {String? ttsLocale}) async {
    if (query.trim().isEmpty) return;

    // ─── CONFIRMATION GUARD ────────────────────────────────────────────────
    // If a transfer is already prepared and awaiting biometric confirmation,
    // block new queries to prevent re-preparing a new transfer accidentally.
    if (state.state == SikaState.securityValidation ||
        state.state == SikaState.executingAction) {
      final currentLang = _ref.read(languageProvider);
      final isEn = currentLang.code == 'en';
      final reminderText = isEn
          ? 'Please confirm or cancel the pending action before continuing.'
          : 'Veuillez confirmer ou annuler l\'action en cours avant de continuer.';
      debugPrint(
          '[SIKA GUARD] 🛑 Blocked query while awaiting confirmation/execution: "$query"');
      final reminderMsg = SikaMessage(text: reminderText, isUser: false);
      state = state.copyWith(
        messages: List<SikaMessage>.from(state.messages)..add(reminderMsg),
      );
      return;
    }
    // ──────────────────────────────────────────────────────────────────────

    final isEnglish = _isEnglishText(query);
    final activeTtsLocale = ttsLocale ?? (isEnglish ? 'en-US' : 'fr-FR');

    // Récupération dynamique du prénom de l'utilisateur connecté
    final authState = _ref.read(authProvider);
    final rawName = authState.user?.name ?? 'David';
    final userFirstName =
        rawName.trim().isNotEmpty ? rawName.trim().split(' ').first : 'David';

    // Récupération dynamique de la devise active de l'utilisateur
    final activeCurrency = _ref.read(currencyProvider);
    final currencyCode = activeCurrency.code;
    final currencySymbol = activeCurrency.symbol;

    String cleanQuery = query.trim();
    final lower = cleanQuery.toLowerCase();

    // 1. SALUTATION / MOT CLÉ SIKA
    if (lower == 'sika' ||
        lower == 'dis sika' ||
        lower == 'hey sika' ||
        lower == 'hello sika') {
      final greetingText = isEnglish
          ? 'Yes $userFirstName, I am listening! How can I assist with your finances today?'
          : 'Oui $userFirstName, je vous écoute ! Que puis-je faire pour vos finances aujourd\'hui ?';

      final sikaMsg = SikaMessage(text: greetingText, isUser: false);
      final updatedMsgs = List<SikaMessage>.from(state.messages)
        ..add(SikaMessage(text: query, isUser: true))
        ..add(sikaMsg);

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
    final updatedMessages = List<SikaMessage>.from(state.messages)
      ..add(userMessage);

    state = state.copyWith(
      state: SikaState.processing,
      messages: updatedMessages,
      currentText: null,
      agentSteps: const [],
    );

    // 2. ENVOI AU BACKEND SIKA AVEC ORCHESTRATION ET CONTEXTE MULTI-TOURS
    try {
      debugPrint(
          '[SIKA API] Querying backend agent ($userFirstName, $currencyCode, $activeTtsLocale): "$cleanQuery"');
      final response = await _apiService.sikaChat(
        cleanQuery,
        userFirstName: userFirstName,
        displayCurrencyCode: currencyCode,
        displayCurrencySymbol: currencySymbol,
      );

      final String sikaText = (response['speech_text'] as String?) ??
          (response['message'] as String?) ??
          (response['response'] as String?) ??
          (isEnglish
              ? 'Sorry $userFirstName, I didn\'t quite catch that. Could you please repeat?'
              : 'Pardon $userFirstName, je n\'ai pas bien compris. Peux-tu répéter ?');

      final action = response['intent'] ?? response['action'];
      final status = response['status'] as String? ?? 'PROCESSED';
      final actionId = response['action_id'] as String?;
      final bool requiresSecurity =
          response['requires_security_validation'] == true ||
              response['requires_biometric'] == true;
      final actionData = response['action_data'] != null
          ? Map<String, dynamic>.from(response['action_data'])
          : null;

      final bool shouldSpeak =
          (response['should_speak'] == true) || state.isVoiceMode;

      final String backendLanguage = response['language'] as String? ?? (isEnglish ? 'en' : 'fr');
      final finalTtsLocale = backendLanguage == 'en' ? 'en-US' : 'fr-FR';

      debugPrint(
          '[SIKA API] Action detected: $action | Requires Security: $requiresSecurity | shouldSpeak: $shouldSpeak');

      SikaState pendingNextState = SikaState.idle;

      if (requiresSecurity && actionId != null) {
        pendingNextState = SikaState.securityValidation;
      } else if (action == 'ask_ambiguity' ||
          status == 'NEEDS_CLARIFICATION' ||
          response['requires_confirmation'] == true) {
        pendingNextState = SikaState.waitingVoiceConfirmation;
      }

      // Parse safe observable steps returned by the backend ReAct loop
      final List<Map<String, dynamic>> newAgentSteps = (response['agent_steps'] as List<dynamic>? ?? [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .toList();

      final sikaMessage = SikaMessage(
        text: response['message'] as String? ??
            response['response'] as String? ??
            sikaText,
        isUser: false,
        suggestedTransaction: actionData,
        canAddTransaction: (action == 'add_expense' ||
                action == 'add_income' ||
                action == 'transfer') &&
            !requiresSecurity &&
            (status == 'PROCESSED' || status == 'CONFIRMED'),
        agentSteps: newAgentSteps.isNotEmpty ? newAgentSteps : null,
      );
      final finalMessages = List<SikaMessage>.from(state.messages)
        ..add(sikaMessage);

      // Invalidate the previous active action if a new one has been prepared
      final String? previousActiveActionId = state.activeActionId;
      final Set<String> updatedObsoleteIds = Set<String>.from(state.obsoleteActionIds);
      if (actionId != null && previousActiveActionId != null && previousActiveActionId != actionId) {
        updatedObsoleteIds.add(previousActiveActionId);
        debugPrint('[SIKA ACTIONS] Previous action $previousActiveActionId marked OBSOLETE. New active: $actionId');
      }

      state = state.copyWith(
        state: shouldSpeak
            ? SikaState.speaking
            : (pendingNextState != SikaState.idle
                ? pendingNextState
                : SikaState.idle),
        messages: finalMessages,
        pendingNextState: pendingNextState,
        pendingActionId: actionId,
        pendingActionData: actionData,
        agentSteps: newAgentSteps,
        activeActionId: actionId ?? state.activeActionId,
        obsoleteActionIds: updatedObsoleteIds,
      );

      if (shouldSpeak) {
        await _speak(sikaText, ttsLocale: finalTtsLocale);
      }
    } catch (e) {
      debugPrint('[SIKA API] Error chatting with SIKA: $e');

      final fallbackText = isEnglish
          ? 'Sorry $userFirstName, I am experiencing a connection issue with my server. Could you please try again?'
          : 'Désolé $userFirstName, je rencontre une difficulté de connexion avec mon serveur. Peux-tu réessayer ?';

      final sikaMessage = SikaMessage(text: fallbackText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)
        ..add(sikaMessage);

      String userFriendlyError = isEnglish 
          ? "SIKA cannot connect right now. Please check your network." 
          : "SIKA n'arrive pas à se connecter pour le moment. Veuillez vérifier votre connexion.";

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
        errorMessage: userFriendlyError,
        pendingNextState: SikaState.error,
        pendingActionId: null,
        clearActionData: true,
      );

      await _speak(fallbackText, ttsLocale: activeTtsLocale);
    }
  }

  Future<void> sendTextMessage(String text, {String? ttsLocale}) async {
    state = state.copyWith(isVoiceMode: false);
    await processUserQuery(text, ttsLocale: ttsLocale);
  }

  Future<void> _speak(String text, {required String ttsLocale}) async {
    final currentRequestId = ++_activeSpeechRequestId;
    final isEn = ttsLocale.toLowerCase().startsWith('en');
    final voiceName = isEn ? 'en-US-Neural2-F' : 'fr-FR-Neural2-C';
    final langCode = isEn ? 'en-US' : 'fr-FR';

    debugPrint(
        '[SIKA TTS] Preparing speech output (ReqID: $currentRequestId, $langCode, Voice: $voiceName): "$text"');

    // Interrompt tout flux audio précédent
    await stopSpeaking(resetState: false);

    try {
      String? b64;

      // 1. MOTEUR PRINCIPAL : Appel de l'endpoint dédié POST /api/v1/sika/tts
      try {
        final ttsRes = await _apiService.fetchGcpTtsAudio(
          text,
          voiceName: voiceName,
          languageCode: langCode,
        );

        // Protection anti-course (Race Condition / Stale Request Protection)
        if (currentRequestId != _activeSpeechRequestId) {
          debugPrint(
              '[GCP TTS] 🛑 Requête obsolète (ReqID $currentRequestId vs Active $_activeSpeechRequestId). Abandon de l\'audio.');
          return;
        }

        if (ttsRes['success'] == true && ttsRes['audio_base64'] != null) {
          b64 = ttsRes['audio_base64'] as String;
        }
      } catch (e) {
        debugPrint(
            '[GCP TTS API] Indisponible ($e). Basculement automatique sur flutter_tts.');
      }

      if (currentRequestId != _activeSpeechRequestId) return;

      // 2. LECTURE AUDIO GCP TTS MP3
      if (b64 != null && b64.isNotEmpty) {
        debugPrint(
            '[GCP TTS] 🔊 Lecture Audio MP3 Google Cloud Text-to-Speech (${b64.length} octets, ReqID: $currentRequestId, Voice: $voiceName)');
        final bytes = base64Decode(b64);
        await _audioPlayer.play(BytesSource(bytes));

        _audioPlayer.onPlayerComplete.first.then((_) {
          if (currentRequestId == _activeSpeechRequestId &&
              state.state == SikaState.speaking) {
            _onSpeechPlaybackFinished(currentRequestId);
          }
        });
        return; // UN SEUL MOTEUR AUDIO EXÉCUTÉ - SANS AUCUN DOUBLON
      }

      // 3. FALLBACK : flutter_tts
      if (currentRequestId != _activeSpeechRequestId) return;
      debugPrint(
          '[FLUTTER TTS FALLBACK] 🔊 Élocution via la synthèse vocale locale (ReqID: $currentRequestId, Locale: $langCode)');
      await _flutterTts.setLanguage(langCode);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint('[SIKA TTS] Error in TTS speak: $e');
      if (currentRequestId == _activeSpeechRequestId) {
        state = state.copyWith(state: SikaState.idle);
      }
    }
  }

  void _onSpeechPlaybackFinished(int reqId) {
    if (reqId != _activeSpeechRequestId) return;
    debugPrint(
        '[HANDS-FREE] Speech playback finished (ReqID: $reqId, PendingState: ${state.pendingNextState})');

    final nextState = state.pendingNextState;
    final actionId = state.pendingActionId;

    if (nextState == SikaState.waitingVoiceConfirmation ||
        nextState == SikaState.ambiguityAsked) {
      debugPrint(
          '[HANDS-FREE] 🎙️ Auto-resuming STT listening for user voice response (State: $nextState)');
      state = state.copyWith(state: nextState);
      startListening();
    } else if (nextState == SikaState.securityValidation && actionId != null) {
      debugPrint(
          '[SECURITY] 🔐 Launching security validation for action_id: $actionId');
      state = state.copyWith(state: SikaState.securityValidation);
      executeSecurityValidationAndConfirm(actionId);
    } else {
      state = state.copyWith(
        state: nextState ?? SikaState.idle,
        pendingNextState: null,
        pendingActionId: null,
      );
    }
  }

  /// Non-destructive cancellation of the prepared action — preserves conversation history
  void cancelPendingAction({String? reason}) {
    final currentLang = _ref.read(languageProvider);
    final isEnglish = currentLang.code == 'en';
    final cancelText = reason ??
        (isEnglish
            ? 'The prepared operation has been cancelled.'
            : 'L\'opération préparée a été annulée.');

    final String? currentActionId = state.pendingActionId ?? state.activeActionId;
    final Set<String> updatedObsolete = Set<String>.from(state.obsoleteActionIds);
    if (currentActionId != null) {
      updatedObsolete.add(currentActionId);
      debugPrint('[SIKA SECURITY] 🛑 Action $currentActionId marked CANCELLED/OBSOLETE.');
    }

    final sikaMessage = SikaMessage(text: cancelText, isUser: false);
    state = state.copyWith(
      state: SikaState.idle,
      messages: List<SikaMessage>.from(state.messages)..add(sikaMessage),
      clearActionData: true,
      clearActiveAction: true,
      obsoleteActionIds: updatedObsolete,
    );
  }

  Future<void> executeSecurityValidationAndConfirm(String actionId) async {
    final currentLang = _ref.read(languageProvider);
    final isEnglish = currentLang.code == 'en';

    // DOUBLE-CONFIRMATION GUARD: Prevent multiple in-flight confirmation requests
    if (state.state == SikaState.executingAction) {
      debugPrint('[SIKA SECURITY] ⚠️ Confirmation already in progress. Ignoring duplicate request.');
      return;
    }

    // OBSOLETE ACTION GUARD: Refuse to confirm an action that has been superseded
    if (state.obsoleteActionIds.contains(actionId)) {
      debugPrint('[SIKA SECURITY] ⛔ Refusing confirmation of OBSOLETE action: $actionId');
      final msg = isEnglish
          ? 'This action has been replaced by a newer request. Please confirm the latest action.'
          : 'Cette action a été remplacée par une nouvelle demande. Veuillez confirmer la dernière action préparée.';
      final sikaMessage = SikaMessage(text: msg, isUser: false);
      state = state.copyWith(
        messages: List<SikaMessage>.from(state.messages)..add(sikaMessage),
        state: SikaState.idle,
      );
      return;
    }

    // ACTIVE ACTION GUARD: Ensure action matches the currently active action if defined
    if (state.activeActionId != null && state.activeActionId != actionId) {
      debugPrint('[SIKA SECURITY] ⛔ Action ID $actionId does not match active action ${state.activeActionId}. Aborting.');
      final msg = isEnglish
          ? 'This action is no longer active. Please confirm the latest request.'
          : 'Cette action n\'est plus active. Veuillez confirmer la dernière demande.';
      final sikaMessage = SikaMessage(text: msg, isUser: false);
      state = state.copyWith(
        messages: List<SikaMessage>.from(state.messages)..add(sikaMessage),
        state: SikaState.idle,
      );
      return;
    }

    try {
      state = state.copyWith(state: SikaState.executingAction);
      debugPrint(
          '[PAYMECHAP EXECUTION] Executing real payout confirmation via POST /api/v1/sika/agent/confirm for action_id: $actionId');

      final confirmRes = await _apiService.sikaAgentConfirm(actionId);
      final String status = (confirmRes['status'] as String?) ?? '';

      // P1.5: détermination du message et de l'état suivant selon le statut backend
      final String sikaText = (confirmRes['speech_text'] as String?) ??
          (confirmRes['message'] as String?) ??
          (status == 'EXPIRED'
              ? (isEnglish
                  ? 'This transaction request has expired. Please try again.'
                  : 'Cette demande de transaction a expiré. Veuillez recommencer l\'opération.')
              : status == 'REQUIRES_RECONCILIATION'
                  ? (isEnglish
                      ? 'The transaction status must be verified before any new attempt.'
                      : 'Le statut de cette opération doit être vérifié avant toute nouvelle tentative.')
                  : status == 'UNKNOWN_RESULT'
                      ? (isEnglish
                          ? 'Transaction status uncertain. I will check with PayMeChap.'
                          : 'Statut de la transaction incertain. Je vérifie auprès de PayMeChap.')
                      : (isEnglish
                          ? 'Operation confirmed and completed successfully on PayMeChap!'
                          : 'Opération confirmée et exécutée avec succès sur PayMeChap !'));

      final bool isExecuted = status == 'EXECUTED';
      final bool needsReconciliation =
          status == 'UNKNOWN_RESULT' || status == 'REQUIRES_RECONCILIATION';

      // CRITICAL FIX: UNKNOWN_RESULT is NOT a failure — it means the status is
      // being verified. Map to reconciling, never to error.
      final SikaState pendingState = isExecuted
          ? SikaState.completed
          : (status == 'EXPIRED' || status == 'FAILED')
              ? SikaState.error
              : needsReconciliation
                  ? SikaState.reconciling  // Reassuring state, not error
                  : SikaState.idle;

      final sikaMessage = SikaMessage(text: sikaText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)
        ..add(sikaMessage);

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
        pendingNextState: pendingState,
        // P1.5: conserver l'action_id pour UNKNOWN_RESULT/REQUIRES_RECONCILIATION
        pendingActionId: needsReconciliation ? actionId : null,
      );

      // P1.1: Rafraîchir le solde immédiatement après exécution réussie
      if (isExecuted) {
        debugPrint(
            '[P1.1] Transaction EXECUTED — rafraîchissement automatique des portefeuilles.');
        _ref.read(walletProvider.notifier).fetchWallets();
        _ref.read(walletProvider.notifier).fetchMovements();
      }

      await _speak(sikaText, ttsLocale: currentLang.ttsLanguage);
    } catch (e) {
      debugPrint('[SECURITY EXECUTION ERROR] $e');
      final errorMsg = isEnglish
          ? 'Failed to execute transaction on PayMeChap: $e'
          : 'Échec d\'exécution de la transaction sur PayMeChap : $e';

      final sikaMessage = SikaMessage(text: errorMsg, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)
        ..add(sikaMessage);

      String userFriendlyError = isEnglish
          ? "Network error communicating with PayMeChap."
          : "Erreur réseau lors de la communication avec PayMeChap.";

      state = state.copyWith(
        state: SikaState.error,
        messages: finalMessages,
        errorMessage: userFriendlyError,
        pendingNextState: SikaState.error,
        pendingActionId: null,
      );

      await _speak(errorMsg, ttsLocale: currentLang.ttsLanguage);
    }
  }

  Future<void> executeActionReconciliation(String actionId) async {
    final currentLang = _ref.read(languageProvider);
    final isEnglish = currentLang.code == 'en';
    try {
      debugPrint(
          '[RECONCILIATION] Triggering reconciliation for actionId: $actionId');
      final res = await _apiService.sikaReconcileAction(actionId);
      final String status = (res['status'] as String?) ?? 'UNKNOWN_RESULT';

      final String speechText = (res['speech_text'] as String?) ??
          (res['message'] as String?) ??
          (status == 'EXECUTED'
              ? (isEnglish
                  ? 'Transaction confirmed and completed successfully on PayMeChap!'
                  : 'Opération confirmée et exécutée avec succès sur PayMeChap !')
              : status == 'FAILED'
                  ? (isEnglish
                      ? 'The transaction failed on PayMeChap. No funds were debited.'
                      : 'La transaction a échoué sur PayMeChap. Aucun montant n\'a été débité.')
                  : (isEnglish
                      ? 'The transaction status is still pending verification with PayMeChap.'
                      : 'Le statut de la transaction est toujours en attente de confirmation auprès de PayMeChap.'));

      final sikaMessage = SikaMessage(text: speechText, isUser: false);
      final finalMessages = List<SikaMessage>.from(state.messages)
        ..add(sikaMessage);

      final bool isExecuted = status == 'EXECUTED';
      final bool isFailed = status == 'FAILED';
      final bool stillPending = status == 'UNKNOWN_RESULT' ||
          status == 'REQUIRES_RECONCILIATION' ||
          status == 'RECONCILIATION_IN_PROGRESS';

      state = state.copyWith(
        state: SikaState.speaking,
        messages: finalMessages,
        pendingNextState: isExecuted
            ? SikaState.completed
            : isFailed
                ? SikaState.idle
                : SikaState.reconciling,
        pendingActionId: stillPending ? actionId : null,
      );

      await _speak(speechText, ttsLocale: currentLang.ttsLanguage);
    } catch (e) {
      debugPrint('[RECONCILIATION ERROR] $e');
      final errorNotice = isEnglish
          ? 'Could not connect to verify status. Please try again shortly.'
          : 'Impossible de joindre le serveur pour vérifier le statut. Veuillez réessayer dans un instant.';
      final sikaMessage = SikaMessage(text: errorNotice, isUser: false);
      state = state.copyWith(
        messages: List<SikaMessage>.from(state.messages)..add(sikaMessage),
      );
    }
  }

  Future<void> stopSpeaking({bool resetState = true}) async {
    try {
      await _audioPlayer.stop();
      await _flutterTts.stop();
      if (resetState) {
        state = state.copyWith(state: SikaState.idle);
      }
    } catch (e) {
      debugPrint('[SIKA TTS] Error stopping TTS: $e');
    }
  }

  bool _isEnglishText(String text) {
    final lower = text.toLowerCase();

    final frenchIndicators = [
      'bonjour',
      'salut',
      'coucou',
      'bonsoir',
      'comment',
      'vas',
      'va',
      'ça va',
      'ca va',
      'solde',
      'combien',
      'portefeuille',
      'dépense',
      'depense',
      'épargne',
      'epargne',
      'transfert',
      'transférer',
      'argent',
      'merci',
      'oui',
      'non',
      'je',
      'tu',
      'moi',
      'toi',
      'suis',
      'vais',
      'bien',
      'comment tu vas'
    ];
    final englishIndicators = [
      'hello',
      'hi',
      'hey',
      'how are you',
      'say hello',
      'good morning',
      'thanks',
      'thank',
      'how much',
      'money',
      'total',
      'balance',
      'transfer',
      'rebalance',
      'save',
      'savings',
      'add',
      'goal',
      'how is my',
      'what is my',
      'analyze',
      'recent',
      'expenses',
      'spend',
      'wallet',
      'dollars',
      'usd',
      'are you okay',
      'are you fine',
      'are you good',
      'you okay',
      'doing',
      'okay',
      'ok'
    ];

    int frenchCount = 0;
    int englishCount = 0;

    for (final word in frenchIndicators) {
      if (lower.contains(word)) frenchCount++;
    }
    for (final word in englishIndicators) {
      if (lower.contains(word)) englishCount++;
    }

    if (englishCount > frenchCount) return true;
    if (frenchCount > englishCount) return false;

    return _ref.read(languageProvider).code == 'en';
  }
}

final sikaProvider = StateNotifierProvider<SikaNotifier, SikaData>((ref) {
  // Utilise l'instance partagée dont le token JWT est synchronisé
  // automatiquement depuis authProvider. Indispensable pour que
  // POST /agent/confirm et POST /actions/{id}/reconcile reçoivent
  // l'Authorization: Bearer.
  final apiService = ref.watch(apiServiceProvider);
  return SikaNotifier(apiService, ref);
});

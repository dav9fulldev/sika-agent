import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/sika_native_service.dart';

enum AppLanguage { english, french }

extension AppLanguageExtension on AppLanguage {
  String get displayName =>
      this == AppLanguage.english ? 'English' : 'Français';
  String get code => this == AppLanguage.english ? 'en' : 'fr';
  String get sttLocale => this == AppLanguage.english ? 'en-US' : 'fr-FR';
  String get ttsLanguage => this == AppLanguage.english ? 'en-US' : 'fr-FR';
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  static const String _keyLang = 'sika_preferred_language';

  LanguageNotifier() : super(AppLanguage.english) {
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_keyLang);
      if (savedCode != null) {
        if (savedCode == 'en' || savedCode.toLowerCase() == 'english') {
          state = AppLanguage.english;
        } else {
          state = AppLanguage.french;
        }
      }
      _syncNativeLanguage();
    } catch (e) {
      debugPrint('[LANGUAGE PREFS] Error loading saved language: $e');
    }
  }

  Future<void> _saveLanguage(AppLanguage lang) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLang, lang.code);
    } catch (e) {
      debugPrint('[LANGUAGE PREFS] Error saving language: $e');
    }
  }

  void _syncNativeLanguage() {
    try {
      SikaNativeService.setSessionContext(
        token: '',
        firstname: '',
        currency: '',
        language: state.code,
      );
    } catch (e) {
      debugPrint('[LANGUAGE NATIVE] Error syncing language to native: $e');
    }
  }

  void setLanguage(AppLanguage lang) {
    state = lang;
    _saveLanguage(lang);
    _syncNativeLanguage();
  }

  void setLanguageByString(String langStr) {
    if (langStr.toLowerCase() == 'english' || langStr.toLowerCase() == 'en') {
      state = AppLanguage.english;
    } else {
      state = AppLanguage.french;
    }
    _saveLanguage(state);
    _syncNativeLanguage();
  }

  bool get isEnglish => state == AppLanguage.english;

  /// Utility translation helper
  String tr(String frText, String enText) {
    return state == AppLanguage.english ? enText : frText;
  }
}

final languageProvider =
    StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

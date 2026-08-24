import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppLanguage { english, french }

extension AppLanguageExtension on AppLanguage {
  String get displayName => this == AppLanguage.english ? 'English' : 'Français';
  String get code => this == AppLanguage.english ? 'en' : 'fr';
  String get sttLocale => this == AppLanguage.english ? 'en-US' : 'fr-FR';
  String get ttsLanguage => this == AppLanguage.english ? 'en-US' : 'fr-FR';
}

class LanguageNotifier extends StateNotifier<AppLanguage> {
  LanguageNotifier() : super(AppLanguage.english); // English by default

  void setLanguage(AppLanguage lang) {
    state = lang;
  }

  void setLanguageByString(String langStr) {
    if (langStr.toLowerCase() == 'english' || langStr.toLowerCase() == 'en') {
      state = AppLanguage.english;
    } else {
      state = AppLanguage.french;
    }
  }

  bool get isEnglish => state == AppLanguage.english;

  /// Utility translation helper
  String tr(String frText, String enText) {
    return state == AppLanguage.english ? enText : frText;
  }
}

final languageProvider = StateNotifierProvider<LanguageNotifier, AppLanguage>((ref) {
  return LanguageNotifier();
});

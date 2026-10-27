import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/features/ai_assistant/presentation/pages/sika_chat_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SIKA Language Consistency Unit & Widget Tests', () {
    test('LanguageNotifier translates correctly and updates state', () {
      final notifier = LanguageNotifier();
      // English by default (hackathon submission language); French is one tap away
      expect(notifier.state, AppLanguage.english);
      expect(notifier.isEnglish, true);
      expect(notifier.tr('Bonjour', 'Hello'), 'Hello');

      notifier.setLanguage(AppLanguage.french);
      expect(notifier.tr('Bonjour', 'Hello'), 'Bonjour');

      notifier.setLanguage(AppLanguage.english);
      expect(notifier.state, AppLanguage.english);
      expect(notifier.isEnglish, true);
      expect(notifier.tr('Bonjour', 'Hello'), 'Hello');

      notifier.setLanguageByString('fr');
      expect(notifier.state, AppLanguage.french);
      expect(notifier.tr('Bonjour', 'Hello'), 'Bonjour');
    });

    testWidgets('SikaChatScreen renders English welcome and suggestions when app is English', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageProvider.overrideWith((ref) {
              final notif = LanguageNotifier();
              notif.setLanguage(AppLanguage.english);
              return notif;
            }),
          ],
          child: const MaterialApp(
            home: SikaChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Hello'), findsOneWidget);
      expect(find.textContaining('I am SIKA Pay'), findsOneWidget);
      expect(find.text('Buy an Excel course under \$50'), findsOneWidget);
      expect(find.text('Cloud storage, \$40 budget'), findsOneWidget);
      expect(find.text('Did my last payment go through?'), findsOneWidget);
      expect(find.text('Active assistant'), findsOneWidget);
      expect(find.text('Ask SIKA...'), findsOneWidget);

      // Verify no French defaults are shown
      expect(find.text('Bonjour'), findsNothing);
      expect(find.text('Acheter un cours Excel à moins de 50 \$'), findsNothing);
      expect(find.text('Du stockage cloud, budget 40 \$'), findsNothing);
      expect(find.text('Assistant actif'), findsNothing);
      expect(find.text('Demander à SIKA...'), findsNothing);
    });

    testWidgets('SikaChatScreen renders French welcome and suggestions when app is French', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageProvider.overrideWith((ref) {
              final notif = LanguageNotifier();
              notif.setLanguage(AppLanguage.french);
              return notif;
            }),
          ],
          child: const MaterialApp(
            home: SikaChatScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Bonjour'), findsOneWidget);
      expect(find.textContaining('Je suis SIKA Pay'), findsOneWidget);
      expect(find.text('Acheter un cours Excel à moins de 50 \$'), findsOneWidget);
      expect(find.text('Du stockage cloud, budget 40 \$'), findsOneWidget);
      expect(find.text('Où en est mon dernier paiement ?'), findsOneWidget);
      expect(find.text('Assistant actif'), findsOneWidget);
      expect(find.text('Demander à SIKA...'), findsOneWidget);

      // Verify no English defaults are shown
      expect(find.text('Hello'), findsNothing);
      expect(find.text('Buy an Excel course under \$50'), findsNothing);
      expect(find.text('Cloud storage, \$40 budget'), findsNothing);
      expect(find.text('Active assistant'), findsNothing);
      expect(find.text('Ask SIKA...'), findsNothing);
    });
  });
}

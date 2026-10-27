import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/pages/subscription_screen.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child) => ProviderScope(
        overrides: [languageProvider.overrideWith((ref) => LanguageNotifier()..setLanguage(AppLanguage.english))],
        child: MaterialApp(home: Scaffold(body: child)),
      );

  testWidgets('prepared subscription asks the user to review it', (tester) async {
    await tester.pumpWidget(wrap(const SubscriptionCard(subscription: {
      'subscription_ref': 'sub_1', 'name': 'TuneWave Music', 'price': '9.99', 'currency': 'USD',
      'status': 'AWAITING_USER_CONFIRMATION', 'paypal': {},
    })));
    expect(find.text('TuneWave Music'), findsOneWidget);
    expect(find.text('9.99 USD/mo'), findsOneWidget);
    expect(find.text('Price verified with PayPal'), findsOneWidget);
    expect(find.text('Review subscription'), findsOneWidget);
  });

  testWidgets('active subscription shows Manage', (tester) async {
    await tester.pumpWidget(wrap(const SubscriptionCard(subscription: {
      'subscription_ref': 'sub_2', 'name': 'CloudVault 200 GB', 'price': '2.99', 'currency': 'USD', 'status': 'ACTIVE', 'paypal': {},
    })));
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
  });
}

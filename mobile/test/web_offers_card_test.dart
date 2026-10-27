import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/widgets/web_offers_card.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('web offers show best merchant and comparison sheet', (tester) async {
    final data = {
      'type': 'web_offers',
      'products': [
        {
          'product_id': 'p1',
          'title': 'Wireless Headphones',
          'brand': 'Acme',
          'image_url': null,
          'offer_count': 3,
          'best_offer': {'merchant': 'store-b.com', 'price': '47.50', 'currency': 'USD', 'availability': 'InStock', 'url': 'https://x/b'},
          'offers': [
            {'merchant': 'store-b.com', 'price': '47.50', 'currency': 'USD', 'availability': 'InStock', 'url': 'https://x/b'},
            {'merchant': 'store-a.com', 'price': '59.99', 'currency': 'USD', 'availability': 'InStock', 'url': 'https://x/a'},
          ],
        }
      ],
    };
    await tester.pumpWidget(ProviderScope(
      overrides: [languageProvider.overrideWith((ref) => LanguageNotifier()..setLanguage(AppLanguage.english))],
      child: MaterialApp(home: Scaffold(body: WebOffersCard(data: data))),
    ));
    expect(find.text('Wireless Headphones'), findsOneWidget);
    expect(find.text('47.50 USD'), findsOneWidget);
    expect(find.textContaining('Available at store-b.com'), findsOneWidget);
    await tester.tap(find.text('Wireless Headphones'));
    await tester.pumpAndSettle();
    expect(find.text('Merchant offers'), findsOneWidget);
    expect(find.text('Open at store-b.com'), findsOneWidget);
    expect(find.textContaining('SIKA does not pay on these sites'), findsOneWidget);
  });
}

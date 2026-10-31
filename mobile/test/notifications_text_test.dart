import 'package:flutter_test/flutter_test.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/pages/notifications_screen.dart';

void main() {
  final drop = {
    'kind': 'price_drop',
    'title': 'Keyboard K2',
    'merchant': 'store-b.com',
    'price': '52.00',
    'previous_price': '59.00',
    'currency': 'USD',
  };

  test('notifications read in the app language', () {
    final en = LanguageNotifier()..setLanguage(AppLanguage.english);
    expect(notificationText(drop, en), ('Price drop', 'Keyboard K2 is now 52.00 USD at store-b.com (was 59.00 USD).'));
    final fr = LanguageNotifier()..setLanguage(AppLanguage.french);
    expect(notificationText(drop, fr).$1, 'Baisse de prix');
    expect(notificationText({...drop, 'kind': 'offer_removed'}, fr).$2, 'store-b.com ne vend plus Keyboard K2.');
  });

  test('time since the change', () {
    final en = LanguageNotifier()..setLanguage(AppLanguage.english);
    final now = DateTime.utc(2026, 10, 31, 12);
    expect(timeAgo('2026-10-31T11:55:00Z', en, now: now), '5 min ago');
    expect(timeAgo('2026-10-31T09:00:00Z', en, now: now), '3 h ago');
    expect(timeAgo('2026-10-29T12:00:00Z', en, now: now), '2 d ago');
  });
}

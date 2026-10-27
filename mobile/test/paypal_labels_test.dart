import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/core/providers/language_provider.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/widgets/sika_pay_ui.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('audit events read as sentences and internal steps are hidden', () {
    final lang = LanguageNotifier()..setLanguage(AppLanguage.english);
    expect(eventLabel({'event_type': 'AGENT_CONFIRMED'}, lang), 'Confirmed by SIKA with your authorization');
    expect(eventLabel({'event_type': 'PAYPAL_CAPTURE_COMPLETED_CAPTURE_RETURN'}, lang), 'Payment captured by PayPal');
    expect(eventLabel({'event_type': 'PAYPAL_CAPTURE_REFUNDED_WEBHOOK'}, lang), 'Refunded by the merchant');
    expect(eventLabel({'event_type': 'CAPTURE_STARTED'}, lang), isNull);
    expect(eventLabel({'event_type': 'PAYER_RETURNED_FROM_PAYPAL'}, lang), isNull);
    lang.setLanguage(AppLanguage.french);
    expect(eventLabel({'event_type': 'USER_CONFIRMED'}, lang), 'Confirmé par vous');
  });

  test('PayPal errors are translated, unknown codes keep the server message', () {
    final lang = LanguageNotifier()..setLanguage(AppLanguage.french);
    expect(paypalErrorText('INSTRUMENT_DECLINED', 'server', lang), contains('autre sur PayPal'));
    expect(paypalErrorText('SOMETHING_NEW', 'Server text', lang), 'Server text');
    lang.setLanguage(AppLanguage.english);
    expect(paypalErrorText('INSTRUMENT_DECLINED', 'The payment method was declined.', lang), 'The payment method was declined.');
  });
}

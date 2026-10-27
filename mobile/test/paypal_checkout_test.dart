import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/widgets/paypal_checkout_card.dart';
import 'package:sika_assistant_mobile/features/paypal/presentation/widgets/sika_pay_ui.dart';
import 'package:sika_assistant_mobile/features/paypal/providers/paypal_checkout_provider.dart';

/// Réponse représentative de GET /api/v1/paypal/checkouts/{id} (forme renvoyée par le backend).
Map<String, dynamic> checkoutJson({String status = 'AWAITING_USER_CONFIRMATION'}) => {
      'checkout_id': 'chk_0123456789abcdef01234567',
      'type': 'paypal_checkout',
      'provider': 'PAYPAL',
      'environment': 'sandbox',
      'status': status,
      'status_label': 'Prepared by SIKA — waiting for your confirmation',
      'next_action': 'CONFIRM',
      'is_terminal': false,
      'merchant': {'name': 'SIKA Demo Store', 'is_demo': true},
      'item': {'sku': 'SIKA-COURSE-EXCEL', 'name': 'Online course: Excel for Small Business', 'category': 'education'},
      'quantity': 1,
      'unit_amount': '49.00',
      'total_amount': '49.00',
      'currency': 'USD',
      'budget': {'limit': '50.00', 'currency': 'USD', 'within_budget': true, 'remaining_after_purchase': '1.00'},
      'details_hash': 'a' * 64,
      'paypal': {'order_id': null, 'approve_url': null},
      'provenance': {'verified': [], 'user_provided': [], 'assumptions': []},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PayPalCheckoutView reads only backend-provided values', () {
    final v = PayPalCheckoutView(data: checkoutJson());
    expect(v.id, 'chk_0123456789abcdef01234567');
    expect(v.total, '49.00');
    expect(v.currency, 'USD');
    expect(v.detailsHash.length, 64);
    expect(v.budget['within_budget'], isTrue);
    expect(v.isTerminal, isFalse);
  });

  test('checkout steps follow the real Orders v2 lifecycle', () {
    expect(checkoutStepIndex('AWAITING_USER_CONFIRMATION'), 0);
    expect(checkoutStepIndex('AWAITING_PAYPAL_APPROVAL'), 1);
    expect(checkoutStepIndex('APPROVED'), 2);
    expect(checkoutStepIndex('COMPLETED'), 4);
    expect(checkoutStepIndex('CANCELLED'), -1);
    // Une commande approuvée n'est jamais présentée comme payée
    expect(checkoutStepIndex('APPROVED') < checkoutStepIndex('COMPLETED'), isTrue);
  });

  test('seed never overwrites a more recent server state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(paypalCheckoutsProvider.notifier);
    notifier.seed(checkoutJson(status: 'COMPLETED'));
    notifier.seed(checkoutJson(status: 'AWAITING_USER_CONFIRMATION'));
    expect(container.read(paypalCheckoutsProvider)['chk_0123456789abcdef01234567']!.status, 'COMPLETED');
  });

  testWidgets('checkout card shows verified total and budget', (tester) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: PayPalCheckoutCard(initialCheckout: checkoutJson()))),
    ));
    await tester.pump();

    expect(find.text('SANDBOX'), findsNothing);
    expect(find.text('49.00 USD'), findsOneWidget);
    expect(find.text('Online course: Excel for Small Business'), findsOneWidget);
    expect(find.textContaining('50.00 USD'), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('cancelled checkout offers no payment button', (tester) async {
    final json = checkoutJson(status: 'CANCELLED')..['is_terminal'] = true;
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(home: Scaffold(body: PayPalCheckoutCard(initialCheckout: json))),
    ));
    await tester.pump();
    expect(find.byType(FilledButton), findsNothing);
  });
}

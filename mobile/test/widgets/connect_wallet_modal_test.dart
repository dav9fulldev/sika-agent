import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sika_assistant_mobile/features/wallet/presentation/widgets/connect_wallet_modal.dart';

void main() {
  testWidgets('ConnectWalletModal renders and handles basic interaction', (WidgetTester tester) async {
    // Wrap with ProviderScope to provide Riverpod dependencies
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                return ElevatedButton(
                  onPressed: () {
                    ConnectWalletModal.show(context);
                  },
                  child: const Text('Show Modal'),
                );
              },
            ),
          ),
        ),
      ),
    );

    // Tap the button to open the modal
    await tester.tap(find.text('Show Modal'));
    await tester.pumpAndSettle();

    // Verify modal is displayed
    expect(find.byType(ConnectWalletModal), findsOneWidget);

    // Verify main elements are present
    expect(find.byType(TextField), findsOneWidget); // Phone number field
    expect(find.byType(ElevatedButton), findsWidgets); // Buttons like OTP request

    // Verify Provider selection exists
    expect(find.text('Wave'), findsOneWidget);
    expect(find.text('Orange Money'), findsOneWidget);
    expect(find.text('MTN MoMo'), findsOneWidget);

    // Enter a phone number
    await tester.enterText(find.byType(TextField).first, '0701020304');
    await tester.pump();
    
    // Tap a provider to select it
    await tester.tap(find.text('Orange Money'));
    await tester.pump();
  });
}

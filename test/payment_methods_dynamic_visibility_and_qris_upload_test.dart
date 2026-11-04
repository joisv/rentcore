import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class MockPaymentRepoForVisibility extends PaymentRepository {
  PaymentContext? lastContext;
  String? lastMethodCode;

  @override
  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? notes,
  }) async {
    lastContext = context;
    lastMethodCode = paymentMethodCode;
    return PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'TX-TEST-001',
      receiptNumber: 'RCP-TEST-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: 0.0,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
    );
  }
}

void main() {
  final defaultPaymentMethods = [
    {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
    {
      'id': 2,
      'code': 'QRIS',
      'name': 'QRIS',
      'is_active': true,
      'qris_image_url': 'http://localhost/storage/qris/test_qris.png',
    },
    {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank', 'is_active': true},
  ];

  final testContext = PaymentContext(
    transactionType: PaymentTransactionType.booking,
    customerName: 'Budi Test',
    customerPhone: '08123456789',
    deviceName: 'iPhone 15 Pro',
    totalAmountDue: 150000.0,
    remainingDue: 150000.0,
    previouslyPaidAmount: 0.0,
    branchId: 1,
  );

  group('Dynamic Payment Method Visibility (Toggle Sync) Tests', () {
    testWidgets(
      'Renders all 3 cards (QRIS, Tunai, Lainnya) when all toggles are active',
      (tester) async {
        final mockSettings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'bank_transfer_enabled': true,
            'ewallet_enabled': true,
            'ewallet_providers': {
              'shopeepay': true,
              'dana': true,
              'linkaja': true,
              'ovo': true,
            },
            'qris_image_url': 'http://localhost/storage/qris/test_qris.png',
          },
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(mockSettings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('QRIS'), findsOneWidget);
        expect(find.text('Tunai'), findsOneWidget);
        expect(find.text('Lainnya'), findsOneWidget);
      },
    );

    testWidgets('Hides Cash card when cash_enabled is false', (tester) async {
      final mockSettings = {
        'config': {
          'cash_enabled': false,
          'qris_statis_enabled': true,
          'bank_transfer_enabled': true,
          'ewallet_enabled': true,
          'ewallet_providers': {'shopeepay': true, 'dana': true},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentMethodsProvider.overrideWith(
              (ref) => Future.value(defaultPaymentMethods),
            ),
            paymentSettingsProvider(1)
                .overrideWith((ref) => Future.value(mockSettings)),
          ],
          child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tunai'), findsNothing);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
    });

    testWidgets('Hides QRIS card when qris_statis_enabled is false', (
      tester,
    ) async {
      final mockSettings = {
        'config': {
          'cash_enabled': true,
          'qris_statis_enabled': false,
          'bank_transfer_enabled': true,
          'ewallet_enabled': true,
          'ewallet_providers': {'shopeepay': true, 'dana': true},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentMethodsProvider.overrideWith(
              (ref) => Future.value(defaultPaymentMethods),
            ),
            paymentSettingsProvider(1)
                .overrideWith((ref) => Future.value(mockSettings)),
          ],
          child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('QRIS'), findsNothing);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Lainnya'), findsOneWidget);
    });

    testWidgets(
      'Hides Lainnya card when ewallet_enabled is false and bank_transfer_enabled is false',
      (tester) async {
        final mockSettings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'bank_transfer_enabled': false,
            'ewallet_enabled': false,
            'ewallet_providers': {
              'shopeepay': false,
              'dana': false,
              'linkaja': false,
              'ovo': false,
            },
          },
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(
                  defaultPaymentMethods
                      .where((m) => m['code'] != 'TRANSFER')
                      .toList(),
                ),
              ),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(mockSettings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('QRIS'), findsOneWidget);
        expect(find.text('Tunai'), findsOneWidget);
        expect(find.text('Lainnya'), findsNothing);
      },
    );

    testWidgets('Shows alert banner when all payment methods are disabled', (
      tester,
    ) async {
      final mockSettings = {
        'config': {
          'cash_enabled': false,
          'qris_statis_enabled': false,
          'bank_transfer_enabled': false,
          'ewallet_enabled': false,
          'ewallet_providers': {'shopeepay': false, 'dana': false},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentMethodsProvider.overrideWith((ref) => Future.value([])),
            paymentSettingsProvider(1)
                .overrideWith((ref) => Future.value(mockSettings)),
          ],
          child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tidak ada metode pembayaran aktif.'), findsOneWidget);
      expect(find.text('Tunai'), findsNothing);
      expect(find.text('QRIS'), findsNothing);
      expect(find.text('Lainnya'), findsNothing);
    });
  });

  group(
    'E-Wallet & Bank Transfer Sub-Toggle Filtering Tests in Bottom Sheet',
    () {
      testWidgets('E-Wallet section is hidden if ewallet_enabled is false', (
        tester,
      ) async {
        final mockSettings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'bank_transfer_enabled': true,
            'ewallet_enabled': false,
            'ewallet_providers': {'shopeepay': true, 'dana': true},
          },
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(mockSettings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
          ),
        );

        await tester.pumpAndSettle();

        // Open Lainnya sheet
        await tester.tap(find.text('Lainnya'));
        await tester.pumpAndSettle();

        // "Dompet Digital" box should NOT be visible
        expect(find.text('Dompet Digital'), findsNothing);
        expect(find.text('ShopeePay'), findsNothing);
        expect(find.text('DANA'), findsNothing);

        // "Transfer Bank" box should be visible
        expect(find.text('Transfer Bank'), findsOneWidget);
        expect(find.text('BCA'), findsOneWidget);
        expect(find.text('Mandiri'), findsOneWidget);
      });

      testWidgets(
        'Specific e-wallet providers toggled off are omitted from the grid',
        (tester) async {
          final mockSettings = {
            'config': {
              'cash_enabled': true,
              'qris_statis_enabled': true,
              'bank_transfer_enabled': true,
              'ewallet_enabled': true,
              'ewallet_providers': {
                'shopeepay': true,
                'dana': false, // Toggled off!
                'linkaja': false, // Toggled off!
                'ovo': true,
                'gopay': false,
              },
            },
          };

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                paymentMethodsProvider.overrideWith(
                  (ref) => Future.value(defaultPaymentMethods),
                ),
                paymentSettingsProvider(1)
                    .overrideWith((ref) => Future.value(mockSettings)),
              ],
              child: MaterialApp(
                home: PaymentPage(paymentContext: testContext),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Open Lainnya sheet
          await tester.tap(find.text('Lainnya'));
          await tester.pumpAndSettle();

          // Active ones should be visible
          expect(find.byKey(const ValueKey('tile_ShopeePay')), findsOneWidget);
          expect(find.byKey(const ValueKey('tile_OVO')), findsOneWidget);

          // Disabled ones should be omitted
          expect(find.byKey(const ValueKey('tile_DANA')), findsNothing);
          expect(find.byKey(const ValueKey('tile_LinkAja!')), findsNothing);
          expect(find.byKey(const ValueKey('tile_GoPay')), findsNothing);
        },
      );

      testWidgets(
        'Transfer Bank section is hidden if bank_transfer_enabled is false',
        (tester) async {
          final mockSettings = {
            'config': {
              'cash_enabled': true,
              'qris_statis_enabled': true,
              'bank_transfer_enabled': false,
              'ewallet_enabled': true,
              'ewallet_providers': {'shopeepay': true, 'dana': true},
            },
          };

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                paymentMethodsProvider.overrideWith(
                  (ref) => Future.value(defaultPaymentMethods),
                ),
                paymentSettingsProvider(1)
                    .overrideWith((ref) => Future.value(mockSettings)),
              ],
              child: MaterialApp(
                home: PaymentPage(paymentContext: testContext),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Open Lainnya sheet
          await tester.tap(find.text('Lainnya'));
          await tester.pumpAndSettle();

          // Dompet Digital should be visible
          expect(find.text('Dompet Digital'), findsOneWidget);

          // Transfer Bank should be hidden
          expect(find.text('Transfer Bank'), findsNothing);
          expect(find.text('BCA'), findsNothing);
          expect(find.text('Mandiri'), findsNothing);
        },
      );
    },
  );

  group('QRIS Static Image Dynamic Fetch & Error Fallback Tests', () {
    testWidgets(
      'QRIS modal renders dynamically fetched image URL with fallback to pattern',
      (tester) async {
        final mockSettings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'bank_transfer_enabled': true,
            'ewallet_enabled': true,
            'ewallet_providers': {'shopeepay': true},
            'qris_image_url': 'http://localhost:8000/api/v1/payment-settings/qris-image?business_id=1&branch_id=1',
          },
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(mockSettings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: testContext)),
          ),
        );

        await tester.pumpAndSettle();

        // Tap QRIS card
        await tester.tap(find.text('QRIS'));
        await tester.pumpAndSettle();

        // Verify QRIS STATIS modal is shown
        expect(find.text('QRIS STATIS'), findsOneWidget);
        expect(find.text('Rp 150.000'), findsOneWidget);
        expect(find.text('PROSES PEMBAYARAN'), findsOneWidget);

        // Verify that Image.network is rendered with the fetched URL
        final imageFinder = find.byType(Image);
        expect(imageFinder, findsOneWidget);
        final imageWidget = tester.widget<Image>(imageFinder);
        expect(imageWidget.image, isA<NetworkImage>());
        final networkImage = imageWidget.image as NetworkImage;
        expect(
          networkImage.url,
          equals(
            'http://localhost:8000/api/v1/payment-settings/qris-image?business_id=1&branch_id=1',
          ),
        );
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class FakeCashierRepoForPolishTest extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': true,
      'shift': {
        'id': 1,
        'status': 'open',
        'opening_cash_float': 50000.0,
      },
    };
  }
}

void main() {
  group('1. Model Creation Chained Bottom Sheet Polish Tests', () {
    testWidgets(
      'Renders centered success badge, bold model name, and single plus CTA label without duplicate plus',
      (tester) async {
        bool unitRegisteredTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    InventoryScreen.showModelCreatedBottomSheet(
                      context,
                      model: {
                        'id': 42,
                        'name': 'Sony FX3 Cinema Line',
                      },
                      onRegisterUnit: () {
                        unitRegisteredTapped = true;
                      },
                    );
                  },
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        );

        // Open bottom sheet
        await tester.tap(find.text('Open Sheet'));
        await tester.pumpAndSettle();

        // 1. Verify centered title
        expect(find.text('Model Berhasil Dibuat!'), findsOneWidget);

        // 2. Verify success badge icon
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

        // 3. Verify RichText containing bold model name 'Sony FX3 Cinema Line'
        final richTextFinder = find.byWidgetPredicate((widget) {
          if (widget is RichText) {
            final plainText = widget.text.toPlainText();
            return plainText.contains('Sony FX3 Cinema Line') &&
                plainText.contains('Langkah berikutnya:') &&
                plainText.contains('agar siap disewakan.');
          }
          return false;
        });
        expect(richTextFinder, findsOneWidget);

        // 4. Verify primary CTA label has NO double plus glitch (renders 'Daftarkan Unit Fisik Sekarang' once)
        final ctaButtonFinder = find.byKey(const Key('register_unit_now_button'));
        expect(ctaButtonFinder, findsOneWidget);
        expect(find.text('Daftarkan Unit Fisik Sekarang'), findsOneWidget);
        expect(find.text('+ + Daftarkan Unit Fisik Sekarang'), findsNothing);

        // 5. Verify tapping primary CTA invokes callback
        await tester.tap(ctaButtonFinder);
        await tester.pumpAndSettle();
        expect(unitRegisteredTapped, isTrue);
      },
    );
  });

  group('2. Payment Success Screen Polish Tests', () {
    final testContext = PaymentContext(
      transactionType: PaymentTransactionType.booking,
      customerName: 'Dimas Jois Vanka',
      customerPhone: '081234567890',
      deviceName: 'iPhone XR Hijau',
      bookingCode: 'RC-2610-20-0002',
      totalAmountDue: 200000.0,
      remainingDue: 200000.0,
      previouslyPaidAmount: 0.0,
      branchId: 1,
      branchName: 'Cabang Sukonatar',
    );

    testWidgets(
      'Cash Payment renders Tunai Diterima & Kembalian without LUNAS OTOMATIS badge',
      (tester) async {
        final cashResult = PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: 'TRX-CASH-001',
          receiptNumber: 'RCP-001',
          amountPaid: 200000.0,
          cashReceived: 250000.0,
          cashChange: 50000.0,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(FakeCashierRepoForPolishTest()),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value([
                  {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
                ]),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({'config': {'cash_enabled': true}}),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(
                paymentContext: testContext,
                initialResult: cashResult,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify subtitle simplification
        expect(find.text('Pembayaran sewa unit berhasil diselesaikan.'), findsOneWidget);
        expect(
          find.text('Transaksi Pembayaran Sewa Baru (Kontrak) berhasil diselesaikan.'),
          findsNothing,
        );

        // 2. Verify cash summary rows are rendered
        expect(find.text('Tunai Diterima'), findsOneWidget);
        expect(find.text('Rp 250.000'), findsOneWidget);
        expect(find.text('Kembalian'), findsOneWidget);
        expect(find.text('Rp 50.000'), findsOneWidget);

        // 3. Verify non-cash automatic badge is NOT rendered
        expect(find.text('LUNAS OTOMATIS'), findsNothing);

        // 4. Verify button hierarchy
        expect(find.widgetWithText(ElevatedButton, 'Cetak Struk Transaksi'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Selesai'), findsOneWidget);
      },
    );

    testWidgets(
      'QRIS Payment normalizes label to "QRIS Dinamis", hides cash breakdown, and displays Status: LUNAS OTOMATIS',
      (tester) async {
        final qrisResult = PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: 'TRX-QRIS-002',
          receiptNumber: 'RCP-002',
          amountPaid: 200000.0,
          cashReceived: 200000.0,
          cashChange: 0.0,
          paymentMethodCode: 'QRIS',
          paymentMethodName: 'QRIS Dinamis / Statis',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(FakeCashierRepoForPolishTest()),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value([
                  {'id': 2, 'code': 'QRIS', 'name': 'QRIS Dinamis / Statis', 'is_active': true},
                ]),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({'config': {'qris_statis_enabled': true}}),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(
                paymentContext: testContext,
                initialResult: qrisResult,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify subtitle
        expect(find.text('Pembayaran sewa unit berhasil diselesaikan.'), findsOneWidget);

        // 2. Verify normalized method display name
        expect(find.text('QRIS Dinamis'), findsOneWidget);
        expect(find.text('QRIS Dinamis / Statis'), findsNothing);

        // 3. Verify cash breakdown is HIDDEN
        expect(find.text('Tunai Diterima'), findsNothing);
        expect(find.text('Kembalian'), findsNothing);

        // 4. Verify automatic lunas badge is PRESENT
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('LUNAS OTOMATIS'), findsOneWidget);

        // 5. Verify action button hierarchy
        expect(find.widgetWithText(ElevatedButton, 'Cetak Struk Transaksi'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Selesai'), findsOneWidget);
      },
    );

    testWidgets(
      'Transfer Bank Payment hides cash breakdown and displays Status: LUNAS OTOMATIS',
      (tester) async {
        final transferResult = PaymentResult(
          status: PaymentStatus.completed,
          transactionCode: 'TRX-TRF-003',
          receiptNumber: 'RCP-003',
          amountPaid: 200000.0,
          cashReceived: 200000.0,
          cashChange: 0.0,
          paymentMethodCode: 'TRANSFER',
          paymentMethodName: 'Transfer Bank BCA',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(FakeCashierRepoForPolishTest()),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value([
                  {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank BCA', 'is_active': true},
                ]),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({'config': {'bank_transfer_enabled': true}}),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(
                paymentContext: testContext,
                initialResult: transferResult,
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify subtitle
        expect(find.text('Pembayaran sewa unit berhasil diselesaikan.'), findsOneWidget);

        // 2. Verify cash breakdown is HIDDEN
        expect(find.text('Tunai Diterima'), findsNothing);
        expect(find.text('Kembalian'), findsNothing);

        // 3. Verify automatic lunas badge is PRESENT
        expect(find.text('Status'), findsOneWidget);
        expect(find.text('LUNAS OTOMATIS'), findsOneWidget);

        // 4. Verify action button hierarchy
        expect(find.widgetWithText(ElevatedButton, 'Cetak Struk Transaksi'), findsOneWidget);
        expect(find.widgetWithText(OutlinedButton, 'Selesai'), findsOneWidget);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class _FakeCashierRepoForSelection extends CashierRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS Dinamis', 'code': 'QRIS', 'qris_image_url': 'http://rentcore.test/qris.png'},
      {'id': 3, 'name': 'Transfer Bank BCA', 'code': 'BCA'},
      {'id': 4, 'name': 'Transfer Bank Mandiri', 'code': 'MANDIRI'},
      {'id': 5, 'name': 'Transfer Bank BRI', 'code': 'BRI'},
      {'id': 6, 'name': 'Transfer Bank BNI', 'code': 'BNI'},
      {'id': 7, 'name': 'ShopeePay', 'code': 'SHOPEEPAY'},
      {'id': 8, 'name': 'DANA', 'code': 'DANA'},
      {'id': 9, 'name': 'GoPay', 'code': 'GOPAY'},
      {'id': 10, 'name': 'OVO', 'code': 'OVO'},
      {'id': 11, 'name': 'LinkAja', 'code': 'LINKAJA'},
    ];
  }
}

class _FakePaymentRepoForSelection extends PaymentRepository {
  int? lastPaymentMethodId;
  String? lastPaymentMethodCode;
  String? lastPaymentMethodName;

  _FakePaymentRepoForSelection() : super(cashierRepo: _FakeCashierRepoForSelection());

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
    lastPaymentMethodId = paymentMethodId;
    lastPaymentMethodCode = paymentMethodCode;
    lastPaymentMethodName = paymentMethodName;

    return PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'TX-TEST-SEL-001',
      receiptNumber: 'REC-TEST-SEL-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: 0.0,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
    );
  }
}

void main() {
  testWidgets('Selecting LinkAja e-wallet properly sets LINKAJA and executes payment with ID 11', (tester) async {
    final fakePaymentRepo = _FakePaymentRepoForSelection();

    final ctx = PaymentContext.booking(
      customerName: 'Budi Penyewa',
      customerPhone: '081234567890',
      deviceName: 'Sony A7 IV',
      totalAmount: 150000,
      branchId: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(_FakeCashierRepoForSelection()),
          paymentRepositoryProvider.overrideWithValue(fakePaymentRepo),
        ],
        child: MaterialApp(
          home: PaymentPage(paymentContext: ctx),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main screen renders Lainya card
    expect(find.text('Lainya'), findsOneWidget);

    // Tap "Lainya" to open Pembayaran Lainnya modal
    await tester.tap(find.text('Lainya'));
    await tester.pumpAndSettle();

    // Verify Modal Title and Sections
    expect(find.text('PEMBAYARAN LAINYA'), findsOneWidget);
    expect(find.text('E-Wallet'), findsOneWidget);
    expect(find.text('Transfer Bank'), findsOneWidget);

    // Verify Bank Transfer options exist
    expect(find.text('BCA'), findsOneWidget);
    expect(find.text('Mandiri'), findsOneWidget);
    expect(find.text('BRI'), findsOneWidget);
    expect(find.text('BNI'), findsOneWidget);

    // Tap "LinkAja!" e-wallet tile via key
    await tester.tap(find.byKey(const ValueKey('tile_LinkAja!')));
    await tester.pumpAndSettle();

    // Tap "PROSES PEMBAYARAN"
    await tester.tap(find.text('PROSES PEMBAYARAN'));
    await tester.pumpAndSettle();

    // Verify that the payment executed with LinkAja (NOT BCA / ID 3!)
    expect(fakePaymentRepo.lastPaymentMethodCode, 'LINKAJA');
    expect(fakePaymentRepo.lastPaymentMethodId, 11);
  });

  testWidgets('Selecting Mandiri bank transfer properly sets MANDIRI and executes payment with ID 4', (tester) async {
    final fakePaymentRepo = _FakePaymentRepoForSelection();

    final ctx = PaymentContext.booking(
      customerName: 'Siti Mandiri',
      customerPhone: '081234567891',
      deviceName: 'PlayStation 5 Slim',
      totalAmount: 200000,
      branchId: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(_FakeCashierRepoForSelection()),
          paymentRepositoryProvider.overrideWithValue(fakePaymentRepo),
        ],
        child: MaterialApp(
          home: PaymentPage(paymentContext: ctx),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap "Lainya"
    await tester.tap(find.text('Lainya'));
    await tester.pumpAndSettle();

    // Tap "Mandiri" under Transfer Bank
    await tester.tap(find.text('Mandiri'));
    await tester.pumpAndSettle();

    // Tap "PROSES PEMBAYARAN"
    await tester.tap(find.text('PROSES PEMBAYARAN'));
    await tester.pumpAndSettle();

    // Verify that the payment executed with Mandiri ID 4
    expect(fakePaymentRepo.lastPaymentMethodCode, 'MANDIRI');
    expect(fakePaymentRepo.lastPaymentMethodId, 4);
  });

  testWidgets('Cash Payment form renders TextFormField aligned with Customer Form styling', (tester) async {
    final ctx = PaymentContext.booking(
      customerName: 'Budi Tunai',
      customerPhone: '081234567892',
      deviceName: 'Fujifilm X-T5',
      totalAmount: 50000,
      branchId: 1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(_FakeCashierRepoForSelection()),
        ],
        child: MaterialApp(
          home: PaymentPage(paymentContext: ctx),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Open Tunai modal
    await tester.tap(find.text('Tunai'));
    await tester.pumpAndSettle();

    // Verify TextFormField with exact InputDecoration exists
    final fieldFinder = find.widgetWithText(TextFormField, 'Jumlah uang diterima *');
    expect(fieldFinder, findsOneWidget);

    final textField = tester.widget<TextField>(find.descendant(of: fieldFinder, matching: find.byType(TextField)));
    final decor = textField.decoration!;
    expect(decor.labelText, 'Jumlah uang diterima *');
    expect(decor.filled, true);
    expect(decor.border, isA<OutlineInputBorder>());
    final outlineBorder = decor.border as OutlineInputBorder;
    expect(outlineBorder.borderRadius, BorderRadius.circular(16));
  });
}

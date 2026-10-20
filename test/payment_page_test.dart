import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class _FakeCashierRepo extends CashierRepository {
  int? lastBookingId;
  int? lastPaymentMethodId;
  double? lastAmount;
  String? lastPaymentType;
  double? lastCashReceived;

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS Dinamis', 'code': 'QRIS'},
      {'id': 3, 'name': 'Transfer Bank', 'code': 'TRANSFER'},
    ];
  }

  @override
  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int paymentMethodId,
    double? amount,
    String? paymentType,
    double? cashReceived,
    String? notes,
    String? idempotencyKey,
  }) async {
    lastBookingId = bookingId;
    lastPaymentMethodId = paymentMethodId;
    lastAmount = amount;
    lastPaymentType = paymentType;
    lastCashReceived = cashReceived;

    return {
      'message': 'Payment successful',
      'transaction_code': 'TX-TEST-POS-001',
      'receipt_number': 'REC-TEST-POS-001',
      'cash_change': (cashReceived != null && amount != null && cashReceived >= amount) ? (cashReceived - amount) : 0.0,
      'payment': {
        'id': 501,
        'transaction_code': 'TX-TEST-POS-001',
        'receipt_number': 'REC-TEST-POS-001',
        'amount': amount,
        'type': paymentType,
      },
    };
  }
}

class _FakeBookingRepo extends BookingRepository {
  Map<String, dynamic>? lastRentalPayload;
  int? lastExtendBookingId;
  int? lastExtendHours;
  double? lastExtendFee;
  int? lastExtendPaymentMethodId;
  double? lastExtendCashReceived;

  @override
  Future<Map<String, dynamic>> createRental(Map<String, dynamic> payload) async {
    lastRentalPayload = payload;
    return {
      'id': 88,
      'booking_code': 'BK-RENT-NEW-001',
      'total_amount': payload['cash_received'] ?? 350000.0,
      'payments': [
        {
          'id': 1,
          'transaction_code': 'TX-RENT-001',
          'receipt_number': 'REC-RENT-001',
          'amount': 350000.0,
          'type': 'rental',
        }
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> extendRental(
    int bookingId,
    int additionalHours, {
    double? fee,
    int? paymentMethodId,
    double? cashReceived,
    String? notes,
  }) async {
    lastExtendBookingId = bookingId;
    lastExtendHours = additionalHours;
    lastExtendFee = fee;
    lastExtendPaymentMethodId = paymentMethodId;
    lastExtendCashReceived = cashReceived;

    return {
      'message': 'Extension recorded',
      'receipt_number': 'REC-EXT-001',
      'extension': {'id': 99, 'additional_hours': additionalHours},
      'payment': {
        'id': 2,
        'transaction_code': 'TX-EXT-001',
        'receipt_number': 'REC-EXT-001',
        'amount': fee ?? 90000.0,
        'cash_change': (cashReceived != null && fee != null && cashReceived >= fee) ? (cashReceived - fee) : 0.0,
      },
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;
}

void main() {
  final businessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Central Business',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Central Business',
        'membership': {'role': 'owner'},
        'branches': [
          {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
        ],
      },
    ],
  );

  group('Shared PaymentPage UI & Workflow Tests', () {
    late _FakeCashierRepo fakeCashierRepo;
    late _FakeBookingRepo fakeBookingRepo;

    setUp(() {
      fakeCashierRepo = _FakeCashierRepo();
      fakeBookingRepo = _FakeBookingRepo();
    });

    Widget createTestWidget(PaymentContext context, {bool isModal = false}) {
      return ProviderScope(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
          bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
          businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PaymentPage(
              paymentContext: context,
              isModal: isModal,
            ),
          ),
        ),
      );
    }

    testWidgets('1. Booking Payment: Renders summary, cash suggestions, calculates change, and completes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.booking(
        customerName: 'Dedi Kurniawan',
        customerPhone: '081298765432',
        deviceName: 'iPhone 15 Pro',
        totalAmount: 350000.0,
        extraPayload: {'collateral_type': 'KTP Asli'},
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Verify Header & Badge
      expect(find.text('TERMINAL KASIR POS'), findsOneWidget);
      expect(find.text('SEWA BARU'), findsOneWidget);
      expect(find.text('Dedi Kurniawan'), findsOneWidget);
      expect(find.text('iPhone 15 Pro'), findsOneWidget);

      // Verify Total Due is Rp 350.000
      expect(find.text('Rp 350.000'), findsAtLeastNWidgets(1));

      // Verify Cash Denomination Suggestions
      expect(find.widgetWithText(ActionChip, 'Rp 350.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 400.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 500.000'), findsOneWidget);

      // Tap Rp 400.000 suggestion chip
      await tester.tap(find.widgetWithText(ActionChip, 'Rp 400.000'));
      await tester.pumpAndSettle();

      // Verify Change is Rp 50.000
      expect(find.text('Kembalian Pelanggan:'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsAtLeastNWidgets(1));

      // Submit Payment
      final submitButton = find.widgetWithText(ElevatedButton, 'Konfirmasi Bayar (Rp 350.000) 🖨️');
      expect(submitButton, findsOneWidget);
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Booking Repo was called with payment details
      expect(fakeBookingRepo.lastRentalPayload, isNotNull);
      expect(fakeBookingRepo.lastRentalPayload!['payment_method_id'], 1);
      expect(fakeBookingRepo.lastRentalPayload!['cash_received'], 400000.0);

      // Verify Success Screen displayed
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
      expect(find.text('Cetak Struk Transaksi (ESC/POS)'), findsOneWidget);
      expect(find.text('Selesai'), findsOneWidget);
    });

    testWidgets('2. Late Return Penalty Payment: Authoritative penalty context, non-cash toggle, and submission', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.penalty(
        bookingId: 42,
        bookingCode: 'BK-LATE-042',
        customerName: 'Siti Rahma',
        deviceModel: 'iPad Air M2',
        penaltyDue: 75000.0,
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Verify Badge & Details
      expect(find.text('DENDA KETERLAMBATAN'), findsOneWidget);
      expect(find.text('Siti Rahma'), findsOneWidget);
      expect(find.text('iPad Air M2'), findsOneWidget);
      expect(find.text('Rp 75.000'), findsAtLeastNWidgets(1));

      // Switch to QRIS
      final qrisChip = find.widgetWithText(ChoiceChip, 'QRIS Dinamis');
      expect(qrisChip, findsOneWidget);
      await tester.tap(qrisChip);
      await tester.pumpAndSettle();

      // Verify cash suggestion chips disappear
      expect(find.widgetWithText(ActionChip, 'Rp 75.000'), findsNothing);
      expect(find.text('Kembalian Pelanggan:'), findsNothing);

      // Verify non-cash verification notice
      expect(find.textContaining('Konfirmasi pembayaran non-tunai'), findsOneWidget);

      // Submit QRIS Payment
      final submitButton = find.widgetWithText(ElevatedButton, 'Konfirmasi Bayar (Rp 75.000) 🖨️');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Cashier Repo was called with penalty type and QRIS method
      expect(fakeCashierRepo.lastBookingId, 42);
      expect(fakeCashierRepo.lastPaymentType, 'penalty');
      expect(fakeCashierRepo.lastPaymentMethodId, 2);
      expect(fakeCashierRepo.lastAmount, 75000.0);

      // Verify Success Screen
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
    });

    testWidgets('3. Additional Rental Time Payment: Correct duration label, fee calculation, and repository invocation', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.extension(
        bookingId: 15,
        bookingCode: 'BK-EXT-015',
        customerName: 'Ahmad Fauzi',
        deviceModel: 'MacBook Air M2',
        additionalHours: 6,
        extensionFee: 90000.0,
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Verify Header & Extension specifics
      expect(find.text('PERPANJANGAN'), findsOneWidget);
      expect(find.textContaining('6 Jam'), findsOneWidget);
      expect(find.text('MacBook Air M2'), findsOneWidget);
      expect(find.text('Rp 90.000'), findsAtLeastNWidgets(1));

      // Submit payment
      final submitButton = find.widgetWithText(ElevatedButton, 'Konfirmasi Bayar (Rp 90.000) 🖨️');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Booking Repo extendRental was called
      expect(fakeBookingRepo.lastExtendBookingId, 15);
      expect(fakeBookingRepo.lastExtendHours, 6);
      expect(fakeBookingRepo.lastExtendFee, 90000.0);
      expect(fakeBookingRepo.lastExtendPaymentMethodId, 1);

      // Verify Success Screen
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
    });

    testWidgets('4. Remaining Balance Settlement: Displays previously paid amount and guards against cash shortage', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.settlement(
        booking: {
          'id': 33,
          'booking_code': 'BK-BAL-033',
          'total_bill': 400000.0,
          'customer': {'name': 'Rian Santoso'},
          'items': [
            {
              'asset': {
                'asset_code': 'IP15-99',
                'model': {'name': 'iPhone 15 Pro'},
              }
            }
          ],
          'payments': [
            {'amount': 200000.0, 'type': 'dp'},
          ],
        },
        remainingDue: 200000.0,
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Verify Badge & Split Display
      expect(find.text('PELUNASAN SEWA'), findsOneWidget);
      expect(find.text('Sudah Terbayar'), findsOneWidget);
      expect(find.text('Rp 200.000'), findsAtLeastNWidgets(1));
      expect(find.text('SISA TAGIHAN SEWA'), findsOneWidget);

      // Clear cash received to 0 and verify shortage
      final cashInput = find.widgetWithText(TextField, 'Jumlah Uang Diterima (Rp)');
      await tester.enterText(cashInput, '150000');
      await tester.pumpAndSettle();

      // Verify Shortage warning appears
      expect(find.text('Kekurangan Uang:'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Verify submit button is disabled
      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'Uang Tunai Kurang (Rp 50.000)');
      expect(submitButtonFinder, findsOneWidget);
      final elevatedButton = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(elevatedButton.onPressed, isNull);

      // Now enter sufficient cash
      await tester.enterText(cashInput, '200000');
      await tester.pumpAndSettle();

      // Button becomes enabled
      final enabledButton = find.widgetWithText(ElevatedButton, 'Konfirmasi Bayar (Rp 200.000) 🖨️');
      expect(enabledButton, findsOneWidget);
      await tester.ensureVisible(enabledButton);
      await tester.tap(enabledButton);
      await tester.pumpAndSettle();

      // Verify Cashier Repo called for settlement
      expect(fakeCashierRepo.lastBookingId, 33);
      expect(fakeCashierRepo.lastPaymentType, 'settlement');
      expect(fakeCashierRepo.lastAmount, 200000.0);
    });
  });
}

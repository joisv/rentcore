import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class _FakeCashierRepo extends CashierRepository {
  int? lastBookingId;
  int? lastPaymentMethodId;
  double? lastAmount;
  String? lastPaymentType;
  double? lastCashReceived;

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
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

  int? lastAdjustBookingId;
  int? lastAdjustBookingItemId;
  String? lastAdjustDirection;
  int? lastAdjustHoursDelta;
  double? lastAdjustAdditionalFee;
  int? lastAdjustPaymentMethodId;
  double? lastAdjustCashReceived;

  @override
  Future<Map<String, dynamic>> adjustDuration({
    required int bookingId,
    int? bookingItemId,
    required String direction,
    required int hoursDelta,
    double? additionalFee,
    int? paymentMethodId,
    double? cashReceived,
    String? managerPin,
    String? reason,
    String? notes,
  }) async {
    lastAdjustBookingId = bookingId;
    lastAdjustBookingItemId = bookingItemId;
    lastAdjustDirection = direction;
    lastAdjustHoursDelta = hoursDelta;
    lastAdjustAdditionalFee = additionalFee;
    lastAdjustPaymentMethodId = paymentMethodId;
    lastAdjustCashReceived = cashReceived;

    return {
      'message': 'Adjustment recorded',
      'adjustment': {'id': 101, 'booking_item_id': bookingItemId, 'hours_delta': hoursDelta},
      'payment': {
        'id': 3,
        'transaction_code': 'TX-EXT-002',
        'receipt_number': 'REC-EXT-002',
        'amount': additionalFee ?? 50000.0,
        'cash_change': (cashReceived != null && additionalFee != null && cashReceived >= additionalFee) ? (cashReceived - additionalFee) : 0.0,
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

  group('Shared PaymentPage UI & Workflow Tests (User Review & Pay Design)', () {
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

    testWidgets('1. Booking Payment: Renders center amount, Detail Sewa sheet, cash sheet, and completes', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.booking(
        customerName: 'Dedi Kurniawan',
        customerPhone: '081298765432',
        customerAddress: 'Jl. Merdeka No. 10',
        deviceName: 'iPhone 15 Pro',
        totalAmount: 350000.0,
        extraPayload: {'collateral_type': 'KTP Asli'},
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Verify Header & Tagihan Sewa
      expect(find.text('Pembayaran  Sewa'), findsOneWidget);
      expect(find.text('Tagihan Sewa'), findsOneWidget);
      expect(find.text('Rp350.000'), findsOneWidget);
      expect(find.text('Detail Sewa'), findsOneWidget);

      // Verify 3 Payment Method Buttons
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Lainya'), findsOneWidget);

      // Tap "Detail Sewa" to open Detail Sewa bottom sheet
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      // Verify Detail Sewa Sheet Content
      expect(find.text('Dedi Kurniawan'), findsOneWidget);
      expect(find.text('iPhone 15 Pro'), findsOneWidget);
      expect(find.text('KONFIRMASI PEMBAYARAN'), findsOneWidget);

      // Tap "KONFIRMASI PEMBAYARAN" -> proceeds to Cash Sheet
      await tester.tap(find.text('KONFIRMASI PEMBAYARAN'));
      await tester.pumpAndSettle();

      // Verify PEMBAYARAN TUNAI Sheet
      expect(find.text('PEMBAYARAN TUNAI'), findsOneWidget);
      expect(find.text('Rp  350.000'), findsOneWidget);

      // Tap Rp 400.000 chip
      final chip400k = find.text('Rp 400.000');
      expect(chip400k, findsOneWidget);
      await tester.tap(chip400k);
      await tester.pumpAndSettle();

      // Verify Change is Rp 50.000
      expect(find.text('Kembalian Pelanggan'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsAtLeastNWidgets(1));

      // Tap PROSES PEMBAYARAN
      final submitButton = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      expect(submitButton, findsOneWidget);
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

    testWidgets('2. Late Return Penalty Payment: Unified screen 2 renders Tagihan Denda, QRIS bottom sheet, and submission', (tester) async {
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

      // Verify Header & Details in Universal Screen 2
      expect(find.text('Pembayaran Denda'), findsOneWidget);
      expect(find.text('Tagihan Denda'), findsOneWidget);
      expect(find.text('Rp75.000'), findsOneWidget);
      expect(find.text('Detail Denda'), findsOneWidget);

      // Verify 3 bottom method cards
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Lainya'), findsOneWidget);

      // Open Detail Denda sheet
      await tester.tap(find.text('Detail Denda'));
      await tester.pumpAndSettle();

      expect(find.text('Siti Rahma'), findsOneWidget);
      expect(find.textContaining('iPad Air M2'), findsOneWidget);

      // Close detail sheet by tapping KONFIRMASI PEMBAYARAN which opens cash sheet
      await tester.tap(find.text('KONFIRMASI PEMBAYARAN'));
      await tester.pumpAndSettle();

      // Submit payment via Cash sheet
      final submitButton = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Cashier Repo was called with penalty type and Cash method
      expect(fakeCashierRepo.lastBookingId, 42);
      expect(fakeCashierRepo.lastPaymentType, 'penalty');
      expect(fakeCashierRepo.lastPaymentMethodId, 1);
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

      // Verify Tagihan Sewa is Rp 90.000
      expect(find.text('Rp90.000'), findsOneWidget);

      // Tap Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('Ahmad Fauzi'), findsOneWidget);
      expect(find.text('MacBook Air M2'), findsOneWidget);
      expect(find.text('6 Jam'), findsOneWidget);

      // Submit payment via sheet
      final confirmBtn = find.text('KONFIRMASI PEMBAYARAN');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
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

    testWidgets('4. Remaining Balance Settlement: Displays amount and guards against cash shortage', (tester) async {
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

      expect(find.text('Rp200.000'), findsOneWidget);

      // Tap Tunai
      await tester.tap(find.text('Tunai'));
      await tester.pumpAndSettle();

      // Clear cash received to 150000 and verify shortage
      final cashInput = find.byType(TextField);
      await tester.enterText(cashInput, '150000');
      await tester.pumpAndSettle();

      // Verify Shortage warning appears
      expect(find.text('Kekurangan Uang:'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Verify submit button is disabled
      final submitButtonFinder = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      final elevatedButton = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(elevatedButton.onPressed, isNull);

      // Now enter sufficient cash
      await tester.enterText(cashInput, '200000');
      await tester.pumpAndSettle();

      // Button becomes enabled
      final enabledButton = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(enabledButton.onPressed, isNotNull);
      await tester.tap(submitButtonFinder);
      await tester.pumpAndSettle();

      // Verify Cashier Repo called for settlement
      expect(fakeCashierRepo.lastBookingId, 33);
      expect(fakeCashierRepo.lastPaymentType, 'settlement');
      expect(fakeCashierRepo.lastAmount, 200000.0);
    });

    testWidgets('5. Add-on Extension Payment: Passes booking_item_id and processes add-on payment correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.extension(
        bookingId: 20,
        bookingCode: 'BK-EXT-020',
        customerName: 'Siti Rahma',
        deviceModel: 'Tripod Bluetooth',
        additionalHours: 12,
        extensionFee: 50000.0,
        extraPayload: {'booking_item_id': 88},
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Tap Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('Tripod Bluetooth'), findsOneWidget);
      expect(find.text('12 Jam'), findsOneWidget);
      expect(find.text('Rp 50.000'), findsAtLeastNWidgets(1));

      // Submit payment
      await tester.tap(find.text('KONFIRMASI PEMBAYARAN'));
      await tester.pumpAndSettle();

      final submitButton = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify adjustDuration was called on booking repo with booking_item_id
      expect(fakeBookingRepo.lastAdjustBookingId, 20);
      expect(fakeBookingRepo.lastAdjustBookingItemId, 88);
      expect(fakeBookingRepo.lastAdjustDirection, 'increase');
      expect(fakeBookingRepo.lastAdjustHoursDelta, 12);
      expect(fakeBookingRepo.lastAdjustAdditionalFee, 50000.0);
      expect(fakeBookingRepo.lastAdjustPaymentMethodId, 1);

      // Verify Success Screen
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
    });

    testWidgets('6. Booking with single add-on: displays primary unit and add-on item with duration and subtotals', (tester) async {
      tester.view.physicalSize = const Size(600, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        const PaymentItem(
          name: 'iPhone 13 128GB — Midnight',
          assetCode: 'IPHONE-13-01',
          isAddon: false,
          durationText: '24 Jam',
          price: 150000.0,
        ),
        const PaymentItem(
          name: 'Power Bank Anker 10000mAh',
          assetCode: 'PB-ANKER-01',
          isAddon: true,
          durationText: '24 Jam',
          price: 25000.0,
        ),
      ];

      final context = PaymentContext.booking(
        customerName: 'Budi Santoso',
        customerPhone: '08123456789',
        deviceName: 'iPhone 13 128GB — Midnight',
        assetCode: 'IPHONE-13-01',
        totalAmount: 175000.0,
        items: items,
        primarySubtotal: 150000.0,
        addonSubtotal: 25000.0,
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      expect(find.text('Rp175.000'), findsOneWidget);

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      // Verify Primary Device
      expect(find.text('iPhone 13 128GB — Midnight'), findsOneWidget);

      // Verify Add-on Item
      expect(find.text('Power Bank Anker 10000mAh'), findsOneWidget);
      expect(find.text('add-on'), findsOneWidget);

      // Verify Subtotals Breakdown
      expect(find.text('Durasi Sewa'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rp 175.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('7. Booking with multiple add-ons: displays primary unit and all add-on items cleanly', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        const PaymentItem(
          name: 'iPhone 13 128GB — Midnight',
          assetCode: 'IPHONE-13-01',
          isAddon: false,
          durationText: '24 Jam',
          price: 150000.0,
        ),
        const PaymentItem(
          name: 'Power Bank Anker 10000mAh',
          assetCode: 'PB-ANKER-01',
          isAddon: true,
          durationText: '24 Jam',
          price: 25000.0,
        ),
        const PaymentItem(
          name: 'Fast Charger 67W',
          assetCode: 'CHG-BASEUS-01',
          isAddon: true,
          durationText: '24 Jam',
          price: 15000.0,
        ),
      ];

      final context = PaymentContext.booking(
        customerName: 'Budi Santoso',
        deviceName: 'iPhone 13 128GB — Midnight',
        totalAmount: 190000.0,
        items: items,
        primarySubtotal: 150000.0,
        addonSubtotal: 40000.0,
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      // All items appear
      expect(find.text('iPhone 13 128GB — Midnight'), findsOneWidget);
      expect(find.text('Power Bank Anker 10000mAh'), findsOneWidget);
      expect(find.text('Fast Charger 67W'), findsOneWidget);
      expect(find.text('add-on'), findsNWidgets(2));

      // Subtotals & totals
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rp 190.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('8. Booking with voucher discount: displays discount row and reconciles total', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final items = [
        const PaymentItem(
          name: 'iPhone 13 128GB',
          assetCode: 'IPHONE-13-01',
          isAddon: false,
          durationText: '24 Jam',
          price: 150000.0,
        ),
        const PaymentItem(
          name: 'Power Bank',
          assetCode: 'PB-01',
          isAddon: true,
          durationText: '24 Jam',
          price: 25000.0,
        ),
      ];

      final context = PaymentContext.booking(
        customerName: 'Budi Santoso',
        deviceName: 'iPhone 13 128GB',
        totalAmount: 160000.0,
        items: items,
        primarySubtotal: 150000.0,
        addonSubtotal: 25000.0,
        discountAmount: 15000.0,
        voucherCode: 'DISKON15K',
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      // Voucher discount: - Rp 15.000
      expect(find.text('Diskon'), findsOneWidget);
      expect(find.text('- Rp 15.000'), findsOneWidget);

      // Final total: 160.000
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rp 160.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('9. PaymentContext.settlement: extracts all items and add-ons from booking data', (tester) async {
      tester.view.physicalSize = const Size(600, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final bookingData = {
        'id': 55,
        'booking_code': 'BK-SETTLE-055',
        'total_bill': 190000.0,
        'primary_subtotal': 150000.0,
        'addon_subtotal': 40000.0,
        'customer': {'name': 'Andi Pratama', 'phone': '0811112222'},
        'items': [
          {
            'id': 101,
            'item_type': 'primary',
            'unit_price': 150000.0,
            'duration_value': 24,
            'duration_unit': 'Jam',
            'asset': {
              'asset_code': 'IP13-01',
              'model': {'name': 'iPhone 13 128GB', 'is_addon': false},
            },
          },
          {
            'id': 102,
            'item_type': 'addon',
            'unit_price': 40000.0,
            'duration_value': 24,
            'duration_unit': 'Jam',
            'asset': {
              'asset_code': 'ANKER-01',
              'model': {'name': 'Anker PowerCore', 'is_addon': true},
            },
          },
        ],
      };

      final context = PaymentContext.settlement(
        booking: bookingData,
        remainingDue: 190000.0,
      );

      expect(context.items.length, 2);
      expect(context.items[0].name, 'iPhone 13 128GB');
      expect(context.items[0].isAddon, false);
      expect(context.items[1].name, 'Anker PowerCore');
      expect(context.items[1].isAddon, true);

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('iPhone 13 128GB'), findsOneWidget);
      expect(find.text('Anker PowerCore'), findsOneWidget);
      expect(find.text('add-on'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('10. Fallback when items is empty: renders deviceName without crash', (tester) async {
      tester.view.physicalSize = const Size(600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final context = PaymentContext.booking(
        customerName: 'Dewi Lestari',
        deviceName: 'iPhone 14 Pro Max',
        assetCode: 'IP14-PRO-01',
        totalAmount: 200000.0,
        items: const [],
      );

      await tester.pumpWidget(createTestWidget(context));
      await tester.pumpAndSettle();

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('iPhone 14 Pro Max'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('Rp 200.000'), findsAtLeastNWidgets(1));
    });
  });
}

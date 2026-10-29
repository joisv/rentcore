import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/return_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';

class _FakeCashierRepositoryForReturn extends CashierRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
    ];
  }
}

class _FakeBookingRepositoryForReturn extends BookingRepository {
  int? processReturnBookingId;
  Map<String, dynamic>? processReturnPayload;
  int processReturnCallCount = 0;

  @override
  Future<Map<String, dynamic>> processReturn(int bookingId, Map<String, dynamic> returnData) async {
    processReturnCallCount++;
    processReturnBookingId = bookingId;
    processReturnPayload = returnData;

    final hasPayment = returnData.containsKey('penalty_payment_method_id');

    return {
      'id': 99,
      'booking_id': bookingId,
      'total_penalty': 30000.0,
      'late_fee': 30000.0,
      'damage_fee': 0.0,
      'condition_grade': returnData['condition_grade'] ?? 'A',
      'booking': {
        'id': bookingId,
        'status': 'returned',
        'payment_status': hasPayment ? 'paid' : 'partial',
        'payments': [
          if (hasPayment)
            {
              'id': 701,
              'transaction_code': 'TX-PEN-261026-0001-TEST',
              'receipt_number': 'REC-PEN-PST-261026-TEST',
              'amount': 30000.0,
              'type': 'penalty',
              'status': 'completed',
              'payment_method': {'id': returnData['penalty_payment_method_id'], 'name': 'Tunai'},
            }
        ],
      },
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  _TestBusinessNotifier(BusinessState state) : super() {
    this.state = state;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCashierRepositoryForReturn fakeCashierRepo;
  late _FakeBookingRepositoryForReturn fakeBookingRepo;

  final overdueBooking = {
    'id': 101,
    'booking_code': 'BK-LATE-101',
    'affiliate_id': 1,
    'business_id': 1,
    'status': 'rented',
    'payment_status': 'paid',
    'start_at': DateTime.now().subtract(const Duration(hours: 26)).toIso8601String(),
    'end_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(), // 3 hrs overdue - 1 hr grace = 2 hrs -> 30,000 penalty
    'total_bill': 150000.0,
    'collateral_storage_slot': 'Slot B-02',
    'customer': {
      'id': 1,
      'name': 'Rahmat Hidayat',
      'phone': '081234567890',
    },
    'items': [
      {
        'id': 1,
        'asset': {
          'id': 50,
          'asset_code': 'IP15-01',
          'model': {
            'id': 10,
            'brand': 'Apple',
            'name': 'iPhone 15 Pro',
            'requires_frp_check': true,
          },
        },
      },
    ],
  };

  final businessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Central Business',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Central Business',
        'branches': [
          {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
        ],
      },
    ],
  );

  setUp(() {
    fakeCashierRepo = _FakeCashierRepositoryForReturn();
    fakeBookingRepo = _FakeBookingRepositoryForReturn();
  });

  Widget buildTestScreen() {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
        businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(
            cashierRepo: fakeCashierRepo,
            bookingRepo: fakeBookingRepo,
          ),
        ),
      ],
      child: MaterialApp(
        home: ReturnWizardScreen(booking: overdueBooking),
      ),
    );
  }

  group('Late Return Penalty Settlement & Cancel Flow Tests', () {
    testWidgets('Pressing X button on PaymentPage cancels flow without completing return or persisting incomplete records', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Verify ReturnWizardScreen is rendered with penalty section
      expect(find.textContaining('PEMBAYARAN DENDA'), findsOneWidget);
      expect(find.text('Bayar Sekarang di Counter'), findsOneWidget);

      // Verify and toggle iCloud FRP switch (mandatory guard for iPhone)
      final frpSwitch = find.byType(SwitchListTile);
      expect(frpSwitch, findsOneWidget);
      await tester.tap(frpSwitch);
      await tester.pumpAndSettle();

      // Tap "Selesaikan Pengembalian & Ambil KTP"
      final submitReturnBtn = find.text('Selesaikan Pengembalian & Ambil KTP 📥');
      await tester.ensureVisible(submitReturnBtn);
      await tester.tap(submitReturnBtn);
      await tester.pumpAndSettle();

      // Verify that Shared PaymentPage opens
      expect(find.text('TERMINAL KASIR POS'), findsOneWidget);
      expect(find.text('BK-LATE-101'), findsAtLeastNWidgets(1));
      expect(find.text('DENDA KETERLAMBATAN'), findsOneWidget);

      // CRITICAL AUDIT CHECK: At this point, processReturn MUST NOT have been called yet!
      expect(fakeBookingRepo.processReturnCallCount, 0,
          reason: 'processReturn must NOT be called before payment confirmation!');

      // Staff presses the X button beside the AppBar in PaymentPage
      final closeButton = find.byTooltip('Batalkan Pembayaran');
      expect(closeButton, findsOneWidget);
      await tester.tap(closeButton);
      await tester.pumpAndSettle();

      // PaymentPage pops; ReturnWizardScreen receives cancellation
      // 1. processReturn must STILL NOT be called!
      expect(fakeBookingRepo.processReturnCallCount, 0,
          reason: 'processReturn must NOT execute when payment is cancelled via X button!');

      // 2. Warning snackbar is displayed informing staff that return was NOT processed
      expect(find.text('Pembayaran denda dibatalkan. Pengembalian unit belum diproses.'), findsOneWidget);

      // 3. User remains on ReturnWizardScreen (unit is still rented in backend)
      expect(find.byType(ReturnWizardScreen), findsOneWidget);
      expect(find.text('Unit Berhasil Kembali!'), findsNothing);
    });

    testWidgets('Completing payment on PaymentPage atomically records penalty and completes unit return', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Toggle iCloud FRP switch
      final frpSwitch = find.byType(SwitchListTile);
      await tester.tap(frpSwitch);
      await tester.pumpAndSettle();

      // Tap submit return
      final submitReturnBtn = find.text('Selesaikan Pengembalian & Ambil KTP 📥');
      await tester.ensureVisible(submitReturnBtn);
      await tester.tap(submitReturnBtn);
      await tester.pumpAndSettle();

      // PaymentPage is open
      expect(find.text('TERMINAL KASIR POS'), findsOneWidget);

      // Tap "Konfirmasi Bayar"
      final confirmPayBtn = find.widgetWithText(ElevatedButton, 'Konfirmasi Bayar (Rp 30.000)');
      await tester.ensureVisible(confirmPayBtn);
      await tester.tap(confirmPayBtn);
      await tester.pumpAndSettle();

      // Verify that processReturn was called atomically with payment method ID and cash received
      expect(fakeBookingRepo.processReturnCallCount, 1);
      expect(fakeBookingRepo.processReturnBookingId, 101);
      expect(fakeBookingRepo.processReturnPayload!['penalty_payment_method_id'], 1);
      expect(fakeBookingRepo.processReturnPayload!['cash_received'], 30000.0);

      // Verify Payment Success view is shown
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);

      // Tap "Selesai" button on payment page
      final selesaiPaymentBtn = find.text('Selesai');
      await tester.ensureVisible(selesaiPaymentBtn);
      await tester.tap(selesaiPaymentBtn);
      await tester.pumpAndSettle();

      // ReturnWizardScreen displays success dialog with paid penalty message
      expect(find.text('Unit Berhasil Kembali!'), findsOneWidget);
      expect(find.textContaining('Denda keterlambatan berhasil dibayar & tercatat di revenue'), findsOneWidget);
    });

    testWidgets('Deferred penalty (Bayar Nanti di Kasir) directly completes return without payment method', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildTestScreen());
      await tester.pumpAndSettle();

      // Toggle iCloud FRP switch
      final frpSwitch = find.byType(SwitchListTile);
      await tester.tap(frpSwitch);
      await tester.pumpAndSettle();

      // Select "Bayar Nanti di Kasir"
      final bayarNantiChip = find.text('Bayar Nanti di Kasir');
      await tester.ensureVisible(bayarNantiChip);
      await tester.tap(bayarNantiChip);
      await tester.pumpAndSettle();

      // Tap submit return
      final submitReturnBtn = find.text('Selesaikan Pengembalian & Ambil KTP 📥');
      await tester.ensureVisible(submitReturnBtn);
      await tester.tap(submitReturnBtn);
      await tester.pumpAndSettle();

      // Verify processReturn was called WITHOUT penalty_payment_method_id
      expect(fakeBookingRepo.processReturnCallCount, 1);
      expect(fakeBookingRepo.processReturnPayload!.containsKey('penalty_payment_method_id'), isFalse);

      // Verify success dialog reports penalty deferred to cashier
      expect(find.text('Unit Berhasil Kembali!'), findsOneWidget);
      expect(find.textContaining('Denda keterlambatan dicatat ke kasir (belum lunas)'), findsOneWidget);
    });
  });
}

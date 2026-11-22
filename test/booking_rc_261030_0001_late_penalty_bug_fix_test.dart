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
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class _FakeCashierRepoForLatePenalty extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
        'has_active_shift': true,
        'shift': {'id': 1, 'status': 'open'},
      };

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
    ];
  }
}

class _FakeBookingRepoForLatePenalty extends BookingRepository {
  int? lastProcessedBookingId;
  Map<String, dynamic>? lastProcessedPayload;
  int processReturnCalls = 0;

  @override
  Future<Map<String, dynamic>> processReturn(int bookingId, Map<String, dynamic> returnData, {String? idempotencyKey}) async {
    processReturnCalls++;
    lastProcessedBookingId = bookingId;
    lastProcessedPayload = returnData;

    return {
      'id': 27,
      'booking_id': bookingId,
      'late_minutes': 1700,
      'late_fee': 560000.0,
      'damage_fee': 0.0,
      'total_penalty': 560000.0,
      'condition_grade': returnData['condition_grade'] ?? 'A',
      'booking': {
        'id': bookingId,
        'booking_code': 'RC-261030-0001',
        'status': 'returned',
        'payment_status': 'paid',
        'payments': [
          {
            'id': 5080,
            'type': 'penalty',
            'amount': 560000.0,
            'cash_received': returnData['cash_received'] ?? 560000.0,
            'cash_change': 0.0,
            'status': 'completed',
            'payment_method': {'id': returnData['penalty_payment_method_id'], 'name': 'Tunai'},
          }
        ],
      },
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState) : super();

  @override
  BusinessState build() => _initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCashierRepoForLatePenalty fakeCashierRepo;
  late _FakeBookingRepoForLatePenalty fakeBookingRepo;

  // Booking RC-261030-0001 reproduction fixture:
  // Overdue by 28 hours (29 hours past end_at - 1 hour grace period = 28 billable hours @ Rp 20,000/hr = Rp 560,000).
  // Base rental already fully paid (total_bill: 280,000, payment_status: paid, remaining rental: 0).
  final bookingRC2610300001 = {
    'id': 67,
    'booking_code': 'RC-261030-0001',
    'business_id': 3,
    'affiliate_id': 5,
    'status': 'rented',
    'payment_status': 'paid',
    'total_bill': 280000.0,
    'subtotal_amount': 280000.0,
    'collateral_storage_slot': 'Brankas A, Slot 05',
    'start_at': DateTime.now().subtract(const Duration(hours: 53)).toIso8601String(),
    'end_at': DateTime.now().subtract(const Duration(hours: 29)).toIso8601String(), // 29h late - 1h grace = 28h billable @ 20,000 = 560,000
    'customer': {
      'id': 3,
      'name': 'Dedi Kurniawan',
      'phone': '081298765432',
      'address': 'Jl. Raya Genteng No. 128',
    },
    'active_item': {
      'rate_snapshot': {
        'extension_hourly_rate': 20000,
      },
    },
    'items': [
      {
        'id': 83,
        'rate_snapshot': {
          'extension_hourly_rate': 20000,
        },
        'asset': {
          'id': 8,
          'asset_code': 'FCHGTS42555',
          'model': {
            'id': 8,
            'brand': 'Apple',
            'name': 'iPhone 17 Pro Max',
            'requires_frp_check': true,
          },
        },
      },
    ],
    'payments': [
      {
        'id': 5066,
        'amount': 280000.0,
        'type': 'settlement',
        'status': 'completed',
        'payment_method': {'id': 1, 'name': 'Tunai'},
      },
    ],
  };

  final businessState = BusinessState(
    activeBusinessId: 3,
    activeBusinessName: 'RentCore Central Business',
    activeBranchId: 5,
    activeBranchName: 'Cabang Banyuwangi',
    businesses: [
      {
        'id': 3,
        'name': 'RentCore Central Business',
        'branches': [
          {'id': 5, 'name': 'Cabang Banyuwangi', 'is_central': true},
        ],
      },
    ],
  );

  setUp(() {
    fakeCashierRepo = _FakeCashierRepoForLatePenalty();
    fakeBookingRepo = _FakeBookingRepoForLatePenalty();
  });

  Widget buildReturnScreen({Map<String, dynamic>? customBooking}) {
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
        home: ReturnWizardScreen(booking: customBooking ?? bookingRC2610300001),
      ),
    );
  }

  group('Booking RC-261030-0001 Late Return Penalty Fix Verification', () {
    testWidgets('Preserves calculated late penalty Rp 560.000 on PaymentPage when base rental balance is 0', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(buildReturnScreen());
      await tester.pumpAndSettle();

      // Verify ReturnWizard calculates and displays Rp 560.000
      expect(find.textContaining('560.000'), findsWidgets);

      // Verify and toggle iCloud FRP switch for iPhone
      final frpSwitch = find.byType(SwitchListTile);
      expect(frpSwitch, findsOneWidget);
      await tester.tap(frpSwitch);
      await tester.pumpAndSettle();

      // Tap "Selesaikan Pengembalian"
      final submitReturnBtn = find.text('Selesaikan Pengembalian');
      await tester.ensureVisible(submitReturnBtn);
      await tester.tap(submitReturnBtn);
      await tester.pumpAndSettle();

      // CRITICAL ASSERTION:
      // PaymentPage MUST display Rp560.000 (NOT Rp 0)!
      expect(find.text('Pembayaran Denda'), findsOneWidget);
      expect(find.text('Tagihan Denda'), findsOneWidget);
      expect(find.text('Rp560.000'), findsOneWidget);
      expect(find.text('Rp0'), findsNothing);

      // Settle penalty via Tunai
      final tunaiCard = find.text('Tunai');
      await tester.ensureVisible(tunaiCard);
      await tester.tap(tunaiCard);
      await tester.pumpAndSettle();

      // Confirm cash received default is Rp 560.000
      expect(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'), findsOneWidget);
      await tester.tap(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'));
      await tester.pumpAndSettle();

      // Verify processReturn was invoked with late_fee: 560,000 and total_penalty: 560,000
      expect(fakeBookingRepo.processReturnCalls, 1);
      expect(fakeBookingRepo.lastProcessedBookingId, 67);
      expect(fakeBookingRepo.lastProcessedPayload!['late_fee'], 560000.0);
      expect(fakeBookingRepo.lastProcessedPayload!['total_penalty'], 560000.0);
      expect(fakeBookingRepo.lastProcessedPayload!['penalty_payment_method_id'], 1);
      expect(fakeBookingRepo.lastProcessedPayload!['cash_received'], 560000.0);

      // Verify payment success
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
      await tester.tap(find.text('Selesai'));
      await tester.pumpAndSettle();

      // Verify return completed dialog
      expect(find.text('Unit Berhasil Kembali'), findsOneWidget);
      expect(find.text('Kembalikan jaminan: Brankas A, Slot 05'), findsOneWidget);
      expect(find.textContaining('Denda keterlambatan berhasil dibayar & tercatat di revenue'), findsOneWidget);
    });

    testWidgets('PaymentContext.penalty guarantees Rp 560.000 even when booking contains stale return_inspection with total_penalty: 0', (tester) async {
      final bookingWithStaleZeroInspection = {
        ...bookingRC2610300001,
        'return_inspection': {
          'id': 1,
          'total_penalty': 0.0,
          'late_fee': 0.0,
        },
      };

      final ctx = PaymentContext.penalty(
        booking: bookingWithStaleZeroInspection,
        penaltyDue: 560000.0,
        extraPayload: {
          'is_return_workflow': true,
          'return_payload': {
            'late_fee': 560000.0,
            'total_penalty': 560000.0,
          },
        },
      );

      expect(ctx.remainingDue, 560000.0);
      expect(ctx.totalAmountDue, 560000.0);
      expect(ctx.items.first.price, 560000.0);
    });

    testWidgets('PaymentContext.penalty falls back to penalty_amount / late_fee keys in extraPayload if penaltyDue is 0', (tester) async {
      final ctx = PaymentContext.penalty(
        booking: bookingRC2610300001,
        penaltyDue: 0.0, // Simulating dropped direct argument
        extraPayload: {
          'is_return_workflow': true,
          'penalty_amount': 560000.0,
          'return_payload': {
            'late_fee': 560000.0,
          },
        },
      );

      expect(ctx.remainingDue, 560000.0);
      expect(ctx.totalAmountDue, 560000.0);
      expect(ctx.items.first.price, 560000.0);
    });
  });
}

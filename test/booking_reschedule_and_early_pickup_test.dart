import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/models/paginated_result.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeRescheduleCashierRepository extends CashierRepository {
  final List<Map<String, dynamic>> processedPayments = [];

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({
    int? branchId,
  }) async => [
    {'id': 1, 'name': 'Tunai', 'code': 'CASH', 'is_active': true},
  ];

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
    'has_active_shift': true,
    'shift': {'id': 9, 'branch_id': 1, 'status': 'open'},
  };

  @override
  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int paymentMethodId,
    double? cashReceived,
    double? amount,
    String? paymentType,
    String? notes,
    String? idempotencyKey,
    bool? frpCleared,
    bool? accountRemoved,
    bool? isHandoverSettlement,
    int? assetUnitId,
    String? collateralType,
    String? collateralStorageSlot,
    bool? startNow,
    bool? keepOriginalEndAt,
  }) async {
    final call = {
      'booking_id': bookingId,
      'payment_method_id': paymentMethodId,
      'amount': amount,
      'is_handover_settlement': isHandoverSettlement,
      'asset_unit_id': assetUnitId,
      'start_now': startNow,
      'keep_original_end_at': keepOriginalEndAt,
    };
    processedPayments.add(call);
    return {
      'payment': {
        'transaction_code': 'TX-EARLY-1',
        'receipt_number': 'REC-EARLY-1',
        'amount': amount ?? 0,
      },
      'receipt_number': 'REC-EARLY-1',
      'cash_change': 0,
      'handover_completed': true,
      'booking': {
        'id': bookingId,
        'status': 'rented',
        'payment_status': 'paid',
      },
    };
  }
}

class _FakeRescheduleBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> bookingsData;
  int rescheduleCalls = 0;
  DateTime? lastNewStartAt;
  bool? lastRescheduleKeepOriginalEndAt;
  bool shouldThrowConflictOnReschedule = false;

  int checkInCalls = 0;
  bool? lastCheckInStartNow;
  bool? lastCheckInKeepOriginalEndAt;
  bool? lastFetchUnitsStartNow;
  bool? lastFetchUnitsKeepOriginalEndAt;

  _FakeRescheduleBookingRepository(this.bookingsData);

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    if (status == null || status.isEmpty || status == 'all') {
      return bookingsData;
    }
    return bookingsData
        .where(
          (b) =>
              (b['status'] ?? '').toString().toLowerCase() ==
              status.toLowerCase(),
        )
        .toList();
  }

  @override
  Future<PaginatedResult<Map<String, dynamic>>> fetchBookingsPaginated({
    int page = 1,
    int perPage = 15,
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    final filtered = bookingsData.where((b) {
      if (status == null || status.isEmpty) return true;
      return b['status']?.toString().toLowerCase() == status.toLowerCase();
    }).toList();
    return PaginatedResult<Map<String, dynamic>>(
      items: filtered,
      currentPage: 1,
      lastPage: 1,
      total: filtered.length,
      perPage: perPage,
      hasMore: false,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableUnitsForBooking(
    dynamic bookingId, {
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    lastFetchUnitsStartNow = startNow;
    lastFetchUnitsKeepOriginalEndAt = keepOriginalEndAt;
    return [
      {
        'id': 41,
        'asset_code': 'IP15P-041',
        'serial_number': 'SN-041',
        'condition_grade': 'A',
        'battery_health': 99,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> rescheduleBooking(
    dynamic bookingId, {
    required DateTime newStartAt,
    bool keepOriginalEndAt = false,
  }) async {
    rescheduleCalls++;
    lastNewStartAt = newStartAt;
    lastRescheduleKeepOriginalEndAt = keepOriginalEndAt;
    if (shouldThrowConflictOnReschedule) {
      throw DioException(
        requestOptions: RequestOptions(path: '/bookings/$bookingId/reschedule'),
        response: Response(
          requestOptions: RequestOptions(path: '/bookings/$bookingId/reschedule'),
          statusCode: 422,
          data: {'message': 'Unit/slot model penuh pada jadwal baru tersebut.'},
        ),
      );
    }
    return {
      'id': bookingId,
      'status': 'booked',
      'start_at': newStartAt.toIso8601String(),
    };
  }

  @override
  Future<Map<String, dynamic>> checkInBooking(
    dynamic bookingId, {
    int? assetUnitId,
    String? collateralType,
    String? collateralStorageSlot,
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    checkInCalls++;
    lastCheckInStartNow = startNow;
    lastCheckInKeepOriginalEndAt = keepOriginalEndAt;
    return {'id': bookingId, 'status': 'rented'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  const businessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Flagship',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Flagship',
        'branches': [
          {
            'id': 1,
            'name': 'Cabang Pusat',
            'booking_grace_period_minutes': 60,
            'booking_auto_noshow': true,
            'allow_floating_unit_booking': true,
          },
        ],
      },
    ],
  );

  Map<String, dynamic> buildFutureNov20Booking({
    String paymentStatus = 'paid',
    double totalBill = 350000,
    double remainingBalance = 0,
  }) {
    return {
      'id': 881,
      'booking_code': 'RC-ADV-0881',
      'status': 'booked',
      'payment_status': paymentStatus,
      'total_bill': totalBill,
      'primary_subtotal': totalBill,
      'subtotal_amount': totalBill,
      'remaining_balance': remainingBalance,
      'duration_hours': 24,
      'start_at': '2026-11-20T18:00:00',
      'end_at': '2026-11-21T18:00:00',
      'grace_expires_at': '2026-11-20T19:00:00',
      'asset_unit_id': null,
      'asset_model': {
        'id': 10,
        'name': 'iPhone 15 Pro',
        'pricing_tiers': [
          {
            'duration_hours': 24,
            'price': 350000,
            'extension_hourly_rate': 25000,
          },
        ],
      },
      'customer': {'name': 'Dewi Lestari', 'phone': '08123456789'},
      'affiliate': {'id': 1, 'name': 'Cabang Pusat'},
      'payments': paymentStatus == 'paid'
          ? [
              {'type': 'settlement', 'amount': totalBill, 'status': 'completed'},
            ]
          : [],
    };
  }

  Widget buildApp({
    required _FakeRescheduleBookingRepository bookingRepo,
    required _FakeRescheduleCashierRepository cashierRepo,
  }) {
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(() => _FakeBusinessNotifier(businessState)),
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
        cashierRepositoryProvider.overrideWithValue(cashierRepo),
        paymentMethodsProvider.overrideWith(
          (ref) => Future.value([
            {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
          ]),
        ),
        paymentSettingsProvider(1).overrideWith(
          (ref) => Future.value({
            'config': {
              'cash_enabled': true,
              'qris_statis_enabled': false,
              'ewallet_enabled': false,
              'bank_transfer_enabled': false,
            },
          }),
        ),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(cashierRepo: cashierRepo, bookingRepo: bookingRepo),
        ),
      ],
      child: const MaterialApp(
        home: BookingsScreen(initialFilter: 'booked'),
      ),
    );
  }

  testWidgets(
    'Ubah Jadwal overflow action advances Nov 20 to Nov 18 via pickers, previews new dates, and surfaces 422 conflicts',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bookingRepo = _FakeRescheduleBookingRepository([
        buildFutureNov20Booking(),
      ]);
      bookingRepo.shouldThrowConflictOnReschedule = true;
      final cashierRepo = _FakeRescheduleCashierRepository();

      await tester.pumpWidget(
        buildApp(bookingRepo: bookingRepo, cashierRepo: cashierRepo),
      );
      await tester.pumpAndSettle();

      // Open overflow menu (⋮)
      await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
      await tester.pumpAndSettle();

      expect(find.text('Ubah Jadwal'), findsOneWidget);
      await tester.tap(find.byKey(const Key('overflow_reschedule_tile')));
      await tester.pumpAndSettle();

      // DatePicker is pre-filled at 20 Nov 2026 -> pick day 18
      await tester.tap(find.text('18'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // TimePicker opens -> confirm 18:00
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Konfirmasi Ubah Jadwal'), findsOneWidget);
      expect(
        find.text('Jadwal Baru: 18 Nov 2026, 18:00 • Selesai: 19 Nov 2026, 18:00'),
        findsOneWidget,
      );

      // First attempt hits HTTP 422 conflict -> message renders cleanly inside dialog
      await tester.tap(find.byKey(const Key('confirm_reschedule_button')));
      await tester.pumpAndSettle();

      expect(bookingRepo.rescheduleCalls, 1);
      expect(
        find.text('Unit/slot model penuh pada jadwal baru tersebut.'),
        findsOneWidget,
      );

      // Clear conflict mock & retry -> succeeds cleanly
      bookingRepo.shouldThrowConflictOnReschedule = false;
      await tester.tap(find.byKey(const Key('confirm_reschedule_button')));
      await tester.pumpAndSettle();

      expect(bookingRepo.rescheduleCalls, 2);
      expect(bookingRepo.lastNewStartAt?.day, 18);
      expect(bookingRepo.lastRescheduleKeepOriginalEndAt, isFalse);
      expect(find.text('Jadwal booking berhasil diperbarui.'), findsOneWidget);
    },
  );

  testWidgets(
    'Serahkan Unit detects early pickup for Nov 20 booking, defaults to Geser jadwal, and supports keeping original return date with extra settlement',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bookingRepo = _FakeRescheduleBookingRepository([
        buildFutureNov20Booking(
          paymentStatus: 'paid',
          totalBill: 350000,
          remainingBalance: 0,
        ),
      ]);
      final cashierRepo = _FakeRescheduleCashierRepository();

      await tester.pumpWidget(
        buildApp(bookingRepo: bookingRepo, cashierRepo: cashierRepo),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Serahkan Unit').first);
      await tester.pumpAndSettle();

      // Early pickup banner appears with both radio options
      expect(find.byKey(const Key('early_pickup_banner')), findsOneWidget);
      expect(find.text('Pengambilan Lebih Awal dari Jadwal'), findsOneWidget);
      expect(find.textContaining('Jadwal awal: 20 Nov 2026'), findsOneWidget);
      expect(find.text('Geser jadwal mulai sekarang'), findsOneWidget);
      expect(find.text('Mulai sekarang, batas kembali tetap'), findsOneWidget);

      // Default mode keeps bill = 0 remaining -> button is Serahkan Unit Sekarang
      expect(bookingRepo.lastFetchUnitsStartNow, isTrue);
      expect(bookingRepo.lastFetchUnitsKeepOriginalEndAt, isFalse);
      expect(find.text('Serahkan Unit Sekarang'), findsOneWidget);

      // Switching to "Mulai sekarang, batas kembali tetap" reloads units & calculates extra hours fee -> CTA switches to Lanjut ke Pembayaran
      await tester.tap(find.byKey(const Key('early_pickup_keep_end_option')));
      await tester.pumpAndSettle();

      expect(bookingRepo.lastFetchUnitsKeepOriginalEndAt, isTrue);
      expect(find.byKey(const Key('handover_remaining_balance_row')), findsOneWidget);
      expect(find.text('Lanjut ke Pembayaran'), findsOneWidget);

      // Switch back to default "Geser jadwal mulai sekarang" and complete direct check-in
      await tester.tap(find.byKey(const Key('early_pickup_shift_option')));
      await tester.pumpAndSettle();
      expect(find.text('Serahkan Unit Sekarang'), findsOneWidget);

      await tester.tap(find.byKey(const Key('confirm_checkin_button')));
      await tester.pumpAndSettle();

      expect(bookingRepo.checkInCalls, 1);
      expect(bookingRepo.lastCheckInStartNow, isTrue);
      expect(bookingRepo.lastCheckInKeepOriginalEndAt, isFalse);
    },
  );
}

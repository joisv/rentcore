import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/models/paginated_result.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/bookings_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeHandoverCashierRepository extends CashierRepository {
  Map<String, dynamic>? lastProcessedPaymentArgs;
  int processPaymentCalls = 0;

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
    'has_active_shift': true,
    'shift': {'id': 1, 'status': 'open'},
  };

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({
    int? branchId,
  }) async => [
    {'id': 1, 'name': 'Tunai', 'code': 'CASH', 'is_active': true},
    {'id': 2, 'name': 'QRIS', 'code': 'QRIS', 'is_active': true},
  ];

  @override
  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int? paymentMethodId,
    String? paymentMethodCode,
    double? cashReceived,
    double? amount,
    String? paymentType,
    String? notes,
    String? idempotencyKey,
    String? externalReference,
    bool? frpCleared,
    bool? accountRemoved,
    bool? isHandoverSettlement,
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool? startNow,
    bool? keepOriginalEndAt,
  }) async {
    processPaymentCalls++;
    lastProcessedPaymentArgs = {
      'booking_id': bookingId,
      'payment_method_id': paymentMethodId,
      'cash_received': cashReceived,
      'amount': amount,
      'payment_type': paymentType,
      'is_handover_settlement': isHandoverSettlement,
      'asset_unit_id': assetUnitId,
      'collateral_type': collateralType,
      'collateral_storage_slot': collateralStorageSlot,
      'start_now': startNow,
      'keep_original_end_at': keepOriginalEndAt,
    };
    return {
      'payment': {
        'transaction_code': 'TX-HANDOVER-1',
        'receipt_number': 'REC-HANDOVER-1',
        'amount': amount ?? 0,
      },
      'receipt_number': 'REC-HANDOVER-1',
      'cash_change': 0,
      'handover_completed': true,
      'booking': {
        'id': bookingId,
        'status': 'rented',
        'payment_status': 'paid',
        'remaining_balance': 0,
      },
    };
  }
}

class _FakeHandoverBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> bookings = [];
  int checkInCalls = 0;
  int? lastCheckedInBookingId;
  int? lastCheckedInUnitId;
  String? lastCheckedInSlot;

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    if (status == null || status == 'all') return bookings;
    return bookings
        .where((b) => (b['status'] ?? '').toString().toLowerCase() == status)
        .toList();
  }

  @override
  Future<PaginatedResult<Map<String, dynamic>>> fetchBookingsPaginated({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
    int page = 1,
    int perPage = 15,
  }) async {
    final filtered = await fetchBookings(
      status: status,
      search: search,
      branchId: branchId,
      allBranches: allBranches,
    );
    return PaginatedResult(
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
  }) async => [
    {
      'id': 33,
      'asset_code': 'IP15P-033',
      'serial_number': 'SN-033',
      'condition_grade': 'A',
      'battery_health': 100,
    },
  ];

  @override
  Future<Map<String, dynamic>> checkInBooking(
    dynamic bookingId, {
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    final parsedId = bookingId is int
        ? bookingId
        : int.tryParse(bookingId.toString());
    checkInCalls++;
    lastCheckedInBookingId = parsedId;
    lastCheckedInUnitId = assetUnitId;
    lastCheckedInSlot = collateralStorageSlot;
    return {'id': parsedId, 'status': 'rented'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const businessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Flagship',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Flagship',
        'enable_collateral': true,
        'require_collateral': false,
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

  Widget buildApp(
    _FakeHandoverBookingRepository bookingRepo,
    _FakeHandoverCashierRepository cashierRepo,
  ) {
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
        cashierRepositoryProvider.overrideWithValue(cashierRepo),
        paymentMethodsProvider.overrideWith(
          (ref) => Future.value([
            {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
            {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'is_active': true},
          ]),
        ),
        paymentSettingsProvider(1).overrideWith(
          (ref) => Future.value({
            'config': {
              'cash_enabled': true,
              'qris_statis_enabled': true,
              'ewallet_enabled': false,
              'bank_transfer_enabled': false,
            },
          }),
        ),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(cashierRepo: cashierRepo, bookingRepo: bookingRepo),
        ),
        businessProvider.overrideWith(() => _FakeBusinessNotifier(businessState)),
      ],
      child: const MaterialApp(home: BookingsScreen(initialFilter: 'booked')),
    );
  }

  group('Single-CTA Handover Sheet & Atomic Settlement Tests', () {
    testWidgets(
      'DP booking shows single Bayar & Serahkan Unit CTA, routes to PaymentPage with handover flags, and shows Pembayaran Lunas & Unit Diserahkan',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookingRepo = _FakeHandoverBookingRepository()
          ..bookings = [
            {
              'id': 501,
              'booking_code': 'RC-HO-DP-501',
              'status': 'booked',
              'payment_status': 'partial',
              'total_bill': 300000,
              'paid_amount': 100000,
              'remaining_balance': 200000,
              'asset_unit_id': null,
              'is_floating_unit': true,
              'collateral_type': 'KTP Asli',
              'collateral_storage_slot': 'Brankas A, Slot 04',
              'start_at': DateTime.now()
                  .add(const Duration(hours: 1))
                  .toIso8601String(),
              'grace_expires_at': DateTime.now()
                  .add(const Duration(hours: 2))
                  .toIso8601String(),
              'customer': {'name': 'Dewi Lestari', 'phone': '081234560001'},
              'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
              'items': [],
            },
          ];
        final cashierRepo = _FakeHandoverCashierRepository();

        await tester.pumpWidget(buildApp(bookingRepo, cashierRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Serahkan Unit'));
        await tester.pumpAndSettle();

        // Compact header & single icon-free primary CTA
        expect(
          find.text('Dewi Lestari • iPhone 15 Pro • RC-HO-DP-501'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('handover_grace_pill')), findsNothing);
        expect(find.byKey(const Key('confirm_checkin_button')), findsOneWidget);
        expect(find.text('Bayar & Serahkan Unit'), findsOneWidget);
        expect(find.text('Serahkan Unit Sekarang'), findsNothing);
        expect(find.text('Lanjut ke Pembayaran'), findsNothing);
        expect(find.text('Bayar Sisa Tagihan di Kasir'), findsNothing);
        expect(find.text('Cetak Slip'), findsNothing);
        expect(find.text('Rincian Booking'), findsNothing);

        // Read-only remaining balance row shown
        expect(
          find.byKey(const Key('handover_remaining_balance_row')),
          findsOneWidget,
        );
        expect(find.text('Sisa Tagihan'), findsOneWidget);
        expect(find.text('Rp 200.000'), findsOneWidget);

        // Pick floating unit and update collateral slot, then tap single CTA
        await tester.tap(find.byKey(const Key('checkin_unit_option_33')));
        await tester.enterText(
          find.byKey(const Key('handover_collateral_field')),
          'Brankas B, Slot 07',
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('confirm_checkin_button')));
        await tester.pumpAndSettle();

        // Now on PaymentPage for remaining Rp 200.000
        expect(find.text('Rp200.000'), findsOneWidget);
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'));
        await tester.pumpAndSettle();

        expect(find.text('Pembayaran Lunas & Unit Diserahkan'), findsOneWidget);
        expect(find.text('AKTIF DISEWA'), findsOneWidget);
        expect(bookingRepo.checkInCalls, 0);
        expect(cashierRepo.processPaymentCalls, 1);
        expect(cashierRepo.lastProcessedPaymentArgs!['booking_id'], 501);
        expect(cashierRepo.lastProcessedPaymentArgs!['amount'], 200000.0);
        expect(
          cashierRepo.lastProcessedPaymentArgs!['is_handover_settlement'],
          isTrue,
        );
        expect(cashierRepo.lastProcessedPaymentArgs!['asset_unit_id'], 33);
        expect(
          cashierRepo.lastProcessedPaymentArgs!['collateral_storage_slot'],
          'Brankas B, Slot 07',
        );
      },
    );

    testWidgets(
      'Fully paid booking shows single Serahkan Unit CTA and activates directly without PaymentPage',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookingRepo = _FakeHandoverBookingRepository()
          ..bookings = [
            {
              'id': 502,
              'booking_code': 'RC-HO-PAID-502',
              'status': 'booked',
              'payment_status': 'paid',
              'total_bill': 300000,
              'paid_amount': 300000,
              'remaining_balance': 0,
              'asset_unit_id': null,
              'is_floating_unit': true,
              'collateral_storage_slot': 'Brankas A, Slot 02',
              'start_at': DateTime.now()
                  .subtract(const Duration(minutes: 10))
                  .toIso8601String(),
              'grace_expires_at': DateTime.now()
                  .add(const Duration(minutes: 50))
                  .toIso8601String(),
              'customer': {'name': 'Rudi Hartono', 'phone': '081234560002'},
              'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
              'items': [],
            },
          ];
        final cashierRepo = _FakeHandoverCashierRepository();

        await tester.pumpWidget(buildApp(bookingRepo, cashierRepo));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Serahkan Unit'));
        await tester.pumpAndSettle();

        expect(
          find.text('Rudi Hartono • iPhone 15 Pro • RC-HO-PAID-502'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('handover_grace_pill')), findsOneWidget);
        expect(find.byKey(const Key('confirm_checkin_button')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('confirm_checkin_button')),
            matching: find.text('Serahkan Unit'),
          ),
          findsOneWidget,
        );
        expect(find.text('Bayar & Serahkan Unit'), findsNothing);
        expect(
          find.byKey(const Key('handover_remaining_balance_row')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('checkin_unit_option_33')));
        await tester.tap(find.byKey(const Key('confirm_checkin_button')));
        await tester.pumpAndSettle();

        expect(bookingRepo.checkInCalls, 1);
        expect(bookingRepo.lastCheckedInBookingId, 502);
        expect(bookingRepo.lastCheckedInUnitId, 33);
        expect(cashierRepo.processPaymentCalls, 0);
      },
    );
  });
}

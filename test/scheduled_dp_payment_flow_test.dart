import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/models/paginated_result.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Smartphones'},
  ];
}

class _FakeCashierRepository extends CashierRepository {
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
}

class _FakeBookingRepository extends BookingRepository {
  Map<String, dynamic>? lastCreatedPayload;
  int createRentalCalls = 0;
  List<Map<String, dynamic>> bookings = [];

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
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async => [
    {
      'id': 101,
      'asset_code': 'RC-IP15-01',
      'serial_number': 'SN99101',
      'status': 'ready',
      'model_id': 5,
      'model': {
        'id': 5,
        'brand': 'Apple',
        'name': 'iPhone 15 Pro',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphones'},
        'pricing_tiers': [
          {
            'id': 10,
            'duration_unit': 'day',
            'duration_value': 1,
            'duration_hours': 24,
            'price': 300000,
          },
        ],
      },
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchModelAvailability({
    required DateTime startAt,
    required DateTime endAt,
    int? branchId,
    int? categoryId,
    String? search,
  }) async => [
    {
      'id': 5,
      'name': 'iPhone 15 Pro',
      'brand': 'Apple',
      'total_units': 3,
      'booked_units': 1,
      'available_slots': 2,
      'category': {'id': 1, 'name': 'Smartphones'},
      'pricing_tiers': [
        {
          'id': 10,
          'duration_unit': 'day',
          'duration_value': 1,
          'duration_hours': 24,
          'price': 300000,
        },
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    createRentalCalls++;
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    final paid = (payload['paid_amount'] as num?)?.toDouble() ?? 0.0;
    return {
      'id': 777 + createRentalCalls,
      'booking_code': 'RC-DP-00$createRentalCalls',
      'status': payload['status'] ?? 'booked',
      'payment_status': paid < 300000 ? 'partial' : 'paid',
      'paid_amount': paid,
      'remaining_balance': (300000.0 - paid).clamp(0.0, 300000.0),
      'payments': [
        {
          'transaction_code': 'TX-DP-00$createRentalCalls',
          'receipt_number': 'REC-DP-00$createRentalCalls',
          'amount': paid,
          'type': 'dp',
        },
      ],
    };
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

  Widget buildApp(Widget home, _FakeBookingRepository repo) {
    final cashierRepo = _FakeCashierRepository();
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
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
          PaymentRepository(cashierRepo: cashierRepo, bookingRepo: repo),
        ),
        businessProvider.overrideWith(() => _FakeBusinessNotifier(businessState)),
      ],
      child: MaterialApp(home: home),
    );
  }

  Future<void> completeCustomerAndSelectDp(
    WidgetTester tester, {
    required String dpText,
  }) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('step2_name_field')),
      'Andi Wijaya',
    );
    await tester.enterText(
      find.byKey(const Key('step2_phone_field')),
      '081234567000',
    );
    await tester.enterText(
      find.byKey(const Key('step2_address_field')),
      'Jl. Gatot Subroto No. 8',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payment_option_dp')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('dp_amount_field')), dpText);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Simpan Booking'));
    await tester.pumpAndSettle();
  }

  group('Scheduled Booking DP Payment Flow Tests', () {
    testWidgets(
      'Floating unit scheduled DP via Tunai shows Total Sewa / DP / Sisa breakdown and completes as DP DIBAYAR',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeBookingRepository();
        await tester.pumpWidget(buildApp(const DirectRentalScreen(), repo));
        await tester.pumpAndSettle();

        // Pick schedule -> floating unit
        final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
        await tester.ensureVisible(scheduleTrigger);
        await tester.tap(scheduleTrigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('floating_model_card_5')));
        await tester.pumpAndSettle();

        await completeCustomerAndSelectDp(tester, dpText: '100000');

        // Main PaymentPage canvas stays clean: shows Nominal DP label, Rp100.000, Detail Sewa link, and zero breakdown card
        expect(find.byKey(const Key('payment_dp_breakdown_card')), findsNothing);
        expect(find.text('Nominal DP'), findsOneWidget);
        expect(find.text('Rp100.000'), findsOneWidget);
        expect(find.text('Total Sewa'), findsNothing);
        expect(find.text('Sisa Tagihan (Saat Ambil Unit)'), findsNothing);

        // Tapping "Detail Sewa" reveals full DP breakdown (300k total, 100k DP, 200k remaining)
        await tester.tap(find.text('Detail Sewa'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('detail_sheet_payment_breakdown')), findsOneWidget);
        expect(find.text('Total Sewa'), findsOneWidget);
        expect(find.text('Nominal DP Dibayar Sekarang'), findsOneWidget);
        expect(find.text('Sisa Tagihan (Saat Ambil Unit)'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('detail_sheet_payment_breakdown')),
            matching: find.text('Rp 300.000'),
          ),
          findsOneWidget,
        );
        expect(find.text('Rp 100.000'), findsOneWidget);
        expect(find.text('Rp 200.000'), findsOneWidget);

        // Close Detail Sewa sheet before tapping Tunai button
        Navigator.of(tester.element(find.byKey(const Key('detail_sheet_payment_breakdown')))).pop();
        await tester.pumpAndSettle();

        // Pay DP via Tunai
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'));
        await tester.pumpAndSettle();

        expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
        expect(find.text('DP DIBAYAR'), findsOneWidget);
        expect(find.text('LUNAS OTOMATIS'), findsNothing);
        expect(repo.createRentalCalls, 1);
        expect(repo.lastCreatedPayload!['status'], 'booked');
        expect(repo.lastCreatedPayload!['paid_amount'], 100000.0);
        expect(repo.lastCreatedPayload!['dp_amount'], 100000.0);
        expect(repo.lastCreatedPayload!['asset_ids'], isNull);
      },
    );

    testWidgets(
      'Pinned unit scheduled DP via QRIS completes without LUNAS OTOMATIS mislabel',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeBookingRepository();
        await tester.pumpWidget(buildApp(const DirectRentalScreen(), repo));
        await tester.pumpAndSettle();

        // Schedule & switch to Pinned physical unit
        final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
        await tester.ensureVisible(scheduleTrigger);
        await tester.tap(scheduleTrigger);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('toggle_pin_specific_unit')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('iPhone 15 Pro').first);
        await tester.pumpAndSettle();

        await completeCustomerAndSelectDp(tester, dpText: '100000');

        // Pay DP via QRIS
        await tester.tap(find.text('QRIS'));
        await tester.pumpAndSettle();
        expect(find.text('Rp 100.000'), findsWidgets);
        await tester.tap(find.byKey(const Key('qris_sheet_process_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
        expect(find.text('DP DIBAYAR'), findsOneWidget);
        expect(find.text('LUNAS OTOMATIS'), findsNothing);
        expect(repo.createRentalCalls, 1);
        expect(repo.lastCreatedPayload!['status'], 'booked');
        expect(repo.lastCreatedPayload!['asset_ids'], [101]);
        expect(repo.lastCreatedPayload!['paid_amount'], 100000.0);
      },
    );

    testWidgets(
      'BookingsScreen displays DP badge and remaining balance on booked partial card',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeBookingRepository()
          ..bookings = [
            {
              'id': 888,
              'booking_code': 'RC-DP-QUEUE-1',
              'status': 'booked',
              'payment_status': 'partial',
              'total_bill': 300000,
              'paid_amount': 100000,
              'remaining_balance': 200000,
              'is_floating_unit': true,
              'asset_unit_id': null,
              'start_at': DateTime.now()
                  .add(const Duration(days: 1))
                  .toIso8601String(),
              'grace_expires_at': DateTime.now()
                  .add(const Duration(days: 1, hours: 1))
                  .toIso8601String(),
              'customer': {'name': 'Andi Wijaya', 'phone': '081234567000'},
              'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
              'items': [],
            },
          ];

        await tester.pumpWidget(
          buildApp(const BookingsScreen(initialFilter: 'booked'), repo),
        );
        await tester.pumpAndSettle();

        expect(find.text('RC-DP-QUEUE-1'), findsOneWidget);
        expect(find.text('DP'), findsOneWidget);
        expect(find.text('Sisa: Rp 200.000'), findsOneWidget);
      },
    );
  });
}

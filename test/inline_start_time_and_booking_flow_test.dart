import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
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
  ];
}

class _FakeBookingRepository extends BookingRepository {
  int availabilityCalls = 0;
  int createRentalCalls = 0;
  Map<String, dynamic>? lastCreatedPayload;

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
  }) async {
    availabilityCalls++;
    return [
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
  }

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    createRentalCalls++;
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return {
      'id': 555,
      'booking_code': 'RC-BOOK-555',
      'status': payload['status'] ?? 'rented',
      'payments': [],
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

  Widget buildApp(_FakeBookingRepository repo) {
    final cashierRepo = _FakeCashierRepository();
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
        cashierRepositoryProvider.overrideWithValue(cashierRepo),
        paymentMethodsProvider.overrideWith(
          (ref) => Future.value([
            {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
          ]),
        ),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(
            cashierRepo: cashierRepo,
            bookingRepo: repo,
          ),
        ),
        businessProvider.overrideWith(() => _FakeBusinessNotifier(businessState)),
      ],
      child: const MaterialApp(home: DirectRentalScreen()),
    );
  }

  Future<void> fillCustomerAndGoToStep3(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('step2_name_field')),
      'Siti Aminah',
    );
    await tester.enterText(
      find.byKey(const Key('step2_phone_field')),
      '081234567899',
    );
    await tester.enterText(
      find.byKey(const Key('step2_address_field')),
      'Jl. Sudirman No. 20',
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();
  }

  group('Inline Waktu Mulai Selector & Dynamic Submit Flow Tests', () {
    testWidgets(
      'Removes top mode tab bar, renders inline Mulia Sekarang / Jadwalkan row, and supports immediate -> scheduled -> Sekarang reset',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeBookingRepository();
        await tester.pumpWidget(buildApp(repo));
        await tester.pumpAndSettle();

        // Top mode tab bar is completely removed
        expect(find.text('Sewa Langsung'), findsNothing);
        expect(find.text('Jadwalkan Booking'), findsNothing);
        expect(find.byKey(const Key('mode_direct_rental_tab')), findsNothing);
        expect(find.byKey(const Key('mode_scheduled_booking_tab')), findsNothing);

        // Form starts directly on Unit Selection & shows inline Waktu Mulai row
        expect(find.text('MODEL PERANGKAT'), findsOneWidget);
        expect(find.text('WAKTU MULAI'), findsOneWidget);
        expect(find.text('Mulai Sekarang'), findsOneWidget);
        expect(find.text('Jadwalkan ›'), findsOneWidget);
        expect(find.byIcon(Icons.access_time_rounded), findsOneWidget);

        // Tapping Jadwalkan opens Date -> Time picker and transitions to scheduled mode
        final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
        await tester.ensureVisible(scheduleTrigger);
        await tester.tap(scheduleTrigger);
        await tester.pumpAndSettle();

        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(repo.availabilityCalls, greaterThanOrEqualTo(1));
        expect(find.byIcon(Icons.event_rounded), findsOneWidget);
        expect(find.text('Booking Terjadwal'), findsOneWidget);
        expect(find.text('Sekarang'), findsOneWidget);
        expect(find.text('MODEL PERANGKAT'), findsOneWidget);
        expect(find.text('Tersedia 2 dari 3 unit'), findsOneWidget);

        // Reset via "Sekarang" returns seamlessly to immediate rental
        final resetBtn = find.byKey(const Key('inline_reset_now_action'));
        await tester.ensureVisible(resetBtn);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        expect(find.text('Mulai Sekarang'), findsOneWidget);
        expect(find.text('Jadwalkan ›'), findsOneWidget);
        expect(find.text('MODEL PERANGKAT'), findsOneWidget);

        // Immediate rental submits with "Buat Sewa" CTA and no scheduled payment selector
        await tester.tap(find.text('iPhone 15 Pro').first);
        await tester.pumpAndSettle();

        await fillCustomerAndGoToStep3(tester);

        expect(find.text('Bayar Lunas'), findsNothing);
        expect(find.text('Bayar DP'), findsNothing);
        expect(find.text('Bayar Saat Ambil'), findsNothing);
        expect(find.text('Buat Sewa'), findsOneWidget);
        expect(find.text('Simpan Booking'), findsNothing);

        // Complete immediate checkout after resetting from scheduled -> verify clean direct payload
        await tester.tap(find.text('Buat Sewa'));
        await tester.pumpAndSettle();

        expect(
          find.text('Pilih waktu dan tanggal di masa mendatang untuk booking terjadwal.'),
          findsNothing,
        );
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'));
        await tester.pumpAndSettle();

        expect(repo.createRentalCalls, 1);
        expect(repo.lastCreatedPayload!['is_scheduled'], false);
        expect(repo.lastCreatedPayload!['booking_mode'], 'direct');
        expect(repo.lastCreatedPayload!['start_at'], isNull);
        expect(repo.lastCreatedPayload!.containsKey('scheduled_start_at'), isFalse);
      },
    );

    testWidgets(
      'Scheduled mode reveals Bayar Lunas, Bayar DP, Bayar Saat Ambil and submits DP via Simpan Booking',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeBookingRepository();
        await tester.pumpWidget(buildApp(repo));
        await tester.pumpAndSettle();

        // Pick immediate unit first, then schedule via inline row -> should auto-sync floating model
        await tester.tap(find.text('iPhone 15 Pro').first);
        await tester.pumpAndSettle();

        final scheduleRow = find.byKey(const Key('inline_start_time_row'));
        await tester.ensureVisible(scheduleRow);
        await tester.tap(scheduleRow);
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        expect(find.text('Booking Terjadwal'), findsOneWidget);

        await fillCustomerAndGoToStep3(tester);

        expect(find.text('Simpan Booking'), findsOneWidget);
        expect(find.text('Buat Sewa'), findsNothing);
        expect(find.text('Bayar Lunas'), findsOneWidget);
        expect(find.text('Bayar DP'), findsOneWidget);
        expect(find.text('Bayar Saat Ambil'), findsOneWidget);

        // Select Bayar DP, enter custom DP nominal, and proceed to PaymentPage
        await tester.tap(find.byKey(const Key('payment_option_dp')));
        await tester.pumpAndSettle();

        await tester.enterText(find.byKey(const Key('dp_amount_field')), '100000');
        await tester.pumpAndSettle();
        expect(find.textContaining('Sisa saat ambil:'), findsOneWidget);

        await tester.tap(find.text('Simpan Booking'));
        await tester.pumpAndSettle();

        expect(find.text('Rp100.000'), findsOneWidget);
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN'));
        await tester.pumpAndSettle();

        expect(repo.createRentalCalls, 1);
        expect(repo.lastCreatedPayload!['status'], 'booked');
        expect(repo.lastCreatedPayload!['booking_mode'], 'scheduled');
        expect(repo.lastCreatedPayload!['paid_amount'], 100000.0);
        expect(repo.lastCreatedPayload!['asset_model_id'], 5);
      },
    );
  });
}

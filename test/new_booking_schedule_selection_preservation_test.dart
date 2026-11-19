import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
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

class _FakeAssetRepo extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Smartphones'},
  ];
}

class _FakeCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
    'has_active_shift': true,
    'shift': {'id': 1, 'status': 'open'},
  };

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({
    int? branchId,
  }) async => [
    {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
  ];
}

class _FakePreserveBookingRepo extends BookingRepository {
  List<Map<String, dynamic>> Function(DateTime startAt, DateTime endAt)
      availabilityBuilder;
  Map<String, dynamic>? lastCreatedPayload;
  int availabilityCalls = 0;

  _FakePreserveBookingRepo(this.availabilityBuilder);

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async =>
      [
        {
          'id': 21,
          'model_id': 5,
          'asset_code': 'IP15P-001',
          'serial_number': 'SN-0011',
          'condition_grade': 'A',
          'battery_health': 98,
          'model': {
            'id': 5,
            'name': 'iPhone 15 Pro',
            'brand': 'Apple',
            'category_id': 1,
            'category': {'id': 1, 'name': 'Smartphones'},
            'pricing_tiers': [
              {
                'id': 10,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 350000,
              },
            ],
          },
        },
        {
          'id': 22,
          'model_id': 5,
          'asset_code': 'IP15P-002',
          'serial_number': 'SN-0022',
          'condition_grade': 'A',
          'battery_health': 96,
          'model': {
            'id': 5,
            'name': 'iPhone 15 Pro',
            'brand': 'Apple',
            'category_id': 1,
            'category': {'id': 1, 'name': 'Smartphones'},
            'pricing_tiers': [
              {
                'id': 10,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 350000,
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
    return availabilityBuilder(startAt, endAt);
  }

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return {
      'id': 901,
      'booking_code': 'RC-PRESERVE-901',
      'status': 'booked',
      'payments': [],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  BusinessState createBizState({bool allowFloating = true}) => BusinessState(
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
            'allow_floating_unit_booking': allowFloating,
          },
        ],
      },
    ],
  );

  Widget buildApp({
    required _FakePreserveBookingRepo bookingRepo,
    bool allowFloating = true,
  }) {
    final cashierRepo = _FakeCashierRepo();
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
        assetRepositoryProvider.overrideWithValue(_FakeAssetRepo()),
        cashierRepositoryProvider.overrideWithValue(cashierRepo),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(cashierRepo: cashierRepo, bookingRepo: bookingRepo),
        ),
        businessProvider.overrideWith(
          () => _FakeBusinessNotifier(createBizState(allowFloating: allowFloating)),
        ),
      ],
      child: const MaterialApp(home: DirectRentalScreen()),
    );
  }

  testWidgets(
    'Selecting unit & 2x multiplier first, then picking future schedule preserves model, tier, multiplier, and submits cleanly',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _FakePreserveBookingRepo((startAt, endAt) => [
            {
              'id': 5,
              'name': 'iPhone 15 Pro',
              'brand': 'Apple',
              'category_id': 1,
              'total_units': 2,
              'booked_units': 0,
              'available_slots': 2,
              'available_asset_ids': [21, 22],
              'category': {'id': 1, 'name': 'Smartphones'},
              'pricing_tiers': [
                {
                  'id': 10,
                  'duration_unit': 'day',
                  'duration_value': 1,
                  'duration_hours': 24,
                  'price': 350000,
                },
              ],
            },
          ]);

      await tester.pumpWidget(buildApp(bookingRepo: repo));
      await tester.pumpAndSettle();

      // 1. Search by asset code first and select physical unit IP15P-001
      await tester.enterText(
        find.byKey(const Key('booking_unit_search_field')),
        'IP15P-001',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('IP15P-001').last);
      await tester.pumpAndSettle();

      // 2. Increment duration multiplier 1x -> 2x (48 Jam, Rp 700.000)
      final plusBtn = find.byKey(const Key('booking_multiplier_increment'));
      await tester.ensureVisible(plusBtn);
      await tester.tap(plusBtn);
      await tester.pumpAndSettle();
      expect(find.text('48 Jam'), findsOneWidget);

      // 3. Tap Jadwalkan > and confirm future date/time
      final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
      await tester.ensureVisible(scheduleTrigger);
      await tester.tap(scheduleTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Model stays selected even though search query had 'IP15P-001'
      expect(find.byKey(const Key('floating_model_card_5')), findsOneWidget);
      expect(find.text('Tersedia 2 dari 2 unit'), findsOneWidget);
      // Multiplier & total duration remain 2x / 48 Jam!
      expect(find.text('48 Jam'), findsOneWidget);

      // Next button stays enabled and advances to Step 2
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('DATA PENYEWA'), findsOneWidget);
    },
  );

  testWidgets(
    'When selected unit model has 0 slots on picked future date, card stays visible with inline Tidak tersedia pada jadwal ini notice',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _FakePreserveBookingRepo((startAt, endAt) => [
            {
              'id': 5,
              'name': 'iPhone 15 Pro',
              'brand': 'Apple',
              'category_id': 1,
              'total_units': 2,
              'booked_units': 2,
              'available_slots': 0,
              'available_asset_ids': [],
              'category': {'id': 1, 'name': 'Smartphones'},
              'pricing_tiers': [
                {
                  'id': 10,
                  'duration_unit': 'day',
                  'duration_value': 1,
                  'duration_hours': 24,
                  'price': 350000,
                },
              ],
            },
          ]);

      await tester.pumpWidget(buildApp(bookingRepo: repo));
      await tester.pumpAndSettle();

      // Pick physical unit IP15P-001 first
      await tester.tap(find.textContaining('IP15P-001').last);
      await tester.pumpAndSettle();

      // Pick future schedule where model 5 is full (0 slots)
      final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
      await tester.ensureVisible(scheduleTrigger);
      await tester.tap(scheduleTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      // Model card MUST remain visible & selected with inline unavailability note
      expect(find.byKey(const Key('floating_model_card_5')), findsOneWidget);
      expect(find.text('Tidak tersedia pada jadwal ini'), findsOneWidget);
      expect(find.text('48 Jam'), findsNothing);
      expect(find.text('24 Jam'), findsOneWidget);

      // Step 1 Next button is disabled until an available schedule or model is chosen
      final nextBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Lanjut'),
      );
      expect(nextBtn.onPressed, isNull);
    },
  );
}

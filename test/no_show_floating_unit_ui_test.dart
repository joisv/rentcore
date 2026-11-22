import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/booking_rules_settings_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeAuthRepository extends AuthRepository {
  Map<String, dynamic> rules = {
    'branch_id': 1,
    'booking_grace_period_minutes': 60,
    'booking_auto_noshow': true,
    'allow_floating_unit_booking': true,
  };
  Map<String, dynamic>? lastSavedRules;

  @override
  Future<Map<String, dynamic>> fetchBranchBookingRules(int branchId) async {
    return Map<String, dynamic>.from(rules);
  }

  @override
  Future<Map<String, dynamic>> updateBranchBookingRules(
    int branchId,
    Map<String, dynamic> payload,
  ) async {
    lastSavedRules = Map<String, dynamic>.from(payload);
    rules = {...rules, ...payload};
    return Map<String, dynamic>.from(rules);
  }
}

class _FakeAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Smartphones'},
  ];
}

class _FakeBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> bookings = [];
  List<Map<String, dynamic>> modelAvailability = [];
  List<Map<String, dynamic>> availableUnitsForCheckIn = [];

  int? lastCheckedInBookingId;
  int? lastCheckedInAssetUnitId;
  int? lastNoShowBookingId;
  Map<String, dynamic>? lastCreatedPayload;

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    if (status == null || status == 'all') return bookings;
    return bookings
        .where(
          (b) => (b['status'] ?? '').toString().toLowerCase() == status,
        )
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    return [
      {
        'id': 21,
        'model_id': 5,
        'asset_code': 'IP15P-001',
        'serial_number': 'SN-1111',
        'condition_grade': 'A',
        'battery_health': 98,
        'model': {
          'id': 5,
          'name': 'iPhone 15 Pro',
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
  }

  @override
  Future<List<Map<String, dynamic>>> fetchModelAvailability({
    required DateTime startAt,
    required DateTime endAt,
    int? branchId,
    int? categoryId,
    String? search,
  }) async {
    return modelAvailability;
  }

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return {
      'id': 999,
      'booking_code': 'RC-NEW-001',
      'status': payload['status'] ?? 'booked',
      'payments': [],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAvailableUnitsForBooking(
    dynamic bookingId, {
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    return availableUnitsForCheckIn;
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
    lastCheckedInBookingId = (bookingId as num).toInt();
    lastCheckedInAssetUnitId = assetUnitId;
    return {
      'id': bookingId,
      'status': 'rented',
      'asset_unit_id': assetUnitId,
    };
  }

  @override
  Future<Map<String, dynamic>> markNoShow(
    dynamic bookingId, {
    String? reason,
  }) async {
    lastNoShowBookingId = (bookingId as num).toInt();
    return {'id': bookingId, 'status': 'no_show'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  BusinessState createBusinessState() => BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Pusat',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Pusat',
        'role': 'owner',
        'branches': [
          {
            'id': 1,
            'name': 'Cabang Pusat',
            'code': 'PST',
            'is_central': true,
            'booking_grace_period_minutes': 60,
            'booking_auto_noshow': true,
            'allow_floating_unit_booking': true,
          },
        ],
      },
    ],
  );

  testWidgets('Pengaturan shows Aturan Booking & No-Show and saves rules', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final fakeAuthRepo = _FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          authProvider.overrideWith(
            () => _FakeAuthNotifier(
              const AuthState(
                user: {'id': 'u-1', 'name': 'Owner', 'role': 'owner'},
                isAuthenticated: true,
              ),
            ),
          ),
          businessProvider.overrideWith(
            () => _FakeBusinessNotifier(createBusinessState()),
          ),
        ],
        child: const MaterialApp(home: StoreSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kebijakan Booking & No-Show'), findsOneWidget);
    await tester.tap(find.byKey(const Key('menu_booking_policy')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('open_branch_booking_rules_link')));
    await tester.pumpAndSettle();

    expect(find.byType(BookingRulesSettingsScreen), findsOneWidget);
    expect(find.text('15 menit'), findsOneWidget);
    expect(find.text('30 menit'), findsOneWidget);
    expect(find.text('60 menit'), findsOneWidget);
    expect(find.text('120 menit'), findsOneWidget);

    await tester.tap(find.byKey(const Key('grace_period_chip_30')));
    await tester.tap(find.byKey(const Key('toggle_auto_noshow')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('save_booking_rules_button')));
    await tester.pumpAndSettle();

    expect(fakeAuthRepo.lastSavedRules, isNotNull);
    expect(fakeAuthRepo.lastSavedRules!['booking_grace_period_minutes'], 30);
    expect(fakeAuthRepo.lastSavedRules!['booking_auto_noshow'], false);
  });

  testWidgets(
    'DirectRentalScreen Jadwalkan Booking displays live floating model slots & submits floating booking',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeBookingRepo = _FakeBookingRepository()
        ..modelAvailability = [
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
                'price': 350000,
              },
            ],
          },
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
            assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(home: DirectRentalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to scheduled mode via inline Waktu Mulai row -> DatePicker -> TimePicker
      final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
      await tester.ensureVisible(scheduleTrigger);
      await tester.tap(scheduleTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text('Tersedia 2 dari 3 unit'), findsOneWidget);
      expect(
        find.byKey(const Key('toggle_pin_specific_unit')),
        findsOneWidget,
      );

      // Select floating model
      await tester.tap(find.byKey(const Key('floating_model_card_5')));
      await tester.pumpAndSettle();

      // Step 2: Customer
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('step2_name_field')),
        'Budi Scheduled',
      );
      await tester.enterText(
        find.byKey(const Key('step2_phone_field')),
        '081234567800',
      );
      await tester.enterText(
        find.byKey(const Key('step2_address_field')),
        'Jl. Merdeka No. 10 Jakarta',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      // Verify flexible scheduled payment options & enable pay later
      expect(find.text('Bayar Lunas'), findsOneWidget);
      expect(find.text('Bayar DP'), findsOneWidget);
      expect(find.text('Bayar Saat Ambil'), findsOneWidget);

      await tester.tap(find.byKey(const Key('toggle_scheduled_pay_later')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Simpan Booking'));
      await tester.pumpAndSettle();

      expect(fakeBookingRepo.lastCreatedPayload, isNotNull);
      expect(fakeBookingRepo.lastCreatedPayload!['booking_mode'], 'scheduled');
      expect(fakeBookingRepo.lastCreatedPayload!['asset_model_id'], 5);
      expect(fakeBookingRepo.lastCreatedPayload!['asset_ids'], isNull);
    },
  );

  testWidgets(
    'BookingsScreen shows grace badge on booked floating card, assigns unit on Serahkan Unit, and supports Tandai No-Show',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final futureGrace = DateTime.now().add(const Duration(minutes: 45));
      final fakeBookingRepo = _FakeBookingRepository()
        ..bookings = [
          {
            'id': 101,
            'booking_code': 'RC-FLOAT-101',
            'status': 'booked',
            'payment_status': 'paid',
            'paid_amount': 350000,
            'remaining_balance': 0,
            'total_bill': 350000,
            'asset_model_id': 5,
            'asset_unit_id': null,
            'is_floating_unit': true,
            'is_overdue_pickup': false,
            'start_at': DateTime.now().toIso8601String(),
            'end_at': DateTime.now()
                .add(const Duration(hours: 24))
                .toIso8601String(),
            'grace_expires_at': futureGrace.toIso8601String(),
            'customer': {'name': 'Rina Booking', 'phone': '081299001122'},
            'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
            'items': [],
          },
        ]
        ..availableUnitsForCheckIn = [
          {
            'id': 22,
            'asset_code': 'IP15P-002',
            'serial_number': 'SN-2222',
            'condition_grade': 'A',
            'battery_health': 99,
          },
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(
            home: BookingsScreen(initialFilter: 'booked'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('RC-FLOAT-101'), findsOneWidget);
      expect(find.text('Floating Unit • Belum Pilih SN'), findsOneWidget);
      expect(find.textContaining('Batas ambil:'), findsOneWidget);
      expect(find.text('Serahkan Unit'), findsOneWidget);

      // Open Serahkan Unit Check-In modal
      await tester.tap(find.text('Serahkan Unit'));
      await tester.pumpAndSettle();

      expect(find.text('IP15P-002'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkin_unit_option_22')));
      await tester.tap(find.byKey(const Key('confirm_checkin_button')));
      await tester.pumpAndSettle();

      expect(fakeBookingRepo.lastCheckedInBookingId, 101);
      expect(fakeBookingRepo.lastCheckedInAssetUnitId, 22);

      // Open overflow menu -> Tandai No-Show
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tandai No-Show'), findsOneWidget);
      await tester.tap(find.byKey(const Key('overflow_mark_noshow_tile')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konfirmasi No-Show'));
      await tester.pumpAndSettle();

      expect(fakeBookingRepo.lastNoShowBookingId, 101);
    },
  );
}

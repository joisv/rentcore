import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';

class _FakeBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> returnData = [];

  Map<String, dynamic>? lastAdjustPayload;
  int? lastAdjustBookingId;

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return returnData;
  }

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
    lastAdjustPayload = {
      'booking_item_id': bookingItemId,
      'direction': direction,
      'hours_delta': hoursDelta,
      'additional_fee': additionalFee,
      'payment_method_id': paymentMethodId,
      'cash_received': cashReceived,
      'manager_pin': managerPin,
      'reason': reason,
      'notes': notes,
    };
    return {
      'success': true,
      'message': 'Success',
      'data': {'id': bookingId},
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

void main() {
  group('Rental Duration Adjustment (Increase and Decrease) UI & Repository Tests', () {
    late _FakeBookingRepository fakeRepo;

    final dummyBookingWithAddon = {
      'id': 201,
      'booking_code': 'RC-ADJ-001',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'rented',
      'duration_hours': 48,
      'start_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 44)).toIso8601String(),
      'primary_subtotal': 280000.0,
      'addon_subtotal': 50000.0,
      'total_bill': 330000.0,
      'customer': {
        'id': 10,
        'name': 'Budi Hartono',
        'phone': '08123456789',
      },
      'payments': [
        {
          'id': 1,
          'type': 'settlement',
          'direction': 'inflow',
          'amount': 330000.0,
        }
      ],
      'items': [
        {
          'id': 11,
          'item_type': 'primary',
          'duration_value': 48,
          'unit_price': 280000.0,
          'asset': {
            'id': 101,
            'asset_code': 'AST-IP15-01',
            'model': {
              'id': 1,
              'name': 'iPhone 15 Pro',
              'pricing_tiers': [
                {'duration_hours': 12, 'price': 90000.0, 'is_active': true},
                {'duration_hours': 24, 'price': 150000.0, 'is_active': true},
                {'duration_hours': 48, 'price': 280000.0, 'is_active': true},
              ],
            },
          },
        },
        {
          'id': 12,
          'item_type': 'addon',
          'duration_value': 48,
          'unit_price': 50000.0,
          'asset': {
            'id': 102,
            'asset_code': 'AST-TRP-01',
            'model': {
              'id': 2,
              'name': 'Tripod Bluetooth',
              'pricing_tiers': [
                {'duration_hours': 24, 'price': 30000.0, 'is_active': true},
                {'duration_hours': 48, 'price': 50000.0, 'is_active': true},
              ],
            },
          },
        },
      ],
    };

    setUp(() {
      fakeRepo = _FakeBookingRepository();
      fakeRepo.returnData = [dummyBookingWithAddon];
    });

    Widget createTestWidget(WidgetTester tester) {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 1400);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final businessState = const BusinessState(
        activeBusinessId: 10,
        activeBusinessName: 'RentCore Store',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 10,
            'name': 'RentCore Store',
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat'},
            ],
          }
        ],
      );

      return ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
        ],
        child: const MaterialApp(
          home: BookingsScreen(),
        ),
      );
    }

    testWidgets('Opens Duration Adjustment Sheet and displays Primary Device and Add-on items', (tester) async {
      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      expect(find.text('RC-ADJ-001'), findsOneWidget);
      expect(find.text('Tambah Jam'), findsOneWidget);

      // Tap to open duration adjustment sheet
      await tester.tap(find.text('Tambah Jam'));
      await tester.pumpAndSettle();

      // Verify Header
      expect(find.text('Atur Durasi Sewa'), findsOneWidget);
      expect(find.text('Pelanggan: Budi Hartono'), findsOneWidget);

      // Verify Target Selector items
      expect(find.textContaining('Utama: iPhone 15 Pro'), findsOneWidget);
      expect(find.textContaining('Add-on: Tripod Bluetooth'), findsOneWidget);

      // Verify Direction buttons
      expect(find.text('+ Tambah Jam'), findsOneWidget);
      expect(find.text('- Kurangi Jam'), findsOneWidget);
    });

    testWidgets('Switching to Kurangi Jam on paid booking shows refund notice and requires Manager PIN', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah Jam'));
      await tester.pumpAndSettle();

      // Switch to Kurangi Jam
      await tester.tap(find.text('- Kurangi Jam'));
      await tester.pumpAndSettle();

      // Select 24 Jam reduction
      await tester.tap(find.ancestor(of: find.textContaining('24 Jam'), matching: find.byType(ChoiceChip)));
      await tester.pumpAndSettle();

      // Verify Refund banner appears because booking is paid 330k and reduction drops bill
      expect(find.textContaining('Pengembalian Dana (Refund)'), findsOneWidget);
      expect(find.text('PIN Manager *'), findsOneWidget);

      // Verify button is disabled or cannot submit without PIN
      final submitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pengurangan Durasi'),
      );
      expect(submitButton.onPressed, isNull);

      // Enter valid Manager PIN
      final pinFinder = find.byWidgetPredicate((w) => w is TextField && w.obscureText);
      await tester.enterText(pinFinder, '123456');
      await tester.pumpAndSettle();

      final activeSubmitButton = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Konfirmasi Pengurangan Durasi'),
      );
      expect(activeSubmitButton.onPressed, isNotNull);

      // Submit reduction
      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pengurangan Durasi'));
      await tester.pumpAndSettle();

      // Verify Repository invoked with decrease parameters
      expect(fakeRepo.lastAdjustBookingId, 201);
      expect(fakeRepo.lastAdjustPayload?['direction'], 'decrease');
      expect(fakeRepo.lastAdjustPayload?['hours_delta'], 24);
      expect(fakeRepo.lastAdjustPayload?['manager_pin'], '123456');
    });

    testWidgets('Targeting Add-on specifically sends booking_item_id to repository', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah Jam'));
      await tester.pumpAndSettle();

      // Select Add-on Tripod target
      await tester.tap(find.textContaining('Add-on: Tripod Bluetooth'));
      await tester.pumpAndSettle();

      // Switch to Kurangi Jam
      await tester.tap(find.text('- Kurangi Jam'));
      await tester.pumpAndSettle();

      // Select 24 Jam reduction
      await tester.tap(find.ancestor(of: find.textContaining('24 Jam'), matching: find.byType(ChoiceChip)));
      await tester.pumpAndSettle();

      // Enter Manager PIN
      final pinFinder = find.byWidgetPredicate((w) => w is TextField && w.obscureText);
      await tester.enterText(pinFinder, '999999');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Konfirmasi Pengurangan Durasi'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdjustBookingId, 201);
      expect(fakeRepo.lastAdjustPayload?['booking_item_id'], 12); // Add-on item ID
      expect(fakeRepo.lastAdjustPayload?['direction'], 'decrease');
      expect(fakeRepo.lastAdjustPayload?['hours_delta'], 24);
      expect(fakeRepo.lastAdjustPayload?['manager_pin'], '999999');
    });

    testWidgets('Extension without direct payment invokes adjustDuration with increase', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah Jam'));
      await tester.pumpAndSettle();

      // In increase mode, select 12 Jam
      await tester.tap(find.ancestor(of: find.textContaining('12 Jam'), matching: find.byType(ChoiceChip)));
      await tester.pumpAndSettle();

      // Tap 'Perpanjang Tanpa Bayar Langsung'
      await tester.tap(find.text('Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastAdjustBookingId, 201);
      expect(fakeRepo.lastAdjustPayload?['direction'], 'increase');
      expect(fakeRepo.lastAdjustPayload?['hours_delta'], 12);
    });

    testWidgets('Boundary check disables chips that would move deadline into past', (tester) async {
      // Booking that started 20 hours ago and has only 4 hours remaining
      final dummyNearExpiryBooking = {
        'id': 202,
        'booking_code': 'RC-NEAR-002',
        'affiliate_id': 1,
        'business_id': 10,
        'status': 'rented',
        'duration_hours': 24,
        'start_at': DateTime.now().subtract(const Duration(hours: 20)).toIso8601String(),
        'end_at': DateTime.now().add(const Duration(hours: 4)).toIso8601String(),
        'primary_subtotal': 150000.0,
        'total_bill': 150000.0,
        'customer': {'id': 11, 'name': 'Ahmad'},
        'payments': [],
        'items': [
          {
            'id': 21,
            'item_type': 'primary',
            'duration_value': 24,
            'unit_price': 150000.0,
            'asset': {
              'id': 103,
              'asset_code': 'AST-IP15-02',
              'model': {'id': 1, 'name': 'iPhone 15 Pro'},
            },
          },
        ],
      };

      fakeRepo.returnData = [dummyNearExpiryBooking];

      await tester.pumpWidget(createTestWidget(tester));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tambah Jam'));
      await tester.pumpAndSettle();

      // Switch to Kurangi Jam
      await tester.tap(find.text('- Kurangi Jam'));
      await tester.pumpAndSettle();

      // Chip for 6h reduction would make end_at 2 hours in the past!
      final chip6 = tester.widget<ChoiceChip>(find.ancestor(of: find.textContaining('6 Jam'), matching: find.byType(ChoiceChip)));
      expect(chip6.onSelected, isNull, reason: '6h reduction pushes deadline into past so chip must be disabled');

      // Chip for 24h reduction would also make end_at in past and reduce duration to 0!
      final chip24 = tester.widget<ChoiceChip>(find.ancestor(of: find.textContaining('24 Jam'), matching: find.byType(ChoiceChip)));
      expect(chip24.onSelected, isNull, reason: '24h reduction must be disabled');
    });
  });
}

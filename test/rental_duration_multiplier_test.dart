import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/utils/date_formatter.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/bookings_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';

class _FakeDurationMultiplierBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> returnData = [];
  int? lastBookingId;
  int? lastBookingItemId;
  String? lastDirection;
  int? lastHoursDelta;
  double? lastAdditionalFee;

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
    String? paymentMethodCode,
    double? cashReceived,
    String? managerPin,
    String? reason,
    String? notes,
    String? idempotencyKey,
  }) async {
    lastBookingId = bookingId;
    lastBookingItemId = bookingItemId;
    lastDirection = direction;
    lastHoursDelta = hoursDelta;
    lastAdditionalFee = additionalFee;
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
  group('Atur Durasi Sewa - Duration Multiplier Stepper', () {
    late _FakeDurationMultiplierBookingRepository fakeRepo;
    late DateTime baseEndAt;

    Map<String, dynamic> buildBooking({
      required DateTime endAt,
      int durationHours = 72,
      double totalBill = 280000.0,
    }) {
      return {
        'id': 501,
        'booking_code': 'RC-MULT-001',
        'affiliate_id': 1,
        'business_id': 10,
        'status': 'rented',
        'duration_hours': durationHours,
        'start_at': endAt
            .subtract(Duration(hours: durationHours))
            .toIso8601String(),
        'end_at': endAt.toIso8601String(),
        'total_bill': totalBill,
        'paid_amount': 0.0,
        'remaining_balance': totalBill,
        'customer_name': 'Budi',
        'customer_phone': '08123456789',
        'items': [
          {
            'id': 8801,
            'duration_hours': durationHours,
            'price': totalBill,
            'asset': {
              'id': 91,
              'name': 'iPhone 17 Pro Max',
              'asset_code': 'IP17-01',
              'model': {
                'id': 42,
                'name': 'iPhone 17 Pro Max',
                'pricing_tiers': [
                  {
                    'id': 11,
                    'duration_hours': 6,
                    'duration_value': 6,
                    'duration_unit': 'hour',
                    'price': 100000.0,
                    'is_active': true,
                  },
                  {
                    'id': 12,
                    'duration_hours': 24,
                    'duration_value': 1,
                    'duration_unit': 'day',
                    'price': 280000.0,
                    'is_active': true,
                  },
                ],
              },
            },
          },
        ],
      };
    }

    setUp(() {
      fakeRepo = _FakeDurationMultiplierBookingRepository();
      baseEndAt = DateTime.now().add(const Duration(hours: 72));
      fakeRepo.returnData = [buildBooking(endAt: baseEndAt)];
    });

    Widget createTestWidget() {
      const businessState = BusinessState(
        activeBusinessId: 10,
        activeBusinessName: 'RentCore Store',
        activeBranchId: 1,
        activeBranchName: 'Cabang Utama',
        businesses: [
          {
            'id': 10,
            'name': 'RentCore Store',
            'branches': [
              {'id': 1, 'name': 'Cabang Utama'},
            ],
          },
        ],
      );

      return ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(businessState),
          ),
        ],
        child: const MaterialApp(home: BookingsScreen()),
      );
    }

    testWidgets(
      '1 Hari (24 Jam) at 2x calculates 48 Jam, Rp 560.000, shifts deadline +48h, and submits multiplied payload',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam'));
        await tester.pumpAndSettle();

        expect(find.text('Jumlah Kelipatan'), findsOneWidget);
        expect(find.byKey(const Key('duration_multiplier_value')), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '1x',
        );

        // Select 1 Hari (24 Jam) • Rp 280.000
        await tester.tap(find.textContaining('1 Hari (24 Jam)'));
        await tester.pumpAndSettle();

        expect(find.text('Biaya Tambahan (24 Jam)'), findsOneWidget);

        // Tap increment '+' to 2x
        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.pumpAndSettle();

        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '2x',
        );
        expect(
          tester
              .widget<Text>(find.byKey(const Key('duration_multiplier_total_hours')))
              .data,
          '48 Jam',
        );
        expect(find.text('Biaya Tambahan (48 Jam)'), findsOneWidget);
        expect(find.text('Rp 560.000'), findsOneWidget);
        expect(find.text('Rp 840.000'), findsOneWidget);

        final expectedDeadline = DateFormatter.formatFull(
          baseEndAt.add(const Duration(hours: 48)),
        );
        expect(find.text(expectedDeadline), findsOneWidget);

        // Submit without direct payment (scroll button into view if needed)
        final submitFinder = find.text(
          'Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)',
        );
        await tester.ensureVisible(submitFinder);
        await tester.tap(submitFinder);
        await tester.pumpAndSettle();

        expect(fakeRepo.lastBookingId, 501);
        expect(fakeRepo.lastBookingItemId, 8801);
        expect(fakeRepo.lastDirection, 'increase');
        expect(fakeRepo.lastHoursDelta, 48);
        expect(fakeRepo.lastAdditionalFee, 560000.0);
      },
    );

    testWidgets(
      'Resets multiplier to 1x when switching rate chip or direction mode, and clamps decrement at 1x',
      (tester) async {
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam'));
        await tester.pumpAndSettle();

        // Decrement at 1x stays 1x
        await tester.tap(find.byKey(const Key('duration_multiplier_decrement')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '1x',
        );

        // Increment to 3x on 6 Jam chip
        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '3x',
        );
        expect(find.text('Biaya Tambahan (18 Jam)'), findsOneWidget);

        // Switch rate package chip -> resets to 1x
        await tester.tap(find.textContaining('1 Hari (24 Jam)'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '1x',
        );
        expect(find.text('Biaya Tambahan (24 Jam)'), findsOneWidget);

        // Increment back to 2x then toggle to '- Kurangi Jam' -> resets to 1x
        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '2x',
        );

        await tester.tap(find.text('- Kurangi Jam'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '1x',
        );
        expect(find.text('Potongan Biaya (24 Jam)'), findsOneWidget);
      },
    );

    testWidgets(
      'Clamps increment in - Kurangi Jam mode so reduced hours cannot exceed remaining active rental duration',
      (tester) async {
        // 72h booking: remaining ~71h -> with 24h option, max multiplier in decrease mode is 2x (48h <= 71h)
        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('- Kurangi Jam'));
        await tester.pumpAndSettle();

        await tester.tap(find.textContaining('1 Hari (24 Jam)'));
        await tester.pumpAndSettle();

        // Tap + twice: reaches 2x (48 Jam), third tap is clamped at 2x
        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '2x',
        );
        expect(find.text('Potongan Biaya (48 Jam)'), findsOneWidget);

        await tester.tap(find.byKey(const Key('duration_multiplier_increment')));
        await tester.pumpAndSettle();
        expect(
          tester.widget<Text>(find.byKey(const Key('duration_multiplier_value'))).data,
          '2x',
        );
      },
    );

    testWidgets(
      'Renders stepper without RenderFlex overflow on compact 320x568 viewport',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam'));
        await tester.pumpAndSettle();

        expect(find.text('Jumlah Kelipatan'), findsOneWidget);
        expect(find.byKey(const Key('duration_multiplier_value')), findsOneWidget);
      },
    );
  });
}

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
    {'id': 2, 'name': 'Aksesoris'},
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
  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async => [
    {
      'id': 101,
      'asset_code': 'RC-IP15-01',
      'serial_number': 'SN99101',
      'condition_grade': 'A',
      'status': 'ready',
      'model_id': 5,
      'model': {
        'id': 5,
        'brand': 'Apple',
        'name': 'iPhone 15 Pro Max',
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
    {
      'id': 201,
      'asset_code': 'RC-PB-01',
      'condition_grade': 'A',
      'status': 'ready',
      'model_id': 9,
      'model': {
        'id': 9,
        'brand': 'Anker',
        'name': 'Anker MagGo 10000mAh',
        'is_addon': true,
        'category_id': 2,
        'category': {'id': 2, 'name': 'Aksesoris', 'is_addon': true},
        'pricing_tiers': [
          {
            'id': 20,
            'duration_unit': 'day',
            'duration_value': 1,
            'duration_hours': 24,
            'price': 25000,
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
      'name': 'iPhone 15 Pro Max',
      'brand': 'Apple',
      'total_units': 4,
      'booked_units': 1,
      'available_slots': 3,
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

  Widget buildApp({Map<String, dynamic>? customer}) {
    final bookingRepo = _FakeBookingRepository();
    final cashierRepo = _FakeCashierRepository();
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookingRepo),
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
            bookingRepo: bookingRepo,
          ),
        ),
        businessProvider.overrideWith(() => _FakeBusinessNotifier(businessState)),
      ],
      child: MaterialApp(
        home: DirectRentalScreen(
          showAppBar: false,
          customer: customer,
        ),
      ),
    );
  }

  group('DirectRentalScreen UI/UX Polish Tests', () {
    testWidgets(
      'Stepper labels, compact floating model rows, single-row package+multiplier, 42px voucher, addon 2-row layout, and Step 3 compact summary + 46px bottom bar render cleanly without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 760);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);

        try {
          await tester.pumpWidget(
            buildApp(
              customer: {
                'id': 1,
                'name': 'Dedi Kurniawan',
                'phone': '081234567890',
                'address': 'Jl. Sudirman No. 12, Jakarta',
              },
            ),
          );
          await tester.pumpAndSettle();

          // 1. Stepper header shortened labels without ellipsis
          expect(find.text('1. Unit'), findsOneWidget);
          expect(find.text('2. Penyewa'), findsOneWidget);
          expect(find.text('3. Ringkasan'), findsOneWidget);
          for (final label in ['1. Unit', '2. Penyewa', '3. Ringkasan']) {
            final t = tester.widget<Text>(find.text(label));
            expect(t.overflow, isNot(TextOverflow.ellipsis));
          }

          // Transition to Scheduled Floating Model mode
          final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
          await tester.ensureVisible(scheduleTrigger);
          await tester.tap(scheduleTrigger);
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('OK'));
          await tester.pumpAndSettle();

          // 2. Clean micro-header "MODEL PERANGKAT" & single subtitle string without double pills
          expect(find.text('MODEL PERANGKAT'), findsOneWidget);
          expect(find.text('DURASI & JADWAL'), findsOneWidget);

          // Select floating model card
          final modelCard = find.byKey(const Key('floating_model_card_5'));
          await tester.ensureVisible(modelCard);
          await tester.tap(modelCard);
          await tester.pumpAndSettle();
          expect(find.text('Model Dipilih'), findsNothing);
          expect(find.text('Tersedia 3 dari 4 unit'), findsOneWidget);

          // 3. Combined Start Time & Estimated Return block + 1-row Package & Multiplier + 42px Voucher
          expect(find.byKey(const Key('inline_reset_now_action')), findsOneWidget);
          expect(find.textContaining('Kembali:'), findsOneWidget);

          final chipFinder = find.widgetWithText(ChoiceChip, '1 Hari (24 Jam)');
          final stepperFinder = find.byKey(const Key('booking_multiplier_value'));
          await tester.ensureVisible(chipFinder);
          final chipRect = tester.getRect(chipFinder);
          final stepperRect = tester.getRect(stepperFinder);
          expect((chipRect.center.dy - stepperRect.center.dy).abs(), lessThan(16.0));
          expect(stepperRect.left, greaterThan(chipRect.right));

          final voucherFieldFinder = find.widgetWithText(TextField, 'Kode voucher...');
          final applyBtnFinder = find.widgetWithText(ElevatedButton, 'Terapkan');
          await tester.ensureVisible(voucherFieldFinder);
          expect(tester.getSize(voucherFieldFinder).height, 42.0);
          expect(tester.getSize(applyBtnFinder).height, 42.0);

          // 4. Add-ons section uses "ADD-ON (OPSIONAL)" micro-header without helper paragraph
          expect(find.text('ADD-ON (OPSIONAL)'), findsOneWidget);
          expect(
            find.text(
              'Pilih power bank, charger, tripod, atau aksesoris tambahan yang disewa bersamaan.',
            ),
            findsNothing,
          );

          final addonRowFinder = find.text('Anker MagGo 10000mAh • RC-PB-01');
          await tester.ensureVisible(addonRowFinder);
          expect(addonRowFinder, findsOneWidget);
          await tester.tap(addonRowFinder);
          await tester.pumpAndSettle();
          expect(find.text('Subtotal Add-on (1x)'), findsOneWidget);

          // Advance Step 1 -> Step 2 -> Step 3
          await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
          await tester.pumpAndSettle();

          expect(find.text('DATA PENYEWA'), findsOneWidget);
          expect(find.text('Cari Pelanggan'), findsOneWidget);
          await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
          await tester.pumpAndSettle();

          // 5. Step 3 shows exact device and addon names, all 3 payment options cleanly, and 46px sticky buttons
          expect(find.text('RINGKASAN'), findsOneWidget);
          expect(find.text('iPhone 15 Pro Max'), findsOneWidget);
          expect(find.text('Anker MagGo 10000mAh'), findsOneWidget);
          expect(find.text('PEMBAYARAN'), findsOneWidget);
          expect(find.text('Bayar Lunas'), findsOneWidget);
          expect(find.text('Bayar DP'), findsOneWidget);
          expect(find.text('Bayar Saat Ambil'), findsOneWidget);

          final backBtnFinder = find.widgetWithText(OutlinedButton, 'Kembali');
          final saveBtnFinder = find.widgetWithText(ElevatedButton, 'Simpan Booking');
          expect(tester.getSize(backBtnFinder).height, 46.0);
          expect(tester.getSize(saveBtnFinder).height, 46.0);
        } finally {
          FlutterError.onError = prevOnError;
        }

        final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty);
      },
    );
  });
}

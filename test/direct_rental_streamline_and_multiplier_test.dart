import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';

class _FakeStreamlineBookingRepository extends BookingRepository {
  Map<String, dynamic>? lastCreatedPayload;
  int createRentalCalls = 0;

  @override
  Future<Map<String, dynamic>> createRental(Map<String, dynamic> payload, {String? idempotencyKey}) async {
    createRentalCalls++;
    lastCreatedPayload = Map<String, dynamic>.from(payload);
    return {
      'id': 901,
      'booking_code': 'RC-NEW-20261115-001',
      'status': 'rented',
      'payment_status': 'paid',
      'payments': [
        {
          'id': 77,
          'transaction_code': 'TRX-901',
          'receipt_number': 'RCP-901',
          'amount': payload['cash_received'] ?? 0,
        },
      ],
    };
  }
}

class _FakeStreamlineCashierRepository extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
        'has_active_shift': true,
        'shift': {'id': 1, 'status': 'open'},
      };

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async => [
        {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
        {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
      ];
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState) : super();

  @override
  BusinessState build() => _initialState;
}

void main() {
  final mockAssets = [
    {
      'id': 101,
      'asset_code': 'IPH15-01',
      'condition_grade': 'A',
      'serial_number': 'SN1001',
      'model': {
        'id': 1,
        'brand': 'Apple',
        'name': 'iPhone 15 Pro Max',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphone'},
        'pricing_tiers': [
          {'id': 11, 'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 180000},
          {'id': 12, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 300000},
        ],
      },
    },
    {
      'id': 102,
      'asset_code': 'SMG24-01',
      'condition_grade': 'A',
      'serial_number': 'SN1002',
      'model': {
        'id': 2,
        'brand': 'Samsung',
        'name': 'Galaxy S24 Ultra',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphone'},
        'pricing_tiers': [
          {'id': 21, 'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 150000},
          {'id': 22, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 280000},
        ],
      },
    },
    {
      'id': 103,
      'asset_code': 'XIA14-01',
      'condition_grade': 'B',
      'serial_number': 'SN1003',
      'model': {
        'id': 3,
        'brand': 'Xiaomi',
        'name': 'Xiaomi 14 Pro',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphone'},
        'pricing_tiers': [
          {'id': 31, 'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 120000},
        ],
      },
    },
    {
      'id': 104,
      'asset_code': 'OPP-01',
      'condition_grade': 'A',
      'serial_number': 'SN1004',
      'model': {
        'id': 4,
        'brand': 'Oppo',
        'name': 'Find X7 Ultra',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphone'},
        'pricing_tiers': [
          {'id': 41, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 250000},
        ],
      },
    },
    {
      'id': 105,
      'asset_code': 'VIV-01',
      'condition_grade': 'A',
      'serial_number': 'SN1005',
      'model': {
        'id': 5,
        'brand': 'Vivo',
        'name': 'Vivo X100 Pro',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphone'},
        'pricing_tiers': [
          {'id': 51, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 240000},
        ],
      },
    },
    {
      'id': 106,
      'asset_code': 'SONY-A7-01',
      'condition_grade': 'A',
      'serial_number': 'CAM9906',
      'model': {
        'id': 6,
        'brand': 'Sony',
        'name': 'Sony Alpha A7 IV',
        'category_id': 2,
        'category': {'id': 2, 'name': 'Kamera'},
        'pricing_tiers': [
          {'id': 61, 'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 150000},
          {'id': 62, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 280000},
        ],
      },
    },
    {
      'id': 107,
      'asset_code': 'DJI-AIR-01',
      'condition_grade': 'A',
      'serial_number': 'DRN7707',
      'model': {
        'id': 7,
        'brand': 'DJI',
        'name': 'Mavic Air 3',
        'category_id': 2,
        'category': {'id': 2, 'name': 'Kamera'},
        'pricing_tiers': [
          {'id': 71, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 350000},
        ],
      },
    },
  ];

  final mockCategories = [
    {'id': 1, 'name': 'Smartphone'},
    {'id': 2, 'name': 'Kamera'},
  ];

  const testBusinessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'Gwenn Rental',
    activeBranchId: 5,
    activeBranchName: 'Malang',
  );

  late _FakeStreamlineBookingRepository fakeBookingRepo;
  late _FakeStreamlineCashierRepository fakeCashierRepo;

  setUp(() {
    fakeBookingRepo = _FakeStreamlineBookingRepository();
    fakeCashierRepo = _FakeStreamlineCashierRepository();
  });

  Widget buildScreen() {
    return ProviderScope(
      overrides: [
        readyAssetsProvider.overrideWith((ref) => Future.value(mockAssets)),
        categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
        cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
        businessProvider.overrideWith(() => _TestBusinessNotifier(testBusinessState)),
        paymentMethodsProvider.overrideWith(
          (ref) => Future.value([
            {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
          ]),
        ),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(
            cashierRepo: fakeCashierRepo,
            bookingRepo: fakeBookingRepo,
          ),
        ),
      ],
      child: const MaterialApp(
        home: DirectRentalScreen(),
      ),
    );
  }

  group('DirectRentalScreen Streamline, Multiplier & No Photo Tests', () {
    testWidgets('Section 1 caps unit list at 5, shows Lihat semua toggle, displays single primary rate, and filters via search', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // Search input rendered at top of Section 1
      final searchField = find.byKey(const Key('booking_unit_search_field'));
      expect(searchField, findsOneWidget);
      expect(find.text('Cari nama unit, merek, atau kode...'), findsOneWidget);

      // First 5 units are rendered; 6th & 7th hidden initially
      expect(find.text('iPhone 15 Pro Max'), findsOneWidget);
      expect(find.text('Vivo X100 Pro'), findsOneWidget);
      expect(find.text('Sony Alpha A7 IV'), findsNothing);
      expect(find.text('Mavic Air 3'), findsNothing);

      // Single primary rate label per unit row (no duplicate tier prices on row)
      expect(find.text('Rp 300.000 / 24 Jam'), findsOneWidget);
      expect(find.text('Rp 280.000 / 24 Jam'), findsOneWidget);
      expect(find.text('Rp 120.000 / 12 Jam'), findsOneWidget);
      expect(find.text('Rp 180.000 / 12 Jam'), findsNothing);

      // Expand link visible for 7 units
      final showAllFinder = find.byKey(const Key('booking_show_all_units'));
      expect(showAllFinder, findsOneWidget);
      expect(find.text('Lihat semua (7 unit)'), findsOneWidget);

      await tester.ensureVisible(showAllFinder);
      await tester.tap(showAllFinder);
      await tester.pumpAndSettle();

      // Now 6th & 7th units are visible and link disappears
      expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
      expect(find.text('Mavic Air 3'), findsOneWidget);
      expect(find.byKey(const Key('booking_show_all_units')), findsNothing);

      // Typing in search resets _showAllUnits and filters by brand / model / code
      await tester.enterText(searchField, 'Sony');
      await tester.pumpAndSettle();
      expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
      expect(find.text('iPhone 15 Pro Max'), findsNothing);

      // Clear search resets back to 5-item cap!
      await tester.tap(find.byKey(const Key('booking_unit_search_clear')));
      await tester.pumpAndSettle();
      expect(find.text('Sony Alpha A7 IV'), findsNothing);
      expect(find.text('Lihat semua (7 unit)'), findsOneWidget);
    });

    testWidgets('Duration multiplier 1x->3x updates hours, subtotal, resets on rate/unit change, removes document photo, and submits booking', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();

      // 1. Search by unit code for Sony Alpha A7 IV (beyond initial 5 cap) and select it
      final searchField = find.byKey(const Key('booking_unit_search_field'));
      await tester.enterText(searchField, 'SONY-A7-01');
      await tester.pumpAndSettle();

      final sonyTile = find.text('Sony Alpha A7 IV');
      expect(sonyTile, findsOneWidget);
      await tester.tap(sonyTile);
      await tester.pumpAndSettle();

      // Default selected package is 24h @ Rp 280.000, multiplier 1x
      expect(find.text('1 Hari (24 Jam)'), findsOneWidget);
      expect(find.byKey(const Key('booking_multiplier_value')), findsOneWidget);
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('24 Jam'), findsOneWidget);
      expect(find.text('Rp 280.000'), findsOneWidget);

      // 2. Increment multiplier twice -> 3x => 72 Jam & Rp 840.000
      final incBtn = find.byKey(const Key('booking_multiplier_increment'));
      await tester.ensureVisible(incBtn);
      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('48 Jam'), findsOneWidget);
      expect(find.text('Rp 560.000'), findsOneWidget);

      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.text('3x'), findsOneWidget);
      expect(find.text('72 Jam'), findsOneWidget);
      expect(find.text('Rp 840.000'), findsOneWidget);

      // 3. Switching rate package to 12 Jam resets multiplier back to 1x
      final chip12h = find.text('12 Jam');
      await tester.ensureVisible(chip12h);
      await tester.tap(chip12h);
      await tester.pumpAndSettle();
      expect(find.text('1x'), findsOneWidget);
      expect(find.text('Rp 150.000'), findsOneWidget);

      // Switch back to 1 Hari (24 Jam) and step to 2x => 48 Jam & Rp 560.000
      final chip24h = find.text('1 Hari (24 Jam)');
      await tester.tap(chip24h);
      await tester.pumpAndSettle();
      await tester.tap(incBtn);
      await tester.pumpAndSettle();
      expect(find.text('2x'), findsOneWidget);
      expect(find.text('48 Jam'), findsOneWidget);
      expect(find.text('Rp 560.000'), findsOneWidget);

      // Advance to Step 2
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // 4. Verify Document Photo Attachment UI is completely removed in Section 2
      expect(find.text('FOTO DOKUMEN JAMINAN (KTP/SIM)'), findsNothing);
      expect(find.text('Lampirkan Foto Dokumen Identitas'), findsNothing);
      expect(find.text('AES-256 VAULT'), findsNothing);

      // Enter customer details without uploading any photo
      await tester.enterText(
        find.byKey(const Key('step2_name_field')),
        'Raka Wijaya',
      );
      await tester.enterText(
        find.byKey(const Key('step2_phone_field')),
        '081234567899',
      );
      await tester.enterText(
        find.byKey(const Key('step2_address_field')),
        'Jl. Soekarno Hatta No. 10, Malang',
      );
      await tester.pumpAndSettle();

      // Advance to Step 3 Summary
      final step2Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step2Cta);
      await tester.tap(step2Cta);
      await tester.pumpAndSettle();

      expect(find.textContaining('48 Jam (2x)'), findsOneWidget);
      expect(find.text('Rp 560.000'), findsWidgets);
      expect(find.text('KTP Valid'), findsNothing);

      // Proceed to PaymentPage and pay via Tunai
      final step3Cta = find.text('Buat Sewa');
      await tester.ensureVisible(step3Cta);
      await tester.tap(step3Cta);
      await tester.pumpAndSettle();

      expect(find.text('Total Tagihan'), findsOneWidget);
      expect(find.text('Rp560.000'), findsOneWidget);

      final tunaiCard = find.text('Tunai');
      await tester.ensureVisible(tunaiCard);
      await tester.tap(tunaiCard);
      await tester.pumpAndSettle();

      final payBtn = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      await tester.ensureVisible(payBtn);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      expect(fakeBookingRepo.createRentalCalls, 1);
      final payload = fakeBookingRepo.lastCreatedPayload!;
      expect(payload.containsKey('identity_photo_base64'), isFalse);
      expect(payload['duration_hours'], 48);
      expect(payload['duration_unit'], 'day');
      expect(payload['duration_value'], 2);
      expect(payload['duration_multiplier'], 2);
      expect(payload['quantity'], 2);
      expect(payload['rate_id'], 62);
      expect(payload['unit_prices']['106'], 560000.0);
    });
  });
}

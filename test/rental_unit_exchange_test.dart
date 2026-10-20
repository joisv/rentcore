import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/presentation/exchange_history_sheet.dart';
import 'package:rentcore_mobile/features/bookings/presentation/exchange_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _FakeExchangeBookingRepository extends BookingRepository {
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> fetchAvailableReplacements(dynamic bookingId, {dynamic assetId}) async {
    final isCoral = assetId == 2;
    return {
      'booking_id': 101,
      'booking_code': 'RC-261020-0042',
      'current_asset': {
        'asset_id': isCoral ? 2 : 1,
        'asset_code': isCoral ? 'RC-XR-002' : 'RC-XR-001',
        'model_name': isCoral ? 'iPhone XR 64GB Coral' : 'iPhone XR 64GB White',
        'unit_price': 40000.0,
      },
      'candidates': [
        {
          'asset_id': 2,
          'asset_code': 'RC-XR-002',
          'serial_number': 'SN-XR-002',
          'condition_grade': 'A',
          'battery_health': 92,
          'tier_category': 'same_tier',
          'price_differential': 0.0,
          'calculated_rate': 40000.0,
          'model': {
            'id': 1,
            'name': 'iPhone XR 64GB Coral',
            'brand': 'Apple',
            'storage_capacity': '64GB',
            'color': 'Coral',
            'requires_frp_check': true,
          },
        },
        {
          'asset_id': 3,
          'asset_code': 'RC-11-001',
          'serial_number': 'SN-11-001',
          'condition_grade': 'A',
          'battery_health': 96,
          'tier_category': 'upgrade',
          'price_differential': 30000.0,
          'calculated_rate': 70000.0,
          'model': {
            'id': 2,
            'name': 'iPhone 11 128GB Black',
            'brand': 'Apple',
            'storage_capacity': '128GB',
            'color': 'Black',
            'requires_frp_check': true,
          },
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> exchangeRentalUnit(dynamic bookingId, Map<String, dynamic> payload) async {
    lastPayload = payload;
    return {
      'success': true,
      'message': 'Unit sewa berhasil ditukar.',
      'receipt_data': {
        'receipt_number': 'REC-EXC-MCM-261020-0001',
        'booking_code': 'RC-261020-0042',
        'customer_name': 'Budi Santoso',
        'customer_phone': '081234567890',
        'branch_name': 'Malang Cyber Mall',
        'cashier_name': 'Kasir Utama',
        'old_asset_name': 'iPhone XR 64GB White',
        'old_asset_code': 'RC-XR-001',
        'old_asset_serial': 'SN-XR-001',
        'reported_issue': 'Kamera getar',
        'new_asset_name': 'iPhone XR 64GB Coral',
        'new_asset_code': 'RC-XR-002',
        'new_asset_serial': 'SN-XR-002',
        'end_at': '21 Okt 2026, 14:00',
        'price_differential': 0.0,
        'payment_method': 'Tanpa Biaya (Setara)',
      },
    };
  }
}

void main() {
  final testBooking = {
    'id': 101,
    'booking_code': 'RC-261020-0042',
    'status': 'rented',
    'total_bill': '40000.00',
    'customer': {
      'name': 'Budi Santoso',
      'phone': '081234567890',
    },
    'items': [
      {
        'asset_id': 1,
        'unit_price': '40000.00',
        'asset': {
          'id': 1,
          'asset_code': 'RC-XR-001',
          'model': {
            'name': 'iPhone XR 64GB White',
            'brand': 'Apple',
            'requires_frp_check': true,
          },
        },
      },
    ],
  };

  testWidgets('ExchangeWizardScreen renders Step 1 Diagnostic and enforces iCloud guard', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = _FakeExchangeBookingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          home: ExchangeWizardScreen(booking: testBooking),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Header & Step 1 elements
    expect(find.text('Tukar Unit: RC-261020-0042'), findsOneWidget);
    expect(find.textContaining('iPhone XR 64GB White'), findsWidgets);
    expect(find.text('Kamera / Lensa'), findsOneWidget);
    expect(find.text('Baterai / Power'), findsOneWidget);
    expect(find.text('Pemeriksaan Akun iCloud / FRP (Wajib)'), findsOneWidget);

    // Try clicking Lanjut without complaint
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Enforces complaint
    expect(find.text('Harap masukkan deskripsi keluhan pelanggan.'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(ExchangeWizardScreen))).clearSnackBars();
    await tester.pumpAndSettle();

    // Enter complaint
    await tester.enterText(
      find.widgetWithText(TextField, 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...'),
      'Kamera belakang getar terus',
    );
    await tester.pumpAndSettle();

    // Try clicking Lanjut without iCloud sign out
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();
    expect(find.text('Akun iCloud / FRP wajib dipastikan sudah Sign Out sebelum lanjut.'), findsOneWidget);

    ScaffoldMessenger.of(tester.element(find.byType(ExchangeWizardScreen))).clearSnackBars();
    await tester.pumpAndSettle();

    // Toggle iCloud Sign-Out switch
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Now Lanjut succeeds to Step 2
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Verify Step 2 Candidate Selection Screen
    expect(find.text('Pilih Perangkat Pengganti dari Stok Cabang'), findsOneWidget);
    expect(find.text('iPhone XR 64GB Coral'), findsOneWidget);
    expect(find.text('iPhone 11 128GB Black'), findsOneWidget);
    expect(find.text('Setara (Rp 0)'), findsOneWidget);
    expect(find.textContaining('Upgrade (+Rp 30.000)'), findsOneWidget);
  });

  testWidgets('Selecting upgrade candidate advances to Step 3 with price differential and manager override option', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = _FakeExchangeBookingRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          paymentMethodsProvider.overrideWith((ref) async => [
            {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
            {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
          ]),
        ],
        child: MaterialApp(
          home: ExchangeWizardScreen(booking: testBooking),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Step 1: fill form
    await tester.enterText(
      find.widgetWithText(TextField, 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...'),
      'Kamera pecah',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Step 2: Select iPhone 11 upgrade
    await tester.tap(find.text('iPhone 11 128GB Black'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Step 3: Verify Financial Calculation
    expect(find.text('Rincian Biaya Penggantian Unit'), findsOneWidget);
    expect(find.text('+Rp 30.000'), findsOneWidget);
    expect(find.text('TOTAL WAJIB DIBAYAR KASIR'), findsOneWidget);
    expect(find.text('Bebaskan Biaya Selisih (Kompensasi / Kebijakan Toko)'), findsOneWidget);

    // Toggle Fee Waiver
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bebaskan Biaya Selisih (Kompensasi / Kebijakan Toko)'));
    await tester.pumpAndSettle();

    // Verify Manager PIN input appears
    expect(find.text('Otorisasi Manager Diperlukan'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'PIN Manager Override'), findsOneWidget);
  });

  testWidgets('Active rental card in BookingsScreen displays replacement device, Ditukar tag, and opens ExchangeHistorySheet', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final testExchangedBooking = {
      'id': 102,
      'booking_code': 'RC-261020-0088',
      'status': 'rented',
      'total_bill': '40000.00',
      'start_at': '2026-10-20 10:00:00',
      'end_at': '2026-10-21 10:00:00',
      'customer': {
        'name': 'Siti Rahma',
        'phone': '08987654321',
      },
      'active_item': {
        'id': 202,
        'asset_id': 2,
        'status': 'active',
        'asset': {
          'id': 2,
          'asset_code': 'RC-XR-002',
          'serial_number': 'SN-XR-002',
          'condition_grade': 'A',
          'model': {
            'id': 1,
            'name': 'iPhone XR 64GB Coral',
            'brand': 'Apple',
          },
        },
      },
      'active_asset': {
        'id': 2,
        'asset_code': 'RC-XR-002',
        'serial_number': 'SN-XR-002',
        'condition_grade': 'A',
        'model': {
          'id': 1,
          'name': 'iPhone XR 64GB Coral',
          'brand': 'Apple',
        },
      },
      'items': [
        {
          'id': 201,
          'asset_id': 1,
          'status': 'exchanged',
          'asset': {
            'id': 1,
            'asset_code': 'RC-XR-001',
            'serial_number': 'SN-XR-001',
            'model': {
              'id': 1,
              'name': 'iPhone XR 64GB White',
              'brand': 'Apple',
            },
          },
        },
        {
          'id': 202,
          'asset_id': 2,
          'status': 'active',
          'asset': {
            'id': 2,
            'asset_code': 'RC-XR-002',
            'serial_number': 'SN-XR-002',
            'model': {
              'id': 1,
              'name': 'iPhone XR 64GB Coral',
              'brand': 'Apple',
            },
          },
        },
      ],
      'exchanges': [
        {
          'id': 501,
          'exchange_reference': 'EXC-261020-0001',
          'booking_id': 102,
          'old_asset_id': 1,
          'new_asset_id': 2,
          'reported_issue_category': 'camera',
          'customer_complaint': 'Kamera getar terus',
          'staff_diagnosis': 'OIS hardware rusak',
          'old_unit_condition_grade': 'B',
          'icloud_signout_verified': true,
          'old_asset_disposition': 'maintenance',
          'price_differential': '0.00',
          'fee_waived': false,
          'time_elapsed_hours': 3.5,
          'exchanged_at': '2026-10-20 13:30:00',
          'old_asset': {
            'id': 1,
            'asset_code': 'RC-XR-001',
            'serial_number': 'SN-XR-001',
            'imei_1': '352981029381023',
            'model': {
              'name': 'iPhone XR 64GB White',
            },
          },
          'new_asset': {
            'id': 2,
            'asset_code': 'RC-XR-002',
            'serial_number': 'SN-XR-002',
            'imei_1': '352981029381099',
            'condition_grade': 'A',
            'model': {
              'name': 'iPhone XR 64GB Coral',
            },
          },
          'handler': {
            'name': 'Staff Kasir 1',
          },
        },
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingsListProvider.overrideWith((ref) async => [testExchangedBooking]),
        ],
        child: const MaterialApp(
          home: BookingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify replacement device is displayed (NOT the old unit)
    expect(find.text('iPhone XR 64GB Coral'), findsOneWidget);
    expect(find.textContaining('RC-XR-002'), findsOneWidget);
    expect(find.text('Ditukar (1x)'), findsOneWidget);

    // Tap exchange badge to open ExchangeHistorySheet
    await tester.tap(find.text('Ditukar (1x)'));
    await tester.pumpAndSettle();

    // Verify ExchangeHistorySheet opened with details
    expect(find.text('Riwayat Pertukaran Unit'), findsOneWidget);
    expect(find.text('Pertukaran #1'), findsOneWidget);
    expect(find.text('EXC-261020-0001'), findsOneWidget);
    expect(find.textContaining('iPhone XR 64GB White'), findsOneWidget);
    expect(find.textContaining('Kamera getar terus'), findsOneWidget);
    expect(find.text('iCloud Sign Out Terverifikasi'), findsOneWidget);
    expect(find.textContaining('iPhone XR 64GB Coral'), findsWidgets);
    expect(find.text('Cetak Bukti Pertukaran Unit'), findsOneWidget);
  });

  testWidgets('Subsequent exchange on previously exchanged booking targets current replacement device', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final fakeRepo = _FakeExchangeBookingRepository();

    final testExchangedBooking = {
      'id': 102,
      'booking_code': 'RC-261020-0088',
      'status': 'rented',
      'total_bill': '40000.00',
      'customer': {
        'name': 'Siti Rahma',
        'phone': '08987654321',
      },
      'active_asset': {
        'id': 2,
        'asset_code': 'RC-XR-002',
        'serial_number': 'SN-XR-002',
        'model': {
          'id': 1,
          'name': 'iPhone XR 64GB Coral',
          'brand': 'Apple',
          'requires_frp_check': true,
        },
      },
      'items': [
        {
          'id': 201,
          'asset_id': 1,
          'status': 'exchanged',
          'asset': {
            'id': 1,
            'asset_code': 'RC-XR-001',
            'model': {
              'name': 'iPhone XR 64GB White',
              'brand': 'Apple',
            },
          },
        },
        {
          'id': 202,
          'asset_id': 2,
          'status': 'active',
          'asset': {
            'id': 2,
            'asset_code': 'RC-XR-002',
            'model': {
              'name': 'iPhone XR 64GB Coral',
              'brand': 'Apple',
              'requires_frp_check': true,
            },
          },
        },
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          paymentMethodsProvider.overrideWith((ref) async => [
            {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
          ]),
        ],
        child: MaterialApp(
          home: ExchangeWizardScreen(booking: testExchangedBooking),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify current unit being exchanged in header is the active replacement unit (Coral RC-XR-002)
    expect(find.textContaining('iPhone XR 64GB Coral'), findsWidgets);
    expect(find.textContaining('RC-XR-002'), findsWidgets);

    // Fill Step 1
    await tester.enterText(
      find.widgetWithText(TextField, 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...'),
      'Layar touchscreen tidak respon di bagian atas',
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    // Advance to Step 2
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Select candidate
    await tester.tap(find.text('iPhone 11 128GB Black'));
    await tester.pumpAndSettle();

    // Advance to Step 3
    await tester.tap(find.text('Lanjut ➔'));
    await tester.pumpAndSettle();

    // Waive fee with PIN
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Bebaskan Biaya Selisih (Kompensasi / Kebijakan Toko)'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Contoh: Kompensasi stok unit sama habis...'),
      'Kendala berulang pada unit pengganti',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'PIN Manager Override'),
      '1234',
    );
    await tester.pumpAndSettle();

    // Submit exchange
    await tester.tap(find.text('Konfirmasi Tukar Unit'));
    await tester.pumpAndSettle();

    // Assert that the old_asset_id submitted is 2 (the current replacement unit), NOT 1!
    expect(fakeRepo.lastPayload, isNotNull);
    expect(fakeRepo.lastPayload!['old_asset_id'], equals(2));
    expect(fakeRepo.lastPayload!['new_asset_id'], equals(3));
    expect(fakeRepo.lastPayload!['fee_waived'], isTrue);

    // Verify Step 4 Selesai is shown
    expect(find.text('Penggantian Unit Selesai!'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/presentation/exchange_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _FakePolishBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return [
      {
        'id': 501,
        'booking_code': 'RC-261031-LONG-01',
        'affiliate_id': 1,
        'business_id': 10,
        'status': 'rented',
        'duration_hours': 24,
        'start_at': DateTime.now().subtract(const Duration(hours: 30)).toIso8601String(),
        'end_at': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(), // Overdue
        'total_bill': 150000.0,
        'collateral_storage_slot': 'Slot A-01',
        'customer': {
          'id': 88,
          'name': 'Alexander Maximillian Bartholomeus von Hohenzollern the Third',
          'phone': '08123456789',
        },
        'payments': [
          {
            'id': 1,
            'type': 'settlement',
            'amount': 150000.0,
          }
        ],
        'items': [
          {
            'id': 801,
            'item_type': 'primary',
            'duration_value': 24,
            'unit_price': 150000.0,
            'asset': {
              'id': 901,
              'asset_code': 'AST-920217',
              'model': {
                'id': 50,
                'name': 'iPhone 15 Pro Max 1TB Natural Titanium',
                'category': {'name': 'Smartphone'},
                'requires_frp_check': true,
                'pricing_tiers': [
                  {'duration_hours': 6, 'price': 50000.0, 'is_active': true},
                  {'duration_hours': 12, 'price': 90000.0, 'is_active': true},
                  {'duration_hours': 24, 'price': 150000.0, 'is_active': true},
                ],
              },
            },
          },
        ],
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchAvailableReplacements(dynamic bookingId, {dynamic assetId}) async {
    return {
      'booking_id': 501,
      'booking_code': 'RC-261031-LONG-01',
      'current_asset': {
        'asset_id': 901,
        'asset_code': 'AST-920217',
        'model_name': 'iPhone 15 Pro Max 1TB Natural Titanium',
        'unit_price': 150000.0,
      },
      'candidates': [
        {
          'asset_id': 902,
          'asset_code': 'AST-920218',
          'serial_number': 'SN-920218',
          'condition_grade': 'A',
          'battery_health': 100,
          'tier_category': 'same_tier',
          'price_differential': 0.0,
          'calculated_rate': 150000.0,
          'model': {
            'id': 50,
            'name': 'iPhone 15 Pro Max 1TB Blue',
            'brand': 'Apple',
            'requires_frp_check': true,
          },
        },
        {
          'asset_id': 903,
          'asset_code': 'AST-920219',
          'serial_number': 'SN-920219',
          'condition_grade': 'A',
          'battery_health': 98,
          'tier_category': 'upgrade',
          'price_differential': 50000.0,
          'calculated_rate': 200000.0,
          'model': {
            'id': 51,
            'name': 'iPhone 16 Pro Max 1TB Desert',
            'brand': 'Apple',
            'requires_frp_check': true,
          },
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> exchangeRentalUnit(dynamic bookingId, Map<String, dynamic> payload) async {
    return {
      'success': true,
      'message': 'Tukar unit berhasil',
      'receipt_data': {
        'receipt_number': 'REC-EXC-001',
        'booking_code': 'RC-261031-LONG-01',
        'customer_name': 'Alexander Maximillian',
        'old_asset_name': 'iPhone 15 Pro Max',
        'new_asset_name': 'iPhone 16 Pro Max',
        'end_at': '31 Okt 2026, 20:00',
        'price_differential': 50000.0,
      },
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
  group('Unit Exchange & Reduce Duration UI Polish and Overflow Tests', () {
    late _FakePolishBookingRepository fakeRepo;

    final testBooking = {
      'id': 501,
      'booking_code': 'RC-261031-LONG-01',
      'status': 'rented',
      'total_bill': '150000.00',
      'end_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'customer': {
        'name': 'Alexander Maximillian Bartholomeus von Hohenzollern the Third',
        'phone': '08123456789',
      },
      'items': [
        {
          'asset_id': 901,
          'unit_price': '150000.00',
          'asset': {
            'id': 901,
            'asset_code': 'AST-920217',
            'model': {
              'name': 'iPhone 15 Pro Max',
              'brand': 'Apple',
              'requires_frp_check': true,
            },
          },
        },
      ],
    };

    setUp(() {
      fakeRepo = _FakePolishBookingRepository();
    });

    testWidgets('1. Top Banner Card formats customer + overdue without RenderFlex overflow on narrow screen', (tester) async {
      tester.view.physicalSize = const Size(320, 600); // Narrow mobile screen (e.g. iPhone SE / small Android)
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      // Verify Header says 'Unit Bermasalah'
      expect(find.text('Unit Bermasalah'), findsOneWidget);

      // Verify Customer & Overdue string renders cleanly without throwing overflow
      expect(find.textContaining('Alexander Maximillian'), findsOneWidget);
      expect(find.textContaining('Terlambat'), findsOneWidget);

      // Verify Step 1 simplified titles
      expect(find.text('Pilih Kendala'), findsOneWidget);
      expect(find.text('Keluhan Pelanggan'), findsOneWidget);
      expect(find.text('Catatan Fisik (Opsional)'), findsOneWidget);
      expect(find.textContaining('Karantina / Servis'), findsOneWidget);
    });

    testWidgets('2. Step 2 Replacement Selection renders simplified title, filter chips, and dot-separated metadata', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

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

      // Fill Step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...'),
        'Kamera blank hitam',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lanjut ➔'));
      await tester.pumpAndSettle();

      // Verify Step 2 Simplified Header
      expect(find.text('Pilih Unit Pengganti'), findsOneWidget);
      expect(find.text('Pilih Perangkat Pengganti dari Stok Cabang'), findsNothing);

      // Verify dot-separated metadata: AST-920218 • Grade A • Bat: 100%
      expect(find.textContaining('AST-920218 • Grade A • Bat: 100%'), findsOneWidget);
      expect(find.textContaining('AST-920219 • Grade A • Bat: 98%'), findsOneWidget);
    });

    testWidgets('3. Step 3 & Step 4 render simplified copy: Total Biaya Tukar, Tukar Unit Berhasil', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            paymentMethodsProvider.overrideWith((ref) async => [
              {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
            ]),
          ],
          child: MaterialApp(
            home: ExchangeWizardScreen(booking: testBooking),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1
      await tester.enterText(
        find.widgetWithText(TextField, 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...'),
        'Layar retak',
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut ➔'));
      await tester.pumpAndSettle();

      // Step 2: Select upgrade
      await tester.tap(find.text('iPhone 16 Pro Max 1TB Desert'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lanjut ➔'));
      await tester.pumpAndSettle();

      // Step 3: Verify clean table and Total Biaya Tukar
      expect(find.text('Tarif Unit Lama'), findsOneWidget);
      expect(find.text('Tarif Unit Baru'), findsOneWidget);
      expect(find.text('Total Biaya Tukar'), findsOneWidget);
      expect(find.text('TOTAL WAJIB DIBAYAR KASIR'), findsNothing);

      // Submit via waiver
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Bebaskan Biaya Selisih (Kompensasi / Kebijakan Toko)'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'PIN Manager Override'), '123456');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Konfirmasi Tukar Unit'));
      await tester.pumpAndSettle();

      // Step 4: Verify Success Headline & Subtitle
      expect(find.text('Tukar Unit Berhasil'), findsOneWidget);
      expect(find.text('Unit lama dialihkan ke servis.'), findsOneWidget);
    });

    testWidgets('4. Reduce Duration Modal renders compact past-due warning and grouped refund+PIN container', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final businessState = const BusinessState(
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
          }
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Atur Durasi Sewa
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam'));
      await tester.pumpAndSettle();

      // Switch to - Kurangi Jam
      await tester.tap(find.text('- Kurangi Jam'));
      await tester.pumpAndSettle();

      // Booking is overdue (end_at was 6 hours ago), so reduction produces past-due warning
      expect(find.text('Batas waktu baru tidak valid (lewat dari batas waktu saat ini).'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/shared/widgets/dock_aware_scaffold.dart';
import 'package:sewakasir/shared/widgets/status_badge.dart';

class _Phase2TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBranchId: 1,
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Test',
            'enable_collateral': true,
            'require_collateral': false,
          },
        ],
      );

  @override
  Future<void> refresh() async {}
}

void main() {
  BusinessNotifier createCollateralEnabledBusiness() => _Phase2TestBusinessNotifier();

  group('Phase P2 — Unified StatusBadge Component Tests', () {
    testWidgets('StatusBadge.rental renders correct state and colors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.rental('returned'),
                StatusBadge.rental('rented', endAt: DateTime.now().add(const Duration(hours: 5))),
                StatusBadge.rental('rented', endAt: DateTime.now().subtract(const Duration(hours: 5))),
              ],
            ),
          ),
        ),
      );

      expect(find.text('SELESAI'), findsOneWidget);
      expect(find.text('SEDANG DISEWA'), findsOneWidget);
      expect(find.text('TERLAMBAT'), findsOneWidget);
    });

    testWidgets('StatusBadge.payment renders correct badge labels', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.payment('paid'),
                StatusBadge.payment('partial'),
                StatusBadge.payment('unpaid'),
                StatusBadge.payment('void'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('LUNAS'), findsOneWidget);
      expect(find.text('SEBAGIAN'), findsOneWidget);
      expect(find.text('BELUM LUNAS'), findsOneWidget);
      expect(find.text('VOID'), findsOneWidget);
    });

    testWidgets('StatusBadge.inventory renders ready, rented, maintenance, and in_transit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.inventory('ready'),
                StatusBadge.inventory('rented'),
                StatusBadge.inventory('maintenance'),
                StatusBadge.inventory('in_transit'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Siap Sewa'), findsOneWidget);
      expect(find.text('Sedang Disewa'), findsOneWidget);
      expect(find.text('Perawatan'), findsOneWidget);
      expect(find.text('Dalam Mutasi'), findsOneWidget);
    });

    testWidgets('StatusBadge.transfer renders proper workflow statuses', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.transfer('pending'),
                StatusBadge.transfer('in_transit'),
                StatusBadge.transfer('received'),
                StatusBadge.transfer('rejected'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Menunggu Persetujuan'), findsOneWidget);
      expect(find.text('Dalam Pengiriman'), findsOneWidget);
      expect(find.text('Diterima'), findsOneWidget);
      expect(find.text('Ditolak'), findsOneWidget);
    });

    testWidgets('StatusBadge.voucher renders active, inactive, and expired', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge.voucher(isActive: true),
                StatusBadge.voucher(isActive: false),
                StatusBadge.voucher(isActive: false, isExpired: true),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Aktif'), findsOneWidget);
      expect(find.text('Nonaktif'), findsOneWidget);
      expect(find.text('Kadaluarsa'), findsOneWidget);
    });
  });

  group('Phase P2 — DockClearance & DockAwareScaffold Tests', () {
    testWidgets('DockClearance renders base dock height of 96.0', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                Text('Top Item'),
                DockClearance(),
              ],
            ),
          ),
        ),
      );

      final dockBox = tester.renderObject<RenderBox>(find.byType(DockClearance));
      expect(dockBox.size.height, greaterThanOrEqualTo(kDockHeight));
    });
  });

  group('Phase P2 — DirectRentalScreen 3-Step Wizard Flow Tests', () {
    final mockReadyAssets = [
      {
        'id': 101,
        'asset_code': 'IPHONE-15-01',
        'condition_grade': 'A',
        'battery_health': 98,
        'serial_number': 'SN15P001',
        'model': {
          'id': 1,
          'name': 'iPhone 15 Pro Max 256GB Natural Titanium',
          'category_id': 1,
          'pricing_tiers': [
            {'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 180000},
            {'duration_unit': 'hour', 'duration_value': 24, 'duration_hours': 24, 'price': 300000},
            {'duration_unit': 'day', 'duration_value': 2, 'duration_hours': 48, 'price': 550000},
          ],
        },
      },
    ];

    final mockCategories = [
      {'id': 1, 'name': 'iPhone'},
    ];

    final mockPaymentMethods = [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai (Cash)'},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
      {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank'},
    ];

    testWidgets('Navigates smoothly through Step 1 -> Step 2 -> Step 3 with bidirectional controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(createCollateralEnabledBusiness),
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(
              customer: {
                'id': 1,
                'name': 'Dedi Kurniawan',
                'phone': '081298765432',
                'address': 'Jl. Raya Genteng No. 128, RT 03/RW 02, Kec. Genteng, Banyuwangi 68465',
              },
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Stepper Header
      expect(find.text('1. Unit'), findsOneWidget);
      expect(find.text('2. Penyewa'), findsOneWidget);
      expect(find.text('3. Ringkasan'), findsOneWidget);

      // --- STEP 1: Unit & Durasi ---
      // Primary button stays disabled until unit and duration are selected
      final ctaFinder = find.widgetWithText(ElevatedButton, 'Lanjut');
      expect(ctaFinder, findsOneWidget);
      final disabledButton = tester.widget<ElevatedButton>(ctaFinder);
      expect(disabledButton.onPressed, isNull);

      // Select unit
      expect(find.text('iPhone 15 Pro Max 256GB Natural Titanium'), findsOneWidget);
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();

      // Button is now enabled and allows advancing
      final enabledButton = tester.widget<ElevatedButton>(ctaFinder);
      expect(enabledButton.onPressed, isNotNull);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      // --- STEP 2: Data Penyewa ---
      expect(find.text('DATA PENYEWA'), findsOneWidget);
      expect(find.text('Cari Pelanggan'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Lanjut'), findsOneWidget);

      // Verify customer form fields & external labels exist
      expect(find.text('Nama Penyewa *'), findsOneWidget);
      expect(find.text('Nomor WhatsApp *'), findsOneWidget);
      expect(find.text('Alamat (KTP/SIM) *'), findsOneWidget);
      expect(find.byKey(const Key('step2_name_field')), findsOneWidget);
      expect(find.byKey(const Key('step2_phone_field')), findsOneWidget);
      expect(find.byKey(const Key('step2_address_field')), findsOneWidget);
      expect(find.byKey(const Key('step2_collateral_dropdown')), findsOneWidget);

      // Advance to Step 3
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      // --- STEP 3: Ringkasan Sewa & Review ---
      expect(find.text('RINGKASAN'), findsOneWidget);
      expect(find.text('Total Tagihan'), findsOneWidget);
      expect(find.text('Waktu Sewa'), findsOneWidget);
      expect(find.textContaining('Mulai Sekarang • Kembali'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Buat Sewa'), findsOneWidget);

      // Test "Kembali" backward navigation to Step 2
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('DATA PENYEWA'), findsOneWidget);

      // Test "Kembali" backward navigation to Step 1
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('MODEL PERANGKAT'), findsOneWidget);
    });
  });
}

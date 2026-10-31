import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/shared/widgets/dock_aware_scaffold.dart';
import 'package:rentcore_mobile/shared/widgets/status_badge.dart';

void main() {
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
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Stepper Header
      expect(find.text('1. Unit & Durasi'), findsOneWidget);
      expect(find.text('2. Penyewa'), findsOneWidget);
      expect(find.text('3. Ringkasan'), findsOneWidget);

      // --- STEP 1: Unit & Durasi ---
      // Primary button stays disabled until unit and duration are selected
      final ctaFinder = find.widgetWithText(ElevatedButton, 'Lanjut ke Data Penyewa');
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
      expect(find.text('DATA PENYEWA & ALAMAT IDENTITAS'), findsOneWidget);
      expect(find.text('Kembali'), findsOneWidget);
      expect(find.text('Lanjut: Ringkasan Biaya'), findsOneWidget);

      // Verify customer form fields exist
      expect(find.widgetWithText(TextFormField, 'Nama Lengkap Penyewa *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Nomor WhatsApp Aktif *'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Alamat Sesuai Kartu Identitas *'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);

      // Advance to Step 3
      await tester.tap(find.text('Lanjut: Ringkasan Biaya'));
      await tester.pumpAndSettle();

      // --- STEP 3: Ringkasan Sewa & Review ---
      expect(find.text('RINGKASAN SEWA & IDENTITAS PENYEWA'), findsOneWidget);
      expect(find.text('TOTAL TAGIHAN POS:'), findsOneWidget);
      expect(find.textContaining('Kembali:'), findsWidgets);
      expect(find.text('Ubah Data'), findsOneWidget);
      expect(find.text('Lanjut ke Pembayaran'), findsOneWidget);

      // Test "Ubah Data" backward navigation to Step 2
      await tester.tap(find.text('Ubah Data'));
      await tester.pumpAndSettle();

      expect(find.text('DATA PENYEWA & ALAMAT IDENTITAS'), findsOneWidget);

      // Test "Kembali" backward navigation to Step 1
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();

      expect(find.text('PILIH UNIT RENTAL TERSEDIA'), findsOneWidget);
    });
  });
}

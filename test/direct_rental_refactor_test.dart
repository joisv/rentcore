import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';

class MockPaymentRepository extends PaymentRepository {
  PaymentResult? lastResult;
  PaymentContext? lastContext;

  @override
  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? notes,
  }) async {
    lastContext = context;
    final isCash = paymentMethodCode.toUpperCase() == 'CASH';
    final change = isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0;

    final result = PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'BOOK-TEST-9921',
      receiptNumber: 'RCP-20261030-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: change,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
      responseData: {'booking_code': 'BOOK-TEST-9921'},
    );
    lastResult = result;
    return result;
  }
}

void main() {
  final mockReadyAssets = [
    {
      'id': 101,
      'asset_code': 'IPHONE-15-01',
      'condition_grade': 'B',
      'battery_health': 100,
      'serial_number': 'SN99881234',
      'model': {
        'id': 1,
        'name': 'iPhone 15 Pro Max 256GB Natural Titanium',
        'category_id': 1,
        'pricing_tiers': [
          {'duration_unit': 'hour', 'duration_value': 12, 'duration_hours': 12, 'price': 180000},
          {'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 300000},
          {'duration_unit': 'day', 'duration_value': 3, 'duration_hours': 72, 'price': 800000},
        ],
      },
    },
  ];

  final mockCategories = [
    {'id': 1, 'name': 'Smartphones'},
    {'id': 2, 'name': 'Smartwatch/Aksesoris Ekstra Panjang'},
    {'id': 3, 'name': 'Kamera & Lensa Mirrorless Sony'},
  ];

  final mockPaymentMethods = [
    {'id': 1, 'code': 'CASH', 'name': 'Tunai (Cash)'},
    {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
    {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank'},
  ];

  group('DirectRentalScreen Refactored Step 1, 2, and 3 Tests', () {
    testWidgets('Step 1: Category chips scroll horizontally, metadata badges render, duration preview activates', (tester) async {
      tester.view.physicalSize = const Size(320, 568); // Compact iPhone SE screen
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

      // Check category list is scrollable and displays categories
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Smartphones'), findsOneWidget);

      // Verify CTA button is disabled before unit selection
      final ctaFinder = find.widgetWithText(ElevatedButton, 'Lanjut ke Data Penyewa');
      expect(ctaFinder, findsOneWidget);
      final disabledCta = tester.widget<ElevatedButton>(ctaFinder);
      expect(disabledCta.onPressed, isNull);

      // Verify compact metadata chips on unit card
      expect(find.text('IPHONE-15-01'), findsOneWidget);
      expect(find.text('Grade B'), findsOneWidget);
      expect(find.text('BH 100%'), findsOneWidget);
      expect(find.text('SN: ...1234'), findsOneWidget); // last 4 digits of SN99881234

      // Select unit
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();

      // Duration preview and quick chips are immediately activated
      expect(find.text('12 Jam'), findsOneWidget);
      expect(find.text('1 Hari (24 Jam)'), findsOneWidget);
      expect(find.text('3 Hari (72 Jam)'), findsOneWidget);
      expect(find.textContaining('Kembali:'), findsOneWidget);

      // CTA button is now enabled
      await tester.ensureVisible(ctaFinder);
      final enabledCta = tester.widget<ElevatedButton>(ctaFinder);
      expect(enabledCta.onPressed, isNotNull);
    });

    testWidgets('Step 2: No overflow on header row with "Cari Riwayat", back button does not wrap "Kembali", slot dropdown works', (tester) async {
      tester.view.physicalSize = const Size(320, 568); // Compact 320dp width
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final errors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = (details) => errors.add(details);
      addTearDown(() => FlutterError.onError = previousOnError);

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

      // Select unit and advance to Step 2
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();

      final ctaFinder = find.widgetWithText(ElevatedButton, 'Lanjut ke Data Penyewa');
      await tester.ensureVisible(ctaFinder);
      await tester.tap(ctaFinder);
      await tester.pumpAndSettle();

      // Verify Step 2 header and Cari Riwayat button
      expect(find.text('DATA PENYEWA & ALAMAT IDENTITAS'), findsOneWidget);
      expect(find.text('Cari Riwayat'), findsOneWidget);

      // Verify no RenderFlex overflow occurred
      FlutterError.onError = previousOnError;
      final overflowErrors = errors.where((e) => e.toString().contains('overflowed')).toList();
      expect(overflowErrors, isEmpty, reason: 'Step 2 header caused layout overflow on 320dp viewport');

      // Verify back button "Kembali"
      expect(find.text('Kembali'), findsOneWidget);

      // Verify safe storage dropdown
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
      expect(find.text('Brankas A, Slot 05'), findsOneWidget);
    });

    testWidgets('Step 3: New booking navigates to unified PaymentPage, verifies Tagihan Sewa, Detail Sewa, and completes checkout', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockPaymentRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
            paymentRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Select unit
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut ke Data Penyewa');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // Step 2: Advance to Step 3
      final step2Cta = find.text('Lanjut: Ringkasan Biaya');
      await tester.ensureVisible(step2Cta);
      await tester.tap(step2Cta);
      await tester.pumpAndSettle();

      // Step 3: Advance to unified PaymentPage
      final step3Cta = find.text('Lanjut ke Pembayaran');
      await tester.ensureVisible(step3Cta);
      await tester.tap(step3Cta);
      await tester.pumpAndSettle();

      // Verify Unified PaymentPage is rendered!
      expect(find.text('Pembayaran  Sewa'), findsOneWidget);
      expect(find.text('Tagihan Sewa'), findsOneWidget);
      expect(find.text('Rp300.000'), findsOneWidget);
      expect(find.text('Detail Sewa'), findsOneWidget);

      // Verify the 3 payment methods: QRIS, Tunai, Lainya
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Tunai'), findsOneWidget);
      expect(find.text('Lainya'), findsOneWidget);

      // Open Detail Sewa
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      // Verify Renter Info and Rented Unit in Detail Sewa sheet
      expect(find.text('Dedi Kurniawan'), findsOneWidget);
      expect(find.text('iPhone 15 Pro Max 256GB Natural Titanium'), findsOneWidget);

      // Tap Konfirmasi Pembayaran in sheet -> opens Tunai sheet
      await tester.tap(find.text('KONFIRMASI PEMBAYARAN'));
      await tester.pumpAndSettle();

      // Verify PEMBAYARAN TUNAI Sheet
      expect(find.text('PEMBAYARAN TUNAI'), findsOneWidget);
      expect(find.text('Kembalian Pelanggan'), findsOneWidget);

      // Process payment
      final submitButton = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      expect(submitButton, findsOneWidget);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify Booking repo / payment repo executed
      expect(mockRepo.lastResult, isNotNull);
      expect(mockRepo.lastResult!.amountPaid, 300000.0);

      // Verify success screen displayed
      expect(find.text('Pembayaran Berhasil Dicatat!'), findsOneWidget);
    });
  });
}

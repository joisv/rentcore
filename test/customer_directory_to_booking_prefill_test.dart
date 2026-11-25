import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/customers/presentation/widgets/customer_detail_sheet.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';

class MockPaymentRepository extends PaymentRepository {
  PaymentContext? lastContext;

  @override
  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int? paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? notes,
    String? idempotencyKey,
    String? externalReference,
  }) async {
    lastContext = context;
    final isCash = paymentMethodCode.toUpperCase() == 'CASH';
    final change = isCash ? (cashReceived - amountToPay).clamp(0.0, double.infinity) : 0.0;

    return PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'RC-TEST-001',
      receiptNumber: 'RC-TEST-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: change,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
      responseData: {'booking_code': 'RC-TEST-001'},
    );
  }
}

void main() {
  final mockReadyAssets = [
    {
      'id': 10,
      'asset_code': 'IPHONE-15-01',
      'serial_number': 'SN99881234',
      'status': 'ready',
      'condition_grade': 'B',
      'battery_health': 100,
      'category_id': 1,
      'model': {
        'id': 1,
        'name': 'iPhone 15 Pro Max 256GB Natural Titanium',
        'category_id': 1,
      },
      'rental_tier': {
        'daily_rate': 300000.0,
        'hourly_rate': 25000.0,
        'tiers': [
          {'unit': 'day', 'value': 1, 'hours': 24, 'price': 300000.0},
        ],
      },
    },
  ];

  final mockCategories = [
    {'id': 1, 'name': 'Smartphones'},
  ];

  final mockPaymentMethods = [
    {'id': 1, 'code': 'CASH', 'name': 'Tunai (Cash)', 'is_active': true},
  ];

  group('Customer Directory to DirectRentalScreen Dynamic Pre-Fill & Hardcoded Removal Tests', () {
    testWidgets('Walk-in Customer: Text fields are empty with ZERO hardcoded dummy data', (tester) async {
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

      // Step 1: Select unit and proceed to Step 2
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // Verify Step 2 is active
      expect(find.text('DATA PENYEWA'), findsOneWidget);
      expect(find.text('Cari Pelanggan'), findsOneWidget);

      // Verify that hardcoded "Dedi Kurniawan" is COMPLETELY ABSENT
      expect(find.text('Dedi Kurniawan'), findsNothing);
      expect(find.text('081298765432'), findsNothing);
      expect(find.textContaining('Jl. Raya Genteng'), findsNothing);

      // Verify external labels & text form fields exist and have empty strings
      expect(find.text('Nama Penyewa *'), findsOneWidget);
      expect(find.text('Nomor WhatsApp *'), findsOneWidget);
      expect(find.text('Alamat (KTP/SIM) *'), findsOneWidget);
      final nameFieldFinder = find.byKey(const Key('step2_name_field'));
      final phoneFieldFinder = find.byKey(const Key('step2_phone_field'));
      final addressFieldFinder = find.byKey(const Key('step2_address_field'));

      expect(nameFieldFinder, findsOneWidget);
      expect(phoneFieldFinder, findsOneWidget);
      expect(addressFieldFinder, findsOneWidget);

      final nameField = tester.widget<TextFormField>(nameFieldFinder);
      final phoneField = tester.widget<TextFormField>(phoneFieldFinder);
      final addressField = tester.widget<TextFormField>(addressFieldFinder);

      expect(nameField.controller?.text, isEmpty);
      expect(phoneField.controller?.text, isEmpty);
      expect(addressField.controller?.text, isEmpty);

      // Tapping "Lanjut" without entering text should trigger validation errors
      final step2Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step2Cta);
      await tester.tap(step2Cta);
      await tester.pumpAndSettle();

      expect(find.text('Nama penyewa minimal 3 karakter'), findsOneWidget);
      expect(find.text('Nomor WhatsApp wajib diisi minimal 8 digit'), findsOneWidget);
      expect(find.text('Alamat (KTP/SIM) wajib diisi lengkap'), findsOneWidget);

      // Cashier can enter custom walk-in customer details
      await tester.enterText(nameFieldFinder, 'Budi Santoso');
      await tester.enterText(phoneFieldFinder, '081234567890');
      await tester.enterText(addressFieldFinder, 'Jl. Sudirman No. 45, Banyuwangi');
      await tester.pumpAndSettle();

      await tester.tap(step2Cta);
      await tester.pumpAndSettle();

      // Successfully advances to Step 3 with entered data
      expect(find.text('RINGKASAN'), findsOneWidget);
      expect(find.text('Budi Santoso • 081234567890'), findsOneWidget);
    });

    testWidgets('Passing Customer: Prefills fields dynamically and registers customer_id in booking payload', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockPaymentRepository();

      final customerPayload = {
        'id': 42,
        'name': 'Rina Sasmita',
        'phone': '081288889999',
        'address': 'Jl. Ahmad Yani No. 12, Banyuwangi',
        'is_blacklisted': false,
        'bookings_count': 5,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
            paymentRepositoryProvider.overrideWithValue(mockRepo),
            currentShiftProvider.overrideWith(
              (ref) async => {'has_active_shift': true, 'shift_enforcement_enabled': false},
            ),
            currentShiftByBranchProvider.overrideWith(
              (ref, branchId) async => {'has_active_shift': true, 'shift_enforcement_enabled': false},
            ),
          ],
          child: MaterialApp(
            home: DirectRentalScreen(
              customer: customerPayload,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Step 1: Select unit and proceed to Step 2
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // Verify Step 2 has prefilled data
      expect(find.text('Rina Sasmita'), findsOneWidget);
      expect(find.text('081288889999'), findsOneWidget);
      expect(find.text('Jl. Ahmad Yani No. 12, Banyuwangi'), findsOneWidget);
      expect(find.textContaining('Pelanggan Terdaftar • 5x Sewa'), findsOneWidget);

      // Cashier can edit customer fields if needed
      final addressFieldFinder = find.byKey(const Key('step2_address_field'));
      await tester.enterText(addressFieldFinder, 'Jl. Ahmad Yani No. 88 (Pindah Rumah), Banyuwangi');
      await tester.pumpAndSettle();

      // Advance to Step 3
      final step2Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step2Cta);
      await tester.tap(step2Cta);
      await tester.pumpAndSettle();

      // Advance to Payment Page
      final step3Cta = find.text('Buat Sewa');
      await tester.ensureVisible(step3Cta);
      await tester.tap(step3Cta);
      await tester.pumpAndSettle();

      // Open Detail Sewa to verify customer info
      await tester.tap(find.text('Detail Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('Rina Sasmita'), findsOneWidget);
      expect(find.text('081288889999'), findsOneWidget);

      // Confirm payment to trigger executePayment
      await tester.tap(find.text('KONFIRMASI PEMBAYARAN'));
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify captured context contains customer_id and updated address
      expect(mockRepo.lastContext, isNotNull);
      final extraPayload = mockRepo.lastContext!.extraPayload;
      expect(extraPayload?['customer_id'], equals(42));
      expect(extraPayload?['customer_name'], equals('Rina Sasmita'));
      expect(extraPayload?['customer_phone'], equals('081288889999'));
      expect(extraPayload?['customer_address'], equals('Jl. Ahmad Yani No. 88 (Pindah Rumah), Banyuwangi'));
    });

    testWidgets('Passing Customer via RouteSettings arguments: Prefills customer data dynamically', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final customerPayload = {
        'id': 77,
        'name': 'Dewi Sartika',
        'phone': '081377778888',
        'address': 'Jl. Diponegoro No. 10, Banyuwangi',
        'is_blacklisted': false,
        'bookings_count': 3,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
          ],
          child: MaterialApp(
            initialRoute: '/',
            routes: {
              '/': (context) => Scaffold(
                    body: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const DirectRentalScreen(),
                            settings: RouteSettings(arguments: customerPayload),
                          ),
                        );
                      },
                      child: const Text('Go To DirectRental'),
                    ),
                  ),
            },
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Go To DirectRental'));
      await tester.pumpAndSettle();

      // Step 1: Select unit and proceed to Step 2
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // Verify fields pre-filled from RouteSettings arguments
      expect(find.text('Dewi Sartika'), findsOneWidget);
      expect(find.text('081377778888'), findsOneWidget);
      expect(find.text('Jl. Diponegoro No. 10, Banyuwangi'), findsOneWidget);
      expect(find.textContaining('Pelanggan Terdaftar • 3x Sewa'), findsOneWidget);
    });

    testWidgets('CustomerDetailSheet "Sewa Unit" button passes active customer object to DirectRentalScreen', (tester) async {
      final activeCustomer = {
        'id': 99,
        'name': 'Gatot Subroto',
        'phone': '081122334455',
        'email': 'gatot@example.com',
        'address': 'Jl. Pahlawan No. 99, Banyuwangi',
        'is_blacklisted': false,
        'bookings_count': 12,
        'identities': [
          {'identity_type': 'KTP', 'identity_number': '3510001122334455', 'is_verified': true},
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            readyAssetsProvider.overrideWith((ref) => Future.value(mockReadyAssets)),
            categoriesProvider.overrideWith((ref) => Future.value(mockCategories)),
            paymentMethodsProvider.overrideWith((ref) => Future.value(mockPaymentMethods)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerDetailSheet(customer: activeCustomer),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "Sewa Unit" button is enabled
      final sewaBtnFinder = find.widgetWithText(ElevatedButton, 'Sewa Unit');
      expect(sewaBtnFinder, findsOneWidget);
      final sewaBtn = tester.widget<ElevatedButton>(sewaBtnFinder);
      expect(sewaBtn.onPressed, isNotNull);

      // Tap "Sewa Unit"
      await tester.tap(sewaBtnFinder);
      await tester.pumpAndSettle();

      // Should have navigated to DirectRentalScreen
      expect(find.byType(DirectRentalScreen), findsOneWidget);

      // Select unit and go to Step 2
      await tester.tap(find.text('iPhone 15 Pro Max 256GB Natural Titanium'));
      await tester.pumpAndSettle();
      final step1Cta = find.widgetWithText(ElevatedButton, 'Lanjut');
      await tester.ensureVisible(step1Cta);
      await tester.tap(step1Cta);
      await tester.pumpAndSettle();

      // Step 2 should have Gatot Subroto pre-filled
      expect(find.text('Gatot Subroto'), findsOneWidget);
      expect(find.text('081122334455'), findsOneWidget);
      expect(find.text('Jl. Pahlawan No. 99, Banyuwangi'), findsOneWidget);
      expect(find.textContaining('Pelanggan Terdaftar • 12x Sewa'), findsOneWidget);
    });

    testWidgets('CustomerDetailSheet "Sewa Unit" button is disabled for blacklisted customer', (tester) async {
      final blacklistedCustomer = {
        'id': 100,
        'name': 'Penipu Buron',
        'phone': '089988776655',
        'is_blacklisted': true,
        'blacklist_reason': 'Membawa kabur unit kamera',
        'bookings_count': 1,
        'identities': [],
      };

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CustomerDetailSheet(customer: blacklistedCustomer),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final sewaBtnFinder = find.widgetWithText(ElevatedButton, 'Sewa Unit');
      expect(sewaBtnFinder, findsOneWidget);
      final sewaBtn = tester.widget<ElevatedButton>(sewaBtnFinder);
      expect(sewaBtn.onPressed, isNull);
    });
  });
}

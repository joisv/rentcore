import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/services/printer_bluetooth_driver.dart';
import 'package:sewakasir/core/services/thermal_printer_service.dart';
import 'package:sewakasir/core/widgets/unified_thermal_receipt_preview.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/presentation/rental_queue_actions.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';
import 'package:sewakasir/features/printer/presentation/printer_settings_screen.dart';
import 'package:sewakasir/features/printer/presentation/receipt_customization_screen.dart';
import 'package:sewakasir/shared/widgets/thermal_receipt_preview_dialog.dart';

class _CapturingPrinterDriver extends MockPrinterDriver {
  final List<Uint8List> writtenPayloads = [];
  bool connected = true;

  @override
  Future<bool> isConnected() async => connected;

  @override
  Future<bool> connect(String address) async {
    connected = true;
    return true;
  }

  @override
  Future<bool> writeBytes(Uint8List bytes) async {
    writtenPayloads.add(Uint8List.fromList(bytes));
    return true;
  }
}

class _FakeBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() {
    return const BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'SewaKasir Pro Studio',
      activeBranchId: 10,
      activeBranchName: 'Cabang Sudirman',
      businesses: [
        {
          'id': 1,
          'name': 'SewaKasir Pro Studio',
          'address': 'Jl. Sudirman Kav. 12',
          'phone': '081122334455',
          'branches': [
            {
              'id': 10,
              'name': 'Cabang Sudirman',
              'address': 'Jl. Sudirman Kav. 12',
              'phone': '081122334455',
              'is_central': true,
            },
          ],
        },
      ],
    );
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: {'id': 7, 'name': 'Kasir Rina'},
    );
  }
}

class _FakeCashierRepo extends CashierRepository {
  final Map<String, dynamic> receiptPayload;
  _FakeCashierRepo(this.receiptPayload);

  @override
  Future<Map<String, dynamic>> fetchReceipt(dynamic receiptId) async {
    return receiptPayload;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'type': 'cash', 'is_active': true},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'type': 'qris', 'is_active': true},
    ];
  }
}

void main() {
  late _CapturingPrinterDriver capturingDriver;

  const sampleBusiness = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'SewaKasir Pro Studio',
    activeBranchId: 10,
    activeBranchName: 'Cabang Sudirman',
    businesses: [
      {
        'id': 1,
        'name': 'SewaKasir Pro Studio',
        'address': 'Jl. Sudirman Kav. 12',
        'phone': '081122334455',
        'branches': [
          {
            'id': 10,
            'name': 'Cabang Sudirman',
            'address': 'Jl. Sudirman Kav. 12',
            'phone': '081122334455',
          },
        ],
      },
    ],
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    capturingDriver = _CapturingPrinterDriver();
    ThermalPrinterService().setDriver(capturingDriver);
    ThermalPrinterService().setConnectedDevice(
      const ThermalPrinterDevice(
        name: 'SewaKasir BT-58',
        address: 'AA:BB:CC:DD:EE:FF',
        isConnected: true,
      ),
    );
  });

  tearDown(() {
    ThermalPrinterService().setConnectedDevice(null);
  });

  group('1. ReceiptDocumentData & Payment Method Normalization', () {
    test('sample() pulls active BusinessState header and respects paper width settings', () {
      const settings80 = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm80,
        customSlogan: 'Rental Gadget Terpercaya',
        customFooterMessage: 'Terima kasih telah menyewa!',
      );
      final doc = ReceiptDocumentData.sample(sampleBusiness, settings: settings80);

      expect(doc.storeName, equals('SewaKasir Pro Studio'));
      expect(doc.branchName, equals('Cabang Sudirman'));
      expect(doc.storeAddress, equals('Jl. Sudirman Kav. 12'));
      expect(doc.storePhone, equals('081122334455'));
      expect(doc.storeTagline, equals('Rental Gadget Terpercaya'));
      expect(doc.paperWidthMm, equals(80));
      expect(doc.columns, equals(48));
      expect(doc.dividerLine.length, equals(48));
      expect(doc.items.length, equals(2));
      expect(doc.items.first.isAddon, isFalse);
      expect(doc.items.last.isAddon, isTrue);
      expect(doc.isReprint, isFalse);
      expect(doc.footerNote, equals('Terima kasih telah menyewa!'));
    });

    test('normalizes QRIS, Tunai, Transfer Bank, and specific E-Wallets accurately', () {
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('qris_static'), equals('QRIS'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('CASH'), equals('Tunai'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('bank_transfer'), equals('Transfer Bank'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('Transfer BCA'), equals('Transfer BCA'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('gopay'), equals('GoPay'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('ovo'), equals('OVO'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('dana'), equals('DANA'));
      expect(ReceiptDocumentData.normalizePaymentMethodLabel('shopeepay'), equals('ShopeePay'));
    });

    test('fromTransaction() maps booking + receiptData including line items, collateral, and QRIS', () {
      final doc = ReceiptDocumentData.fromTransaction(
        business: sampleBusiness,
        booking: {
          'id': 99,
          'booking_code': 'SK-2026-0099',
          'duration_hours': 24,
          'collateral_type_name': 'KTP Fisik',
          'collateral_storage_slot': 'Slot A3',
          'customer': {'name': 'Andi Wijaya', 'phone': '081298765432'},
        },
        receiptData: {
          'receipt_number': 'INV-2026-0099',
          'cashier_name': 'Kasir Rina',
          'transacted_at': '2026-11-25 14:30:00',
          'payment_method': 'qris_dynamic',
          'subtotal': 350000,
          'discount_amount': 25000,
          'total_amount': 325000,
          'items': [
            {
              'name': 'Sony A7 IV Body',
              'asset_code': 'CAM-01',
              'price': 300000,
              'is_addon': false,
            },
            {
              'name': 'Baterai NP-FZ100',
              'asset_code': 'ACC-09',
              'price': 50000,
              'is_addon': true,
            },
          ],
        },
        isReprint: true,
      );

      expect(doc.storeName, equals('SewaKasir Pro Studio'));
      expect(doc.branchName, equals('Cabang Sudirman'));
      expect(doc.transactionCode, equals('INV-2026-0099'));
      expect(doc.bookingCode, equals('SK-2026-0099'));
      expect(doc.customerName, equals('Andi Wijaya'));
      expect(doc.paymentMethodLabel, equals('QRIS'));
      expect(doc.collateralSummary, contains('KTP Fisik'));
      expect(doc.items.length, equals(2));
      expect(doc.items[0].name, equals('Sony A7 IV Body'));
      expect(doc.items[1].isAddon, isTrue);
      expect(doc.discount, equals(25000));
      expect(doc.totalAmount, equals(325000));
      expect(doc.isReprint, isTrue);
    });
  });

  group('2. ThermalReceiptEscPosBuilder & Unified printReceipt Pipeline', () {
    test('generates identical store header, items, payment method, and [CETAK ULANG] tag when isReprint == true', () async {
      final doc = ReceiptDocumentData(
        storeName: 'SewaKasir Pro Studio',
        storeTagline: 'Cepat & Aman',
        storeAddress: 'Jl. Sudirman Kav. 12',
        storePhone: '081122334455',
        branchName: 'Cabang Sudirman',
        title: 'STRUK TRANSAKSI SEWA',
        transactionCode: 'INV-2026-0088',
        bookingCode: 'SK-2026-0088',
        printedAt: '25 Nov 2026, 15:00',
        cashierName: 'Kasir Rina',
        customerName: 'Nadia Putri',
        customerPhone: '081234567890',
        rentalPeriodLabel: '24 Jam',
        isReprint: true,
        items: const [
          ReceiptDocumentItem(
            name: 'iPhone 15 Pro 256GB',
            variantOrCode: 'IPH-15P-01',
            quantity: 1,
            unitPrice: 250000,
          ),
          ReceiptDocumentItem(
            name: 'Tripod Mini',
            variantOrCode: 'ACC-TR-02',
            quantity: 1,
            unitPrice: 30000,
            isAddon: true,
          ),
        ],
        subtotal: 280000,
        discount: 30000,
        collateralSummary: 'KTP Fisik - Slot A1',
        totalAmount: 250000,
        paidAmount: 250000,
        changeAmount: 0,
        paymentMethodLabel: 'GoPay',
        paperWidthMm: 58,
        footerNote: 'Terima kasih telah bertransaksi!',
      );

      final builtBytes = ThermalReceiptEscPosBuilder.build(doc);
      final ok = await ThermalPrinterService().printReceipt(doc);

      expect(ok, isTrue);
      expect(capturingDriver.writtenPayloads, hasLength(1));
      expect(capturingDriver.writtenPayloads.first, equals(builtBytes));

      // Verify ESC @ init and GS V 1 partial cut
      expect(builtBytes.sublist(0, 2), equals([0x1B, 0x40]));
      expect(builtBytes.sublist(builtBytes.length - 3), equals([0x1D, 0x56, 0x01]));

      final decoded = latin1.decode(builtBytes);
      expect(decoded, contains('SewaKasir Pro Studio'));
      expect(decoded, contains('Cabang Sudirman'));
      expect(decoded, contains('Jl. Sudirman Kav. 12'));
      expect(decoded, contains('Telp: 081122334455'));
      expect(decoded, contains('[CETAK ULANG]'));
      expect(decoded, contains('INV-2026-0088'));
      expect(decoded, contains('iPhone 15 Pro 256GB'));
      expect(decoded, contains('Tripod Mini (Add-on)'));
      expect(decoded, contains('GoPay'));
      expect(decoded, contains('KTP Fisik - Slot A1'));
      expect(decoded, contains('Terima kasih telah bertransaksi!'));
      expect(decoded, contains('-' * 32));
    });

    test('omits [CETAK ULANG] tag for initial checkout print and uses 48-char divider for 80mm', () {
      final doc = ReceiptDocumentData.sample(
        sampleBusiness,
        settings: const ReceiptCustomizationSettings(paperWidth: ReceiptPaperWidth.mm80),
        isReprint: false,
      );

      final bytes = ThermalReceiptEscPosBuilder.build(doc);
      final decoded = latin1.decode(bytes);

      expect(decoded, isNot(contains('[CETAK ULANG]')));
      expect(decoded, contains('-' * 48));
      expect(decoded, contains('SewaKasir Pro Studio'));
    });
  });

  group('3. Unified Widget Preview Parity across Printer Settings, Dashboard Queue, Detail & Checkout', () {
    testWidgets(
      'Pengaturan Printer and Desain Struk render UnifiedThermalReceiptPreview and react live to 58mm/80mm & header edits',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: const MaterialApp(home: PrinterSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // PrinterSettingsScreen displays UnifiedThermalReceiptPreview at 58mm initially
        expect(find.byType(UnifiedThermalReceiptPreview), findsOneWidget);
        expect(find.byKey(const Key('unified_thermal_receipt_paper_58mm')), findsOneWidget);
        expect(find.text('SewaKasir Pro Studio'), findsOneWidget);
        expect(find.text('iPhone 15 Pro Max 256GB Natural'), findsOneWidget);

        // Switching to 80mm updates UnifiedThermalReceiptPreview reactively
        await tester.tap(find.text('80mm POS'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('unified_thermal_receipt_paper_80mm')), findsOneWidget);

        // Navigating to Desain Struk uses the exact same UnifiedThermalReceiptPreview
        await tester.tap(find.text('Desain Struk'));
        await tester.pumpAndSettle();
        expect(find.byType(ReceiptCustomizationScreen), findsOneWidget);
        expect(find.byType(UnifiedThermalReceiptPreview), findsOneWidget);
        expect(find.byKey(const Key('unified_thermal_receipt_paper_80mm')), findsOneWidget);
      },
    );

    testWidgets(
      'Dashboard Queue Cetak Struk modal renders UnifiedThermalReceiptPreview with [CETAK ULANG] and prints identical ESC/POS bytes',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final booking = {
          'id': 55,
          'booking_code': 'SK-2026-0055',
          'status': 'returned',
          'payment_status': 'paid',
          'duration_hours': 24,
          'collateral_type_name': 'KTP Fisik',
          'collateral_storage_slot': 'Slot C1',
          'customer': {'name': 'Budi Santoso', 'phone': '081234567890'},
          'affiliate': {
            'name': 'Cabang Sudirman',
            'address': 'Jl. Sudirman Kav. 12',
            'phone': '081122334455',
          },
          'payments': [
            {
              'id': 501,
              'receipt_number': 'INV-0055',
              'amount': 325000,
              'payment_method': 'QRIS',
              'status': 'paid',
            },
          ],
        };

        final fakeRepo = _FakeCashierRepo({
          'receipt_number': 'INV-0055',
          'outlet_name': 'Cabang Sudirman',
          'outlet_address': 'Jl. Sudirman Kav. 12',
          'outlet_phone': '081122334455',
          'cashier_name': 'Kasir Rina',
          'customer_name': 'Budi Santoso',
          'customer_phone': '081234567890',
          'booking_code': 'SK-2026-0055',
          'duration_hours': 24,
          'subtotal': 350000,
          'discount_amount': 25000,
          'total_amount': 325000,
          'payment_method': 'QRIS',
          'transacted_at': '2026-11-25 11:15:00',
          'items': [
            {
              'name': 'iPhone 15 Pro Max',
              'asset_code': 'IPH-15PM-02',
              'price': 325000,
              'is_addon': false,
            },
            {
              'name': 'Powerbank MagSafe',
              'asset_code': 'ACC-PB-01',
              'price': 25000,
              'is_addon': true,
            },
          ],
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => ElevatedButton(
                    onPressed: () => RentalQueueActions.printBookingReceipt(
                      context,
                      ref,
                      booking,
                    ),
                    child: const Text('Cetak Struk'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Cetak Struk'));
        await tester.pumpAndSettle();

        // Uses exact same UnifiedThermalReceiptPreview widget
        expect(find.byType(ThermalReceiptPreviewDialog), findsOneWidget);
        expect(find.byType(UnifiedThermalReceiptPreview), findsOneWidget);
        expect(find.byKey(const Key('unified_receipt_reprint_badge')), findsOneWidget);
        expect(find.text('[CETAK ULANG]'), findsOneWidget);
        expect(find.text('SewaKasir Pro Studio'), findsOneWidget);
        expect(find.text('Cabang Sudirman'), findsOneWidget);
        expect(find.text('iPhone 15 Pro Max'), findsOneWidget);
        expect(find.text('Powerbank MagSafe (Add-on)'), findsOneWidget);
        expect(find.text('QRIS'), findsOneWidget);

        // Tap Cetak Thermal -> dispatches via printReceipt(ReceiptDocumentData)
        await tester.tap(find.byKey(const Key('print_thermal_receipt_button')));
        await tester.pumpAndSettle();

        expect(capturingDriver.writtenPayloads, hasLength(1));
        final printedText = latin1.decode(capturingDriver.writtenPayloads.first);
        expect(printedText, contains('SewaKasir Pro Studio'));
        expect(printedText, contains('[CETAK ULANG]'));
        expect(printedText, contains('iPhone 15 Pro Max'));
        expect(printedText, contains('Powerbank MagSafe (Add-on)'));
        expect(printedText, contains('QRIS'));
      },
    );

    testWidgets(
      'PaymentPage initial checkout print renders UnifiedThermalReceiptPreview without [CETAK ULANG] badge',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _FakeCashierRepo({
          'receipt_number': 'INV-0077',
          'outlet_name': 'Cabang Sudirman',
          'cashier_name': 'Kasir Rina',
          'customer_name': 'Siti Aminah',
          'total_amount': 200000,
          'payment_method': 'Transfer Bank',
          'transacted_at': '2026-11-25 12:00:00',
          'items': [
            {'name': 'iPad Pro M4', 'asset_code': 'IPD-04', 'price': 200000},
          ],
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
              authProvider.overrideWith(_FakeAuthNotifier.new),
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: PaymentPage(
                paymentContext: PaymentContext.booking(
                  customerName: 'Siti Aminah',
                  deviceName: 'iPad Pro M4',
                  totalAmount: 200000,
                  branchId: 10,
                  branchName: 'Cabang Sudirman',
                  items: const [
                    PaymentItem(
                      name: 'iPad Pro M4',
                      assetCode: 'IPD-04',
                      price: 200000,
                      durationText: '24 Jam',
                    ),
                  ],
                ),
                initialResult: const PaymentResult(
                  status: PaymentStatus.completed,
                  amountPaid: 200000,
                  cashReceived: 200000,
                  cashChange: 0,
                  paymentMethodCode: 'BANK_TRANSFER',
                  paymentMethodName: 'Transfer Bank',
                  receiptNumber: 'INV-0077',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('print_payment_receipt_button')));
        await tester.pumpAndSettle();

        final previewFinder = find.byType(UnifiedThermalReceiptPreview);
        expect(previewFinder, findsOneWidget);
        expect(find.byKey(const Key('unified_receipt_reprint_badge')), findsNothing);
        expect(
          find.descendant(of: previewFinder, matching: find.text('iPad Pro M4')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: previewFinder, matching: find.text('Transfer Bank')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'PosTransactionDetailSheet reprint modal renders UnifiedThermalReceiptPreview with [CETAK ULANG]',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _FakeCashierRepo({
          'receipt_number': 'INV-0077',
          'outlet_name': 'Cabang Sudirman',
          'cashier_name': 'Kasir Rina',
          'customer_name': 'Siti Aminah',
          'total_amount': 200000,
          'payment_method': 'Transfer Bank',
          'transacted_at': '2026-11-25 12:00:00',
          'items': [
            {'name': 'iPad Pro M4', 'asset_code': 'IPD-04', 'price': 200000},
          ],
        });

        final booking = {
          'id': 77,
          'booking_code': 'SK-2026-0077',
          'status': 'rented',
          'payment_status': 'paid',
          'total_bill': 200000,
          'subtotal_amount': 200000,
          'discount_amount': 0,
          'customer': {'name': 'Siti Aminah'},
          'affiliate': {'name': 'Cabang Sudirman'},
          'payments': [
            {
              'id': 701,
              'receipt_number': 'INV-0077',
              'type': 'rental',
              'amount': 200000,
              'payment_method': 'Transfer Bank',
              'status': 'paid',
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              bookingDetailProvider(77).overrideWith((ref) async => booking),
            ],
            child: MaterialApp(
              home: Scaffold(body: PosTransactionDetailSheet(booking: booking)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reprintBtn = find.byKey(const Key('reprint_receipt_button'));
        await tester.ensureVisible(reprintBtn);
        await tester.tap(reprintBtn);
        await tester.pumpAndSettle();

        final detailPreviewFinder = find.byType(UnifiedThermalReceiptPreview);
        expect(detailPreviewFinder, findsOneWidget);
        expect(
          find.descendant(of: detailPreviewFinder, matching: find.text('[CETAK ULANG]')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailPreviewFinder, matching: find.text('iPad Pro M4')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: detailPreviewFinder, matching: find.text('Transfer Bank')),
          findsOneWidget,
        );
      },
    );
  });
}

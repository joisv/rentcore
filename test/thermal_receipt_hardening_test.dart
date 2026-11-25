import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/services/printer_bluetooth_driver.dart';
import 'package:sewakasir/core/services/thermal_printer_service.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';
import 'package:sewakasir/features/printer/presentation/printer_settings_screen.dart';
import 'package:sewakasir/shared/widgets/thermal_receipt_preview_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThermalPrinterService().setDriver(MockPrinterDriver());
    ThermalPrinterService().setConnectedDevice(null);
  });

  group('Hardening 1 & 2: Dynamic Tenant Branding & Bagikan Struk PNG', () {
    testWidgets(
      'ThermalReceiptPreviewDialog shows dynamic business/branch branding, reprint note, and captures PNG on Bagikan Struk',
      (tester) async {
        Uint8List? capturedPng;
        String? capturedCaption;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_TenantBusinessNotifier.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => ThermalReceiptPreviewDialog(
                          title: 'Cetak Ulang Struk POS',
                          branchName: 'Cabang Kemang',
                          isReprint: true,
                          qrData: 'INV-2026-001',
                          escposBytes: Uint8List.fromList([0x1B, 0x40]),
                          onShareImage: (png, caption) async {
                            capturedPng = png;
                            capturedCaption = caption;
                          },
                          content: const Text('Total: Rp 300.000'),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        expect(find.text('Kamera Nusantara'), findsOneWidget);
        expect(find.text('Cabang Kemang'), findsOneWidget);
        expect(find.text('Jl. Kemang Raya No. 10'), findsOneWidget);
        expect(find.text('Telp: 08123456789'), findsOneWidget);
        expect(find.text('-- CETAK ULANG --'), findsOneWidget);
        expect(find.textContaining('RENTCORE GADGETS'), findsNothing);

        final shareBtn = find.byKey(const Key('share_receipt_png_button'));
        expect(shareBtn, findsOneWidget);
        expect(find.text('Bagikan Struk'), findsOneWidget);

        await tester.runAsync(() async {
          await tester.tap(shareBtn);
          await Future<void>.delayed(const Duration(milliseconds: 50));
        });
        await tester.pump();

        expect(capturedPng, isNotNull);
        // PNG magic header: 89 50 4E 47
        expect(capturedPng!.sublist(0, 4), equals([0x89, 0x50, 0x4E, 0x47]));
        expect(capturedCaption, contains('Kamera Nusantara'));
      },
    );
  });

  group('Hardening 3 & 4a: SharedPreferences Persistence, Raster QR, Feed Lines & Permission Denial', () {
    testWidgets(
      'PrinterSettingsScreen persists mac_address, printer_name, paper_width, extra_feed_lines, and use_raster_qr',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: PrinterSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap 80mm, increment extra_feed_lines (3 -> 4), toggle raster QR (false -> true)
        await tester.tap(find.text('80mm POS'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('feed_lines_increment_button')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('use_raster_qr_switch')));
        await tester.pumpAndSettle();

        // Connect first discovered printer
        await tester.tap(find.text('Hubungkan').first);
        await tester.pumpAndSettle();

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getInt('paper_width'), equals(80));
        expect(prefs.getInt('extra_feed_lines'), equals(4));
        expect(prefs.getBool('use_raster_qr'), isTrue);
        expect(prefs.getString('mac_address'), equals('00:11:22:33:44:55'));
        expect(prefs.getString('printer_name'), equals('RPP-02N Bluetooth Printer (58mm)'));
      },
    );

    testWidgets(
      'Permission denial in PrinterSettingsScreen shows clean SnackBar without throwing',
      (tester) async {
        ThermalPrinterService().setDriver(_DeniedPermDriver());
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(home: PrinterSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.textContaining('Izin Bluetooth'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('Hardening 4b: PosTransactionDetailSheet Reprint & Post-Payment Share Button', () {
    testWidgets(
      'PosTransactionDetailSheet has Cetak Ulang Struk button that sets isReprint=true',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final booking = {
          'id': 42,
          'booking_code': 'RC-2026-0042',
          'status': 'rented',
          'payment_status': 'paid',
          'total_bill': 300000,
          'subtotal_amount': 300000,
          'discount_amount': 0,
          'customer': {'name': 'Budi Santoso'},
          'affiliate': {'name': 'Cabang Kemang', 'address': 'Jl. Kemang Raya No. 10', 'phone': '08123456789'},
          'payments': [
            {
              'id': 10,
              'receipt_number': 'INV-0042',
              'type': 'rental',
              'amount': 300000,
              'payment_method': 'Tunai',
              'status': 'paid',
            }
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_TenantBusinessNotifier.new),
              cashierRepositoryProvider.overrideWithValue(_FakeCashierRepo()),
              bookingDetailProvider(42).overrideWith((ref) async => booking),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: PosTransactionDetailSheet(booking: booking),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final reprintBtn = find.byKey(const Key('reprint_receipt_button'));
        expect(reprintBtn, findsOneWidget);
        expect(find.text('Cetak Ulang Struk'), findsOneWidget);

        await tester.ensureVisible(reprintBtn);
        await tester.tap(reprintBtn);
        await tester.pumpAndSettle();

        final dialogFinder = find.byType(ThermalReceiptPreviewDialog);
        expect(dialogFinder, findsOneWidget);
        final dialog = tester.widget<ThermalReceiptPreviewDialog>(dialogFinder);
        expect(dialog.isReprint, isTrue);
        expect(find.text('[CETAK ULANG]'), findsOneWidget);
        expect(latin1.decode(dialog.escposBytes), contains('[CETAK ULANG]'));
      },
    );

    testWidgets(
      'PaymentPage success prompt shows Bagikan Struk secondary button alongside Cetak Struk',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(_TenantBusinessNotifier.new),
              authProvider.overrideWith(_TenantAuthNotifier.new),
              cashierRepositoryProvider.overrideWithValue(_FakeCashierRepo()),
              paymentRepositoryProvider.overrideWithValue(_FakePaymentRepo()),
            ],
            child: MaterialApp(
              home: PaymentPage(
                paymentContext: PaymentContext(
                  transactionType: PaymentTransactionType.settlement,
                  bookingId: 77,
                  bookingCode: 'RC-2026-0077',
                  customerName: 'Siti',
                  totalAmountDue: 100000,
                  remainingDue: 100000,
                  branchId: 1,
                  branchName: 'Cabang Kemang',
                ),
                initialResult: const PaymentResult(
                  status: PaymentStatus.completed,
                  amountPaid: 100000,
                  cashReceived: 100000,
                  cashChange: 0,
                  paymentMethodCode: 'CASH',
                  paymentMethodName: 'Tunai',
                  receiptNumber: 'INV-0077',
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('print_payment_receipt_button')), findsOneWidget);
        expect(find.byKey(const Key('share_payment_receipt_button')), findsOneWidget);
        expect(find.text('Bagikan Struk'), findsOneWidget);
      },
    );
  });
}

class _TenantBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() {
    return const BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'Kamera Nusantara',
      activeBranchId: 10,
      activeBranchName: 'Cabang Kemang',
      businesses: [
        {
          'id': 1,
          'name': 'Kamera Nusantara',
          'address': 'Jl. Pusat No. 1',
          'phone': '021999888',
          'branches': [
            {
              'id': 10,
              'name': 'Cabang Kemang',
              'address': 'Jl. Kemang Raya No. 10',
              'phone': '08123456789',
            }
          ],
        }
      ],
    );
  }
}

class _TenantAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: {'id': 1, 'name': 'Kasir Rina'},
    );
  }
}

class _DeniedPermDriver extends MockPrinterDriver {
  @override
  Future<bool> checkAndRequestPermissions() async => false;
}

class _FakeCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchReceipt(dynamic receiptId) async {
    return {
      'receipt_number': 'INV-0042',
      'outlet_name': 'Cabang Kemang',
      'cashier_name': 'Kasir Rina',
      'total_amount': 300000,
      'payment_method': 'Tunai',
      'transacted_at': '2026-11-21 10:00',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'type': 'cash', 'is_active': true},
    ];
  }
}

class _FakePaymentRepo extends PaymentRepository {
  @override
  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int? paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? externalReference,
    String? notes,
    String? idempotencyKey,
  }) async {
    return PaymentResult(
      status: PaymentStatus.completed,
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: cashReceived - amountToPay,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
      receiptNumber: 'INV-0077',
    );
  }
}

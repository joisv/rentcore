import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/services/qris_service.dart';
import 'package:rentcore_mobile/core/services/thermal_printer_service.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';
import 'package:rentcore_mobile/features/printer/providers/printer_provider.dart';
import 'package:rentcore_mobile/shared/widgets/thermal_receipt_preview_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _tlv(String tag, String value) {
  return '$tag${value.length.toString().padLeft(2, '0')}$value';
}

String _buildStrictStaticQris() {
  final tag26 = '${_tlv('00', 'ID.CO.GOPAY.WWW')}${_tlv('01', '11')}${_tlv('02', '936005402991234')}';
  const merchantName = 'TOKO 540299 010211';
  final tag62 = '${_tlv('01', '11')}${_tlv('05', '540299')}';

  final body = '${_tlv('00', '01')}'
      '${_tlv('01', '11')}'
      '${_tlv('26', tag26)}'
      '${_tlv('52', '5812')}'
      '${_tlv('53', '360')}'
      '${_tlv('54', '10000')}'
      '${_tlv('58', 'ID')}'
      '${_tlv('59', merchantName)}'
      '${_tlv('60', 'JAKARTA')}'
      '${_tlv('61', '12340')}'
      '${_tlv('62', tag62)}'
      '6304';

  return '$body${QrisService.calculateCrc16(body)}';
}

bool _containsSublist(Uint8List haystack, List<int> needle) {
  if (needle.isEmpty || haystack.length < needle.length) return false;
  for (int i = 0; i <= haystack.length - needle.length; i++) {
    var matched = true;
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

class _Wave3AuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {'id': '99', 'name': 'Siti Kasir', 'role': 'staff'},
      );
}

class _Wave3BusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore',
        activeBranchId: 1,
        activeBranchName: 'Cabang Sudirman',
      );
}

class _Wave3PrinterNotifier extends PrinterNotifier {
  final ReceiptPaperWidth _paperWidth;
  _Wave3PrinterNotifier(this._paperWidth);

  @override
  PrinterState build() => PrinterState(
        settings: ReceiptCustomizationSettings(paperWidth: _paperWidth),
      );
}

class _FakeWave3ShiftRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    return {
      'id': shiftId ?? 77,
      'shift_number': 'SHF-20261119-077',
      'status': 'closed',
      'opened_at': '2026-11-19T08:00:00+07:00',
      'closed_at': '2026-11-19T17:30:00+07:00',
      'opening_cash_float': 300000.0,
      'cash_inflow': 450000.0,
      'non_cash_inflow': 600000.0,
      'cash_expenses': 50000.0,
      'total_transactions': 14,
      'expected_cash_total': 700000.0,
      'actual_cash_counted': actualCashCounted,
      'cash_difference': actualCashCounted - 700000.0,
    };
  }
}

class _FakeWave3CashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': true,
      'shift_enforcement_enabled': true,
      'shift': {
        'id': 77,
        'shift_number': 'SHF-20261119-077',
        'status': 'open',
        'opening_cash_float': 300000.0,
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    final strictQris = _buildStrictStaticQris();
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS Dinamis', 'code': 'QRIS', 'qris_raw_payload': strictQris},
      {'id': 3, 'name': 'Transfer Bank BCA', 'code': 'BCA'},
      {'id': 7, 'name': 'ShopeePay', 'code': 'SHOPEEPAY'},
    ];
  }
}

class _SpyWave3PaymentRepo extends PaymentRepository {
  String? capturedExternalReference;
  String? capturedMethodCode;
  double? capturedAmountToPay;
  double? capturedCashReceived;

  _SpyWave3PaymentRepo() : super(cashierRepo: _FakeWave3CashierRepo());

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
    capturedMethodCode = paymentMethodCode;
    capturedAmountToPay = amountToPay;
    capturedCashReceived = cashReceived;
    capturedExternalReference = externalReference;

    return PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'TX-W3-001',
      receiptNumber: 'RCP-W3-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: paymentMethodCode == 'CASH'
          ? (cashReceived - amountToPay).clamp(0.0, double.infinity)
          : 0.0,
      paymentMethodName: paymentMethodName,
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Wave 3: Dart EMVCo Root TLV QRIS Parser', () {
    test('updates only root tags 01 & 54 while keeping nested 010211 / 540299 intact and CRC valid', () {
      final staticQris = _buildStrictStaticQris();
      expect(QrisService.hasValidCrc(staticQris), isTrue);

      final dynamicQris = QrisService.generateDynamicQris(staticQris, 150000);
      expect(QrisService.hasValidCrc(dynamicQris), isTrue);

      // Must contain dynamic tag 01=12 and tag 54=150000 at root, NOT static 54=10000
      expect(dynamicQris.startsWith('000201010212'), isTrue);
      expect(dynamicQris.contains('530336054061500005802ID'), isTrue);

      // Nested lookalikes in tag 26, tag 59, and tag 62 remain completely preserved
      expect(dynamicQris.contains('0015ID.CO.GOPAY.WWW0102110215936005402991234'), isTrue);
      expect(dynamicQris.contains('5918TOKO 540299 010211'), isTrue);
      expect(dynamicQris.contains('62160102110506540299'), isTrue);
    });
  });

  group('Wave 3: ThermalPrinterService Closing, POS, 58mm/80mm QR, Wrapping & Sanitization', () {
    final service = ThermalPrinterService();

    test('buildClosingShiftSlipBytes respects 80mm 48-col width and prints full closing metadata', () {
      final bytes = service.buildClosingShiftSlipBytes(
        branchName: 'Cabang Sudirman',
        cashierName: 'Siti Kasir',
        date: '19 Nov 2026',
        shiftNumber: 'SHF-20261119-077',
        openingCashFloat: 300000,
        totalTransactions: 14,
        totalRevenue: 1050000,
        paymentBreakdown: const {'Tunai': 450000, 'Non-Tunai': 600000},
        netCashRevenue: 450000,
        nonCashInflow: 600000,
        cashDrawerExpenses: 50000,
        expectedCashInDrawer: 700000,
        actualCashCounted: 705000,
        cashDifference: 5000,
        openedAt: '2026-11-19 08:00',
        closedAt: '2026-11-19 17:30',
        paperWidth: ReceiptPaperWidth.mm80,
      );

      final decoded = latin1.decode(bytes);
      expect(decoded, contains('=' * 48));
      expect(decoded, contains('-' * 48));
      expect(decoded, contains('Cabang Sudirman'));
      expect(decoded, contains('Siti Kasir'));
      expect(decoded, contains('2026-11-19 08:00'));
      expect(decoded, contains('2026-11-19 17:30'));
      expect(decoded, contains('Total Transaksi'));
      expect(decoded, contains('14'));
      expect(decoded, contains('Non-Tunai'));
      expect(decoded, contains('FISIK KAS DIHITUNG'));
      expect(decoded, contains('SELISIH KAS'));
    });

    test('buildPosPaymentSlipBytes renders Subtotal, Diskon, DP BELUM LUNAS / LUNAS, and wraps long lines cleanly', () {
      const mm58 = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
        showQrBarcode: true,
        showReturnTerms: false,
        customFooterMessage: '',
      );
      final dpModel = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: 'Cabang Kemang • Utama — Jaksel',
        receiptNumber: 'RCP-W3-DP',
        bookingCode: 'RC-261119-0099',
        customerName: 'Budi',
        cashierName: 'Siti Kasir',
        items: const [
          {
            'name': 'MacBook Pro 16 M3 Max Ultra Long Title Item Name For Wrapping',
            'price': 500000.0,
            'duration': '2 Hari',
          },
        ],
        subtotal: 500000,
        discount: 50000,
        totalAmount: 200000,
        paymentMethod: 'QRIS',
        isDownPayment: true,
        remainingBalance: 250000,
        transactedAt: '2026-11-19 12:00',
      );

      final dpBytes = service.buildPosPaymentSlipBytes(dpModel, mm58);
      final dpText = latin1.decode(dpBytes);

      // Unicode punctuation sanitized without UTF-8 multi-byte garbling
      expect(dpText, isNot(contains('â€¢')));
      expect(dpText, isNot(contains('â€”')));
      expect(dpText, contains('Cabang Kemang - Utama - Jaksel'));

      // Subtotal, Diskon & DP status present
      expect(dpText, contains('Subtotal'));
      expect(dpText, contains('Diskon'));
      expect(dpText, contains('STATUS: DP (BELUM LUNAS)'));
      expect(dpText, contains('Sisa Tagihan'));

      // Native ESC/POS QR emitted via ReceiptDocument on 58mm with module size 4 (0x04)
      final dpDoc = service.buildReceiptDocument(dpModel, mm58);
      final dpDocBytes = service.buildSlipBytesFromDocument(dpDoc, mm58);
      expect(
        _containsSublist(dpDocBytes, const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04]),
        isTrue,
      );

      // Printable text lines do not exceed 32 characters on 58mm (strip 2-byte/3-byte ESC/POS sequences first)
      final strippedEscPos = dpText
          .replaceAll(RegExp(r'\x1B@|\x1B[aEd].|\x1D!.|\x1DV.'), '')
          .replaceAll(RegExp(r'[\x00-\x09\x0B-\x1F\x7F]'), '');
      final printableLines = strippedEscPos.split('\n');
      for (final line in printableLines) {
        expect(line.length, lessThanOrEqualTo(32), reason: 'Overflow line: "$line"');
      }

      // LUNAS branch + 80mm QR module size 6 (0x06)
      const mm80 = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm80,
        showQrBarcode: true,
      );
      final paidModel = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: 'Cabang Kemang',
        receiptNumber: 'RCP-W3-PAID',
        bookingCode: 'RC-261119-0100',
        customerName: 'Andi',
        cashierName: 'Siti Kasir',
        totalAmount: 450000,
        paymentMethod: 'Tunai',
        isDownPayment: false,
        transactedAt: '2026-11-19 12:15',
      );

      final paidBytes = service.buildPosPaymentSlipBytes(paidModel, mm80);
      final paidText = latin1.decode(paidBytes);
      expect(paidText, contains('STATUS: LUNAS'));
      expect(paidText, isNot(contains('STATUS: DP (BELUM LUNAS)')));

      final paidDocBytes = service.buildSlipBytesFromDocument(
        service.buildReceiptDocument(paidModel, mm80),
        mm80,
      );
      expect(
        _containsSublist(paidDocBytes, const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]),
        isTrue,
      );
    });

    test('buildRentalBookingSlipBytes & buildTestSlipBytes emit native ESC/POS QR on 58mm', () {
      const mm58 = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
        showQrBarcode: true,
        showReturnTerms: false,
        customFooterMessage: '',
      );

      final bookingBytes = service.buildRentalBookingSlipBytes(
        ReceiptDataModel(
          type: ReceiptType.rentalBooking,
          title: 'STRUK BUKTI SEWA',
          branchName: 'Cabang Pusat',
          bookingCode: 'RC-261119-0055',
          customerName: 'Rina',
          totalAmount: 150000,
          paymentMethod: 'Tunai',
          transactedAt: '2026-11-19 10:00',
        ),
        mm58,
      );
      expect(
        _containsSublist(bookingBytes, const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04]),
        isTrue,
      );

      final testBytes = service.buildTestSlipBytes(mm58);
      expect(
        _containsSublist(testBytes, const [0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x04]),
        isTrue,
      );
    });
  });

  group('Wave 3: Closing Shift Print Dialog Real Auth & Branch Metadata', () {
    testWidgets('uses active branchName, auth user name, and totalTransactions instead of hardcoded placeholders', (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeShift = {
        'id': 77,
        'shift_number': 'SHF-20261119-077',
        'status': 'open',
        'opened_at': '2026-11-19T08:00:00+07:00',
        'opening_cash_float': 300000.0,
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(_FakeWave3ShiftRepo()),
            authProvider.overrideWith(_Wave3AuthNotifier.new),
            businessProvider.overrideWith(_Wave3BusinessNotifier.new),
            printerProvider.overrideWith(() => _Wave3PrinterNotifier(ReceiptPaperWidth.mm80)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) {
                  ref.watch(authProvider);
                  ref.watch(businessProvider);
                  return CashDrawerShiftModal(activeShift: activeShift);
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Direct Lump-sum & enter counted cash
      await tester.tap(find.text('Input Total Langsung'));
      await tester.pumpAndSettle();
      final textFields = find.widgetWithText(TextFormField, '');
      await tester.enterText(textFields.first, '700000');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tutup Shift & Rekapitulasi Kasir'));
      await tester.pumpAndSettle();

      // Closing slip preview dialog & generated ESC/POS bytes use real branch, user, trx count, and mm80 width
      expect(find.text('Cabang Kasir'), findsNothing);
      expect(find.text('Staff Kasir'), findsNothing);
      final dialogFinder = find.byType(ThermalReceiptPreviewDialog);
      expect(dialogFinder, findsOneWidget);
      final previewDialog = tester.widget<ThermalReceiptPreviewDialog>(dialogFinder);
      expect(previewDialog.branchName, 'Cabang Sudirman');

      final slipText = latin1.decode(previewDialog.escposBytes);
      expect(slipText, contains('Cabang Sudirman'));
      expect(slipText, contains('Siti Kasir'));
      expect(slipText, contains('14'));
      expect(slipText, contains('600.000'));
      expect(slipText, contains('=' * 48));
      expect(slipText, isNot(contains('Cabang Kasir')));
      expect(slipText, isNot(contains('Staff Kasir')));
    });
  });

  group('Wave 3: PaymentPage Decimal Precision & Non-Cash Reference Capture', () {
    testWidgets('preserves non-zero decimals in Tunai input and captures external_reference from QRIS sheet', (tester) async {
      tester.view.physicalSize = const Size(412 * 2, 915 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final spyRepo = _SpyWave3PaymentRepo();
      final ctx = PaymentContext(
        transactionType: PaymentTransactionType.settlement,
        bookingId: 505,
        bookingCode: 'RC-261119-0505',
        customerName: 'Dewi Anggraini',
        totalAmountDue: 150000.50,
        remainingDue: 150000.50,
        branchId: 1,
        branchName: 'Cabang Sudirman',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(_FakeWave3CashierRepo()),
            paymentRepositoryProvider.overrideWithValue(spyRepo),
            authProvider.overrideWith(_Wave3AuthNotifier.new),
            businessProvider.overrideWith(_Wave3BusinessNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: PaymentPage(paymentContext: ctx),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Tunai sheet and confirm cash input preserves '.50'
      await tester.tap(find.text('Tunai'));
      await tester.pumpAndSettle();
      expect(find.text('150000.50'), findsOneWidget);

      // Dismiss Tunai sheet
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      // 2. Open QRIS sheet, check warning text & enter external reference
      await tester.tap(find.text('QRIS'));
      await tester.pumpAndSettle();

      expect(
        find.text('Pastikan dana telah masuk ke mutasi/notifikasi merchant sebelum konfirmasi.'),
        findsOneWidget,
      );

      final refField = find.byKey(const Key('external_reference_input'));
      expect(refField, findsOneWidget);
      await tester.enterText(refField, 'APR-2026-XYZ');
      await tester.pumpAndSettle();

      final processBtn = find.byKey(const Key('qris_sheet_process_button'));
      await tester.ensureVisible(processBtn);
      await tester.pumpAndSettle();
      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      expect(spyRepo.capturedMethodCode, 'QRIS');
      expect(spyRepo.capturedExternalReference, 'APR-2026-XYZ');
      expect(spyRepo.capturedAmountToPay, 150000.50);
    });
  });
}

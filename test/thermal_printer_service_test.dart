import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/services/printer_bluetooth_driver.dart';
import 'package:rentcore_mobile/core/services/thermal_printer_service.dart';

void main() {
  group('PlatformBluetoothDriver payload encoding', () {
    test('converts Uint8List to a plain List<int> the plugin can cast to List<Int>', () {
      final source = Uint8List.fromList([0x1B, 0x40, 0x41, 0xFF]);
      final payload = PlatformBluetoothDriver.toPluginPayload(source);

      expect(payload, isNot(isA<Uint8List>()));
      expect(payload, equals([0x1B, 0x40, 0x41, 0xFF]));

      // StandardMessageCodec encodes Uint8List as byte[] (type 8) and a
      // plain List as a generic list (type 12). The plugin needs the latter.
      const codec = StandardMessageCodec();
      final encoded = codec.encodeMessage(payload)!;
      expect(encoded.getUint8(0), equals(12));
      final encodedRaw = codec.encodeMessage(source)!;
      expect(encodedRaw.getUint8(0), equals(8));
    });
  });

  group('ThermalPrinterModels Serialization & Defaults Tests', () {
    test('ReceiptCustomizationSettings initializes with default values', () {
      const settings = ReceiptCustomizationSettings();
      expect(settings.paperWidth, equals(ReceiptPaperWidth.mm58));
      expect(settings.printMode, equals(PrintMode.normal));
      expect(settings.headerAlignment, equals(ReceiptHeaderAlignment.center));
      expect(settings.showCashierName, isTrue);
      expect(settings.showCustomerPhone, isTrue);
      expect(settings.maskCustomerPhone, isTrue);
      expect(settings.showQrBarcode, isTrue);
      expect(settings.separatorStyle, equals('dash'));
    });

    test('ReceiptCustomizationSettings serializes to and from JSON accurately', () {
      final original = const ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm80,
        printMode: PrintMode.echo,
        customShopName: 'SKYRENTAL BALI',
        customBranchName: 'Cabang Kuta',
        storeAddress: 'Jl. Sunset Road 88',
        storePhone: '081299998888',
        headerAlignment: ReceiptHeaderAlignment.left,
        showCashierName: false,
        showCustomerPhone: true,
        maskCustomerPhone: false,
        showCollateralInfo: true,
        showReturnTerms: true,
        showQrBarcode: false,
        showChangeDue: true,
        showPenaltyDetails: true,
        customFooterMessage: 'Terima kasih telah menyewa!',
        returnTermsText: 'Denda 50rb per jam.',
        compactSpacing: true,
        separatorStyle: 'double',
      );

      final jsonMap = original.toJson();
      final restored = ReceiptCustomizationSettings.fromJson(jsonMap);

      expect(restored.paperWidth, equals(ReceiptPaperWidth.mm80));
      expect(restored.printMode, equals(PrintMode.echo));
      expect(restored.customShopName, equals('SKYRENTAL BALI'));
      expect(restored.customBranchName, equals('Cabang Kuta'));
      expect(restored.storeAddress, equals('Jl. Sunset Road 88'));
      expect(restored.storePhone, equals('081299998888'));
      expect(restored.headerAlignment, equals(ReceiptHeaderAlignment.left));
      expect(restored.showCashierName, isFalse);
      expect(restored.showCustomerPhone, isTrue);
      expect(restored.maskCustomerPhone, isFalse);
      expect(restored.showQrBarcode, isFalse);
      expect(restored.separatorStyle, equals('double'));
    });

    test('ThermalPrinterDevice serializes and deserializes', () {
      const device = ThermalPrinterDevice(
        name: 'Panda PRJ-58D',
        address: '11:22:33:44:55:66',
        isConnected: true,
        rssi: -65,
        isBonded: true,
        deviceType: 'classic',
      );

      final json = device.toJson();
      final restored = ThermalPrinterDevice.fromJson(json);

      expect(restored.name, equals('Panda PRJ-58D'));
      expect(restored.address, equals('11:22:33:44:55:66'));
      expect(restored.isConnected, isTrue);
      expect(restored.rssi, equals(-65));
      expect(restored.isBonded, isTrue);
    });
  });

  group('ThermalPrinterService Layout Engine Tests', () {
    late ThermalPrinterService service;

    setUp(() {
      service = ThermalPrinterService();
      service.setDriver(MockPrinterDriver());
    });

    test('generates valid ESC/POS rental booking slip bytes (58mm)', () {
      const settings = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
        customShopName: 'RENTCORE ELECTRONICS',
        customBranchName: 'Cabang Mataram',
      );

      const model = ReceiptDataModel(
        type: ReceiptType.rentalBooking,
        title: 'STRUK SEWA PERANGKAT',
        branchName: 'Cabang Mataram',
        bookingCode: 'RC-202610-0099',
        customerName: 'Ahmad Dahlan',
        customerPhone: '081234567890',
        cashierName: 'Budi Kasir',
        unitName: 'iPhone 15 Pro Max 256GB',
        unitSerial: 'IMEI358999001122',
        rentalDurationText: '24 Jam',
        rentalEndDate: '18 Okt 2026, 15:00',
        collateralInfo: 'KTP Fisik - Slot A1',
        subtotal: 350000,
        discount: 50000,
        totalAmount: 300000,
        paymentMethod: 'Tunai',
        cashReceived: 350000,
        cashChange: 50000,
        transactedAt: '2026-10-17 14:00',
      );

      final bytes = service.buildRentalBookingSlipBytes(model, settings);
      expect(bytes, isNotEmpty);
      // ESC @ (init)
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));
      // GS V 1 (cut)
      expect(bytes[bytes.length - 3], equals(0x1D));
      expect(bytes[bytes.length - 2], equals(0x56));
      expect(bytes[bytes.length - 1], equals(0x01));

      // Contains masked phone
      final rawString = utf8.decode(bytes, allowMalformed: true);
      expect(rawString, contains('0812****7890'));
      expect(rawString, contains('RC-202610-0099'));
      expect(rawString, contains('iPhone 15 Pro Max'));
    });

    test('generates valid ESC/POS POS payment slip bytes (80mm)', () {
      const settings = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm80,
        customShopName: 'RENTCORE BALI',
        customBranchName: 'Cabang Kuta',
        separatorStyle: 'double',
      );

      const model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: 'Cabang Kuta',
        receiptNumber: 'INV-202610-7711',
        bookingCode: 'RC-202610-0088',
        customerName: 'Siti Rahma',
        cashierName: 'Dewi',
        totalAmount: 450000,
        paymentMethod: 'QRIS BCA',
        transactedAt: '2026-10-17 14:30',
      );

      final bytes = service.buildPosPaymentSlipBytes(model, settings);
      expect(bytes, isNotEmpty);
      expect(bytes[0], equals(0x1B));
      expect(bytes[1], equals(0x40));

      final rawString = utf8.decode(bytes, allowMalformed: true);
      expect(rawString, contains('INV-202610-7711'));
      expect(rawString, contains('QRIS BCA'));
      expect(rawString, contains('LUNAS'));
    });

    test('generates valid ESC/POS rental return slip bytes', () {
      const settings = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
      );

      const model = ReceiptDataModel(
        type: ReceiptType.rentalReturn,
        title: 'BUKTI PENGEMBALIAN UNIT',
        branchName: 'Cabang Pusat',
        bookingCode: 'RC-202610-0033',
        customerName: 'Bambang',
        cashierName: 'Rudi',
        unitName: 'Sony A7IV Mirrorless',
        conditionGrade: 'Grade A (Mulus)',
        checklistNotes: 'Sensor & Layar Bersih',
        accessoriesNotes: 'Lengkap (Baterai & Charger)',
        penaltyAmount: 75000,
        paymentMethod: 'Tunai',
        totalAmount: 75000,
        transactedAt: '2026-10-17 16:00',
      );

      final bytes = service.buildRentalReturnSlipBytes(model, settings);
      expect(bytes, isNotEmpty);

      final rawString = utf8.decode(bytes, allowMalformed: true);
      expect(rawString, contains('Grade A (Mulus)'));
      expect(rawString, contains('KTP DIKEMBALIKAN'));
      expect(rawString, contains('75.000'));
    });

    test('generates valid diagnostic test receipt bytes', () {
      const settings = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
        printMode: PrintMode.normal,
      );

      final bytes = service.buildTestSlipBytes(settings);
      expect(bytes, isNotEmpty);

      final rawString = utf8.decode(bytes, allowMalformed: true);
      expect(rawString, contains('RENTCORE TEST PRINT'));
      expect(rawString, contains('Thermal Printer Diagnostic'));
      expect(rawString, contains('RENTCORE-TEST-OK'));
    });

    test('verifies Normal and Echo print modes execution', () async {
      service.setConnectedDevice(const ThermalPrinterDevice(
        name: 'Test Thermal Printer',
        address: '00:11:22:33:44:55',
        isConnected: true,
      ));

      final testBytes = service.buildTestSlipBytes(const ReceiptCustomizationSettings());

      // 1. Normal mode
      final normalResult = await service.sendPrintJob(testBytes, PrintMode.normal);
      expect(normalResult, isTrue);

      // 2. Echo mode (physical transmission with compact log)
      final echoResult = await service.sendPrintJob(testBytes, PrintMode.echo);
      expect(echoResult, isTrue);
      expect(service.lastEchoLog, contains('ECHO OK'));

      // 3. Disconnected printer in Normal mode should fail
      service.setConnectedDevice(null);
      final disconnectedResult = await service.sendPrintJob(testBytes, PrintMode.normal);
      expect(disconnectedResult, isFalse);
      expect(service.lastError, equals('Belum ada printer yang dipilih.'));

      // 4. Disconnected printer in Echo mode should also fail (physical transmission required)
      final echoWithoutPrinter = await service.sendPrintJob(testBytes, PrintMode.echo);
      expect(echoWithoutPrinter, isFalse);
      expect(service.lastError, equals('Belum ada printer yang dipilih.'));
    });

    test('auto-reconnects when socket dropped and sets error if connection fails', () async {
      service.setConnectedDevice(const ThermalPrinterDevice(
        name: 'Sleeping Printer',
        address: '99:88:77:66:55:44',
        isConnected: true,
      ));

      // 1. Connection failure during auto-reconnect
      service.setDriver(_FailingConnectMockDriver());
      final testBytes = service.buildTestSlipBytes(const ReceiptCustomizationSettings());
      final failedResult = await service.sendPrintJob(testBytes, PrintMode.normal);
      expect(failedResult, isFalse);
      expect(service.lastError, contains('Gagal terhubung ke Sleeping Printer'));

      // 2. Write failure when connected
      service.setDriver(_FailingWriteMockDriver());
      final writeFailedResult = await service.sendPrintJob(testBytes, PrintMode.normal);
      expect(writeFailedResult, isFalse);
      expect(service.lastError, contains('Gagal mengirim data cetak ke printer'));
    });

    test('buildReceiptDocument generates standard and compact echo documents retaining essential fields', () {
      const settings = ReceiptCustomizationSettings(
        paperWidth: ReceiptPaperWidth.mm58,
        customShopName: 'RENTCORE BALI',
        customBranchName: 'Cabang Kuta',
        storePhone: '081234567890',
        storeAddress: 'Jl. Legian No. 1',
      );
      final sample = service.getSampleBookingReceipt(settings);

      // 1. Standard mode document
      final stdDoc = service.buildReceiptDocument(sample, settings, PrintMode.normal);
      expect(stdDoc.lines.any((l) => l.isDoubleSize), isTrue); // Shop name double size
      expect(stdDoc.lines.any((l) => l.text == 'DETAIL PERANGKAT:'), isTrue);
      expect(stdDoc.lines.any((l) => l.leftText == 'TOTAL AKHIR'), isTrue);

      // 2. Echo mode document (compact, clean thermal layout)
      final echoDoc = service.buildReceiptDocument(sample, settings, PrintMode.echo);
      expect(echoDoc.lines.any((l) => l.isDoubleSize), isFalse); // Compact single-size header
      expect(echoDoc.lines.any((l) => l.text == 'DETAIL PERANGKAT:'), isFalse); // Streamlined
      // Essential transaction & financial data MUST be preserved
      expect(echoDoc.lines.any((l) => l.text == 'STRUK SEWA PERANGKAT'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'No. Booking'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'Pelanggan'), isTrue);
      expect(echoDoc.lines.any((l) => l.text == 'iPhone 15 Pro Max 256GB Natural'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'Biaya Sewa'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'TOTAL AKHIR'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'Uang Diterima'), isTrue);
      expect(echoDoc.lines.any((l) => l.leftText == 'Kembalian'), isTrue);

      // 3. Bytes generation for both
      final stdBytes = service.buildSlipBytesFromDocument(stdDoc, settings);
      final echoBytes = service.buildSlipBytesFromDocument(echoDoc, settings);
      expect(stdBytes, isNotEmpty);
      expect(echoBytes, isNotEmpty);
    });
  });
}

class _FailingConnectMockDriver extends MockPrinterDriver {
  @override
  Future<bool> isConnected() async => false;

  @override
  Future<bool> connect(String address) async => false;
}

class _FailingWriteMockDriver extends MockPrinterDriver {
  @override
  Future<bool> isConnected() async => true;

  @override
  Future<bool> writeBytes(Uint8List bytes) async => false;
}

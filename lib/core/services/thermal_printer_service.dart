import 'dart:convert';
import 'dart:typed_data';

class ThermalPrinterDevice {
  final String name;
  final String address;
  final bool isConnected;

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    this.isConnected = false,
  });
}

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  ThermalPrinterDevice? _connectedDevice = const ThermalPrinterDevice(
    name: 'RPP-02N Bluetooth Printer (58mm)',
    address: '00:11:22:33:44:55',
    isConnected: true,
  );

  ThermalPrinterDevice? get connectedDevice => _connectedDevice;

  void setConnectedDevice(ThermalPrinterDevice? device) {
    _connectedDevice = device;
  }

  // --- ESC/POS Command Constants ---
  static const List<int> cmdInit = [0x1B, 0x40]; // ESC @
  static const List<int> cmdAlignLeft = [0x1B, 0x61, 0x00]; // ESC a 0
  static const List<int> cmdAlignCenter = [0x1B, 0x61, 0x01]; // ESC a 1
  static const List<int> cmdAlignRight = [0x1B, 0x61, 0x02]; // ESC a 2
  static const List<int> cmdBoldOn = [0x1B, 0x45, 0x01]; // ESC E 1
  static const List<int> cmdBoldOff = [0x1B, 0x45, 0x00]; // ESC E 0
  static const List<int> cmdDoubleSize = [0x1D, 0x21, 0x11]; // GS ! 0x11
  static const List<int> cmdNormalSize = [0x1D, 0x21, 0x00]; // GS ! 0x00
  static const List<int> cmdFeed3Lines = [0x1B, 0x64, 0x03]; // ESC d 3
  static const List<int> cmdCutPaper = [0x1D, 0x56, 0x01]; // GS V 1 (Partial Cut)

  /// Generate raw ESC/POS binary stream for Voucher Thermal Slip with 2D Barcode.
  Uint8List buildVoucherSlipBytes({
    required String shopName,
    required String branchName,
    required String voucherCode,
    required double discountPercentage,
    required double minTransaction,
    required String validUntil,
  }) {
    final builder = BytesBuilder();

    // 1. Initialize
    builder.add(cmdInit);

    // 2. Center Header
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('$shopName\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$branchName\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    // 3. Voucher Title & Discount
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('VOUCHER DISKON SPESIAL\n'));
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('${discountPercentage.toInt()}% OFF\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('--------------------------------\n'));

    // 4. Details (Left Aligned)
    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('Kode Voucher  : $voucherCode\n'));
    builder.add(utf8.encode('Min. Transaksi: Rp ${_formatNumber(minTransaction)}\n'));
    builder.add(utf8.encode('Berlaku s/d   : $validUntil\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    // 5. 2D Barcode (QR Code ESC/POS commands GS ( k)
    builder.add(cmdAlignCenter);
    builder.add(_buildQrCodeEscPos(voucherCode));
    builder.add(utf8.encode('\n$voucherCode\n\n'));

    // 6. Footer Notes
    builder.add(utf8.encode('* Tunjukkan slip fisik ini atau\n'));
    builder.add(utf8.encode('  scan QR Code saat sewa gadget.\n'));
    builder.add(utf8.encode('Terima kasih atas kunjungan Anda!\n'));
    builder.add(utf8.encode('================================\n'));

    // 7. Feed & Cut
    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);

    return builder.toBytes();
  }

  /// Generate raw ESC/POS binary stream for Cashier Closing Shift Slip.
  Uint8List buildClosingShiftSlipBytes({
    required String branchName,
    required String cashierName,
    required String date,
    required int totalTransactions,
    required double totalRevenue,
    required Map<String, double> paymentBreakdown,
  }) {
    final builder = BytesBuilder();

    // 1. Initialize & Header
    builder.add(cmdInit);
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('RENTCORE CLOSING SHIFT\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$branchName\n'));
    builder.add(utf8.encode('================================\n'));

    // 2. Shift Info
    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('Tanggal : $date\n'));
    builder.add(utf8.encode('Kasir   : $cashierName\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    // 3. Transactions & Total Revenue
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('Total Transaksi : $totalTransactions\n'));
    builder.add(utf8.encode('Total Omset     : Rp ${_formatNumber(totalRevenue)}\n'));
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('--------------------------------\n'));

    // 4. Breakdown by Payment Method
    builder.add(utf8.encode('RINCIAN METODE PEMBAYARAN:\n'));
    paymentBreakdown.forEach((method, amount) {
      final line = _formatTwoColumn(method, 'Rp ${_formatNumber(amount)}', 32);
      builder.add(utf8.encode('$line\n'));
    });
    builder.add(utf8.encode('================================\n'));

    // 5. Signatures
    builder.add(cmdAlignCenter);
    builder.add(utf8.encode('Tanda Tangan Kasir / Supervisor\n\n\n'));
    builder.add(utf8.encode('( ____________________ )\n'));

    // 6. Feed & Cut
    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);

    return builder.toBytes();
  }

  /// ESC/POS Standard QR Code generation sequence:
  /// Model, Size, Error Correction, Store Data, Print QR.
  List<int> _buildQrCodeEscPos(String data) {
    final bytes = <int>[];
    final dataBytes = utf8.encode(data);
    final dataLen = dataBytes.length + 3;
    final pL = dataLen % 256;
    final pH = dataLen ~/ 256;

    // 1. Select QR Model 2: GS ( k 4 0 49 65 50 0
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);

    // 2. Set Module Size 6: GS ( k 3 0 49 67 6
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);

    // 3. Set Error Correction Level M (49): GS ( k 3 0 49 69 49
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);

    // 4. Store Data in Symbol Storage Area: GS ( k pL pH 49 80 48 <data>
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(dataBytes);

    // 5. Print Symbol Data: GS ( k 3 0 49 81 48
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  String _formatNumber(num number) {
    final s = number.toInt().toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = s.length - 1; i >= 0; i--) {
      buffer.write(s[i]);
      count++;
      if (count % 3 == 0 && i > 0) {
        buffer.write('.');
      }
    }
    return buffer.toString().split('').reversed.join('');
  }

  String _formatTwoColumn(String left, String right, int totalWidth) {
    final available = totalWidth - left.length - right.length;
    if (available <= 0) return '$left $right';
    return left + (' ' * available) + right;
  }

  /// Simulated Bluetooth print transmission with error handling.
  Future<bool> sendPrintJob(Uint8List payload) async {
    // Simulate Bluetooth RFCOMM socket write delay
    await Future.delayed(const Duration(milliseconds: 600));
    return _connectedDevice != null && _connectedDevice!.isConnected;
  }
}

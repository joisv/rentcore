import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../models/thermal_printer_models.dart';
import 'printer_bluetooth_driver.dart';

export '../models/thermal_printer_models.dart';

class ThermalPrinterService {
  static final ThermalPrinterService _instance = ThermalPrinterService._internal();
  factory ThermalPrinterService() => _instance;
  ThermalPrinterService._internal();

  PrinterBluetoothDriver _driver = PlatformBluetoothDriver();

  /// Set the active Bluetooth driver (useful for tests or mocking).
  void setDriver(PrinterBluetoothDriver driver) {
    _driver = driver;
  }

  PrinterBluetoothDriver get driver => _driver;

  ThermalPrinterDevice? _connectedDevice;
  String? _lastError;
  String? _lastEchoLog;

  ThermalPrinterDevice? get connectedDevice => _connectedDevice;
  String? get lastError => _lastError;
  String? get lastEchoLog => _lastEchoLog;

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
  static const List<int> cmdFeed1Line = [0x1B, 0x64, 0x01]; // ESC d 1
  static const List<int> cmdCutPaper = [0x1D, 0x56, 0x01]; // GS V 1 (Partial Cut)

  // ==========================================
  // 1. Voucher Slip (Backward Compatible)
  // ==========================================
  Uint8List buildVoucherSlipBytes({
    required String shopName,
    required String branchName,
    required String voucherCode,
    required double discountPercentage,
    required double minTransaction,
    required String validUntil,
  }) {
    final builder = BytesBuilder();
    builder.add(cmdInit);
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('$shopName\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$branchName\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    builder.add(cmdBoldOn);
    builder.add(utf8.encode('VOUCHER DISKON SPESIAL\n'));
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('${discountPercentage.toInt()}% OFF\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('--------------------------------\n'));

    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('Kode Voucher  : $voucherCode\n'));
    builder.add(utf8.encode('Min. Transaksi: Rp ${_formatNumber(minTransaction)}\n'));
    builder.add(utf8.encode('Berlaku s/d   : $validUntil\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    builder.add(cmdAlignCenter);
    builder.add(_buildQrCodeEscPos(voucherCode));
    builder.add(utf8.encode('\n$voucherCode\n\n'));

    builder.add(utf8.encode('* Tunjukkan slip fisik ini atau\n'));
    builder.add(utf8.encode('  scan QR Code saat sewa gadget.\n'));
    builder.add(utf8.encode('Terima kasih atas kunjungan Anda!\n'));
    builder.add(utf8.encode('================================\n'));

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);

    return builder.toBytes();
  }

  // ==========================================
  // 2. Closing Shift Slip (Backward Compatible)
  // ==========================================
  Uint8List buildClosingShiftSlipBytes({
    required String branchName,
    required String cashierName,
    required String date,
    required int totalTransactions,
    required double totalRevenue,
    required Map<String, double> paymentBreakdown,
  }) {
    final builder = BytesBuilder();
    builder.add(cmdInit);
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('RENTCORE CLOSING SHIFT\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$branchName\n'));
    builder.add(utf8.encode('================================\n'));

    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('Tanggal : $date\n'));
    builder.add(utf8.encode('Kasir   : $cashierName\n'));
    builder.add(utf8.encode('--------------------------------\n'));

    builder.add(cmdBoldOn);
    builder.add(utf8.encode('Total Transaksi : $totalTransactions\n'));
    builder.add(utf8.encode('Total Omset     : Rp ${_formatNumber(totalRevenue)}\n'));
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('--------------------------------\n'));

    builder.add(utf8.encode('RINCIAN METODE PEMBAYARAN:\n'));
    paymentBreakdown.forEach((method, amount) {
      final line = _formatTwoColumn(method, 'Rp ${_formatNumber(amount)}', 32);
      builder.add(utf8.encode('$line\n'));
    });
    builder.add(utf8.encode('================================\n'));

    builder.add(cmdAlignCenter);
    builder.add(utf8.encode('Tanda Tangan Kasir / Supervisor\n\n\n'));
    builder.add(utf8.encode('( ____________________ )\n'));

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);

    return builder.toBytes();
  }

  // =========================================================================
  // Unified Document Engine (Single Source of Truth for Preview & Bytes)
  // =========================================================================

  /// Sample transaction data matching current store settings for designer preview.
  ReceiptDataModel getSampleBookingReceipt(ReceiptCustomizationSettings settings) {
    return ReceiptDataModel(
      type: ReceiptType.rentalBooking,
      title: 'STRUK SEWA PERANGKAT',
      branchName: settings.customBranchName.isNotEmpty ? settings.customBranchName : 'Cabang Mataram',
      shopName: settings.customShopName.isNotEmpty ? settings.customShopName : 'RENTCORE GADGETS',
      bookingCode: 'RC-202610-0042',
      customerName: 'Dewi Lestari',
      customerPhone: '081234568890',
      cashierName: 'Budi Santoso',
      unitName: 'iPhone 15 Pro Max 256GB Natural',
      unitSerial: 'IMEI358999001122',
      rentalDurationText: '24 Jam',
      rentalEndDate: '18 Okt 2026, 14:00',
      collateralInfo: 'KTP Fisik - Slot B2',
      subtotal: 350000,
      discount: 50000,
      totalAmount: 300000,
      paymentMethod: 'Tunai',
      cashReceived: 400000,
      cashChange: 100000,
      transactedAt: '17 Okt 2026, 14:00',
      qrData: 'RC-202610-0042',
    );
  }

  /// Builds a structured [ReceiptPrintDocument] that acts as the single source
  /// of truth for both on-screen previews (Standard/Echo) and ESC/POS byte rendering.
  ReceiptPrintDocument buildReceiptDocument(
    ReceiptDataModel data,
    ReceiptCustomizationSettings settings, [
    PrintMode? mode,
  ]) {
    final effectiveMode = mode ?? settings.printMode;
    final isEcho = effectiveMode == PrintMode.echo;
    final width = settings.paperWidth.columns;
    final dividerChar = isEcho ? '-' : (settings.separatorStyle == 'double' ? '=' : '-');
    final divider = dividerChar * width;
    final lines = <ReceiptLineItem>[];

    // 1. Header Section
    final shopName = settings.customShopName.isNotEmpty
        ? settings.customShopName
        : (data.shopName ?? 'RENTCORE GADGETS');
    final branchName = settings.customBranchName.isNotEmpty
        ? settings.customBranchName
        : data.branchName;

    if (isEcho) {
      // Echo Mode: Clean, compact store identity
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.header,
        text: shopName,
        alignment: settings.headerAlignment,
        isBold: true,
        isDoubleSize: false,
      ));
      String subInfo = branchName;
      if (settings.storePhone.isNotEmpty) {
        subInfo = '$subInfo • ${settings.storePhone}';
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.text,
        text: subInfo,
        alignment: settings.headerAlignment,
      ));
      if (settings.storeAddress.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: settings.storeAddress,
          alignment: settings.headerAlignment,
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    } else {
      // Standard Mode: Full prominent header
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.header,
        text: shopName,
        alignment: settings.headerAlignment,
        isBold: true,
        isDoubleSize: true,
      ));
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.header,
        text: branchName,
        alignment: settings.headerAlignment,
      ));
      if (settings.storeAddress.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.header,
          text: settings.storeAddress,
          alignment: settings.headerAlignment,
        ));
      }
      if (settings.storePhone.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.header,
          text: 'Telp: ${settings.storePhone}',
          alignment: settings.headerAlignment,
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }

    // 2. Receipt Title
    lines.add(ReceiptLineItem(
      type: ReceiptLineType.text,
      text: data.title,
      alignment: ReceiptHeaderAlignment.center,
      isBold: true,
    ));
    lines.add(ReceiptLineItem(
      type: ReceiptLineType.divider,
      text: divider,
      alignment: ReceiptHeaderAlignment.center,
    ));

    // 3. Transaction Meta
    if (data.receiptNumber != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'No. Struk',
        rightText: data.receiptNumber!,
        text: _formatTwoColumn('No. Struk', data.receiptNumber!, width),
      ));
    }
    if (data.bookingCode != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'No. Booking',
        rightText: data.bookingCode!,
        text: _formatTwoColumn('No. Booking', data.bookingCode!, width),
      ));
    }
    if (data.transactedAt != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Waktu',
        rightText: data.transactedAt!,
        text: _formatTwoColumn('Waktu', data.transactedAt!, width),
      ));
    }
    if (settings.showCashierName && data.cashierName != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Kasir',
        rightText: data.cashierName!,
        text: _formatTwoColumn('Kasir', data.cashierName!, width),
      ));
    }
    if (data.customerName != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Pelanggan',
        rightText: data.customerName!,
        text: _formatTwoColumn('Pelanggan', data.customerName!, width),
      ));
    }
    if (settings.showCustomerPhone && data.customerPhone != null && data.customerPhone!.isNotEmpty) {
      final phone = settings.maskCustomerPhone ? _maskPhone(data.customerPhone!) : data.customerPhone!;
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'No. Telp',
        rightText: phone,
        text: _formatTwoColumn('No. Telp', phone, width),
      ));
    }
    lines.add(ReceiptLineItem(
      type: ReceiptLineType.divider,
      text: divider,
      alignment: ReceiptHeaderAlignment.center,
    ));

    // 4. Line Items / Unit Details
    if (data.items != null && data.items!.isNotEmpty) {
      for (final item in data.items!) {
        final name = item['name']?.toString() ?? 'Item';
        final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: name,
          rightText: 'Rp ${_formatNumber(price)}',
          text: _formatTwoColumn(name, 'Rp ${_formatNumber(price)}', width),
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }

    if (data.unitName != null) {
      if (!isEcho) {
        lines.add(const ReceiptLineItem(
          type: ReceiptLineType.text,
          text: 'DETAIL PERANGKAT:',
          isBold: true,
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.text,
        text: data.unitName!,
        isBold: isEcho,
      ));
      if (data.unitSerial != null && data.unitSerial!.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: 'SN/IMEI: ${data.unitSerial}',
        ));
      }
      if (data.rentalDurationText != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: 'Durasi',
          rightText: data.rentalDurationText!,
          text: _formatTwoColumn('Durasi', data.rentalDurationText!, width),
        ));
      }
      if (data.rentalEndDate != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: 'Batas Sewa',
          rightText: data.rentalEndDate!,
          text: _formatTwoColumn('Batas Sewa', data.rentalEndDate!, width),
        ));
      }
      if (settings.showCollateralInfo && data.collateralInfo != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: 'Jaminan',
          rightText: data.collateralInfo!,
          text: _formatTwoColumn('Jaminan', data.collateralInfo!, width),
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }

    // 5. Financial Summary
    if (data.subtotal != null && data.subtotal! > 0) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Biaya Sewa',
        rightText: 'Rp ${_formatNumber(data.subtotal!)}',
        text: _formatTwoColumn('Biaya Sewa', 'Rp ${_formatNumber(data.subtotal!)}', width),
      ));
    }
    if (data.discount != null && data.discount! > 0) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Diskon Promo',
        rightText: '-Rp ${_formatNumber(data.discount!)}',
        text: _formatTwoColumn('Diskon Promo', '-Rp ${_formatNumber(data.discount!)}', width),
      ));
    }
    if (data.penaltyAmount != null && data.penaltyAmount! > 0 && settings.showPenaltyDetails) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Denda Telat',
        rightText: 'Rp ${_formatNumber(data.penaltyAmount!)}',
        text: _formatTwoColumn('Denda Telat', 'Rp ${_formatNumber(data.penaltyAmount!)}', width),
      ));
    }

    lines.add(ReceiptLineItem(
      type: ReceiptLineType.keyValue,
      leftText: 'TOTAL AKHIR',
      rightText: 'Rp ${_formatNumber(data.totalAmount)}',
      text: _formatTwoColumn('TOTAL AKHIR', 'Rp ${_formatNumber(data.totalAmount)}', width),
      isBold: true,
    ));

    if (data.paymentMethod != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Pembayaran',
        rightText: data.paymentMethod!,
        text: _formatTwoColumn('Pembayaran', data.paymentMethod!, width),
      ));
    }
    if (settings.showChangeDue && data.cashReceived != null && data.cashReceived! > 0) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Uang Diterima',
        rightText: 'Rp ${_formatNumber(data.cashReceived!)}',
        text: _formatTwoColumn('Uang Diterima', 'Rp ${_formatNumber(data.cashReceived!)}', width),
      ));
      if (data.cashChange != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: 'Kembalian',
          rightText: 'Rp ${_formatNumber(data.cashChange!)}',
          text: _formatTwoColumn('Kembalian', 'Rp ${_formatNumber(data.cashChange!)}', width),
        ));
      }
    }
    lines.add(ReceiptLineItem(
      type: ReceiptLineType.divider,
      text: divider,
      alignment: ReceiptHeaderAlignment.center,
    ));

    // 6. QR Code Section
    if (settings.showQrBarcode && (data.qrData != null || data.bookingCode != null)) {
      final qrString = data.qrData ?? data.bookingCode!;
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.qrCode,
        text: qrString,
        qrData: qrString,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }

    // 7. Footer & Return Terms
    if (settings.showReturnTerms && settings.returnTermsText.isNotEmpty) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.text,
        text: settings.returnTermsText,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }
    if (settings.customFooterMessage.isNotEmpty) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.text,
        text: settings.customFooterMessage,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }
    lines.add(ReceiptLineItem(
      type: ReceiptLineType.divider,
      text: divider,
      alignment: ReceiptHeaderAlignment.center,
    ));

    return ReceiptPrintDocument(
      lines: lines,
      paperWidth: settings.paperWidth,
      charColumns: width,
      receiptType: data.type,
      sampleTitle: data.title,
    );
  }

  /// Builds ESC/POS byte array from a structured [ReceiptPrintDocument].
  Uint8List buildSlipBytesFromDocument(
    ReceiptPrintDocument doc,
    ReceiptCustomizationSettings settings,
  ) {
    final builder = BytesBuilder();
    builder.add(cmdInit);

    for (final line in doc.lines) {
      switch (line.type) {
        case ReceiptLineType.header:
        case ReceiptLineType.text:
        case ReceiptLineType.keyValue:
        case ReceiptLineType.divider:
          if (line.alignment == ReceiptHeaderAlignment.center) {
            builder.add(cmdAlignCenter);
          } else {
            builder.add(cmdAlignLeft);
          }
          if (line.isDoubleSize) builder.add(cmdDoubleSize);
          if (line.isBold) builder.add(cmdBoldOn);
          builder.add(utf8.encode('${line.text}\n'));
          if (line.isBold) builder.add(cmdBoldOff);
          if (line.isDoubleSize) builder.add(cmdNormalSize);
          break;
        case ReceiptLineType.qrCode:
          builder.add(cmdAlignCenter);
          if (settings.paperWidth == ReceiptPaperWidth.mm80 && line.qrData != null) {
            builder.add(_buildQrCodeEscPos(line.qrData!));
          }
          builder.add(utf8.encode('${line.text}\n\n'));
          break;
        case ReceiptLineType.emptyFeed:
          builder.add(utf8.encode('\n'));
          break;
      }
    }

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  /// Sends a structured [ReceiptPrintDocument] to printer or echo simulation.
  Future<bool> printDocument(
    ReceiptPrintDocument doc,
    ReceiptCustomizationSettings settings,
  ) async {
    final bytes = buildSlipBytesFromDocument(doc, settings);
    return sendPrintJob(bytes, settings.printMode);
  }

  // =========================================================================
  // 3. Rental Booking Handover Slip (Customizable, 58mm/80mm, Normal/Echo)
  // =========================================================================
  Uint8List buildRentalBookingSlipBytes(
    ReceiptDataModel data,
    ReceiptCustomizationSettings settings,
  ) {
    final builder = BytesBuilder();
    final width = settings.paperWidth.columns;
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    final divider = dividerChar * width;

    builder.add(cmdInit);

    // Header
    _appendHeader(builder, data, settings);
    builder.add(utf8.encode('$divider\n'));

    // Title
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$divider\n'));

    // Transaction Details
    builder.add(cmdAlignLeft);
    if (data.bookingCode != null) {
      builder.add(utf8.encode(_formatTwoColumn('No. Booking', data.bookingCode!, width) + '\n'));
    }
    if (data.transactedAt != null) {
      builder.add(utf8.encode(_formatTwoColumn('Waktu', data.transactedAt!, width) + '\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Kasir', data.cashierName!, width) + '\n'));
    }
    if (data.customerName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Pelanggan', data.customerName!, width) + '\n'));
    }
    if (settings.showCustomerPhone && data.customerPhone != null && data.customerPhone!.isNotEmpty) {
      final phone = settings.maskCustomerPhone ? _maskPhone(data.customerPhone!) : data.customerPhone!;
      builder.add(utf8.encode(_formatTwoColumn('No. Telp', phone, width) + '\n'));
    }
    builder.add(utf8.encode('$divider\n'));

    // Unit Details
    if (data.unitName != null) {
      builder.add(cmdBoldOn);
      builder.add(utf8.encode('DETAIL PERANGKAT:\n'));
      builder.add(cmdBoldOff);
      builder.add(utf8.encode('${data.unitName}\n'));
      if (data.unitSerial != null && data.unitSerial!.isNotEmpty) {
        builder.add(utf8.encode('SN/IMEI: ${data.unitSerial}\n'));
      }
      if (data.rentalDurationText != null) {
        builder.add(utf8.encode(_formatTwoColumn('Durasi', data.rentalDurationText!, width) + '\n'));
      }
      if (data.rentalEndDate != null) {
        builder.add(utf8.encode(_formatTwoColumn('Batas Sewa', data.rentalEndDate!, width) + '\n'));
      }
      if (settings.showCollateralInfo && data.collateralInfo != null) {
        builder.add(utf8.encode(_formatTwoColumn('Jaminan', data.collateralInfo!, width) + '\n'));
      }
      builder.add(utf8.encode('$divider\n'));
    }

    // Financial breakdown
    if (data.subtotal != null && data.subtotal! > 0) {
      builder.add(utf8.encode(_formatTwoColumn('Biaya Sewa', 'Rp ${_formatNumber(data.subtotal!)}', width) + '\n'));
    }
    if (data.discount != null && data.discount! > 0) {
      builder.add(utf8.encode(_formatTwoColumn('Diskon Promo', '-Rp ${_formatNumber(data.discount!)}', width) + '\n'));
    }
    builder.add(cmdBoldOn);
    builder.add(utf8.encode(_formatTwoColumn('TOTAL AKHIR', 'Rp ${_formatNumber(data.totalAmount)}', width) + '\n'));
    builder.add(cmdBoldOff);

    if (data.paymentMethod != null) {
      builder.add(utf8.encode(_formatTwoColumn('Pembayaran', data.paymentMethod!, width) + '\n'));
    }
    if (settings.showChangeDue && data.cashReceived != null && data.cashReceived! > 0) {
      builder.add(utf8.encode(_formatTwoColumn('Uang Diterima', 'Rp ${_formatNumber(data.cashReceived!)}', width) + '\n'));
      if (data.cashChange != null) {
        builder.add(utf8.encode(_formatTwoColumn('Kembalian', 'Rp ${_formatNumber(data.cashChange!)}', width) + '\n'));
      }
    }
    builder.add(utf8.encode('$divider\n'));

    // QR Code for Fast Return (Only send GS ( k on 80mm printers, 58mm mobile prints clean text code)
    if (settings.showQrBarcode && (data.qrData != null || data.bookingCode != null)) {
      final qrString = data.qrData ?? data.bookingCode!;
      builder.add(cmdAlignCenter);
      if (settings.paperWidth == ReceiptPaperWidth.mm80) {
        builder.add(_buildQrCodeEscPos(qrString));
      }
      builder.add(utf8.encode('$qrString\n\n'));
    }

    // Footer & Terms
    _appendFooter(builder, settings, width);

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  // =========================================================================
  // 4. POS Payment Receipt Slip (Customizable, 58mm/80mm, Normal/Echo)
  // =========================================================================
  Uint8List buildPosPaymentSlipBytes(
    ReceiptDataModel data,
    ReceiptCustomizationSettings settings,
  ) {
    final builder = BytesBuilder();
    final width = settings.paperWidth.columns;
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    final divider = dividerChar * width;

    builder.add(cmdInit);

    _appendHeader(builder, data, settings);
    builder.add(utf8.encode('$divider\n'));

    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$divider\n'));

    builder.add(cmdAlignLeft);
    if (data.receiptNumber != null) {
      builder.add(utf8.encode(_formatTwoColumn('No. Struk', data.receiptNumber!, width) + '\n'));
    }
    if (data.bookingCode != null) {
      builder.add(utf8.encode(_formatTwoColumn('Ref Booking', data.bookingCode!, width) + '\n'));
    }
    if (data.transactedAt != null) {
      builder.add(utf8.encode(_formatTwoColumn('Waktu', data.transactedAt!, width) + '\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Kasir', data.cashierName!, width) + '\n'));
    }
    if (data.customerName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Pelanggan', data.customerName!, width) + '\n'));
    }
    builder.add(utf8.encode('$divider\n'));

    // Line items or summary
    if (data.items != null && data.items!.isNotEmpty) {
      for (final item in data.items!) {
        final name = item['name']?.toString() ?? 'Item';
        final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
        builder.add(utf8.encode(_formatTwoColumn(name, 'Rp ${_formatNumber(price)}', width) + '\n'));
      }
      builder.add(utf8.encode('$divider\n'));
    }

    if (data.penaltyAmount != null && data.penaltyAmount! > 0 && settings.showPenaltyDetails) {
      builder.add(utf8.encode(_formatTwoColumn('Denda Telat', 'Rp ${_formatNumber(data.penaltyAmount!)}', width) + '\n'));
    }

    builder.add(cmdBoldOn);
    builder.add(utf8.encode(_formatTwoColumn('TOTAL BAYAR', 'Rp ${_formatNumber(data.totalAmount)}', width) + '\n'));
    builder.add(cmdBoldOff);

    if (data.paymentMethod != null) {
      builder.add(utf8.encode(_formatTwoColumn('Metode', data.paymentMethod!, width) + '\n'));
    }
    if (settings.showChangeDue && data.cashReceived != null && data.cashReceived! > 0) {
      builder.add(utf8.encode(_formatTwoColumn('Tunai Diterima', 'Rp ${_formatNumber(data.cashReceived!)}', width) + '\n'));
      if (data.cashChange != null) {
        builder.add(utf8.encode(_formatTwoColumn('Kembalian', 'Rp ${_formatNumber(data.cashChange!)}', width) + '\n'));
      }
    }
    builder.add(utf8.encode(_formatTwoColumn('Status', 'LUNAS', width) + '\n'));
    builder.add(utf8.encode('$divider\n'));

    _appendFooter(builder, settings, width);

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  // =========================================================================
  // 5. Rental Return Slip (Checklist, Grade, Penalty, Collateral returned)
  // =========================================================================
  Uint8List buildRentalReturnSlipBytes(
    ReceiptDataModel data,
    ReceiptCustomizationSettings settings,
  ) {
    final builder = BytesBuilder();
    final width = settings.paperWidth.columns;
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    final divider = dividerChar * width;

    builder.add(cmdInit);

    _appendHeader(builder, data, settings);
    builder.add(utf8.encode('$divider\n'));

    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('$divider\n'));

    builder.add(cmdAlignLeft);
    if (data.bookingCode != null) {
      builder.add(utf8.encode(_formatTwoColumn('Kode Sewa', data.bookingCode!, width) + '\n'));
    }
    if (data.transactedAt != null) {
      builder.add(utf8.encode(_formatTwoColumn('Waktu Kembali', data.transactedAt!, width) + '\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Petugas', data.cashierName!, width) + '\n'));
    }
    if (data.customerName != null) {
      builder.add(utf8.encode(_formatTwoColumn('Pelanggan', data.customerName!, width) + '\n'));
    }
    builder.add(utf8.encode('$divider\n'));

    if (data.unitName != null) {
      builder.add(cmdBoldOn);
      builder.add(utf8.encode('HASIL PEMERIKSAAN UNIT:\n'));
      builder.add(cmdBoldOff);
      builder.add(utf8.encode('${data.unitName}\n'));
      if (data.conditionGrade != null) {
        builder.add(utf8.encode(_formatTwoColumn('Kondisi Fisik', data.conditionGrade!, width) + '\n'));
      }
      if (data.checklistNotes != null) {
        builder.add(utf8.encode('Checklist: ${data.checklistNotes}\n'));
      }
      if (data.accessoriesNotes != null) {
        builder.add(utf8.encode('Aksesoris: ${data.accessoriesNotes}\n'));
      }
      builder.add(utf8.encode(_formatTwoColumn('Status Jaminan', 'KTP DIKEMBALIKAN', width) + '\n'));
      builder.add(utf8.encode('$divider\n'));
    }

    if (data.penaltyAmount != null && data.penaltyAmount! > 0) {
      builder.add(utf8.encode(_formatTwoColumn('Denda Keterlambatan', 'Rp ${_formatNumber(data.penaltyAmount!)}', width) + '\n'));
      if (data.paymentMethod != null) {
        builder.add(utf8.encode(_formatTwoColumn('Status Denda', 'LUNAS (${data.paymentMethod})', width) + '\n'));
      }
      builder.add(utf8.encode('$divider\n'));
    }

    _appendFooter(builder, settings, width);

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  // =========================================================================
  // 6. Test Receipt Slip (Hardware verification, fonts, paper width)
  // =========================================================================
  Uint8List buildTestSlipBytes(ReceiptCustomizationSettings settings) {
    final builder = BytesBuilder();
    final width = settings.paperWidth.columns;
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    final divider = dividerChar * width;

    builder.add(cmdInit);

    // Center header test
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('RENTCORE TEST PRINT\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(utf8.encode('Thermal Printer Diagnostic\n'));
    builder.add(utf8.encode('$divider\n'));

    // Config info
    builder.add(cmdAlignLeft);
    builder.add(utf8.encode(_formatTwoColumn('Lebar Kertas', settings.paperWidth.label, width) + '\n'));
    builder.add(utf8.encode(_formatTwoColumn('Mode Cetak', settings.printMode.name.toUpperCase(), width) + '\n'));
    builder.add(utf8.encode(_formatTwoColumn('Total Kolom', '$width Karakter', width) + '\n'));
    builder.add(utf8.encode('$divider\n'));

    // Typography sample
    builder.add(utf8.encode('1. Teks Biasa: ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'));
    builder.add(cmdBoldOn);
    builder.add(utf8.encode('2. Teks Bold: 0123456789 (Angka Tebal)\n'));
    builder.add(cmdBoldOff);

    // Alignment samples (each on its own line per ESC/POS specification)
    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('Format: Teks Rata Kiri\n'));
    builder.add(cmdAlignCenter);
    builder.add(utf8.encode('Format: Teks Rata Tengah\n'));
    builder.add(cmdAlignRight);
    builder.add(utf8.encode('Format: Teks Rata Kanan\n'));
    builder.add(cmdAlignLeft);
    builder.add(utf8.encode('$divider\n'));

    // Column Ruler test
    String ruler = '';
    for (int i = 1; i <= width; i++) {
      ruler += (i % 10).toString();
    }
    builder.add(utf8.encode('Ruler: $ruler\n'));
    builder.add(utf8.encode('$divider\n'));

    // QR Code test (Only send GS ( k on 80mm printers; 58mm mobile displays safe text tag)
    if (settings.showQrBarcode) {
      builder.add(cmdAlignCenter);
      if (settings.paperWidth == ReceiptPaperWidth.mm80) {
        builder.add(_buildQrCodeEscPos('RENTCORE-TEST-OK'));
      }
      builder.add(utf8.encode('RENTCORE-TEST-OK\n\n'));
    }

    builder.add(cmdAlignCenter);
    builder.add(utf8.encode('Hardware siap & berfungsi baik!\n'));
    builder.add(utf8.encode('$divider\n'));

    builder.add(cmdFeed3Lines);
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  // --- Header & Footer Helpers ---
  void _appendHeader(BytesBuilder builder, ReceiptDataModel data, ReceiptCustomizationSettings settings) {
    if (settings.headerAlignment == ReceiptHeaderAlignment.center) {
      builder.add(cmdAlignCenter);
    } else {
      builder.add(cmdAlignLeft);
    }

    final shopName = settings.customShopName.isNotEmpty
        ? settings.customShopName
        : (data.shopName ?? 'RENTCORE GADGETS');
    final branchName = settings.customBranchName.isNotEmpty
        ? settings.customBranchName
        : data.branchName;

    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(utf8.encode('$shopName\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);

    builder.add(utf8.encode('$branchName\n'));

    if (settings.storeAddress.isNotEmpty) {
      builder.add(utf8.encode('${settings.storeAddress}\n'));
    }
    if (settings.storePhone.isNotEmpty) {
      builder.add(utf8.encode('Telp: ${settings.storePhone}\n'));
    }
  }

  void _appendFooter(BytesBuilder builder, ReceiptCustomizationSettings settings, int width) {
    builder.add(cmdAlignCenter);
    if (settings.showReturnTerms && settings.returnTermsText.isNotEmpty) {
      builder.add(utf8.encode('${settings.returnTermsText}\n\n'));
    }
    if (settings.customFooterMessage.isNotEmpty) {
      builder.add(utf8.encode('${settings.customFooterMessage}\n'));
    }
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    builder.add(utf8.encode('${dividerChar * width}\n'));
  }

  // --- Text & Number Helpers ---
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

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final start = phone.substring(0, 4);
    final end = phone.substring(phone.length - 4);
    return '$start****$end';
  }

  // --- QR Code ESC/POS Builder ---
  List<int> _buildQrCodeEscPos(String data) {
    final bytes = <int>[];
    final dataBytes = utf8.encode(data);
    final dataLen = dataBytes.length + 3;
    final pL = dataLen % 256;
    final pH = dataLen ~/ 256;

    // 1. Model 2: GS ( k 4 0 49 65 50 0
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // 2. Module Size 6: GS ( k 3 0 49 67 6
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, 0x06]);
    // 3. Error Correction Level M: GS ( k 3 0 49 69 49
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // 4. Store Data: GS ( k pL pH 49 80 48 <data>
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(dataBytes);
    // 5. Print Symbol: GS ( k 3 0 49 81 48
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  // ==========================================
  // Print Job Transmission (Normal vs Echo)
  // ==========================================
  Future<bool> sendPrintJob(Uint8List payload, [PrintMode mode = PrintMode.normal]) async {
    if (mode == PrintMode.echo) {
      _lastEchoLog = 'ECHO OK: ${payload.length} bytes dispatched at ${DateTime.now().toIso8601String()}';
    }

    if (_connectedDevice == null) {
      _lastError = 'Belum ada printer yang dipilih.';
      return false;
    }

    try {
      // 1. Verify active Bluetooth socket connection
      final bool socketAlive = await _driver.isConnected();
      if (!socketAlive) {
        // 2. Attempt transparent reconnection handshake
        final bool reconnected = await _driver.connect(_connectedDevice!.address);
        if (!reconnected) {
          _lastError = 'Gagal terhubung ke ${_connectedDevice!.name}. Pastikan printer menyala dan dalam jangkauan.';
          _connectedDevice = _connectedDevice!.copyWith(isConnected: false);
          return false;
        }
        _connectedDevice = _connectedDevice!.copyWith(isConnected: true);
      }

      // 3. Transmit payload bytes
      final bool success = await _driver.writeBytes(payload);
      if (!success) {
        _lastError = 'Gagal mengirim data cetak ke printer. Periksa status kertas atau koneksi Bluetooth.';
        return false;
      }

      _lastError = null;
      return true;
    } catch (e) {
      _lastError = 'Terjadi kesalahan saat transmisi ke printer: $e';
      return false;
    }
  }
}

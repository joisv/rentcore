import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:qr/qr.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    String? branchAddress,
    String? branchPhone,
    ReceiptCustomizationSettings? settings,
  }) {
    final effectiveSettings = settings ?? const ReceiptCustomizationSettings();
    final resolvedShop = effectiveSettings.customShopName.trim().isNotEmpty
        ? effectiveSettings.customShopName.trim()
        : (shopName.trim().isNotEmpty ? shopName.trim() : 'Toko Rental');
    final resolvedBranch = effectiveSettings.customBranchName.trim().isNotEmpty
        ? effectiveSettings.customBranchName.trim()
        : (branchName.trim().isNotEmpty ? branchName.trim() : 'Cabang Utama');
    final resolvedAddress = effectiveSettings.storeAddress.trim().isNotEmpty
        ? effectiveSettings.storeAddress.trim()
        : (branchAddress?.trim() ?? '');
    final resolvedPhone = effectiveSettings.storePhone.trim().isNotEmpty
        ? effectiveSettings.storePhone.trim()
        : (branchPhone?.trim() ?? '');
    final width = effectiveSettings.paperWidth.columns;
    final dividerChar = effectiveSettings.separatorStyle == 'double' ? '=' : '-';
    final divider = dividerChar * width;

    final builder = BytesBuilder();
    builder.add(cmdInit);
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(_encodeEscPos('$resolvedShop\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$resolvedBranch\n'));
    if (resolvedAddress.isNotEmpty) {
      builder.add(_encodeEscPos('$resolvedAddress\n'));
    }
    if (resolvedPhone.isNotEmpty) {
      builder.add(_encodeEscPos('Telp: $resolvedPhone\n'));
    }
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdBoldOn);
    builder.add(_encodeEscPos('VOUCHER DISKON SPESIAL\n'));
    builder.add(cmdDoubleSize);
    builder.add(_encodeEscPos('${discountPercentage.toInt()}% OFF\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignLeft);
    builder.add(_encodeEscPos('Kode Voucher  : $voucherCode\n'));
    builder.add(_encodeEscPos('Min. Transaksi: Rp ${_formatNumber(minTransaction)}\n'));
    builder.add(_encodeEscPos('Berlaku s/d   : $validUntil\n'));
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignCenter);
    builder.add(
      buildQrCodeBytes(
        voucherCode,
        paperWidth: effectiveSettings.paperWidth,
        useRasterQr: effectiveSettings.useRasterQr,
      ),
    );
    builder.add(_encodeEscPos('\n$voucherCode\n\n'));

    builder.add(_encodeEscPos('* Tunjukkan slip fisik ini atau\n'));
    builder.add(_encodeEscPos('  scan QR Code saat sewa gadget.\n'));
    if (effectiveSettings.customFooterMessage.trim().isNotEmpty) {
      builder.add(_encodeEscPos('${effectiveSettings.customFooterMessage.trim()}\n'));
    } else {
      builder.add(_encodeEscPos('Terima kasih atas kunjungan Anda!\n'));
    }
    builder.add(_encodeEscPos('${'=' * width}\n'));

    builder.add(_buildFeedLinesCmd(effectiveSettings.extraFeedLines));
    builder.add(cmdCutPaper);

    return builder.toBytes();
  }

  // ==========================================
  // 2. Closing Shift Slip (58mm/80mm Aware)
  // ==========================================
  Uint8List buildClosingShiftSlipBytes({
    required String branchName,
    required String cashierName,
    required String date,
    required int totalTransactions,
    required double totalRevenue,
    required Map<String, double> paymentBreakdown,
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm58,
    String? openedAt,
    String? closedAt,
    double? openingCashFloat,
    double? netCashRevenue,
    double? nonCashInflow,
    double? cashDrawerExpenses,
    double? expectedCashInDrawer,
    double? actualCashCounted,
    double? cashDifference,
    String? shiftNumber,
    String? shopName,
    String? branchAddress,
    String? branchPhone,
    ReceiptCustomizationSettings? settings,
  }) {
    final effectiveWidth = settings?.paperWidth ?? paperWidth;
    final builder = BytesBuilder();
    final width = effectiveWidth.columns;
    final doubleDivider = '=' * width;
    final singleDivider = '-' * width;

    final resolvedShop = (settings?.customShopName.trim().isNotEmpty == true)
        ? settings!.customShopName.trim()
        : (shopName?.trim().isNotEmpty == true ? shopName!.trim() : '');
    final resolvedBranch = (settings?.customBranchName.trim().isNotEmpty == true)
        ? settings!.customBranchName.trim()
        : (branchName.trim().isNotEmpty ? branchName.trim() : 'Cabang Utama');
    final resolvedAddress = (settings?.storeAddress.trim().isNotEmpty == true)
        ? settings!.storeAddress.trim()
        : (branchAddress?.trim() ?? '');
    final resolvedPhone = (settings?.storePhone.trim().isNotEmpty == true)
        ? settings!.storePhone.trim()
        : (branchPhone?.trim() ?? '');

    builder.add(cmdInit);
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    if (resolvedShop.isNotEmpty) {
      builder.add(_encodeEscPos('$resolvedShop\n'));
      builder.add(cmdNormalSize);
      builder.add(_encodeEscPos('LAPORAN CLOSING SHIFT\n'));
    } else {
      builder.add(_encodeEscPos('LAPORAN CLOSING SHIFT\n'));
      builder.add(cmdNormalSize);
    }
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$resolvedBranch\n'));
    if (resolvedAddress.isNotEmpty) {
      builder.add(_encodeEscPos('$resolvedAddress\n'));
    }
    if (resolvedPhone.isNotEmpty) {
      builder.add(_encodeEscPos('Telp: $resolvedPhone\n'));
    }
    if (shiftNumber != null && shiftNumber.isNotEmpty) {
      builder.add(_encodeEscPos('Shift: $shiftNumber\n'));
    }
    builder.add(_encodeEscPos('$doubleDivider\n'));

    builder.add(cmdAlignLeft);
    builder.add(_encodeEscPos('${_formatTwoColumn('Tanggal', date, width)}\n'));
    if (openedAt != null && openedAt.isNotEmpty) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Buka Shift', openedAt, width)}\n'));
    }
    if (closedAt != null && closedAt.isNotEmpty) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Tutup Shift', closedAt, width)}\n'));
    }
    builder.add(_encodeEscPos('${_formatTwoColumn('Kasir', cashierName, width)}\n'));
    builder.add(_encodeEscPos('$singleDivider\n'));

    builder.add(cmdBoldOn);
    builder.add(_encodeEscPos('${_formatTwoColumn('Total Transaksi', '$totalTransactions', width)}\n'));
    builder.add(_encodeEscPos('${_formatTwoColumn('Total Omset', 'Rp ${_formatNumber(totalRevenue)}', width)}\n'));
    builder.add(cmdBoldOff);
    if (nonCashInflow != null && nonCashInflow > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Kas Non-Tunai', 'Rp ${_formatNumber(nonCashInflow)}', width)}\n'));
    }
    builder.add(_encodeEscPos('$singleDivider\n'));

    builder.add(_encodeEscPos('RINCIAN METODE PEMBAYARAN:\n'));
    paymentBreakdown.forEach((method, amount) {
      final prefix = amount < 0 ? '-Rp ' : 'Rp ';
      final line = _formatTwoColumn(method, '$prefix${_formatNumber(amount.abs())}', width);
      builder.add(_encodeEscPos('$line\n'));
    });

    if (expectedCashInDrawer != null) {
      builder.add(_encodeEscPos('$singleDivider\n'));
      builder.add(cmdBoldOn);
      builder.add(_encodeEscPos('REKONSILIASI KAS LACI:\n'));
      builder.add(cmdBoldOff);
      if (openingCashFloat != null && openingCashFloat > 0) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Modal Awal Laci', 'Rp ${_formatNumber(openingCashFloat)}', width)}\n'));
      }
      if (netCashRevenue != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Kas Masuk Bersih', 'Rp ${_formatNumber(netCashRevenue)}', width)}\n'));
      }
      if (cashDrawerExpenses != null && cashDrawerExpenses > 0) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Beban Kas Laci', '-Rp ${_formatNumber(cashDrawerExpenses)}', width)}\n'));
      }
      builder.add(_encodeEscPos('$singleDivider\n'));
      builder.add(cmdBoldOn);
      builder.add(_encodeEscPos('${_formatTwoColumn('FISIK KAS SISTEM', 'Rp ${_formatNumber(expectedCashInDrawer)}', width)}\n'));
      if (actualCashCounted != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('FISIK KAS DIHITUNG', 'Rp ${_formatNumber(actualCashCounted)}', width)}\n'));
      }
      if (cashDifference != null) {
        final diffPrefix = cashDifference < 0 ? '-Rp ' : (cashDifference > 0 ? '+Rp ' : 'Rp ');
        builder.add(_encodeEscPos('${_formatTwoColumn('SELISIH KAS', '$diffPrefix${_formatNumber(cashDifference.abs())}', width)}\n'));
      }
      builder.add(cmdBoldOff);
    }

    builder.add(_encodeEscPos('$doubleDivider\n'));

    builder.add(cmdAlignCenter);
    builder.add(_encodeEscPos('Tanda Tangan Kasir / Supervisor\n\n\n'));
    builder.add(_encodeEscPos('( ____________________ )\n'));
    if (settings != null && settings.customFooterMessage.trim().isNotEmpty) {
      builder.add(_encodeEscPos('\n${settings.customFooterMessage.trim()}\n'));
    }

    builder.add(_buildFeedLinesCmd(settings?.extraFeedLines ?? 3));
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
      branchName: settings.customBranchName.isNotEmpty ? settings.customBranchName : 'Cabang Utama',
      shopName: settings.customShopName.isNotEmpty ? settings.customShopName : 'Toko Rental',
      branchAddress: settings.storeAddress.isNotEmpty ? settings.storeAddress : null,
      branchPhone: settings.storePhone.isNotEmpty ? settings.storePhone : null,
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
    final header = _resolveHeaderFields(data, settings);
    final shopName = header.shopName;
    final branchName = header.branchName;
    final address = header.address;
    final phone = header.phone;

    if (isEcho) {
      // Echo Mode: Clean, compact store identity
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.header,
        text: shopName,
        alignment: settings.headerAlignment,
        isBold: true,
        isDoubleSize: false,
      ));
      if (settings.customSlogan.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: settings.customSlogan,
          alignment: settings.headerAlignment,
        ));
      }
      String subInfo = branchName;
      if (phone.isNotEmpty) {
        subInfo = '$subInfo • $phone';
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.text,
        text: subInfo,
        alignment: settings.headerAlignment,
      ));
      if (address.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: address,
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
      if (settings.customSlogan.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: settings.customSlogan,
          alignment: settings.headerAlignment,
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.header,
        text: branchName,
        alignment: settings.headerAlignment,
      ));
      if (address.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.header,
          text: address,
          alignment: settings.headerAlignment,
        ));
      }
      if (phone.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.header,
          text: 'Telp: $phone',
          alignment: settings.headerAlignment,
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    }

    // 2. Receipt Title (plus optional Reprint header note)
    if (data.isReprint) {
      lines.add(const ReceiptLineItem(
        type: ReceiptLineType.text,
        text: '-- CETAK ULANG --',
        alignment: ReceiptHeaderAlignment.center,
        isBold: true,
      ));
    }
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

    if (data.type == ReceiptType.rentalExchange) {
      lines.add(const ReceiptLineItem(
        type: ReceiptLineType.text,
        text: 'PERANGKAT LAMA (DIKEMBALIKAN):',
        isBold: true,
      ));
      if (data.oldUnitName != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: data.oldUnitName!,
        ));
      }
      if (data.oldUnitSerial != null && data.oldUnitSerial!.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: 'SN/IMEI: ${data.oldUnitSerial}',
        ));
      }
      if (data.exchangeReason != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: 'Kendala: ${data.exchangeReason}',
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
      lines.add(const ReceiptLineItem(
        type: ReceiptLineType.text,
        text: 'PERANGKAT BARU (PENGGANTI):',
        isBold: true,
      ));
      if (data.unitName != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: data.unitName!,
        ));
      }
      if (data.unitSerial != null && data.unitSerial!.isNotEmpty) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.text,
          text: 'SN/IMEI: ${data.unitSerial}',
        ));
      }
      if (data.rentalEndDate != null) {
        lines.add(ReceiptLineItem(
          type: ReceiptLineType.keyValue,
          leftText: 'Batas Sewa Tetap',
          rightText: data.rentalEndDate!,
          text: _formatTwoColumn('Batas Sewa Tetap', data.rentalEndDate!, width),
        ));
      }
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.divider,
        text: divider,
        alignment: ReceiptHeaderAlignment.center,
      ));
    } else if (data.unitName != null) {
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
    if (data.type == ReceiptType.rentalExchange && data.priceDifferential != null) {
      lines.add(ReceiptLineItem(
        type: ReceiptLineType.keyValue,
        leftText: 'Selisih Biaya',
        rightText: data.priceDifferential! > 0 ? 'Rp ${_formatNumber(data.priceDifferential!)}' : 'Rp 0 (Setara)',
        text: _formatTwoColumn('Selisih Biaya', data.priceDifferential! > 0 ? 'Rp ${_formatNumber(data.priceDifferential!)}' : 'Rp 0 (Setara)', width),
        isBold: true,
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
          builder.add(_encodeEscPos('${line.text}\n'));
          if (line.isBold) builder.add(cmdBoldOff);
          if (line.isDoubleSize) builder.add(cmdNormalSize);
          break;
        case ReceiptLineType.qrCode:
          builder.add(cmdAlignCenter);
          if (line.qrData != null && line.qrData!.trim().isNotEmpty) {
            builder.add(
              buildQrCodeBytes(
                line.qrData!,
                paperWidth: settings.paperWidth,
                useRasterQr: settings.useRasterQr,
              ),
            );
          }
          builder.add(_encodeEscPos('${line.text}\n\n'));
          break;
        case ReceiptLineType.emptyFeed:
          builder.add(_encodeEscPos('\n'));
          break;
      }
    }

    builder.add(_buildFeedLinesCmd(settings.extraFeedLines));
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
    builder.add(_encodeEscPos('$divider\n'));

    // Title
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    if (data.isReprint) {
      builder.add(_encodeEscPos('-- CETAK ULANG --\n'));
    }
    builder.add(_encodeEscPos('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$divider\n'));

    // Transaction Details
    builder.add(cmdAlignLeft);
    if (data.bookingCode != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('No. Booking', data.bookingCode!, width)}\n'));
    }
    if (data.transactedAt != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Waktu', data.transactedAt!, width)}\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Kasir', data.cashierName!, width)}\n'));
    }
    if (data.customerName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Pelanggan', data.customerName!, width)}\n'));
    }
    if (settings.showCustomerPhone && data.customerPhone != null && data.customerPhone!.isNotEmpty) {
      final phone = settings.maskCustomerPhone ? _maskPhone(data.customerPhone!) : data.customerPhone!;
      builder.add(_encodeEscPos('${_formatTwoColumn('No. Telp', phone, width)}\n'));
    }
    builder.add(_encodeEscPos('$divider\n'));

    // Unit Details
    if (data.unitName != null) {
      builder.add(cmdBoldOn);
      builder.add(_encodeEscPos('DETAIL PERANGKAT:\n'));
      builder.add(cmdBoldOff);
      builder.add(_encodeEscPos('${data.unitName}\n'));
      if (data.unitSerial != null && data.unitSerial!.isNotEmpty) {
        builder.add(_encodeEscPos('SN/IMEI: ${data.unitSerial}\n'));
      }
      if (data.rentalDurationText != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Durasi', data.rentalDurationText!, width)}\n'));
      }
      if (data.rentalEndDate != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Batas Sewa', data.rentalEndDate!, width)}\n'));
      }
      if (settings.showCollateralInfo && data.collateralInfo != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Jaminan', data.collateralInfo!, width)}\n'));
      }
      builder.add(_encodeEscPos('$divider\n'));
    }

    // Financial breakdown
    if (data.subtotal != null && data.subtotal! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Biaya Sewa', 'Rp ${_formatNumber(data.subtotal!)}', width)}\n'));
    }
    if (data.discount != null && data.discount! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Diskon Promo', '-Rp ${_formatNumber(data.discount!)}', width)}\n'));
    }
    builder.add(cmdBoldOn);
    builder.add(_encodeEscPos('${_formatTwoColumn('TOTAL AKHIR', 'Rp ${_formatNumber(data.totalAmount)}', width)}\n'));
    builder.add(cmdBoldOff);

    if (data.paymentMethod != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Pembayaran', data.paymentMethod!, width)}\n'));
    }
    if (settings.showChangeDue && data.cashReceived != null && data.cashReceived! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Uang Diterima', 'Rp ${_formatNumber(data.cashReceived!)}', width)}\n'));
      if (data.cashChange != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Kembalian', 'Rp ${_formatNumber(data.cashChange!)}', width)}\n'));
      }
    }
    builder.add(_encodeEscPos('$divider\n'));

    // QR Code for Fast Return (both 58mm size4 and 80mm size6, or raster bitmap)
    if (settings.showQrBarcode && (data.qrData != null || data.bookingCode != null)) {
      final qrString = data.qrData ?? data.bookingCode!;
      builder.add(cmdAlignCenter);
      builder.add(
        buildQrCodeBytes(
          qrString,
          paperWidth: settings.paperWidth,
          useRasterQr: settings.useRasterQr,
        ),
      );
      builder.add(_encodeEscPos('$qrString\n\n'));
    }

    // Footer & Terms
    _appendFooter(builder, settings, width);

    builder.add(_buildFeedLinesCmd(settings.extraFeedLines));
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
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    if (data.isReprint) {
      builder.add(_encodeEscPos('-- CETAK ULANG --\n'));
    }
    builder.add(_encodeEscPos('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignLeft);
    if (data.receiptNumber != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('No. Struk', data.receiptNumber!, width)}\n'));
    }
    if (data.bookingCode != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Ref Booking', data.bookingCode!, width)}\n'));
    }
    if (data.transactedAt != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Waktu', data.transactedAt!, width)}\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Kasir', data.cashierName!, width)}\n'));
    }
    if (data.customerName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Pelanggan', data.customerName!, width)}\n'));
    }
    builder.add(_encodeEscPos('$divider\n'));

    // Line items or summary
    if (data.items != null && data.items!.isNotEmpty) {
      for (final item in data.items!) {
        final name = item['name']?.toString() ?? 'Item';
        final price = (item['price'] is num) ? (item['price'] as num).toDouble() : 0.0;
        builder.add(_encodeEscPos('${_formatTwoColumn(name, 'Rp ${_formatNumber(price)}', width)}\n'));
      }
      builder.add(_encodeEscPos('$divider\n'));
    }

    if (data.subtotal != null && data.subtotal! > 0 && (data.discount ?? 0) > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Subtotal', 'Rp ${_formatNumber(data.subtotal!)}', width)}\n'));
    }
    if (data.discount != null && data.discount! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Diskon', '-Rp ${_formatNumber(data.discount!)}', width)}\n'));
    }

    if (data.penaltyAmount != null && data.penaltyAmount! > 0 && settings.showPenaltyDetails) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Denda Telat', 'Rp ${_formatNumber(data.penaltyAmount!)}', width)}\n'));
    }

    builder.add(cmdBoldOn);
    builder.add(_encodeEscPos('${_formatTwoColumn('TOTAL BAYAR', 'Rp ${_formatNumber(data.totalAmount)}', width)}\n'));
    builder.add(cmdBoldOff);

    if (data.paymentMethod != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Metode', data.paymentMethod!, width)}\n'));
    }
    if (settings.showChangeDue && data.cashReceived != null && data.cashReceived! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Tunai Diterima', 'Rp ${_formatNumber(data.cashReceived!)}', width)}\n'));
      if (data.cashChange != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Kembalian', 'Rp ${_formatNumber(data.cashChange!)}', width)}\n'));
      }
    }

    final remaining = data.remainingBalance ?? 0.0;
    final isDpOrPartial = data.isDownPayment || remaining > 0;
    builder.add(cmdBoldOn);
    if (isDpOrPartial) {
      builder.add(_encodeEscPos('STATUS: DP (BELUM LUNAS)\n'));
      builder.add(cmdBoldOff);
      builder.add(_encodeEscPos('${_formatTwoColumn('Sisa Tagihan', 'Rp ${_formatNumber(remaining)}', width)}\n'));
    } else {
      builder.add(_encodeEscPos('STATUS: LUNAS\n'));
      builder.add(cmdBoldOff);
    }
    builder.add(_encodeEscPos('$divider\n'));

    _appendFooter(builder, settings, width);

    builder.add(_buildFeedLinesCmd(settings.extraFeedLines));
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
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    if (data.isReprint) {
      builder.add(_encodeEscPos('-- CETAK ULANG --\n'));
    }
    builder.add(_encodeEscPos('${data.title}\n'));
    builder.add(cmdBoldOff);
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(cmdAlignLeft);
    if (data.bookingCode != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Kode Sewa', data.bookingCode!, width)}\n'));
    }
    if (data.transactedAt != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Waktu Kembali', data.transactedAt!, width)}\n'));
    }
    if (settings.showCashierName && data.cashierName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Petugas', data.cashierName!, width)}\n'));
    }
    if (data.customerName != null) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Pelanggan', data.customerName!, width)}\n'));
    }
    builder.add(_encodeEscPos('$divider\n'));

    if (data.unitName != null) {
      builder.add(cmdBoldOn);
      builder.add(_encodeEscPos('HASIL PEMERIKSAAN UNIT:\n'));
      builder.add(cmdBoldOff);
      builder.add(_encodeEscPos('${data.unitName}\n'));
      if (data.conditionGrade != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Kondisi Fisik', data.conditionGrade!, width)}\n'));
      }
      if (data.checklistNotes != null) {
        builder.add(_encodeEscPos('Checklist: ${data.checklistNotes}\n'));
      }
      if (data.accessoriesNotes != null) {
        builder.add(_encodeEscPos('Aksesoris: ${data.accessoriesNotes}\n'));
      }
      builder.add(_encodeEscPos('${_formatTwoColumn('Status Jaminan', 'KTP DIKEMBALIKAN', width)}\n'));
      builder.add(_encodeEscPos('$divider\n'));
    }

    if (data.penaltyAmount != null && data.penaltyAmount! > 0) {
      builder.add(_encodeEscPos('${_formatTwoColumn('Denda Keterlambatan', 'Rp ${_formatNumber(data.penaltyAmount!)}', width)}\n'));
      if (data.paymentMethod != null) {
        builder.add(_encodeEscPos('${_formatTwoColumn('Status Denda', 'LUNAS (${data.paymentMethod})', width)}\n'));
      }
      builder.add(_encodeEscPos('$divider\n'));
    }

    _appendFooter(builder, settings, width);

    builder.add(_buildFeedLinesCmd(settings.extraFeedLines));
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
    final headerTitle = settings.customShopName.trim().isNotEmpty
        ? settings.customShopName.trim()
        : 'TEST PRINT THERMAL';

    builder.add(cmdInit);

    // Center header test
    builder.add(cmdAlignCenter);
    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(_encodeEscPos('$headerTitle\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);
    if (settings.customBranchName.trim().isNotEmpty) {
      builder.add(_encodeEscPos('${settings.customBranchName.trim()}\n'));
    }
    builder.add(_encodeEscPos('Thermal Printer Diagnostic\n'));
    builder.add(_encodeEscPos('$divider\n'));

    // Config info
    builder.add(cmdAlignLeft);
    builder.add(_encodeEscPos('${_formatTwoColumn('Lebar Kertas', settings.paperWidth.label, width)}\n'));
    builder.add(_encodeEscPos('${_formatTwoColumn('Mode Cetak', settings.printMode.name.toUpperCase(), width)}\n'));
    builder.add(_encodeEscPos('${_formatTwoColumn('Total Kolom', '$width Karakter', width)}\n'));
    builder.add(_encodeEscPos('${_formatTwoColumn('Feed Akhir', '${settings.extraFeedLines} Baris', width)}\n'));
    builder.add(_encodeEscPos('${_formatTwoColumn('Mode QR', settings.useRasterQr ? 'Raster Bitmap' : 'ESC/POS Native', width)}\n'));
    builder.add(_encodeEscPos('$divider\n'));

    // Typography sample
    builder.add(_encodeEscPos('1. Teks Biasa: ABCDEFGHIJKLMNOPQRSTUVWXYZ\n'));
    builder.add(cmdBoldOn);
    builder.add(_encodeEscPos('2. Teks Bold: 0123456789 (Angka Tebal)\n'));
    builder.add(cmdBoldOff);

    // Alignment samples (each on its own line per ESC/POS specification)
    builder.add(cmdAlignLeft);
    builder.add(_encodeEscPos('Format: Teks Rata Kiri\n'));
    builder.add(cmdAlignCenter);
    builder.add(_encodeEscPos('Format: Teks Rata Tengah\n'));
    builder.add(cmdAlignRight);
    builder.add(_encodeEscPos('Format: Teks Rata Kanan\n'));
    builder.add(cmdAlignLeft);
    builder.add(_encodeEscPos('$divider\n'));

    // Column Ruler test
    String ruler = '';
    for (int i = 1; i <= width; i++) {
      ruler += (i % 10).toString();
    }
    builder.add(_encodeEscPos('Ruler: $ruler\n'));
    builder.add(_encodeEscPos('$divider\n'));

    // QR Code test (supports native 58mm/80mm and raster bitmap mode)
    if (settings.showQrBarcode) {
      builder.add(cmdAlignCenter);
      builder.add(
        buildQrCodeBytes(
          'TEST-PRINT-OK',
          paperWidth: settings.paperWidth,
          useRasterQr: settings.useRasterQr,
        ),
      );
      builder.add(_encodeEscPos('TEST-PRINT-OK\n\n'));
    }

    builder.add(cmdAlignCenter);
    builder.add(_encodeEscPos('Hardware siap & berfungsi baik!\n'));
    builder.add(_encodeEscPos('$divider\n'));

    builder.add(_buildFeedLinesCmd(settings.extraFeedLines));
    builder.add(cmdCutPaper);
    return builder.toBytes();
  }

  // --- Header & Footer Helpers ---
  ({String shopName, String branchName, String address, String phone}) _resolveHeaderFields(
    ReceiptDataModel? data,
    ReceiptCustomizationSettings settings,
  ) {
    final customShop = settings.customShopName.trim();
    final dataShop = data?.shopName?.trim() ?? '';
    final shopName = customShop.isNotEmpty
        ? customShop
        : (dataShop.isNotEmpty ? dataShop : 'Toko Rental');

    final customBranch = settings.customBranchName.trim();
    final dataBranch = data?.branchName.trim() ?? '';
    final branchName = customBranch.isNotEmpty
        ? customBranch
        : (dataBranch.isNotEmpty ? dataBranch : 'Cabang Utama');

    final customAddr = settings.storeAddress.trim();
    final dataAddr = data?.branchAddress?.trim() ?? '';
    final address = customAddr.isNotEmpty ? customAddr : dataAddr;

    final customPhone = settings.storePhone.trim();
    final dataPhone = data?.branchPhone?.trim() ?? '';
    final phone = customPhone.isNotEmpty ? customPhone : dataPhone;

    return (
      shopName: shopName,
      branchName: branchName,
      address: address,
      phone: phone,
    );
  }

  List<int> _buildFeedLinesCmd(int lines) {
    final clamped = lines.clamp(0, 15);
    if (clamped == 0) return const [];
    return [0x1B, 0x64, clamped];
  }

  void _appendHeader(BytesBuilder builder, ReceiptDataModel data, ReceiptCustomizationSettings settings) {
    if (settings.headerAlignment == ReceiptHeaderAlignment.center) {
      builder.add(cmdAlignCenter);
    } else {
      builder.add(cmdAlignLeft);
    }

    final header = _resolveHeaderFields(data, settings);

    builder.add(cmdBoldOn);
    builder.add(cmdDoubleSize);
    builder.add(_encodeEscPos('${header.shopName}\n'));
    builder.add(cmdNormalSize);
    builder.add(cmdBoldOff);

    if (settings.customSlogan.trim().isNotEmpty) {
      builder.add(_encodeEscPos('${settings.customSlogan.trim()}\n'));
    }

    builder.add(_encodeEscPos('${header.branchName}\n'));

    if (header.address.isNotEmpty) {
      builder.add(_encodeEscPos('${header.address}\n'));
    }
    if (header.phone.isNotEmpty) {
      builder.add(_encodeEscPos('Telp: ${header.phone}\n'));
    }
  }

  void _appendFooter(BytesBuilder builder, ReceiptCustomizationSettings settings, int width) {
    builder.add(cmdAlignCenter);
    if (settings.showReturnTerms && settings.returnTermsText.isNotEmpty) {
      builder.add(_encodeEscPos('${settings.returnTermsText}\n\n'));
    }
    if (settings.customFooterMessage.isNotEmpty) {
      builder.add(_encodeEscPos('${settings.customFooterMessage}\n'));
    }
    final dividerChar = settings.separatorStyle == 'double' ? '=' : '-';
    builder.add(_encodeEscPos('${dividerChar * width}\n'));
  }

  // --- Text, Sanitizer & Number Helpers ---
  String _sanitizeEscPosText(String input) {
    return input
        .replaceAll('•', '-')
        .replaceAll('—', '-')
        .replaceAll('–', '-')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('\u00A0', ' ');
  }

  List<int> _encodeEscPos(String text) {
    return const Latin1Codec(allowInvalid: true).encode(_sanitizeEscPosText(text));
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
    final cleanLeft = _sanitizeEscPosText(left).trim();
    final cleanRight = _sanitizeEscPosText(right).trim();
    final safeWidth = totalWidth > 8 ? totalWidth : 32;

    if (cleanLeft.length + 1 + cleanRight.length <= safeWidth) {
      final spaces = safeWidth - cleanLeft.length - cleanRight.length;
      return '$cleanLeft${' ' * spaces}$cleanRight';
    }

    final words = cleanLeft.split(RegExp(r'\s+'));
    final wrapped = <String>[];
    var current = '';
    for (final word in words) {
      if (word.isEmpty) continue;
      if (current.isEmpty) {
        if (word.length <= safeWidth) {
          current = word;
        } else {
          for (int i = 0; i < word.length; i += safeWidth) {
            final end = (i + safeWidth < word.length) ? i + safeWidth : word.length;
            final chunk = word.substring(i, end);
            if (end < word.length) {
              wrapped.add(chunk);
            } else {
              current = chunk;
            }
          }
        }
      } else if (current.length + 1 + word.length <= safeWidth) {
        current = '$current $word';
      } else {
        wrapped.add(current);
        current = word;
      }
    }
    if (current.isNotEmpty) {
      wrapped.add(current);
    }
    if (wrapped.isEmpty) {
      wrapped.add('');
    }

    final last = wrapped.removeLast();
    final buffer = StringBuffer();
    for (final line in wrapped) {
      buffer.writeln(line);
    }

    if (last.length + 1 + cleanRight.length <= safeWidth) {
      final spaces = safeWidth - last.length - cleanRight.length;
      buffer.write('$last${' ' * spaces}$cleanRight');
    } else {
      buffer.writeln(last);
      final rightPad = (safeWidth - cleanRight.length).clamp(0, safeWidth);
      buffer.write('${' ' * rightPad}$cleanRight');
    }
    return buffer.toString();
  }

  String _maskPhone(String phone) {
    if (phone.length <= 6) return phone;
    final start = phone.substring(0, 4);
    final end = phone.substring(phone.length - 4);
    return '$start****$end';
  }

  // --- QR Code ESC/POS Builder ---
  /// Builds ESC/POS bytes for a QR code, choosing either native ESC/POS
  /// `GS ( k` or monochrome raster bitmap `GS v 0` when [useRasterQr] is true.
  List<int> buildQrCodeBytes(
    String data, {
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm80,
    bool useRasterQr = false,
  }) {
    if (useRasterQr) {
      return _buildQrCodeRasterEscPos(data, paperWidth: paperWidth);
    }
    return _buildQrCodeEscPos(data, paperWidth: paperWidth);
  }

  List<int> _buildQrCodeEscPos(
    String data, {
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm80,
  }) {
    final bytes = <int>[];
    final dataBytes = utf8.encode(data);
    final dataLen = dataBytes.length + 3;
    final pL = dataLen % 256;
    final pH = dataLen ~/ 256;
    final moduleSize = paperWidth == ReceiptPaperWidth.mm58 ? 0x04 : 0x06;

    // 1. Model 2: GS ( k 4 0 49 65 50 0
    bytes.addAll([0x1D, 0x28, 0x6B, 0x04, 0x00, 0x31, 0x41, 0x32, 0x00]);
    // 2. Module Size (size4 for 58mm, size6 for 80mm): GS ( k 3 0 49 67 <moduleSize>
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x43, moduleSize]);
    // 3. Error Correction Level M: GS ( k 3 0 49 69 49
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x45, 0x31]);
    // 4. Store Data: GS ( k pL pH 49 80 48 <data>
    bytes.addAll([0x1D, 0x28, 0x6B, pL, pH, 0x31, 0x50, 0x30]);
    bytes.addAll(dataBytes);
    // 5. Print Symbol: GS ( k 3 0 49 81 48
    bytes.addAll([0x1D, 0x28, 0x6B, 0x03, 0x00, 0x31, 0x51, 0x30]);

    return bytes;
  }

  /// Renders [data] to a monochrome [img.Image] and encodes it with ESC/POS
  /// `GS v 0` raster bit-image commands for low-cost ESC/POS printers that
  /// lack native `GS ( k` QR firmware support.
  List<int> _buildQrCodeRasterEscPos(
    String data, {
    ReceiptPaperWidth paperWidth = ReceiptPaperWidth.mm80,
  }) {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final moduleCount = qrImage.moduleCount;
    final targetPx = paperWidth == ReceiptPaperWidth.mm58 ? 192 : 256;
    final modulePx = (targetPx ~/ (moduleCount + 4)).clamp(3, 10);
    final rawSize = moduleCount * modulePx + modulePx * 4;
    // Align width to 8-pixel byte boundary for GS v 0
    final size = ((rawSize + 7) ~/ 8) * 8;
    final offset = (size - moduleCount * modulePx) ~/ 2;

    final bitmap = img.Image(width: size, height: size);
    img.fill(bitmap, color: img.ColorRgb8(255, 255, 255));

    for (var row = 0; row < moduleCount; row++) {
      for (var col = 0; col < moduleCount; col++) {
        if (qrImage.isDark(row, col)) {
          final x0 = offset + col * modulePx;
          final y0 = offset + row * modulePx;
          img.fillRect(
            bitmap,
            x1: x0,
            y1: y0,
            x2: x0 + modulePx - 1,
            y2: y0 + modulePx - 1,
            color: img.ColorRgb8(0, 0, 0),
          );
        }
      }
    }

    return encodeRasterImageEscPos(bitmap);
  }

  /// Encodes a [img.Image] as a 1-bit monochrome ESC/POS `GS v 0` raster image.
  @visibleForTesting
  List<int> encodeRasterImageEscPos(img.Image image) {
    final width = image.width;
    final height = image.height;
    final xBytes = (width + 7) ~/ 8;
    final xL = xBytes & 0xFF;
    final xH = (xBytes >> 8) & 0xFF;
    final yL = height & 0xFF;
    final yH = (height >> 8) & 0xFF;

    final bytes = <int>[0x1D, 0x76, 0x30, 0x00, xL, xH, yL, yH];
    for (var y = 0; y < height; y++) {
      for (var xByte = 0; xByte < xBytes; xByte++) {
        var slice = 0;
        for (var bit = 0; bit < 8; bit++) {
          final x = xByte * 8 + bit;
          if (x < width) {
            final pixel = image.getPixel(x, y);
            final luminance = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
            if (luminance < 128) {
              slice |= (1 << (7 - bit));
            }
          }
        }
        bytes.add(slice);
      }
    }
    return bytes;
  }

  /// Restores the saved printer from SharedPreferences if [_connectedDevice] is null.
  Future<ThermalPrinterDevice?> loadSavedDeviceFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final deviceJson = prefs.getString('rentcore_printer_saved_device_v1');
      if (deviceJson != null && deviceJson.trim().isNotEmpty) {
        final decoded = json.decode(deviceJson) as Map<String, dynamic>;
        final parsed = ThermalPrinterDevice.fromJson(decoded);
        if (parsed.address.trim().isNotEmpty) return parsed;
      }
      final mac = (prefs.getString('mac_address') ??
              prefs.getString('last_connected_printer_mac') ??
              prefs.getString('selected_printer_device') ??
              '')
          .trim();
      if (mac.isNotEmpty) {
        final name = (prefs.getString('printer_name') ??
                prefs.getString('last_connected_printer_name') ??
                'Thermal Printer')
            .trim();
        return ThermalPrinterDevice(
          name: name.isNotEmpty ? name : 'Thermal Printer',
          address: mac,
        );
      }
    } catch (e) {
      debugPrint('[ThermalPrinterService] loadSavedDeviceFromPrefs error: $e');
    }
    return null;
  }

  // ==========================================
  // Print Job Transmission (Normal vs Echo)
  // ==========================================
  Future<bool> sendPrintJob(Uint8List payload, [PrintMode mode = PrintMode.normal]) async {
    if (mode == PrintMode.echo) {
      _lastEchoLog = 'ECHO OK: ${payload.length} bytes dispatched at ${DateTime.now().toIso8601String()}';
    }

    _connectedDevice ??= await loadSavedDeviceFromPrefs();
    if (_connectedDevice == null || _connectedDevice!.address.trim().isEmpty) {
      _lastError = 'Belum ada printer yang dipilih.';
      return false;
    }

    try {
      // 1. Verify runtime Bluetooth permissions before touching socket
      final bool hasPermission = await _driver.checkAndRequestPermissions();
      if (!hasPermission) {
        _lastError = 'Izin Bluetooth ditolak. Aktifkan izin Bluetooth di Pengaturan aplikasi.';
        return false;
      }

      // 2. Verify Bluetooth adapter state
      final bool btAvailable = await _driver.isBluetoothAvailable();
      if (!btAvailable) {
        _lastError = 'Bluetooth nonaktif. Silakan nyalakan Bluetooth Anda terlebih dahulu.';
        return false;
      }

      // 3. Verify active Bluetooth socket connection; silent reconnect if disconnected
      final bool socketAlive = await _driver.isConnected();
      if (!socketAlive) {
        final bool reconnected = await _driver.connect(_connectedDevice!.address);
        if (!reconnected) {
          _lastError = 'Gagal terhubung ke ${_connectedDevice!.name}. Pastikan printer menyala dan dalam jangkauan.';
          _connectedDevice = _connectedDevice!.copyWith(isConnected: false);
          return false;
        }
        _connectedDevice = _connectedDevice!.copyWith(isConnected: true);
      }

      // 4. Transmit payload bytes
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

import 'dart:convert';
import 'dart:typed_data';

import 'thermal_printer_service.dart';

/// Unified ESC/POS byte builder that renders directly from [ReceiptDocumentData].
///
/// Guarantees 1:1 structural parity with `UnifiedThermalReceiptPreview`:
/// 1. Store & Branch Header
/// 2. Optional `[CETAK ULANG]` header tag (when `data.isReprint == true`) & Title
/// 3. Transaction Metadata (code, time, cashier, customer, phone, rental period, collateral)
/// 4. Line Items (name, variant/code, qty/unit price, right-aligned total)
/// 5. Financial & Payment Summary (subtotal, discount, penalty, total, payment method, paid/change, status)
/// 6. Optional QR Code (`GS ( k` native or `GS v 0` raster bitmap)
/// 7. Return Terms & Footer Note + Feed & Cut
class ThermalReceiptEscPosBuilder {
  const ThermalReceiptEscPosBuilder._();

  static const String reprintTag = '[CETAK ULANG]';

  /// Builds raw ESC/POS bytes from [ReceiptDocumentData] using the exact same
  /// column width (`32` for `58mm`, `48` for `80mm`) and section order shown on screen.
  static Uint8List build(ReceiptDocumentData data) {
    final builder = BytesBuilder();
    final width = data.columns;
    final divider = data.dividerLine;
    final isEcho = data.isCompactEcho;

    builder.add(ThermalPrinterService.cmdInit);

    // 1. Store & Branch Header
    builder.add(
      data.headerAlignment == ReceiptHeaderAlignment.center
          ? ThermalPrinterService.cmdAlignCenter
          : ThermalPrinterService.cmdAlignLeft,
    );
    builder.add(ThermalPrinterService.cmdBoldOn);
    if (!isEcho) {
      builder.add(ThermalPrinterService.cmdDoubleSize);
    }
    builder.add(_encode('${data.storeName}\n'));
    if (!isEcho) {
      builder.add(ThermalPrinterService.cmdNormalSize);
    }
    builder.add(ThermalPrinterService.cmdBoldOff);

    if (data.storeTagline.trim().isNotEmpty) {
      builder.add(_encode('${data.storeTagline.trim()}\n'));
    }

    if (isEcho) {
      final subLine = data.storePhone.trim().isNotEmpty
          ? '${data.branchName} - ${data.storePhone.trim()}'
          : data.branchName;
      builder.add(_encode('$subLine\n'));
      if (data.storeAddress.trim().isNotEmpty) {
        builder.add(_encode('${data.storeAddress.trim()}\n'));
      }
    } else {
      if (data.branchName.trim().isNotEmpty) {
        builder.add(_encode('${data.branchName.trim()}\n'));
      }
      if (data.storeAddress.trim().isNotEmpty) {
        builder.add(_encode('${data.storeAddress.trim()}\n'));
      }
      if (data.storePhone.trim().isNotEmpty) {
        builder.add(_encode('Telp: ${data.storePhone.trim()}\n'));
      }
    }

    builder.add(ThermalPrinterService.cmdAlignCenter);
    builder.add(_encode('$divider\n'));

    // 2. Reprint Tag & Document Title
    builder.add(ThermalPrinterService.cmdBoldOn);
    if (data.isReprint) {
      builder.add(_encode('$reprintTag\n'));
    }
    builder.add(_encode('${data.title}\n'));
    builder.add(ThermalPrinterService.cmdBoldOff);
    builder.add(_encode('$divider\n'));

    // 3. Transaction Metadata
    builder.add(ThermalPrinterService.cmdAlignLeft);
    builder.add(_encode('${formatTwoColumn('No. Struk', data.transactionCode, width)}\n'));
    if (data.bookingCode != null &&
        data.bookingCode!.trim().isNotEmpty &&
        data.bookingCode!.trim() != data.transactionCode.trim()) {
      builder.add(_encode('${formatTwoColumn('No. Booking', data.bookingCode!.trim(), width)}\n'));
    }
    if (data.printedAt.trim().isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('Waktu', data.printedAt.trim(), width)}\n'));
    }
    if (data.showCashierName && data.cashierName.trim().isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('Kasir', data.cashierName.trim(), width)}\n'));
    }
    if (data.customerName.trim().isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('Pelanggan', data.customerName.trim(), width)}\n'));
    }
    if (data.showCustomerPhone && data.formattedCustomerPhone.isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('No. Telp', data.formattedCustomerPhone, width)}\n'));
    }
    if (data.rentalPeriodLabel.trim().isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('Periode', data.rentalPeriodLabel.trim(), width)}\n'));
    }
    if (data.showCollateralInfo &&
        data.collateralSummary != null &&
        data.collateralSummary!.trim().isNotEmpty) {
      builder.add(_encode('${formatTwoColumn('Jaminan', data.collateralSummary!.trim(), width)}\n'));
    }
    builder.add(_encode('$divider\n'));

    // 4. Line Items
    if (data.items.isNotEmpty) {
      for (final item in data.items) {
        builder.add(
          _encode(
            '${formatTwoColumn(item.displayName, formatReceiptCurrency(item.totalPrice), width)}\n',
          ),
        );
        final sub = item.detailSubtitle;
        if (sub != null && sub.isNotEmpty) {
          builder.add(_encode('  $sub\n'));
        }
      }
      builder.add(_encode('$divider\n'));
    }

    // 5. Financial & Payment Summary
    if (data.subtotal > 0 &&
        (data.discount > 0 || data.penaltyAmount > 0 || data.items.length > 1)) {
      builder.add(
        _encode('${formatTwoColumn('Subtotal', formatReceiptCurrency(data.subtotal), width)}\n'),
      );
    }
    if (data.discount > 0) {
      builder.add(
        _encode('${formatTwoColumn('Diskon', '-${formatReceiptCurrency(data.discount)}', width)}\n'),
      );
    }
    if (data.showPenaltyDetails &&
        (data.penaltyAmount > 0 || data.waivedLateFee > 0)) {
      final grossPenalty = data.calculatedLateFee > 0
          ? data.calculatedLateFee
          : data.penaltyAmount;
      builder.add(
        _encode('${formatTwoColumn('Denda Telat', formatReceiptCurrency(grossPenalty), width)}\n'),
      );
      if (data.waivedLateFee > 0) {
        builder.add(
          _encode('${formatTwoColumn('Keringanan Denda', '-${formatReceiptCurrency(data.waivedLateFee)}', width)}\n'),
        );
        if (data.lateFeeWaiverReason != null &&
            data.lateFeeWaiverReason!.trim().isNotEmpty) {
          builder.add(
            _encode('${formatTwoColumn('Alasan', data.lateFeeWaiverReason!.trim(), width)}\n'),
          );
        }
      }
    }

    builder.add(ThermalPrinterService.cmdBoldOn);
    builder.add(
      _encode('${formatTwoColumn('TOTAL', formatReceiptCurrency(data.totalAmount), width)}\n'),
    );
    builder.add(ThermalPrinterService.cmdBoldOff);

    builder.add(
      _encode('${formatTwoColumn('Metode', data.paymentMethodLabel, width)}\n'),
    );
    if (data.showChangeDue && data.paidAmount > 0) {
      builder.add(
        _encode('${formatTwoColumn('Dibayar', formatReceiptCurrency(data.paidAmount), width)}\n'),
      );
      if (data.changeAmount > 0 ||
          data.paymentMethodLabel.toLowerCase() == 'tunai') {
        builder.add(
          _encode('${formatTwoColumn('Kembalian', formatReceiptCurrency(data.changeAmount), width)}\n'),
        );
      }
    }

    builder.add(ThermalPrinterService.cmdBoldOn);
    if (data.isPartialOrDownPayment) {
      builder.add(_encode('STATUS: DP (BELUM LUNAS)\n'));
      builder.add(ThermalPrinterService.cmdBoldOff);
      if (data.remainingBalance > 0) {
        builder.add(
          _encode('${formatTwoColumn('Sisa Tagihan', formatReceiptCurrency(data.remainingBalance), width)}\n'),
        );
      }
    } else {
      builder.add(_encode('STATUS: LUNAS\n'));
      builder.add(ThermalPrinterService.cmdBoldOff);
    }
    builder.add(_encode('$divider\n'));

    // 6. Optional QR Code
    final qrString = data.effectiveQrData;
    if (data.showQrBarcode && qrString != null) {
      builder.add(ThermalPrinterService.cmdAlignCenter);
      builder.add(
        ThermalPrinterService().buildQrCodeBytes(
          qrString,
          paperWidth: data.paperWidth,
          useRasterQr: data.useRasterQr,
        ),
      );
      builder.add(_encode('$qrString\n\n'));
    }

    // 7. Return Terms & Footer Note
    builder.add(ThermalPrinterService.cmdAlignCenter);
    if (data.showReturnTerms && data.returnTermsText.trim().isNotEmpty) {
      builder.add(_encode('${data.returnTermsText.trim()}\n'));
    }
    if (data.footerNote.trim().isNotEmpty) {
      builder.add(_encode('${data.footerNote.trim()}\n'));
    }
    builder.add(_encode('$divider\n'));

    // Feed & Cut
    final feed = data.extraFeedLines.clamp(0, 15);
    if (feed > 0) {
      builder.add([0x1B, 0x64, feed]);
    }
    builder.add(ThermalPrinterService.cmdCutPaper);

    return builder.toBytes();
  }

  /// Formats a two-column key/value thermal line strictly within [totalWidth] characters.
  static String formatTwoColumn(String left, String right, int totalWidth) {
    final cleanLeft = sanitizeText(left).trim();
    final cleanRight = sanitizeText(right).trim();
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
            final end =
                (i + safeWidth < word.length) ? i + safeWidth : word.length;
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
    if (current.isNotEmpty) wrapped.add(current);
    if (wrapped.isEmpty) wrapped.add('');

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

  static String sanitizeText(String input) {
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

  static List<int> _encode(String text) {
    return const Latin1Codec(allowInvalid: true).encode(sanitizeText(text));
  }
}

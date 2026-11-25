import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/receipt_document_data.dart';
import '../models/thermal_printer_models.dart';
import '../services/thermal_receipt_escpos_builder.dart';

/// Single Source of Truth Airy Minimalist thermal paper preview widget.
///
/// Renders [ReceiptDocumentData] identically across:
/// - **Pengaturan Printer** & **Desain Struk** (live sample preview)
/// - **Dashboard Queue `Cetak Struk` Preview Modal**
/// - **Rincian Transaksi Reprint Modal**
/// - **POS Checkout Receipt Preview**
class UnifiedThermalReceiptPreview extends StatelessWidget {
  final ReceiptDocumentData data;

  /// Optional top strip badge (e.g. `TEAR BAR MANUAL (58MM)` or `MODE ECHO • KOMPAK (58MM)`).
  final String? paperEdgeLabel;

  /// Optional icon shown alongside [paperEdgeLabel].
  final IconData? paperEdgeIcon;

  /// Optional color for [paperEdgeIcon].
  final Color? paperEdgeIconColor;

  /// Shows subtle bottom dotted tear edge for realistic roll finish.
  final bool showBottomTearEdge;

  const UnifiedThermalReceiptPreview({
    super.key,
    required this.data,
    this.paperEdgeLabel,
    this.paperEdgeIcon,
    this.paperEdgeIconColor,
    this.showBottomTearEdge = true,
  });

  static const Color _paperBg = Color(0xFFFFFFFF);
  static const Color _paperBorder = Color(0xFFE2E8F0);
  static const Color _inkPrimary = Color(0xFF0F172A);
  static const Color _inkSecondary = Color(0xFF64748B);
  static const Color _dividerColor = Color(0xFFCBD5E1);
  static const Color _reprintBg = Color(0xFFF1F5F9);
  static const Color _reprintBorder = Color(0xFFCBD5E1);

  @override
  Widget build(BuildContext context) {
    final is58mm = data.paperWidthMm < 80;
    final isCompact = data.isCompactEcho;
    final maxWidth = is58mm ? 320.0 : 400.0;
    final headerAlign = data.headerAlignment == ReceiptHeaderAlignment.center
        ? TextAlign.center
        : TextAlign.left;
    final headerCross = data.headerAlignment == ReceiptHeaderAlignment.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    final dividerText = data.dividerLine;
    final qrValue = data.effectiveQrData;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          key: Key('unified_thermal_receipt_paper_${data.paperWidthMm}mm'),
          decoration: BoxDecoration(
            color: _paperBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _paperBorder, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Optional Paper Roll Top Edge Header
              if (paperEdgeLabel != null && paperEdgeLabel!.trim().isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(9)),
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (paperEdgeIcon != null) ...[
                        Icon(
                          paperEdgeIcon,
                          size: 12,
                          color: paperEdgeIconColor ?? _inkSecondary,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          paperEdgeLabel!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: _inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: isCompact ? 10 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. Store & Branch Header
                    Column(
                      crossAxisAlignment: headerCross,
                      children: [
                        Text(
                          data.storeName,
                          textAlign: headerAlign,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: isCompact ? 12.5 : 14.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: isCompact ? 0.2 : 0.6,
                            color: _inkPrimary,
                          ),
                        ),
                        if (data.storeTagline.trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(
                              data.storeTagline.trim(),
                              textAlign: headerAlign,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: _inkSecondary,
                              ),
                            ),
                          ),
                        if (isCompact) ...[
                          Text(
                            data.storePhone.trim().isNotEmpty
                                ? '${data.branchName} • ${data.storePhone.trim()}'
                                : data.branchName,
                            textAlign: headerAlign,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10.5,
                              color: _inkSecondary,
                            ),
                          ),
                          if (data.storeAddress.trim().isNotEmpty)
                            Text(
                              data.storeAddress.trim(),
                              textAlign: headerAlign,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: _inkSecondary,
                              ),
                            ),
                        ] else ...[
                          if (data.branchName.trim().isNotEmpty)
                            Text(
                              data.branchName.trim(),
                              textAlign: headerAlign,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: _inkPrimary,
                              ),
                            ),
                          if (data.storeAddress.trim().isNotEmpty)
                            Text(
                              data.storeAddress.trim(),
                              textAlign: headerAlign,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: _inkSecondary,
                              ),
                            ),
                          if (data.storePhone.trim().isNotEmpty)
                            Text(
                              'Telp: ${data.storePhone.trim()}',
                              textAlign: headerAlign,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 10,
                                color: _inkSecondary,
                              ),
                            ),
                        ],
                      ],
                    ),

                    _buildDivider(dividerText, isCompact),

                    // 2. Subtle [CETAK ULANG] Badge + Title
                    if (data.isReprint) ...[
                      Center(
                        child: Container(
                          key: const Key('unified_receipt_reprint_badge'),
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _reprintBg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: _reprintBorder, width: 1),
                          ),
                          child: const Text(
                            ThermalReceiptEscPosBuilder.reprintTag,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: _inkPrimary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    Text(
                      data.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: isCompact ? 10.5 : 11.5,
                        fontWeight: FontWeight.w800,
                        color: _inkPrimary,
                      ),
                    ),

                    _buildDivider(dividerText, isCompact),

                    // 3. Transaction Metadata
                    _buildKeyValueRow('No. Struk', data.transactionCode, isCompact: isCompact),
                    if (data.bookingCode != null &&
                        data.bookingCode!.trim().isNotEmpty &&
                        data.bookingCode!.trim() != data.transactionCode.trim())
                      _buildKeyValueRow('No. Booking', data.bookingCode!.trim(), isCompact: isCompact),
                    if (data.printedAt.trim().isNotEmpty)
                      _buildKeyValueRow('Waktu', data.printedAt.trim(), isCompact: isCompact),
                    if (data.showCashierName && data.cashierName.trim().isNotEmpty)
                      _buildKeyValueRow('Kasir', data.cashierName.trim(), isCompact: isCompact),
                    if (data.customerName.trim().isNotEmpty)
                      _buildKeyValueRow('Pelanggan', data.customerName.trim(), isCompact: isCompact),
                    if (data.showCustomerPhone && data.formattedCustomerPhone.isNotEmpty)
                      _buildKeyValueRow('No. Telp', data.formattedCustomerPhone, isCompact: isCompact),
                    if (data.rentalPeriodLabel.trim().isNotEmpty)
                      _buildKeyValueRow('Periode', data.rentalPeriodLabel.trim(), isCompact: isCompact),
                    if (data.showCollateralInfo &&
                        data.collateralSummary != null &&
                        data.collateralSummary!.trim().isNotEmpty)
                      _buildKeyValueRow('Jaminan', data.collateralSummary!.trim(), isCompact: isCompact),

                    _buildDivider(dividerText, isCompact),

                    // 4. Line Items
                    if (data.items.isNotEmpty) ...[
                      for (final item in data.items) ...[
                        _buildKeyValueRow(
                          item.displayName,
                          formatReceiptCurrency(item.totalPrice),
                          isCompact: isCompact,
                          isBold: !item.isAddon,
                        ),
                        if (item.detailSubtitle != null)
                          Padding(
                            padding: EdgeInsets.only(
                              left: 6,
                              bottom: isCompact ? 1.5 : 2.5,
                            ),
                            child: Text(
                              item.detailSubtitle!,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                fontSize: isCompact ? 9.0 : 9.5,
                                color: _inkSecondary,
                              ),
                            ),
                          ),
                      ],
                      _buildDivider(dividerText, isCompact),
                    ],

                    // 5. Financial & Payment Summary
                    if (data.subtotal > 0 &&
                        (data.discount > 0 ||
                            data.penaltyAmount > 0 ||
                            data.items.length > 1))
                      _buildKeyValueRow(
                        'Subtotal',
                        formatReceiptCurrency(data.subtotal),
                        isCompact: isCompact,
                      ),
                    if (data.discount > 0)
                      _buildKeyValueRow(
                        'Diskon',
                        '-${formatReceiptCurrency(data.discount)}',
                        isCompact: isCompact,
                      ),
                    if (data.showPenaltyDetails &&
                        (data.penaltyAmount > 0 || data.waivedLateFee > 0)) ...[
                      _buildKeyValueRow(
                        'Denda Telat',
                        formatReceiptCurrency(
                          data.calculatedLateFee > 0
                              ? data.calculatedLateFee
                              : data.penaltyAmount,
                        ),
                        isCompact: isCompact,
                      ),
                      if (data.waivedLateFee > 0) ...[
                        _buildKeyValueRow(
                          'Keringanan Denda',
                          '-${formatReceiptCurrency(data.waivedLateFee)}',
                          isCompact: isCompact,
                        ),
                        if (data.lateFeeWaiverReason != null &&
                            data.lateFeeWaiverReason!.trim().isNotEmpty)
                          _buildKeyValueRow(
                            'Alasan',
                            data.lateFeeWaiverReason!.trim(),
                            isCompact: isCompact,
                          ),
                      ],
                    ],
                    _buildKeyValueRow(
                      'TOTAL',
                      formatReceiptCurrency(data.totalAmount),
                      isCompact: isCompact,
                      isBold: true,
                    ),
                    _buildKeyValueRow(
                      'Metode',
                      data.paymentMethodLabel,
                      isCompact: isCompact,
                    ),
                    if (data.showChangeDue && data.paidAmount > 0) ...[
                      _buildKeyValueRow(
                        'Dibayar',
                        formatReceiptCurrency(data.paidAmount),
                        isCompact: isCompact,
                      ),
                      if (data.changeAmount > 0 ||
                          data.paymentMethodLabel.toLowerCase() == 'tunai')
                        _buildKeyValueRow(
                          'Kembalian',
                          formatReceiptCurrency(data.changeAmount),
                          isCompact: isCompact,
                        ),
                    ],
                    Padding(
                      padding: EdgeInsets.only(top: isCompact ? 2 : 3),
                      child: Text(
                        data.isPartialOrDownPayment
                            ? 'STATUS: DP (BELUM LUNAS)'
                            : 'STATUS: LUNAS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: isCompact ? 10.0 : 10.5,
                          fontWeight: FontWeight.w800,
                          color: _inkPrimary,
                        ),
                      ),
                    ),
                    if (data.isPartialOrDownPayment && data.remainingBalance > 0)
                      _buildKeyValueRow(
                        'Sisa Tagihan',
                        formatReceiptCurrency(data.remainingBalance),
                        isCompact: isCompact,
                      ),

                    _buildDivider(dividerText, isCompact),

                    // 6. Optional QR Code
                    if (data.showQrBarcode && qrValue != null) ...[
                      SizedBox(height: isCompact ? 4 : 6),
                      Center(
                        child: QrImageView(
                          data: qrValue,
                          version: QrVersions.auto,
                          size: is58mm
                              ? (isCompact ? 64.0 : 80.0)
                              : (isCompact ? 80.0 : 96.0),
                          padding: const EdgeInsets.all(2),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Center(
                        child: Text(
                          qrValue,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: _inkPrimary,
                          ),
                        ),
                      ),
                      SizedBox(height: isCompact ? 4 : 6),
                    ],

                    // 7. Return Terms & Footer Note
                    if (data.showReturnTerms &&
                        data.returnTermsText.trim().isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(bottom: isCompact ? 3 : 5),
                        child: Text(
                          data.returnTermsText.trim(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 9.5,
                            color: _inkSecondary,
                          ),
                        ),
                      ),
                    if (data.footerNote.trim().isNotEmpty)
                      Text(
                        data.footerNote.trim(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _inkPrimary,
                        ),
                      ),

                    _buildDivider(dividerText, isCompact),
                  ],
                ),
              ),

              if (showBottomTearEdge)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(9)),
                  ),
                  child: Center(
                    child: Text(
                      is58mm
                          ? '· · · · · · · · · · · · · · · ·'
                          : '· · · · · · · · · · · · · · · · · · · · · · · ·',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 8,
                        color: _dividerColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(String dividerText, bool isCompact) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 3.0 : 4.5),
      child: Text(
        dividerText,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10,
          color: _dividerColor,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(
    String left,
    String right, {
    bool isCompact = false,
    bool isBold = false,
  }) {
    final textStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: isCompact ? 10.0 : 10.5,
      fontWeight: isBold ? FontWeight.w800 : FontWeight.w400,
      color: _inkPrimary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: isCompact ? 1.0 : 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: 5,
            child: Text(left, style: textStyle),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 6,
            child: Text(
              right,
              textAlign: TextAlign.right,
              style: textStyle,
            ),
          ),
        ],
      ),
    );
  }
}

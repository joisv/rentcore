import '../../features/auth/providers/business_provider.dart';
import '../../features/payments/models/payment_context.dart';
import '../utils/collateral_helper.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';
import 'thermal_printer_models.dart';

/// A single line item rendered on both thermal receipt previews and ESC/POS prints.
class ReceiptDocumentItem {
  final String name;
  final String? variantOrCode;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final bool isAddon;
  final String? durationLabel;

  const ReceiptDocumentItem({
    required this.name,
    this.variantOrCode,
    this.quantity = 1,
    required this.unitPrice,
    double? totalPrice,
    this.isAddon = false,
    this.durationLabel,
  }) : totalPrice = totalPrice ?? (unitPrice * quantity);

  String get displayName => isAddon ? '$name (Add-on)' : name;

  String? get detailSubtitle {
    final parts = <String>[];
    if (variantOrCode != null && variantOrCode!.trim().isNotEmpty) {
      parts.add(variantOrCode!.trim());
    }
    if (durationLabel != null && durationLabel!.trim().isNotEmpty) {
      parts.add(durationLabel!.trim());
    }
    if (quantity > 1) {
      parts.add('${quantity}x ${formatReceiptCurrency(unitPrice)}');
    }
    return parts.isEmpty ? null : parts.join(' - ');
  }
}

/// Formats a numeric amount into Indonesian Rupiah without decimals (e.g. `Rp 300.000`).
String formatReceiptCurrency(num amount) {
  final negative = amount < 0;
  final s = amount.abs().round().toString();
  final buffer = StringBuffer();
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    buffer.write(s[i]);
    count++;
    if (count % 3 == 0 && i > 0) {
      buffer.write('.');
    }
  }
  final formatted = buffer.toString().split('').reversed.join('');
  return negative ? '-Rp $formatted' : 'Rp $formatted';
}

/// Masks a phone number for customer privacy when enabled in printer settings.
String maskReceiptPhone(String phone) {
  final clean = phone.trim();
  if (clean.length <= 6) return clean;
  return '${clean.substring(0, 4)}****${clean.substring(clean.length - 4)}';
}

/// Single Source of Truth data model shared by:
/// - `UnifiedThermalReceiptPreview` (Printer Settings, Receipt Designer,
///   Dashboard Queue Preview, Checkout Preview, Transaction Detail Reprint)
/// - `ThermalReceiptEscPosBuilder` & `ThermalPrinterService.printReceipt`
class ReceiptDocumentData {
  // Store & Branch Header
  final String storeName;
  final String storeTagline;
  final String storeAddress;
  final String storePhone;
  final String branchName;

  // Transaction Metadata
  final String title;
  final String transactionCode;
  final String? bookingCode;
  final String printedAt;
  final String cashierName;
  final String customerName;
  final String customerPhone;
  final String rentalPeriodLabel;
  final bool isReprint;

  // Line Items
  final List<ReceiptDocumentItem> items;

  // Financial & Payment Summary
  final double subtotal;
  final double discount;
  final double penaltyAmount;
  final double calculatedLateFee;
  final double waivedLateFee;
  final String? lateFeeWaiverReason;
  final String? collateralSummary;
  final double totalAmount;
  final double paidAmount;
  final double changeAmount;
  final double remainingBalance;
  final bool isDownPayment;
  final String paymentMethodLabel;

  // Printer Layout & Formatting Settings
  final int paperWidthMm;
  final String footerNote;
  final String returnTermsText;
  final String? qrData;
  final ReceiptHeaderAlignment headerAlignment;
  final String separatorStyle;
  final PrintMode printMode;
  final bool showCashierName;
  final bool showCustomerPhone;
  final bool maskCustomerPhone;
  final bool showCollateralInfo;
  final bool showReturnTerms;
  final bool showQrBarcode;
  final bool showChangeDue;
  final bool showPenaltyDetails;
  final int extraFeedLines;
  final bool useRasterQr;

  const ReceiptDocumentData({
    required this.storeName,
    this.storeTagline = '',
    this.storeAddress = '',
    this.storePhone = '',
    required this.branchName,
    this.title = 'STRUK SEWA PERANGKAT',
    required this.transactionCode,
    this.bookingCode,
    required this.printedAt,
    required this.cashierName,
    required this.customerName,
    this.customerPhone = '',
    this.rentalPeriodLabel = '',
    this.isReprint = false,
    required this.items,
    required this.subtotal,
    this.discount = 0.0,
    this.penaltyAmount = 0.0,
    this.calculatedLateFee = 0.0,
    this.waivedLateFee = 0.0,
    this.lateFeeWaiverReason,
    this.collateralSummary,
    required this.totalAmount,
    required this.paidAmount,
    this.changeAmount = 0.0,
    this.remainingBalance = 0.0,
    this.isDownPayment = false,
    required this.paymentMethodLabel,
    this.paperWidthMm = 58,
    this.footerNote = '*** TERIMA KASIH ***\nSimpan struk ini sebagai bukti resmi',
    this.returnTermsText =
        'Harap mengembalikan unit tepat waktu sesuai jadwal sewa. Keterlambatan dikenakan denda resmi.',
    this.qrData,
    this.headerAlignment = ReceiptHeaderAlignment.center,
    this.separatorStyle = 'dash',
    this.printMode = PrintMode.normal,
    this.showCashierName = true,
    this.showCustomerPhone = true,
    this.maskCustomerPhone = true,
    this.showCollateralInfo = true,
    this.showReturnTerms = true,
    this.showQrBarcode = true,
    this.showChangeDue = true,
    this.showPenaltyDetails = true,
    this.extraFeedLines = 3,
    this.useRasterQr = false,
  });

  /// Character column width matching physical thermal paper (`58mm` = 32, `80mm` = 48).
  int get columns => paperWidthMm >= 80 ? 48 : 32;

  ReceiptPaperWidth get paperWidth =>
      paperWidthMm >= 80 ? ReceiptPaperWidth.mm80 : ReceiptPaperWidth.mm58;

  bool get isCompactEcho => printMode == PrintMode.echo;

  String get dividerLine {
    final char = isCompactEcho ? '-' : (separatorStyle == 'double' ? '=' : '-');
    return char * columns;
  }

  String get formattedCustomerPhone {
    if (customerPhone.trim().isEmpty) return '';
    return maskCustomerPhone
        ? maskReceiptPhone(customerPhone)
        : customerPhone.trim();
  }

  bool get isPartialOrDownPayment => isDownPayment || remainingBalance > 0;

  String? get effectiveQrData {
    final candidate = qrData?.trim();
    if (candidate != null && candidate.isNotEmpty) return candidate;
    final bCode = bookingCode?.trim();
    if (bCode != null && bCode.isNotEmpty) return bCode;
    final txCode = transactionCode.trim();
    if (txCode.isNotEmpty && txCode != '-') return txCode;
    return null;
  }

  ReceiptDocumentData copyWith({
    String? storeName,
    String? storeTagline,
    String? storeAddress,
    String? storePhone,
    String? branchName,
    String? title,
    String? transactionCode,
    String? bookingCode,
    String? printedAt,
    String? cashierName,
    String? customerName,
    String? customerPhone,
    String? rentalPeriodLabel,
    bool? isReprint,
    List<ReceiptDocumentItem>? items,
    double? subtotal,
    double? discount,
    double? penaltyAmount,
    double? calculatedLateFee,
    double? waivedLateFee,
    String? lateFeeWaiverReason,
    String? collateralSummary,
    double? totalAmount,
    double? paidAmount,
    double? changeAmount,
    double? remainingBalance,
    bool? isDownPayment,
    String? paymentMethodLabel,
    int? paperWidthMm,
    String? footerNote,
    String? returnTermsText,
    String? qrData,
    ReceiptHeaderAlignment? headerAlignment,
    String? separatorStyle,
    PrintMode? printMode,
    bool? showCashierName,
    bool? showCustomerPhone,
    bool? maskCustomerPhone,
    bool? showCollateralInfo,
    bool? showReturnTerms,
    bool? showQrBarcode,
    bool? showChangeDue,
    bool? showPenaltyDetails,
    int? extraFeedLines,
    bool? useRasterQr,
  }) {
    return ReceiptDocumentData(
      storeName: storeName ?? this.storeName,
      storeTagline: storeTagline ?? this.storeTagline,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      branchName: branchName ?? this.branchName,
      title: title ?? this.title,
      transactionCode: transactionCode ?? this.transactionCode,
      bookingCode: bookingCode ?? this.bookingCode,
      printedAt: printedAt ?? this.printedAt,
      cashierName: cashierName ?? this.cashierName,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      rentalPeriodLabel: rentalPeriodLabel ?? this.rentalPeriodLabel,
      isReprint: isReprint ?? this.isReprint,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      discount: discount ?? this.discount,
      penaltyAmount: penaltyAmount ?? this.penaltyAmount,
      calculatedLateFee: calculatedLateFee ?? this.calculatedLateFee,
      waivedLateFee: waivedLateFee ?? this.waivedLateFee,
      lateFeeWaiverReason: lateFeeWaiverReason ?? this.lateFeeWaiverReason,
      collateralSummary: collateralSummary ?? this.collateralSummary,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      changeAmount: changeAmount ?? this.changeAmount,
      remainingBalance: remainingBalance ?? this.remainingBalance,
      isDownPayment: isDownPayment ?? this.isDownPayment,
      paymentMethodLabel: paymentMethodLabel ?? this.paymentMethodLabel,
      paperWidthMm: paperWidthMm ?? this.paperWidthMm,
      footerNote: footerNote ?? this.footerNote,
      returnTermsText: returnTermsText ?? this.returnTermsText,
      qrData: qrData ?? this.qrData,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      separatorStyle: separatorStyle ?? this.separatorStyle,
      printMode: printMode ?? this.printMode,
      showCashierName: showCashierName ?? this.showCashierName,
      showCustomerPhone: showCustomerPhone ?? this.showCustomerPhone,
      maskCustomerPhone: maskCustomerPhone ?? this.maskCustomerPhone,
      showCollateralInfo: showCollateralInfo ?? this.showCollateralInfo,
      showReturnTerms: showReturnTerms ?? this.showReturnTerms,
      showQrBarcode: showQrBarcode ?? this.showQrBarcode,
      showChangeDue: showChangeDue ?? this.showChangeDue,
      showPenaltyDetails: showPenaltyDetails ?? this.showPenaltyDetails,
      extraFeedLines: extraFeedLines ?? this.extraFeedLines,
      useRasterQr: useRasterQr ?? this.useRasterQr,
    );
  }

  /// Applies updated [ReceiptCustomizationSettings] (and optional live [BusinessState])
  /// without rebuilding transaction fields.
  ReceiptDocumentData applySettings(
    ReceiptCustomizationSettings settings, {
    BusinessState? business,
    PrintMode? modeOverride,
  }) {
    final resolvedStore = _firstNonEmpty([
      settings.customShopName,
      storeName,
      business?.resolvedStoreName,
    ], 'Toko Rental');
    final resolvedBranch = _firstNonEmpty([
      settings.customBranchName,
      branchName,
      business?.resolvedBranchName,
    ], 'Cabang Utama');
    final resolvedAddress = _firstNonEmpty([
      settings.storeAddress,
      storeAddress,
      business?.resolvedBranchAddress,
    ], '');
    final resolvedPhone = _firstNonEmpty([
      settings.storePhone,
      storePhone,
      business?.resolvedBranchPhone,
    ], '');

    return copyWith(
      storeName: resolvedStore,
      storeTagline: settings.customSlogan.trim(),
      storeAddress: resolvedAddress,
      storePhone: resolvedPhone,
      branchName: resolvedBranch,
      paperWidthMm: settings.paperWidth == ReceiptPaperWidth.mm80 ? 80 : 58,
      footerNote: settings.customFooterMessage.trim(),
      returnTermsText: settings.returnTermsText.trim(),
      headerAlignment: settings.headerAlignment,
      separatorStyle: settings.separatorStyle,
      printMode: modeOverride ?? settings.printMode,
      showCashierName: settings.showCashierName,
      showCustomerPhone: settings.showCustomerPhone,
      maskCustomerPhone: settings.maskCustomerPhone,
      showCollateralInfo: settings.showCollateralInfo,
      showReturnTerms: settings.showReturnTerms,
      showQrBarcode: settings.showQrBarcode,
      showChangeDue: settings.showChangeDue,
      showPenaltyDetails: settings.showPenaltyDetails,
      extraFeedLines: settings.extraFeedLines,
      useRasterQr: settings.useRasterQr,
    );
  }

  /// Normalizes backend or POS payment method names/codes to clear Indonesian labels:
  /// `QRIS`, `Tunai`, `Transfer Bank`, or specific E-Wallets (`GoPay`, `OVO`, `DANA`, etc.).
  static String normalizePaymentMethodLabel(
    String? rawMethod, {
    String? code,
  }) {
    final raw = (rawMethod ?? '').trim();
    final rawCode = (code ?? '').trim();
    final combined = '${raw.toLowerCase()} ${rawCode.toLowerCase()}'.trim();

    if (combined.isEmpty) return 'Tunai';

    if (combined.contains('qris')) return 'QRIS';
    if (combined.contains('gopay') || combined.contains('go-pay')) {
      return 'GoPay';
    }
    if (RegExp(r'\bovo\b').hasMatch(combined)) return 'OVO';
    if (RegExp(r'\bdana\b').hasMatch(combined)) return 'DANA';
    if (combined.contains('shopeepay') || combined.contains('shopee pay')) {
      return 'ShopeePay';
    }
    if (combined.contains('linkaja') || combined.contains('link aja')) {
      return 'LinkAja';
    }
    if (combined.contains('e_wallet') ||
        combined.contains('e-wallet') ||
        combined.contains('ewallet')) {
      if (raw.isNotEmpty &&
          raw.toLowerCase() != 'ewallet' &&
          raw.toLowerCase() != 'e_wallet') {
        return raw;
      }
      return 'E-Wallet';
    }
    if (combined.contains('transfer') || combined.contains('bank')) {
      if (raw.isNotEmpty &&
          raw.toLowerCase() != 'transfer' &&
          raw.toLowerCase() != 'bank_transfer' &&
          raw.toLowerCase() != 'transfer_bank') {
        return raw;
      }
      return 'Transfer Bank';
    }
    if (combined.contains('cash') || combined.contains('tunai')) {
      return 'Tunai';
    }

    return raw.isNotEmpty ? raw : rawCode.toUpperCase();
  }

  /// Sample receipt constructor for **Pengaturan Printer** & **Desain Struk**.
  factory ReceiptDocumentData.sample(
    BusinessState business, {
    ReceiptCustomizationSettings? settings,
    PrintMode? modeOverride,
    bool isReprint = false,
  }) {
    final s = settings ?? const ReceiptCustomizationSettings();
    final storeName = _firstNonEmpty(
      [s.customShopName, business.resolvedStoreName],
      'Toko Rental',
    );
    final branchName = _firstNonEmpty(
      [s.customBranchName, business.resolvedBranchName],
      'Cabang Utama',
    );
    final address = _firstNonEmpty(
      [s.storeAddress, business.resolvedBranchAddress],
      '',
    );
    final phone = _firstNonEmpty(
      [s.storePhone, business.resolvedBranchPhone],
      '',
    );

    return ReceiptDocumentData(
      storeName: storeName,
      storeTagline: s.customSlogan.trim(),
      storeAddress: address,
      storePhone: phone,
      branchName: branchName,
      title: 'STRUK SEWA PERANGKAT',
      transactionCode: 'RC-202610-0042',
      bookingCode: 'RC-202610-0042',
      printedAt: '17 Okt 2026, 14:00',
      cashierName: 'Budi Santoso',
      customerName: 'Dewi Lestari',
      customerPhone: '081234568890',
      rentalPeriodLabel: '24 Jam • s/d 18 Okt 2026, 14:00',
      isReprint: isReprint,
      items: const [
        ReceiptDocumentItem(
          name: 'iPhone 15 Pro Max 256GB Natural',
          variantOrCode: 'IMEI358999001122',
          quantity: 1,
          unitPrice: 325000,
          totalPrice: 325000,
          isAddon: false,
          durationLabel: '24 Jam',
        ),
        ReceiptDocumentItem(
          name: 'Powerbank MagSafe 10.000mAh',
          variantOrCode: 'ACC-PB-04',
          quantity: 1,
          unitPrice: 25000,
          totalPrice: 25000,
          isAddon: true,
        ),
      ],
      subtotal: 350000,
      discount: 50000,
      collateralSummary: 'KTP Fisik - Slot B2',
      totalAmount: 300000,
      paidAmount: 400000,
      changeAmount: 100000,
      paymentMethodLabel: 'Tunai',
      paperWidthMm: s.paperWidth == ReceiptPaperWidth.mm80 ? 80 : 58,
      footerNote: s.customFooterMessage.trim(),
      returnTermsText: s.returnTermsText.trim(),
      qrData: 'RC-202610-0042',
      headerAlignment: s.headerAlignment,
      separatorStyle: s.separatorStyle,
      printMode: modeOverride ?? s.printMode,
      showCashierName: s.showCashierName,
      showCustomerPhone: s.showCustomerPhone,
      maskCustomerPhone: s.maskCustomerPhone,
      showCollateralInfo: s.showCollateralInfo,
      showReturnTerms: s.showReturnTerms,
      showQrBarcode: s.showQrBarcode,
      showChangeDue: s.showChangeDue,
      showPenaltyDetails: s.showPenaltyDetails,
      extraFeedLines: s.extraFeedLines,
      useRasterQr: s.useRasterQr,
    );
  }

  /// Unified constructor for **Dashboard Queue Preview / Reprint**, **POS Checkout**,
  /// and **Transaction Detail Reprint**.
  factory ReceiptDocumentData.fromTransaction({
    required BusinessState business,
    Map<String, dynamic>? booking,
    Map<String, dynamic>? receiptData,
    PaymentContext? paymentContext,
    PaymentResult? paymentResult,
    ReceiptCustomizationSettings? settings,
    String? fallbackCashierName,
    String? title,
    bool isReprint = false,
  }) {
    final s = settings ?? const ReceiptCustomizationSettings();
    final b = booking ?? const <String, dynamic>{};
    final r = receiptData ?? const <String, dynamic>{};
    final affiliate = b['affiliate'] is Map
        ? Map<String, dynamic>.from(b['affiliate'] as Map)
        : const <String, dynamic>{};
    final customer = b['customer'] is Map
        ? Map<String, dynamic>.from(b['customer'] as Map)
        : const <String, dynamic>{};
    final extra = paymentContext?.extraPayload ?? const <String, dynamic>{};

    // 1. Store & Branch Header
    final storeName = _firstNonEmpty([
      s.customShopName,
      r['business_name']?.toString(),
      business.resolvedStoreName,
    ], 'Toko Rental');
    final branchName = _firstNonEmpty([
      s.customBranchName,
      r['outlet_name']?.toString(),
      affiliate['name']?.toString(),
      paymentContext?.branchName,
      business.resolvedBranchName,
    ], 'Cabang Utama');
    final storeAddress = _firstNonEmpty([
      s.storeAddress,
      r['outlet_address']?.toString(),
      affiliate['address']?.toString(),
      business.resolvedBranchAddress,
    ], '');
    final storePhone = _firstNonEmpty([
      s.storePhone,
      r['outlet_phone']?.toString(),
      affiliate['whatsapp']?.toString(),
      affiliate['phone']?.toString(),
      business.resolvedBranchPhone,
    ], '');

    // 2. Metadata
    final resolvedBookingCode = _firstNonEmpty([
      r['booking_code']?.toString(),
      b['booking_code']?.toString(),
      paymentContext?.bookingCode,
      paymentResult?.responseData?['booking_code']?.toString(),
    ], '');
    final transactionCode = _firstNonEmpty([
      r['receipt_number']?.toString(),
      r['transaction_code']?.toString(),
      paymentResult?.receiptNumber,
      paymentResult?.transactionCode,
      resolvedBookingCode,
    ], '-');
    final printedAtRaw = _firstNonEmpty([
      r['transacted_at']?.toString(),
      b['created_at']?.toString(),
    ], '');
    final printedAt = printedAtRaw.isNotEmpty
        ? _formatTimestamp(printedAtRaw)
        : DateFormatter.formatFull(DateTime.now());
    final cashierName = _firstNonEmpty([
      r['cashier_name']?.toString(),
      fallbackCashierName,
    ], 'Kasir');
    final customerName = _firstNonEmpty([
      r['customer_name']?.toString(),
      customer['name']?.toString(),
      paymentContext?.customerName,
    ], 'Pelanggan');
    final customerPhone = _firstNonEmpty([
      r['customer_phone']?.toString(),
      customer['phone']?.toString(),
      paymentContext?.customerPhone,
    ], '');

    // 3. Rental Period Label
    final rentalPeriodLabel = _resolveRentalPeriodLabel(
      booking: b,
      receiptData: r,
      paymentContext: paymentContext,
    );

    // 4. Line Items
    final parsedItems = _parseItems(
      paymentContext: paymentContext,
      receiptData: r,
      booking: b,
    );

    // 5. Collateral Summary
    final collateralSummary = _resolveCollateralSummary(
      booking: b,
      receiptData: r,
      extraPayload: extra,
    );

    // 6. Financials & Payment Method
    final itemsSum = parsedItems.fold<double>(
      0.0,
      (sum, item) => sum + item.totalPrice,
    );
    final rawTotal = paymentResult != null
        ? paymentResult.amountPaid
        : CurrencyFormatter.parse(
            r['total_amount'] ?? b['total_bill'] ?? paymentContext?.remainingDue ?? itemsSum,
          );
    final rawDiscount = CurrencyFormatter.parse(
      r['discount_amount'] ??
          b['discount_amount'] ??
          paymentContext?.discountAmount ??
          0,
    );
    final returnInspection = b['return_inspection'] is Map
        ? Map<String, dynamic>.from(b['return_inspection'] as Map)
        : (b['returnInspection'] is Map
            ? Map<String, dynamic>.from(b['returnInspection'] as Map)
            : const <String, dynamic>{});
    final rawPenalty = CurrencyFormatter.parse(
      r['penalty_amount'] ??
          returnInspection['final_late_fee'] ??
          returnInspection['late_fee'] ??
          b['penalty_amount'] ??
          b['late_fee'] ??
          0,
    );
    final rawCalculatedLateFee = CurrencyFormatter.parse(
      r['calculated_late_fee'] ??
          returnInspection['calculated_late_fee'] ??
          rawPenalty,
    );
    final rawWaivedLateFee = CurrencyFormatter.parse(
      r['waived_late_fee'] ?? returnInspection['waived_late_fee'] ?? 0,
    );
    final rawWaiverReason = _firstNonEmpty([
      r['late_fee_waiver_reason']?.toString(),
      r['late_fee_waive_reason']?.toString(),
      returnInspection['late_fee_waiver_reason']?.toString(),
      returnInspection['late_fee_waive_reason']?.toString(),
    ], '');
    final explicitSubtotal = CurrencyFormatter.parse(
      r['subtotal'] ??
          b['subtotal_amount'] ??
          ((paymentContext?.primarySubtotal != null ||
                  paymentContext?.addonSubtotal != null)
              ? ((paymentContext?.primarySubtotal ?? 0) +
                  (paymentContext?.addonSubtotal ?? 0))
              : 0),
    );
    final resolvedSubtotal = explicitSubtotal > 0
        ? explicitSubtotal
        : (itemsSum > 0 ? itemsSum : rawTotal + rawDiscount);

    final rawPaid = paymentResult != null && paymentResult.cashReceived > 0
        ? paymentResult.cashReceived
        : CurrencyFormatter.parse(
            r['cash_received'] ??
                r['paid_amount'] ??
                (paymentResult != null ? paymentResult.amountPaid : rawTotal),
          );
    final rawChange = paymentResult != null
        ? paymentResult.cashChange
        : CurrencyFormatter.parse(r['cash_change'] ?? 0);

    final rawMethodName = _firstNonEmpty([
      r['payment_method']?.toString(),
      paymentResult?.paymentMethodName,
      _latestPaymentMethodFromBooking(b),
    ], 'Tunai');
    final methodLabel = normalizePaymentMethodLabel(
      rawMethodName,
      code: paymentResult?.paymentMethodCode,
    );

    final isDownPayment =
        paymentContext?.isDownPayment == true ||
        r['type']?.toString().toLowerCase() == 'dp';
    final remainingBalance = paymentContext != null
        ? paymentContext.remainingAfterCurrentPayment
        : CurrencyFormatter.parse(r['remaining_balance'] ?? 0);

    final resolvedTitle = _firstNonEmpty([
      title,
      if (paymentContext != null)
        _titleForPaymentType(paymentContext.transactionType),
      if (r['type']?.toString().toLowerCase() == 'penalty')
        'STRUK PEMBAYARAN DENDA',
      if (r['type']?.toString().toLowerCase() == 'extension')
        'STRUK PERPANJANGAN SEWA',
    ], 'STRUK TRANSAKSI SEWA');

    return ReceiptDocumentData(
      storeName: storeName,
      storeTagline: s.customSlogan.trim(),
      storeAddress: storeAddress,
      storePhone: storePhone,
      branchName: branchName,
      title: resolvedTitle,
      transactionCode: transactionCode,
      bookingCode: resolvedBookingCode.isNotEmpty ? resolvedBookingCode : null,
      printedAt: printedAt,
      cashierName: cashierName,
      customerName: customerName,
      customerPhone: customerPhone,
      rentalPeriodLabel: rentalPeriodLabel,
      isReprint: isReprint,
      items: parsedItems,
      subtotal: resolvedSubtotal,
      discount: rawDiscount,
      penaltyAmount: rawPenalty,
      calculatedLateFee: rawCalculatedLateFee,
      waivedLateFee: rawWaivedLateFee,
      lateFeeWaiverReason: rawWaiverReason.isNotEmpty ? rawWaiverReason : null,
      collateralSummary: collateralSummary,
      totalAmount: rawTotal,
      paidAmount: rawPaid > 0 ? rawPaid : rawTotal,
      changeAmount: rawChange > 0 ? rawChange : 0.0,
      remainingBalance: remainingBalance > 0 ? remainingBalance : 0.0,
      isDownPayment: isDownPayment,
      paymentMethodLabel: methodLabel,
      paperWidthMm: s.paperWidth == ReceiptPaperWidth.mm80 ? 80 : 58,
      footerNote: s.customFooterMessage.trim(),
      returnTermsText: s.returnTermsText.trim(),
      qrData: resolvedBookingCode.isNotEmpty
          ? resolvedBookingCode
          : (transactionCode != '-' ? transactionCode : null),
      headerAlignment: s.headerAlignment,
      separatorStyle: s.separatorStyle,
      printMode: s.printMode,
      showCashierName: s.showCashierName,
      showCustomerPhone: s.showCustomerPhone,
      maskCustomerPhone: s.maskCustomerPhone,
      showCollateralInfo: s.showCollateralInfo,
      showReturnTerms: s.showReturnTerms,
      showQrBarcode: s.showQrBarcode,
      showChangeDue: s.showChangeDue,
      showPenaltyDetails: s.showPenaltyDetails,
      extraFeedLines: s.extraFeedLines,
      useRasterQr: s.useRasterQr,
    );
  }

  /// Bridges a legacy [ReceiptDataModel] into [ReceiptDocumentData].
  factory ReceiptDocumentData.fromLegacyModel(
    ReceiptDataModel model, {
    ReceiptCustomizationSettings? settings,
    BusinessState? business,
  }) {
    final s = settings ?? const ReceiptCustomizationSettings();
    final items = <ReceiptDocumentItem>[];
    if (model.items != null && model.items!.isNotEmpty) {
      for (final raw in model.items!) {
        final name = raw['name']?.toString() ?? 'Item';
        final price = CurrencyFormatter.parse(raw['price'] ?? raw['unit_price']);
        final qty = (raw['quantity'] as num?)?.toInt() ??
            (raw['qty'] as num?)?.toInt() ??
            1;
        items.add(
          ReceiptDocumentItem(
            name: name.replaceAll(' (Add-on)', ''),
            variantOrCode: raw['asset_code']?.toString(),
            quantity: qty,
            unitPrice: qty > 0 ? price / qty : price,
            totalPrice: price,
            isAddon: raw['is_addon'] == true || name.contains('(Add-on)'),
            durationLabel: raw['duration']?.toString(),
          ),
        );
      }
    } else if (model.unitName != null && model.unitName!.trim().isNotEmpty) {
      items.add(
        ReceiptDocumentItem(
          name: model.unitName!.trim(),
          variantOrCode: model.unitSerial,
          quantity: 1,
          unitPrice: model.subtotal ?? model.totalAmount,
          totalPrice: model.subtotal ?? model.totalAmount,
          durationLabel: model.rentalDurationText,
        ),
      );
    }

    final periodParts = <String>[];
    if (model.rentalDurationText != null &&
        model.rentalDurationText!.trim().isNotEmpty) {
      periodParts.add(model.rentalDurationText!.trim());
    }
    if (model.rentalEndDate != null && model.rentalEndDate!.trim().isNotEmpty) {
      periodParts.add('s/d ${model.rentalEndDate!.trim()}');
    }

    return ReceiptDocumentData(
      storeName: _firstNonEmpty(
        [s.customShopName, model.shopName, business?.resolvedStoreName],
        'Toko Rental',
      ),
      storeTagline: s.customSlogan.trim(),
      storeAddress: _firstNonEmpty(
        [s.storeAddress, model.branchAddress, business?.resolvedBranchAddress],
        '',
      ),
      storePhone: _firstNonEmpty(
        [s.storePhone, model.branchPhone, business?.resolvedBranchPhone],
        '',
      ),
      branchName: _firstNonEmpty(
        [s.customBranchName, model.branchName, business?.resolvedBranchName],
        'Cabang Utama',
      ),
      title: model.title,
      transactionCode: _firstNonEmpty(
        [model.receiptNumber, model.bookingCode],
        '-',
      ),
      bookingCode: model.bookingCode,
      printedAt: model.transactedAt ?? DateFormatter.formatFull(DateTime.now()),
      cashierName: model.cashierName ?? 'Kasir',
      customerName: model.customerName ?? 'Pelanggan',
      customerPhone: model.customerPhone ?? '',
      rentalPeriodLabel: periodParts.join(' • '),
      isReprint: model.isReprint,
      items: items,
      subtotal: model.subtotal ?? model.totalAmount,
      discount: model.discount ?? 0.0,
      penaltyAmount: model.penaltyAmount ?? 0.0,
      collateralSummary: model.collateralInfo,
      totalAmount: model.totalAmount,
      paidAmount: model.cashReceived ?? model.totalAmount,
      changeAmount: model.cashChange ?? 0.0,
      remainingBalance: model.remainingBalance ?? 0.0,
      isDownPayment: model.isDownPayment,
      paymentMethodLabel: normalizePaymentMethodLabel(model.paymentMethod),
      paperWidthMm: s.paperWidth == ReceiptPaperWidth.mm80 ? 80 : 58,
      footerNote: s.customFooterMessage.trim(),
      returnTermsText: s.returnTermsText.trim(),
      qrData: model.qrData ?? model.bookingCode,
      headerAlignment: s.headerAlignment,
      separatorStyle: s.separatorStyle,
      printMode: s.printMode,
      showCashierName: s.showCashierName,
      showCustomerPhone: s.showCustomerPhone,
      maskCustomerPhone: s.maskCustomerPhone,
      showCollateralInfo: s.showCollateralInfo,
      showReturnTerms: s.showReturnTerms,
      showQrBarcode: s.showQrBarcode,
      showChangeDue: s.showChangeDue,
      showPenaltyDetails: s.showPenaltyDetails,
      extraFeedLines: s.extraFeedLines,
      useRasterQr: s.useRasterQr,
    );
  }

  static String _firstNonEmpty(List<String?> candidates, String fallback) {
    for (final c in candidates) {
      final trimmed = c?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  static String _formatTimestamp(String raw) {
    final parsed = DateFormatter.parseLocal(raw);
    if (parsed != null) {
      return DateFormatter.formatFull(parsed);
    }
    return raw.trim();
  }

  static String _titleForPaymentType(PaymentTransactionType type) {
    switch (type) {
      case PaymentTransactionType.booking:
        return 'STRUK SEWA PERANGKAT';
      case PaymentTransactionType.settlement:
        return 'STRUK PELUNASAN SEWA';
      case PaymentTransactionType.penalty:
        return 'STRUK PEMBAYARAN DENDA';
      case PaymentTransactionType.extension:
        return 'STRUK PERPANJANGAN SEWA';
    }
  }

  static String? _latestPaymentMethodFromBooking(Map<String, dynamic> booking) {
    final payments = booking['payments'];
    if (payments is List && payments.isNotEmpty) {
      for (int i = payments.length - 1; i >= 0; i--) {
        final p = payments[i];
        if (p is Map) {
          if (p['status']?.toString().toLowerCase() == 'void') continue;
          final method = p['payment_method'];
          if (method is Map) {
            final name = method['name']?.toString() ?? method['code']?.toString();
            if (name != null && name.trim().isNotEmpty) return name;
          } else if (method != null && method.toString().trim().isNotEmpty) {
            return method.toString();
          }
        }
      }
    }
    return null;
  }

  static String _resolveRentalPeriodLabel({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> receiptData,
    PaymentContext? paymentContext,
  }) {
    final parts = <String>[];
    final durVal = booking['duration_value'] ??
        receiptData['duration_hours'] ??
        booking['duration_hours'] ??
        paymentContext?.additionalHours;
    final durUnit = (booking['duration_unit']?.toString() ?? '').trim();
    if (durVal != null && durVal.toString().trim().isNotEmpty) {
      final unitLabel = durUnit.isNotEmpty
          ? (durUnit.toLowerCase() == 'days' || durUnit.toLowerCase() == 'day'
              ? 'Hari'
              : (durUnit.toLowerCase() == 'hours' || durUnit.toLowerCase() == 'hour'
                  ? 'Jam'
                  : durUnit))
          : 'Jam';
      parts.add('$durVal $unitLabel');
    }

    final endAt = booking['end_at'] ??
        booking['return_due_at'] ??
        paymentContext?.extraPayload?['end_at'];
    if (endAt != null && endAt.toString().trim().isNotEmpty) {
      parts.add('s/d ${_formatTimestamp(endAt.toString())}');
    }
    return parts.join(' • ');
  }

  static String? _resolveCollateralSummary({
    required Map<String, dynamic> booking,
    required Map<String, dynamic> receiptData,
    required Map<String, dynamic> extraPayload,
  }) {
    final explicit = _firstNonEmpty([
      receiptData['collateral_summary']?.toString(),
      booking['collateral_summary']?.toString(),
    ], '');
    if (explicit.isNotEmpty) return explicit;

    final merged = <String, dynamic>{...extraPayload, ...booking};
    final hasCollateralField = merged['collateral_type_name'] != null ||
        merged['collateral_type'] != null ||
        merged['collateral_storage_slot'] != null ||
        (CurrencyFormatter.parse(merged['collateral_deposit_amount']) > 0);
    if (!hasCollateralField) return null;

    final summary = formatCollateralSummary(merged).trim();
    if (summary.isEmpty ||
        summary == '-' ||
        summary.toLowerCase() == 'tanpa jaminan') {
      return null;
    }
    return summary;
  }

  static List<ReceiptDocumentItem> _parseItems({
    PaymentContext? paymentContext,
    required Map<String, dynamic> receiptData,
    required Map<String, dynamic> booking,
  }) {
    final result = <ReceiptDocumentItem>[];

    // Priority 1: Structured PaymentContext items (Checkout POS)
    if (paymentContext != null && paymentContext.items.isNotEmpty) {
      for (final item in paymentContext.items) {
        result.add(
          ReceiptDocumentItem(
            name: item.name,
            variantOrCode: item.assetCode,
            quantity: 1,
            unitPrice: item.price,
            totalPrice: item.price,
            isAddon: item.isAddon,
            durationLabel: item.durationText,
          ),
        );
      }
      return result;
    }

    // Priority 2: Receipt API items (Dashboard Queue / Transaction Detail)
    final rawReceiptItems = receiptData['items'];
    if (rawReceiptItems is List && rawReceiptItems.isNotEmpty) {
      final bookingItems = (booking['items'] is List)
          ? (booking['items'] as List)
          : const <dynamic>[];
      for (int i = 0; i < rawReceiptItems.length; i++) {
        final raw = rawReceiptItems[i];
        if (raw is! Map) continue;
        final rawMap = Map<String, dynamic>.from(raw);
        final matchingBookingItem =
            i < bookingItems.length && bookingItems[i] is Map
                ? Map<String, dynamic>.from(bookingItems[i] as Map)
                : null;
        final isAddon = rawMap['is_addon'] == true ||
            rawMap['item_type']?.toString().toLowerCase() == 'addon' ||
            matchingBookingItem?['item_type']?.toString().toLowerCase() ==
                'addon' ||
            (matchingBookingItem?['asset']?['model']?['is_addon'] == true);
        final qty = (rawMap['quantity'] as num?)?.toInt() ??
            (rawMap['qty'] as num?)?.toInt() ??
            1;
        final total = CurrencyFormatter.parse(
          rawMap['total_price'] ?? rawMap['price'] ?? rawMap['unit_price'],
        );
        final unit = rawMap['unit_price'] != null
            ? CurrencyFormatter.parse(rawMap['unit_price'])
            : (qty > 0 ? total / qty : total);

        result.add(
          ReceiptDocumentItem(
            name: rawMap['name']?.toString() ?? 'Unit Sewa',
            variantOrCode: rawMap['asset_code']?.toString() ??
                rawMap['variant']?.toString(),
            quantity: qty,
            unitPrice: unit,
            totalPrice: total,
            isAddon: isAddon,
            durationLabel: rawMap['duration']?.toString(),
          ),
        );
      }
      return result;
    }

    // Priority 3: Booking items directly (fallback if receipt endpoint omitted items)
    final rawBookingItems = booking['items'];
    if (rawBookingItems is List && rawBookingItems.isNotEmpty) {
      for (final raw in rawBookingItems) {
        if (raw is! Map) continue;
        final it = Map<String, dynamic>.from(raw);
        final asset = it['asset'] is Map ? it['asset'] as Map : const {};
        final model = asset['model'] is Map ? asset['model'] as Map : const {};
        final name = model['name']?.toString() ??
            it['name']?.toString() ??
            'Unit Sewa';
        final code = asset['asset_code']?.toString() ??
            asset['serial_number']?.toString();
        final isAddon = it['item_type']?.toString().toLowerCase() == 'addon' ||
            model['is_addon'] == true;
        final qty = (it['quantity'] as num?)?.toInt() ??
            (it['qty'] as num?)?.toInt() ??
            1;
        final unitPrice = CurrencyFormatter.parse(
          it['unit_price'] ?? it['price'] ?? 0,
        );
        final totalPrice = it['subtotal'] != null
            ? CurrencyFormatter.parse(it['subtotal'])
            : unitPrice * qty;
        result.add(
          ReceiptDocumentItem(
            name: name,
            variantOrCode: code,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
            isAddon: isAddon,
          ),
        );
      }
      return result;
    }

    // Priority 4: Single device fallback
    final fallbackDevice = _firstNonEmpty([
      paymentContext?.deviceName,
      booking['device']?['asset_model']?['name']?.toString(),
      booking['device_name']?.toString(),
    ], '');
    if (fallbackDevice.isNotEmpty) {
      final fallbackAmount = CurrencyFormatter.parse(
        receiptData['total_amount'] ??
            booking['total_bill'] ??
            paymentContext?.totalAmountDue ??
            0,
      );
      result.add(
        ReceiptDocumentItem(
          name: fallbackDevice,
          variantOrCode: paymentContext?.assetCode ??
              booking['device']?['asset_code']?.toString(),
          quantity: 1,
          unitPrice: fallbackAmount,
          totalPrice: fallbackAmount,
        ),
      );
    }

    return result;
  }
}

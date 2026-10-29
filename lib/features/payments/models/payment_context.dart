import '../../../core/utils/currency_formatter.dart';

enum PaymentTransactionType {
  booking,
  settlement,
  penalty,
  extension,
}

enum PaymentStatus {
  completed,
  partial,
  cancelled,
  failed,
}

class PaymentItem {
  final String name;
  final String? assetCode;
  final bool isAddon;
  final String? durationText;
  final double price;

  const PaymentItem({
    required this.name,
    this.assetCode,
    this.isAddon = false,
    this.durationText,
    required this.price,
  });
}

class PaymentContext {
  final PaymentTransactionType transactionType;
  final int? bookingId;
  final String? bookingCode;
  final String customerName;
  final String? customerPhone;
  final String? customerAddress;
  final String? deviceName;
  final String? assetCode;
  final double totalAmountDue;
  final double previouslyPaidAmount;
  final double remainingDue;
  final int? branchId;
  final String? branchName;
  final bool isCentral;
  final int? additionalHours;
  final Map<String, dynamic>? extraPayload;
  final List<PaymentItem> items;
  final double? primarySubtotal;
  final double? addonSubtotal;
  final double? discountAmount;
  final String? voucherCode;
  final double? depositFee;

  const PaymentContext({
    required this.transactionType,
    this.bookingId,
    this.bookingCode,
    required this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.deviceName,
    this.assetCode,
    required this.totalAmountDue,
    this.previouslyPaidAmount = 0.0,
    required this.remainingDue,
    this.branchId,
    this.branchName,
    this.isCentral = false,
    this.additionalHours,
    this.extraPayload,
    this.items = const [],
    this.primarySubtotal,
    this.addonSubtotal,
    this.discountAmount,
    this.voucherCode,
    this.depositFee,
  });

  String get transactionTypeTitle {
    switch (transactionType) {
      case PaymentTransactionType.booking:
        return 'Pembayaran Sewa Baru (Kontrak)';
      case PaymentTransactionType.settlement:
        return 'Pelunasan Sisa Tagihan Sewa';
      case PaymentTransactionType.penalty:
        return 'Pelunasan Denda Keterlambatan';
      case PaymentTransactionType.extension:
        return 'Pembayaran Perpanjangan Sewa (${additionalHours ?? 0} Jam)';
    }
  }

  String get typeBadgeLabel {
    switch (transactionType) {
      case PaymentTransactionType.booking:
        return 'SEWA BARU';
      case PaymentTransactionType.settlement:
        return 'PELUNASAN SEWA';
      case PaymentTransactionType.penalty:
        return 'DENDA KETERLAMBATAN';
      case PaymentTransactionType.extension:
        return 'PERPANJANGAN';
    }
  }

  factory PaymentContext.booking({
    Map<String, dynamic>? bookingPayload,
    Map<String, dynamic>? extraPayload,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
    required String deviceName,
    String? assetCode,
    required double totalAmount,
    int? branchId,
    String? branchName,
    bool isCentral = false,
    List<PaymentItem> items = const [],
    double? primarySubtotal,
    double? addonSubtotal,
    double? discountAmount,
    String? voucherCode,
    double? depositFee,
  }) {
    return PaymentContext(
      transactionType: PaymentTransactionType.booking,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      deviceName: deviceName,
      assetCode: assetCode,
      totalAmountDue: totalAmount,
      previouslyPaidAmount: 0.0,
      remainingDue: totalAmount,
      branchId: branchId,
      branchName: branchName,
      isCentral: isCentral,
      extraPayload: extraPayload ?? bookingPayload,
      items: items,
      primarySubtotal: primarySubtotal,
      addonSubtotal: addonSubtotal,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      depositFee: depositFee,
    );
  }

  factory PaymentContext.settlement({
    required Map<String, dynamic> booking,
    required double remainingDue,
  }) {
    final customer = booking['customer'] as Map? ?? {};
    final rawItems = (booking['items'] as List?) ?? [];

    final parsedItems = <PaymentItem>[];
    String? primaryModelName;
    String? primaryAssetCode;

    for (final it in rawItems) {
      if (it is Map) {
        final itMap = Map<String, dynamic>.from(it);
        final asset = itMap['asset'] as Map? ?? {};
        final model = asset['model'] as Map? ?? {};
        final name = model['name']?.toString() ?? 'Unit Sewa';
        final code = asset['asset_code']?.toString();
        final isAddon = itMap['item_type']?.toString().toLowerCase() == 'addon' ||
            model['is_addon'] == true;
        final durVal = itMap['duration_value'] ?? booking['duration_value'] ?? booking['duration_hours'];
        final durUnit = itMap['duration_unit'] ?? booking['duration_unit'] ?? 'Jam';
        final durText = durVal != null ? '$durVal $durUnit' : null;
        final price = CurrencyFormatter.parse(itMap['unit_price'] ?? 0);

        parsedItems.add(
          PaymentItem(
            name: name,
            assetCode: code,
            isAddon: isAddon,
            durationText: durText,
            price: price,
          ),
        );

        if (!isAddon && primaryModelName == null) {
          primaryModelName = name;
          primaryAssetCode = code;
        }
      }
    }

    final firstItem = rawItems.isNotEmpty ? (rawItems[0] as Map) : null;
    final modelName = primaryModelName ??
        firstItem?['asset']?['model']?['name']?.toString() ??
        booking['device']?['asset_model']?['name']?.toString() ??
        'Unit Sewa';
    final assetCode = primaryAssetCode ??
        firstItem?['asset']?['asset_code']?.toString() ??
        booking['device']?['asset_code']?.toString() ??
        '';
    final affiliate = booking['affiliate'] as Map? ?? {};
    final totalBill = CurrencyFormatter.parse(booking['total_bill'] ?? booking['total_amount'] ?? 0);
    final payments = (booking['payments'] as List?) ?? [];
    double totalPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pType = p['type']?.toString().toLowerCase();
      if (pType == 'settlement' || pType == 'dp' || pType == 'extension' || pType == 'rental' || pType == 'exchange') {
        totalPaid += CurrencyFormatter.parse(p['amount']);
      }
    }

    final primarySubtotal = booking['primary_subtotal'] != null
        ? CurrencyFormatter.parse(booking['primary_subtotal'])
        : null;
    final addonSubtotal = booking['addon_subtotal'] != null
        ? CurrencyFormatter.parse(booking['addon_subtotal'])
        : null;
    final discountAmount = booking['discount_amount'] != null
        ? CurrencyFormatter.parse(booking['discount_amount'])
        : null;
    final voucherCode = booking['voucher']?['code']?.toString() ?? booking['voucher_code']?.toString();
    final depositFee = booking['deposit_fee'] != null
        ? CurrencyFormatter.parse(booking['deposit_fee'])
        : null;

    return PaymentContext(
      transactionType: PaymentTransactionType.settlement,
      bookingId: booking['id'] as int?,
      bookingCode: booking['booking_code']?.toString(),
      customerName: customer['name']?.toString() ?? 'Pelanggan',
      customerPhone: customer['phone']?.toString(),
      customerAddress: customer['address']?.toString(),
      deviceName: modelName,
      assetCode: assetCode,
      totalAmountDue: totalBill,
      previouslyPaidAmount: totalPaid,
      remainingDue: remainingDue,
      branchId: affiliate['id'] ?? booking['affiliate_id'],
      branchName: affiliate['name']?.toString(),
      isCentral: affiliate['is_central'] == true,
      extraPayload: booking,
      items: parsedItems,
      primarySubtotal: primarySubtotal,
      addonSubtotal: addonSubtotal,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      depositFee: depositFee,
    );
  }

  factory PaymentContext.penalty({
    Map<String, dynamic>? booking,
    int? bookingId,
    String? bookingCode,
    String? customerName,
    String? deviceModel,
    required double penaltyDue,
    int? branchId,
    String? branchName,
    bool isCentral = false,
    Map<String, dynamic>? extraPayload,
  }) {
    final b = booking ?? {};
    final bId = bookingId ?? b['id'] as int?;
    final bCode = bookingCode ?? b['booking_code']?.toString();
    final customer = (b['customer'] as Map?) ?? {};
    final cName = customerName ?? customer['name']?.toString() ?? 'Pelanggan';
    final cPhone = customer['phone']?.toString();
    final cAddress = customer['address']?.toString();
    final items = (b['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? (items[0] as Map) : null;
    final modelName = deviceModel ??
        firstItem?['asset']?['model']?['name']?.toString() ??
        b['device']?['asset_model']?['name']?.toString() ??
        'Unit Sewa';
    final assetCode = firstItem?['asset']?['asset_code']?.toString() ??
        b['device']?['asset_code']?.toString() ??
        '';
    final affiliate = (b['affiliate'] as Map?) ?? {};
    final returnInspection = (b['return_inspection'] as Map?) ?? (b['returnInspection'] as Map?) ?? {};
    final totalPenalty = CurrencyFormatter.parse(returnInspection['total_penalty'] ?? 0);
    final payments = (b['payments'] as List?) ?? [];
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      if (p['type']?.toString().toLowerCase() == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    // Server-persisted penalty is authoritative; client estimate is fallback only.
    final effectiveRemaining = totalPenalty > 0
        ? (totalPenalty - penaltyPaid).clamp(0.0, double.infinity).toDouble()
        : penaltyDue;

    return PaymentContext(
      transactionType: PaymentTransactionType.penalty,
      bookingId: bId,
      bookingCode: bCode,
      customerName: cName,
      customerPhone: cPhone,
      customerAddress: cAddress,
      deviceName: modelName,
      assetCode: assetCode,
      totalAmountDue: totalPenalty > 0 ? totalPenalty : penaltyDue,
      previouslyPaidAmount: penaltyPaid,
      remainingDue: effectiveRemaining,
      branchId: branchId ?? affiliate['id'] ?? b['affiliate_id'],
      branchName: branchName ?? affiliate['name']?.toString(),
      isCentral: isCentral || affiliate['is_central'] == true,
      extraPayload: extraPayload != null ? {...b, ...extraPayload} : b,
    );
  }

  factory PaymentContext.extension({
    Map<String, dynamic>? booking,
    int? bookingId,
    String? bookingCode,
    String? customerName,
    String? deviceModel,
    required int additionalHours,
    required double extensionFee,
    int? branchId,
    String? branchName,
    bool isCentral = false,
    Map<String, dynamic>? extraPayload,
  }) {
    final b = booking ?? {};
    final bId = bookingId ?? b['id'] as int?;
    final bCode = bookingCode ?? b['booking_code']?.toString();
    final customer = (b['customer'] as Map?) ?? {};
    final cName = customerName ?? customer['name']?.toString() ?? 'Pelanggan';
    final cPhone = customer['phone']?.toString();
    final cAddress = customer['address']?.toString();
    final items = (b['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? (items[0] as Map) : null;
    final modelName = deviceModel ??
        firstItem?['asset']?['model']?['name']?.toString() ??
        b['device']?['asset_model']?['name']?.toString() ??
        'Unit Sewa';
    final assetCode = firstItem?['asset']?['asset_code']?.toString() ??
        b['device']?['asset_code']?.toString() ??
        '';
    final affiliate = (b['affiliate'] as Map?) ?? {};
    final totalBill = CurrencyFormatter.parse(b['total_bill'] ?? b['total_amount'] ?? 0);

    return PaymentContext(
      transactionType: PaymentTransactionType.extension,
      bookingId: bId,
      bookingCode: bCode,
      customerName: cName,
      customerPhone: cPhone,
      customerAddress: cAddress,
      deviceName: modelName,
      assetCode: assetCode,
      totalAmountDue: totalBill + extensionFee,
      previouslyPaidAmount: totalBill,
      remainingDue: extensionFee,
      additionalHours: additionalHours,
      branchId: branchId ?? affiliate['id'] ?? b['affiliate_id'],
      branchName: branchName ?? affiliate['name']?.toString(),
      isCentral: isCentral || affiliate['is_central'] == true,
      extraPayload: extraPayload ?? b,
    );
  }
}

class PaymentResult {
  final PaymentStatus status;
  final String? transactionCode;
  final String? receiptNumber;
  final double amountPaid;
  final double cashReceived;
  final double cashChange;
  final String? paymentMethodCode;
  final String? paymentMethodName;
  final Map<String, dynamic>? responseData;
  final String? errorMessage;

  const PaymentResult({
    required this.status,
    this.transactionCode,
    this.receiptNumber,
    this.amountPaid = 0.0,
    this.cashReceived = 0.0,
    this.cashChange = 0.0,
    this.paymentMethodCode,
    this.paymentMethodName,
    this.responseData,
    this.errorMessage,
  });

  bool get isSuccess => status == PaymentStatus.completed || status == PaymentStatus.partial;
}

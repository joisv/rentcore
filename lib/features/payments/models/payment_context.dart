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
  final bool isDownPayment;
  final double? contractTotalAmount;
  final bool isHandoverSettlement;
  final String? idempotencyKey;

  double get effectiveContractTotal => contractTotalAmount ?? totalAmountDue;
  double get remainingAfterCurrentPayment => isDownPayment
      ? (effectiveContractTotal - remainingDue).clamp(0.0, double.infinity)
      : 0.0;

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
    this.isDownPayment = false,
    this.contractTotalAmount,
    this.isHandoverSettlement = false,
    this.idempotencyKey,
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

  String get pageHeaderTitle {
    switch (transactionType) {
      case PaymentTransactionType.booking:
      case PaymentTransactionType.settlement:
        return 'Pembayaran  Sewa';
      case PaymentTransactionType.penalty:
        return 'Pembayaran Denda';
      case PaymentTransactionType.extension:
        return 'Pembayaran Perpanjangan';
    }
  }

  String get tagihanLabel {
    if (isDownPayment) return 'Nominal DP';
    if (isHandoverSettlement ||
        transactionType == PaymentTransactionType.settlement) {
      return 'Sisa Tagihan';
    }
    switch (transactionType) {
      case PaymentTransactionType.penalty:
        return 'Tagihan Denda';
      default:
        return 'Total Tagihan';
    }
  }

  String get detailLinkText {
    switch (transactionType) {
      case PaymentTransactionType.penalty:
        return 'Detail Denda';
      default:
        return 'Detail Sewa';
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
    int? additionalHours,
    List<PaymentItem> items = const [],
    double? primarySubtotal,
    double? addonSubtotal,
    double? discountAmount,
    String? voucherCode,
    double? depositFee,
    bool isDownPayment = false,
    double? contractTotalAmount,
    String? idempotencyKey,
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
      additionalHours: additionalHours,
      extraPayload: extraPayload ?? bookingPayload,
      items: items,
      primarySubtotal: primarySubtotal,
      addonSubtotal: addonSubtotal,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      depositFee: depositFee,
      isDownPayment: isDownPayment,
      contractTotalAmount: contractTotalAmount,
      idempotencyKey: idempotencyKey,
    );
  }

  factory PaymentContext.settlement({
    required Map<String, dynamic> booking,
    required double remainingDue,
    bool isHandoverSettlement = false,
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool startNow = false,
    bool keepOriginalEndAt = false,
    double? contractTotalOverride,
    String? idempotencyKey,
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
      totalAmountDue: contractTotalOverride ?? totalBill,
      previouslyPaidAmount: totalPaid,
      remainingDue: remainingDue,
      branchId: affiliate['id'] ?? booking['affiliate_id'],
      branchName: affiliate['name']?.toString(),
      isCentral: affiliate['is_central'] == true,
      extraPayload: {
        ...booking,
        if (isHandoverSettlement) 'is_handover_settlement': true,
        if (startNow) 'start_now': true,
        if (startNow) 'keep_original_end_at': keepOriginalEndAt,
        'asset_unit_id': ?assetUnitId,
        'collateral_type': ?collateralType,
        'collateral_type_id': ?collateralTypeId,
        'collateral_type_name': ?collateralTypeName,
        'collateral_storage_slot': ?collateralStorageSlot,
        'collateral_deposit_amount': ?collateralDepositAmount,
      },
      items: parsedItems,
      primarySubtotal: primarySubtotal,
      addonSubtotal: addonSubtotal,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      depositFee: depositFee,
      isHandoverSettlement: isHandoverSettlement,
      idempotencyKey: idempotencyKey,
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
    String? idempotencyKey,
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
    final totalPenalty = CurrencyFormatter.parse(
      returnInspection['total_penalty'] ??
      returnInspection['late_fee'] ??
      returnInspection['penalty_amount'] ??
      b['total_penalty'] ??
      b['penalty_amount'] ??
      b['late_fee'] ??
      0,
    );
    final payments = (b['payments'] as List?) ?? [];
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      if (p['type']?.toString().toLowerCase() == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }

    final returnPayload = (extraPayload?['return_payload'] as Map?) ?? {};
    final isReturnWorkflow = extraPayload?['is_return_workflow'] == true;

    // Ingest penalty amount from all potential keys across payload and booking
    final fallbackPenalty = CurrencyFormatter.parse(
      extraPayload?['penalty_amount'] ??
      extraPayload?['late_fee'] ??
      extraPayload?['total_penalty'] ??
      extraPayload?['amount'] ??
      returnPayload['penalty_amount'] ??
      returnPayload['late_fee'] ??
      returnPayload['total_penalty'] ??
      b['penalty_amount'] ??
      b['late_fee'] ??
      b['total_penalty'] ??
      0,
    );

    final resolvedPenaltyDue = penaltyDue > 0 ? penaltyDue : fallbackPenalty;

    // During active return inspection, the client calculated penalty is authoritative.
    // For deferred/pos settlement of already returned bookings, server penalty takes precedence.
    final double effectiveRemaining;
    if (isReturnWorkflow) {
      effectiveRemaining = resolvedPenaltyDue > 0
          ? resolvedPenaltyDue
          : (totalPenalty > 0 ? (totalPenalty - penaltyPaid).clamp(0.0, double.infinity).toDouble() : 0.0);
    } else {
      effectiveRemaining = totalPenalty > 0
          ? (totalPenalty - penaltyPaid).clamp(0.0, double.infinity).toDouble()
          : resolvedPenaltyDue;
    }

    final finalPayableAmount = effectiveRemaining > 0 ? effectiveRemaining : resolvedPenaltyDue;

    final penaltyItems = <PaymentItem>[
      PaymentItem(
        name: 'Denda Keterlambatan ($modelName)',
        assetCode: assetCode,
        isAddon: false,
        durationText: 'Sanksi Keterlambatan',
        price: finalPayableAmount,
      ),
    ];

    return PaymentContext(
      transactionType: PaymentTransactionType.penalty,
      bookingId: bId,
      bookingCode: bCode,
      customerName: cName,
      customerPhone: cPhone,
      customerAddress: cAddress,
      deviceName: modelName,
      assetCode: assetCode,
      totalAmountDue: isReturnWorkflow && resolvedPenaltyDue > 0
          ? resolvedPenaltyDue
          : (totalPenalty > 0 ? totalPenalty : resolvedPenaltyDue),
      previouslyPaidAmount: penaltyPaid,
      remainingDue: finalPayableAmount,
      branchId: branchId ?? affiliate['id'] ?? b['affiliate_id'],
      branchName: branchName ?? affiliate['name']?.toString(),
      isCentral: isCentral || affiliate['is_central'] == true,
      extraPayload: extraPayload != null ? {...b, ...extraPayload} : b,
      items: penaltyItems,
      idempotencyKey: idempotencyKey,
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
    String? idempotencyKey,
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

    final extensionItems = <PaymentItem>[
      PaymentItem(
        name: modelName,
        assetCode: assetCode,
        isAddon: false,
        durationText: '$additionalHours Jam',
        price: extensionFee,
      ),
    ];

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
      items: extensionItems,
      idempotencyKey: idempotencyKey,
    );
  }

  factory PaymentContext.fromGeneric({
    required dynamic transactionType,
    int? referenceId,
    int? bookingId,
    String? bookingCode,
    required double totalAmount,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? deviceName,
    String? assetCode,
    int? branchId,
    String? branchName,
    bool isCentral = false,
    int? additionalHours,
    Map<String, dynamic>? metadata,
    List<PaymentItem>? items,
    double? primarySubtotal,
    double? addonSubtotal,
    double? discountAmount,
    String? voucherCode,
    double? depositFee,
    String? idempotencyKey,
  }) {
    final effectiveBookingId = bookingId ?? referenceId;
    PaymentTransactionType type;
    if (transactionType is PaymentTransactionType) {
      type = transactionType;
    } else {
      final s = transactionType.toString().toLowerCase().replaceAll('-', '_');
      if (s.contains('penalty') || s.contains('denda')) {
        type = PaymentTransactionType.penalty;
      } else if (s.contains('extend') || s.contains('perpanjang')) {
        type = PaymentTransactionType.extension;
      } else if (s.contains('settle') || s.contains('lunas')) {
        type = PaymentTransactionType.settlement;
      } else {
        type = PaymentTransactionType.booking;
      }
    }

    final resolvedAmount = totalAmount > 0
        ? totalAmount
        : CurrencyFormatter.parse(
            metadata?['penalty_amount'] ??
            metadata?['late_fee'] ??
            metadata?['total_penalty'] ??
            metadata?['penaltyDue'] ??
            metadata?['amount'] ??
            metadata?['total_amount'] ??
            0,
          );

    final parsedItems = items ?? <PaymentItem>[];
    if (parsedItems.isEmpty && deviceName != null) {
      parsedItems.add(
        PaymentItem(
          name: deviceName,
          assetCode: assetCode,
          isAddon: false,
          durationText: additionalHours != null ? '$additionalHours Jam' : null,
          price: resolvedAmount,
        ),
      );
    }

    return PaymentContext(
      transactionType: type,
      bookingId: effectiveBookingId,
      bookingCode: bookingCode,
      customerName: customerName ?? 'Pelanggan',
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      deviceName: deviceName ?? 'Unit Sewa',
      assetCode: assetCode,
      totalAmountDue: resolvedAmount,
      previouslyPaidAmount: 0.0,
      remainingDue: resolvedAmount,
      branchId: branchId,
      branchName: branchName,
      isCentral: isCentral,
      additionalHours: additionalHours,
      extraPayload: metadata,
      items: parsedItems,
      primarySubtotal: primarySubtotal ?? resolvedAmount,
      addonSubtotal: addonSubtotal,
      discountAmount: discountAmount,
      voucherCode: voucherCode,
      depositFee: depositFee,
      idempotencyKey: idempotencyKey,
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

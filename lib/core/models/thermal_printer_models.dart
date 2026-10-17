import 'dart:convert';

enum ReceiptPaperWidth {
  mm58(columns: 32, label: '58mm (Standar Portabel)'),
  mm80(columns: 48, label: '80mm (Desktop POS)');

  final int columns;
  final String label;
  const ReceiptPaperWidth({required this.columns, required this.label});

  static ReceiptPaperWidth fromName(String? name) {
    if (name == 'mm80' || name == '80mm') return ReceiptPaperWidth.mm80;
    return ReceiptPaperWidth.mm58;
  }
}

enum PrintMode {
  normal(label: 'Normal (Cetak Fisik Bluetooth)', description: 'Mengirim perintah ESC/POS langsung ke printer thermal fisik.'),
  echo(label: 'Echo (Virtual Audit / Dry-Run)', description: 'Simulasi cetak & cermin audit terminal tanpa menghabiskan kertas thermal.');

  final String label;
  final String description;
  const PrintMode({required this.label, required this.description});

  static PrintMode fromName(String? name) {
    if (name == 'echo') return PrintMode.echo;
    return PrintMode.normal;
  }
}

enum PrinterConnectionStatus {
  disconnected,
  scanning,
  connecting,
  connected,
  error;

  String get label {
    switch (this) {
      case PrinterConnectionStatus.disconnected:
        return 'Tidak Terhubung';
      case PrinterConnectionStatus.scanning:
        return 'Mencari Printer...';
      case PrinterConnectionStatus.connecting:
        return 'Menghubungkan...';
      case PrinterConnectionStatus.connected:
        return 'Terhubung & Siap';
      case PrinterConnectionStatus.error:
        return 'Gagal Terhubung';
    }
  }
}

enum ReceiptHeaderAlignment {
  left,
  center;

  static ReceiptHeaderAlignment fromName(String? name) {
    if (name == 'left') return ReceiptHeaderAlignment.left;
    return ReceiptHeaderAlignment.center;
  }
}

class ThermalPrinterDevice {
  final String name;
  final String address;
  final bool isConnected;
  final int? rssi;
  final bool isBonded;
  final String deviceType; // 'classic' or 'ble'

  const ThermalPrinterDevice({
    required this.name,
    required this.address,
    this.isConnected = false,
    this.rssi,
    this.isBonded = false,
    this.deviceType = 'classic',
  });

  ThermalPrinterDevice copyWith({
    String? name,
    String? address,
    bool? isConnected,
    int? rssi,
    bool? isBonded,
    String? deviceType,
  }) {
    return ThermalPrinterDevice(
      name: name ?? this.name,
      address: address ?? this.address,
      isConnected: isConnected ?? this.isConnected,
      rssi: rssi ?? this.rssi,
      isBonded: isBonded ?? this.isBonded,
      deviceType: deviceType ?? this.deviceType,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'address': address,
    'isConnected': isConnected,
    'rssi': rssi,
    'isBonded': isBonded,
    'deviceType': deviceType,
  };

  factory ThermalPrinterDevice.fromJson(Map<String, dynamic> json) => ThermalPrinterDevice(
    name: json['name']?.toString() ?? 'Thermal Printer',
    address: json['address']?.toString() ?? '',
    isConnected: json['isConnected'] == true,
    rssi: json['rssi'] is int ? json['rssi'] as int : null,
    isBonded: json['isBonded'] == true,
    deviceType: json['deviceType']?.toString() ?? 'classic',
  );
}

class ReceiptCustomizationSettings {
  final ReceiptPaperWidth paperWidth;
  final PrintMode printMode;
  final String customShopName;
  final String customBranchName;
  final String storeAddress;
  final String storePhone;
  final ReceiptHeaderAlignment headerAlignment;

  // Field toggles
  final bool showCashierName;
  final bool showCustomerPhone;
  final bool maskCustomerPhone;
  final bool showCollateralInfo;
  final bool showReturnTerms;
  final bool showQrBarcode;
  final bool showChangeDue;
  final bool showPenaltyDetails;

  // Custom text
  final String customFooterMessage;
  final String returnTermsText;

  // Formatting options
  final bool compactSpacing;
  final String separatorStyle; // 'dash' (-) or 'double' (=)

  const ReceiptCustomizationSettings({
    this.paperWidth = ReceiptPaperWidth.mm58,
    this.printMode = PrintMode.normal,
    this.customShopName = '',
    this.customBranchName = '',
    this.storeAddress = '',
    this.storePhone = '',
    this.headerAlignment = ReceiptHeaderAlignment.center,
    this.showCashierName = true,
    this.showCustomerPhone = true,
    this.maskCustomerPhone = true,
    this.showCollateralInfo = true,
    this.showReturnTerms = true,
    this.showQrBarcode = true,
    this.showChangeDue = true,
    this.showPenaltyDetails = true,
    this.customFooterMessage = '*** TERIMA KASIH ***\nSimpan struk ini sebagai bukti resmi',
    this.returnTermsText = 'Harap mengembalikan unit tepat waktu sesuai jadwal sewa. Keterlambatan dikenakan denda resmi.',
    this.compactSpacing = false,
    this.separatorStyle = 'dash',
  });

  ReceiptCustomizationSettings copyWith({
    ReceiptPaperWidth? paperWidth,
    PrintMode? printMode,
    String? customShopName,
    String? customBranchName,
    String? storeAddress,
    String? storePhone,
    ReceiptHeaderAlignment? headerAlignment,
    bool? showCashierName,
    bool? showCustomerPhone,
    bool? maskCustomerPhone,
    bool? showCollateralInfo,
    bool? showReturnTerms,
    bool? showQrBarcode,
    bool? showChangeDue,
    bool? showPenaltyDetails,
    String? customFooterMessage,
    String? returnTermsText,
    bool? compactSpacing,
    String? separatorStyle,
  }) {
    return ReceiptCustomizationSettings(
      paperWidth: paperWidth ?? this.paperWidth,
      printMode: printMode ?? this.printMode,
      customShopName: customShopName ?? this.customShopName,
      customBranchName: customBranchName ?? this.customBranchName,
      storeAddress: storeAddress ?? this.storeAddress,
      storePhone: storePhone ?? this.storePhone,
      headerAlignment: headerAlignment ?? this.headerAlignment,
      showCashierName: showCashierName ?? this.showCashierName,
      showCustomerPhone: showCustomerPhone ?? this.showCustomerPhone,
      maskCustomerPhone: maskCustomerPhone ?? this.maskCustomerPhone,
      showCollateralInfo: showCollateralInfo ?? this.showCollateralInfo,
      showReturnTerms: showReturnTerms ?? this.showReturnTerms,
      showQrBarcode: showQrBarcode ?? this.showQrBarcode,
      showChangeDue: showChangeDue ?? this.showChangeDue,
      showPenaltyDetails: showPenaltyDetails ?? this.showPenaltyDetails,
      customFooterMessage: customFooterMessage ?? this.customFooterMessage,
      returnTermsText: returnTermsText ?? this.returnTermsText,
      compactSpacing: compactSpacing ?? this.compactSpacing,
      separatorStyle: separatorStyle ?? this.separatorStyle,
    );
  }

  Map<String, dynamic> toJson() => {
    'paperWidth': paperWidth.name,
    'printMode': printMode.name,
    'customShopName': customShopName,
    'customBranchName': customBranchName,
    'storeAddress': storeAddress,
    'storePhone': storePhone,
    'headerAlignment': headerAlignment.name,
    'showCashierName': showCashierName,
    'showCustomerPhone': showCustomerPhone,
    'maskCustomerPhone': maskCustomerPhone,
    'showCollateralInfo': showCollateralInfo,
    'showReturnTerms': showReturnTerms,
    'showQrBarcode': showQrBarcode,
    'showChangeDue': showChangeDue,
    'showPenaltyDetails': showPenaltyDetails,
    'customFooterMessage': customFooterMessage,
    'returnTermsText': returnTermsText,
    'compactSpacing': compactSpacing,
    'separatorStyle': separatorStyle,
  };

  factory ReceiptCustomizationSettings.fromJson(Map<String, dynamic> json) => ReceiptCustomizationSettings(
    paperWidth: ReceiptPaperWidth.fromName(json['paperWidth']?.toString()),
    printMode: PrintMode.fromName(json['printMode']?.toString()),
    customShopName: json['customShopName']?.toString() ?? '',
    customBranchName: json['customBranchName']?.toString() ?? '',
    storeAddress: json['storeAddress']?.toString() ?? '',
    storePhone: json['storePhone']?.toString() ?? '',
    headerAlignment: ReceiptHeaderAlignment.fromName(json['headerAlignment']?.toString()),
    showCashierName: json['showCashierName'] != false,
    showCustomerPhone: json['showCustomerPhone'] != false,
    maskCustomerPhone: json['maskCustomerPhone'] != false,
    showCollateralInfo: json['showCollateralInfo'] != false,
    showReturnTerms: json['showReturnTerms'] != false,
    showQrBarcode: json['showQrBarcode'] != false,
    showChangeDue: json['showChangeDue'] != false,
    showPenaltyDetails: json['showPenaltyDetails'] != false,
    customFooterMessage: json['customFooterMessage']?.toString() ?? '*** TERIMA KASIH ***\nSimpan struk ini sebagai bukti resmi',
    returnTermsText: json['returnTermsText']?.toString() ?? 'Harap mengembalikan unit tepat waktu sesuai jadwal sewa. Keterlambatan dikenakan denda resmi.',
    compactSpacing: json['compactSpacing'] == true,
    separatorStyle: json['separatorStyle']?.toString() ?? 'dash',
  );

  static ReceiptCustomizationSettings defaultSettings({String? shopName, String? branchName}) {
    return ReceiptCustomizationSettings(
      customShopName: shopName ?? '',
      customBranchName: branchName ?? '',
    );
  }
}

enum ReceiptType {
  rentalBooking,
  posPayment,
  rentalReturn,
  closingShift,
  voucherSlip,
  testPrint;

  String get defaultTitle {
    switch (this) {
      case ReceiptType.rentalBooking:
        return 'STRUK SEWA PERANGKAT';
      case ReceiptType.posPayment:
        return 'STRUK TRANSAKSI POS';
      case ReceiptType.rentalReturn:
        return 'BUKTI PENGEMBALIAN UNIT';
      case ReceiptType.closingShift:
        return 'LAPORAN CLOSING SHIFT';
      case ReceiptType.voucherSlip:
        return 'VOUCHER DISKON SPESIAL';
      case ReceiptType.testPrint:
        return 'TEST PRINT THERMAL';
    }
  }
}

class ReceiptDataModel {
  final ReceiptType type;
  final String title;
  final String branchName;
  final String? shopName;
  final String? receiptNumber;
  final String? bookingCode;
  final String? customerName;
  final String? customerPhone;
  final String? cashierName;
  final String? unitName;
  final String? unitModel;
  final String? unitSerial;
  final String? rentalStartDate;
  final String? rentalEndDate;
  final String? rentalDurationText;
  final String? collateralInfo;
  final List<Map<String, dynamic>>? items;
  final double? subtotal;
  final double? discount;
  final double? penaltyAmount;
  final String? penaltyReason;
  final double totalAmount;
  final String? paymentMethod;
  final double? cashReceived;
  final double? cashChange;
  final String? conditionGrade;
  final String? checklistNotes;
  final String? accessoriesNotes;
  final String? qrData;
  final Map<String, double>? shiftBreakdown;
  final int? shiftTotalTransactions;
  final String? transactedAt;

  const ReceiptDataModel({
    required this.type,
    required this.title,
    required this.branchName,
    this.shopName,
    this.receiptNumber,
    this.bookingCode,
    this.customerName,
    this.customerPhone,
    this.cashierName,
    this.unitName,
    this.unitModel,
    this.unitSerial,
    this.rentalStartDate,
    this.rentalEndDate,
    this.rentalDurationText,
    this.collateralInfo,
    this.items,
    this.subtotal,
    this.discount,
    this.penaltyAmount,
    this.penaltyReason,
    required this.totalAmount,
    this.paymentMethod,
    this.cashReceived,
    this.cashChange,
    this.conditionGrade,
    this.checklistNotes,
    this.accessoriesNotes,
    this.qrData,
    this.shiftBreakdown,
    this.shiftTotalTransactions,
    this.transactedAt,
  });
}

// ==========================================
// Structured Receipt Document Models (Single Source of Truth)
// ==========================================
enum ReceiptLineType {
  header,
  text,
  keyValue,
  divider,
  qrCode,
  emptyFeed,
}

class ReceiptLineItem {
  final ReceiptLineType type;
  final String text;
  final String? leftText;
  final String? rightText;
  final ReceiptHeaderAlignment alignment;
  final bool isBold;
  final bool isDoubleSize;
  final String? qrData;

  const ReceiptLineItem({
    required this.type,
    required this.text,
    this.leftText,
    this.rightText,
    this.alignment = ReceiptHeaderAlignment.left,
    this.isBold = false,
    this.isDoubleSize = false,
    this.qrData,
  });
}

class ReceiptPrintDocument {
  final List<ReceiptLineItem> lines;
  final ReceiptPaperWidth paperWidth;
  final int charColumns;
  final ReceiptType receiptType;
  final String? sampleTitle;

  const ReceiptPrintDocument({
    required this.lines,
    required this.paperWidth,
    required this.charColumns,
    this.receiptType = ReceiptType.rentalBooking,
    this.sampleTitle,
  });

  int get totalLines => lines.length;

  int get totalCharacters {
    return lines.fold<int>(0, (sum, line) => sum + line.text.length);
  }
}


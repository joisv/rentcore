import 'currency_formatter.dart';

/// Input mode values supported by tenant collateral configurations.
class CollateralInputMode {
  const CollateralInputMode._();

  static const String vaultSlot = 'vault_slot';
  static const String cashDeposit = 'cash_deposit';
  static const String noteOnly = 'note_only';
  static const String none = 'none';

  static const List<String> editableModes = [
    vaultSlot,
    cashDeposit,
    noteOnly,
  ];

  static String normalize(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case cashDeposit:
        return cashDeposit;
      case noteOnly:
        return noteOnly;
      case none:
        return none;
      case vaultSlot:
      default:
        return vaultSlot;
    }
  }

  static String label(String mode) {
    switch (normalize(mode)) {
      case cashDeposit:
        return 'Deposit Tunai';
      case noteOnly:
        return 'Catatan / No. ID';
      case vaultSlot:
      default:
        return 'Slot Brankas';
    }
  }
}

/// Structured configurable collateral option for a tenant business.
class CollateralTypeOption {
  final String id;
  final String name;
  final String inputMode;
  final bool isActive;

  const CollateralTypeOption({
    required this.id,
    required this.name,
    required this.inputMode,
    this.isActive = true,
  });

  CollateralTypeOption copyWith({
    String? id,
    String? name,
    String? inputMode,
    bool? isActive,
  }) {
    return CollateralTypeOption(
      id: id ?? this.id,
      name: name ?? this.name,
      inputMode: inputMode ?? this.inputMode,
      isActive: isActive ?? this.isActive,
    );
  }

  factory CollateralTypeOption.fromJson(Map<dynamic, dynamic> json) {
    final name = (json['name']?.toString() ?? '').trim();
    final rawId = (json['id']?.toString() ?? '').trim();
    final fallbackId = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return CollateralTypeOption(
      id: rawId.isNotEmpty ? rawId : (fallbackId.isNotEmpty ? fallbackId : 'custom'),
      name: name.isNotEmpty ? name : 'Jaminan',
      inputMode: CollateralInputMode.normalize(json['input_mode']?.toString()),
      isActive: json['is_active'] != false && json['is_active'] != 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'input_mode': inputMode,
        'is_active': isActive,
      };
}

/// Default presets when a business has not customized collateral types yet.
const List<CollateralTypeOption> kDefaultCollateralTypes = [
  CollateralTypeOption(
    id: 'cash_deposit',
    name: 'Deposit Tunai',
    inputMode: CollateralInputMode.cashDeposit,
    isActive: true,
  ),
  CollateralTypeOption(
    id: 'ektp',
    name: 'e-KTP',
    inputMode: CollateralInputMode.vaultSlot,
    isActive: true,
  ),
  CollateralTypeOption(
    id: 'sim',
    name: 'SIM (A/C)',
    inputMode: CollateralInputMode.vaultSlot,
    isActive: true,
  ),
  CollateralTypeOption(
    id: 'stnk',
    name: 'STNK / BPKB',
    inputMode: CollateralInputMode.vaultSlot,
    isActive: true,
  ),
  CollateralTypeOption(
    id: 'student_id',
    name: 'Kartu Pelajar / KTM',
    inputMode: CollateralInputMode.noteOnly,
    isActive: true,
  ),
];

bool resolveEnableCollateral(Map<String, dynamic>? business) {
  if (business == null) return false;
  final raw = business['enable_collateral'];
  if (raw == null) return false;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final str = raw.toString().trim().toLowerCase();
  return str == 'true' || str == '1';
}

bool resolveRequireCollateral(Map<String, dynamic>? business) {
  if (business == null) return false;
  final raw = business['require_collateral'];
  if (raw == null) return false;
  if (raw is bool) return raw;
  if (raw is num) return raw != 0;
  final str = raw.toString().trim().toLowerCase();
  return str == 'true' || str == '1';
}

bool hasCollateralRecord(Map<String, dynamic>? booking) {
  if (booking == null) return false;
  final typeId = booking['collateral_type_id']?.toString().trim() ?? '';
  final typeName = booking['collateral_type_name']?.toString().trim() ?? '';
  final slot = booking['collateral_storage_slot']?.toString().trim() ?? '';
  final type = booking['collateral_type']?.toString().trim() ?? '';
  final deposit = parseCollateralDepositAmount(booking);

  if (deposit != null && deposit > 0) return true;
  if (typeId.isNotEmpty) return true;
  if (typeName.isNotEmpty && typeName != '-') return true;
  if (slot.isNotEmpty && slot != '-') return true;
  if (type.isNotEmpty && type != '-' && booking['collateral_secured'] == true) {
    return true;
  }
  return false;
}

List<CollateralTypeOption> resolveBusinessCollateralTypes(
  Map<String, dynamic>? business,
) {
  final raw = business?['collateral_types'];
  if (raw is List && raw.isNotEmpty) {
    final parsed = raw
        .whereType<Map>()
        .map((m) => CollateralTypeOption.fromJson(m))
        .where((o) => o.name.isNotEmpty && o.id.isNotEmpty)
        .toList();
    if (parsed.isNotEmpty) return parsed;
  }
  return List<CollateralTypeOption>.from(kDefaultCollateralTypes);
}

bool isNoCollateralRecord(Map<String, dynamic>? booking) {
  if (booking == null) return false;
  final typeId = booking['collateral_type_id']?.toString().trim();
  final typeName = booking['collateral_type_name']?.toString().trim();
  final type = booking['collateral_type']?.toString().trim();
  return typeId == 'none' ||
      typeName == 'Tanpa Jaminan' ||
      type == 'Tanpa Jaminan';
}

double? parseCollateralDepositAmount(Map<String, dynamic>? booking) {
  if (booking == null) return null;
  final raw = booking['collateral_deposit_amount'];
  if (raw == null) return null;
  final parsed = CurrencyFormatter.parse(raw);
  return parsed > 0 ? parsed : null;
}

/// Formats structured collateral summary (`"e-KTP • Brankas A, Slot 05"`,
/// `"Deposit Tunai • Rp 200.000"`, or `"Tanpa Jaminan"`), preserving
/// clean fallbacks for legacy bookings.
String formatCollateralSummary(
  Map<String, dynamic>? booking, {
  bool legacyIncludeTypeFallback = false,
}) {
  if (booking == null) return 'Brankas Cabang';
  if (isNoCollateralRecord(booking)) {
    return 'Tanpa Jaminan';
  }

  final typeId = booking['collateral_type_id']?.toString().trim();
  final typeName = (booking['collateral_type_name'] ??
          (typeId != null ? booking['collateral_type'] : null))
      ?.toString()
      .trim();
  final slot = booking['collateral_storage_slot']?.toString().trim();
  final deposit = parseCollateralDepositAmount(booking);

  if (deposit != null) {
    final formatted = CurrencyFormatter.format(deposit);
    if (typeName != null && typeName.isNotEmpty) {
      return '$typeName • $formatted';
    }
    return 'Deposit Tunai • $formatted';
  }

  if (typeName != null && typeName.isNotEmpty && slot != null && slot.isNotEmpty) {
    return '$typeName • $slot';
  }
  if (slot != null && slot.isNotEmpty) {
    return legacyIncludeTypeFallback ? 'KTP • $slot' : slot;
  }
  if (typeName != null && typeName.isNotEmpty) {
    return typeName;
  }
  return legacyIncludeTypeFallback ? 'KTP • Brankas Cabang' : 'Brankas Cabang';
}

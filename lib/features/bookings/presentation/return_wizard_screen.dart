import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/booking_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';

enum RentalDeviceCategory {
  apple,
  mobile,
  console,
  outdoor,
  general,
}

class ChecklistItemDef {
  final String key;
  final String label;

  const ChecklistItemDef({required this.key, required this.label});
}

class _ReturnAddonItem {
  final String key;
  final List<int> itemIds;
  final String name;
  final int quantity;

  const _ReturnAddonItem({
    required this.key,
    required this.itemIds,
    required this.name,
    required this.quantity,
  });
}

class ReturnWizardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;

  const ReturnWizardScreen({super.key, required this.booking});

  @override
  ConsumerState<ReturnWizardScreen> createState() => _ReturnWizardScreenState();
}

class _ReturnWizardScreenState extends ConsumerState<ReturnWizardScreen> {
  bool _accountCleared = false; // CRITICAL GUARD FOR APPLE
  bool _isQuarantined = false; // QUARANTINE GUARD
  final _staffNotesController = TextEditingController();

  String _conditionGrade = 'A';
  bool _isSubmitting = false;
  bool _payPenaltyNow = true;
  bool _enableWaiver = false;
  final _waiverAmountController = TextEditingController();
  final _waiverReasonController = TextEditingController();

  late final RentalDeviceCategory _category;
  late final List<ChecklistItemDef> _checklistDefs;
  final Map<String, bool> _checklistStates = {};
  late final List<_ReturnAddonItem> _addonItems;
  final Set<String> _checkedAddonKeys = {};

  @override
  void initState() {
    super.initState();
    _category = _resolveCategory(widget.booking);
    _checklistDefs = _getItemsForCategory(_category);
    for (final def in _checklistDefs) {
      _checklistStates[def.key] = true;
    }
    _addonItems = _extractAddonItems(widget.booking);
  }

  static List<_ReturnAddonItem> _extractAddonItems(Map<String, dynamic> booking) {
    final explicitAddons = booking['addons'];
    if (explicitAddons is List && explicitAddons.isNotEmpty) {
      final result = <_ReturnAddonItem>[];
      for (var i = 0; i < explicitAddons.length; i++) {
        final raw = explicitAddons[i];
        if (raw is! Map) continue;
        final name = (raw['name'] ?? raw['model_name'] ?? raw['title'] ?? 'Add-on')
            .toString()
            .trim();
        if (name.isEmpty) continue;
        final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
        final itemIds = <int>[];
        final rawIds = raw['item_ids'];
        if (rawIds is List) {
          for (final idVal in rawIds) {
            final parsed = (idVal as num?)?.toInt() ?? int.tryParse(idVal.toString());
            if (parsed != null) itemIds.add(parsed);
          }
        }
        final singleId = (raw['id'] as num?)?.toInt() ?? int.tryParse(raw['id']?.toString() ?? '');
        if (itemIds.isEmpty && singleId != null) {
          itemIds.add(singleId);
        }
        final key = (raw['model_id'] ?? raw['id'] ?? '${i}_$name').toString();
        result.add(
          _ReturnAddonItem(
            key: key,
            itemIds: itemIds,
            name: name,
            quantity: qty < 1 ? 1 : qty,
          ),
        );
      }
      if (result.isNotEmpty) return result;
    }

    final rawList = (booking['addon_items'] is List && (booking['addon_items'] as List).isNotEmpty)
        ? (booking['addon_items'] as List)
        : ((booking['items'] as List?) ?? const []);

    final grouped = <String, ({List<int> ids, String name, int quantity})>{};
    for (final raw in rawList) {
      if (raw is! Map) continue;
      final itemType = raw['item_type']?.toString().toLowerCase();
      final asset = raw['asset'] as Map?;
      final model = (asset?['model'] as Map?) ?? (raw['asset_model'] as Map?);
      final isAddon =
          booking['addon_items'] is List && (booking['addon_items'] as List).isNotEmpty
              ? true
              : (itemType == 'addon' ||
                    model?['is_addon'] == true ||
                    model?['is_addon'] == 1);
      if (!isAddon) continue;

      final name = (raw['name'] ??
              model?['name'] ??
              raw['asset_name'] ??
              asset?['asset_code'] ??
              'Add-on')
          .toString()
          .trim();
      if (name.isEmpty) continue;

      final modelKey = (model?['id'] ?? raw['asset_model_id'] ?? name.toLowerCase()).toString();
      final itemId = (raw['id'] as num?)?.toInt() ?? int.tryParse(raw['id']?.toString() ?? '');
      final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
      final existing = grouped[modelKey];
      if (existing == null) {
        grouped[modelKey] = (
          ids: itemId != null ? <int>[itemId] : <int>[],
          name: name,
          quantity: qty < 1 ? 1 : qty,
        );
      } else {
        if (itemId != null && !existing.ids.contains(itemId)) {
          existing.ids.add(itemId);
        }
        grouped[modelKey] = (
          ids: existing.ids,
          name: existing.name,
          quantity: existing.quantity + (qty < 1 ? 1 : qty),
        );
      }
    }

    return grouped.entries
        .map(
          (e) => _ReturnAddonItem(
            key: e.key,
            itemIds: e.value.ids,
            name: e.value.name,
            quantity: e.value.quantity,
          ),
        )
        .toList();
  }

  @override
  void dispose() {
    _staffNotesController.dispose();
    _waiverAmountController.dispose();
    _waiverReasonController.dispose();
    super.dispose();
  }

  static const List<String> _smartphoneCategoryTokens = [
    'smartphone',
    'handphone',
    'hp',
    'phone',
    'mobile',
  ];

  static bool _isSmartphoneCategory(String raw) {
    final normalized = raw.toLowerCase().trim();
    if (normalized.isEmpty) return false;
    if (_smartphoneCategoryTokens.contains(normalized)) return true;
    return RegExp(
      r'\b(smartphone|smartphones|handphone|handphones|hp|phone|phones|mobile|mobiles)\b',
    ).hasMatch(normalized);
  }

  static RentalDeviceCategory _resolveCategory(Map<String, dynamic> booking) {
    final items = (booking['items'] as List?) ?? [];
    final activeItem = booking['active_item'] as Map?;
    final directAsset = booking['asset'] as Map?;

    final candidates = <Map>[
      ?activeItem,
      ...items.whereType<Map>(),
      if (directAsset != null) {'asset': directAsset},
    ];

    if (candidates.isEmpty) {
      final cat = booking['category']?.toString().toLowerCase().trim() ?? '';
      if (cat.contains('iphone') || cat.contains('apple')) return RentalDeviceCategory.apple;
      if (cat.contains('ps') || cat.contains('game') || cat.contains('konsol')) return RentalDeviceCategory.console;
      if (cat.contains('outdoor') || cat.contains('tenda') || cat.contains('camp')) return RentalDeviceCategory.outdoor;
      if (_isSmartphoneCategory(cat)) return RentalDeviceCategory.mobile;
      return RentalDeviceCategory.general;
    }

    for (final it in candidates) {
      final asset = (it['asset'] as Map?) ?? (it == directAsset ? directAsset : null);
      final model = asset?['model'] as Map?;

      final rawCat = it['category'] ?? model?['category'] ?? asset?['category'];
      final catName = (rawCat is Map ? (rawCat['name'] ?? rawCat['slug'] ?? rawCat['code']) : rawCat)?.toString().toLowerCase().trim() ?? '';
      final catSlug = (rawCat is Map ? (rawCat['slug'] ?? rawCat['code'] ?? '') : '').toString().toLowerCase().trim();
      final brand = (model?['brand'] ?? it['brand'] ?? asset?['brand'] ?? '').toString().toLowerCase();
      final modelName = (model?['name'] ?? it['name'] ?? asset?['name'] ?? '').toString().toLowerCase();
      final assetCode = (asset?['asset_code'] ?? it['asset_code'] ?? '').toString().toLowerCase();

      // 1. Apple hardware
      if (brand == 'apple' ||
          catName == 'iphone' ||
          catName.contains('apple') ||
          modelName.contains('iphone') ||
          modelName.contains('ipad') ||
          modelName.contains('macbook') ||
          assetCode.startsWith('iph') ||
          assetCode.startsWith('app')) {
        return RentalDeviceCategory.apple;
      }

      // 2. PlayStation / Consoles
      if (catName.contains('konsol') ||
          catName.contains('console') ||
          catName.contains('game') ||
          catName.contains('playstation') ||
          (brand.contains('sony') && (modelName.contains('ps') || modelName.contains('playstation'))) ||
          brand.contains('nintendo') ||
          brand.contains('xbox') ||
          modelName.contains('playstation') ||
          modelName.contains('ps4') ||
          modelName.contains('ps5') ||
          modelName.contains('nintendo') ||
          modelName.contains('xbox') ||
          assetCode.startsWith('ps') ||
          assetCode.startsWith('swi')) {
        return RentalDeviceCategory.console;
      }

      // 3. Outdoor / Tents
      if (catName.contains('outdoor') ||
          catName.contains('camp') ||
          catName.contains('tenda') ||
          catName.contains('gunung') ||
          modelName.contains('tenda') ||
          modelName.contains('tent') ||
          modelName.contains('carrier') ||
          modelName.contains('sleeping bag') ||
          modelName.contains('flysheet') ||
          assetCode.startsWith('tnd') ||
          assetCode.startsWith('camp')) {
        return RentalDeviceCategory.outdoor;
      }

      // 4. Mobile / Smartphones (Android, generic smartphone/handphone/hp/phone/mobile categories)
      if (brand == 'samsung' ||
          brand == 'xiaomi' ||
          brand == 'oppo' ||
          brand == 'vivo' ||
          brand == 'google' ||
          brand == 'realme' ||
          brand == 'infinix' ||
          brand == 'poco' ||
          brand == 'asus' ||
          _isSmartphoneCategory(catName) ||
          _isSmartphoneCategory(catSlug) ||
          modelName.contains('galaxy') ||
          modelName.contains('pixel') ||
          modelName.contains('redmi') ||
          modelName.contains('poco') ||
          modelName.contains('realme') ||
          model?['requires_frp_check'] == true) {
        return RentalDeviceCategory.mobile;
      }
    }

    return RentalDeviceCategory.general;
  }

  static List<ChecklistItemDef> _getItemsForCategory(RentalDeviceCategory category) {
    switch (category) {
      case RentalDeviceCategory.apple:
      case RentalDeviceCategory.mobile:
        return const [
          ChecklistItemDef(key: 'screen_ok', label: 'Layar sentuh & kamera'),
          ChecklistItemDef(key: 'cable', label: 'Kabel charger'),
          ChecklistItemDef(key: 'adapter', label: 'Adaptor charger'),
        ];
      case RentalDeviceCategory.console:
        return const [
          ChecklistItemDef(key: 'controller', label: 'Controller / Gamepad'),
          ChecklistItemDef(key: 'hdmi_cable', label: 'Kabel HDMI'),
          ChecklistItemDef(key: 'power_cable', label: 'Kabel power'),
          ChecklistItemDef(key: 'console_chassis', label: 'Bodi konsol'),
        ];
      case RentalDeviceCategory.outdoor:
        return const [
          ChecklistItemDef(key: 'tent_poles', label: 'Frame & tiang tenda'),
          ChecklistItemDef(key: 'guy_lines', label: 'Pasak & tali tenda'),
          ChecklistItemDef(key: 'tent_fabric', label: 'Kain tenda & ritsleting'),
          ChecklistItemDef(key: 'carry_bag', label: 'Tas tenda (carry bag)'),
        ];
      case RentalDeviceCategory.general:
        return const [
          ChecklistItemDef(key: 'unit_operational', label: 'Unit berfungsi normal'),
          ChecklistItemDef(key: 'accessories_complete', label: 'Aksesoris standar lengkap'),
          ChecklistItemDef(key: 'body_intact', label: 'Bodi bebas kerusakan parah'),
        ];
    }
  }

  bool get _isAppleDevice => _category == RentalDeviceCategory.apple;
  bool get _isSmartphone =>
      _category == RentalDeviceCategory.apple ||
      _category == RentalDeviceCategory.mobile;
  bool get _hasAddons => _addonItems.isNotEmpty;
  bool get _allAddonsChecked =>
      !_hasAddons || _checkedAddonKeys.length == _addonItems.length;
  bool get _canSubmitReturn =>
      (!_isSmartphone || _accountCleared || _isQuarantined) && _allAddonsChecked;
  bool get _screenOk => _checklistStates['screen_ok'] ?? _checklistStates['unit_operational'] ?? true;
  bool get _cameraOk => _checklistStates['screen_ok'] ?? _checklistStates['unit_operational'] ?? true;
  bool get _cableReturned => _checklistStates['cable'] ?? _checklistStates['power_cable'] ?? _checklistStates['accessories_complete'] ?? true;
  bool get _adapterReturned => _checklistStates['adapter'] ?? _checklistStates['hdmi_cable'] ?? _checklistStates['accessories_complete'] ?? true;

  String _formatOverdueDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0 && mins > 0) {
      return '${hours}j ${mins}m';
    } else if (hours > 0) {
      return '${hours}j';
    } else {
      return '${mins}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final customer = booking['customer'] ?? {};
    final endAt = booking['end_at'] != null ? DateTime.tryParse(booking['end_at']) : null;
    final now = DateTime.now();
    final activeBusiness = ref.watch(businessProvider).activeBusiness;

    // Resolve cascading late-fee policy (contract snapshot -> unit -> model -> business)
    int lateMinutes = 0;
    double billableHours = 0.0;
    double hourlyLateRate = 15000.0;
    double calculatedPenalty = 0.0;
    int gracePeriodMinutes = 60;
    String roundingMode = 'hourly_ceil';
    double? dailyRateCap;
    bool wasCapped = false;

    final activeItem = booking['active_item'] as Map?;
    final items = (booking['items'] as List?) ?? const [];
    final Map? primaryItem = activeItem ??
        items.cast<Map?>().firstWhere(
          (it) =>
              it != null &&
              (it['item_type'] == 'primary' || it['item_type'] == null) &&
              (it['status'] == 'active' || it['status'] == null),
          orElse: () => items.isNotEmpty && items.first is Map ? items.first as Map : null,
        );

    final rateSnap = (primaryItem?['rate_snapshot'] as Map?) ??
        (activeItem?['rate_snapshot'] as Map?);
    final assetMap = primaryItem?['asset'] as Map?;
    final modelMap = (assetMap?['model'] as Map?) ??
        (primaryItem?['asset_model'] as Map?) ??
        (booking['asset_model'] as Map?);

    // 1. Grace period
    final rawAppliedGrace = primaryItem?['applied_grace_period_minutes'] ??
        rateSnap?['applied_grace_period_minutes'];
    if (rawAppliedGrace != null) {
      gracePeriodMinutes = int.tryParse(rawAppliedGrace.toString()) ?? 15;
    } else if (activeBusiness != null &&
        activeBusiness.containsKey('return_grace_period_minutes') &&
        activeBusiness['return_grace_period_minutes'] != null) {
      gracePeriodMinutes =
          int.tryParse(activeBusiness['return_grace_period_minutes'].toString()) ?? 15;
    }

    // 2. Rounding mode
    final rawRoundingMode = (primaryItem?['applied_late_fee_rounding_mode'] ??
            rateSnap?['applied_late_fee_rounding_mode'] ??
            activeBusiness?['late_fee_rounding_mode'])
        ?.toString();
    if (rawRoundingMode == 'half_hourly_ceil' || rawRoundingMode == 'hourly_ceil') {
      roundingMode = rawRoundingMode!;
    }

    // 3. Hourly late rate (applied snapshot -> unit -> model -> business -> legacy tier rate)
    final rawAppliedRate = primaryItem?['applied_hourly_late_fee'] ??
        rateSnap?['applied_hourly_late_fee'];
    if (rawAppliedRate != null) {
      hourlyLateRate = double.tryParse(rawAppliedRate.toString()) ?? 0.0;
    } else if (assetMap != null && assetMap['hourly_late_fee'] != null) {
      hourlyLateRate = double.tryParse(assetMap['hourly_late_fee'].toString()) ?? 0.0;
    } else if (modelMap != null && modelMap['hourly_late_fee'] != null) {
      hourlyLateRate = double.tryParse(modelMap['hourly_late_fee'].toString()) ?? 0.0;
    } else if (activeBusiness != null &&
        activeBusiness['default_hourly_late_fee'] != null) {
      hourlyLateRate =
          double.tryParse(activeBusiness['default_hourly_late_fee'].toString()) ?? 0.0;
    } else if (rateSnap != null && rateSnap['extension_hourly_rate'] != null) {
      hourlyLateRate =
          double.tryParse(rateSnap['extension_hourly_rate'].toString()) ?? 15000.0;
    } else {
      final tiers = modelMap?['pricing_tiers'] as List?;
      if (tiers != null && tiers.isNotEmpty && tiers.first is Map) {
        final firstTier = tiers.first as Map;
        if (firstTier['extension_hourly_rate'] != null) {
          hourlyLateRate =
              double.tryParse(firstTier['extension_hourly_rate'].toString()) ?? 15000.0;
        }
      }
    }

    // 4. Daily rate cap
    final hasSnapshotCapKey =
        (primaryItem != null && primaryItem.containsKey('applied_daily_rate_cap')) ||
        (rateSnap != null && rateSnap.containsKey('applied_daily_rate_cap'));
    if (hasSnapshotCapKey) {
      final rawCap = primaryItem?['applied_daily_rate_cap'] ??
          rateSnap?['applied_daily_rate_cap'];
      dailyRateCap = rawCap != null ? double.tryParse(rawCap.toString()) : null;
    } else if (activeBusiness?['cap_late_fee_at_daily_rate'] == true) {
      final tiers = modelMap?['pricing_tiers'] as List?;
      if (tiers != null) {
        for (final t in tiers.whereType<Map>()) {
          final isOneDay = (t['duration_unit'] == 'day' &&
                  int.tryParse(t['duration_value']?.toString() ?? '') == 1) ||
              int.tryParse(t['duration_hours']?.toString() ?? '') == 24;
          if (isOneDay && t['price'] != null) {
            final parsedDaily = double.tryParse(t['price'].toString());
            if (parsedDaily != null && parsedDaily > 0) {
              dailyRateCap = parsedDaily;
              break;
            }
          }
        }
      }
    }

    if (endAt != null && now.isAfter(endAt)) {
      lateMinutes = now.difference(endAt).inMinutes;
      if (lateMinutes > gracePeriodMinutes) {
        final chargeableMinutes = lateMinutes - gracePeriodMinutes;
        if (roundingMode == 'half_hourly_ceil') {
          billableHours = (chargeableMinutes / 30).ceil() * 0.5;
        } else {
          billableHours = (chargeableMinutes / 60).ceil().toDouble();
        }
        calculatedPenalty = billableHours * hourlyLateRate;

        if (dailyRateCap != null && dailyRateCap > 0 && calculatedPenalty > 0) {
          final fullCycles = billableHours ~/ 24;
          final remHours = math.max(0.0, billableHours - (fullCycles * 24));
          final fullCycleCost = math.min(24 * hourlyLateRate, dailyRateCap);
          final remCycleCost = math.min(remHours * hourlyLateRate, dailyRateCap);
          final cappedPenalty = (fullCycles * fullCycleCost) + remCycleCost;
          if (cappedPenalty < calculatedPenalty) {
            calculatedPenalty = cappedPenalty;
            wasCapped = true;
          }
        }
      }
    }

    final rawWaivedAmount = _enableWaiver
        ? CurrencyFormatter.parse(_waiverAmountController.text.trim())
        : 0.0;
    final double waivedAmount =
        math.max(0.0, math.min(calculatedPenalty, rawWaivedAmount));
    final double penaltyAmount = math.max(0.0, calculatedPenalty - waivedAmount);
    final String billableHoursLabel = billableHours % 1 == 0
        ? billableHours.toInt().toString()
        : billableHours.toStringAsFixed(1);
    final bool isLateBeyondGrace = lateMinutes > gracePeriodMinutes;

    final collateralSlot = booking['collateral_storage_slot'] ?? 'Brankas Cabang';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: const RentCoreBackButton(),
        titleSpacing: 0,
        title: Text(
          'Pengembalian • ${booking['booking_code'] ?? ''}',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF0F172A),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFF1F5F9),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Streamlined Customer & Collateral Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RINGKASAN PENYEWA & JAMINAN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Penyewa',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          customer['name'] ?? 'Pelanggan',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jaminan',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Jaminan: KTP • $collateralSlot',
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0F172A),
                          ),
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // Return Timestamps & Overtime Summary
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'WAKTU PENGEMBALIAN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Jadwal Selesai Sewa',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormatter.formatFull(endAt),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Waktu Fisik Kembali',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormatter.formatFull(now),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (lateMinutes > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            !isLateBeyondGrace
                                ? 'Terlambat (Grace Period Bebas Denda)'
                                : 'Denda Keterlambatan (${_formatOverdueDuration(lateMinutes)})',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isLateBeyondGrace
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFB45309),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(penaltyAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: isLateBeyondGrace
                                ? const Color(0xFFDC2626)
                                : const Color(0xFF059669),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            // Conditional Account Clearance Section (Rendered ONLY for smartphones: iOS & Android)
            if (_isSmartphone) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Pemeriksaan Akun Perangkat',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _accountCleared
                                ? const Color(0xFFECFDF5)
                                : (_isQuarantined
                                    ? const Color(0xFFFFFBEB)
                                    : const Color(0xFFFEF2F2)),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _accountCleared
                                  ? const Color(0xFFA7F3D0)
                                  : (_isQuarantined
                                      ? const Color(0xFFFDE68A)
                                      : const Color(0xFFFECACA)),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _accountCleared
                                ? 'Terverifikasi'
                                : (_isQuarantined ? 'Karantina' : 'Wajib'),
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _accountCleared
                                  ? const Color(0xFF047857)
                                  : (_isQuarantined
                                      ? const Color(0xFFB45309)
                                      : const Color(0xFFDC2626)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Material(
                      type: MaterialType.transparency,
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        activeThumbColor: Colors.white,
                        activeTrackColor: const Color(0xFF059669),
                        title: const Text(
                          'Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan',
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Text(
                            'Wajib dipastikan sebelum unit diterima kembali',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        value: _accountCleared,
                        onChanged: (val) => setState(() {
                          _accountCleared = val;
                          if (val) _isQuarantined = false;
                        }),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        setState(() {
                          _isQuarantined = !_isQuarantined;
                          if (_isQuarantined) _accountCleared = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: _isQuarantined
                              ? const Color(0xFFFFFBEB)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _isQuarantined
                                ? const Color(0xFFFDE68A)
                                : const Color(0xFFE2E8F0),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isQuarantined
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: _isQuarantined
                                  ? const Color(0xFFB45309)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unit Terkunci / Lupa Sandi (Masuk Karantina)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: _isQuarantined
                                          ? const Color(0xFF92400E)
                                          : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Unit akan dialihkan ke status Maintenance. Wajib mengisi catatan staf di bawah.',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: _isQuarantined
                                          ? const Color(0xFFB45309)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],

            // Physical Condition Checklist & Grade Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'KONDISI & KELENGKAPAN',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Kondisi & Kelengkapan',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: ['A', 'B', 'C'].map((grade) {
                        final isSel = _conditionGrade == grade;
                        return Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _conditionGrade = grade),
                            borderRadius: BorderRadius.circular(8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSel ? Colors.white : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                border: isSel
                                    ? Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      )
                                    : null,
                              ),
                              child: Text(
                                'Grade $grade',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight:
                                      isSel ? FontWeight.w600 : FontWeight.w500,
                                  color: isSel
                                      ? const Color(0xFF0F172A)
                                      : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Theme(
                    data: Theme.of(context).copyWith(
                      checkboxTheme: CheckboxThemeData(
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return const Color(0xFF0F172A);
                          }
                          return Colors.transparent;
                        }),
                        checkColor: WidgetStateProperty.all(Colors.white),
                        side: const BorderSide(
                          color: Color(0xFFCBD5E1),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    child: Material(
                      type: MaterialType.transparency,
                      child: Column(
                        children: _checklistDefs.map((item) {
                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              item.label,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            value: _checklistStates[item.key] ?? false,
                            onChanged: (v) => setState(
                              () => _checklistStates[item.key] = v ?? false,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),

            if (_hasAddons) ...[
              Padding(
                key: const Key('addon_checklist_card'),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Kelengkapan Add-on (${_checkedAddonKeys.length}/${_addonItems.length})',
                            key: const Key('addon_checklist_header'),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (!_allAddonsChecked)
                          InkWell(
                            key: const Key('addon_check_all_button'),
                            onTap: () {
                              setState(() {
                                _checkedAddonKeys
                                    .addAll(_addonItems.map((a) => a.key));
                              });
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              child: Text(
                                'Centang Semua',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Theme(
                      data: Theme.of(context).copyWith(
                        checkboxTheme: CheckboxThemeData(
                          fillColor: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.selected)) {
                              return const Color(0xFF0F172A);
                            }
                            return Colors.transparent;
                          }),
                          checkColor: WidgetStateProperty.all(Colors.white),
                          side: const BorderSide(
                            color: Color(0xFFCBD5E1),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                      child: Material(
                        type: MaterialType.transparency,
                        child: Column(
                          children: _addonItems.map((addon) {
                            final isChecked =
                                _checkedAddonKeys.contains(addon.key);
                            return CheckboxListTile(
                              key: Key('addon_checkbox_${addon.key}'),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: Text(
                                '${addon.name} • ${addon.quantity}x',
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              value: isChecked,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _checkedAddonKeys.add(addon.key);
                                  } else {
                                    _checkedAddonKeys.remove(addon.key);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            ],

            // Staff Notes / Quarantine Follow-Up (Flat #F8FAFC Input + External Label)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isQuarantined
                        ? 'Catatan Staf (Wajib)'
                        : 'Catatan Staf (Opsional)',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _isQuarantined
                          ? const Color(0xFFB45309)
                          : const Color(0xFF475569),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _staffNotesController,
                    maxLines: 3,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: _isQuarantined
                          ? 'Wajib: Catat alasan karantina, kontak pelanggan, dan batas waktu tindak lanjut akun...'
                          : 'Catatan kondisi tambahan atau pesan pengembalian...',
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF94A3B8),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0F172A),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Penalty Payment Section (Rendered when calculatedPenalty > 0)
            if (calculatedPenalty > 0) ...[
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Penyelesaian Denda',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(penaltyAmount),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFFECACA),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Telat $lateMinutes menit - Toleransi $gracePeriodMinutes menit = $billableHoursLabel jam × ${CurrencyFormatter.format(hourlyLateRate)}',
                            key: const Key('late_fee_breakdown_formula'),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Denda Hitungan Sistem',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(calculatedPenalty),
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Grace period',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$gracePeriodMinutes menit bebas biaya',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF64748B),
                                ),
                                textAlign: TextAlign.end,
                              ),
                            ],
                          ),
                          if (wasCapped && dailyRateCap != null) ...[
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Batas Maksimal Harian',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Dibatasi ${CurrencyFormatter.format(dailyRateCap)}/hari',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFB45309),
                                  ),
                                  textAlign: TextAlign.end,
                                ),
                              ],
                            ),
                          ],
                          if (_enableWaiver && waivedAmount > 0) ...[
                            const Divider(
                              height: 14,
                              color: Color(0xFFFECACA),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Keringanan / Diskon',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF047857),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '- ${CurrencyFormatter.format(waivedAmount)}',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: Color(0xFF047857),
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      key: const Key('waiver_toggle'),
                      onTap: () => setState(() {
                        _enableWaiver = !_enableWaiver;
                        if (!_enableWaiver) {
                          _waiverAmountController.clear();
                          _waiverReasonController.clear();
                        }
                      }),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Icon(
                              _enableWaiver
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: _enableWaiver
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Beri Keringanan / Bebaskan Denda',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_enableWaiver) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              key: const Key('waiver_amount_input'),
                              controller: _waiverAmountController,
                              keyboardType: TextInputType.number,
                              onChanged: (_) => setState(() {}),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Nominal Keringanan',
                                prefixText: 'Rp ',
                                isDense: true,
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                    color: Color(0xFF0F172A),
                                    width: 1.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ActionChip(
                            key: const Key('waiver_full_chip'),
                            backgroundColor: const Color(0xFFF8FAFC),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            label: const Text(
                              'Bebaskan 100%',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                _waiverAmountController.text =
                                    calculatedPenalty.toInt().toString();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        key: const Key('waiver_reason_input'),
                        controller: _waiverReasonController,
                        maxLines: 2,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        decoration: InputDecoration(
                          labelText: 'Alasan Keringanan / Pembebasan (Wajib) *',
                          hintText:
                              'Contoh: Pelanggan konfirmasi macet via admin',
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Color(0xFF0F172A),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                    if (penaltyAmount > 0) ...[
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => setState(() => _payPenaltyNow = true),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: _payPenaltyNow
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _payPenaltyNow
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _payPenaltyNow
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: _payPenaltyNow
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bayar Sekarang',
                                  style: TextStyle(
                                    color: _payPenaltyNow
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => setState(() => _payPenaltyNow = false),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: !_payPenaltyNow
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: !_payPenaltyNow
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                !_payPenaltyNow
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_unchecked,
                                color: !_payPenaltyNow
                                    ? Colors.white
                                    : const Color(0xFF64748B),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Bayar Nanti (Catat ke Tagihan)',
                                  style: TextStyle(
                                    color: !_payPenaltyNow
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!_allAddonsChecked)
                  const Text(
                    'Centang kelengkapan add-on untuk melanjutkan',
                    key: Key('addon_incomplete_helper'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    'Jaminan fisik: $collateralSlot',
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: (_isSubmitting || !_canSubmitReturn)
                        ? null
                        : () => _processReturn(
                              penaltyAmount,
                              waivedAmount: waivedAmount,
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFF1F5F9),
                      disabledForegroundColor: const Color(0xFF94A3B8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Selesaikan Pengembalian',
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _processReturn(double penaltyAmount, {double waivedAmount = 0.0}) async {
    if (!_allAddonsChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pastikan semua add-on dikembalikan lengkap.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_enableWaiver && waivedAmount > 0 && _waiverReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alasan keringanan / pembebasan denda wajib diisi.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_isSmartphone && !_accountCleared && !_isQuarantined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pastikan akun perangkat (iCloud / Google / FRP) telah dikeluarkan sebelum menyelesaikan pengembalian, atau pilih Karantina Unit!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_isQuarantined && _staffNotesController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Catatan staf wajib diisi jika perangkat dikarantina untuk mendokumentasikan tindak lanjut.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final inspectionTime = DateTime.now().toUtc();
    final isApple = _category == RentalDeviceCategory.apple;
    final isMobile = _category == RentalDeviceCategory.mobile;

    final categoryChecklist = <String, dynamic>{};
    if (isApple) {
      categoryChecklist['icloud_removed'] = _accountCleared;
      categoryChecklist['frp_cleared'] = _accountCleared;
      categoryChecklist['account_removed'] = _accountCleared;
      categoryChecklist['account_quarantined'] = _isQuarantined;
      categoryChecklist['account_status'] = _accountCleared ? 'cleared' : (_isQuarantined ? 'quarantined' : 'unverified');
      categoryChecklist['device_platform'] = 'ios';
      categoryChecklist['screen_ok'] = _screenOk;
      categoryChecklist['camera_ok'] = _cameraOk;
    } else if (isMobile) {
      categoryChecklist['frp_removed'] = _accountCleared;
      categoryChecklist['google_account_removed'] = _accountCleared;
      categoryChecklist['frp_cleared'] = _accountCleared;
      categoryChecklist['account_removed'] = _accountCleared;
      categoryChecklist['account_quarantined'] = _isQuarantined;
      categoryChecklist['account_status'] = _accountCleared ? 'cleared' : (_isQuarantined ? 'quarantined' : 'unverified');
      categoryChecklist['device_platform'] = 'android';
      categoryChecklist['screen_ok'] = _screenOk;
      categoryChecklist['camera_ok'] = _cameraOk;
    }
    // Add all specific inspection items for this category
    for (final item in _getItemsForCategory(_category)) {
      categoryChecklist[item.key] = _checklistStates[item.key] ?? true;
    }

    final categoryAccessories = <String, dynamic>{};
    if (isApple || isMobile) {
      categoryAccessories['cable'] = _cableReturned;
      categoryAccessories['adapter'] = _adapterReturned;
    } else if (_category == RentalDeviceCategory.console) {
      categoryAccessories['controller'] = _checklistStates['controller'] ?? true;
      categoryAccessories['hdmi_cable'] = _checklistStates['hdmi_cable'] ?? true;
      categoryAccessories['power_cable'] = _checklistStates['power_cable'] ?? true;
    } else if (_category == RentalDeviceCategory.outdoor) {
      categoryAccessories['tent_poles'] = _checklistStates['tent_poles'] ?? true;
      categoryAccessories['guy_lines'] = _checklistStates['guy_lines'] ?? true;
      categoryAccessories['carry_bag'] = _checklistStates['carry_bag'] ?? true;
    } else {
      categoryAccessories['accessories_complete'] = _checklistStates['accessories_complete'] ?? true;
    }

    final waiveReason = _waiverReasonController.text.trim();
    final returnedAddonIds = _addonItems.expand((a) => a.itemIds).toList();
    final payload = <String, dynamic>{
      'returned_at': inspectionTime.toIso8601String(),
      'condition_grade': _conditionGrade,
      'late_fee': penaltyAmount,
      'total_penalty': penaltyAmount,
      'penalty_amount': penaltyAmount,
      if (_enableWaiver && waivedAmount > 0) ...{
        'waived_late_fee': waivedAmount,
        'late_fee_discount': waivedAmount,
        'late_fee_waive_reason': waiveReason,
      },
      'staff_notes': _staffNotesController.text.trim().isEmpty ? null : _staffNotesController.text.trim(),
      'checklist_results': categoryChecklist,
      'accessories_returned': categoryAccessories,
      if (_hasAddons) 'addons_returned': true,
      if (_hasAddons && returnedAddonIds.isNotEmpty)
        'returned_addon_ids': returnedAddonIds,
      if (isApple || isMobile) 'frp_cleared': _accountCleared,
      if (isApple || isMobile) 'account_removed': _accountCleared,
    };

    if (penaltyAmount > 0 && _payPenaltyNow) {
      // 1. Counter settlement: Launch Shared Payment Page FIRST to settle penalty atomically.
      final result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            paymentContext: PaymentContext.penalty(
              booking: widget.booking,
              penaltyDue: penaltyAmount,
              extraPayload: {
                'is_return_workflow': true,
                'return_payload': payload,
                'penalty_amount': penaltyAmount,
                'late_fee': penaltyAmount,
                'total_penalty': penaltyAmount,
                if (isApple || isMobile) 'frp_cleared': _accountCleared,
                if (isApple || isMobile) 'account_removed': _accountCleared,
              },
            ),
          ),
        ),
      );

      // If user aborted/closed with X or payment failed, DO NOT mark as returned!
      if (result == null || !result.isSuccess) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pembayaran denda dibatalkan. Pengembalian unit belum diproses.'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
        return;
      }

      // Succeeded: Unit returned and penalty paid atomically in one transaction
      ref.invalidate(bookingsListProvider);
      ref.invalidate(closingSummaryProvider);

      if (mounted) {
        _showReturnSuccessDialog(penaltyAmount, true);
      }
      return;
    }

    // 2. On-time return (penaltyAmount <= 0) OR explicit cashier deferral (_payPenaltyNow == false)
    setState(() => _isSubmitting = true);

    try {
      final inspection = await ref.read(bookingRepositoryProvider).processReturn(widget.booking['id'], payload);
      ref.invalidate(bookingsListProvider);
      ref.invalidate(closingSummaryProvider);

      // Server-persisted penalty is authoritative (client value was only a preview).
      final serverPenalty = inspection['total_penalty'];
      if (serverPenalty != null) {
        penaltyAmount = CurrencyFormatter.parse(serverPenalty);
      }

      if (mounted) {
        _showReturnSuccessDialog(penaltyAmount, false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses kembali: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReturnSuccessDialog(double penaltyAmount, bool penaltyPaid) {
    final collateralSlot = widget.booking['collateral_storage_slot'] ?? 'Brankas Cabang';
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  key: const Key('return_success_squircle_badge'),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFA7F3D0),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_rounded,
                    size: 26,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Unit Berhasil Kembali',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                penaltyPaid
                    ? 'Pemeriksaan pengembalian selesai dan unit siap disewakan kembali. Denda keterlambatan berhasil dibayar & tercatat di revenue.'
                    : (penaltyAmount > 0
                        ? 'Pemeriksaan pengembalian selesai dan unit siap disewakan kembali. Denda keterlambatan dicatat ke kasir (belum lunas).'
                        : 'Pemeriksaan pengembalian selesai dan unit siap disewakan kembali.'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Kembalikan jaminan: $collateralSlot',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF334155),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(
                            color: Color(0xFFE2E8F0),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        icon: const Icon(Icons.print_outlined, size: 17),
                        label: const Text(
                          'Cetak Bukti',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                        onPressed: () {
                          final printerService = ThermalPrinterService();
                          final printerSettings =
                              ref.read(printerProvider).settings;
                          final bizState = ref.read(businessProvider);
                          final shopName = bizState.resolvedStoreName;
                          final branchName =
                              bizState.resolvedBranchName.isNotEmpty
                                  ? bizState.resolvedBranchName
                                  : 'Cabang Utama';
                          final branchAddress = bizState.resolvedBranchAddress;
                          final branchPhone = bizState.resolvedBranchPhone;
                          final checklistSummary = _isQuarantined
                              ? 'Status: Karantina (Maintenance)'
                              : (_isSmartphone
                                  ? (_isAppleDevice
                                      ? 'Status: Bersih (iCloud Logout)'
                                      : 'Status: Bersih (Akun Google/FRP Logout)')
                                  : 'Status: Fisik Diperiksa');
                          final accessoriesSummary = _checklistDefs
                              .map(
                                (d) =>
                                    '${d.label}: ${_checklistStates[d.key] == true ? "OK" : "Kurang"}',
                              )
                              .join(' • ');

                          final model = ReceiptDataModel(
                            type: ReceiptType.rentalReturn,
                            title: 'BUKTI PENGEMBALIAN UNIT',
                            shopName: shopName.isNotEmpty ? shopName : null,
                            branchName: branchName,
                            branchAddress:
                                branchAddress.isNotEmpty ? branchAddress : null,
                            branchPhone:
                                branchPhone.isNotEmpty ? branchPhone : null,
                            bookingCode:
                                widget.booking['booking_code']?.toString() ??
                                '',
                            customerName: widget.booking['customer']?['name']
                                    ?.toString() ??
                                'Pelanggan',
                            unitName:
                                widget.booking['asset']?['name']?.toString() ??
                                'Perangkat Gadget',
                            conditionGrade: 'Grade $_conditionGrade',
                            checklistNotes: checklistSummary,
                            accessoriesNotes: accessoriesSummary,
                            penaltyAmount: penaltyPaid ? penaltyAmount : 0.0,
                            paymentMethod: penaltyPaid ? 'Lunas Denda' : null,
                            totalAmount: penaltyPaid ? penaltyAmount : 0.0,
                            transactedAt: DateTime.now()
                                .toString()
                                .substring(0, 16),
                          );
                          final escposBytes =
                              printerService.buildRentalReturnSlipBytes(
                            model,
                            printerSettings,
                          );
                          showDialog(
                            context: context,
                            builder: (dCtx) => ThermalReceiptPreviewDialog(
                              title: 'Bukti Pengembalian',
                              shopName: shopName.isNotEmpty ? shopName : null,
                              branchName: branchName,
                              branchAddress: branchAddress.isNotEmpty
                                  ? branchAddress
                                  : null,
                              branchPhone:
                                  branchPhone.isNotEmpty ? branchPhone : null,
                              escposBytes: escposBytes,
                              qrData: widget.booking['booking_code']?.toString(),
                              content: Column(
                                children: [
                                  const Text(
                                    'BUKTI PENGEMBALIAN UNIT',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'Kode: ${widget.booking['booking_code'] ?? "-"}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'Pelanggan: ${widget.booking['customer']?['name'] ?? "-"}',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  Text(
                                    'Kondisi: Grade $_conditionGrade',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                  const Divider(height: 16),
                                  Text(
                                    'Jaminan Fisik ($collateralSlot) Telah Diserahkan Kembali',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 11,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F172A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                        },
                        child: const Text(
                          'Selesai',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

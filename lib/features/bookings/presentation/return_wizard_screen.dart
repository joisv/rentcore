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

  late final RentalDeviceCategory _category;
  late final List<ChecklistItemDef> _checklistDefs;
  final Map<String, bool> _checklistStates = {};

  @override
  void initState() {
    super.initState();
    _category = _resolveCategory(widget.booking);
    _checklistDefs = _getItemsForCategory(_category);
    for (final def in _checklistDefs) {
      _checklistStates[def.key] = true;
    }
  }

  @override
  void dispose() {
    _staffNotesController.dispose();
    super.dispose();
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
      final cat = booking['category']?.toString().toLowerCase() ?? '';
      if (cat.contains('iphone') || cat.contains('apple')) return RentalDeviceCategory.apple;
      if (cat.contains('phone') || cat.contains('hp')) return RentalDeviceCategory.mobile;
      if (cat.contains('ps') || cat.contains('game') || cat.contains('konsol')) return RentalDeviceCategory.console;
      if (cat.contains('outdoor') || cat.contains('tenda') || cat.contains('camp')) return RentalDeviceCategory.outdoor;
      return RentalDeviceCategory.general;
    }

    for (final it in candidates) {
      final asset = (it['asset'] as Map?) ?? (it == directAsset ? directAsset : null);
      final model = asset?['model'] as Map?;

      final rawCat = it['category'] ?? model?['category'] ?? asset?['category'];
      final catName = (rawCat is Map ? (rawCat['name'] ?? rawCat['slug'] ?? rawCat['code']) : rawCat)?.toString().toLowerCase() ?? '';
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

      // 4. Mobile / Phones (Android, etc.)
      if (brand == 'samsung' ||
          brand == 'xiaomi' ||
          brand == 'oppo' ||
          brand == 'vivo' ||
          brand == 'google' ||
          catName.contains('phone') ||
          catName.contains('hp') ||
          catName.contains('smartphone') ||
          modelName.contains('galaxy') ||
          modelName.contains('pixel') ||
          modelName.contains('redmi')) {
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

    // Calculate late penalty (60-minute grace period formula with dynamic hourly rate)
    int lateMinutes = 0;
    int billableHours = 0;
    double hourlyLateRate = 15000.0;
    double penaltyAmount = 0.0;

    // Resolve dynamic hourly late rate from booking / model pricing tier
    final activeItem = booking['active_item'];
    if (activeItem != null && activeItem['rate_snapshot'] != null && activeItem['rate_snapshot']['extension_hourly_rate'] != null) {
      hourlyLateRate = double.tryParse(activeItem['rate_snapshot']['extension_hourly_rate'].toString()) ?? 15000.0;
    } else {
      final items = (booking['items'] as List?) ?? [];
      for (final it in items) {
        final rateSnap = it['rate_snapshot'];
        if (rateSnap != null && rateSnap['extension_hourly_rate'] != null) {
          hourlyLateRate = double.tryParse(rateSnap['extension_hourly_rate'].toString()) ?? hourlyLateRate;
          break;
        }
        final tiers = it['asset']?['model']?['pricing_tiers'] as List?;
        if (tiers != null && tiers.isNotEmpty) {
          final firstTier = tiers.first;
          if (firstTier['extension_hourly_rate'] != null) {
            hourlyLateRate = double.tryParse(firstTier['extension_hourly_rate'].toString()) ?? hourlyLateRate;
            break;
          }
        }
      }
    }

    if (endAt != null && now.isAfter(endAt)) {
      lateMinutes = now.difference(endAt).inMinutes;
      if (lateMinutes > 60) {
        billableHours = ((lateMinutes - 60) / 60).ceil();
        penaltyAmount = billableHours * hourlyLateRate;
      }
    }

    final collateralSlot = booking['collateral_storage_slot'] ?? 'Brankas Cabang';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RentCoreAppBar(
        title: 'Pengembalian: ${booking['booking_code']}',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer & Slot Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer['name'] ?? 'Pelanggan',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Jaminan: KTP ($collateralSlot)',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Overtime Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lateMinutes > 60 ? AppColors.dangerLight : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: lateMinutes > 60 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jadwal Selesai Sewa:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormatter.formatFull(endAt),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Waktu Fisik Kembali:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          DateFormatter.formatFull(now),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                  if (lateMinutes > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            lateMinutes <= 60
                                ? 'Terlambat (Grace Period Bebas Denda):'
                                : 'Denda Keterlambatan (${_formatOverdueDuration(lateMinutes)}):',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: lateMinutes > 60 ? AppColors.danger : AppColors.warning,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(penaltyAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: lateMinutes > 60 ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Conditional iCloud Check Card (Only rendered for Apple / iPhone hardware)
            if (_isAppleDevice) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _accountCleared
                      ? AppColors.successLight
                      : (_isQuarantined ? Colors.amber.withValues(alpha: 0.15) : AppColors.dangerLight),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _accountCleared
                        ? AppColors.success
                        : (_isQuarantined ? Colors.amber.shade700 : AppColors.danger),
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Pemeriksaan Akun iCloud',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _accountCleared
                                ? AppColors.success.withValues(alpha: 0.15)
                                : (_isQuarantined ? Colors.amber.shade100 : AppColors.danger.withValues(alpha: 0.15)),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _accountCleared
                                  ? AppColors.success
                                  : (_isQuarantined ? Colors.amber.shade700 : AppColors.danger),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            _accountCleared ? 'Selesai' : (_isQuarantined ? 'Karantina' : 'Wajib'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _accountCleared
                                  ? AppColors.success
                                  : (_isQuarantined ? Colors.amber.shade900 : AppColors.danger),
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
                        title: const Text(
                          'iCloud & Find My telah di-logout',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        value: _accountCleared,
                        onChanged: (val) => setState(() {
                          _accountCleared = val;
                          if (val) _isQuarantined = false;
                        }),
                      ),
                    ),
                    const Divider(height: 16),
                    InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        setState(() {
                          _isQuarantined = !_isQuarantined;
                          if (_isQuarantined) _accountCleared = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: _isQuarantined ? Colors.amber.withValues(alpha: 0.25) : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _isQuarantined ? Colors.amber.shade700 : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _isQuarantined ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: _isQuarantined ? Colors.amber.shade900 : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Unit Terkunci / Lupa Sandi (Masuk Karantina)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _isQuarantined ? Colors.amber.shade900 : AppColors.obsidian,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Unit akan dialihkan ke status Maintenance. Wajib mengisi catatan staf di bawah.',
                                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
              const SizedBox(height: 16),
            ],

            // Physical Condition Checklist
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Kondisi & Kelengkapan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ['A', 'B', 'C'].map((grade) {
                      final isSel = _conditionGrade == grade;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            onTap: () => setState(() => _conditionGrade = grade),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel ? AppColors.obsidian : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSel ? AppColors.obsidian : AppColors.border,
                                  width: isSel ? 1.5 : 1,
                                ),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                'Grade $grade',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSel ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    type: MaterialType.transparency,
                    child: Column(
                      children: _checklistDefs.map((item) {
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.label, style: const TextStyle(fontSize: 13)),
                          value: _checklistStates[item.key] ?? false,
                          onChanged: (v) => setState(() => _checklistStates[item.key] = v ?? false),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Staff Notes / Quarantine Follow-Up
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _isQuarantined ? Colors.amber.shade700 : AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isQuarantined ? 'CATATAN TINDAK LANJUT KARANTINA (WAJIB)' : 'Catatan Staf (Opsional)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: _isQuarantined ? Colors.amber.shade800 : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _staffNotesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: _isQuarantined
                          ? 'Wajib: Catat alasan karantina, kontak pelanggan, dan batas waktu tindak lanjut akun...'
                          : 'Catatan kondisi tambahan atau pesan pengembalian...',
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Penalty Payment Section (Rendered when penalty > 0)
            if (penaltyAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5),
                ),
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
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          CurrencyFormatter.format(penaltyAmount),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Keterlambatan:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${_formatOverdueDuration(lateMinutes)} ($billableHours jam tagih)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Tarif per jam:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${CurrencyFormatter.format(hourlyLateRate)} / jam',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Grace period:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '60 menit bebas biaya',
                                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Stacked vertical options with clear radio/tap affordance
                    InkWell(
                      onTap: () => setState(() => _payPenaltyNow = true),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: _payPenaltyNow ? AppColors.obsidian : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _payPenaltyNow ? AppColors.obsidian : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _payPenaltyNow ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: _payPenaltyNow ? Colors.white : AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bayar Sekarang',
                                style: TextStyle(
                                  color: _payPenaltyNow ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
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
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(
                          color: !_payPenaltyNow ? AppColors.obsidian : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: !_payPenaltyNow ? AppColors.obsidian : AppColors.border,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              !_payPenaltyNow ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: !_payPenaltyNow ? Colors.white : AppColors.textSecondary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Bayar Nanti (Catat ke Tagihan)',
                                style: TextStyle(
                                  color: !_payPenaltyNow ? Colors.white : AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Return
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _processReturn(penaltyAmount),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Selesaikan Pengembalian',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Kembalikan jaminan fisik ($collateralSlot) ke pelanggan',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _processReturn(double penaltyAmount) async {
    if (_isAppleDevice && !_accountCleared && !_isQuarantined) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Akun iCloud wajib dipastikan logout sebelum unit dapat diterima kembali, atau pilih Karantina Unit!'),
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
      categoryChecklist['account_quarantined'] = _isQuarantined;
      categoryChecklist['account_status'] = _accountCleared ? 'cleared' : (_isQuarantined ? 'quarantined' : 'unverified');
      categoryChecklist['device_platform'] = 'ios';
      categoryChecklist['screen_ok'] = _screenOk;
      categoryChecklist['camera_ok'] = _cameraOk;
    } else if (isMobile) {
      categoryChecklist['frp_removed'] = _accountCleared;
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

    final payload = {
      'returned_at': inspectionTime.toIso8601String(),
      'condition_grade': _conditionGrade,
      'late_fee': penaltyAmount,
      'total_penalty': penaltyAmount,
      'penalty_amount': penaltyAmount,
      'staff_notes': _staffNotesController.text.trim().isEmpty ? null : _staffNotesController.text.trim(),
      'checklist_results': categoryChecklist,
      'accessories_returned': categoryAccessories,
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
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Expanded(child: Text('Unit Berhasil Kembali!')),
          ],
        ),
        content: Text(
          'Pemeriksaan pengembalian selesai.\n'
          'Unit kini siap disewakan kembali.\n'
          '${penaltyPaid ? 'Denda keterlambatan berhasil dibayar & tercatat di revenue.\n' : (penaltyAmount > 0 ? 'Denda keterlambatan dicatat ke kasir (belum lunas).\n' : '')}'
          'Silakan kembalikan jaminan fisik ($collateralSlot) kepada pelanggan.',
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Cetak Bukti'),
            onPressed: () {
              final printerService = ThermalPrinterService();
              final printerSettings = ref.read(printerProvider).settings;
              final branchName = ref.read(businessProvider).activeBranchName ?? 'RentCore';
              final checklistSummary = _isQuarantined
                  ? 'Status: Karantina (Maintenance)'
                  : (_isAppleDevice ? 'Status: Bersih (iCloud Logout)' : 'Status: Fisik Diperiksa');
              final accessoriesSummary = _checklistDefs
                  .map((d) => '${d.label}: ${_checklistStates[d.key] == true ? "OK" : "Kurang"}')
                  .join(' • ');

              final model = ReceiptDataModel(
                type: ReceiptType.rentalReturn,
                title: 'BUKTI PENGEMBALIAN UNIT',
                branchName: branchName,
                bookingCode: widget.booking['booking_code']?.toString() ?? '',
                customerName: widget.booking['customer']?['name']?.toString() ?? 'Pelanggan',
                unitName: widget.booking['asset']?['name']?.toString() ?? 'Perangkat Gadget',
                conditionGrade: 'Grade $_conditionGrade',
                checklistNotes: checklistSummary,
                accessoriesNotes: accessoriesSummary,
                penaltyAmount: penaltyPaid ? penaltyAmount : 0.0,
                paymentMethod: penaltyPaid ? 'Lunas Denda' : null,
                totalAmount: penaltyPaid ? penaltyAmount : 0.0,
                transactedAt: DateTime.now().toString().substring(0, 16),
              );
              final escposBytes = printerService.buildRentalReturnSlipBytes(model, printerSettings);
              showDialog(
                context: context,
                builder: (dCtx) => ThermalReceiptPreviewDialog(
                  title: 'Bukti Pengembalian',
                  branchName: branchName,
                  escposBytes: escposBytes,
                  qrData: widget.booking['booking_code']?.toString(),
                  content: Column(
                    children: [
                      const Text('BUKTI PENGEMBALIAN UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Kode: ${widget.booking['booking_code'] ?? "-"}', style: const TextStyle(fontSize: 11)),
                      Text('Pelanggan: ${widget.booking['customer']?['name'] ?? "-"}', style: const TextStyle(fontSize: 11)),
                      Text('Kondisi: Grade $_conditionGrade', style: const TextStyle(fontSize: 11)),
                      const Divider(height: 16),
                      Text('Jaminan Fisik ($collateralSlot) Telah Diserahkan Kembali', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success)),
                    ],
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}

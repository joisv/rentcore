import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../../shared/widgets/unit_thumbnail.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../../vouchers/data/voucher_repository.dart';
import '../data/booking_repository.dart';
import '../providers/booking_provider.dart';

enum _ScheduledPaymentOption { full, dp, payLater }

class RentalTierOption {
  final int? id;
  final String unit; // 'hour', 'day', 'week', 'month'
  final int value;
  final int hours;
  final double price;
  final String label;

  const RentalTierOption({
    this.id,
    required this.unit,
    required this.value,
    required this.hours,
    required this.price,
    required this.label,
  });

  static String formatLabel(String unit, int value, int hours) {
    switch (unit.toLowerCase()) {
      case 'day':
        return '$value Hari ($hours Jam)';
      case 'week':
        return '$value Minggu';
      case 'month':
        return '$value Bulan';
      case 'hour':
      default:
        return '$value Jam';
    }
  }
}

class DirectRentalScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? customer;
  final int? customerId;
  final String? customerName;
  final String? customerPhone;
  final String? customerAddress;
  final ScrollController? scrollController;
  final bool showAppBar;

  const DirectRentalScreen({
    super.key,
    this.customer,
    this.customerId,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.scrollController,
    this.showAppBar = true,
  });

  @override
  ConsumerState<DirectRentalScreen> createState() => _DirectRentalScreenState();
}

class _DirectRentalScreenState extends ConsumerState<DirectRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0: Unit & Durasi, 1: Data Penyewa, 2: Ringkasan

  String? _assetValidationError;
  String? _durationValidationError;

  // Customer Info Controllers
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  final List<String> _safeSlots = [
    'Brankas A, Slot 01',
    'Brankas A, Slot 02',
    'Brankas A, Slot 03',
    'Brankas A, Slot 04',
    'Brankas A, Slot 05',
    'Brankas B, Slot 01',
    'Brankas B, Slot 02',
    'Brankas B, Slot 03',
    'Brankas B, Slot 04',
    'Brankas C, Slot Khusus (VIP)',
  ];
  String _selectedSafeSlot = 'Brankas A, Slot 05';
  static const int _initialUnitCap = 5;
  static const int _maxDurationMultiplier = 30;

  final _slotController = TextEditingController(text: 'Brankas A, Slot 05');
  final _voucherController = TextEditingController();
  final _unitSearchController = TextEditingController();
  String _unitSearchQuery = '';
  bool _showAllUnits = false;

  // Unit Selection initially null
  bool _isScheduledBooking = false;
  DateTime? _scheduledStartAt;
  String? _scheduleValidationError;
  bool _pinSpecificUnit = false;
  _ScheduledPaymentOption _scheduledPaymentOption = _ScheduledPaymentOption.full;
  final TextEditingController _dpAmountController = TextEditingController();
  bool _isSubmittingScheduled = false;
  int? _pendingScheduledModelId;
  int? _manualBranchOverrideId;

  bool get _payLaterScheduled =>
      _scheduledPaymentOption == _ScheduledPaymentOption.payLater;

  Map<String, dynamic>? _selectedModel;
  int? _selectedModelId;
  List<Map<String, dynamic>> _modelAvailabilityList = [];
  bool _isLoadingModelAvailability = false;
  String? _modelAvailabilityError;
  Map<int, Map<String, dynamic>> _immediateWindowAvailabilityByAssetId = {};
  int? _immediateWindowBranchId;
  int? _immediateWindowDurationHours;

  Map<String, dynamic>? _selectedAsset;
  int? _selectedAssetId;
  int? _lastImmediateAssetId;
  int? _selectedAssetCategoryId;
  int? _selectedTierId;
  int? _selectedRateHours;
  String _selectedDurationUnit = 'hour';
  int _selectedDurationValue = 24;
  double _selectedRatePrice = 0.0;
  int _durationMultiplier = 1;

  int? get _selectedDuration =>
      _selectedRateHours != null ? _selectedRateHours! * _durationMultiplier : null;
  int get _totalDurationValue => _selectedDurationValue * _durationMultiplier;
  double get _basePrice => _selectedRatePrice * _durationMultiplier;

  double _addonSubtotal = 0.0;
  final List<Map<String, dynamic>> _selectedAddons = [];
  int? _selectedAddonCategoryId;
  final _addonSearchController = TextEditingController();
  String _addonSearchQuery = '';
  double _discountAmount = 0.0;
  bool _isValidatingVoucher = false;
  String? _voucherMessage;

  // Customer Search & Auto-Fill
  bool _isNavigatingToPayment = false;
  bool _isSearchingCustomer = false;
  Map<String, dynamic>? _foundCustomer;
  int? _selectedCustomerId;
  bool _initializedFromRoute = false;
  String? _customerLookupMessage;
  String _initialName = '';
  String _initialPhone = '';
  String _initialAddress = '';
  bool _lastKnownUnsavedInput = false;
  bool _isConfirmingDiscard = false;

  bool get _hasUnsavedInput {
    return _selectedAssetId != null ||
        _selectedModelId != null ||
        _selectedAddons.isNotEmpty ||
        _selectedRateHours != null ||
        _durationMultiplier != 1 ||
        _isScheduledBooking ||
        _pinSpecificUnit ||
        _currentStep > 0 ||
        _dpAmountController.text.trim().isNotEmpty ||
        _nameController.text.trim() != _initialName ||
        _phoneController.text.trim() != _initialPhone ||
        _addressController.text.trim() != _initialAddress ||
        _voucherController.text.trim().isNotEmpty;
  }

  void _syncUnsavedInputState() {
    final dirty = _hasUnsavedInput;
    if (dirty != _lastKnownUnsavedInput && mounted) {
      setState(() {
        _lastKnownUnsavedInput = dirty;
      });
    }
  }

  Future<void> _handleClosePressed() async {
    await Navigator.of(context).maybePop();
  }

  Future<void> _promptDiscardBooking() async {
    if (_isConfirmingDiscard || !mounted) return;
    _isConfirmingDiscard = true;
    try {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: AppColors.border),
          ),
          title: const Text(
            'Batalkan Booking?',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          content: const Text(
            'Data unit atau penyewa yang sudah diisi akan hilang jika form ditutup.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.obsidian,
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Lanjut Isi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Ya, Tutup',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
      if (shouldDiscard == true && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _isConfirmingDiscard = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _slotController.text = _selectedSafeSlot;

    final customerData = widget.customer;
    if (customerData != null) {
      _foundCustomer = customerData;
      _selectedCustomerId = customerData['id'] != null
          ? int.tryParse(customerData['id'].toString())
          : widget.customerId;
      _nameController = TextEditingController(
        text: customerData['name']?.toString() ?? widget.customerName ?? '',
      );
      _phoneController = TextEditingController(
        text: customerData['phone']?.toString() ?? widget.customerPhone ?? '',
      );
      _addressController = TextEditingController(
        text: customerData['address']?.toString() ?? widget.customerAddress ?? '',
      );

      final count = customerData['bookings_count'] ?? 0;
      if (customerData['is_blacklisted'] == true) {
        _customerLookupMessage = 'PERINGATAN: Pelanggan ini masuk daftar hitam!';
      } else {
        _customerLookupMessage = 'Pelanggan terverifikasi ($count transaksi sewa sebelumnya)';
      }
    } else {
      _selectedCustomerId = widget.customerId;
      _nameController = TextEditingController(text: widget.customerName ?? '');
      _phoneController = TextEditingController(text: widget.customerPhone ?? '');
      _addressController = TextEditingController(text: widget.customerAddress ?? '');
    }

    _initialName = _nameController.text.trim();
    _initialPhone = _phoneController.text.trim();
    _initialAddress = _addressController.text.trim();
    _nameController.addListener(_syncUnsavedInputState);
    _phoneController.addListener(_syncUnsavedInputState);
    _addressController.addListener(_syncUnsavedInputState);
    _voucherController.addListener(_syncUnsavedInputState);
    _dpAmountController.addListener(_syncUnsavedInputState);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isScheduledBooking) {
        _loadImmediateWindowAvailability();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initializedFromRoute) {
      _initializedFromRoute = true;
      final routeArgs = ModalRoute.of(context)?.settings.arguments;
      if (routeArgs is Map<String, dynamic> && widget.customer == null) {
        setState(() {
          _foundCustomer = routeArgs;
          _selectedCustomerId = routeArgs['id'] != null
              ? int.tryParse(routeArgs['id'].toString())
              : _selectedCustomerId;
          if (_nameController.text.isEmpty && routeArgs['name'] != null) {
            _nameController.text = routeArgs['name'].toString();
          }
          if (_phoneController.text.isEmpty && routeArgs['phone'] != null) {
            _phoneController.text = routeArgs['phone'].toString();
          }
          if (_addressController.text.isEmpty && routeArgs['address'] != null) {
            _addressController.text = routeArgs['address'].toString();
          }
          _initialName = _nameController.text.trim();
          _initialPhone = _phoneController.text.trim();
          _initialAddress = _addressController.text.trim();
          final count = routeArgs['bookings_count'] ?? 0;
          if (routeArgs['is_blacklisted'] == true) {
            _customerLookupMessage = 'PERINGATAN: Pelanggan ini masuk daftar hitam!';
          } else {
            _customerLookupMessage = 'Pelanggan terverifikasi ($count transaksi sewa sebelumnya)';
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_syncUnsavedInputState);
    _phoneController.removeListener(_syncUnsavedInputState);
    _addressController.removeListener(_syncUnsavedInputState);
    _voucherController.removeListener(_syncUnsavedInputState);
    _dpAmountController.removeListener(_syncUnsavedInputState);
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _slotController.dispose();
    _voucherController.dispose();
    _dpAmountController.dispose();
    _unitSearchController.dispose();
    _addonSearchController.dispose();
    super.dispose();
  }

  String _formatReturnTimeLabel({bool includeWib = true}) {
    final hours = _selectedDuration ?? 24;
    final baseStart = (_isScheduledBooking && _scheduledStartAt != null)
        ? _scheduledStartAt!
        : DateTime.now();
    final now = DateTime.now();
    final returnTime = baseStart.add(Duration(hours: hours));

    final isToday = returnTime.year == now.year && returnTime.month == now.month && returnTime.day == now.day;
    final tomorrow = now.add(const Duration(days: 1));
    final isTomorrow = returnTime.year == tomorrow.year && returnTime.month == tomorrow.month && returnTime.day == tomorrow.day;

    final hh = returnTime.hour.toString().padLeft(2, '0');
    final mm = returnTime.minute.toString().padLeft(2, '0');

    final String dayPrefix;
    if (isToday) {
      dayPrefix = 'Hari Ini';
    } else if (isTomorrow) {
      dayPrefix = 'Besok';
    } else {
      const days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
      final dayName = days[returnTime.weekday - 1];
      final monthName = months[returnTime.month - 1];
      dayPrefix = '$dayName, ${returnTime.day} $monthName';
    }

    return '$dayPrefix, $hh:$mm${includeWib ? ' WIB' : ''}';
  }

  String _formatReturnDeadline() {
    return 'Kembali: ${_formatReturnTimeLabel()}';
  }

  String _formatLast4Sn(String? sn) {
    if (sn == null || sn.trim().isEmpty) return '';
    final trimmed = sn.trim();
    if (trimmed.length <= 4) return trimmed;
    return '...${trimmed.substring(trimmed.length - 4)}';
  }

  IconData _getCategoryIcon(String? categoryName) {
    final cat = (categoryName ?? '').toLowerCase();
    if (cat.contains('kamera') || cat.contains('camera')) return Icons.camera_alt_rounded;
    if (cat.contains('laptop') || cat.contains('komputer')) return Icons.laptop_mac_rounded;
    if (cat.contains('proyektor') || cat.contains('projector')) return Icons.videocam_rounded;
    if (cat.contains('game') || cat.contains('konsol') || cat.contains('playstation')) return Icons.sports_esports_rounded;
    if (cat.contains('tablet') || cat.contains('ipad')) return Icons.tablet_mac_rounded;
    return Icons.phone_iphone_rounded;
  }

  List<RentalTierOption> _getAvailableTiers(Map<String, dynamic>? asset) {
    if (asset == null) return [];
    final model = asset['model'];
    return _getAvailableTiersForModel(
      model is Map ? Map<String, dynamic>.from(model) : null,
    );
  }

  List<RentalTierOption> _getAvailableTiersForModel(Map<String, dynamic>? model) {
    if (model == null) return [];
    final tiers = (model['pricing_tiers'] as List?) ?? (model['pricingTiers'] as List?) ?? [];
    final list = <RentalTierOption>[];
    for (final t in tiers) {
      final tierId = t['id'] != null ? int.tryParse(t['id'].toString()) : null;
      final unit = (t['duration_unit']?.toString() ?? 'hour').toLowerCase();
      final hours = int.tryParse(t['duration_hours']?.toString() ?? '0') ?? 0;
      final val = int.tryParse(t['duration_value']?.toString() ?? '') ?? hours;
      final price = CurrencyFormatter.parse(t['price']);
      if (hours > 0) {
        list.add(RentalTierOption(
          id: tierId,
          unit: unit,
          value: val,
          hours: hours,
          price: price,
          label: RentalTierOption.formatLabel(unit, val, hours),
        ));
      }
    }
    if (list.isEmpty) {
      return const [
        RentalTierOption(unit: 'hour', value: 12, hours: 12, price: 200000.0, label: '12 Jam'),
        RentalTierOption(unit: 'day', value: 1, hours: 24, price: 350000.0, label: '1 Hari (24 Jam)'),
        RentalTierOption(unit: 'day', value: 2, hours: 48, price: 650000.0, label: '2 Hari (48 Jam)'),
      ];
    }
    list.sort((a, b) => a.hours.compareTo(b.hours));
    return list;
  }

  Map<String, dynamic>? _findResolvedBranchMap(BusinessState bizState, {int? resolvedBranchId}) {
    if (bizState.currentBranch != null && (resolvedBranchId == null || resolvedBranchId == bizState.activeBranchId)) {
      return bizState.currentBranch;
    }
    final targetId = resolvedBranchId ??
        _resolveTargetBranch(bizState, ref.read(authProvider)).branchId;
    if (targetId == null) return null;
    final branches = bizState.currentBusiness?['branches'] as List<dynamic>?;
    if (branches != null) {
      for (final b in branches.whereType<Map>()) {
        if (_parseId(b['id']) == targetId) {
          return Map<String, dynamic>.from(b);
        }
      }
    }
    return null;
  }

  bool _isFloatingAllowedForActiveBranch(BusinessState bizState, {int? resolvedBranchId}) {
    final branch = _findResolvedBranchMap(bizState, resolvedBranchId: resolvedBranchId);
    if (branch == null) return true;
    return branch['allow_floating_unit_booking'] != false;
  }

  int _graceMinutesForActiveBranch(BusinessState bizState, {int? resolvedBranchId}) {
    final branch = _findResolvedBranchMap(bizState, resolvedBranchId: resolvedBranchId);
    return (branch?['booking_grace_period_minutes'] as num?)?.toInt() ?? 60;
  }

  int? _parseId(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw.toString());
  }

  Map<String, dynamic>? _findSelectedModelInAvailability() {
    if (_selectedModelId == null) return _selectedModel;
    for (final m in _modelAvailabilityList) {
      if (_parseId(m['id']) == _selectedModelId) {
        return m;
      }
    }
    return _selectedModel;
  }

  bool _isAssetAvailableForSchedule(int? assetId, int? modelId) {
    if (!_isScheduledBooking) {
      if (assetId == null) return true;
      final info = _immediateWindowAvailabilityByAssetId[assetId];
      if (info == null) return true;
      if (info.containsKey('is_available_for_window')) {
        return info['is_available_for_window'] != false;
      }
      if (info.containsKey('is_available_for_schedule')) {
        return info['is_available_for_schedule'] != false;
      }
      return true;
    }
    if (_modelAvailabilityList.isEmpty || _isLoadingModelAvailability) {
      return true;
    }
    if (modelId == null) return true;
    Map<String, dynamic>? matchedModel;
    for (final m in _modelAvailabilityList) {
      if (_parseId(m['id']) == modelId) {
        matchedModel = m;
        break;
      }
    }
    if (matchedModel == null) return false;
    final availableSlots = (_parseId(matchedModel['available_slots']) ?? 0);
    if (availableSlots <= 0) return false;
    final rawIds = matchedModel['available_asset_ids'];
    if (rawIds is List && assetId != null) {
      return rawIds.map(_parseId).contains(assetId);
    }
    return true;
  }

  String? _getAssetConflictReason(int? assetId) {
    if (assetId == null) return null;
    final info = _immediateWindowAvailabilityByAssetId[assetId];
    final reason = info?['conflict_reason']?.toString().trim();
    if (reason != null && reason.isNotEmpty) {
      return reason;
    }
    return null;
  }

  bool _isSelectedUnavailableForSchedule(BusinessState bizState) {
    if (!_isScheduledBooking) {
      if (_selectedAssetId == null) return false;
      return !_isAssetAvailableForSchedule(_selectedAssetId, _selectedModelId);
    }
    if (_isLoadingModelAvailability) return false;
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState);
    if (floatingAllowed && !_pinSpecificUnit) {
      if (_selectedModelId == null || _modelAvailabilityList.isEmpty) {
        return false;
      }
      final model = _findSelectedModelInAvailability();
      if (model == null) return false;
      final availableSlots = _parseId(model['available_slots']) ?? 0;
      return availableSlots <= 0;
    }
    if (_selectedAssetId != null) {
      final modelId = _selectedModelId ??
          _parseId(_selectedAsset?['model_id']) ??
          _parseId(_selectedAsset?['model']?['id']);
      return !_isAssetAvailableForSchedule(_selectedAssetId, modelId);
    }
    return false;
  }

  ({
    int? branchId,
    String? branchName,
    bool isConsolidatedFallback,
    List<Map<String, dynamic>> availableBranches,
  }) _resolveTargetBranch(BusinessState bizState, AuthState authState) {
    final rawBranches = bizState.currentBusiness?['branches'] as List<dynamic>?;
    final availableBranches = rawBranches
            ?.whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .where((b) => b['is_active'] != false)
            .toList() ??
        const <Map<String, dynamic>>[];

    Map<String, dynamic>? findBranchById(int? id) {
      if (id == null) return null;
      for (final b in availableBranches) {
        if (_parseId(b['id']) == id) return b;
      }
      return null;
    }

    if (bizState.activeBranchId != null) {
      final activeId = bizState.activeBranchId;
      final matched = findBranchById(activeId);
      final branchName = bizState.resolvedBranchName.isNotEmpty
          ? bizState.resolvedBranchName
          : matched?['name']?.toString();
      return (
        branchId: activeId,
        branchName: branchName,
        isConsolidatedFallback: false,
        availableBranches: availableBranches,
      );
    }

    // Consolidated ("Semua Cabang") mode: resolve a concrete branch fallback
    final overrideBranch = findBranchById(_manualBranchOverrideId);
    if (overrideBranch != null) {
      return (
        branchId: _parseId(overrideBranch['id']),
        branchName: overrideBranch['name']?.toString(),
        isConsolidatedFallback: true,
        availableBranches: availableBranches,
      );
    }

    final userAffiliateId = _parseId(authState.user?['affiliate_id']);
    final userAssignedBranch = findBranchById(userAffiliateId);
    if (userAssignedBranch != null) {
      return (
        branchId: _parseId(userAssignedBranch['id']),
        branchName: userAssignedBranch['name']?.toString(),
        isConsolidatedFallback: true,
        availableBranches: availableBranches,
      );
    }

    final firstBranch = availableBranches.isNotEmpty ? availableBranches.first : null;
    return (
      branchId: _parseId(firstBranch?['id']),
      branchName: firstBranch?['name']?.toString(),
      isConsolidatedFallback: true,
      availableBranches: availableBranches,
    );
  }

  void _resetBranchScopedSelections() {
    _selectedModel = null;
    _selectedModelId = null;
    _pendingScheduledModelId = null;
    _selectedAsset = null;
    _selectedAssetId = null;
    _lastImmediateAssetId = null;
    _selectedAddons.clear();
    _addonSubtotal = 0.0;
    _selectedTierId = null;
    _selectedRateHours = null;
    _selectedRatePrice = 0.0;
    _durationMultiplier = 1;
    _selectedSafeSlot = 'Brankas A, Slot 05';
    _slotController.text = _selectedSafeSlot;
    _modelAvailabilityList = [];
    _modelAvailabilityError = null;
    _assetValidationError = null;
    _durationValidationError = null;
    if (_currentStep > 0) {
      _currentStep = 0;
    }
  }

  void _refreshBranchProviders(int? branchId) {
    ref.invalidate(readyAssetsProvider);
    ref.invalidate(readyAssetsByBranchProvider(branchId));
    ref.invalidate(categoriesProvider);
    ref.invalidate(currentShiftByBranchProvider(branchId));
    ref.invalidate(currentShiftProvider);
  }

  Future<void> _showTargetBranchPickerSheet(
    List<Map<String, dynamic>> branches,
    int? currentBranchId,
  ) async {
    if (branches.isEmpty) return;
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pilih Cabang Transaksi Booking',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
              ),
              const SizedBox(height: 10),
              for (final b in branches)
                ListTile(
                  key: Key('booking_branch_option_${b['id']}'),
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  leading: Icon(
                    Icons.storefront_rounded,
                    size: 20,
                    color: _parseId(b['id']) == currentBranchId ? const Color(0xFF111111) : const Color(0xFF6B7280),
                  ),
                  title: Text(
                    b['name']?.toString() ?? 'Cabang',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: _parseId(b['id']) == currentBranchId ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  trailing: _parseId(b['id']) == currentBranchId
                      ? const Icon(Icons.check_circle_rounded, color: Color(0xFF111111), size: 18)
                      : null,
                  onTap: () => Navigator.pop(sheetCtx, _parseId(b['id'])),
                ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == currentBranchId || !mounted) return;
    setState(() {
      _manualBranchOverrideId = picked;
      _resetBranchScopedSelections();
    });
    _refreshBranchProviders(picked);
    if (_isScheduledBooking && _scheduledStartAt != null) {
      _loadModelAvailability(branchIdOverride: picked);
    }
    _syncUnsavedInputState();
  }

  bool _isPrimarySelectionReady(BusinessState bizState, {int? resolvedBranchId}) {
    final effectiveBranchId = resolvedBranchId ??
        _resolveTargetBranch(bizState, ref.read(authProvider)).branchId;
    if (bizState.activeBusinessId != null && effectiveBranchId == null) {
      return false;
    }
    if (!_isScheduledBooking) {
      return _selectedAssetId != null;
    }
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState, resolvedBranchId: effectiveBranchId);
    if (!floatingAllowed || _pinSpecificUnit) {
      return _selectedAssetId != null;
    }
    return _selectedModelId != null;
  }

  DateTime _defaultSchedulePickerInitialTime() {
    final nextHour = DateTime.now().add(const Duration(hours: 1));
    return DateTime(nextHour.year, nextHour.month, nextHour.day, nextHour.hour);
  }

  DateTime get _effectiveScheduledEndAt {
    final hours = _selectedDuration ?? 24;
    final start = _scheduledStartAt ?? _defaultSchedulePickerInitialTime();
    return start.add(Duration(hours: hours));
  }

  Future<void> _loadModelAvailability({int? branchIdOverride}) async {
    final startAt = _scheduledStartAt;
    if (!_isScheduledBooking || startAt == null) return;
    final bizState = ref.read(businessProvider);
    if (bizState.activeBusinessId == null) return;
    final activeBranchId = branchIdOverride ??
        _resolveTargetBranch(bizState, ref.read(authProvider)).branchId;
    if (activeBranchId == null) {
      setState(() {
        _modelAvailabilityList = [];
        _isLoadingModelAvailability = false;
        _modelAvailabilityError =
            'Mode Semua Cabang aktif. Pilih cabang spesifik terlebih dahulu untuk mengecek ketersediaan booking.';
        _selectedModel = null;
        _selectedModelId = null;
        _pendingScheduledModelId = null;
      });
      _syncUnsavedInputState();
      return;
    }

    setState(() {
      _isLoadingModelAvailability = true;
      _modelAvailabilityError = null;
    });

    try {
      final list = await ref.read(bookingRepositoryProvider).fetchModelAvailability(
            startAt: startAt,
            endAt: _effectiveScheduledEndAt,
            branchId: activeBranchId,
          );
      if (!mounted) return;
      // Ignore stale responses if the user switched branch mid-flight.
      final currentResolvedBranchId = _resolveTargetBranch(
        ref.read(businessProvider),
        ref.read(authProvider),
      ).branchId;
      if (currentResolvedBranchId != activeBranchId) {
        return;
      }
      setState(() {
        _modelAvailabilityList = list;
        _isLoadingModelAvailability = false;
        final targetModelId = _selectedModelId ?? _pendingScheduledModelId;
        _pendingScheduledModelId = null;

        if (targetModelId != null) {
          Map<String, dynamic>? matchedModel;
          for (final item in list) {
            if (_parseId(item['id']) == targetModelId) {
              matchedModel = item;
              break;
            }
          }

          if (matchedModel != null) {
            _selectedModel = matchedModel;
            _selectedModelId = targetModelId;
            final availableTiers = _getAvailableTiersForModel(matchedModel);
            if (availableTiers.isNotEmpty) {
              final hasExistingDuration = _selectedRateHours != null;
              final matchedTier = availableTiers.where(
                (t) =>
                    t.hours == _selectedRateHours &&
                    t.unit == _selectedDurationUnit &&
                    t.value == _selectedDurationValue,
              );
              if (matchedTier.isNotEmpty) {
                final tier = matchedTier.first;
                _selectedTierId = tier.id;
                _selectedRateHours = tier.hours;
                _selectedDurationUnit = tier.unit;
                _selectedDurationValue = tier.value;
                _selectedRatePrice = tier.price;
              } else if (!hasExistingDuration) {
                final defaultTier = availableTiers.firstWhere(
                  (t) => t.hours == 24,
                  orElse: () => availableTiers.first,
                );
                _selectedTierId = defaultTier.id;
                _selectedRateHours = defaultTier.hours;
                _selectedDurationUnit = defaultTier.unit;
                _selectedDurationValue = defaultTier.value;
                _selectedRatePrice = defaultTier.price;
              }
            }
          } else {
            // Model has 0 units / does not belong to this branch; clear stale cross-branch selection.
            _selectedModel = null;
            _selectedModelId = null;
          }
        }
      });
      _syncUnsavedInputState();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingModelAvailability = false;
        _modelAvailabilityError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _loadImmediateWindowAvailability({
    int? branchIdOverride,
    bool force = false,
  }) async {
    if (_isScheduledBooking) return;
    final repo = ref.read(bookingRepositoryProvider);
    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isWidgetTest && repo.runtimeType == BookingRepository) {
      return;
    }

    final bizState = ref.read(businessProvider);
    if (bizState.activeBusinessId == null) return;
    final activeBranchId = branchIdOverride ??
        _resolveTargetBranch(bizState, ref.read(authProvider)).branchId;
    if (activeBranchId == null) return;

    final durationHours = _selectedDuration ?? 24;
    if (!force &&
        _immediateWindowBranchId == activeBranchId &&
        _immediateWindowDurationHours == durationHours &&
        _immediateWindowAvailabilityByAssetId.isNotEmpty) {
      return;
    }

    final startAt = DateTime.now();
    final endAt = startAt.add(Duration(hours: durationHours));

    try {
      final list = await repo.fetchAssetsForWindow(
        branchId: activeBranchId,
        startAt: startAt,
        endAt: endAt,
      );
      if (!mounted) return;
      final map = <int, Map<String, dynamic>>{};
      for (final item in list) {
        final id = _parseId(item['id']);
        if (id != null) {
          map[id] = item;
        }
      }
      setState(() {
        _immediateWindowBranchId = activeBranchId;
        _immediateWindowDurationHours = durationHours;
        _immediateWindowAvailabilityByAssetId = map;
        if (_selectedAssetId != null) {
          final reason = _getAssetConflictReason(_selectedAssetId);
          if (!_isAssetAvailableForSchedule(_selectedAssetId, _selectedModelId)) {
            _assetValidationError = reason ??
                'Unit/model yang dipilih tidak tersedia untuk durasi $durationHours jam.';
          } else {
            _assetValidationError = null;
          }
        }
      });
    } catch (_) {
      // Keep UI usable when offline; backend will still enforce overlap atomically at submit.
    }
  }

  void _resetToImmediateRental() {
    final readyAssets = ref.read(readyAssetsProvider).value;
    Map<String, dynamic>? restoredAsset;
    if (readyAssets != null) {
      final candidateId = _selectedAssetId ?? _lastImmediateAssetId;
      if (candidateId != null) {
        for (final a in readyAssets) {
          if (_parseId(a['id']) == candidateId) {
            restoredAsset = Map<String, dynamic>.from(a);
            break;
          }
        }
      }
      if (restoredAsset == null && _selectedModelId != null) {
        for (final a in readyAssets) {
          final aModelId = _parseId(a['model_id']) ?? _parseId(a['model']?['id']);
          if (aModelId == _selectedModelId) {
            restoredAsset = Map<String, dynamic>.from(a);
            break;
          }
        }
      }
    }

    setState(() {
      _isScheduledBooking = false;
      _scheduledStartAt = null;
      _scheduleValidationError = null;
      _scheduledPaymentOption = _ScheduledPaymentOption.full;
      _dpAmountController.clear();
      _pinSpecificUnit = false;
      _pendingScheduledModelId = null;
      _assetValidationError = null;
      if (restoredAsset != null) {
        _selectedAsset = restoredAsset;
        _selectedAssetId = _parseId(restoredAsset['id']);
        _lastImmediateAssetId = _selectedAssetId;
      } else {
        _selectedModel = null;
        _selectedModelId = null;
      }
    });
    _syncUnsavedInputState();
    _loadImmediateWindowAvailability(force: true);
  }

  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final referenceTime = _scheduledStartAt ?? _defaultSchedulePickerInitialTime();
    final initialDate = referenceTime.isBefore(now) ? now : referenceTime;
    final pickerTheme = Theme.of(context).copyWith(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF111111),
        onPrimary: Colors.white,
        surface: Colors.white,
        onSurface: Color(0xFF111111),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF111111),
        ),
      ),
    );

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: pickerTheme,
        child: child ?? const SizedBox(),
      ),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(referenceTime),
      builder: (context, child) => Theme(
        data: pickerTheme,
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        ),
      ),
    );
    if (pickedTime == null || !mounted) return;

    final pickedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    if (!pickedDateTime.isAfter(DateTime.now().subtract(const Duration(minutes: 2)))) {
      const msg = 'Pilih waktu dan tanggal di masa mendatang untuk booking terjadwal.';
      setState(() => _scheduleValidationError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bizState = ref.read(businessProvider);
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState);
    final rawAssetModel = _selectedAsset?['model'];
    final assetModelMap = rawAssetModel is Map
        ? Map<String, dynamic>.from(rawAssetModel)
        : null;
    final priorModelId = _selectedModelId ??
        _parseId(_selectedAsset?['model_id']) ??
        _parseId(assetModelMap?['id']);

    setState(() {
      _scheduledStartAt = pickedDateTime;
      _isScheduledBooking = true;
      _scheduleValidationError = null;
      _assetValidationError = null;
      if (floatingAllowed && !_pinSpecificUnit) {
        if (_selectedAssetId != null) {
          _lastImmediateAssetId = _selectedAssetId;
        }
        if (priorModelId != null) {
          _selectedModelId = priorModelId;
          _pendingScheduledModelId = priorModelId;
          _selectedModel ??= assetModelMap;
        }
        _selectedAsset = null;
        _selectedAssetId = null;
      }
    });
    _syncUnsavedInputState();
    _loadModelAvailability();
  }

  void _onModelSelected(Map<String, dynamic> model) {
    final modelId = _parseId(model['id']);
    final availableSlots = _parseId(model['available_slots']) ?? 0;
    if (availableSlots <= 0 && _selectedModelId != modelId) return;

    setState(() {
      _selectedModel = model;
      _selectedModelId = modelId;
      _selectedAsset = null;
      _selectedAssetId = null;
      _assetValidationError = null;
      _durationValidationError = null;

      final availableTiers = _getAvailableTiersForModel(model);
      RentalTierOption selectedTier = availableTiers.first;
      for (final tier in availableTiers) {
        if (tier.hours == 24) {
          selectedTier = tier;
          break;
        }
      }

      _selectedTierId = selectedTier.id;
      _selectedRateHours = selectedTier.hours;
      _selectedDurationUnit = selectedTier.unit;
      _selectedDurationValue = selectedTier.value;
      _selectedRatePrice = selectedTier.price;
      _durationMultiplier = 1;
      _recalculateAddons();
    });

    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  bool _matchesUnitSearch(Map<String, dynamic> asset, String rawQuery) {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return true;
    final model = asset['model'] as Map? ?? const {};
    final fields = [
      model['name'],
      model['brand'],
      asset['name'],
      asset['asset_code'],
      asset['serial_number'],
    ];
    return fields.any(
      (field) => field != null && field.toString().toLowerCase().contains(query),
    );
  }

  String _formatPrimaryUnitRateLabel(List<RentalTierOption> tiers) {
    if (tiers.isEmpty) return CurrencyFormatter.format(0);
    RentalTierOption primaryTier = tiers.first;
    for (final tier in tiers) {
      if (tier.hours == 24) {
        primaryTier = tier;
        break;
      }
    }
    final durationLabel = switch (primaryTier.unit) {
      'week' => '${primaryTier.value} Minggu',
      'month' => '${primaryTier.value} Bulan',
      _ => '${primaryTier.hours} Jam',
    };
    return '${CurrencyFormatter.format(primaryTier.price)} / $durationLabel';
  }

  void _onAssetSelected(Map<String, dynamic> asset) {
    final rawModel = asset['model'];
    final modelMap = rawModel is Map ? Map<String, dynamic>.from(rawModel) : null;
    final assetId = _parseId(asset['id']);
    final modelId = _parseId(asset['model_id']) ?? _parseId(modelMap?['id']);

    setState(() {
      _selectedAsset = asset;
      _selectedAssetId = assetId;
      _lastImmediateAssetId = assetId;
      _selectedModelId = modelId;
      _selectedModel = modelMap;
      _assetValidationError = null;
      _durationValidationError = null;
      final availableTiers = _getAvailableTiers(asset);

      RentalTierOption selectedTier = availableTiers.first;
      for (final tier in availableTiers) {
        if (tier.hours == 24) {
          selectedTier = tier;
          break;
        }
      }

      _selectedTierId = selectedTier.id;
      _selectedRateHours = selectedTier.hours;
      _selectedDurationUnit = selectedTier.unit;
      _selectedDurationValue = selectedTier.value;
      _selectedRatePrice = selectedTier.price;
      _durationMultiplier = 1;

      _recalculateAddons();
    });

    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
    if (!_isScheduledBooking) {
      _loadImmediateWindowAvailability(force: true);
    }
  }

  void _onTierSelected(RentalTierOption tier) {
    setState(() {
      _selectedTierId = tier.id;
      _selectedRateHours = tier.hours;
      _selectedDurationUnit = tier.unit;
      _selectedDurationValue = tier.value;
      _selectedRatePrice = tier.price;
      _durationMultiplier = 1;
      _durationValidationError = null;
      _recalculateAddons();
    });

    if (_isScheduledBooking) {
      _loadModelAvailability();
    } else {
      _loadImmediateWindowAvailability(force: true);
    }
    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  void _onMultiplierChanged(int nextMultiplier) {
    final clamped = nextMultiplier.clamp(1, _maxDurationMultiplier);
    if (clamped == _durationMultiplier) return;
    setState(() {
      _durationMultiplier = clamped;
      _recalculateAddons();
    });
    if (_isScheduledBooking) {
      _loadModelAvailability();
    } else {
      _loadImmediateWindowAvailability(force: true);
    }
    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  double _computeAddonPrice(Map<String, dynamic> addonAsset) {
    final tiers = _getAvailableTiers(addonAsset);
    if (tiers.isEmpty) return 20000.0 * _durationMultiplier;
    final targetHours = _selectedRateHours ?? 24;
    for (final t in tiers) {
      if (t.hours == targetHours) {
        return t.price * _durationMultiplier;
      }
    }
    return tiers.first.price * _durationMultiplier;
  }

  void _recalculateAddons() {
    double total = 0.0;
    for (final addon in _selectedAddons) {
      total += _computeAddonPrice(addon);
    }
    _addonSubtotal = total;
  }

  void _toggleAddon(Map<String, dynamic> addon) {
    final addonId = addon['id'];
    final existingIdx = _selectedAddons.indexWhere((a) => a['id'] == addonId);
    setState(() {
      if (existingIdx >= 0) {
        _selectedAddons.removeAt(existingIdx);
      } else {
        _selectedAddons.add(addon);
      }
      _recalculateAddons();
    });
  }

  void _validateVoucher() async {
    final code = _voucherController.text.trim();
    final combinedSubtotal = _basePrice + _addonSubtotal;
    if (code.isEmpty || combinedSubtotal <= 0) return;

    setState(() {
      _isValidatingVoucher = true;
      _voucherMessage = null;
    });

    try {
      final repo = VoucherRepository();
      final result = await repo.validateVoucher(code, combinedSubtotal);
      setState(() {
        _discountAmount = CurrencyFormatter.parse(result['calculated_discount']);
        _voucherMessage = 'Voucher aktif: Hemat ${CurrencyFormatter.format(_discountAmount)} (${result['discount_percentage']}%)';
      });
    } catch (e) {
      setState(() {
        _discountAmount = 0.0;
        _voucherMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() => _isValidatingVoucher = false);
    }
  }

  void _searchCustomer() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nomor WhatsApp pelanggan untuk mencari.')),
      );
      return;
    }

    setState(() {
      _isSearchingCustomer = true;
      _customerLookupMessage = null;
    });

    try {
      final repo = CustomerRepository();
      final result = await repo.lookupCustomer(phone);
      if (result != null) {
        setState(() {
          _foundCustomer = result;
          _selectedCustomerId = result['id'] != null
              ? int.tryParse(result['id'].toString())
              : null;
          _nameController.text = result['name'] ?? _nameController.text;
          _phoneController.text = result['phone'] ?? _phoneController.text;
          if (result['address'] != null && result['address'].toString().trim().isNotEmpty) {
            _addressController.text = result['address'].toString();
          }

          if (result['is_blacklisted'] == true) {
            _customerLookupMessage = 'PERINGATAN: Pelanggan ini masuk daftar hitam!';
          } else {
            final count = result['bookings_count'] ?? 0;
            _customerLookupMessage = 'Pelanggan terverifikasi ($count transaksi sewa sebelumnya)';
          }
        });
      } else {
        setState(() {
          _foundCustomer = null;
          _selectedCustomerId = null;
          _customerLookupMessage = 'Pelanggan baru (belum terdaftar di database).';
        });
      }
    } catch (e) {
      setState(() {
        _customerLookupMessage = 'Gagal mencari pelanggan: $e';
      });
    } finally {
      setState(() => _isSearchingCustomer = false);
    }
  }

  bool _validateScheduleBeforeSubmit() {
    if (!_isScheduledBooking) {
      if (_scheduleValidationError != null) {
        setState(() => _scheduleValidationError = null);
      }
      return true;
    }
    final minAllowed = DateTime.now().subtract(const Duration(minutes: 2));
    if (_scheduledStartAt == null || !_scheduledStartAt!.isAfter(minAllowed)) {
      const msg = 'Pilih waktu dan tanggal di masa mendatang untuk booking terjadwal.';
      setState(() => _scheduleValidationError = msg);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.danger,
        ),
      );
      return false;
    }
    if (_scheduleValidationError != null) {
      setState(() => _scheduleValidationError = null);
    }
    return true;
  }

  void _onNextToCustomerStep() {
    if (!_validateScheduleBeforeSubmit()) return;
    final bizState = ref.read(businessProvider);
    final isReady = _isPrimarySelectionReady(bizState);
    final isUnavailableOnSchedule = isReady && _isSelectedUnavailableForSchedule(bizState);
    final conflictReason = _getAssetConflictReason(_selectedAssetId);
    final unavailableMsg = conflictReason ??
        (_isScheduledBooking
            ? 'Unit/model yang dipilih tidak tersedia pada jadwal ini.'
            : 'Unit/model yang dipilih sudah terikat jadwal sewa/booking lain untuk durasi tersebut.');
    setState(() {
      if (!isReady) {
        _assetValidationError = _isScheduledBooking && _isFloatingAllowedForActiveBranch(bizState) && !_pinSpecificUnit
            ? 'Pilih salah satu model perangkat terlebih dahulu.'
            : 'Pilih salah satu unit rental terlebih dahulu.';
      } else if (isUnavailableOnSchedule) {
        _assetValidationError = unavailableMsg;
      } else {
        _assetValidationError = null;
      }
      _durationValidationError = _selectedDuration == null ? 'Pilih durasi sewa yang diinginkan.' : null;
    });

    if (!isReady || isUnavailableOnSchedule || _selectedDuration == null) {
      if (isUnavailableOnSchedule) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.event_busy_rounded, color: AppColors.danger),
                SizedBox(width: 8),
                Expanded(child: Text('Jadwal Sewa Bentrok')),
              ],
            ),
            content: Text(unavailableMsg),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Mengerti'),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silakan pilih unit/model rental dan durasi terlebih dahulu.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _onNextToSummaryStep() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lengkapi formulir data penyewa yang bertanda merah.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_foundCustomer != null && _foundCustomer!['is_blacklisted'] == true) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.block_rounded, color: AppColors.danger),
              SizedBox(width: 8),
              Text('Pelanggan Blacklist!'),
            ],
          ),
          content: Text(
            'Transaksi sewa DITOLAK karena pelanggan ini berada dalam daftar hitam (blacklist):\n\n'
            'Alasan: ${_foundCustomer!['blacklist_reason'] ?? 'Pelanggaran kebijakan sewa.'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Kembali'),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _currentStep = 2);
  }

  void _onBackStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  double _effectiveDpAmount(double totalPayable) {
    final raw = CurrencyFormatter.parse(_dpAmountController.text);
    if (raw > 0 && raw < totalPayable) return raw;
    if (raw >= totalPayable && totalPayable > 0) return totalPayable;
    return totalPayable > 0 ? (totalPayable * 0.5).roundToDouble() : 0.0;
  }

  Map<String, dynamic> _buildBookingPayload() {
    final bizState = ref.read(businessProvider);
    final authState = ref.read(authProvider);
    final activeBranchId = _resolveTargetBranch(bizState, authState).branchId;
    final address = _addressController.text.trim();
    final customerId = _selectedCustomerId ?? _foundCustomer?['id'];
    final totalHours = _selectedDuration;
    final totalDurationValue = _totalDurationValue;
    final totalPayable =
        (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState, resolvedBranchId: activeBranchId);
    final isFloating =
        _isScheduledBooking && floatingAllowed && !_pinSpecificUnit;

    final effectiveModelId =
        _selectedModelId ??
        (_selectedAsset?['model_id'] as num?)?.toInt() ??
        (_selectedAsset?['model']?['id'] as num?)?.toInt();

    final payload = <String, dynamic>{
      if (customerId != null)
        'customer_id': customerId is int
            ? customerId
            : int.tryParse(customerId.toString()),
      'customer_name': _nameController.text.trim(),
      'customer_phone': _phoneController.text.trim(),
      'customer_address': address,
      if (_isScheduledBooking && _scheduledStartAt != null) ...{
        'is_scheduled': true,
        'booking_mode': 'scheduled',
        'status': 'booked',
        'start_at': _scheduledStartAt!.toUtc().toIso8601String(),
        'asset_model_id': ?effectiveModelId,
        if (_scheduledPaymentOption == _ScheduledPaymentOption.payLater)
          'paid_amount': 0
        else if (_scheduledPaymentOption == _ScheduledPaymentOption.dp) ...{
          'paid_amount': _effectiveDpAmount(totalPayable),
          'dp_amount': _effectiveDpAmount(totalPayable),
        } else
          'paid_amount': totalPayable,
      } else ...{
        'is_scheduled': false,
        'booking_mode': 'direct',
        'start_at': null,
      },
      if (!isFloating && _selectedAssetId != null)
        'asset_ids': [_selectedAssetId],
      if (_selectedAddons.isNotEmpty)
        'addon_asset_ids': _selectedAddons.map((a) => a['id']).toList(),
      'duration_hours': totalHours,
      'duration_unit': _selectedDurationUnit,
      'duration_value': totalDurationValue,
      'duration_multiplier': _durationMultiplier,
      'quantity': _durationMultiplier,
      if (_selectedTierId != null) 'rate_id': _selectedTierId,
      'collateral_type': 'KTP Asli',
      'collateral_storage_slot': _slotController.text.trim(),
      'voucher_code': _discountAmount > 0 ? _voucherController.text.trim() : null,
      'unit_prices': {
        if (isFloating && effectiveModelId != null)
          'model_$effectiveModelId': _basePrice
        else if (_selectedAssetId != null)
          _selectedAssetId.toString(): _basePrice,
        for (final a in _selectedAddons)
          if (a['id'] != null) a['id'].toString(): _computeAddonPrice(a),
      },
    };
    if (activeBranchId != null) {
      payload['branch_id'] = activeBranchId;
      payload['affiliate_id'] = activeBranchId;
    }
    return payload;
  }

  PaymentContext _buildBookingPaymentContext() {
    final bizState = ref.read(businessProvider);
    final authState = ref.read(authProvider);
    final target = _resolveTargetBranch(bizState, authState);
    final activeBranchId = target.branchId;
    final activeBranchName = target.branchName;
    final address = _addressController.text.trim();
    final model = (_selectedAsset?['model'] as Map?) ?? _selectedModel;
    final deviceModelName = model?['name']?.toString() ?? 'Unit Sewa';
    final totalPayable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final isScheduledDp =
        _isScheduledBooking && _scheduledPaymentOption == _ScheduledPaymentOption.dp;
    final payableNow = isScheduledDp
        ? _effectiveDpAmount(totalPayable)
        : totalPayable;

    final payload = _buildBookingPayload();

    final paymentItems = <PaymentItem>[
      PaymentItem(
        name: deviceModelName,
        assetCode: _selectedAsset?['asset_code']?.toString() ??
            (_isScheduledBooking ? 'Floating Unit' : null),
        isAddon: false,
        durationText: '$_selectedDuration Jam',
        price: _basePrice,
      ),
      for (final a in _selectedAddons)
        PaymentItem(
          name: (a['model'] as Map?)?['name']?.toString() ?? 'Aksesoris',
          assetCode: a['asset_code']?.toString(),
          isAddon: true,
          durationText: '$_selectedDuration Jam',
          price: _computeAddonPrice(a),
        ),
    ];

    return PaymentContext.booking(
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      customerAddress: address,
      deviceName: deviceModelName,
      assetCode: _selectedAsset?['asset_code']?.toString(),
      totalAmount: payableNow,
      branchId: activeBranchId,
      branchName: activeBranchName,
      additionalHours: _selectedDuration,
      extraPayload: payload,
      items: paymentItems,
      primarySubtotal: _basePrice,
      addonSubtotal: _addonSubtotal,
      discountAmount: _discountAmount > 0 ? _discountAmount : null,
      voucherCode: _discountAmount > 0 ? _voucherController.text.trim() : null,
      isDownPayment: isScheduledDp,
      contractTotalAmount: isScheduledDp ? totalPayable : null,
    );
  }

  Future<void> _submitScheduledWithoutPayment() async {
    if (!_validateScheduleBeforeSubmit()) return;
    setState(() => _isSubmittingScheduled = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final payload = _buildBookingPayload();
      payload['paid_amount'] = 0;

      await ref.read(bookingRepositoryProvider).createRental(payload);
      ref.invalidate(bookingsListProvider);
      ref.invalidate(dashboardQueueBookingsProvider);
      ref.invalidate(dashboardKpiProvider);
      ref.invalidate(readyAssetsProvider);

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Booking terjadwal berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmittingScheduled = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan booking: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _navigateToUnifiedPaymentPage() async {
    if (!_validateScheduleBeforeSubmit()) return;
    if (_isScheduledBooking && _scheduledPaymentOption == _ScheduledPaymentOption.dp) {
      final totalPayable =
          (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
      final parsedDp = CurrencyFormatter.parse(_dpAmountController.text);
      if (parsedDp <= 0 || parsedDp >= totalPayable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nominal DP harus lebih dari Rp 0 dan kurang dari total tagihan.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    }
    setState(() => _isNavigatingToPayment = true);
    try {
      final paymentContext = _buildBookingPaymentContext();

      final result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            paymentContext: paymentContext,
            onPaymentSuccess: () {
              ref.invalidate(bookingsListProvider);
              ref.invalidate(closingSummaryProvider);
              ref.invalidate(readyAssetsProvider);
              ref.invalidate(inventoryListProvider);
            },
          ),
        ),
      );

      if (result != null && result.isSuccess) {
        if (mounted) {
          Navigator.pop(context, result);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigatingToPayment = false);
      }
    }
  }

  Widget _buildModalHeader({
    String? branchName,
    bool showSwitchBranch = false,
    List<Map<String, dynamic>> availableBranches = const [],
    int? currentBranchId,
  }) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            children: [
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  key: const Key('new_booking_modal_close_button'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 40,
                    height: 40,
                  ),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.obsidian,
                    size: 22,
                  ),
                  tooltip: 'Tutup',
                  onPressed: _handleClosePressed,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Sewa / Booking Baru',
                      style: AppTextStyles.pageHeader,
                    ),
                    if (branchName != null && branchName.isNotEmpty)
                      Text(
                        'Cabang: $branchName',
                        key: const Key('booking_active_branch_subtitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
              ),
              if (showSwitchBranch && availableBranches.length > 1)
                TextButton.icon(
                  key: const Key('booking_switch_branch_button'),
                  onPressed: () => _showTargetBranchPickerSheet(availableBranches, currentBranchId),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: const Color(0xFF111111),
                  ),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                  label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bizState = ref.watch(businessProvider);
    final authState = ref.watch(authProvider);
    final targetBranch = _resolveTargetBranch(bizState, authState);

    ref.listen<int?>(
      businessProvider.select((s) => s.activeBranchId),
      (previous, next) {
        if (previous == next || !mounted) return;
        setState(() {
          _manualBranchOverrideId = null;
          _resetBranchScopedSelections();
        });
        final resolvedNextBranchId = next ??
            _resolveTargetBranch(ref.read(businessProvider), ref.read(authProvider)).branchId;
        _refreshBranchProviders(resolvedNextBranchId);
        if (_isScheduledBooking && _scheduledStartAt != null && resolvedNextBranchId != null) {
          _loadModelAvailability(branchIdOverride: resolvedNextBranchId);
        }
        _syncUnsavedInputState();
      },
    );

    final readyAssetsAsync = (bizState.activeBranchId == null && targetBranch.branchId != null)
        ? ref.watch(readyAssetsByBranchProvider(targetBranch.branchId))
        : ref.watch(readyAssetsProvider);
    if (targetBranch.branchId != null) {
      ref.watch(currentShiftByBranchProvider(targetBranch.branchId));
    }
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalPayable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final isUnitSelected = _isPrimarySelectionReady(
      bizState,
      resolvedBranchId: targetBranch.branchId,
    );

    return PopScope(
      canPop: !_hasUnsavedInput,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _promptDiscardBooking();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: widget.showAppBar
            ? RentCoreAppBar(
                titleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _isScheduledBooking
                          ? 'Jadwalkan Booking Baru'
                          : 'Transaksi Sewa Baru di Meja Kasir',
                      style: AppTextStyles.pageHeader,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (targetBranch.branchName != null && targetBranch.branchName!.isNotEmpty)
                      Text(
                        'Cabang: ${targetBranch.branchName}',
                        key: const Key('booking_active_branch_subtitle'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                  ],
                ),
                actions: [
                  if (targetBranch.isConsolidatedFallback && targetBranch.availableBranches.length > 1)
                    TextButton.icon(
                      key: const Key('booking_switch_branch_button'),
                      onPressed: () => _showTargetBranchPickerSheet(
                        targetBranch.availableBranches,
                        targetBranch.branchId,
                      ),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF111111)),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                      label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                ],
              )
            : null,
        body: Column(
          children: [
            if (!widget.showAppBar)
              _buildModalHeader(
                branchName: targetBranch.branchName,
                showSwitchBranch: targetBranch.isConsolidatedFallback,
                availableBranches: targetBranch.availableBranches,
                currentBranchId: targetBranch.branchId,
              ),
            Expanded(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // STEPPER PROGRESS HEADER
                    _buildStepperHeader(),

                    // STEP BODY
                    if (_currentStep == 0)
                      _buildStep1UnitAndDuration(readyAssetsAsync, categoriesAsync, isUnitSelected)
                    else if (_currentStep == 1)
                      _buildStep2CustomerAndCollateral()
                    else
                      _buildStep3SummaryAndPayment(totalPayable, isUnitSelected),
                  ],
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: _buildStickyBottomNavigation(totalPayable, isUnitSelected),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Flexible(
            flex: 3,
            child: _buildStepItem(
              step: 0,
              label: '1. Unit',
              icon: Icons.phone_iphone_rounded,
            ),
          ),
          _buildStepDivider(0),
          Flexible(
            flex: 4,
            child: _buildStepItem(
              step: 1,
              label: '2. Penyewa',
              icon: Icons.person_rounded,
            ),
          ),
          _buildStepDivider(1),
          Flexible(
            flex: 4,
            child: _buildStepItem(
              step: 2,
              label: '3. Ringkasan',
              icon: Icons.assignment_turned_in_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem({
    required int step,
    required String label,
    required IconData icon,
  }) {
    final isActive = _currentStep == step;
    final isDone = _currentStep > step;
    final isClickable = isDone;

    final color = isActive
        ? AppColors.obsidian
        : (isDone ? AppColors.success : AppColors.textMuted);

    return InkWell(
      onTap: isClickable ? () => setState(() => _currentStep = step) : null,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.obsidian
                    : (isDone ? AppColors.successLight : AppColors.surfaceMuted),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? AppColors.obsidian
                      : (isDone ? AppColors.success : AppColors.border),
                ),
              ),
              child: Center(
                child: isDone
                    ? const Icon(Icons.check_rounded, size: 11, color: AppColors.success)
                    : Icon(icon, size: 10, color: isActive ? Colors.white : AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepDivider(int step) {
    final isDone = _currentStep > step;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        color: isDone ? AppColors.success : AppColors.border,
      ),
    );
  }

  Widget _buildUnitSelectionRow({
    Key? key,
    required bool isSelected,
    required bool isEnabled,
    required bool isAvailable,
    required String? imageUrl,
    required IconData fallbackIcon,
    required String title,
    required String subtitle,
    Color subtitleColor = const Color(0xFF6B7280),
    FontWeight subtitleWeight = FontWeight.w400,
    required String rateLabel,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Opacity(
        opacity: (isEnabled || isSelected) ? 1.0 : 0.55,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          color: isSelected ? const Color(0xFFF9FAFB) : Colors.white,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: isSelected
                    ? (isAvailable ? const Color(0xFF111111) : AppColors.danger)
                    : AppColors.textMuted,
              ),
              const SizedBox(width: 8),
              UnitThumbnail(
                imageUrl: imageUrl,
                fallbackIcon: fallbackIcon,
                size: 34,
                iconSize: 16,
                borderRadius: 8,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        fontSize: 13.5,
                        color: const Color(0xFF111111),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: subtitleWeight,
                        color: subtitleColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width < 350 ? 84 : 120,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    rateLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: Color(0xFF111111),
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

  Widget _buildStep1UnitAndDuration(
    AsyncValue<List<dynamic>> readyAssetsAsync,
    AsyncValue<List<dynamic>> categoriesAsync,
    bool isUnitSelected,
  ) {
    final bizState = ref.watch(businessProvider);
    final authState = ref.watch(authProvider);
    final targetBranch = _resolveTargetBranch(bizState, authState);
    final floatingAllowed = _isFloatingAllowedForActiveBranch(
      bizState,
      resolvedBranchId: targetBranch.branchId,
    );
    final showFloatingModels = _isScheduledBooking && floatingAllowed && !_pinSpecificUnit;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (targetBranch.branchId == null) ...[
            Container(
              key: const Key('consolidated_branch_booking_warning'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.store_mall_directory_outlined, size: 18, color: AppColors.danger),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tidak ada cabang aktif yang tersedia untuk transaksi booking.',
                      style: TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (targetBranch.isConsolidatedFallback) ...[
            Container(
              key: const Key('consolidated_branch_fallback_banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.storefront_rounded, size: 16, color: Color(0xFF374151)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mode Semua Cabang aktif. Booking diarahkan ke ${targetBranch.branchName ?? 'cabang terpilih'}.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF374151), fontWeight: FontWeight.w500),
                    ),
                  ),
                  if (targetBranch.availableBranches.length > 1)
                    InkWell(
                      onTap: () => _showTargetBranchPickerSheet(
                        targetBranch.availableBranches,
                        targetBranch.branchId,
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          'Ubah',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF111111)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          const Text(
            'MODEL PERANGKAT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),

          // Real-Time Unit Search Field
          TextField(
            key: const Key('booking_unit_search_field'),
            controller: _unitSearchController,
            onChanged: (value) {
              setState(() {
                _unitSearchQuery = value.trim();
                _showAllUnits = false;
              });
              if (showFloatingModels) {
                _loadModelAvailability();
              }
            },
            decoration: InputDecoration(
              hintText: showFloatingModels
                  ? 'Cari nama model atau merek...'
                  : 'Cari nama unit, merek, atau kode...',
              hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 19, color: AppColors.textSecondary),
              suffixIcon: _unitSearchQuery.isNotEmpty
                  ? IconButton(
                      key: const Key('booking_unit_search_clear'),
                      icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                      onPressed: () {
                        _unitSearchController.clear();
                        setState(() {
                          _unitSearchQuery = '';
                          _showAllUnits = false;
                        });
                        if (showFloatingModels) {
                          _loadModelAvailability();
                        }
                      },
                    )
                  : null,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Category Filter Chips (Horizontally Scrollable)
          categoriesAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
            data: (categories) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        final isSelected = _selectedAssetCategoryId == null;
                        return ChoiceChip(
                          label: const Text('Semua'),
                          selected: isSelected,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          visualDensity: VisualDensity.compact,
                          onSelected: (_) {
                            setState(() {
                              _selectedAssetCategoryId = null;
                              _showAllUnits = false;
                            });
                            if (showFloatingModels) {
                              _loadModelAvailability();
                            }
                          },
                          selectedColor: const Color(0xFF111111),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : const Color(0xFF111111),
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 12,
                          ),
                        );
                      }
                      final cat = categories[index - 1];
                      final isSelected = _selectedAssetCategoryId == cat['id'];
                      return ChoiceChip(
                        label: Text(cat['name'] ?? ''),
                        selected: isSelected,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() {
                            _selectedAssetCategoryId = cat['id'];
                            _showAllUnits = false;
                          });
                          if (showFloatingModels) {
                            _loadModelAvailability();
                          }
                        },
                        selectedColor: const Color(0xFF111111),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : const Color(0xFF111111),
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          ),

          if (_isScheduledBooking && floatingAllowed) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih nomor seri unit tertentu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF111111),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Switch.adaptive(
                    key: const Key('toggle_pin_specific_unit'),
                    value: _pinSpecificUnit,
                    activeThumbColor: const Color(0xFF111111),
                    onChanged: (v) {
                      setState(() {
                        _pinSpecificUnit = v;
                        _selectedAsset = null;
                        _selectedAssetId = null;
                        if (!v) {
                          _loadModelAvailability();
                        }
                      });
                    },
                  ),
                ],
              ),
            ),
          ],

          if (_assetValidationError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _assetValidationError!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (showFloatingModels)
            _buildFloatingModelList()
          else
            readyAssetsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Gagal memuat unit: $e'),
              data: (assets) {
                final filteredAssets = assets
                    .where((a) {
                      final aId = _parseId(a['id']);
                      final isCurrentlySelected = _selectedAssetId != null && aId == _selectedAssetId;
                      if (isCurrentlySelected) return true;
                      final aModelId = _parseId(a['model_id']) ?? _parseId(a['model']?['id']);
                      final aCatId = _parseId(a['model']?['category_id']);
                      final matchesCategory = _selectedAssetCategoryId == null ||
                          aCatId == _selectedAssetCategoryId;
                      if (!matchesCategory) return false;
                      if (_isScheduledBooking &&
                          _pinSpecificUnit &&
                          _selectedModelId != null &&
                          aModelId != _selectedModelId) {
                        return false;
                      }
                      return a is Map<String, dynamic> && _matchesUnitSearch(a, _unitSearchQuery);
                    })
                    .toList();

                if (filteredAssets.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _unitSearchQuery.isNotEmpty
                                ? 'Tidak ada unit yang cocok dengan pencarian "$_unitSearchQuery".'
                                : 'Tidak ada unit rental ready sewa saat ini di kategori ini.',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final displayedAssets = _showAllUnits
                    ? filteredAssets
                    : filteredAssets.take(_initialUnitCap).toList();
                if (!_showAllUnits && _selectedAssetId != null) {
                  final selectedInDisplayed = displayedAssets.any(
                    (a) => _parseId(a['id']) == _selectedAssetId,
                  );
                  if (!selectedInDisplayed) {
                    for (final a in filteredAssets) {
                      if (_parseId(a['id']) == _selectedAssetId) {
                        displayedAssets.insert(0, a);
                        break;
                      }
                    }
                  }
                }
                final hasMoreUnits = filteredAssets.length > _initialUnitCap && !_showAllUnits;

                return Column(
                  children: [
                    for (int i = 0; i < displayedAssets.length; i++) ...[
                      if (i > 0)
                        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                      Builder(
                        builder: (context) {
                          final asset = displayedAssets[i];
                          final assetId = _parseId(asset['id']);
                          final modelId = _parseId(asset['model_id']) ?? _parseId(asset['model']?['id']);
                          final isSelected = _selectedAssetId != null && assetId == _selectedAssetId;
                          final isAvailableOnSchedule = _isAssetAvailableForSchedule(assetId, modelId);
                          final model = asset['model'] ?? {};
                          final category = model['category'] ?? {};
                          final tiers = _getAvailableTiers(asset);
                          final primaryRateLabel = _formatPrimaryUnitRateLabel(tiers);
                          final snFormatted = _formatLast4Sn(asset['serial_number']?.toString());
                          final grade = asset['condition_grade']?.toString();
                          final bh = asset['battery_health'];
                          final code = asset['asset_code']?.toString() ?? '';
                          final conflictReason = _getAssetConflictReason(assetId);
                          final metaText = !isAvailableOnSchedule
                              ? (conflictReason ?? 'Tidak tersedia pada jadwal ini')
                              : [
                                  if (code.isNotEmpty) code,
                                  if (grade != null && grade.isNotEmpty) 'Grade $grade',
                                  if (bh != null) 'BH $bh%',
                                  if (snFormatted.isNotEmpty) 'SN: $snFormatted',
                                ].join(' • ');

                          return _buildUnitSelectionRow(
                            isSelected: isSelected,
                            isEnabled: true,
                            isAvailable: isAvailableOnSchedule,
                            imageUrl: extractUnitImageUrl(
                              model: model is Map ? model : null,
                              asset: asset is Map ? asset : null,
                            ),
                            fallbackIcon: _getCategoryIcon(category['name']),
                            title: model['name']?.toString() ?? '',
                            subtitle: metaText,
                            subtitleColor: isAvailableOnSchedule
                                ? const Color(0xFF6B7280)
                                : const Color(0xFFEF4444),
                            subtitleWeight: isAvailableOnSchedule
                                ? FontWeight.w400
                                : FontWeight.w500,
                            rateLabel: primaryRateLabel,
                            onTap: () => _onAssetSelected(asset),
                          );
                        },
                      ),
                    ],
                    if (hasMoreUnits)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InkWell(
                          key: const Key('booking_show_all_units'),
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setState(() => _showAllUnits = true),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Text(
                              'Lihat semua (${filteredAssets.length} unit)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          ),

          // DURATION & SCHEDULE SECTION
          const Text(
            'DURASI & JADWAL',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 10),
          _buildCompactScheduleAndReturnBlock(isUnitSelected),
          const SizedBox(height: 12),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isUnitSelected ? 1.0 : 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_durationValidationError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _durationValidationError!,
                            style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                readyAssetsAsync.when(
                  loading: () => const SizedBox.shrink(),
                  error: (e, s) => const SizedBox.shrink(),
                  data: (assets) {
                    Map<String, dynamic>? selectedAsset;
                    for (final a in assets) {
                      if (_parseId(a['id']) == _selectedAssetId) {
                        selectedAsset = a;
                        break;
                      }
                    }
                    selectedAsset ??= _selectedAsset;
                    final activeModel = _findSelectedModelInAvailability();
                    final availableTiers = (showFloatingModels && activeModel != null)
                        ? _getAvailableTiersForModel(activeModel)
                        : (selectedAsset != null
                            ? _getAvailableTiers(selectedAsset)
                            : _getAvailableTiersForModel(activeModel));

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: availableTiers.map((tier) {
                              final isSelected = _selectedRateHours == tier.hours &&
                                  _selectedDurationUnit == tier.unit &&
                                  _selectedDurationValue == tier.value;
                              return ChoiceChip(
                                label: Text(tier.label),
                                selected: isSelected,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                visualDensity: VisualDensity.compact,
                                onSelected: isUnitSelected ? (_) => _onTierSelected(tier) : null,
                                selectedColor: const Color(0xFF111111),
                                labelStyle: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : const Color(0xFF111111),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        if (isUnitSelected && _selectedDuration != null) ...[
                          const SizedBox(width: 8),
                          _buildDurationMultiplierRow(
                            totalHours: _selectedDuration!,
                            canDecrement: _durationMultiplier > 1,
                            canIncrement: _durationMultiplier < _maxDurationMultiplier,
                          ),
                        ],
                      ],
                    );
                  },
                ),

                const SizedBox(height: 10),

                // Voucher Input Field
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: TextField(
                          controller: _voucherController,
                          enabled: isUnitSelected,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Kode voucher...',
                            hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                            prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 18),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 42,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF111111),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(84, 42),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: (isUnitSelected && !_isValidatingVoucher) ? _validateVoucher : null,
                        child: _isValidatingVoucher
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Terapkan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                if (_voucherMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _voucherMessage!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _discountAmount > 0 ? AppColors.success : AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),

          _buildAddonsSelectionSection(readyAssetsAsync, categoriesAsync),
        ],
      ),
    );
  }

  Widget _buildFloatingModelList() {
    if (_isLoadingModelAvailability) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }

    if (_modelAvailabilityError != null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, size: 18, color: AppColors.danger),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Gagal memuat ketersediaan model: $_modelAvailabilityError',
                style: const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
            TextButton(
              onPressed: _loadModelAvailability,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    final query = _unitSearchQuery.trim().toLowerCase();
    final filteredModels = _modelAvailabilityList.where((model) {
      final totalUnits = _parseId(model['total_units']) ?? 0;
      if (totalUnits <= 0) {
        return false;
      }
      final modelId = _parseId(model['id']);
      if (_selectedModelId != null && modelId == _selectedModelId) {
        return true;
      }
      final catId = _parseId(model['category_id']) ?? _parseId(model['category']?['id']);
      if (_selectedAssetCategoryId != null && catId != _selectedAssetCategoryId) {
        return false;
      }
      if (query.isEmpty) return true;
      final name = model['name']?.toString().toLowerCase() ?? '';
      final brand = model['brand']?.toString().toLowerCase() ?? '';
      return name.contains(query) || brand.contains(query);
    }).toList();

    if (filteredModels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: AppColors.textMuted),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tidak ada model perangkat tersedia pada kategori atau pencarian ini.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < filteredModels.length; i++) ...[
          if (i > 0)
            const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          Builder(
            builder: (context) {
              final model = filteredModels[i];
              final modelId = _parseId(model['id']);
              final isSelected = _selectedModelId != null && _selectedModelId == modelId;
              final availableSlots = _parseId(model['available_slots']) ?? 0;
              final totalUnits = _parseId(model['total_units']) ?? 0;
              final isAvailable = availableSlots > 0;
              final category = model['category'] as Map?;
              final tiers = _getAvailableTiersForModel(model);
              final primaryRateLabel = _formatPrimaryUnitRateLabel(tiers);
              final subtitle = isAvailable
                  ? 'Tersedia $availableSlots dari $totalUnits unit'
                  : (isSelected ? 'Tidak tersedia pada jadwal ini' : 'Penuh');

              return _buildUnitSelectionRow(
                key: Key('floating_model_card_$modelId'),
                isSelected: isSelected,
                isEnabled: isAvailable,
                isAvailable: isAvailable,
                imageUrl: extractUnitImageUrl(model: model),
                fallbackIcon: _getCategoryIcon(category?['name']?.toString()),
                title: model['name']?.toString() ?? '',
                subtitle: subtitle,
                subtitleColor: isAvailable
                    ? const Color(0xFF6B7280)
                    : const Color(0xFFEF4444),
                subtitleWeight: isAvailable ? FontWeight.w400 : FontWeight.w500,
                rateLabel: primaryRateLabel,
                onTap: isAvailable ? () => _onModelSelected(model) : null,
              );
            },
          ),
        ],
      ],
    );
  }

  Widget _buildDurationMultiplierRow({
    required int totalHours,
    required bool canDecrement,
    required bool canIncrement,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('booking_multiplier_decrement'),
                  onTap: canDecrement
                      ? () => _onMultiplierChanged(_durationMultiplier - 1)
                      : null,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(9),
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.remove_rounded,
                      size: 16,
                      color: canDecrement ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 34),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                child: Text(
                  '${_durationMultiplier}x',
                  key: const Key('booking_multiplier_value'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('booking_multiplier_increment'),
                  onTap: canIncrement
                      ? () => _onMultiplierChanged(_durationMultiplier + 1)
                      : null,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(9),
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: canIncrement ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '$totalHours Jam',
          key: const Key('booking_multiplier_total_hours'),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildAddonsSelectionSection(
    AsyncValue<List<dynamic>> readyAssetsAsync,
    AsyncValue<List<dynamic>> categoriesAsync,
  ) {
    return readyAssetsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (assets) {
        final addonAssets = assets.where((a) {
          final m = a['model'] as Map? ?? {};
          final c = m['category'] as Map? ?? {};
          final isAddonModel = m['is_addon'] == true || m['is_addon'] == 1;
          final isAddonCat = c['is_addon'] == true || c['is_addon'] == 1;
          final catName = (c['name']?.toString() ?? '').toLowerCase();
          final isKnownAddon = catName.contains('aksesoris') ||
              catName.contains('accessory') ||
              catName.contains('power bank') ||
              catName.contains('charger') ||
              catName.contains('tripod');
          return isAddonModel || isAddonCat || isKnownAddon;
        }).toList();

        if (addonAssets.isEmpty) {
          return const SizedBox.shrink();
        }

        final categoryFilteredAddons = _selectedAddonCategoryId == null
            ? addonAssets
            : addonAssets.where((a) => a['model']?['category_id'] == _selectedAddonCategoryId).toList();

        final addonQuery = _addonSearchQuery.trim().toLowerCase();
        final filteredAddons = addonQuery.isEmpty
            ? categoryFilteredAddons
            : categoryFilteredAddons.where((a) {
                final model = a['model'] as Map? ?? {};
                final category = model['category'] as Map? ?? {};
                final name = (model['name']?.toString() ?? '').toLowerCase();
                final brand = (model['brand']?.toString() ?? '').toLowerCase();
                final desc = (model['description']?.toString() ?? '').toLowerCase();
                final code = (a['asset_code']?.toString() ?? '').toLowerCase();
                final cat = (category['name']?.toString() ?? '').toLowerCase();
                return name.contains(addonQuery) ||
                    brand.contains(addonQuery) ||
                    desc.contains(addonQuery) ||
                    code.contains(addonQuery) ||
                    cat.contains(addonQuery);
              }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            ),
            const Text(
              'ADD-ON (OPSIONAL)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.6,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 10),

            // Real-Time Add-on Search Field
            TextField(
              key: const Key('booking_addon_search_field'),
              controller: _addonSearchController,
              onChanged: (value) => setState(() {
                _addonSearchQuery = value.trim();
              }),
              decoration: InputDecoration(
                hintText: 'Cari add-on...',
                hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
                suffixIcon: _addonSearchQuery.isNotEmpty
                    ? IconButton(
                        key: const Key('booking_addon_search_clear'),
                        icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
                        onPressed: () {
                          _addonSearchController.clear();
                          setState(() => _addonSearchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Addon items list
            if (filteredAddons.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _addonSearchQuery.isNotEmpty
                      ? 'Tidak ada add-on yang cocok dengan "$_addonSearchQuery".'
                      : 'Tidak ada add-on tersedia.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              )
            else
              Column(
                children: [
                  for (int i = 0; i < filteredAddons.length; i++) ...[
                    if (i > 0)
                      const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
                    Builder(
                      builder: (context) {
                        final addon = filteredAddons[i];
                        final isSelected = _selectedAddons.any((a) => a['id'] == addon['id']);
                        final model = addon['model'] as Map? ?? {};
                        final modelName = model['name']?.toString() ?? 'Aksesoris';
                        final price = _computeAddonPrice(addon);
                        final assetCode = addon['asset_code']?.toString() ?? '-';

                        return InkWell(
                          onTap: () => _toggleAddon(addon),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                            color: isSelected ? const Color(0xFFF9FAFB) : Colors.white,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Checkbox(
                                  value: isSelected,
                                  activeColor: const Color(0xFF111111),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  onChanged: (_) => _toggleAddon(addon),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '$modelName • $assetCode',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 13.5,
                                      color: Color(0xFF111111),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '+ ${CurrencyFormatter.format(price)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12.5,
                                    color: isSelected
                                        ? const Color(0xFF111111)
                                        : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),

            if (_selectedAddons.isNotEmpty) ...[
              const Divider(height: 16, thickness: 1, color: Color(0xFFF3F4F6)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Subtotal Add-on (${_selectedAddons.length}x)',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(_addonSubtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildStep2CustomerAndCollateral() {
    InputDecoration compactFieldDecoration({
      required String labelText,
      String? hintText,
      bool alignLabelWithHint = false,
      Widget? prefixIcon,
    }) {
      return InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(
          fontSize: 12,
          color: Color(0xFF6B7280),
        ),
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 12,
          color: AppColors.textMuted,
        ),
        alignLabelWithHint: alignLabelWithHint,
        prefixIcon: prefixIcon,
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF111111), width: 1.2),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'DATA PENYEWA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: const Key('step2_search_customer_action'),
                  onTap: _isSearchingCustomer ? null : _searchCustomer,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: _isSearchingCustomer
                        ? const SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF111111),
                            ),
                          )
                        : const Text(
                            'Cari Pelanggan',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Customer Name
            TextFormField(
              controller: _nameController,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF111111)),
              decoration: compactFieldDecoration(
                labelText: 'Nama Penyewa *',
                prefixIcon: const Icon(Icons.person_outline_rounded, size: 18),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 3) {
                  return 'Nama penyewa minimal 3 karakter';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // WhatsApp Phone
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF111111)),
              decoration: compactFieldDecoration(
                labelText: 'Nomor WhatsApp *',
                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 8) {
                  return 'Nomor WhatsApp wajib diisi minimal 8 digit';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Address
            TextFormField(
              controller: _addressController,
              maxLines: 3,
              minLines: 2,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF111111)),
              decoration: compactFieldDecoration(
                labelText: 'Alamat (KTP/SIM) *',
                hintText: 'Jalan, nomor rumah, RT/RW, kelurahan, kecamatan, kota',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(top: 2, bottom: 18),
                  child: Icon(Icons.home_outlined, size: 18),
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().length < 5) {
                  return 'Alamat (KTP/SIM) wajib diisi lengkap';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            // Collateral Safe Slot Dropdown
            DropdownButtonFormField<String>(
              initialValue: _safeSlots.contains(_selectedSafeSlot)
                  ? _selectedSafeSlot
                  : _safeSlots.first,
              decoration: compactFieldDecoration(
                labelText: _isScheduledBooking
                    ? 'Slot Brankas Jaminan'
                    : 'Slot Brankas Jaminan *',
                prefixIcon: const Icon(Icons.shield_outlined, size: 18),
              ),
              isExpanded: true,
              items: _safeSlots.map((slot) {
                return DropdownMenuItem<String>(
                  value: slot,
                  child: Text(
                    slot,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF111111),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _selectedSafeSlot = val;
                    _slotController.text = val;
                  });
                }
              },
              validator: (v) {
                if (!_isScheduledBooking && (v == null || v.trim().isEmpty)) {
                  return 'Slot brankas jaminan wajib dipilih';
                }
                return null;
              },
            ),

            // Customer Search Status Feedback
            if (_foundCustomer != null && _foundCustomer!['is_blacklisted'] == true)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.block_rounded, color: AppColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DAFTAR HITAM (BLACKLIST)',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            'Alasan: ${_foundCustomer!['blacklist_reason'] ?? 'Pelanggan bermasalah'}',
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else if (_foundCustomer != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pelanggan Terdaftar • ${_foundCustomer!['bookings_count'] ?? 0}x Sewa',
                        style: const TextStyle(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 11.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              )
            else if (_customerLookupMessage != null)
              Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _customerLookupMessage!,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiptMetaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF111111),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReceiptTotalRow(
    String label,
    String value, {
    Color labelColor = const Color(0xFF6B7280),
    Color valueColor = const Color(0xFF111111),
    FontWeight labelWeight = FontWeight.w400,
    FontWeight valueWeight = FontWeight.w500,
    double labelSize = 13,
    double valueSize = 13,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: labelWeight,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: valueWeight,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3SummaryAndPayment(double totalPayable, bool isUnitSelected) {
    final bizState = ref.watch(businessProvider);
    final model = (_selectedAsset?['model'] as Map?) ?? _selectedModel;
    final deviceModelName = model?['name']?.toString() ?? 'Unit Sewa';
    final isFloating = _isScheduledBooking &&
        _isFloatingAllowedForActiveBranch(bizState) &&
        !_pinSpecificUnit &&
        _selectedAsset == null;
    final unitCode = _selectedAsset?['asset_code']?.toString() ?? '-';
    final durationLabel =
        '$_selectedDuration Jam${_durationMultiplier > 1 ? ' (${_durationMultiplier}x)' : ''}';
    final graceMinutes = _graceMinutesForActiveBranch(bizState);
    final graceDeadline = (_scheduledStartAt ?? DateTime.now()).add(
      Duration(minutes: graceMinutes),
    );
    final customerName = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final collateralSlot = _slotController.text.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'RINGKASAN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 12),

          // Primary Unit Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      deviceModelName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$durationLabel • ${isFloating ? 'Floating Unit' : unitCode}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                CurrencyFormatter.format(_basePrice),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111111),
                ),
              ),
            ],
          ),

          // Add-on Line Items
          if (_selectedAddons.isNotEmpty)
            for (final addon in _selectedAddons) ...[
              const SizedBox(height: 12),
              Builder(
                builder: (context) {
                  final addonModel = addon['model'] as Map? ?? {};
                  final addonName =
                      addonModel['name']?.toString() ?? 'Aksesoris';
                  final rawCode = addon['asset_code']?.toString().trim();
                  final addonCode =
                      (rawCode != null && rawCode.isNotEmpty) ? rawCode : null;
                  final qty =
                      (addon['qty'] as num?)?.toInt() ??
                      (addon['quantity'] as num?)?.toInt() ??
                      1;
                  final price = _computeAddonPrice(addon);
                  final subtitle =
                      'Add-on${addonCode != null ? ' • $addonCode' : ''}${qty > 1 ? ' • ${qty}x' : ''}';
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              addonName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF111111),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        CurrencyFormatter.format(price),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF111111),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          ),

          // Schedule & Customer Metadata Rows
          if (_isScheduledBooking && _scheduledStartAt != null) ...[
            _buildReceiptMetaRow(
              'Jadwal Ambil',
              '${DateFormatter.formatFull(_scheduledStartAt)} (Batas ${DateFormatter.formatTime(graceDeadline)})',
            ),
            _buildReceiptMetaRow(
              'Kembali',
              _formatReturnTimeLabel(),
            ),
          ] else ...[
            _buildReceiptMetaRow(
              'Waktu Sewa',
              'Mulai Sekarang • Kembali ${_formatReturnTimeLabel(includeWib: false)}',
            ),
          ],
          _buildReceiptMetaRow(
            'Penyewa',
            '$customerName${phone.isNotEmpty ? ' • $phone' : ''}',
          ),
          if (collateralSlot.isNotEmpty)
            _buildReceiptMetaRow('Jaminan', collateralSlot),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          ),

          // Totals
          _buildReceiptTotalRow(
            'Subtotal Unit',
            CurrencyFormatter.format(_basePrice),
          ),
          if (_selectedAddons.isNotEmpty)
            _buildReceiptTotalRow(
              'Subtotal Add-on (${_selectedAddons.length}x)',
              CurrencyFormatter.format(_addonSubtotal),
            ),
          if (_discountAmount > 0)
            _buildReceiptTotalRow(
              'Diskon Voucher',
              '- ${CurrencyFormatter.format(_discountAmount)}',
              labelColor: AppColors.success,
              valueColor: AppColors.success,
              valueWeight: FontWeight.w600,
            ),
          const SizedBox(height: 6),
          _buildReceiptTotalRow(
            'Total Tagihan',
            CurrencyFormatter.format(totalPayable),
            labelColor: const Color(0xFF111111),
            valueColor: const Color(0xFF111111),
            labelWeight: FontWeight.w700,
            valueWeight: FontWeight.w700,
            labelSize: 15,
            valueSize: 17,
          ),

          if (_isScheduledBooking) ...[
            const SizedBox(height: 20),
            _buildScheduledPaymentSelector(totalPayable),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactScheduleAndReturnBlock(bool isUnitSelected) {
    const ink = Color(0xFF111111);
    const muted = Color(0xFF6B7280);
    final showReturnRow = isUnitSelected && _selectedDuration != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'WAKTU MULAI',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        Material(
          color: Colors.white,
          child: InkWell(
            key: const Key('inline_start_time_row'),
            onTap: _pickScheduledDateTime,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: (!_isScheduledBooking || _scheduledStartAt == null)
                  ? Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 17,
                          color: ink,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Mulai Sekarang',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: ink,
                            ),
                          ),
                        ),
                        InkWell(
                          key: const Key('inline_schedule_action'),
                          onTap: _pickScheduledDateTime,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              'Jadwalkan ›',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        const Icon(
                          Icons.event_rounded,
                          size: 17,
                          color: ink,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormatter.formatFull(_scheduledStartAt),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: ink,
                                ),
                              ),
                              const Text(
                                'Booking Terjadwal',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          key: const Key('inline_reset_now_action'),
                          onTap: _resetToImmediateRental,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            child: Text(
                              'Sekarang',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: muted,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        if (showReturnRow) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatReturnDeadline(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                CurrencyFormatter.format(_basePrice),
                key: const Key('booking_duration_live_subtotal'),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ],
          ),
        ],
        if (_scheduleValidationError != null) ...[
          const SizedBox(height: 6),
          Text(
            _scheduleValidationError!,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScheduledPaymentSelector(double totalPayable) {
    final dpParsed = CurrencyFormatter.parse(_dpAmountController.text);
    final remainingAfterDp =
        (totalPayable - dpParsed).clamp(0.0, totalPayable);

    Widget buildRadioRow({
      required Key key,
      required _ScheduledPaymentOption option,
      required String title,
    }) {
      final isSelected = _scheduledPaymentOption == option;
      return InkWell(
        key: key,
        onTap: () {
          setState(() {
            _scheduledPaymentOption = option;
            if (option == _ScheduledPaymentOption.dp &&
                _dpAmountController.text.trim().isEmpty &&
                totalPayable > 0) {
              _dpAmountController.text =
                  (totalPayable * 0.5).round().toString();
            }
          });
          _syncUnsavedInputState();
        },
        child: SizedBox(
          height: 46,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                  color: isSelected
                      ? const Color(0xFF111111)
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: const Color(0xFF111111),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'PEMBAYARAN',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF6B7280),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildRadioRow(
                  key: const Key('payment_option_full'),
                  option: _ScheduledPaymentOption.full,
                  title: 'Bayar Lunas',
                ),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),
                buildRadioRow(
                  key: const Key('payment_option_dp'),
                  option: _ScheduledPaymentOption.dp,
                  title: 'Bayar DP',
                ),
                if (_scheduledPaymentOption == _ScheduledPaymentOption.dp) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('dp_amount_field'),
                          controller: _dpAmountController,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                          decoration: InputDecoration(
                            labelText: 'Nominal DP (Rp)',
                            hintText: 'Contoh: 150000',
                            isDense: true,
                            prefixText: 'Rp ',
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E7EB),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                color: Color(0xFF111111),
                                width: 1.2,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Sisa saat ambil: ${CurrencyFormatter.format(remainingAfterDp)}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF3F4F6),
                ),
                buildRadioRow(
                  key: const Key('toggle_scheduled_pay_later'),
                  option: _ScheduledPaymentOption.payLater,
                  title: 'Bayar Saat Ambil',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomNavigation(double totalPayable, bool isUnitSelected) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: _buildNavigationButtonRow(totalPayable, isUnitSelected),
        ),
      ),
    );
  }

  Widget _buildNavigationButtonRow(double totalPayable, bool isUnitSelected) {
    final bizState = ref.read(businessProvider);
    if (_currentStep == 0) {
      final canAdvanceStep1 =
          isUnitSelected &&
          _selectedDuration != null &&
          !_isSelectedUnavailableForSchedule(bizState);
      return SizedBox(
        height: 46,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: canAdvanceStep1 ? _onNextToCustomerStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFF111111).withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            minimumSize: const Size.fromHeight(46),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            'Lanjut',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ),
      );
    } else if (_currentStep == 1) {
      return Row(
        children: [
          SizedBox(
            width: 108,
            height: 46,
            child: OutlinedButton(
              onPressed: _onBackStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Kembali',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: _onNextToSummaryStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text(
                  'Lanjut',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          SizedBox(
            width: 108,
            height: 46,
            child: OutlinedButton(
              onPressed: _onBackStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                'Kembali',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton(
                onPressed: (!isUnitSelected || _isNavigatingToPayment || _isSubmittingScheduled)
                    ? null
                    : (_isScheduledBooking && _payLaterScheduled
                        ? _submitScheduledWithoutPayment
                        : _navigateToUnifiedPaymentPage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111111),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF111111).withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  minimumSize: const Size.fromHeight(46),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: (_isNavigatingToPayment || _isSubmittingScheduled)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _isScheduledBooking ? 'Simpan Booking' : 'Buat Sewa',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ),
          ),
        ],
      );
    }
  }
}

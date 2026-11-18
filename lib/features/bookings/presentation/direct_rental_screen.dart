import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/unit_thumbnail.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../../vouchers/data/voucher_repository.dart';
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

  bool get _payLaterScheduled =>
      _scheduledPaymentOption == _ScheduledPaymentOption.payLater;

  Map<String, dynamic>? _selectedModel;
  int? _selectedModelId;
  List<Map<String, dynamic>> _modelAvailabilityList = [];
  bool _isLoadingModelAvailability = false;
  String? _modelAvailabilityError;

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
            borderRadius: BorderRadius.circular(18),
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

  String _formatReturnDeadline() {
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

    return 'Kembali: $dayPrefix, $hh:$mm WIB';
  }

  String _formatLast4Sn(String? sn) {
    if (sn == null || sn.trim().isEmpty) return '';
    final trimmed = sn.trim();
    if (trimmed.length <= 4) return trimmed;
    return '...${trimmed.substring(trimmed.length - 4)}';
  }

  Color _getGradeBgColor(dynamic grade) {
    final g = grade?.toString().toUpperCase() ?? '';
    if (g.contains('A')) return AppColors.successLight;
    if (g.contains('B')) return AppColors.infoLight;
    return AppColors.warningLight;
  }

  Color _getGradeTextColor(dynamic grade) {
    final g = grade?.toString().toUpperCase() ?? '';
    if (g.contains('A')) return AppColors.success;
    if (g.contains('B')) return AppColors.info;
    return AppColors.warning;
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

  bool _isFloatingAllowedForActiveBranch(BusinessState bizState) {
    final branch = bizState.currentBranch;
    if (branch == null) return true;
    return branch['allow_floating_unit_booking'] != false;
  }

  int _graceMinutesForActiveBranch(BusinessState bizState) {
    final branch = bizState.currentBranch;
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
    if (!_isScheduledBooking || _modelAvailabilityList.isEmpty || _isLoadingModelAvailability) {
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
    if (matchedModel == null) return true;
    final availableSlots = (_parseId(matchedModel['available_slots']) ?? 0);
    if (availableSlots <= 0) return false;
    final rawIds = matchedModel['available_asset_ids'];
    if (rawIds is List && assetId != null) {
      return rawIds.map(_parseId).contains(assetId);
    }
    return true;
  }

  bool _isSelectedUnavailableForSchedule(BusinessState bizState) {
    if (!_isScheduledBooking || _isLoadingModelAvailability) return false;
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

  bool _isPrimarySelectionReady(BusinessState bizState) {
    if (!_isScheduledBooking) {
      return _selectedAssetId != null;
    }
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState);
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

  Future<void> _loadModelAvailability() async {
    final startAt = _scheduledStartAt;
    if (!_isScheduledBooking || startAt == null) return;
    final bizState = ref.read(businessProvider);
    if (bizState.activeBusinessId == null) return;

    setState(() {
      _isLoadingModelAvailability = true;
      _modelAvailabilityError = null;
    });

    try {
      final list = await ref.read(bookingRepositoryProvider).fetchModelAvailability(
            startAt: startAt,
            endAt: _effectiveScheduledEndAt,
            branchId: bizState.activeBranchId,
          );
      if (!mounted) return;
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
            // Preserve ID-based selection even if filtered/not returned
            _selectedModelId = targetModelId;
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
    setState(() {
      if (!isReady) {
        _assetValidationError = _isScheduledBooking && _isFloatingAllowedForActiveBranch(bizState) && !_pinSpecificUnit
            ? 'Pilih salah satu model perangkat terlebih dahulu.'
            : 'Pilih salah satu unit rental terlebih dahulu.';
      } else if (isUnavailableOnSchedule) {
        _assetValidationError = 'Unit/model yang dipilih tidak tersedia pada jadwal ini.';
      } else {
        _assetValidationError = null;
      }
      _durationValidationError = _selectedDuration == null ? 'Pilih durasi sewa yang diinginkan.' : null;
    });

    if (!isReady || isUnavailableOnSchedule || _selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isUnavailableOnSchedule
                ? 'Unit/model yang dipilih tidak tersedia pada jadwal ini.'
                : 'Silakan pilih unit/model rental dan durasi terlebih dahulu.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
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
    final activeBranchId = bizState.activeBranchId;
    final address = _addressController.text.trim();
    final customerId = _selectedCustomerId ?? _foundCustomer?['id'];
    final totalHours = _selectedDuration;
    final totalDurationValue = _totalDurationValue;
    final totalPayable =
        (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState);
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
      payload['affiliate_id'] = activeBranchId;
    }
    return payload;
  }

  PaymentContext _buildBookingPaymentContext() {
    final bizState = ref.read(businessProvider);
    final activeBranchId = bizState.activeBranchId;
    final activeBranchName = bizState.activeBranchName;
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

  Widget _buildModalHeader() {
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
                      borderRadius: BorderRadius.circular(12),
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
              const Expanded(
                child: Text(
                  'Sewa / Booking Baru',
                  style: AppTextStyles.pageHeader,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readyAssetsAsync = ref.watch(readyAssetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final bizState = ref.watch(businessProvider);
    final totalPayable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final isUnitSelected = _isPrimarySelectionReady(bizState);

    return PopScope(
      canPop: !_hasUnsavedInput,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _promptDiscardBooking();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: widget.showAppBar
            ? RentCoreAppBar(
                title: _isScheduledBooking
                    ? 'Jadwalkan Booking Baru'
                    : 'Transaksi Sewa Baru di Meja Kasir',
              )
            : null,
        body: Column(
          children: [
            if (!widget.showAppBar) _buildModalHeader(),
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
        borderRadius: BorderRadius.circular(16),
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

  Widget _buildStep1UnitAndDuration(
    AsyncValue<List<dynamic>> readyAssetsAsync,
    AsyncValue<List<dynamic>> categoriesAsync,
    bool isUnitSelected,
  ) {
    final bizState = ref.watch(businessProvider);
    final floatingAllowed = _isFloatingAllowedForActiveBranch(bizState);
    final showFloatingModels = _isScheduledBooking && floatingAllowed && !_pinSpecificUnit;
    final graceMinutes = _graceMinutesForActiveBranch(bizState);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isUnitSelected ? AppColors.obsidian : Colors.grey.shade300,
              width: isUnitSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      showFloatingModels
                          ? 'PILIH MODEL PERANGKAT'
                          : 'PILIH UNIT RENTAL TERSEDIA',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  if (isUnitSelected)
                    StatusBadge(
                      label: showFloatingModels ? 'Model Dipilih' : 'Unit Dipilih',
                      textColor: AppColors.success,
                      backgroundColor: AppColors.successLight,
                      icon: Icons.check_circle_rounded,
                    )
                  else
                    const Text(
                      '*Wajib Dipilih',
                      style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                ],
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
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Category Filter Chips (Horizontally Scrollable)
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (categories) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
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
                              shape: const StadiumBorder(),
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
                              selectedColor: AppColors.obsidian,
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : AppColors.textPrimary,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                            );
                          }
                          final cat = categories[index - 1];
                          final isSelected = _selectedAssetCategoryId == cat['id'];
                          return ChoiceChip(
                            label: Text(cat['name'] ?? ''),
                            selected: isSelected,
                            shape: const StadiumBorder(),
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
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Kunci unit fisik tertentu (Serial/IMEI)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Batas ambil (Grace): $graceMinutes menit',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        key: const Key('toggle_pin_specific_unit'),
                        value: _pinSpecificUnit,
                        activeThumbColor: AppColors.obsidian,
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
                        color: const Color(0xFFF8F9FA),
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
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Column(
                          children: [
                            for (int i = 0; i < displayedAssets.length; i++) ...[
                              if (i > 0)
                                const Divider(height: 1, color: AppColors.borderSubtle),
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

                                  return InkWell(
                                    onTap: () => _onAssetSelected(asset),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      color: isSelected ? const Color(0xFFF8F9FA) : Colors.transparent,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            crossAxisAlignment: CrossAxisAlignment.center,
                                            children: [
                                              Icon(
                                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                                size: 18,
                                                color: isSelected
                                                    ? (isAvailableOnSchedule ? AppColors.obsidian : AppColors.danger)
                                                    : AppColors.textMuted,
                                              ),
                                              const SizedBox(width: 6),
                                              UnitThumbnail(
                                                imageUrl: extractUnitImageUrl(
                                                  model: model is Map ? model : null,
                                                  asset: asset is Map ? asset : null,
                                                ),
                                                fallbackIcon: _getCategoryIcon(category['name']),
                                                size: 32,
                                                iconSize: 16,
                                                borderRadius: 10,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  model['name'] ?? '',
                                                  style: TextStyle(
                                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                                    fontSize: 12.5,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxWidth: MediaQuery.sizeOf(context).width < 350 ? 78 : 116,
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    primaryRateLabel,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 11.5,
                                                      color: AppColors.obsidian,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Padding(
                                            padding: const EdgeInsets.only(left: 26),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (!isAvailableOnSchedule)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.dangerLight,
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Text(
                                                      'Tidak tersedia pada jadwal ini',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.danger,
                                                      ),
                                                    ),
                                                  ),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.surfaceMuted,
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Text(
                                                    asset['asset_code']?.toString() ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w600,
                                                      color: AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                                if (asset['condition_grade'] != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: _getGradeBgColor(asset['condition_grade']),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'Grade ${asset['condition_grade']}',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: _getGradeTextColor(asset['condition_grade']),
                                                      ),
                                                    ),
                                                  ),
                                                if (asset['battery_health'] != null)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.successLight,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'BH ${asset['battery_health']}%',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: AppColors.success,
                                                      ),
                                                    ),
                                                  ),
                                                if (snFormatted.isNotEmpty)
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.surfaceMuted,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      'SN: $snFormatted',
                                                      style: const TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: AppColors.textMuted,
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                      ),
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
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // DURATION & VOUCHER SECTION
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'DURASI SEWA & VOUCHER PROMO',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildCompactScheduleAndReturnBlock(isUnitSelected),
              const SizedBox(height: 10),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isUnitSelected ? 1.0 : 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUnitSelected)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.touch_app_outlined, size: 17, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pilih salah satu unit di atas untuk mengaktifkan pilihan durasi dan voucher.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),

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
                                    shape: const StadiumBorder(),
                                    visualDensity: VisualDensity.compact,
                                    onSelected: isUnitSelected ? (_) => _onTierSelected(tier) : null,
                                    selectedColor: AppColors.obsidian,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      color: isSelected ? Colors.white : AppColors.textPrimary,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
                                fillColor: AppColors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.borderSubtle),
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
                              minimumSize: const Size(84, 42),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
            ],
          ),
        ),
        _buildAddonsSelectionSection(readyAssetsAsync, categoriesAsync),
      ],
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
          borderRadius: BorderRadius.circular(12),
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

    if (filteredModels.isEmpty && _selectedModel != null && _selectedModelId != null) {
      filteredModels.add(_selectedModel!);
    }

    if (filteredModels.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
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

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Column(
        children: [
          for (int i = 0; i < filteredModels.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.borderSubtle),
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

                return InkWell(
                  key: Key('floating_model_card_$modelId'),
                  onTap: isAvailable ? () => _onModelSelected(model) : null,
                  child: Opacity(
                    opacity: (isAvailable || isSelected) ? 1.0 : 0.55,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      color: isSelected ? const Color(0xFFF8F9FA) : Colors.transparent,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected
                                    ? (isAvailable ? AppColors.obsidian : AppColors.danger)
                                    : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              UnitThumbnail(
                                imageUrl: extractUnitImageUrl(model: model),
                                fallbackIcon: _getCategoryIcon(category?['name']?.toString()),
                                size: 32,
                                iconSize: 16,
                                borderRadius: 10,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  model['name']?.toString() ?? '',
                                  style: TextStyle(
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 12.5,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.sizeOf(context).width < 350 ? 78 : 116,
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    primaryRateLabel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                      color: AppColors.obsidian,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Row(
                              children: [
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: isAvailable ? AppColors.successLight : AppColors.dangerLight,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isAvailable
                                            ? 'Tersedia $availableSlots slot'
                                            : (isSelected
                                                ? 'Tidak tersedia pada jadwal ini'
                                                : 'Penuh (0 slot)'),
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: isAvailable ? AppColors.success : AppColors.danger,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Total $totalUnits unit',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
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

        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _selectedAddons.isNotEmpty ? AppColors.obsidian : Colors.grey.shade300,
              width: _selectedAddons.isNotEmpty ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.extension_outlined, size: 17, color: AppColors.obsidian),
                  const SizedBox(width: 6),
                  const Flexible(
                    child: Text(
                      'AKSESORIS & ADD-ON SEWA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 8),
                  if (_selectedAddons.isNotEmpty)
                    StatusBadge(
                      label: '${_selectedAddons.length} Dipilih',
                      textColor: AppColors.success,
                      backgroundColor: AppColors.successLight,
                      icon: Icons.check_circle_rounded,
                    )
                  else
                    const StatusBadge(
                      label: 'Opsional',
                      textColor: AppColors.textSecondary,
                      backgroundColor: AppColors.surfaceMuted,
                    ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih power bank, charger, tripod, atau aksesoris tambahan yang disewa bersamaan.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.borderSubtle),
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
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _addonSearchQuery.isNotEmpty
                        ? 'Tidak ada add-on yang cocok dengan "$_addonSearchQuery".'
                        : 'Tidak ada add-on tersedia.',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Column(
                    children: [
                      for (int i = 0; i < filteredAddons.length; i++) ...[
                        if (i > 0)
                          const Divider(height: 1, color: AppColors.borderSubtle),
                        Builder(
                          builder: (context) {
                            final addon = filteredAddons[i];
                            final isSelected = _selectedAddons.any((a) => a['id'] == addon['id']);
                            final model = addon['model'] as Map? ?? {};
                            final modelName = model['name']?.toString() ?? 'Aksesoris';
                            final price = _computeAddonPrice(addon);
                            final assetCode = addon['asset_code']?.toString() ?? '-';
                            final grade = addon['condition_grade']?.toString();
                            final gradeMeta = grade != null && grade.isNotEmpty
                                ? '$assetCode • Grade $grade'
                                : assetCode;

                            return InkWell(
                              onTap: () => _toggleAddon(addon),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                color: isSelected ? const Color(0xFFF8F9FA) : Colors.transparent,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: AppColors.obsidian,
                                      visualDensity: VisualDensity.compact,
                                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      onChanged: (_) => _toggleAddon(addon),
                                    ),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.power_rounded,
                                        size: 16,
                                        color: isSelected ? Colors.white : AppColors.obsidian,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  modelName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 13,
                                                    color: AppColors.textPrimary,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              ConstrainedBox(
                                                constraints: const BoxConstraints(maxWidth: 112),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerRight,
                                                  child: Text(
                                                    '+ ${CurrencyFormatter.format(price)}',
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w700,
                                                      fontSize: 12.5,
                                                      color: isSelected ? AppColors.obsidian : AppColors.textSecondary,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  gradeMeta,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
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
                ),

              if (_selectedAddons.isNotEmpty) ...[
                const Divider(height: 16, color: AppColors.borderSubtle),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Subtotal Add-on (${_selectedAddons.length} item):',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      CurrencyFormatter.format(_addonSubtotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.obsidian),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
      Widget? suffixIcon,
    }) {
      return InputDecoration(
        labelText: labelText,
        hintText: hintText,
        alignLabelWithHint: alignLabelWithHint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Flexible(
                      child: Text(
                        'DATA PENYEWA & ALAMAT IDENTITAS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Spacer(),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: _searchCustomer,
                      icon: _isSearchingCustomer
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                            )
                          : const Icon(Icons.search_rounded, size: 14, color: AppColors.obsidian),
                      label: const Text(
                        'Cari Riwayat',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.obsidian,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Customer Name
                TextFormField(
                  controller: _nameController,
                  decoration: compactFieldDecoration(
                    labelText: 'Nama Lengkap Penyewa *',
                    prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'Nama lengkap penyewa minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // WhatsApp Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: compactFieldDecoration(
                    labelText: 'Nomor WhatsApp Aktif *',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 19),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded, size: 19),
                      onPressed: _searchCustomer,
                      tooltip: 'Cari Riwayat Pelanggan',
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 8) {
                      return 'Nomor WhatsApp aktif wajib diisi minimal 8 digit';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Address
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: compactFieldDecoration(
                    labelText: 'Alamat Sesuai Kartu Identitas *',
                    hintText: 'Jalan, nomor rumah, RT/RW, kelurahan/desa, kecamatan, kota/kabupaten',
                    alignLabelWithHint: true,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 24),
                      child: Icon(Icons.home_outlined, size: 19),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 5) {
                      return 'Alamat sesuai kartu identitas wajib diisi lengkap';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),

                // Collateral Safe Slot Dropdown
                DropdownButtonFormField<String>(
                  initialValue: _safeSlots.contains(_selectedSafeSlot) ? _selectedSafeSlot : _safeSlots.first,
                  decoration: compactFieldDecoration(
                    labelText: 'Slot Brankas Penyimpanan Jaminan Fisik *',
                    prefixIcon: const Icon(Icons.shield_outlined, size: 19),
                  ),
                  isExpanded: true,
                  items: _safeSlots.map((slot) {
                    return DropdownMenuItem<String>(
                      value: slot,
                      child: Text(
                        slot,
                        style: const TextStyle(fontSize: 13),
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
                    if (v == null || v.trim().isEmpty) {
                      return 'Lokasi slot brankas jaminan fisik wajib dipilih';
                    }
                    return null;
                  },
                ),

                // Customer Search Status Feedback
                if (_foundCustomer != null && _foundCustomer!['is_blacklisted'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded, color: AppColors.danger, size: 20),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_rounded, color: AppColors.success, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pelanggan Terdaftar • ${_foundCustomer!['bookings_count'] ?? 0}x Sewa Selesai',
                            style: const TextStyle(
                              color: AppColors.success,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
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
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
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
    final graceMinutes = _graceMinutesForActiveBranch(bizState);
    final graceDeadline = (_scheduledStartAt ?? DateTime.now()).add(
      Duration(minutes: graceMinutes),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // OVERVIEW REVIEW CARD
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'RINGKASAN SEWA & IDENTITAS PENYEWA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Unit + Add-ons Unified Summary Block (No double nested borders)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.obsidian,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      deviceModelName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${isFloating ? 'Floating Unit (Pilih SN saat serah terima)' : (_selectedAsset?['asset_code'] ?? '-')} • Durasi: $_selectedDuration Jam${_durationMultiplier > 1 ? ' (${_durationMultiplier}x)' : ''}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(_basePrice),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 12,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                          if (_isScheduledBooking && _scheduledStartAt != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.event_available_rounded, size: 13, color: AppColors.obsidian),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Jadwal ambil: ${DateFormatter.formatFull(_scheduledStartAt)} • Batas ambil: ${DateFormatter.formatTime(graceDeadline)}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.infoLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 12, color: AppColors.info),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    _formatReturnDeadline(),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.info,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Add-on Review Rows separated by thin Divider
                    if (_selectedAddons.isNotEmpty)
                      for (final addon in _selectedAddons) ...[
                        const Divider(height: 1, color: AppColors.borderSubtle),
                        Builder(
                          builder: (context) {
                            final addonModel = addon['model'] as Map? ?? {};
                            final addonName = addonModel['name']?.toString() ?? 'Aksesoris';
                            final price = _computeAddonPrice(addon);
                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: AppColors.obsidian,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.power_rounded, color: Colors.white, size: 14),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          addonName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12.5,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${addon['asset_code'] ?? '-'} • Add-on',
                                          style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const StatusBadge(
                                    label: 'Add-on',
                                    textColor: AppColors.obsidian,
                                    backgroundColor: AppColors.surface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.format(price),
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                  ],
                ),
              ),
              const SizedBox(height: 8),

              // Customer Card Review
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.obsidian, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _nameController.text.trim(),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                          Text(
                            'WA: ${_phoneController.text.trim()} • Slot: ${_slotController.text.trim()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Itemized Bill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Subtotal Perangkat Utama:',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(_basePrice),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              if (_selectedAddons.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Subtotal Add-on (${_selectedAddons.length} unit):',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '+ ${CurrencyFormatter.format(_addonSubtotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.obsidian),
                    ),
                  ],
                ),
              ],
              if (_discountAmount > 0) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Diskon Promo Voucher:',
                        style: TextStyle(fontSize: 13, color: AppColors.success),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '- ${CurrencyFormatter.format(_discountAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.success),
                    ),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'TOTAL TAGIHAN POS:',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    CurrencyFormatter.format(totalPayable),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: AppColors.obsidian),
                  ),
                ],
              ),
              if (_isScheduledBooking) ...[
                const SizedBox(height: 10),
                _buildScheduledPaymentSelector(totalPayable),
              ],
            ],
          ),
        ),
      ],
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: muted,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Column(
            children: [
              Material(
                color: const Color(0xFFF8F9FA),
                child: InkWell(
                  key: const Key('inline_start_time_row'),
                  onTap: _pickScheduledDateTime,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                const Divider(height: 1, color: AppColors.borderSubtle),
                Container(
                  color: AppColors.infoLight,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 15, color: AppColors.info),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _formatReturnDeadline(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.format(_basePrice),
                        key: const Key('booking_duration_live_subtotal'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.info,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
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

    Widget buildOptionTile({
      required Key key,
      required _ScheduledPaymentOption option,
      required String title,
      required String subtitle,
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
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF8F9FA) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? AppColors.obsidian : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 18,
                color: isSelected ? AppColors.obsidian : AppColors.textMuted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'OPSI PEMBAYARAN BOOKING',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        buildOptionTile(
          key: const Key('payment_option_full'),
          option: _ScheduledPaymentOption.full,
          title: 'Bayar Lunas',
          subtitle:
              'Lunasi ${CurrencyFormatter.format(totalPayable)} sekarang via kasir.',
        ),
        const SizedBox(height: 6),
        buildOptionTile(
          key: const Key('payment_option_dp'),
          option: _ScheduledPaymentOption.dp,
          title: 'Bayar DP',
          subtitle: 'Bayar DP sekarang, sisa dilunasi saat ambil.',
        ),
        if (_scheduledPaymentOption == _ScheduledPaymentOption.dp) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(10),
            ),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sisa saat ambil: ${CurrencyFormatter.format(remainingAfterDp)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        buildOptionTile(
          key: const Key('toggle_scheduled_pay_later'),
          option: _ScheduledPaymentOption.payLater,
          title: 'Bayar Saat Ambil',
          subtitle: 'Simpan booking tanpa DP, bayar saat ambil.',
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
        child: ElevatedButton.icon(
          onPressed: canAdvanceStep1 ? _onNextToCustomerStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.obsidian.withValues(alpha: 0.35),
            disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
            minimumSize: const Size.fromHeight(46),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: const Text(
            'Lanjut ke Data Penyewa',
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
            child: OutlinedButton.icon(
              onPressed: _onBackStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text(
                'Kembali',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _onNextToSummaryStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text(
                  'Lanjut: Ringkasan Biaya',
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
            width: 112,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: _onBackStep,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 46),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text(
                'Ubah Data',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: (!isUnitSelected || _isNavigatingToPayment || _isSubmittingScheduled)
                    ? null
                    : (_isScheduledBooking && _payLaterScheduled
                        ? _submitScheduledWithoutPayment
                        : _navigateToUnifiedPaymentPage),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.obsidian.withValues(alpha: 0.35),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  minimumSize: const Size.fromHeight(46),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                icon: (_isNavigatingToPayment || _isSubmittingScheduled)
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(
                        _isScheduledBooking
                            ? Icons.event_available_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 18,
                      ),
                label: Text(
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

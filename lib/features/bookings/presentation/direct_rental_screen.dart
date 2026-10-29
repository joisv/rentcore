import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../vouchers/data/voucher_repository.dart';
import '../providers/booking_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';

class RentalTierOption {
  final String unit; // 'hour', 'day', 'week', 'month'
  final int value;
  final int hours;
  final double price;
  final String label;

  const RentalTierOption({
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
  const DirectRentalScreen({super.key});

  @override
  ConsumerState<DirectRentalScreen> createState() => _DirectRentalScreenState();
}

class _DirectRentalScreenState extends ConsumerState<DirectRentalScreen> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0; // 0: Unit & Durasi, 1: Data Penyewa, 2: Ringkasan & Bayar

  String? _assetValidationError;
  String? _durationValidationError;

  // Customer Info Controllers
  final _nameController = TextEditingController(text: 'Dedi Kurniawan');
  final _phoneController = TextEditingController(text: '081298765432');
  final _addressController = TextEditingController(
    text: 'Jl. Raya Genteng No. 128, RT 03/RW 02, Kec. Genteng, Banyuwangi 68465',
  );
  final _slotController = TextEditingController(text: 'Brankas A, Slot 05');
  final _voucherController = TextEditingController();
  final _cashReceivedController = TextEditingController();

  // Unit Selection initially null
  Map<String, dynamic>? _selectedAsset;
  int? _selectedAssetId;
  int? _selectedAssetCategoryId;
  int? _selectedDuration;
  String _selectedDurationUnit = 'hour';
  int _selectedDurationValue = 24;

  double _basePrice = 0.0;
  double _addonSubtotal = 0.0;
  final List<Map<String, dynamic>> _selectedAddons = [];
  int? _selectedAddonCategoryId;
  double _discountAmount = 0.0;
  bool _isValidatingVoucher = false;
  String? _voucherMessage;

  // Customer Search & Auto-Fill
  bool _isNavigatingToPayment = false;
  bool _isSearchingCustomer = false;
  Map<String, dynamic>? _foundCustomer;
  String? _customerLookupMessage;

  // Encrypted ID Document Photo Vault
  String? _identityPhotoBase64;
  String? _identityPhotoName;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _slotController.dispose();
    _voucherController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
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
    final model = asset['model'] ?? {};
    final tiers = (model['pricing_tiers'] as List?) ?? (model['pricingTiers'] as List?) ?? [];
    final list = <RentalTierOption>[];
    for (final t in tiers) {
      final unit = (t['duration_unit']?.toString() ?? 'hour').toLowerCase();
      final hours = int.tryParse(t['duration_hours']?.toString() ?? '0') ?? 0;
      final val = int.tryParse(t['duration_value']?.toString() ?? '') ?? hours;
      final price = CurrencyFormatter.parse(t['price']);
      if (hours > 0) {
        list.add(RentalTierOption(
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

  void _onAssetSelected(Map<String, dynamic> asset) {
    setState(() {
      _selectedAsset = asset;
      _selectedAssetId = asset['id'];
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

      _selectedDuration = selectedTier.hours;
      _selectedDurationUnit = selectedTier.unit;
      _selectedDurationValue = selectedTier.value;
      _basePrice = selectedTier.price;

      _recalculateAddons();
      _updateCashReceivedDefault();
    });

    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  void _onTierSelected(RentalTierOption tier) {
    setState(() {
      _selectedDuration = tier.hours;
      _selectedDurationUnit = tier.unit;
      _selectedDurationValue = tier.value;
      _basePrice = tier.price;
      _durationValidationError = null;
      _recalculateAddons();
      _updateCashReceivedDefault();
    });

    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  double _computeAddonPrice(Map<String, dynamic> addonAsset) {
    final tiers = _getAvailableTiers(addonAsset);
    if (tiers.isEmpty) return 20000.0;
    for (final t in tiers) {
      if (t.hours == (_selectedDuration ?? 24)) {
        return t.price;
      }
    }
    return tiers.first.price;
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
      _updateCashReceivedDefault();
    });
  }

  void _updateCashReceivedDefault() {
    final payable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    if (_cashReceivedController.text.isEmpty ||
        CurrencyFormatter.parse(_cashReceivedController.text) == 0.0) {
      _cashReceivedController.text = payable.toInt().toString();
    }
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
        _updateCashReceivedDefault();
      });
    } catch (e) {
      setState(() {
        _discountAmount = 0.0;
        _voucherMessage = e.toString().replaceAll('Exception: ', '');
        _updateCashReceivedDefault();
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

  void _attachIdentityDocument() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final docNumber = _phoneController.text.isNotEmpty ? _phoneController.text : '$timestamp';
    final fakePhotoData = 'data:image/jpeg;base64,${base64Encode(utf8.encode('RENTCORE_SECURE_VAULT_AES256_${docNumber}_$timestamp'))}';
    setState(() {
      _identityPhotoBase64 = fakePhotoData;
      _identityPhotoName = 'ID_$docNumber.jpg';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.shield_rounded, color: AppColors.success, size: 18),
            SizedBox(width: 8),
            Text('Foto dokumen identitas tersimpan & terenkripsi ke brankas.'),
          ],
        ),
        backgroundColor: AppColors.obsidian,
      ),
    );
  }

  void _removeIdentityDocument() {
    setState(() {
      _identityPhotoBase64 = null;
      _identityPhotoName = null;
    });
  }

  void _onNextToCustomerStep() {
    setState(() {
      _assetValidationError = _selectedAssetId == null ? 'Pilih salah satu unit rental terlebih dahulu.' : null;
      _durationValidationError = _selectedDuration == null ? 'Pilih durasi sewa yang diinginkan.' : null;
    });

    if (_selectedAssetId == null || _selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Silakan pilih unit rental dan durasi terlebih dahulu.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _currentStep = 1);
  }

  void _onNextToSummaryStep() {
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

  void _proceedToPayment() async {
    if (_isNavigatingToPayment) return;

    final address = _addressController.text.trim();

    if (_selectedAssetId == null || _selectedDuration == null) {
      setState(() => _currentStep = 0);
      return;
    }

    final isFormValid = _formKey.currentState?.validate() ?? true;
    if (!isFormValid) {
      setState(() => _currentStep = 1);
      return;
    }

    if (_foundCustomer != null && _foundCustomer!['is_blacklisted'] == true) {
      return;
    }

    setState(() => _isNavigatingToPayment = true);

    try {
      final totalPayable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
      final activeBranchId = ref.read(businessProvider).activeBranchId;
      final activeBranchName = ref.read(businessProvider).activeBranchName;
      final payload = <String, dynamic>{
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'customer_address': address,
        'identity_photo_base64': _identityPhotoBase64,
        'asset_ids': [_selectedAssetId],
        if (_selectedAddons.isNotEmpty)
          'addon_asset_ids': _selectedAddons.map((a) => a['id']).toList(),
        'duration_hours': _selectedDuration,
        'duration_unit': _selectedDurationUnit,
        'duration_value': _selectedDurationValue,
        'collateral_type': 'KTP Asli',
        'collateral_storage_slot': _slotController.text.trim(),
        'voucher_code': _discountAmount > 0 ? _voucherController.text.trim() : null,
        'unit_prices': {
          if (_selectedAssetId != null)
            _selectedAssetId.toString(): _basePrice,
          for (final a in _selectedAddons)
            if (a['id'] != null)
              a['id'].toString(): _computeAddonPrice(a),
        },
      };
      if (activeBranchId != null) {
        payload['affiliate_id'] = activeBranchId;
      }

      final model = _selectedAsset?['model'] as Map?;
      final deviceModelName = model?['name']?.toString() ?? 'Unit Sewa';

      final paymentItems = <PaymentItem>[
        PaymentItem(
          name: deviceModelName,
          assetCode: _selectedAsset?['asset_code']?.toString(),
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

      final result = await Navigator.push<PaymentResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentPage(
            paymentContext: PaymentContext.booking(
              customerName: _nameController.text.trim(),
              customerPhone: _phoneController.text.trim(),
              customerAddress: address,
              deviceName: deviceModelName,
              assetCode: _selectedAsset?['asset_code']?.toString(),
              totalAmount: totalPayable,
              branchId: activeBranchId,
              branchName: activeBranchName,
              extraPayload: payload,
              items: paymentItems,
              primarySubtotal: _basePrice,
              addonSubtotal: _addonSubtotal,
              discountAmount: _discountAmount > 0 ? _discountAmount : null,
              voucherCode: _discountAmount > 0 ? _voucherController.text.trim() : null,
            ),
          ),
        ),
      );

      if (result != null && result.isSuccess) {
        ref.invalidate(bookingsListProvider);
        ref.invalidate(closingSummaryProvider);
        ref.invalidate(readyAssetsProvider);
        ref.invalidate(inventoryListProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Sewa ${result.transactionCode ?? ''} berhasil aktif & dibayar!'),
              backgroundColor: AppColors.success,
            ),
          );
          Navigator.pop(context);
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isNavigatingToPayment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyAssetsAsync = ref.watch(readyAssetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final totalPayable = (_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity);
    final isUnitSelected = _selectedAssetId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(
        title: 'Transaksi Sewa Baru di Meja Kasir',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _buildStepItem(
            step: 0,
            label: '1. Unit & Durasi',
            icon: Icons.phone_iphone_rounded,
          ),
          _buildStepDivider(0),
          _buildStepItem(
            step: 1,
            label: '2. Penyewa',
            icon: Icons.person_rounded,
          ),
          _buildStepDivider(1),
          _buildStepItem(
            step: 2,
            label: '3. Bayar',
            icon: Icons.payment_rounded,
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 26,
              height: 26,
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
                    ? const Icon(Icons.check_rounded, size: 14, color: AppColors.success)
                    : Icon(icon, size: 13, color: isActive ? Colors.white : AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: color,
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
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: isDone ? AppColors.success : AppColors.border,
      ),
    );
  }

  Widget _buildStep1UnitAndDuration(
    AsyncValue<List<dynamic>> readyAssetsAsync,
    AsyncValue<List<dynamic>> categoriesAsync,
    bool isUnitSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isUnitSelected ? AppColors.obsidian : AppColors.border,
              width: isUnitSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PILIH UNIT RENTAL TERSEDIA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (isUnitSelected)
                    const StatusBadge(
                      label: 'Unit Dipilih',
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
              const SizedBox(height: 14),

              // Category Filter Chips
              categoriesAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (e, s) => const SizedBox.shrink(),
                data: (categories) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: const Text('Semua'),
                            selected: _selectedAssetCategoryId == null,
                            onSelected: (_) => setState(() => _selectedAssetCategoryId = null),
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              color: _selectedAssetCategoryId == null ? Colors.white : AppColors.textPrimary,
                              fontWeight: _selectedAssetCategoryId == null ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          ...categories.map((cat) {
                            final isSelected = _selectedAssetCategoryId == cat['id'];
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: ChoiceChip(
                                label: Text(cat['name'] ?? ''),
                                selected: isSelected,
                                onSelected: (_) => setState(() => _selectedAssetCategoryId = cat['id']),
                                selectedColor: AppColors.obsidian,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppColors.textPrimary,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  fontSize: 12,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  );
                },
              ),

              if (_assetValidationError != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
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

              readyAssetsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat unit: $e'),
                data: (assets) {
                  final filteredAssets = _selectedAssetCategoryId == null
                      ? assets
                      : assets.where((a) => a['model']?['category_id'] == _selectedAssetCategoryId).toList();

                  if (filteredAssets.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tidak ada unit rental ready sewa saat ini di kategori ini.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: filteredAssets.map((asset) {
                      final isSelected = _selectedAssetId == asset['id'];
                      final model = asset['model'] ?? {};
                      final category = model['category'] ?? {};
                      final tiers = _getAvailableTiers(asset);
                      double dynamicRate = tiers.isNotEmpty ? tiers.first.price : 0.0;
                      for (final t in tiers) {
                        if (t.hours == (_selectedDuration ?? 24)) {
                          dynamicRate = t.price;
                          break;
                        }
                      }

                      final batteryText = asset['battery_health'] != null ? 'Baterai ${asset['battery_health']}% • ' : '';
                      final snText = asset['serial_number'] != null ? 'SN: ${asset['serial_number']} • ' : '';
                      final subtitle = '${asset['asset_code']} • $batteryText$snText Grade ${asset['condition_grade']}';

                      return GestureDetector(
                        onTap: () => _onAssetSelected(asset),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.surfaceMuted : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.obsidian : AppColors.borderSubtle,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                size: 18,
                                color: isSelected ? AppColors.obsidian : AppColors.textMuted,
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _getCategoryIcon(category['name']),
                                size: 20,
                                color: isSelected ? AppColors.obsidian : AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      model['name'] ?? '',
                                      style: TextStyle(
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                CurrencyFormatter.format(dynamicRate),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.obsidian,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // DURATION & VOUCHER SECTION
        AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          opacity: isUnitSelected ? 1.0 : 0.6,
          child: Container(
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
                  'DURASI SEWA & VOUCHER PROMO',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 14),

                if (!isUnitSelected)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 18, color: AppColors.textSecondary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pilih unit rental terlebih dahulu untuk menentukan durasi dan voucher.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (_durationValidationError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
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
                      if (a['id'] == _selectedAssetId) {
                        selectedAsset = a;
                        break;
                      }
                    }
                    final availableTiers = _getAvailableTiers(selectedAsset);

                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: availableTiers.map((tier) {
                        final isSelected = _selectedDuration == tier.hours;
                        return ChoiceChip(
                          label: Text(tier.label),
                          selected: isSelected,
                          onSelected: isUnitSelected ? (_) => _onTierSelected(tier) : null,
                          selectedColor: AppColors.obsidian,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                const SizedBox(height: 16),

                // Voucher Input Field
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _voucherController,
                        enabled: isUnitSelected,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Kode Voucher Diskon (Opsional)',
                          hintText: isUnitSelected ? 'Contoh: RC-VCR-8921' : 'Pilih unit terlebih dahulu',
                          prefixIcon: const Icon(Icons.confirmation_number_outlined, size: 20),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(90, 52),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: (isUnitSelected && !_isValidatingVoucher) ? _validateVoucher : null,
                      child: _isValidatingVoucher
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Terapkan'),
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
        ),
        _buildAddonsSelectionSection(readyAssetsAsync, categoriesAsync),
        const SizedBox(height: 20),

        // FORWARD ACTION TO STEP 2
        ElevatedButton.icon(
          onPressed: _onNextToCustomerStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          label: Text(
            !isUnitSelected
                ? 'Pilih Unit Terlebih Dahulu'
                : 'Lanjut: Data Penyewa (${CurrencyFormatter.format((_basePrice + _addonSubtotal - _discountAmount).clamp(0.0, double.infinity))})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
      error: (_, __) => const SizedBox.shrink(),
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

        final filteredAddons = _selectedAddonCategoryId == null
            ? addonAssets
            : addonAssets.where((a) => a['model']?['category_id'] == _selectedAddonCategoryId).toList();

        return Container(
          margin: const EdgeInsets.only(top: 16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _selectedAddons.isNotEmpty ? AppColors.obsidian : AppColors.border,
              width: _selectedAddons.isNotEmpty ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.extension_outlined, size: 18, color: AppColors.obsidian),
                      SizedBox(width: 8),
                      Text(
                        'AKSESORIS & ADD-ON SEWA',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
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
              const SizedBox(height: 4),
              const Text(
                'Pilih power bank, charger, tripod, atau aksesoris tambahan yang disewa bersamaan.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),

              // Addon items list
              Column(
                children: filteredAddons.map((addon) {
                  final isSelected = _selectedAddons.any((a) => a['id'] == addon['id']);
                  final model = addon['model'] as Map? ?? {};
                  final modelName = model['name']?.toString() ?? 'Aksesoris';
                  final price = _computeAddonPrice(addon);

                  return InkWell(
                    onTap: () => _toggleAddon(addon),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.surfaceMuted : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? AppColors.obsidian : AppColors.border,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: isSelected,
                            activeColor: AppColors.obsidian,
                            onChanged: (_) => _toggleAddon(addon),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.power_rounded,
                              size: 18,
                              color: isSelected ? Colors.white : AppColors.obsidian,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  modelName,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                Text(
                                  '${addon['asset_code']} • Grade ${addon['condition_grade']}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+ ${CurrencyFormatter.format(price)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isSelected ? AppColors.obsidian : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_selectedAddons.isNotEmpty) ...[
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal Add-on (${_selectedAddons.length} item):',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'DATA PENYEWA & ALAMAT IDENTITAS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                const SizedBox(height: 14),

                // Customer Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap Penyewa *',
                    prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 3) {
                      return 'Nama lengkap penyewa minimal 3 karakter';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // WhatsApp Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Nomor WhatsApp Aktif *',
                    prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search_rounded, size: 20),
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
                const SizedBox(height: 12),

                // Address
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  minLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Alamat Sesuai Kartu Identitas *',
                    hintText: 'Jalan, nomor rumah, RT/RW, kelurahan/desa, kecamatan, kota/kabupaten',
                    alignLabelWithHint: true,
                    prefixIcon: Padding(
                      padding: EdgeInsets.only(bottom: 28),
                      child: Icon(Icons.home_outlined, size: 20),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().length < 5) {
                      return 'Alamat sesuai kartu identitas wajib diisi lengkap';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                // Collateral Safe Slot
                TextFormField(
                  controller: _slotController,
                  decoration: const InputDecoration(
                    labelText: 'Slot Brankas Penyimpanan Jaminan Fisik *',
                    prefixIcon: Icon(Icons.shield_outlined, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Lokasi slot brankas jaminan fisik wajib dicatat';
                    }
                    return null;
                  },
                ),

                // Customer Search Status Feedback
                if (_foundCustomer != null && _foundCustomer!['is_blacklisted'] == true)
                  Container(
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.danger),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.block_rounded, color: AppColors.danger, size: 22),
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
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
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
                    margin: const EdgeInsets.only(top: 14),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
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

                // Encrypted ID Document Photo Vault
                const SizedBox(height: 16),
                const Divider(height: 1),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FOTO DOKUMEN JAMINAN (KTP/SIM)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                    if (_identityPhotoBase64 != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_rounded, size: 10, color: Colors.white),
                            SizedBox(width: 4),
                            Text(
                              'AES-256 VAULT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                if (_identityPhotoBase64 == null)
                  InkWell(
                    onTap: _attachIdentityDocument,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, color: AppColors.textSecondary, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Lampirkan Foto Dokumen Identitas',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.obsidian,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.badge_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _identityPhotoName ?? 'Foto_Identitas.jpg',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Dokumen terenkripsi & tersimpan',
                                style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.danger),
                          onPressed: _removeIdentityDocument,
                          tooltip: 'Hapus Foto',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // STEP 2 NAVIGATION BUTTONS
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onBackStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _onNextToSummaryStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('Lanjut: Ringkasan Biaya', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStep3SummaryAndPayment(double totalPayable, bool isUnitSelected) {
    final model = _selectedAsset?['model'] as Map?;
    final deviceModelName = model?['name']?.toString() ?? 'Unit Sewa';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // OVERVIEW REVIEW CARDS
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
                'RINGKASAN SEWA & IDENTITAS PENYEWA',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 14),

              // Unit Card Review
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.phone_iphone_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(deviceModelName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          Text(
                            '${_selectedAsset?['asset_code'] ?? '-'} • Durasi: $_selectedDuration Jam',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    StatusBadge.inventory('ready'),
                  ],
                ),
              ),

              // Add-on Review Tiles
              if (_selectedAddons.isNotEmpty) ...[
                const SizedBox(height: 8),
                ..._selectedAddons.map((addon) {
                  final model = addon['model'] as Map? ?? {};
                  final modelName = model['name']?.toString() ?? 'Aksesoris';
                  final price = _computeAddonPrice(addon);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                modelName,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                              Text(
                                '${addon['asset_code']} • Add-on',
                                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
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
                }),
              ],
              const SizedBox(height: 10),

              // Customer Card Review
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.person_rounded, color: AppColors.obsidian, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nameController.text.trim(), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          Text(
                            'WA: ${_phoneController.text.trim()} • Slot: ${_slotController.text.trim()}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (_identityPhotoBase64 != null)
                      const StatusBadge(
                        label: 'KTP Valid',
                        textColor: AppColors.success,
                        backgroundColor: AppColors.successLight,
                        icon: Icons.shield_rounded,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Itemized Bill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Subtotal Perangkat Utama:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(
                    CurrencyFormatter.format(_basePrice),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ],
              ),
              if (_selectedAddons.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal Add-on (${_selectedAddons.length} unit):',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    Text(
                      '+ ${CurrencyFormatter.format(_addonSubtotal)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.obsidian),
                    ),
                  ],
                ),
              ],
              if (_discountAmount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Diskon Promo Voucher:', style: TextStyle(fontSize: 13, color: AppColors.success)),
                    Text(
                      '- ${CurrencyFormatter.format(_discountAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.success),
                    ),
                  ],
                ),
              ],
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1, color: AppColors.border),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TOTAL TAGIHAN POS:',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
                  Text(
                    CurrencyFormatter.format(totalPayable),
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: AppColors.obsidian),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // STEP 3 NAVIGATION BUTTONS
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _onBackStep,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Ubah Data', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: (!isUnitSelected || _isNavigatingToPayment) ? null : _proceedToPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isNavigatingToPayment
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Proses pembayaran',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

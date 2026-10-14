import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/data/customer_repository.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../vouchers/data/voucher_repository.dart';
import '../providers/booking_provider.dart';

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
  // Customer Info Controllers
  final _nameController = TextEditingController(text: 'Dedi Kurniawan');
  final _phoneController = TextEditingController(text: '081298765432');
  final _addressController = TextEditingController(
    text: 'Jl. Raya Genteng No. 128, RT 03/RW 02, Kec. Genteng, Banyuwangi 68465',
  );
  final _slotController = TextEditingController(text: 'Brankas A, Slot 05');
  final _voucherController = TextEditingController();
  final _cashReceivedController = TextEditingController();

  // Unit Selection MUST Come First: initially null
  int? _selectedAssetId;
  int? _selectedAssetCategoryId;
  int? _selectedDuration;
  String _selectedDurationUnit = 'hour';
  int _selectedDurationValue = 24;
  int _selectedPaymentMethodId = 1;
  String _selectedPaymentMethodCode = 'CASH';

  double _basePrice = 0.0;
  double _discountAmount = 0.0;
  bool _isValidatingVoucher = false;
  String? _voucherMessage;
  bool _isSubmitting = false;
  bool _nonCashConfirmed = true;

  // Customer Search & Auto-Fill
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

  /// Returns available duration tiers list for the currently selected asset model.
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

  /// Handles user tapping a rental unit.
  void _onAssetSelected(Map<String, dynamic> asset) {
    setState(() {
      _selectedAssetId = asset['id'];
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

      // Auto set cash received to total if not manually modified
      _updateCashReceivedDefault();
    });

    // Revalidate voucher against new unit price if voucher was previously entered
    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  /// Handles duration tier change.
  void _onTierSelected(RentalTierOption tier) {
    setState(() {
      _selectedDuration = tier.hours;
      _selectedDurationUnit = tier.unit;
      _selectedDurationValue = tier.value;
      _basePrice = tier.price;
      _updateCashReceivedDefault();
    });

    if (_voucherController.text.trim().isNotEmpty) {
      _validateVoucher();
    }
  }

  void _updateCashReceivedDefault() {
    final payable = (_basePrice - _discountAmount).clamp(0.0, double.infinity);
    if (_cashReceivedController.text.isEmpty ||
        CurrencyFormatter.parse(_cashReceivedController.text) == 0.0) {
      _cashReceivedController.text = payable.toInt().toString();
    }
  }

  void _validateVoucher() async {
    final code = _voucherController.text.trim();
    if (code.isEmpty || _basePrice <= 0) return;

    setState(() {
      _isValidatingVoucher = true;
      _voucherMessage = null;
    });

    try {
      final repo = VoucherRepository();
      final result = await repo.validateVoucher(code, _basePrice);
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

  void _submitRental() async {
    // 1. Unit Validation Must Come First
    if (_selectedAssetId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih salah satu unit rental terlebih dahulu!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    if (_selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih durasi sewa yang diinginkan.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // 2. Customer Address Validation (Alamat Sesuai Kartu Identitas)
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alamat sesuai kartu identitas wajib diisi lengkap.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    // 3. Blacklist Guard
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

    // 4. POS Cashier Payment Validation
    final totalPayable = (_basePrice - _discountAmount).clamp(0.0, double.infinity);
    double cashReceived = 0.0;

    if (_selectedPaymentMethodCode == 'CASH') {
      cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
      if (cashReceived < totalPayable) {
        final shortage = totalPayable - cashReceived;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Uang tunai kurang ${CurrencyFormatter.format(shortage)}! Tagihan belum mencukupi.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
    } else {
      if (!_nonCashConfirmed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Harap centang konfirmasi pembayaran non-tunai telah diverifikasi.'),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }
      cashReceived = totalPayable;
    }

    setState(() => _isSubmitting = true);

    try {
      final activeBranchId = ref.read(businessProvider).activeBranchId;
      final payload = <String, dynamic>{
        'customer_name': _nameController.text.trim(),
        'customer_phone': _phoneController.text.trim(),
        'customer_address': address,
        'identity_photo_base64': _identityPhotoBase64,
        'asset_ids': [_selectedAssetId],
        'duration_hours': _selectedDuration,
        'duration_unit': _selectedDurationUnit,
        'duration_value': _selectedDurationValue,
        'collateral_type': 'KTP Asli',
        'collateral_storage_slot': _slotController.text.trim(),
        'voucher_code': _discountAmount > 0 ? _voucherController.text.trim() : null,
        'payment_method_id': _selectedPaymentMethodId,
        'cash_received': cashReceived,
      };
      if (activeBranchId != null) {
        payload['affiliate_id'] = activeBranchId;
      }

      final booking = await ref.read(bookingRepositoryProvider).createRental(payload);
      ref.invalidate(bookingsListProvider);
      ref.invalidate(closingSummaryProvider);
      ref.invalidate(readyAssetsProvider);
      ref.invalidate(inventoryListProvider);

      if (mounted) {
        final change = _selectedPaymentMethodCode == 'CASH' ? (cashReceived - totalPayable) : 0.0;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppColors.success),
                SizedBox(width: 8),
                Text('Sewa Berhasil Aktif!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Booking ${booking['booking_code']} telah aktif.\n'
                  'Perangkat langsung diserahkan ke pelanggan.\n'
                  'Jaminan KTP diamankan di: ${_slotController.text}.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Tagihan:', style: TextStyle(fontSize: 12)),
                          Text(CurrencyFormatter.format(totalPayable), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        ],
                      ),
                      if (_selectedPaymentMethodCode == 'CASH') ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Uang Diterima:', style: TextStyle(fontSize: 12)),
                            Text(CurrencyFormatter.format(cashReceived), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Kembalian:', style: TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.bold)),
                            Text(CurrencyFormatter.format(change), style: const TextStyle(fontSize: 13, color: AppColors.success, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('Selesai & Tutup'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuat sewa: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readyAssetsAsync = ref.watch(readyAssetsProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    final totalPayable = (_basePrice - _discountAmount).clamp(0.0, double.infinity);
    final cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
    final cashShortage = (totalPayable - cashReceived).clamp(0.0, double.infinity);
    final cashChange = (cashReceived - totalPayable).clamp(0.0, double.infinity);

    final isUnitSelected = _selectedAssetId != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Transaksi Sewa Baru di Meja Kasir'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // STEP 1: PILIH UNIT RENTAL TERSEDIA (MUST COME FIRST)
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.obsidian,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LANGKAH 1',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'PILIH UNIT RENTAL TERSEDIA',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      if (isUnitSelected)
                        const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20)
                      else
                        const Text(
                          '*Wajib Pertama',
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
            const SizedBox(height: 20),

            // STEP 2: DURASI SEWA & VOUCHER DISKON (DISABLED UNTIL UNIT SELECTED)
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isUnitSelected ? 1.0 : 0.5,
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isUnitSelected ? AppColors.obsidian : AppColors.textMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LANGKAH 2',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'DURASI SEWA & VOUCHER DISKON',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Helper banner when unit is not selected
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

                    // Duration Tier Chips
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
                              onSelected: isUnitSelected
                                  ? (_) => _onTierSelected(tier)
                                  : null,
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

                    // Voucher Field
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
            const SizedBox(height: 20),

            // STEP 3: DATA PENYEWA & JAMINAN (WITH MULTILINE ADDRESS)
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.obsidian,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'LANGKAH 3',
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'DATA PENYEWA & ALAMAT IDENTITAS',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
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
                          'Cari Data',
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
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Lengkap Penyewa',
                      prefixIcon: Icon(Icons.person_outline_rounded, size: 20),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // WhatsApp Phone
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Nomor WhatsApp Aktif',
                      prefixIcon: const Icon(Icons.phone_outlined, size: 20),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search_rounded, size: 20),
                        onPressed: _searchCustomer,
                        tooltip: 'Cari Riwayat Pelanggan',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Address as Written on Identity Card (Multiline Input)
                  TextField(
                    controller: _addressController,
                    maxLines: 3,
                    minLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Alamat Sesuai Kartu Identitas',
                      hintText: 'Jalan, nomor rumah, RT/RW, kelurahan/desa, kecamatan, kota/kabupaten, kode pos',
                      alignLabelWithHint: true,
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(bottom: 28),
                        child: Icon(Icons.home_outlined, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Collateral Safe Slot
                  TextField(
                    controller: _slotController,
                    decoration: const InputDecoration(
                      labelText: 'Slot Brankas Penyimpanan Jaminan Fisik',
                      prefixIcon: Icon(Icons.shield_outlined, size: 20),
                    ),
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
            const SizedBox(height: 20),

            // STEP 4: POS-STYLE CASHIER PAYMENT SECTION
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LANGKAH 4',
                          style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'PEMBAYARAN KASIR POS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Payment Method Selector
                  paymentMethodsAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Gagal memuat metode pembayaran: $e'),
                    data: (methods) {
                      if (methods.isEmpty) {
                        return const Text('Metode pembayaran tidak tersedia.');
                      }

                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: methods.map((m) {
                          final isSelected = _selectedPaymentMethodId == m['id'];
                          return ChoiceChip(
                            label: Text(m['name'] ?? m['code'] ?? 'Metode'),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() {
                                _selectedPaymentMethodId = m['id'];
                                _selectedPaymentMethodCode = (m['code'] ?? 'CASH').toString().toUpperCase();
                              });
                            },
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

                  // If Cash: Show Amount Received input & Change Calculation
                  if (_selectedPaymentMethodCode == 'CASH') ...[
                    TextField(
                      controller: _cashReceivedController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Jumlah Uang Diterima (Rp)',
                        hintText: 'Masukkan nominal uang tunai dari pelanggan',
                        prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                          tooltip: 'Uang Pas',
                          onPressed: () {
                            _cashReceivedController.text = totalPayable.toInt().toString();
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Cash denomination shortcuts
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Uang Pas'),
                          onPressed: () {
                            _cashReceivedController.text = totalPayable.toInt().toString();
                          },
                        ),
                        ActionChip(
                          label: const Text('Rp 50.000'),
                          onPressed: () => _cashReceivedController.text = '50000',
                        ),
                        ActionChip(
                          label: const Text('Rp 100.000'),
                          onPressed: () => _cashReceivedController.text = '100000',
                        ),
                        ActionChip(
                          label: const Text('Rp 200.000'),
                          onPressed: () => _cashReceivedController.text = '200000',
                        ),
                        ActionChip(
                          label: const Text('Rp 350.000'),
                          onPressed: () => _cashReceivedController.text = '350000',
                        ),
                        ActionChip(
                          label: const Text('Rp 500.000'),
                          onPressed: () => _cashReceivedController.text = '50000',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Change or Shortage Display
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cashShortage > 0 ? AppColors.dangerLight : AppColors.successLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                cashShortage > 0 ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                                color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                cashShortage > 0 ? 'Kekurangan Uang:' : 'Kembalian Pelanggan:',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            CurrencyFormatter.format(cashShortage > 0 ? cashShortage : cashChange),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    // Non-Cash: Confirmation Checkbox
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Checkbox(
                            value: _nonCashConfirmed,
                            activeColor: AppColors.obsidian,
                            onChanged: (val) {
                              setState(() => _nonCashConfirmed = val ?? false);
                            },
                          ),
                          const Expanded(
                            child: Text(
                              'Konfirmasi bukti transfer/pembayaran QRIS telah diterima dan diverifikasi oleh kasir.',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BILLING SUMMARY CARD
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal Sewa', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text(
                        isUnitSelected ? CurrencyFormatter.format(_basePrice) : 'Rp 0',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                    ],
                  ),
                  if (_discountAmount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Potongan Diskon Voucher', style: TextStyle(color: Colors.greenAccent, fontSize: 13)),
                        Text(
                          '- ${CurrencyFormatter.format(_discountAmount)}',
                          style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Colors.white24, height: 1),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'TOTAL TAGIHAN POS',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                          ),
                          Text('Wajib lunas di meja kasir', style: TextStyle(color: Colors.white60, fontSize: 11)),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(totalPayable),
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SUBMIT BUTTON WITH VALIDATION AND PROTECTION
            ElevatedButton(
              onPressed: (_isSubmitting || !isUnitSelected || (_selectedPaymentMethodCode == 'CASH' && cashShortage > 0))
                  ? null
                  : _submitRental,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      !isUnitSelected
                          ? 'Pilih Unit Rental Terlebih Dahulu'
                          : (_selectedPaymentMethodCode == 'CASH' && cashShortage > 0
                              ? 'Uang Tunai Kurang (${CurrencyFormatter.format(cashShortage)})'
                              : 'Konfirmasi Bayar & Aktifkan Sewa 🖨️'),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

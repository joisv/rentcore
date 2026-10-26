import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/asset_provider.dart';

class AddProductSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final Map<String, dynamic>? initialProduct;

  const AddProductSheet({
    super.key,
    required this.onSuccess,
    this.initialProduct,
  });

  @override
  ConsumerState<AddProductSheet> createState() => _AddProductSheetState();
}

class _RateItem {
  String unit;
  final TextEditingController valueController;
  final TextEditingController priceController;
  final TextEditingController extensionRateController;

  _RateItem({
    this.unit = 'day',
    String value = '1',
    String price = '',
    String extensionRate = '20000',
  })  : valueController = TextEditingController(text: value),
        priceController = TextEditingController(text: price),
        extensionRateController = TextEditingController(text: extensionRate);

  void dispose() {
    valueController.dispose();
    priceController.dispose();
    extensionRateController.dispose();
  }
}

class _AddProductSheetState extends ConsumerState<AddProductSheet> {
  final _formKey = GlobalKey<FormState>();

  bool get _isEditing => widget.initialProduct != null;

  int? _selectedCategoryId;
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _storageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessoriesController = TextEditingController();
  bool _requiresFrpCheck = false;
  bool _isAddon = false;
  bool _isLoading = false;

  final List<_RateItem> _rates = [];

  @override
  void initState() {
    super.initState();
    final p = widget.initialProduct;
    if (p != null) {
      _selectedCategoryId = p['category_id'] as int? ?? p['category']?['id'] as int?;
      _brandController.text = p['brand']?.toString() ?? '';
      _nameController.text = p['name']?.toString() ?? '';
      _colorController.text = p['color']?.toString() ?? '';
      _storageController.text = p['storage_capacity']?.toString() ?? '';
      _descriptionController.text = p['description']?.toString() ?? '';
      _requiresFrpCheck = p['requires_frp_check'] == true;
      _isAddon = p['is_addon'] == true || p['is_addon'] == 1;

      final acc = p['standard_accessories'];
      if (acc is List) {
        _accessoriesController.text = acc.join(', ');
      } else if (acc != null) {
        _accessoriesController.text = acc.toString();
      }

      final tiers = p['pricing_tiers'] as List?;
      if (tiers != null && tiers.isNotEmpty) {
        for (final t in tiers) {
          if (t is Map<String, dynamic>) {
            final pr = t['price'];
            final ext = t['extension_hourly_rate'];
            _rates.add(_RateItem(
              unit: t['duration_unit']?.toString() ?? 'day',
              value: (t['duration_value'] ?? 1).toString(),
              price: pr != null ? (pr is num ? pr.toInt().toString() : pr.toString()) : '',
              extensionRate: ext != null ? (ext is num ? ext.toInt().toString() : ext.toString()) : '20000',
            ));
          }
        }
      }
    }

    if (_rates.isEmpty) {
      // Default initial rate: 1 Hari
      _rates.add(_RateItem(unit: 'day', value: '1', price: '', extensionRate: '20000'));
    }
  }

  @override
  void dispose() {
    _brandController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _storageController.dispose();
    _descriptionController.dispose();
    _accessoriesController.dispose();
    for (final r in _rates) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRateRow() {
    setState(() {
      final nextValue = _rates.isEmpty ? '1' : (_rates.length == 1 ? '3' : (_rates.length == 2 ? '7' : '1'));
      final nextUnit = _rates.length >= 2 ? 'week' : 'day';
      _rates.add(_RateItem(unit: nextUnit, value: nextValue, price: '', extensionRate: '20000'));
    });
  }

  void _addPresetRate(String unit, int value) {
    final exists = _rates.any((r) => r.unit == unit && r.valueController.text.trim() == value.toString());
    if (exists) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paket $value ${_formatUnitName(unit)} sudah ada di daftar!'),
          duration: const Duration(seconds: 1),
          backgroundColor: AppColors.obsidian,
        ),
      );
      return;
    }
    setState(() {
      _rates.add(_RateItem(
        unit: unit,
        value: value.toString(),
        price: '',
        extensionRate: '20000',
      ));
    });
  }

  String _formatUnitName(String unit) {
    switch (unit) {
      case 'hour':
        return 'Jam';
      case 'day':
        return 'Hari';
      case 'week':
        return 'Minggu';
      case 'month':
        return 'Bulan';
      default:
        return unit;
    }
  }

  Widget _buildPresetChip(String label, String unit, int value) {
    final isAlreadyAdded = _rates.any((r) => r.unit == unit && r.valueController.text.trim() == value.toString());
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ActionChip(
        label: Text(
          isAlreadyAdded ? '$label (Ada)' : label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAlreadyAdded ? const Color(0xFF047857) : const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: isAlreadyAdded ? const Color(0xFFECFDF5) : Colors.white,
        side: BorderSide(
          color: isAlreadyAdded ? const Color(0xFFA7F3D0) : const Color(0xFFCBD5E1),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onPressed: isAlreadyAdded ? null : () => _addPresetRate(unit, value),
      ),
    );
  }

  void _removeRateRow(int index) {
    if (_rates.length > 1) {
      setState(() {
        _rates[index].dispose();
        _rates.removeAt(index);
      });
    }
  }

  void _showQuickAddCategoryDialog() {
    final catNameController = TextEditingController();
    bool isSubmitting = false;
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: catNameController,
                  autofocus: true,
                  enabled: !isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'Misal: Drone & Gimbal / Audio',
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                if (localError != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            localError!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(88, 40),
                ),
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final name = catNameController.text.trim();
                        if (name.isEmpty) {
                          setDialogState(() => localError = 'Nama kategori wajib diisi.');
                          return;
                        }

                        setDialogState(() {
                          isSubmitting = true;
                          localError = null;
                        });

                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final repo = ref.read(assetRepositoryProvider);
                          final res = await repo.createCategory({'name': name});
                          final newId = int.tryParse(res['id']?.toString() ?? '');

                          final _ = await ref.refresh(categoriesProvider.future);

                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }

                          if (mounted && newId != null) {
                            setState(() {
                              _selectedCategoryId = newId;
                            });
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Kategori "$name" berhasil ditambahkan!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          String errorMsg = 'Gagal membuat kategori.';
                          if (e.toString().contains('403') || e.toString().contains('FORBIDDEN')) {
                            errorMsg = 'Hanya Owner bisnis atau Admin yang berwenang membuat kategori.';
                          } else if (e.toString().contains('422')) {
                            errorMsg = 'Nama kategori "$name" sudah digunakan.';
                          } else {
                            errorMsg = 'Gagal membuat kategori: $e';
                          }

                          if (ctx.mounted) {
                            setDialogState(() {
                              isSubmitting = false;
                              localError = errorMsg;
                            });
                          }
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Simpan'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih kategori produk terlebih dahulu!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // Validate rate cards
    final formattedRates = <Map<String, dynamic>>[];
    for (int i = 0; i < _rates.length; i++) {
      final r = _rates[i];
      final val = int.tryParse(r.valueController.text.trim());
      final price = CurrencyFormatter.parse(r.priceController.text.trim());
      final ext = CurrencyFormatter.parse(r.extensionRateController.text.trim());

      if (val == null || val <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Durasi pada paket #${i + 1} tidak valid!'), backgroundColor: AppColors.danger),
        );
        return;
      }
      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Harga sewa pada paket #${i + 1} wajib diisi!'), backgroundColor: AppColors.danger),
        );
        return;
      }

      formattedRates.add({
        'duration_unit': r.unit,
        'duration_value': val,
        'price': price,
        'extension_hourly_rate': ext > 0 ? ext : 20000.0,
      });
    }

    if (formattedRates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambahkan minimal 1 paket tarif sewa!'), backgroundColor: AppColors.danger),
      );
      return;
    }

    // Split accessories
    final accessories = _accessoriesController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    setState(() => _isLoading = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final repo = ref.read(assetRepositoryProvider);
      final payload = <String, dynamic>{
        'category_id': _selectedCategoryId,
        'brand': _brandController.text.trim(),
        'name': _nameController.text.trim(),
        if (_descriptionController.text.trim().isNotEmpty)
          'description': _descriptionController.text.trim(),
        if (_colorController.text.trim().isNotEmpty)
          'color': _colorController.text.trim(),
        if (_storageController.text.trim().isNotEmpty)
          'storage_capacity': _storageController.text.trim(),
        if (accessories.isNotEmpty)
          'standard_accessories': accessories,
        'requires_frp_check': _requiresFrpCheck,
        'is_addon': _isAddon,
        'rates': formattedRates,
      };

      if (_isEditing) {
        await repo.updateProduct(widget.initialProduct!['id'] as int, payload);
      } else {
        await repo.createProduct(payload);
      }

      // Refresh catalog providers
      ref.invalidate(categoriesProvider);
      ref.invalidate(allCatalogModelsProvider);
      ref.invalidate(catalogModelsProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(inventoryListProvider);

      widget.onSuccess();
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(_isEditing ? 'Katalog berhasil diperbarui!' : 'Produk baru berhasil didaftarkan!')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal ${_isEditing ? "memperbarui" : "mendaftarkan"} produk: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  InputDecoration _inputDecoration({
    String? hintText,
    Widget? prefixIcon,
    BoxConstraints? prefixIconConstraints,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIcon: prefixIcon,
      prefixIconConstraints: prefixIconConstraints,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF43F5E)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFF43F5E), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Drag Handle & Sticky Header
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 12, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // iOS Drag handle bar
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Edit Model & Tarif Sewa' : 'Tambah Model & Tarif Sewa',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 18,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _isEditing
                                  ? 'Perbarui informasi katalog & konfigurasi paket harga'
                                  : 'Katalog produk baru & konfigurasi paket harga sewa',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        style: IconButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          foregroundColor: const Color(0xFF94A3B8),
                        ),
                        icon: const Icon(Icons.close_rounded, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Scrollable Form Body
            Expanded(
              child: Container(
                color: const Color(0xFFF8FAFC),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // SECTION 1: IDENTITAS UNIT
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '1. IDENTITAS UNIT',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '* Wajib diisi',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF43F5E),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Kategori Perangkat
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Kategori Perangkat *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          InkWell(
                            onTap: _showQuickAddCategoryDialog,
                            borderRadius: BorderRadius.circular(6),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_rounded, size: 15, color: Color(0xFF2563EB)),
                                  SizedBox(width: 3),
                                  Text(
                                    'Kategori Baru',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2563EB),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      categoriesAsync.when(
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('Gagal memuat kategori: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                        data: (cats) {
                          return DropdownButtonFormField<int>(
                            // ignore: deprecated_member_use
                            value: cats.any((c) => c['id'] == _selectedCategoryId) ? _selectedCategoryId : null,
                            isExpanded: true,
                            decoration: _inputDecoration(),
                            hint: const Text(
                              'Pilih Kategori (Kamera, Laptop, Lensa, Drone...)',
                              style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                            ),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                            items: cats.map((c) {
                              return DropdownMenuItem<int>(
                                value: c['id'] as int,
                                child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                              );
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedCategoryId = val;
                                if (val != null) {
                                  final selected = cats.firstWhere((x) => x['id'] == val, orElse: () => {});
                                  final slug = (selected['slug'] ?? '').toString().toLowerCase();
                                  _requiresFrpCheck = slug.contains('phone') || slug.contains('tablet');
                                }
                              });
                            },
                            validator: (v) => v == null ? 'Kategori wajib dipilih' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),

                      // Merk / Brand
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Merk / Brand *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _brandController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            decoration: _inputDecoration(hintText: 'Misal: Sony, Apple, DJI'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Nama Model
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Nama Model *',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                            decoration: _inputDecoration(hintText: 'Misal: Alpha A7 IV Body'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama model wajib' : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Warna & Kapasitas / RAM (2 Columns Optional)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Warna (Opsional)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _colorController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  decoration: _inputDecoration(hintText: 'Hitam / Silver'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Kapasitas / RAM (Opsional)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _storageController,
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                                  decoration: _inputDecoration(hintText: '512GB / 16GB RAM'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Deskripsi Singkat & Spesifikasi
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Deskripsi Singkat & Spesifikasi',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _descriptionController,
                            maxLines: 2,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            decoration: _inputDecoration(
                              hintText: 'Spesifikasi ringkas, sensor, resolusi, port input/output...',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Kelengkapan Standar Bawaan
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kelengkapan Standar Bawaan',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Pisahkan dengan koma: 2x Baterai, Dual Charger, Tas Kamera, SD Card 128GB',
                            style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _accessoriesController,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B)),
                            decoration: _inputDecoration(
                              hintText: 'Charger, Kabel HDMI, Tas, Baterai Cadangan...',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // SECTION 2: PROTEKSI & TIPE UNIT
                      const Text(
                        '2. PROTEKSI & TIPE UNIT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Toggle 1: Wajib Cek Akun (iCloud / FRP)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Wajib Cek Akun (iCloud / FRP)',
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFFEF3C7),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Penting',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  const Text(
                                    'Wajibkan kasir verifikasi pelepasan akun iCloud/Google saat unit dikembalikan.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _requiresFrpCheck,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF0F172A),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              onChanged: (val) => setState(() => _requiresFrpCheck = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Toggle 2: Tandai sebagai Aksesoris Tambahan
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: const [
                            BoxShadow(color: Color(0x06000000), blurRadius: 4, offset: Offset(0, 1)),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Tandai sebagai Aksesoris Tambahan',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                  ),
                                  SizedBox(height: 3),
                                  Text(
                                    'Power bank, tripod, charger, dll. yang dapat disewa berdampingan dengan unit utama.',
                                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Switch(
                              value: _isAddon,
                              activeThumbColor: Colors.white,
                              activeTrackColor: const Color(0xFF0F172A),
                              inactiveThumbColor: Colors.white,
                              inactiveTrackColor: const Color(0xFFE2E8F0),
                              onChanged: (val) => setState(() => _isAddon = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // SECTION 3: PAKET TARIF SEWA *
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.sell_outlined, size: 14, color: Colors.white),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Paket Tarif Sewa *',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Tentukan harga sewa per jam, hari, minggu, atau bulan. Minimal 1 paket wajib aktif.',
                                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Rate cards
                      ..._rates.asMap().entries.map((entry) {
                        final idx = entry.key;
                        final rate = entry.value;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                            boxShadow: const [
                              BoxShadow(color: Color(0x08000000), blurRadius: 4, offset: Offset(0, 1)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Card Header Badge & Delete Action
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0F172A),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.sell_outlined, size: 12, color: Colors.white),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Paket #${idx + 1}: ${rate.valueController.text.isEmpty ? "1" : rate.valueController.text} ${_formatUnitName(rate.unit)}',
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (idx == 0) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: const Color(0xFFA7F3D0)),
                                          ),
                                          child: const Text(
                                            'Paket Utama',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF047857),
                                            ),
                                          ),
                                        ),
                                        if (_rates.length > 1) const SizedBox(width: 8),
                                      ],
                                      if (_rates.length > 1)
                                        InkWell(
                                          onTap: () => _removeRateRow(idx),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.delete_outline_rounded, size: 15, color: Color(0xFFF43F5E)),
                                                SizedBox(width: 4),
                                                Text(
                                                  'Hapus Paket',
                                                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFF43F5E)),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Duration Value & Duration Unit (2 Columns)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Durasi *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        TextField(
                                          controller: rate.valueController,
                                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            hintText: '1',
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                            ),
                                          ),
                                          onChanged: (_) => setState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Satuan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                                        const SizedBox(height: 6),
                                        DropdownButtonFormField<String>(
                                          // ignore: deprecated_member_use
                                          value: rate.unit,
                                          isExpanded: true,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.white,
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF0F172A), width: 2),
                                            ),
                                          ),
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF0F172A)),
                                          items: const [
                                            DropdownMenuItem(value: 'day', child: Text('Hari (day)')),
                                            DropdownMenuItem(value: 'hour', child: Text('Jam (hour)')),
                                            DropdownMenuItem(value: 'week', child: Text('Minggu (week)')),
                                            DropdownMenuItem(value: 'month', child: Text('Bulan (month)')),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) setState(() => rate.unit = val);
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Price
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Harga Sewa Paket *',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: rate.priceController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                                    decoration: InputDecoration(
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(left: 14, right: 8),
                                        child: Text('Rp', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF64748B), fontSize: 14)),
                                      ),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      hintText: 'Misal: 300000',
                                      hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF94A3B8), fontWeight: FontWeight.normal),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Extension rate per hour
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Denda / Overtime per Jam',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                      ),
                                      Text(
                                        'Opsional',
                                        style: TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  TextField(
                                    controller: rate.extensionRateController,
                                    keyboardType: TextInputType.number,
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
                                    decoration: InputDecoration(
                                      prefixIcon: const Padding(
                                        padding: EdgeInsets.only(left: 14, right: 8),
                                        child: Text('Rp', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontSize: 13)),
                                      ),
                                      prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                                      hintText: '20000',
                                      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                      filled: true,
                                      fillColor: const Color(0xFFF8FAFC),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),

                      // Quick presets section
                      const SizedBox(height: 4),
                      const Text(
                        'Pintasan Tambah Cepat Paket Populer:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 8),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildPresetChip('1 Hari', 'day', 1),
                            _buildPresetChip('3 Hari', 'day', 3),
                            _buildPresetChip('1 Minggu', 'week', 1),
                            _buildPresetChip('1 Bulan', 'month', 1),
                            _buildPresetChip('12 Jam', 'hour', 12),
                            _buildPresetChip('6 Jam', 'hour', 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Prominent UX-Friendly Add Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF0F172A),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                        label: const Text(
                          '+ Tambah Paket Tarif Baru (Kustom)',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                        ),
                        onPressed: _addRateRow,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky Footer Action Bar
            Container(
              padding: EdgeInsets.fromLTRB(18, 12, 18, bottomInset > 0 ? bottomInset + 12 : 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 10,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                  shadowColor: const Color(0x330F172A),
                ),
                onPressed: _isLoading ? null : _submitProduct,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(
                        _isEditing ? 'Simpan Perubahan Katalog' : 'Simpan Produk & Tarif ke Katalog',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

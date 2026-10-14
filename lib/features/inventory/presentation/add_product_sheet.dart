import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/asset_provider.dart';

class AddProductSheet extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const AddProductSheet({super.key, required this.onSuccess});

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

  int? _selectedCategoryId;
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _storageController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _accessoriesController = TextEditingController();
  bool _requiresFrpCheck = false;
  bool _isLoading = false;

  final List<_RateItem> _rates = [];

  @override
  void initState() {
    super.initState();
    // Default initial rate: 1 Hari
    _rates.add(_RateItem(unit: 'day', value: '1', price: '', extensionRate: '20000'));
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
        avatar: Icon(
          isAlreadyAdded ? Icons.check_circle_rounded : Icons.add_rounded,
          size: 16,
          color: isAlreadyAdded ? AppColors.success : AppColors.obsidian,
        ),
        label: Text(
          isAlreadyAdded ? '$label (Ada)' : '+ $label',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isAlreadyAdded ? AppColors.textMuted : AppColors.obsidian,
          ),
        ),
        backgroundColor: isAlreadyAdded ? AppColors.surfaceMuted : Colors.white,
        side: BorderSide(
          color: isAlreadyAdded ? AppColors.borderSubtle : AppColors.obsidian.withValues(alpha: 0.3),
        ),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kategori Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: TextField(
          controller: catNameController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Misal: Drone & Gimbal / Audio',
            filled: true,
            fillColor: AppColors.surfaceMuted,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final name = catNameController.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              try {
                final repo = ref.read(assetRepositoryProvider);
                final res = await repo.createCategory({'name': name});
                ref.invalidate(categoriesProvider);
                if (res['id'] != null) {
                  setState(() => _selectedCategoryId = res['id'] as int);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal membuat kategori: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Simpan'),
          ),
        ],
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
        'rates': formattedRates,
      };

      await repo.createProduct(payload);

      // Refresh catalog providers
      ref.invalidate(categoriesProvider);
      ref.invalidate(allCatalogModelsProvider);
      ref.invalidate(catalogModelsProvider);
      ref.invalidate(productsProvider);

      widget.onSuccess();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal mendaftarkan produk: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tambah Model & Tarif Sewa',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Katalog produk baru & konfigurasi paket harga',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 16),

              // Category Selector with quick-add button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kategori Perangkat *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  TextButton.icon(
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact, padding: EdgeInsets.zero),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Kategori Baru', style: TextStyle(fontSize: 12)),
                    onPressed: _showQuickAddCategoryDialog,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              categoriesAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat kategori: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                data: (cats) {
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('Pilih Kategori (Kamera, Laptop, Konsol, dll)'),
                    items: cats.map((c) {
                      return DropdownMenuItem<int>(
                        value: c['id'] as int,
                        child: Text(c['name'] ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedCategoryId = val;
                        // Auto-toggle FRP check default based on category slug
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
              const SizedBox(height: 14),

              // Brand & Model Name
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Merk / Brand *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _brandController,
                          decoration: InputDecoration(
                            hintText: 'Sony / DJI / Canon',
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nama Model *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            hintText: 'Alpha A7 IV Body',
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama model wajib' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Color & Storage (Optional)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Warna (Opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _colorController,
                          decoration: InputDecoration(
                            hintText: 'Hitam / Silver / Space Grey',
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kapasitas / Memori (Opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _storageController,
                          decoration: InputDecoration(
                            hintText: '512GB / 1TB / 32GB RAM',
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description
              const Text('Deskripsi Singkat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Spesifikasi ringkas, sensor, resolusi, port...',
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // Standard Accessories
              const Text('Kelengkapan Standar Bawaan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 4),
              const Text('Pisahkan dengan tanda koma (misal: 2x Baterai, Dual Charger, Tas, SD Card 128GB)', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              TextField(
                controller: _accessoriesController,
                decoration: InputDecoration(
                  hintText: 'Charger, Kabel HDMI, Tas, Baterai Cadangan',
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),

              // FRP / iCloud switch
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: const Text('Wajib Cek Akun (iCloud / Google FRP)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  subtitle: const Text(
                    'Aktifkan hanya untuk smartphone/tablet. Untuk kamera, proyektor, laptop, dan konsol game sebaiknya matikan.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: _requiresFrpCheck,
                  onChanged: (val) => setState(() => _requiresFrpCheck = val),
                ),
              ),
              const SizedBox(height: 20),

              // RATE CARDS BUILDER
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payments_outlined, size: 20, color: AppColors.obsidian),
                        SizedBox(width: 8),
                        Text('Paket Tarif Sewa *', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tentukan harga sewa per jam, hari, minggu, atau bulan. Minimal 1 paket wajib diisi.',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Rate rows
              ..._rates.asMap().entries.map((entry) {
                final idx = entry.key;
                final rate = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Card Header Badge & Delete Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.obsidian,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.sell_outlined, size: 13, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  'Paket #${idx + 1}: ${rate.valueController.text.isEmpty ? "1" : rate.valueController.text} ${_formatUnitName(rate.unit)}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                          if (_rates.length > 1)
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.danger,
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              icon: const Icon(Icons.delete_outline_rounded, size: 16),
                              label: const Text('Hapus Paket', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              onPressed: () => _removeRateRow(idx),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Duration Value & Duration Unit
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Durasi *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: rate.valueController,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    hintText: '1, 3, 7...',
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Satuan *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: rate.unit,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: AppColors.surface,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
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
                          const Text('Harga Sewa Paket *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: rate.priceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.obsidian, fontSize: 13),
                              hintText: 'Misal: 300000',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                            children: [
                              Text('Denda / Perpanjangan per Jam:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                              SizedBox(width: 4),
                              Text('(Opsional)', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: rate.extensionRateController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              prefixText: 'Rp ',
                              prefixStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                              hintText: '20000',
                              filled: true,
                              fillColor: AppColors.surface,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              // Quick presets section
              const SizedBox(height: 6),
              const Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 16, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text('Pintasan Tambah Cepat Paket Populer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                ],
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
                  foregroundColor: AppColors.obsidian,
                  backgroundColor: AppColors.surface,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.obsidian, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                label: const Text(
                  '+ Tambah Paket Tarif Baru (Kustom)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                onPressed: _addRateRow,
              ),
              const SizedBox(height: 20),

              // Submit button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isLoading ? null : _submitProduct,
                child: _isLoading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Simpan Produk & Tarif ke Katalog', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

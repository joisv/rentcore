import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/asset_provider.dart';
import 'add_product_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final String? initialStatusFilter;

  const InventoryScreen({super.key, this.initialStatusFilter});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(widget.initialStatusFilter);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bizState = ref.watch(businessProvider);
    final hasBusiness = bizState.activeBusinessId != null && bizState.businesses.isNotEmpty;

    final statusFilter = ref.watch(selectedAssetStatusFilterProvider);
    final categoryFilter = ref.watch(selectedAssetCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final assetsAsync = ref.watch(inventoryListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Inventaris & Katalog Unit',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          if (hasBusiness) ...[
            IconButton(
              icon: const Icon(Icons.post_add_rounded),
              tooltip: 'Tambah Model & Tarif Baru',
              onPressed: () => _showAddProductSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: () => ref.invalidate(inventoryListProvider),
            ),
          ],
        ],
      ),
      floatingActionButton: hasBusiness
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Registrasi Unit', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => _showAddAssetSheet(context),
            )
          : null,
      body: !hasBusiness
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront_rounded, size: 48, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Belum Ada Bisnis Rental',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Untuk mengelola stok perangkat, katalog iPhone & gadget, dan paket tarif, silakan daftarkan bisnis rental Anda terlebih dahulu.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.add_business_rounded),
                      label: const Text('Daftarkan Bisnis Rental Baru', style: TextStyle(fontWeight: FontWeight.w700)),
                      onPressed: () => BusinessSelectorSheet.show(context),
                    ),
                  ],
                ),
              ),
            )
          : Column(
        children: [
          // Search & Filter Header
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kode unit, serial number, atau tipe...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(assetSearchQueryProvider.notifier).setSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (val) {
                    ref.read(assetSearchQueryProvider.notifier).setSearch(val.trim());
                  },
                ),
                const SizedBox(height: 10),
                categoriesAsync.when(
                  data: (categories) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildCategoryFilterChip(null, 'Semua Kategori', categoryFilter),
                          ...categories.map((cat) {
                            return Padding(
                              padding: const EdgeInsets.only(left: 8),
                              child: _buildCategoryFilterChip(
                                cat['id'] as int?,
                                cat['name'] as String? ?? '',
                                categoryFilter,
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, _) => const SizedBox.shrink(),
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(null, 'Semua Status', statusFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('ready', 'Siap Sewa', statusFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('rented', 'Sedang Sewa', statusFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('maintenance', 'Perawatan', statusFilter),
                      const SizedBox(width: 8),
                      _buildFilterChip('in_transit', 'Dalam Mutasi', statusFilter),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Asset List
          Expanded(
            child: assetsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text('Gagal memuat inventaris: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(inventoryListProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (assets) {
                if (assets.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'Inventaris Masih Kosong',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Bisnis rental Anda belum memiliki unit terdaftar. Anda dapat menambahkan tipe model beserta paket tarif sewa terlebih dahulu, kemudian meregistrasikan unit fisiknya.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: [
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.post_add_rounded, size: 18),
                                label: const Text('1. Tambah Model & Tarif', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () => _showAddProductSheet(context),
                              ),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.obsidian,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                icon: const Icon(Icons.add_rounded, size: 18),
                                label: const Text('2. Registrasi Unit', style: TextStyle(fontWeight: FontWeight.w700)),
                                onPressed: () => _showAddAssetSheet(context),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inventoryListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: assets.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final asset = assets[index];
                      return _buildAssetCard(context, asset);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String? value, String label, String? currentValue) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) {
        ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(value);
      },
    );
  }

  Widget _buildCategoryFilterChip(int? value, String label, int? currentValue) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) {
        ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(value);
      },
    );
  }

  IconData _getCategoryIcon(String? categoryName) {
    final cat = (categoryName ?? '').toLowerCase();
    if (cat.contains('kamera') || cat.contains('camera')) return Icons.camera_alt_rounded;
    if (cat.contains('laptop') || cat.contains('komputer') || cat.contains('macbook')) return Icons.laptop_mac_rounded;
    if (cat.contains('proyektor') || cat.contains('projector')) return Icons.videocam_rounded;
    if (cat.contains('game') || cat.contains('konsol') || cat.contains('playstation')) return Icons.sports_esports_rounded;
    if (cat.contains('tablet') || cat.contains('ipad')) return Icons.tablet_mac_rounded;
    return Icons.phone_iphone_rounded;
  }

  Widget _buildAssetCard(BuildContext context, Map<String, dynamic> asset) {
    final model = asset['model'] as Map<String, dynamic>?;
    final category = model?['category'] as Map<String, dynamic>?;
    final status = asset['status'] as String? ?? 'ready';
    final grade = asset['condition_grade'] as String? ?? 'A';
    final battery = asset['battery_health'] as int?;

    final specParts = [
      category?['name'] ?? 'Gadget',
      if (model?['color'] != null && (model!['color'] as String).isNotEmpty) model['color'],
      if (model?['storage_capacity'] != null && (model!['storage_capacity'] as String).isNotEmpty) model['storage_capacity'],
    ];

    return InkWell(
      onTap: () => _showEditAssetSheet(context, asset),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Model & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getCategoryIcon(category?['name']), size: 24, color: AppColors.obsidian),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model?['name'] ?? 'Perangkat Elektronik',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        specParts.join(' • '),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                StatusBadge.inventory(status),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 12),

            // Metadata Row: Asset Code, Serial Number, Grade & Battery
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kode Unit', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      Text(
                        asset['asset_code'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Serial Number', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                      Text(
                        asset['serial_number'] ?? '-',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('Grade $grade', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                if (battery != null && battery > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('🔋 $battery%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssetSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _AddAssetForm(
        onSuccess: () {
          Navigator.pop(ctx);
          ref.invalidate(inventoryListProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Unit perangkat berhasil didaftarkan!'), backgroundColor: AppColors.success),
          );
        },
        onAddProductRequested: () {
          Navigator.pop(ctx);
          _showAddProductSheet(context);
        },
      ),
    );
  }

  void _showAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => AddProductSheet(
        onSuccess: () {
          Navigator.pop(ctx);
          ref.invalidate(allCatalogModelsProvider);
          ref.invalidate(catalogModelsProvider);
          ref.invalidate(productsProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Model produk & paket tarif berhasil didaftarkan ke katalog!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  void _showEditAssetSheet(BuildContext context, Map<String, dynamic> asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _EditAssetSheet(
        asset: asset,
        onSuccess: () {
          Navigator.pop(ctx);
          ref.invalidate(inventoryListProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perangkat berhasil diperbarui!'), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }
}

class _AddAssetForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback? onAddProductRequested;

  const _AddAssetForm({
    required this.onSuccess,
    this.onAddProductRequested,
  });

  @override
  ConsumerState<_AddAssetForm> createState() => _AddAssetFormState();
}

class _AddAssetFormState extends ConsumerState<_AddAssetForm> {
  int? _selectedModelId;
  final _codeController = TextEditingController();
  final _snController = TextEditingController();
  final _imei1Controller = TextEditingController();
  final _batteryController = TextEditingController();
  final _notesController = TextEditingController();
  String _grade = 'A';
  bool _isLoading = false;

  @override
  void dispose() {
    _codeController.dispose();
    _snController.dispose();
    _imei1Controller.dispose();
    _batteryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(allCatalogModelsProvider);

    Map<String, dynamic>? selectedModel;
    if (_selectedModelId != null && modelsAsync.hasValue) {
      for (final m in modelsAsync.value!) {
        if (m['id'] == _selectedModelId) {
          selectedModel = m;
          break;
        }
      }
    }
    final categoryName = (selectedModel?['category']?['name'] ?? '').toString().toLowerCase();
    final modelName = (selectedModel?['name'] ?? '').toString().toLowerCase();
    final isPhone = categoryName.contains('phone') || categoryName.contains('smartphone') || modelName.contains('iphone');
    final hasBattery = isPhone || categoryName.contains('laptop') || modelName.contains('macbook') || categoryName.contains('tablet') || categoryName.contains('ipad');

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Registrasi Unit Baru',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Model Catalog Selector
            const Text('Tipe Model Rental', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            modelsAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
              error: (err, _) => Text('Gagal memuat katalog: $err', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              data: (models) {
                return DropdownButtonFormField<int>(
                  initialValue: _selectedModelId,
                  isExpanded: true,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surfaceMuted,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  hint: const Text('Pilih Model Perangkat Rental...'),
                  items: models.map((m) {
                    final catName = m['category']?['name'] ?? 'Item';
                    final specs = [
                      if (m['color'] != null && (m['color'] as String).isNotEmpty) m['color'],
                      if (m['storage_capacity'] != null && (m['storage_capacity'] as String).isNotEmpty) m['storage_capacity'],
                    ].join(' - ');
                    final label = specs.isNotEmpty ? '${m['name']} ($catName • $specs)' : '${m['name']} ($catName)';
                    return DropdownMenuItem<int>(
                      value: m['id'] as int,
                      child: Text(
                        label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedModelId = val;
                      if (val != null) {
                        final m = models.firstWhere((x) => x['id'] == val, orElse: () => {});
                        final cName = (m['category']?['name'] ?? '').toString().toLowerCase();
                        final mName = (m['name'] ?? '').toString().toLowerCase();
                        if (cName.contains('phone') || mName.contains('iphone')) {
                          if (_batteryController.text.isEmpty) _batteryController.text = '100';
                        }
                      }
                    });
                  },
                );
              },
            ),
            if (widget.onAddProductRequested != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text(
                    'Model belum ada? + Tambah Model Baru',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                  onPressed: widget.onAddProductRequested,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Asset Code & Serial Number
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kode Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Misal: CAM-001 / IP15P-001',
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
                      const Text('Serial Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _snController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          hintText: 'Misal: F2LW89...',
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

            // IMEI 1 & Battery Health
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPhone ? 'IMEI 1 (Wajib HP)' : 'IMEI 1 (Opsional)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _imei1Controller,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: isPhone ? 'Nomor IMEI 15-digit' : 'Opsional / tidak ada',
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
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasBattery ? 'Battery Health (%)' : 'Battery (Opsional)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _batteryController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: hasBattery ? '100' : 'N/A',
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

            // Condition Grade
            const Text('Kondisi Fisik Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            Row(
              children: ['A', 'B', 'C'].map((g) {
                final isSelected = _grade == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Grade $g'),
                    selected: isSelected,
                    selectedColor: AppColors.obsidian,
                    backgroundColor: AppColors.surfaceMuted,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    onSelected: (_) => setState(() => _grade = g),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Notes
            const Text('Catatan Tambahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(height: 6),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(
                hintText: 'Kelengkapan atau kondisi fisik unit...',
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),

            // Submit
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: (_isLoading || _selectedModelId == null || _codeController.text.trim().isEmpty || _snController.text.trim().isEmpty)
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final repo = ref.read(assetRepositoryProvider);
                        final payload = <String, dynamic>{
                          'model_id': _selectedModelId,
                          'asset_code': _codeController.text.trim().toUpperCase(),
                          'serial_number': _snController.text.trim().toUpperCase(),
                          'condition_grade': _grade,
                          if (_imei1Controller.text.trim().isNotEmpty) 'imei_1': _imei1Controller.text.trim(),
                          if (_batteryController.text.trim().isNotEmpty && int.tryParse(_batteryController.text.trim()) != null)
                            'battery_health': int.tryParse(_batteryController.text.trim()),
                          if (_notesController.text.trim().isNotEmpty) 'notes': _notesController.text.trim(),
                        };
                        await repo.createAsset(payload);
                        widget.onSuccess();
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          messenger.showSnackBar(
                            SnackBar(content: Text('Gagal registrasi unit: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Simpan ke Inventaris', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EditAssetSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onSuccess;

  const _EditAssetSheet({required this.asset, required this.onSuccess});

  @override
  ConsumerState<_EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends ConsumerState<_EditAssetSheet> {
  late String _status;
  late String _grade;
  late TextEditingController _batteryController;
  late TextEditingController _notesController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final rawStatus = widget.asset['status']?.toString().toLowerCase().trim();
    _status = (rawStatus != null && rawStatus.isNotEmpty) ? rawStatus : 'ready';
    final rawGrade = widget.asset['condition_grade']?.toString().toUpperCase().trim();
    _grade = (rawGrade == 'A' || rawGrade == 'B' || rawGrade == 'C') ? rawGrade! : 'A';
    final bh = widget.asset['battery_health'];
    _batteryController = TextEditingController(text: bh != null ? bh.toString() : '');
    _notesController = TextEditingController(text: widget.asset['notes'] ?? '');
  }

  @override
  void dispose() {
    _batteryController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final model = widget.asset['model'] as Map<String, dynamic>?;
    final categoryName = (model?['category']?['name'] ?? '').toString().toLowerCase();
    final modelName = (model?['name'] ?? '').toString().toLowerCase();
    final hasBattery = categoryName.contains('phone') || categoryName.contains('laptop') || modelName.contains('iphone') || modelName.contains('macbook');
    final isRented = _status == 'rented';
    final isInTransit = _status == 'in_transit';
    final isLockedStatus = isRented || isInTransit;

    final List<DropdownMenuItem<String>> statusItems = [
      if (isRented)
        const DropdownMenuItem(
          value: 'rented',
          enabled: false,
          child: Text('Sedang Disewa (Terkunci)'),
        ),
      if (isInTransit)
        const DropdownMenuItem(
          value: 'in_transit',
          enabled: false,
          child: Text('Dalam Mutasi (Terkunci)'),
        ),
      const DropdownMenuItem(value: 'ready', child: Text('Siap Sewa (Ready)')),
      const DropdownMenuItem(value: 'maintenance', child: Text('Perawatan / Rusak (Maintenance)')),
      const DropdownMenuItem(value: 'retired', child: Text('Pensiun / Afkir (Retired)')),
      const DropdownMenuItem(value: 'lost', child: Text('Hilang (Lost)')),
    ];

    if (!statusItems.any((item) => item.value == _status)) {
      statusItems.insert(
        0,
        DropdownMenuItem(
          value: _status,
          enabled: false,
          child: Text('$_status (Terkunci)'),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model?['name'] ?? 'Perangkat Elektronik',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  Text(
                    '${widget.asset['asset_code'] ?? '-'} • SN: ${widget.asset['serial_number'] ?? '-'}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

          // Status Selector
          const Text('Status Operasional Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: InputDecoration(
              filled: true,
              fillColor: isLockedStatus ? AppColors.surfaceMuted.withValues(alpha: 0.6) : AppColors.surfaceMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            items: statusItems,
            onChanged: isLockedStatus
                ? null
                : (val) {
                    if (val != null) setState(() => _status = val);
                  },
          ),
          if (isLockedStatus) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isRented ? AppColors.infoLight : AppColors.warningLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isRented ? AppColors.info.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isRented ? Icons.info_outline_rounded : Icons.local_shipping_outlined,
                    size: 16,
                    color: isRented ? AppColors.info : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isRented
                          ? 'Unit sedang aktif disewa pelanggan. Status operasional dikunci otomatis oleh sistem rental.'
                          : 'Unit sedang dalam perjalanan mutasi antar cabang. Status operasional dikunci otomatis.',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isRented ? AppColors.info : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),

          // Grade Selector
          const Text('Kondisi Fisik', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: ['A', 'B', 'C'].map((g) {
              final isSelected = _grade == g;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text('Grade $g'),
                  selected: isSelected,
                  selectedColor: AppColors.obsidian,
                  backgroundColor: AppColors.surfaceMuted,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  onSelected: (_) => setState(() => _grade = g),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // Battery Health
          Text(
            hasBattery ? 'Battery Health (%)' : 'Battery Health (Opsional)',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _batteryController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: hasBattery ? '100' : 'N/A',
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 14),

          // Notes
          const Text('Catatan Perangkat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Save Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _isLoading
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final repo = ref.read(assetRepositoryProvider);
                      final payload = <String, dynamic>{
                        if (!isLockedStatus) 'status': _status,
                        'condition_grade': _grade,
                        if (_batteryController.text.trim().isNotEmpty && int.tryParse(_batteryController.text.trim()) != null)
                          'battery_health': int.tryParse(_batteryController.text.trim()),
                        'notes': _notesController.text.trim(),
                      };
                      await repo.updateAsset(widget.asset['id'] as int, payload);
                      widget.onSuccess();
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Gagal perbarui data unit: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

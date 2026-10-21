import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/business_provider.dart';
import '../data/asset_repository.dart';
import '../providers/asset_provider.dart';
import 'add_product_sheet.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  final String? initialStatusFilter;
  final int initialTabIndex;

  const InventoryScreen({
    super.key,
    this.initialStatusFilter,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStatusFilter != null) {
        ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(widget.initialStatusFilter);
      }
      ref.read(assetSearchQueryProvider.notifier).setSearch('');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(inventoryListProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(catalogModelsProvider);
    ref.invalidate(allCatalogModelsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final bizState = ref.watch(businessProvider);
    final hasBusiness = bizState.activeBusinessId != null;

    final statusFilter = ref.watch(selectedAssetStatusFilterProvider);
    final categoryFilter = ref.watch(selectedAssetCategoryFilterProvider);
    final searchQuery = ref.watch(assetSearchQueryProvider);

    final categoriesAsync = ref.watch(categoriesProvider);
    final assetsAsync = ref.watch(inventoryListProvider);
    final productsAsync = ref.watch(productsProvider);

    print('>>> [INVENTORY_SCREEN_BUILD] tabController.index: ${_tabController.index}, anim: ${_tabController.animation?.value}');

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
        bottom: hasBusiness
            ? TabBar(
                controller: _tabController,
                labelColor: AppColors.obsidian,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.obsidian,
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.inventory_2_outlined, size: 18), text: 'Unit Fisik (Inventaris)'),
                  Tab(icon: Icon(Icons.style_outlined, size: 18), text: 'Katalog & Tarif'),
                ],
              )
            : null,
        actions: [
          if (hasBusiness) ...[
            IconButton(
              icon: const Icon(Icons.post_add_rounded),
              tooltip: 'Tambah Model Baru',
              onPressed: () => _openAddProductSheet(context),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Segarkan',
              onPressed: _refreshAll,
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
              onPressed: () => _openAddAssetSheet(context),
            )
          : null,
      body: !hasBusiness
          ? _buildNoBusinessView(context)
          : Column(
              children: [
                _buildBranchBar(context, bizState),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // TAB 0: UNIT FISIK
                      _buildUnitsView(
                        context,
                        bizState,
                        statusFilter,
                        categoryFilter,
                        searchQuery,
                        categoriesAsync,
                        assetsAsync,
                      ),
                      // TAB 1: KATALOG & TARIF
                      _buildCatalogView(
                        context,
                        categoryFilter,
                        searchQuery,
                        categoriesAsync,
                        productsAsync,
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ==========================================
  // BRANCH CONTEXT HEADER
  // ==========================================
  Widget _buildBranchBar(BuildContext context, BusinessState bizState) {
    final isConsolidated = bizState.isConsolidated;
    final branchName = isConsolidated ? 'Semua Cabang (Konsolidasi)' : (bizState.activeBranchName ?? 'Pilih Cabang');
    final isCentral = !isConsolidated && bizState.isCentralBranch;

    return Container(
      width: double.infinity,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(
              isConsolidated ? Icons.hub_rounded : (isCentral ? Icons.store_rounded : Icons.storefront_outlined),
              size: 16,
              color: AppColors.obsidian,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Cabang: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  children: [
                    TextSpan(
                      text: branchName,
                      style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (isCentral)
                      const TextSpan(
                        text: ' (Pusat)',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.info),
                      ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => BusinessSelectorSheet.show(context),
              borderRadius: BorderRadius.circular(6),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.info)),
                    SizedBox(width: 2),
                    Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.info),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 0: PHYSICAL UNITS (INVENTARIS)
  // ==========================================
  Widget _buildUnitsView(
    BuildContext context,
    BusinessState bizState,
    String? statusFilter,
    int? categoryFilter,
    String searchQuery,
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    AsyncValue<List<Map<String, dynamic>>> assetsAsync,
  ) {
    return Column(
      children: [
        // Search & Filter Section
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari kode unit, serial number, atau nama tipe...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            ref.read(assetSearchQueryProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  setState(() {});
                  ref.read(assetSearchQueryProvider.notifier).setSearch(val.trim());
                },
              ),
              const SizedBox(height: 8),
              // Category chips
              categoriesAsync.when(
                data: (categories) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip(
                        selected: categoryFilter == null,
                        label: 'Semua Kategori',
                        onTap: () => ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null),
                      ),
                      ...categories.map((cat) {
                        final catId = cat['id'] as int?;
                        final catName = cat['name']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildChip(
                            selected: categoryFilter == catId,
                            label: catName,
                            onTap: () => ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(catId),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 6),
              // Status chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip(
                      selected: statusFilter == null,
                      label: 'Semua Status',
                      onTap: () => ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(null),
                    ),
                    const SizedBox(width: 6),
                    _buildChip(
                      selected: statusFilter == 'ready',
                      label: 'Siap Sewa',
                      onTap: () => ref.read(selectedAssetStatusFilterProvider.notifier).setFilter('ready'),
                    ),
                    const SizedBox(width: 6),
                    _buildChip(
                      selected: statusFilter == 'rented',
                      label: 'Sedang Sewa',
                      onTap: () => ref.read(selectedAssetStatusFilterProvider.notifier).setFilter('rented'),
                    ),
                    const SizedBox(width: 6),
                    _buildChip(
                      selected: statusFilter == 'maintenance',
                      label: 'Perawatan',
                      onTap: () => ref.read(selectedAssetStatusFilterProvider.notifier).setFilter('maintenance'),
                    ),
                    const SizedBox(width: 6),
                    _buildChip(
                      selected: statusFilter == 'in_transit',
                      label: 'Dalam Mutasi',
                      onTap: () => ref.read(selectedAssetStatusFilterProvider.notifier).setFilter('in_transit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        // List Area
        Expanded(
          child: assetsAsync.when(
            loading: () {
              print('>>> [UI_UNITS_VIEW] assetsAsync: LOADING');
              return const Center(child: CircularProgressIndicator());
            },
            error: (err, st) {
              print('>>> [UI_UNITS_VIEW] assetsAsync: ERROR: $err\n$st');
              return Center(
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
              );
            },
            data: (assets) {
              print('>>> [UI_UNITS_VIEW] assetsAsync: DATA length=${assets.length}');
              for (var i = 0; i < assets.length; i++) {
                print('>>> [UI_UNITS_VIEW] asset[$i]: ${assets[i]['asset_code']} (${assets[i]['status']})');
              }
              if (assets.isEmpty) {
                final hasSearch = searchQuery.isNotEmpty;
                final hasFilter = statusFilter != null || categoryFilter != null;

                if (hasSearch) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(inventoryListProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.search_off_rounded, size: 36, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak Ada Unit Ditemukan',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tidak ada unit inventaris yang cocok dengan pencarian "$searchQuery"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.obsidian,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Reset Pencarian'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              ref.read(assetSearchQueryProvider.notifier).setSearch('');
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (hasFilter) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(inventoryListProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      children: [
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.filter_alt_off_rounded, size: 36, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Tidak Ada Unit Sesuai Filter',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tidak ditemukan unit inventaris dengan status atau kategori yang dipilih',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.obsidian,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Reset Semua Filter'),
                            onPressed: () {
                              ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(null);
                              ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(inventoryListProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    children: [
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.inventory_2_outlined, size: 36, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Belum Ada Unit Inventaris',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Bisnis rental Anda belum memiliki unit fisik terdaftar. Silakan registrasi unit baru atau tambahkan model di katalog.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      Center(
                        child: Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.obsidian,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Registrasi Unit Baru'),
                              onPressed: () => _openAddAssetSheet(context),
                            ),
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.obsidian,
                                side: const BorderSide(color: AppColors.border),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.post_add_rounded),
                              label: const Text('Tambah Model & Tarif'),
                              onPressed: () => _openAddProductSheet(context),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(inventoryListProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: assets.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    );
  }

  // ==========================================
  // ASSET CARD
  // ==========================================
  Widget _buildAssetCard(BuildContext context, Map<String, dynamic> asset) {
    print('>>> [UI_CARD] Building card for: ${asset['asset_code']}');
    final rawModel = asset['model'];
    final model = rawModel is Map ? Map<String, dynamic>.from(rawModel) : null;
    final rawCat = model?['category'];
    final category = rawCat is Map ? Map<String, dynamic>.from(rawCat) : null;
    final catName = category?['name']?.toString() ?? 'Gadget';

    final assetCode = asset['asset_code']?.toString() ?? '-';
    final serialNum = asset['serial_number']?.toString() ?? '-';
    final modelName = model?['name']?.toString() ?? 'Perangkat Elektronik';
    final status = asset['status']?.toString() ?? 'ready';
    final grade = asset['condition_grade']?.toString() ?? 'A';
    final battery = asset['battery_health'] != null ? int.tryParse(asset['battery_health'].toString()) : null;

    final rawAff = asset['affiliate'];
    final affiliate = rawAff is Map ? Map<String, dynamic>.from(rawAff) : null;
    final branchName = affiliate?['name']?.toString();

    final specs = <String>[
      catName,
      if (model?['color'] != null && model!['color'].toString().isNotEmpty) model['color'].toString(),
      if (model?['storage_capacity'] != null && model!['storage_capacity'].toString().isNotEmpty)
        '${model['storage_capacity']}GB',
      if (branchName != null && branchName.isNotEmpty) branchName,
    ];

    return InkWell(
      onTap: () => _openEditAssetSheet(context, asset),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0A000000),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.phone_iphone_rounded, size: 24, color: AppColors.obsidian),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        modelName,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        specs.join(' • '),
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                StatusBadge.inventory(status),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Kode Unit', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      Text(assetCode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Serial Number', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                      Text(serialNum, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(6)),
                  child: Text('Grade $grade', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                if (battery != null && battery > 0) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(6)),
                    child: Text('🔋 $battery%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 32),
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppColors.obsidian,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Edit Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  onPressed: () => _openEditAssetSheet(context, asset),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // TAB 1: PRODUCT CATALOG & RATES
  // ==========================================
  Widget _buildCatalogView(
    BuildContext context,
    int? categoryFilter,
    String searchQuery,
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    AsyncValue<List<Map<String, dynamic>>> productsAsync,
  ) {
    return Column(
      children: [
        Container(
          color: AppColors.surface,
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Cari model, merk, atau spesifikasi...',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: AppColors.textSecondary),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            ref.read(assetSearchQueryProvider.notifier).setSearch('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (val) {
                  setState(() {});
                  ref.read(assetSearchQueryProvider.notifier).setSearch(val.trim());
                },
              ),
              const SizedBox(height: 8),
              categoriesAsync.when(
                data: (categories) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildChip(
                        selected: categoryFilter == null,
                        label: 'Semua Kategori',
                        onTap: () => ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null),
                      ),
                      ...categories.map((cat) {
                        final catId = cat['id'] as int?;
                        final catName = cat['name']?.toString() ?? '';
                        return Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: _buildChip(
                            selected: categoryFilter == catId,
                            label: catName,
                            onTap: () => ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(catId),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text('Gagal memuat katalog: $err', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(productsProvider),
                      child: const Text('Coba Lagi'),
                    ),
                  ],
                ),
              ),
            ),
            data: (products) {
              if (products.isEmpty) {
                final hasSearch = searchQuery.isNotEmpty;
                final hasCategory = categoryFilter != null;

                if (hasSearch) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(productsProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 32),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.search_off_rounded, size: 44, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tidak Ada Katalog Ditemukan',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tidak ada model produk yang cocok dengan pencarian "$searchQuery"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.obsidian,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Reset Pencarian'),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                              ref.read(assetSearchQueryProvider.notifier).setSearch('');
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                if (hasCategory) {
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(productsProvider),
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(32),
                      children: [
                        const SizedBox(height: 32),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.filter_alt_off_rounded, size: 44, color: AppColors.textMuted),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Tidak Ada Katalog Dalam Kategori Ini',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada model produk terdaftar untuk kategori yang dipilih.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.obsidian,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            label: const Text('Tampilkan Semua Kategori'),
                            onPressed: () {
                              ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(productsProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(32),
                    children: [
                      const SizedBox(height: 32),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.style_outlined, size: 44, color: AppColors.textMuted),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Belum Ada Katalog Produk',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Bisnis rental Anda belum memiliki katalog model atau paket tarif sewa. Tambahkan model katalog dan tarif sewa untuk mulai mengelola armada.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.obsidian,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.post_add_rounded),
                          label: const Text('+ Tambah Model & Tarif Baru'),
                          onPressed: () => _openAddProductSheet(context),
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => ref.invalidate(productsProvider),
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: products.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final product = products[index];
                    return _buildProductCard(context, product);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==========================================
  // PRODUCT CARD
  // ==========================================
  Widget _buildProductCard(BuildContext context, Map<String, dynamic> product) {
    final rawCat = product['category'];
    final category = rawCat is Map ? Map<String, dynamic>.from(rawCat) : null;
    final catName = category?['name']?.toString() ?? 'Gadget';

    final name = product['name']?.toString() ?? '-';
    final brand = product['brand']?.toString() ?? '';
    final color = product['color']?.toString() ?? '';
    final storage = product['storage_capacity']?.toString() ?? '';

    final readyUnitsCount = product['ready_units_count'] ?? 0;
    final totalUnitsCount = product['assets_count'] ?? 0;

    final rawTiers = product['pricing_tiers'];
    final tiers = rawTiers is List ? rawTiers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

    final desc = <String>[
      if (brand.isNotEmpty) brand,
      catName,
      if (color.isNotEmpty) color,
      if (storage.isNotEmpty) '${storage}GB',
    ].join(' • ');

    final unitCountText = totalUnitsCount == 0
        ? '0 Unit • Belum Ada Unit Fisik'
        : '$readyUnitsCount Siap Sewa • $totalUnitsCount Total Unit';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.style_rounded, size: 24, color: AppColors.obsidian),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(desc, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      unitCountText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: totalUnitsCount == 0 ? AppColors.warning : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (tiers.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tiers.map((tier) {
                final duration = '${tier['duration_value'] ?? 1} ${tier['duration_unit'] ?? 'hari'}';
                final price = CurrencyFormatter.format(tier['price'] ?? 0);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    '$duration: $price',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (totalUnitsCount == 0)
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('+ Daftarkan Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => _openAddAssetSheet(context, initialModelId: int.tryParse(product['id']?.toString() ?? '')),
                )
              else
                TextButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Registrasi Unit Tipe Ini', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                  onPressed: () => _openAddAssetSheet(context, initialModelId: int.tryParse(product['id']?.toString() ?? '')),
                ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 32),
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.obsidian,
                  side: const BorderSide(color: AppColors.border),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
                icon: const Icon(Icons.edit_outlined, size: 14),
                label: const Text('Edit Model & Tarif', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                onPressed: () => _openEditProductSheet(context, product),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // HELPERS & SHEETS
  // ==========================================
  Widget _buildChip({required bool selected, required String label, required VoidCallback onTap}) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textPrimary,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildNoBusinessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.storefront_rounded, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 16),
            const Text('Belum Ada Bisnis Rental', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Silakan pilih atau daftarkan bisnis rental Anda untuk mengelola inventaris.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => BusinessSelectorSheet.show(context),
              child: const Text('Pilih Bisnis Rental'),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddProductSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => AddProductSheet(onSuccess: _refreshAll),
    );
  }

  void _openEditProductSheet(BuildContext context, Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => AddProductSheet(
        initialProduct: product,
        onSuccess: _refreshAll,
      ),
    );
  }

  void _openAddAssetSheet(BuildContext context, {int? initialModelId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _AddAssetSheet(initialModelId: initialModelId, onSuccess: _refreshAll),
    );
  }

  void _openEditAssetSheet(BuildContext context, Map<String, dynamic> asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => _EditAssetSheet(asset: asset, onSuccess: _refreshAll),
    );
  }
}

// ==========================================
// ADD ASSET SHEET (REGISTER NEW UNIT)
// ==========================================
class _AddAssetSheet extends ConsumerStatefulWidget {
  final int? initialModelId;
  final VoidCallback onSuccess;

  const _AddAssetSheet({this.initialModelId, required this.onSuccess});

  @override
  ConsumerState<_AddAssetSheet> createState() => _AddAssetSheetState();
}

class _AddAssetSheetState extends ConsumerState<_AddAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  int? _selectedModelId;
  final _assetCodeController = TextEditingController();
  final _serialNumberController = TextEditingController();
  final _imei1Controller = TextEditingController();
  final _batteryHealthController = TextEditingController(text: '100');
  final _notesController = TextEditingController();
  String _grade = 'A';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.initialModelId;
    _assetCodeController.text = 'AST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _assetCodeController.dispose();
    _serialNumberController.dispose();
    _imei1Controller.dispose();
    _batteryHealthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(allCatalogModelsProvider);
    final bizState = ref.watch(businessProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Registrasi Unit Baru', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              // Model Dropdown
              const Text('Model / Tipe Perangkat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              modelsAsync.when(
                data: (models) {
                  return DropdownButtonFormField<int>(
                    initialValue: _selectedModelId,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    hint: const Text('Pilih Model Katalog'),
                    items: models.map((m) {
                      final id = m['id'] as int;
                      final name = m['name']?.toString() ?? '-';
                      final brand = m['brand']?.toString() ?? '';
                      return DropdownMenuItem<int>(
                        value: id,
                        child: Text('$name ($brand)'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedModelId = val),
                    validator: (val) => val == null ? 'Pilih tipe model terlebih dahulu' : null,
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat model: $e', style: const TextStyle(color: AppColors.danger)),
              ),
              const SizedBox(height: 12),
              // Asset Code
              const Text('Kode Unit / Barcode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _assetCodeController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Kode unit wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              // Serial Number
              const Text('Serial Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  hintText: 'Nomor seri pabrik (SN)',
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // IMEI 1
              const Text('IMEI 1 (Opsional untuk Smartphone)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _imei1Controller,
                decoration: InputDecoration(
                  hintText: '15 digit IMEI',
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Grade & Battery
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kondisi Fisik', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _grade,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: ['A', 'B', 'C'].map((g) => DropdownMenuItem(value: g, child: Text('Grade $g'))).toList(),
                          onChanged: (val) => setState(() => _grade = val ?? 'A'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Battery Health (%)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _batteryHealthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
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
              const SizedBox(height: 12),
              // Notes
              const Text('Catatan Tambahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Kondisi fisik, lecet, kelengkapan awal...',
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),
              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);

                          try {
                            final repo = ref.read(assetRepositoryProvider);
                            final payload = <String, dynamic>{
                              'model_id': _selectedModelId,
                              'asset_code': _assetCodeController.text.trim(),
                              if (_serialNumberController.text.trim().isNotEmpty)
                                'serial_number': _serialNumberController.text.trim(),
                              if (_imei1Controller.text.trim().isNotEmpty)
                                'imei_1': _imei1Controller.text.trim(),
                              'status': 'ready',
                              'condition_grade': _grade,
                              'battery_health': int.tryParse(_batteryHealthController.text.trim()) ?? 100,
                              if (_notesController.text.trim().isNotEmpty)
                                'notes': _notesController.text.trim(),
                              if (bizState.activeBranchId != null)
                                'affiliate_id': bizState.activeBranchId,
                            };

                            await repo.createAsset(payload);
                            nav.pop();
                            widget.onSuccess();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Unit inventaris berhasil didaftarkan!')),
                            );
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Gagal mendaftar unit: $e'), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan & Daftarkan Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// EDIT ASSET SHEET (UPDATE EXISTING UNIT)
// ==========================================
class _EditAssetSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> asset;
  final VoidCallback onSuccess;

  const _EditAssetSheet({required this.asset, required this.onSuccess});

  @override
  ConsumerState<_EditAssetSheet> createState() => _EditAssetSheetState();
}

class _EditAssetSheetState extends ConsumerState<_EditAssetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _assetCodeController;
  late final TextEditingController _serialNumberController;
  late final TextEditingController _imei1Controller;
  late final TextEditingController _batteryHealthController;
  late final TextEditingController _notesController;
  late String _status;
  late String _grade;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _assetCodeController = TextEditingController(text: widget.asset['asset_code']?.toString() ?? '');
    _serialNumberController = TextEditingController(text: widget.asset['serial_number']?.toString() ?? '');
    _imei1Controller = TextEditingController(text: widget.asset['imei_1']?.toString() ?? '');
    _batteryHealthController = TextEditingController(text: widget.asset['battery_health']?.toString() ?? '100');
    _notesController = TextEditingController(text: widget.asset['notes']?.toString() ?? '');
    _status = widget.asset['status']?.toString() ?? 'ready';
    _grade = widget.asset['condition_grade']?.toString() ?? 'A';
  }

  @override
  void dispose() {
    _assetCodeController.dispose();
    _serialNumberController.dispose();
    _imei1Controller.dispose();
    _batteryHealthController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawModel = widget.asset['model'];
    final model = rawModel is Map ? Map<String, dynamic>.from(rawModel) : null;
    final modelName = model?['name']?.toString() ?? 'Perangkat';
    final isLocked = _status != 'ready' && _status != 'maintenance';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Edit Unit Inventaris', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                      Text(modelName, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                  IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 16),
              // Status Dropdown
              const Text('Status Operasional Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: isLocked ? AppColors.surfaceMuted : AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: [
                  const DropdownMenuItem(value: 'ready', child: Text('Siap Sewa (Ready)')),
                  const DropdownMenuItem(value: 'rented', child: Text('Sedang Sewa (Rented)')),
                  const DropdownMenuItem(value: 'maintenance', child: Text('Dalam Perawatan (Maintenance)')),
                  const DropdownMenuItem(value: 'in_transit', child: Text('Dalam Mutasi / Transfer')),
                  if (!['ready', 'rented', 'maintenance', 'in_transit'].contains(_status))
                    DropdownMenuItem(value: _status, child: Text('$_status (Terkunci)')),
                ],
                onChanged: isLocked ? null : (val) => setState(() => _status = val ?? 'ready'),
              ),
              if (_status == 'rented') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_rounded, size: 20, color: AppColors.warning),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sedang Disewa (Terkunci)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unit sedang aktif disewa pelanggan. Status operasional tidak dapat diubah manual.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_status == 'in_transit') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_shipping_outlined, size: 20, color: AppColors.info),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dalam Mutasi (Terkunci)',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unit sedang dalam perjalanan mutasi antar cabang. Status operasional tidak dapat diubah manual.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Kode Unit
              const Text('Kode Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _assetCodeController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Kode unit wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              // Serial Number
              const Text('Serial Number', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serialNumberController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // IMEI 1
              const Text('IMEI 1', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _imei1Controller,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Grade & Battery
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Kondisi Fisik', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _grade,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surfaceMuted,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          items: ['A', 'B', 'C'].map((g) => DropdownMenuItem(value: g, child: Text('Grade $g'))).toList(),
                          onChanged: (val) => setState(() => _grade = val ?? 'A'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Battery Health (%)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _batteryHealthController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
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
              const SizedBox(height: 12),
              // Notes
              const Text('Catatan Perangkat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 6),
              TextFormField(
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : () async {
                          if (!_formKey.currentState!.validate()) return;
                          setState(() => _isLoading = true);
                          final messenger = ScaffoldMessenger.of(context);
                          final nav = Navigator.of(context);

                          try {
                            final repo = ref.read(assetRepositoryProvider);
                            final assetId = widget.asset['id'] as int;
                            final payload = <String, dynamic>{
                              'asset_code': _assetCodeController.text.trim(),
                              'serial_number': _serialNumberController.text.trim(),
                              'imei_1': _imei1Controller.text.trim(),
                              if (!isLocked) 'status': _status,
                              'condition_grade': _grade,
                              'battery_health': int.tryParse(_batteryHealthController.text.trim()) ?? 100,
                              'notes': _notesController.text.trim(),
                            };

                            await repo.updateAsset(assetId, payload);
                            nav.pop();
                            widget.onSuccess();
                            messenger.showSnackBar(
                              const SnackBar(content: Text('Perubahan data unit berhasil disimpan!')),
                            );
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              messenger.showSnackBar(
                                SnackBar(content: Text('Gagal menyimpan: $e'), backgroundColor: AppColors.danger),
                              );
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

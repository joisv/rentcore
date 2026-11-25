import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/debounced_search_controller.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/presentation/widgets/report_shared_widgets.dart'
    show formatReportBranchName;
import '../../home/providers/dashboard_provider.dart';
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

  /// Displays the chained bottom sheet after an asset model is created.
  static Future<void> showModelCreatedBottomSheet(
    BuildContext context, {
    required Map<String, dynamic> model,
    VoidCallback? onRegisterUnit,
  }) {
    final modelName = model['name']?.toString() ?? 'Model Baru';

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Centered status indicator badge & header
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppColors.success,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'Model Berhasil Dibuat!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.45,
                      color: AppColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Langkah berikutnya: Daftarkan nomor seri atau identitas fisik untuk ',
                      ),
                      TextSpan(
                        text: modelName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text: ' agar siap disewakan.',
                      ),
                    ],
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                key: const Key('register_unit_now_button'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text(
                  'Daftarkan Unit Fisik Sekarang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  onRegisterUnit?.call();
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('dismiss_model_created_button'),
                onPressed: () => Navigator.pop(ctx),
                child: const Text(
                  'Selesai / Nanti Saja',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final DebouncedSearchController _searchDebouncer = DebouncedSearchController();
  final ScrollController _scrollController = ScrollController();
  final Set<String> _expandedModelKeys = <String>{};
  String _searchQuery = '';

  final List<Map<String, dynamic>> _extraAssets = [];
  int _currentAssetPage = 1;
  bool _hasMoreAssets = true;
  bool _isLoadingMoreAssets = false;

  void _resetAssetPagination() {
    _extraAssets.clear();
    _currentAssetPage = 1;
    _hasMoreAssets = true;
    _isLoadingMoreAssets = false;
  }

  Future<void> _onAssetsScroll() async {
    if (!_scrollController.hasClients ||
        _isLoadingMoreAssets ||
        !_hasMoreAssets) {
      return;
    }
    if (_scrollController.position.maxScrollExtent <= 0 ||
        _scrollController.position.pixels <= 0) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
      final bizState = ref.read(businessProvider);
      final repo = ref.read(assetRepositoryProvider);
      final status = ref.read(selectedAssetStatusFilterProvider);
      final categoryId = ref.read(selectedAssetCategoryFilterProvider);
      final search = _searchQuery.trim();

      setState(() => _isLoadingMoreAssets = true);
      try {
        final nextPage = _currentAssetPage + 1;
        final cancelToken = _searchDebouncer.nextCancelToken('Pagination superseded');
        repo.attachCancelToken(cancelToken);
        final res = await repo.fetchAssetsPaginated(
          status: status,
          categoryId: categoryId,
          search: search.isEmpty ? null : search,
          branchId: bizState.activeBranchId,
          allBranches: bizState.isConsolidated,
          page: nextPage,
        );

        if (mounted) {
          final existingIds = <dynamic>{};
          for (final a in _extraAssets) {
            final id = a['id'];
            if (id != null) existingIds.add(id);
          }
          final currentBaseAssets = ref.read(inventoryListProvider).value ?? [];
          for (final a in currentBaseAssets) {
            final id = a['id'];
            if (id != null) existingIds.add(id);
          }

          final uniqueNewItems = res.items.where((item) {
            final id = item['id'];
            return id == null || existingIds.add(id);
          }).toList();

          setState(() {
            _currentAssetPage = nextPage;
            _hasMoreAssets = res.hasMore;
            _extraAssets.addAll(uniqueNewItems);
            _isLoadingMoreAssets = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isLoadingMoreAssets = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onAssetsScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialStatusFilter != null) {
        ref
            .read(selectedAssetStatusFilterProvider.notifier)
            .setFilter(widget.initialStatusFilter);
      }
      ref.read(assetSearchQueryProvider.notifier).setSearch('');
      ref.read(catalogSearchQueryProvider.notifier).setSearch('');
    });
  }

  @override
  void dispose() {
    _searchDebouncer.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _searchDebouncer.run(
      val,
      (trimmed, _) {
        if (!mounted) return;
        _resetAssetPagination();
        setState(() => _searchQuery = trimmed);
      },
      immediate: isTestEnvironment,
    );
  }

  void _refreshAll() {
    _searchDebouncer.cancelPending();
    _resetAssetPagination();
    ref.invalidate(inventoryListProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(catalogModelsProvider);
    ref.invalidate(allCatalogModelsProvider);
    ref.invalidate(dashboardKpiProvider);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchDebouncer.cancelPending();
    _resetAssetPagination();
    setState(() => _searchQuery = '');
    ref.read(assetSearchQueryProvider.notifier).setSearch('');
    ref.read(catalogSearchQueryProvider.notifier).setSearch('');
  }

  void _resetAllFilters() {
    ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(null);
    ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null);
  }

  @override
  Widget build(BuildContext context) {
    final bizState = ref.watch(businessProvider);
    final hasBusiness = bizState.activeBusinessId != null;

    final statusFilter = ref.watch(selectedAssetStatusFilterProvider);
    final categoryFilter = ref.watch(selectedAssetCategoryFilterProvider);

    final categoriesAsync = ref.watch(categoriesProvider);
    final assetsAsync = ref.watch(inventoryListProvider);
    final productsAsync = ref.watch(productsProvider);

    ref.listen<AsyncValue<List<Map<String, dynamic>>>>(
      inventoryListProvider,
      (previous, next) {
        if (next.hasValue && _extraAssets.isNotEmpty) {
          _resetAssetPagination();
        }
      },
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: hasBusiness
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              automaticallyImplyLeading: false,
              titleSpacing: 20,
              toolbarHeight: 62,
              title: const Text(
                'Daftar Aset',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              actions: [
                if (bizState.canRegisterUnits)
                  Padding(
                    padding: const EdgeInsets.only(right: 20),
                    child: Center(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          key: const Key('inventory_add_model_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F172A),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => _openAddProductSheet(context),
                          child: const Text(
                            '+ Model Baru',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            )
          : null,
      body: !hasBusiness
          ? _buildNoBusinessView(context)
          : Column(
              children: [
                if (bizState.isConsolidated) _buildBranchBar(context, bizState),
                if (!bizState.canRegisterUnits) _buildOwnerOnlyPolicyBanner(),
                Expanded(
                  child: _buildUnifiedBody(
                    context: context,
                    bizState: bizState,
                    statusFilter: statusFilter,
                    categoryFilter: categoryFilter,
                    categoriesAsync: categoriesAsync,
                    assetsAsync: assetsAsync,
                    productsAsync: productsAsync,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOwnerOnlyPolicyBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        key: const Key('inventory_owner_only_notice'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Color(0xFF64748B),
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pendaftaran unit baru hanya dapat dilakukan oleh Owner sesuai kebijakan bisnis.',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchBar(BuildContext context, BusinessState bizState) {
    final isConsolidated = bizState.isConsolidated;
    final branchName = isConsolidated
        ? 'Semua Cabang (Konsolidasi)'
        : (bizState.resolvedBranchName.isNotEmpty
            ? formatReportBranchName(bizState.resolvedBranchName)
            : 'Pilih Cabang');
    final isCentral = !isConsolidated && bizState.isCentralBranch;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(
              isConsolidated
                  ? Icons.hub_outlined
                  : (isCentral
                        ? Icons.store_outlined
                        : Icons.storefront_outlined),
              size: 16,
              color: const Color(0xFF0F172A),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Cabang: ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  children: [
                    TextSpan(
                      text: branchName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (isCentral)
                      const TextSpan(
                        text: ' (Pusat)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.info,
                        ),
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
                    Text(
                      'Ganti',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.info,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 16,
                      color: AppColors.info,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnifiedBody({
    required BuildContext context,
    required BusinessState bizState,
    required String? statusFilter,
    required int? categoryFilter,
    required AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    required AsyncValue<List<Map<String, dynamic>>> assetsAsync,
    required AsyncValue<List<Map<String, dynamic>>> productsAsync,
  }) {
    final bool isInitialLoading =
        (assetsAsync.isLoading && !assetsAsync.hasValue) &&
        (productsAsync.isLoading && !productsAsync.hasValue);
    if (isInitialLoading) {
      return const PhysicalUnitsTabSkeleton(count: 5);
    }

    final products = productsAsync.value ?? const <Map<String, dynamic>>[];
    final rawAssets = assetsAsync.value ?? const <Map<String, dynamic>>[];

    if (assetsAsync.hasError &&
        products.isEmpty &&
        rawAssets.isEmpty &&
        !assetsAsync.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.danger,
              ),
              const SizedBox(height: 12),
              Text(
                'Gagal memuat inventaris: ${assetsAsync.error}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF475569)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _refreshAll,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final deduplicatedAssets = _deduplicateAssets([
      ...rawAssets,
      ..._extraAssets,
    ]);
    final allGroups = _buildModelAssetGroups(products, deduplicatedAssets);
    final hasAnySearchOrFilter =
        _searchQuery.trim().isNotEmpty ||
        statusFilter != null ||
        categoryFilter != null;

    if (allGroups.isEmpty && !hasAnySearchOrFilter) {
      return _buildInventoryOnboardingEmptyState(
        context: context,
        hasModels: false,
        canRegisterUnits: bizState.canRegisterUnits,
        onCreateModel: () => _openAddProductSheet(context),
        onRefresh: () async => _refreshAll(),
      );
    }

    final filteredGroups = _filterModelAssetGroups(
      allGroups,
      searchQuery: _searchQuery,
      statusFilter: statusFilter,
      categoryFilter: categoryFilter,
    );

    final categories = _resolveCategories(categoriesAsync, allGroups);

    return Column(
      children: [
        _buildSearchAndFilterBar(
          hasActiveFilter: statusFilter != null || categoryFilter != null,
          categoriesAsync: categoriesAsync,
          categoryFilter: categoryFilter,
          statusFilter: statusFilter,
        ),
        if (categories.isNotEmpty)
          _buildCategoryQuickFilterStrip(categories, categoryFilter),
        Expanded(
          child: _buildGroupsContent(
            context: context,
            bizState: bizState,
            filteredGroups: filteredGroups,
            hasSearch: _searchQuery.trim().isNotEmpty,
            hasFilter: statusFilter != null || categoryFilter != null,
            hasActiveStatusOrSearch:
                _searchQuery.trim().isNotEmpty || statusFilter != null,
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _deduplicateAssets(
    List<Map<String, dynamic>> source,
  ) {
    final seenIds = <dynamic>{};
    final result = <Map<String, dynamic>>[];
    for (final asset in source) {
      final id = asset['id'];
      if (id == null || seenIds.add(id)) {
        result.add(asset);
      }
    }
    return result;
  }

  List<_ModelAssetGroup> _buildModelAssetGroups(
    List<Map<String, dynamic>> products,
    List<Map<String, dynamic>> assets,
  ) {
    final Map<String, Map<String, dynamic>> modelByKey = {};
    final Map<String, List<Map<String, dynamic>>> unitsByKey = {};
    final List<String> orderedKeys = [];

    String keyForModelId(dynamic id, [String? fallbackName]) {
      if (id != null) return 'model_$id';
      return 'orphan_${(fallbackName ?? 'item').trim().toLowerCase()}';
    }

    final sortedAssets = sortAssetsNewestFirst(assets);
    for (final asset in sortedAssets) {
      final rawModel = asset['model'];
      final embeddedModel = rawModel is Map
          ? Map<String, dynamic>.from(rawModel)
          : null;
      final modelId = asset['model_id'] ?? embeddedModel?['id'];
      final key = keyForModelId(
        modelId,
        embeddedModel?['name']?.toString() ?? asset['asset_code']?.toString(),
      );

      if (!modelByKey.containsKey(key)) {
        orderedKeys.add(key);
        modelByKey[key] = embeddedModel ??
            <String, dynamic>{
              'id': modelId,
              'name': asset['model_name']?.toString() ?? 'Model Perangkat',
            };
      }
      unitsByKey.putIfAbsent(key, () => []).add(asset);
    }

    for (final product in products) {
      final key = keyForModelId(product['id'], product['name']?.toString());
      if (!modelByKey.containsKey(key)) {
        orderedKeys.add(key);
      }
      modelByKey[key] = Map<String, dynamic>.from(product);
      unitsByKey.putIfAbsent(key, () => []);
    }

    return orderedKeys.map((key) {
      final model = modelByKey[key]!;
      final units = unitsByKey[key] ?? const <Map<String, dynamic>>[];
      final computedReady = units
          .where((u) => (u['status']?.toString().toLowerCase() ?? '') == 'ready')
          .length;
      final rawTotal =
          num.tryParse('${model['assets_count'] ?? ''}')?.toInt();
      final rawReady =
          num.tryParse('${model['ready_units_count'] ?? ''}')?.toInt();

      final totalCount = units.isNotEmpty
          ? (rawTotal != null && rawTotal >= units.length
                ? rawTotal
                : units.length)
          : (rawTotal ?? 0);
      final readyCount = units.isNotEmpty
          ? (rawTotal != null && rawTotal >= units.length && rawReady != null
                ? rawReady
                : computedReady)
          : (rawReady ?? 0);

      return _ModelAssetGroup(
        groupKey: key,
        model: model,
        allUnits: units,
        visibleUnits: units,
        readyCount: readyCount,
        totalCount: totalCount,
      );
    }).toList();
  }

  List<_ModelAssetGroup> _filterModelAssetGroups(
    List<_ModelAssetGroup> groups, {
    required String searchQuery,
    required String? statusFilter,
    required int? categoryFilter,
  }) {
    final q = searchQuery.trim().toLowerCase();

    return groups.map((group) {
      final model = group.model;
      final rawCat = model['category'];
      final catId = rawCat is Map
          ? int.tryParse('${rawCat['id'] ?? ''}')
          : int.tryParse('${model['category_id'] ?? ''}');

      final matchesCategory = categoryFilter == null ||
          catId == categoryFilter ||
          group.allUnits.any((u) {
            final uModel = u['model'];
            final uCat = uModel is Map ? uModel['category'] : null;
            final uCatId = uCat is Map ? int.tryParse('${uCat['id'] ?? ''}') : null;
            return uCatId == categoryFilter;
          });
      if (!matchesCategory) return null;

      final bool modelMatchesQuery = q.isEmpty || _modelMatchesQuery(model, q);

      final List<Map<String, dynamic>> filteredUnits = group.allUnits.where((u) {
        if (statusFilter != null &&
            (u['status']?.toString().toLowerCase() ?? '') !=
                statusFilter.toLowerCase()) {
          return false;
        }
        if (q.isNotEmpty && !modelMatchesQuery && !_unitMatchesQuery(u, q)) {
          return false;
        }
        return true;
      }).toList();

      if (statusFilter != null && filteredUnits.isEmpty) {
        return null;
      }
      if (q.isNotEmpty && !modelMatchesQuery && filteredUnits.isEmpty) {
        return null;
      }

      return _ModelAssetGroup(
        groupKey: group.groupKey,
        model: group.model,
        allUnits: group.allUnits,
        visibleUnits: filteredUnits,
        readyCount: group.readyCount,
        totalCount: group.totalCount,
      );
    }).whereType<_ModelAssetGroup>().toList();
  }

  bool _modelMatchesQuery(Map<String, dynamic> model, String q) {
    final rawCat = model['category'];
    final catName = rawCat is Map ? (rawCat['name']?.toString() ?? '') : '';
    final fields = [
      model['name']?.toString() ?? '',
      model['brand']?.toString() ?? '',
      catName,
      model['color']?.toString() ?? '',
      model['storage_capacity']?.toString() ?? '',
    ];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  bool _unitMatchesQuery(Map<String, dynamic> unit, String q) {
    final rawAff = unit['affiliate'] ?? unit['branch'];
    final branchName = rawAff is Map ? (rawAff['name']?.toString() ?? '') : '';
    final fields = [
      unit['asset_code']?.toString() ?? '',
      unit['serial_number']?.toString() ?? '',
      unit['imei_1']?.toString() ?? '',
      unit['notes']?.toString() ?? '',
      unit['status']?.toString() ?? '',
      branchName,
    ];
    return fields.any((f) => f.toLowerCase().contains(q));
  }

  List<Map<String, dynamic>> _resolveCategories(
    AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    List<_ModelAssetGroup> groups,
  ) {
    final fromProvider = categoriesAsync.value;
    if (fromProvider != null && fromProvider.isNotEmpty) {
      return fromProvider;
    }
    final seen = <int>{};
    final derived = <Map<String, dynamic>>[];
    for (final group in groups) {
      final rawCat = group.model['category'];
      if (rawCat is Map) {
        final id = int.tryParse('${rawCat['id'] ?? ''}');
        final name = rawCat['name']?.toString().trim() ?? '';
        if (id != null && name.isNotEmpty && seen.add(id)) {
          derived.add({'id': id, 'name': name});
        }
      }
    }
    return derived;
  }

  Widget _buildSearchAndFilterBar({
    required bool hasActiveFilter,
    required AsyncValue<List<Map<String, dynamic>>> categoriesAsync,
    required int? categoryFilter,
    required String? statusFilter,
  }) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                key: const Key('inventory_unified_search_field'),
                controller: _searchController,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  hintText: 'Cari model, kode unit, atau serial number...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(
                            Icons.clear_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
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
                      width: 1.4,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildFilterButton(
            hasActiveFilter: hasActiveFilter,
            onTap: () => _openFilterModal(context),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton({
    required bool hasActiveFilter,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('inventory_filter_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasActiveFilter
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: hasActiveFilter
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF475569),
              ),
              if (hasActiveFilter)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    key: const Key('inventory_filter_active_dot'),
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryQuickFilterStrip(
    List<Map<String, dynamic>> categories,
    int? activeCategoryId,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _buildQuickCategoryPill(
              label: 'Semua',
              selected: activeCategoryId == null,
              onTap: () => ref
                  .read(selectedAssetCategoryFilterProvider.notifier)
                  .setFilter(null),
            ),
            ...categories.map((cat) {
              final catId = int.tryParse('${cat['id'] ?? ''}');
              final catName = cat['name']?.toString() ?? '';
              if (catId == null || catName.isEmpty) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _buildQuickCategoryPill(
                  label: catName,
                  selected: activeCategoryId == catId,
                  onTap: () => ref
                      .read(selectedAssetCategoryFilterProvider.notifier)
                      .setFilter(activeCategoryId == catId ? null : catId),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCategoryPill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? Colors.white : const Color(0xFF475569),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGroupsContent({
    required BuildContext context,
    required BusinessState bizState,
    required List<_ModelAssetGroup> filteredGroups,
    required bool hasSearch,
    required bool hasFilter,
    required bool hasActiveStatusOrSearch,
  }) {
    if (filteredGroups.isEmpty) {
      if (hasSearch) {
        return _buildSearchEmptyState();
      }
      if (hasFilter) {
        return _buildFilterEmptyState();
      }
    }

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 96),
        itemCount: filteredGroups.length + (_isLoadingMoreAssets ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= filteredGroups.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          return _buildUnifiedModelCard(
            context,
            bizState,
            filteredGroups[index],
            forceExpandAll: hasActiveStatusOrSearch,
          );
        },
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 26,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Aset Ditemukan',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tidak ada model atau unit fisik yang cocok dengan pencarian "$_searchQuery".',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text(
                  'Reset Pencarian',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onPressed: _clearSearch,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterEmptyState() {
    return RefreshIndicator(
      onRefresh: () async => _refreshAll(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
        children: [
          Center(
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Icon(
                Icons.filter_alt_off_outlined,
                size: 26,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tidak Ada Aset Sesuai Filter',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 17,
              color: Color(0xFF0F172A),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Tidak ditemukan model atau unit inventaris dengan status atau kategori yang dipilih.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 13,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              height: 44,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.clear_rounded, size: 16),
                label: const Text(
                  'Reset Semua Filter',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                ),
                onPressed: _resetAllFilters,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // UNIFIED MODEL + PHYSICAL UNITS CARD
  // ==========================================
  Widget _buildUnifiedModelCard(
    BuildContext context,
    BusinessState bizState,
    _ModelAssetGroup group, {
    required bool forceExpandAll,
  }) {
    final product = group.model;
    final name = product['name']?.toString() ?? '-';
    final imageUrl = _extractModelImageUrl(product);
    final rawTiers = product['pricing_tiers'] ?? product['pricingTiers'];
    final tiers = rawTiers is List
        ? rawTiers
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : <Map<String, dynamic>>[];

    final dailyRateText = _extractModelPrimaryRate(product, tiersOverride: tiers);
    final metadataText = _buildModelMetadata(product);
    final modelId = int.tryParse(product['id']?.toString() ?? '');

    final visibleUnits = group.visibleUnits;
    final bool isExpanded =
        forceExpandAll || _expandedModelKeys.contains(group.groupKey);
    final bool hasCollapseToggle = !forceExpandAll && visibleUnits.length > 4;
    final displayedUnits = (!isExpanded && hasCollapseToggle)
        ? visibleUnits.take(4).toList()
        : visibleUnits;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Model Header + Action Row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildModelThumbnailWidget(name, imageUrl, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: Color(0xFF0F172A),
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (dailyRateText != null) ...[
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    dailyRateText,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (metadataText.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              metadataText,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          _buildStockPill(group.readyCount, group.totalCount),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 34,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                          ),
                          onPressed: () =>
                              _openEditProductSheet(context, product),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Edit Tarif',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (bizState.canRegisterUnits) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 34,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F172A),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            onPressed: () => _openAddAssetSheet(
                              context,
                              initialModelId: modelId,
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '+ Tambah Unit',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Hairline Divider + Bottom Physical Units Section
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          if (displayedUnits.isEmpty)
            Container(
              color: const Color(0xFFF8FAFC),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Belum ada unit fisik terdaftar',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (bizState.canRegisterUnits)
                    InkWell(
                      onTap: () =>
                          _openAddAssetSheet(context, initialModelId: modelId),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          '+ Tambah Unit',
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
            )
          else ...[
            for (var i = 0; i < displayedUnits.length; i++) ...[
              if (i > 0)
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),
              _buildPhysicalUnitRow(context, bizState, displayedUnits[i]),
            ],
            if (hasCollapseToggle) ...[
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              InkWell(
                key: Key('inventory_expand_units_${group.groupKey}'),
                onTap: () => setState(() {
                  if (isExpanded) {
                    _expandedModelKeys.remove(group.groupKey);
                  } else {
                    _expandedModelKeys.add(group.groupKey);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 11,
                  ),
                  child: Text(
                    isExpanded
                        ? 'Tampilkan lebih sedikit'
                        : 'Lihat semua (${visibleUnits.length} unit)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildPhysicalUnitRow(
    BuildContext context,
    BusinessState bizState,
    Map<String, dynamic> unit,
  ) {
    final assetCode = unit['asset_code']?.toString() ?? '-';
    final rawSn = unit['serial_number']?.toString().trim() ?? '';
    final grade = unit['condition_grade']?.toString().trim() ?? '';
    final battery = unit['battery_health'] != null
        ? int.tryParse(unit['battery_health'].toString())
        : null;
    final status = unit['status']?.toString() ?? 'ready';
    final rawAff = unit['affiliate'] ?? unit['branch'];
    final rawBranch =
        rawAff is Map ? (rawAff['name']?.toString().trim() ?? '') : '';
    final bizBranches =
        (bizState.currentBusiness?['branches'] as List<dynamic>?) ?? const [];
    final showBranch = bizState.isConsolidated || bizBranches.length > 1;
    final formattedBranch = (showBranch && rawBranch.isNotEmpty)
        ? formatReportBranchName(rawBranch)
        : '';

    final specParts = <String>[
      if (rawSn.isNotEmpty) 'SN: $rawSn',
      if (grade.isNotEmpty) 'Grade $grade',
      if (battery != null && battery > 0) 'BH $battery%',
      if (formattedBranch.isNotEmpty) formattedBranch,
    ];

    final isPendingApproval = status.toLowerCase() == 'pending_approval';
    final showOwnerApprovalActions =
        isPendingApproval && bizState.isCurrentUserOwner;

    return InkWell(
      onTap: () => _openEditAssetSheet(context, unit),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        assetCode,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (specParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          specParts.join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusPill(status),
                const SizedBox(width: 4),
                Tooltip(
                  message: 'Edit Unit',
                  child: InkWell(
                    key: Key('edit_unit_btn_${unit['id']}'),
                    onTap: () => _openEditAssetSheet(context, unit),
                    borderRadius: BorderRadius.circular(8),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.edit_outlined,
                        size: 17,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
                Tooltip(
                  message: 'Hapus Unit',
                  child: InkWell(
                    key: Key('delete_unit_btn_${unit['id']}'),
                    onTap: () => _confirmDeleteFromCard(context, unit),
                    borderRadius: BorderRadius.circular(8),
                    child: const SizedBox(
                      width: 32,
                      height: 32,
                      child: Icon(
                        Icons.delete_outline_rounded,
                        size: 17,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (showOwnerApprovalActions) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    height: 32,
                    child: ElevatedButton(
                      key: Key('approve_unit_btn_${unit['id']}'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _approvePendingUnit(context, unit),
                      child: const Text(
                        'Setujui',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 32,
                    child: OutlinedButton(
                      key: Key('reject_unit_btn_${unit['id']}'),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(
                          color: Color(0xFFE2E8F0),
                          width: 1,
                        ),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () => _rejectPendingUnit(context, unit),
                      child: const Text(
                        'Tolak',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approvePendingUnit(
    BuildContext context,
    Map<String, dynamic> unit,
  ) async {
    final unitId = (unit['id'] as num?)?.toInt();
    if (unitId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(assetRepositoryProvider).approveAsset(unitId);
      _refreshAll();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unit baru disetujui dan kini berstatus Siap Sewa.'),
          backgroundColor: Color(0xFF0F172A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.extractErrorMessage(
              e,
              fallback: 'Gagal menyetujui unit baru.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _rejectPendingUnit(
    BuildContext context,
    Map<String, dynamic> unit,
  ) async {
    final unitId = (unit['id'] as num?)?.toInt();
    if (unitId == null) return;
    final assetCode = unit['asset_code']?.toString() ?? '-';
    var reasonDraft = '';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Tolak Pengajuan Unit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tolak pengajuan pendaftaran unit "$assetCode"?',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF475569),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const Key('reject_unit_reason_field'),
              onChanged: (val) => reasonDraft = val,
              maxLines: 2,
              decoration: _airyAssetInputDecoration(
                hintText: 'Alasan penolakan (opsional)...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ),
          ElevatedButton(
            key: const Key('confirm_reject_unit_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Tolak Unit'),
          ),
        ],
      ),
    );

    final reason = reasonDraft.trim();
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(assetRepositoryProvider).rejectAsset(
        unitId,
        reason: reason.isNotEmpty ? reason : null,
      );
      _refreshAll();
      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengajuan unit berhasil ditolak.'),
          backgroundColor: Color(0xFF0F172A),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ApiClient.extractErrorMessage(
              e,
              fallback: 'Gagal menolak pengajuan unit.',
            ),
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _toTitleCase(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _buildModelMetadata(Map<String, dynamic> model) {
    final rawCat = model['category'];
    final category = rawCat is Map ? Map<String, dynamic>.from(rawCat) : null;
    final catName = category?['name']?.toString().trim() ?? '';
    final brand = model['brand']?.toString().trim() ?? '';
    final color = _toTitleCase(model['color']?.toString() ?? '');
    final formattedSpec = _formatSpecification(
      model['storage_capacity']?.toString() ?? '',
    );

    final colorSpecParts = <String>[
      if (color.isNotEmpty) color,
      if (formattedSpec.isNotEmpty) formattedSpec,
    ];
    final colorSpec = colorSpecParts.join(' / ');

    final segments = <String>[];
    final seen = <String>{};
    void addUnique(String value) {
      final cleaned = value.trim();
      if (cleaned.isEmpty) return;
      if (seen.add(cleaned.toLowerCase())) {
        segments.add(cleaned);
      }
    }

    addUnique(brand);
    if (catName.isNotEmpty) {
      addUnique(catName);
    } else if (brand.isEmpty) {
      addUnique('Gadget');
    }
    addUnique(colorSpec);

    return segments.join(' • ');
  }

  String _formatSpecification(String raw) {
    var s = raw.trim();
    if (s.isEmpty) return '';

    if (RegExp(r'mah\s*gb$', caseSensitive: false).hasMatch(s)) {
      s = s.replaceAll(RegExp(r'gb$', caseSensitive: false), '').trim();
    }

    final mahMatch = RegExp(
      r'^(\d+)\s*mah$',
      caseSensitive: false,
    ).firstMatch(s);
    if (mahMatch != null) {
      final numVal = int.tryParse(mahMatch.group(1)!) ?? 0;
      final formattedNum = numVal >= 1000
          ? numVal.toString().replaceAllMapped(
              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
              (m) => '${m[1]}.',
            )
          : numVal.toString();
      return '$formattedNum mAh';
    }

    final tbMatch = RegExp(r'^(\d+)\s*tb$', caseSensitive: false).firstMatch(s);
    if (tbMatch != null) {
      return '${tbMatch.group(1)} TB';
    }

    final gbMatch = RegExp(r'^(\d+)\s*gb$', caseSensitive: false).firstMatch(s);
    if (gbMatch != null) {
      return '${gbMatch.group(1)} GB';
    }

    final numOnly = int.tryParse(s);
    if (numOnly != null) {
      if (numOnly >= 1000) {
        final formattedNum = numOnly.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
        return '$formattedNum mAh';
      } else {
        return '$numOnly GB';
      }
    }

    return _toTitleCase(s);
  }

  Widget _buildStockPill(int readyCount, int totalCount) {
    final hasReady = readyCount > 0;
    final bgColor = hasReady ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9);
    final textColor =
        hasReady ? const Color(0xFF047857) : const Color(0xFF64748B);
    final text = '$readyCount Siap Sewa • $totalCount Total';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: textColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _buildStatusPill(String status) {
    final (String label, Color bg, Color text, Color? borderColor) =
        switch (status.toLowerCase()) {
      'ready' || 'siap sewa' => (
        'Siap Sewa',
        const Color(0xFFECFDF5),
        const Color(0xFF047857),
        null,
      ),
      'pending_approval' || 'menunggu persetujuan' => (
        'Menunggu Persetujuan',
        const Color(0xFFFFFBEB),
        const Color(0xFFB45309),
        const Color(0xFFFDE68A),
      ),
      'rejected' || 'ditolak' => (
        'Ditolak',
        const Color(0xFFFEF2F2),
        const Color(0xFFDC2626),
        const Color(0xFFFECACA),
      ),
      'rented' || 'sedang sewa' => (
        'Sedang Sewa',
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
        null,
      ),
      'maintenance' || 'perawatan' => (
        'Perawatan',
        const Color(0xFFFFFBEB),
        const Color(0xFFB45309),
        null,
      ),
      'in_transit' || 'dalam mutasi' => (
        'Dalam Mutasi',
        const Color(0xFFFAF5FF),
        const Color(0xFF7E22CE),
        null,
      ),
      _ => (
        status,
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
        null,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
        border: borderColor != null
            ? Border.all(color: borderColor, width: 1)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  void _openFilterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _FilterAsetBottomSheet(),
    );
  }

  Widget _buildNoBusinessView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.storefront_outlined,
              size: 48,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Bisnis Rental',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan pilih atau daftarkan bisnis rental Anda untuk mengelola inventaris.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => BusinessSelectorSheet.show(context),
              child: const Text('Pilih Bisnis Rental'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAddProductSheet(BuildContext context) async {
    final createdProduct = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (ctx) => AddProductSheet(onSuccess: _refreshAll),
    );

    if (createdProduct != null && context.mounted) {
      _showChainedUnitRegistrationPrompt(context, createdProduct);
    }
  }

  void _showChainedUnitRegistrationPrompt(
    BuildContext context,
    Map<String, dynamic> model,
  ) {
    final modelId = (model['id'] as num?)?.toInt();
    InventoryScreen.showModelCreatedBottomSheet(
      context,
      model: model,
      onRegisterUnit: () {
        _openAddAssetSheet(context, initialModelId: modelId);
      },
    );
  }

  Widget _buildInventoryOnboardingEmptyState({
    required BuildContext context,
    bool hasModels = false,
    bool canRegisterUnits = true,
    required VoidCallback onCreateModel,
    VoidCallback? onRegisterUnit,
    required Future<void> Function() onRefresh,
  }) {
    final bool canRegisterUnit = hasModels && onRegisterUnit != null;
    final String primaryLabel =
        canRegisterUnit ? '+ Tambah Unit Fisik' : '+ Buat Model Pertama';
    final VoidCallback primaryAction =
        canRegisterUnit ? onRegisterUnit : onCreateModel;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              size: 24,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Belum Ada Inventaris',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Buat model katalog terlebih dahulu sebelum mendaftarkan unit fisik.',
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: 26,
                                      child: Column(
                                        children: [
                                          Container(
                                            width: 26,
                                            height: 26,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0F172A),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            alignment: Alignment.center,
                                            child: const Text(
                                              '1',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Expanded(
                                            child: Center(
                                              child: Container(
                                                width: 1.5,
                                                color: const Color(0xFFE2E8F0),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.only(bottom: 16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Model & Tarif',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            SizedBox(height: 3),
                                            Text(
                                              'Tipe barang dan harga sewa (mis. iPhone 13, PS5).',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                color: Color(0xFF64748B),
                                                height: 1.4,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: const Color(0xFFE2E8F0),
                                        width: 1,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: const Text(
                                      '2',
                                      style: TextStyle(
                                        color: Color(0xFF475569),
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Unit Fisik',
                                          key: Key(
                                            'inventory_empty_step_2_title',
                                          ),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        SizedBox(height: 3),
                                        Text(
                                          'Stok nyata siap sewa lengkap dengan nomor seri / barcode.',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: Color(0xFF64748B),
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (canRegisterUnits)
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton(
                              key: const Key('inventory_empty_primary_cta'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              onPressed: primaryAction,
                              child: Text(
                                primaryLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          )
                        else
                          Container(
                            key: const Key('inventory_owner_only_notice'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.lock_outline_rounded,
                                  size: 16,
                                  color: Color(0xFF64748B),
                                ),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pendaftaran model dan unit baru hanya dapat dilakukan oleh Owner.',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: Color(0xFF64748B),
                                      height: 1.4,
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
              ),
            ),
          );
        },
      ),
    );
  }

  void _openEditProductSheet(
    BuildContext context,
    Map<String, dynamic> product,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
      ),
      builder: (ctx) =>
          AddProductSheet(initialProduct: product, onSuccess: _refreshAll),
    );
  }

  void _openAddAssetSheet(BuildContext context, {int? initialModelId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AddAssetSheet(
        initialModelId: initialModelId,
        onSuccess: _refreshAll,
      ),
    );
  }

  void _openEditAssetSheet(BuildContext context, Map<String, dynamic> asset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditAssetSheet(asset: asset, onSuccess: _refreshAll),
    );
  }

  void _confirmDeleteFromCard(
    BuildContext context,
    Map<String, dynamic> asset,
  ) {
    final assetCode = asset['asset_code']?.toString() ?? '-';
    final assetId = asset['id'] as int;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Hapus Unit Inventaris',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus unit "$assetCode"?\n\n'
          'Unit yang belum pernah disewa akan dihapus permanen. Unit dengan riwayat sewa akan otomatis diarsipkan (status Retired) demi menjaga integritas data akuntansi.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              final messenger = ScaffoldMessenger.of(context);

              try {
                final repo = ref.read(assetRepositoryProvider);
                final res = await repo.deleteAsset(assetId);
                _refreshAll();
                final msg =
                    res['message']?.toString() ??
                    'Unit inventaris berhasil diproses.';
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.obsidian,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal menghapus unit: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// SHARED MODEL DISPLAY HELPERS
// ==========================================
String? _extractModelImageUrl(Map<String, dynamic>? model) {
  if (model == null) return null;
  return (model['image_url'] ??
          model['image'] ??
          model['photo_url'] ??
          model['thumbnail'])
      ?.toString();
}

String? _extractModelPrimaryRate(
  Map<String, dynamic> model, {
  List<Map<String, dynamic>>? tiersOverride,
}) {
  final rawTiers = tiersOverride ?? model['pricing_tiers'] ?? model['pricingTiers'];
  final tiers = rawTiers is List
      ? rawTiers.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];

  if (tiers.isNotEmpty) {
    final day1Tier = tiers.firstWhere(
      (t) {
        final unit = t['duration_unit']?.toString().toLowerCase();
        final val = t['duration_value']?.toString();
        return unit == 'day' && (val == '1' || val == null);
      },
      orElse: () => tiers.firstWhere(
        (t) => t['duration_unit']?.toString().toLowerCase() == 'day',
        orElse: () => tiers.first,
      ),
    );

    final priceVal = day1Tier['price'];
    if (priceVal != null) {
      final priceNum = num.tryParse(priceVal.toString()) ?? 0;
      final unitStr = day1Tier['duration_unit']?.toString().toLowerCase();
      final valStr = day1Tier['duration_value']?.toString() ?? '1';
      final suffix = switch (unitStr) {
        'day' => valStr == '1' ? '/ hari' : '/ $valStr hari',
        'hour' => valStr == '1' ? '/ jam' : '/ $valStr jam',
        'week' => valStr == '1' ? '/ minggu' : '/ $valStr minggu',
        'month' => valStr == '1' ? '/ bulan' : '/ $valStr bulan',
        _ => '/ hari',
      };
      return '${CurrencyFormatter.format(priceNum)} $suffix';
    }
  }

  final dailyRate =
      model['daily_rate'] ?? model['price'] ?? model['rental_price'];
  if (dailyRate != null) {
    final priceNum = num.tryParse(dailyRate.toString()) ?? 0;
    if (priceNum > 0) {
      return '${CurrencyFormatter.format(priceNum)} / hari';
    }
  }

  return null;
}

Widget _buildModelThumbnailWidget(
  String name,
  String? imageUrl, {
  double size = 44,
}) {
  Widget fallback() {
    final initial = name.trim().isNotEmpty
        ? name.trim().substring(0, 1).toUpperCase()
        : 'P';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: AppColors.obsidian,
          fontWeight: FontWeight.w800,
          fontSize: size * 0.4,
        ),
      ),
    );
  }

  if (imageUrl != null && imageUrl.trim().isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => fallback(),
      ),
    );
  }
  return fallback();
}

// ==========================================
// ADAPTIVE FIELD HELPERS
// ==========================================
bool _checkImeiRelevant(
  Map<String, dynamic>? model,
  List<String> bizCategories,
) {
  if (model != null) {
    if (model['requires_frp_check'] == true) return true;
    final cat = model['category'];
    final catSlug = (cat is Map ? cat['slug']?.toString() ?? '' : '')
        .toLowerCase();
    final catName = (cat is Map ? cat['name']?.toString() ?? '' : '')
        .toLowerCase();
    final modelName = (model['name']?.toString() ?? '').toLowerCase();
    if (catSlug.contains('phone') ||
        catSlug.contains('cellular') ||
        catSlug.contains('hp') ||
        catName.contains('phone') ||
        catName.contains('hp') ||
        catName.contains('ponsel') ||
        catName.contains('smartphone') ||
        modelName.contains('iphone') ||
        modelName.contains('galaxy') ||
        modelName.contains('pixel')) {
      return true;
    }
    if (catSlug.contains('tenda') ||
        catSlug.contains('kursi') ||
        catSlug.contains('meja') ||
        catSlug.contains('mobil') ||
        catSlug.contains('motor') ||
        catSlug.contains('perkakas') ||
        catSlug.contains('alat') ||
        catSlug.contains('kamera') ||
        catSlug.contains('drone')) {
      return false;
    }
  }
  return bizCategories.isEmpty ||
      bizCategories.contains('electronics') ||
      bizCategories.contains('other');
}

bool _checkBatteryRelevant(
  Map<String, dynamic>? model,
  List<String> bizCategories,
) {
  if (model != null) {
    final cat = model['category'];
    final catSlug = (cat is Map ? cat['slug']?.toString() ?? '' : '')
        .toLowerCase();
    final catName = (cat is Map ? cat['name']?.toString() ?? '' : '')
        .toLowerCase();
    final combined = '$catSlug $catName ${(model['name'] ?? '')}'.toLowerCase();
    if (combined.contains('tenda') ||
        combined.contains('kursi') ||
        combined.contains('meja') ||
        combined.contains('panggung') ||
        combined.contains('dekor') ||
        combined.contains('kostum') ||
        combined.contains('mobil') ||
        combined.contains('motor') ||
        combined.contains('sepeda') ||
        combined.contains('kabel') ||
        combined.contains('tripod') ||
        combined.contains('stand')) {
      return false;
    }
    if (combined.contains('phone') ||
        combined.contains('kamera') ||
        combined.contains('camera') ||
        combined.contains('drone') ||
        combined.contains('laptop') ||
        combined.contains('tablet') ||
        combined.contains('gadget') ||
        combined.contains('audio') ||
        combined.contains('speaker') ||
        combined.contains('gimbal')) {
      return true;
    }
  }
  if (bizCategories.isNotEmpty) {
    final hasElectronic =
        bizCategories.contains('electronics') ||
        bizCategories.contains('cameras') ||
        bizCategories.contains('other');
    if (!hasElectronic) return false;
  }
  return true;
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
  final _batteryHealthController = TextEditingController();
  final _hourlyLateFeeController = TextEditingController();
  final _notesController = TextEditingController();
  String _grade = 'A';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedModelId = widget.initialModelId;
    _assetCodeController.text =
        'AST-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
  }

  @override
  void dispose() {
    _assetCodeController.dispose();
    _serialNumberController.dispose();
    _imei1Controller.dispose();
    _batteryHealthController.dispose();
    _hourlyLateFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modelsAsync = ref.watch(allCatalogModelsProvider);
    final bizState = ref.watch(businessProvider);
    final models = modelsAsync.asData?.value ?? [];
    final selectedModel = models
        .where((m) => m['id'] == _selectedModelId)
        .firstOrNull;
    final bool hasSerial =
        selectedModel == null || selectedModel['has_serial_number'] != false;
    final bizCategories = bizState.activeBusinessCategories;
    final isImeiApplicable =
        _checkImeiRelevant(selectedModel, bizCategories) ||
        _imei1Controller.text.trim().isNotEmpty;
    final isBatteryApplicable =
        _checkBatteryRelevant(selectedModel, bizCategories) ||
        _batteryHealthController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
        left: 20,
        right: 20,
        top: 10,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAiryModalHeader(
                context,
                title: 'Registrasi Unit Baru',
              ),
              const SizedBox(height: 16),
              // Searchable Model Selector
              const Text(
                'Model / Tipe Perangkat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              modelsAsync.when(
                data: (models) {
                  return FormField<int>(
                    key: ValueKey(_selectedModelId),
                    initialValue: _selectedModelId,
                    validator: (val) =>
                        val == null ? 'Pilih tipe model terlebih dahulu' : null,
                    builder: (field) {
                      final hasSelection = selectedModel != null;
                      final modelTitle =
                          selectedModel?['name']?.toString() ?? '-';
                      final modelBrand =
                          selectedModel?['brand']?.toString().trim() ?? '';
                      final rawCat = selectedModel?['category'];
                      final modelCategory = rawCat is Map
                          ? (rawCat['name']?.toString().trim() ?? '')
                          : '';
                      final modelRate = hasSelection
                          ? _extractModelPrimaryRate(selectedModel)
                          : null;
                      final modelImage = _extractModelImageUrl(selectedModel);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            key: const Key('register_unit_model_selector'),
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              final pickedId =
                                  await showModalBottomSheet<int>(
                                context: context,
                                isScrollControlled: true,
                                useSafeArea: true,
                                backgroundColor: Colors.white,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                ),
                                builder: (ctx) => _ModelPickerBottomSheet(
                                  models: models,
                                  selectedModelId: _selectedModelId,
                                  canCreateModel: bizState.canRegisterUnits,
                                  onModelCreated: () {
                                    ref.invalidate(allCatalogModelsProvider);
                                    widget.onSuccess();
                                  },
                                ),
                              );
                              if (pickedId != null && mounted) {
                                setState(() => _selectedModelId = pickedId);
                                field.didChange(pickedId);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: field.hasError
                                      ? AppColors.danger
                                      : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (hasSelection) ...[
                                    _buildModelThumbnailWidget(
                                      modelTitle,
                                      modelImage,
                                      size: 40,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            modelTitle,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                              color: Color(0xFF0F172A),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            [
                                              if (modelBrand.isNotEmpty)
                                                modelBrand,
                                              if (modelCategory.isNotEmpty)
                                                modelCategory,
                                              ?modelRate,
                                            ].join(' • '),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B),
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else
                                    const Expanded(
                                      child: Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        child: Text(
                                          'Pilih atau cari model perangkat...',
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: Color(0xFF94A3B8),
                                          ),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.search_rounded,
                                    size: 18,
                                    color: Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 2),
                                  const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 20,
                                    color: Color(0xFF64748B),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (field.hasError) ...[
                            const SizedBox(height: 6),
                            Padding(
                              padding: const EdgeInsets.only(left: 12),
                              child: Text(
                                field.errorText!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text(
                  'Gagal memuat model: $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              const SizedBox(height: 14),
              // Asset Code
              const Text(
                'Kode Unit / Barcode',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _assetCodeController,
                decoration: _airyAssetInputDecoration(),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Kode unit wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              // Serial Number (Adaptive)
              Text(
                hasSerial ? 'Serial Number *' : 'Serial Number (Opsional)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serialNumberController,
                decoration: _airyAssetInputDecoration(
                  hintText: hasSerial
                      ? 'Nomor seri pabrik (SN)'
                      : 'Kosongkan jika barang tanpa SN fisik',
                ),
                validator: hasSerial
                    ? (val) => (val == null || val.trim().isEmpty)
                          ? 'Serial number wajib diisi'
                          : null
                    : null,
              ),
              // IMEI 1 (Adaptive)
              if (isImeiApplicable) ...[
                const SizedBox(height: 14),
                const Text(
                  'IMEI 1 (Opsional untuk Smartphone)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _imei1Controller,
                  decoration: _airyAssetInputDecoration(hintText: '15 digit IMEI'),
                ),
              ],
              const SizedBox(height: 14),
              // Grade & Battery (Adaptive)
              if (isBatteryApplicable) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kondisi Fisik',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _grade,
                            isExpanded: true,
                            decoration: _airyAssetInputDecoration(),
                            items: ['A', 'B', 'C']
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      'Grade $g',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _grade = val ?? 'A'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Battery Health (%)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _batteryHealthController,
                            keyboardType: TextInputType.number,
                            decoration: _airyAssetInputDecoration(hintText: 'Misal: 100'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kondisi Fisik',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _grade,
                      decoration: _airyAssetInputDecoration(),
                      items: ['A', 'B', 'C']
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text('Grade $g'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _grade = val ?? 'A'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              // Denda / Jam (Opsional - inherits model/business)
              Builder(
                builder: (context) {
                  final modelRate = double.tryParse(
                    selectedModel?['hourly_late_fee']?.toString() ?? '',
                  );
                  final bizDefaultRate = double.tryParse(
                    bizState.activeBusiness?['default_hourly_late_fee']
                            ?.toString() ??
                        '',
                  );
                  final inheritedRate = modelRate ?? bizDefaultRate ?? 0.0;
                  final helper = modelRate != null
                      ? 'Kosongkan untuk mengikuti tarif model: ${CurrencyFormatter.format(modelRate)}/jam'
                      : (bizDefaultRate != null && bizDefaultRate > 0
                            ? 'Kosongkan untuk mengikuti tarif default toko: ${CurrencyFormatter.format(bizDefaultRate)}/jam'
                            : 'Kosongkan untuk mengikuti tarif default model/toko');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Denda / Jam (Opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('add_unit_hourly_late_fee_input'),
                        controller: _hourlyLateFeeController,
                        keyboardType: TextInputType.number,
                        decoration: _airyAssetInputDecoration(
                          prefixText: 'Rp ',
                          hintText: inheritedRate > 0
                              ? inheritedRate.toInt().toString()
                              : 'Otomatis sesuai model',
                          helperText: helper,
                          helperMaxLines: 2,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              // Notes
              const Text(
                'Catatan Tambahan',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _airyAssetInputDecoration(
                  hintText: 'Kondisi fisik, kelengkapan, nomor segel...',
                ),
              ),
              const SizedBox(height: 20),
              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                            final sn = _serialNumberController.text.trim();
                            final imei = _imei1Controller.text.trim();
                            final bh = _batteryHealthController.text.trim();

                            final rawHourlyLateFee =
                                _hourlyLateFeeController.text.trim();
                            final double? parsedHourlyLateFee =
                                rawHourlyLateFee.isNotEmpty
                                ? CurrencyFormatter.parse(rawHourlyLateFee)
                                : null;

                            final payload = <String, dynamic>{
                              'model_id': _selectedModelId,
                              'asset_code': _assetCodeController.text.trim(),
                              if (sn.isNotEmpty) 'serial_number': sn,
                              if (imei.isNotEmpty) 'imei_1': imei,
                              'status': 'ready',
                              'condition_grade': _grade,
                              if (bh.isNotEmpty)
                                'battery_health': int.tryParse(bh),
                              'hourly_late_fee': ?parsedHourlyLateFee,
                              if (_notesController.text.trim().isNotEmpty)
                                'notes': _notesController.text.trim(),
                              if (bizState.activeBranchId != null)
                                'affiliate_id': bizState.activeBranchId,
                            };

                            final created = await repo.createAsset(payload);
                            final isPending = created['status']
                                    ?.toString()
                                    .toLowerCase() ==
                                'pending_approval';
                            ref.invalidate(dashboardKpiProvider);
                            nav.pop();
                            widget.onSuccess();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  isPending
                                      ? 'Unit berhasil diajukan dan menunggu persetujuan Owner.'
                                      : 'Unit inventaris berhasil didaftarkan!',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    ApiClient.extractErrorMessage(
                                      e,
                                      fallback: 'Gagal mendaftar unit.',
                                    ),
                                  ),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan & Daftarkan Unit',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
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
// KEYBOARD-SAFE SEARCHABLE MODEL PICKER SHEET
// ==========================================
class _ModelPickerBottomSheet extends StatefulWidget {
  final List<Map<String, dynamic>> models;
  final int? selectedModelId;
  final bool canCreateModel;
  final VoidCallback onModelCreated;

  const _ModelPickerBottomSheet({
    required this.models,
    this.selectedModelId,
    this.canCreateModel = true,
    required this.onModelCreated,
  });

  @override
  State<_ModelPickerBottomSheet> createState() =>
      _ModelPickerBottomSheetState();
}

class _ModelPickerBottomSheetState extends State<_ModelPickerBottomSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openCreateModelSheet() async {
    final created = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => AddProductSheet(onSuccess: widget.onModelCreated),
    );
    if (!mounted) return;
    final newId = (created?['id'] as num?)?.toInt();
    if (newId != null) {
      Navigator.pop(context, newId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filteredModels = q.isEmpty
        ? widget.models
        : widget.models.where((m) {
            final name = (m['name']?.toString() ?? '').toLowerCase();
            final brand = (m['brand']?.toString() ?? '').toLowerCase();
            final rawCat = m['category'];
            final category = rawCat is Map
                ? (rawCat['name']?.toString() ?? '').toLowerCase()
                : (m['category_name']?.toString() ?? '').toLowerCase();
            return name.contains(q) ||
                brand.contains(q) ||
                category.contains(q);
          }).toList();

    final sheetHeight = MediaQuery.sizeOf(context).height * 0.85;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Pinned Top Drag Handle
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Pinned Top Title & Close Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Model Perangkat',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  key: const Key('model_picker_close_button'),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Pinned Search Field (Never Covered by Keyboard)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: SizedBox(
              height: 44,
              child: TextField(
                key: const Key('model_picker_search_field'),
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF0F172A),
                ),
                onChanged: (val) => setState(() => _query = val),
                decoration: InputDecoration(
                  hintText: 'Cari nama model, merek, atau kategori...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF64748B),
                  ),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          key: const Key('model_picker_search_clear'),
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: Color(0xFF64748B),
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
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
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          // Keyboard-Inset-Aware Scrollable Results List
          Expanded(
            child: filteredModels.isEmpty
                ? SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      28,
                      20,
                      keyboardInset + 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.search_off_rounded,
                          size: 36,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _query.trim().isNotEmpty
                              ? 'Model "${_query.trim()}" tidak ditemukan.'
                              : 'Belum ada model katalog tersedia.',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    key: const Key('model_picker_results_list'),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      8,
                      20,
                      keyboardInset + 24,
                    ),
                    itemCount: filteredModels.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    itemBuilder: (context, index) {
                      final m = filteredModels[index];
                      final id = (m['id'] as num?)?.toInt();
                      final name = m['name']?.toString() ?? '-';
                      final brand = m['brand']?.toString().trim() ?? '';
                      final rawCat = m['category'];
                      final category = rawCat is Map
                          ? (rawCat['name']?.toString().trim() ?? '')
                          : (m['category_name']?.toString().trim() ?? '');
                      final imageUrl = _extractModelImageUrl(m);
                      final primaryRate = _extractModelPrimaryRate(m);
                      final isSelected =
                          id != null && id == widget.selectedModelId;

                      final subtitleParts = <String>[
                        if (brand.isNotEmpty) brand,
                        if (category.isNotEmpty) category,
                        if (primaryRate != null && primaryRate.isNotEmpty)
                          primaryRate,
                      ];

                      return InkWell(
                        key: Key('model_picker_row_${id ?? index}'),
                        onTap: id == null
                            ? null
                            : () => Navigator.pop(context, id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFF8FAFC)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              _buildModelThumbnailWidget(
                                name,
                                imageUrl,
                                size: 40,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14.5,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    if (subtitleParts.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitleParts.join(' • '),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF64748B),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected) ...[
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.check_rounded,
                                  size: 20,
                                  color: Color(0xFF0F172A),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (widget.canCreateModel && keyboardInset == 0)
            SafeArea(
              top: false,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: OutlinedButton(
                  key: const Key('model_picker_add_new_button'),
                  onPressed: _openCreateModelSheet,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1.2,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    '+ Tambah Model Baru',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ),
            ),
        ],
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
  late final TextEditingController _hourlyLateFeeController;
  late final TextEditingController _notesController;
  late String _status;
  late String _grade;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _assetCodeController = TextEditingController(
      text: widget.asset['asset_code']?.toString() ?? '',
    );
    _serialNumberController = TextEditingController(
      text: widget.asset['serial_number']?.toString() ?? '',
    );
    _imei1Controller = TextEditingController(
      text: widget.asset['imei_1']?.toString() ?? '',
    );
    _batteryHealthController = TextEditingController(
      text: widget.asset['battery_health']?.toString() ?? '',
    );
    final rawLateFee = widget.asset['hourly_late_fee'];
    final parsedLateFee = rawLateFee != null
        ? double.tryParse(rawLateFee.toString())
        : null;
    _hourlyLateFeeController = TextEditingController(
      text: parsedLateFee != null ? parsedLateFee.toInt().toString() : '',
    );
    _notesController = TextEditingController(
      text: widget.asset['notes']?.toString() ?? '',
    );
    _status = widget.asset['status']?.toString() ?? 'ready';
    _grade = widget.asset['condition_grade']?.toString() ?? 'A';
  }

  @override
  void dispose() {
    _assetCodeController.dispose();
    _serialNumberController.dispose();
    _imei1Controller.dispose();
    _batteryHealthController.dispose();
    _hourlyLateFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rawModel = widget.asset['model'];
    final model = rawModel is Map ? Map<String, dynamic>.from(rawModel) : null;
    final modelName = model?['name']?.toString() ?? 'Item Rental';
    final isLocked = _status != 'ready' && _status != 'maintenance';
    final bool hasSerial = model == null || model['has_serial_number'] != false;
    final bizState = ref.watch(businessProvider);
    final bizCategories = bizState.activeBusinessCategories;
    final isImeiApplicable =
        _checkImeiRelevant(model, bizCategories) ||
        _imei1Controller.text.trim().isNotEmpty;
    final isBatteryApplicable =
        _checkBatteryRelevant(model, bizCategories) ||
        _batteryHealthController.text.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 10,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAiryModalHeader(
                context,
                title: 'Edit Unit Inventaris',
                subtitle: modelName,
              ),
              const SizedBox(height: 16),
              // Status Dropdown
              const Text(
                'Status Operasional Unit',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: _airyAssetInputDecoration(),
                items: [
                  const DropdownMenuItem(
                    value: 'ready',
                    child: Text('Siap Sewa (Ready)'),
                  ),
                  const DropdownMenuItem(
                    value: 'rented',
                    child: Text('Sedang Sewa (Rented)'),
                  ),
                  const DropdownMenuItem(
                    value: 'maintenance',
                    child: Text('Dalam Perawatan (Maintenance)'),
                  ),
                  const DropdownMenuItem(
                    value: 'in_transit',
                    child: Text('Dalam Mutasi / Transfer'),
                  ),
                  if (![
                    'ready',
                    'rented',
                    'maintenance',
                    'in_transit',
                  ].contains(_status))
                    DropdownMenuItem(
                      value: _status,
                      child: Text('$_status (Terkunci)'),
                    ),
                ],
                onChanged: isLocked
                    ? null
                    : (val) => setState(() => _status = val ?? 'ready'),
              ),
              if (_status == 'rented') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 20,
                        color: AppColors.warning,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Sedang Disewa (Terkunci)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unit sedang aktif disewa pelanggan. Status operasional tidak dapat diubah manual.',
                              style: TextStyle(
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
              ] else if (_status == 'in_transit') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.4),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.local_shipping_outlined,
                        size: 20,
                        color: AppColors.info,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Dalam Mutasi (Terkunci)',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Unit sedang dalam perjalanan mutasi antar cabang. Status operasional tidak dapat diubah manual.',
                              style: TextStyle(
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
              ],
              const SizedBox(height: 14),
              // Kode Unit
              const Text(
                'Kode Unit',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _assetCodeController,
                decoration: _airyAssetInputDecoration(),
                validator: (val) => (val == null || val.trim().isEmpty)
                    ? 'Kode unit wajib diisi'
                    : null,
              ),
              const SizedBox(height: 14),
              // Serial Number (Adaptive)
              Text(
                hasSerial ? 'Serial Number *' : 'Serial Number (Opsional)',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _serialNumberController,
                decoration: _airyAssetInputDecoration(
                  hintText: hasSerial
                      ? 'Nomor seri pabrik (SN)'
                      : 'Kosongkan jika barang tanpa SN fisik',
                ),
                validator: hasSerial
                    ? (val) => (val == null || val.trim().isEmpty)
                          ? 'Serial number wajib diisi'
                          : null
                    : null,
              ),
              // IMEI 1 (Adaptive)
              if (isImeiApplicable) ...[
                const SizedBox(height: 14),
                const Text(
                  'IMEI 1',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _imei1Controller,
                  decoration: _airyAssetInputDecoration(),
                ),
              ],
              const SizedBox(height: 14),
              // Grade & Battery (Adaptive)
              if (isBatteryApplicable) ...[
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kondisi Fisik',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          DropdownButtonFormField<String>(
                            initialValue: _grade,
                            isExpanded: true,
                            decoration: _airyAssetInputDecoration(),
                            items: ['A', 'B', 'C']
                                .map(
                                  (g) => DropdownMenuItem(
                                    value: g,
                                    child: Text(
                                      'Grade $g',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _grade = val ?? 'A'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Battery Health (%)',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _batteryHealthController,
                            keyboardType: TextInputType.number,
                            decoration: _airyAssetInputDecoration(hintText: 'Misal: 100'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kondisi Fisik',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _grade,
                      decoration: _airyAssetInputDecoration(),
                      items: ['A', 'B', 'C']
                          .map(
                            (g) => DropdownMenuItem(
                              value: g,
                              child: Text('Grade $g'),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _grade = val ?? 'A'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),
              // Denda / Jam (Opsional - inherits model/business)
              Builder(
                builder: (context) {
                  final modelRate = double.tryParse(
                    model?['hourly_late_fee']?.toString() ?? '',
                  );
                  final bizDefaultRate = double.tryParse(
                    bizState.activeBusiness?['default_hourly_late_fee']
                            ?.toString() ??
                        '',
                  );
                  final inheritedRate = modelRate ?? bizDefaultRate ?? 0.0;
                  final helper = modelRate != null
                      ? 'Kosongkan untuk mengikuti tarif model: ${CurrencyFormatter.format(modelRate)}/jam'
                      : (bizDefaultRate != null && bizDefaultRate > 0
                            ? 'Kosongkan untuk mengikuti tarif default toko: ${CurrencyFormatter.format(bizDefaultRate)}/jam'
                            : 'Kosongkan untuk mengikuti tarif default model/toko');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Denda / Jam (Opsional)',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('edit_unit_hourly_late_fee_input'),
                        controller: _hourlyLateFeeController,
                        keyboardType: TextInputType.number,
                        decoration: _airyAssetInputDecoration(
                          prefixText: 'Rp ',
                          hintText: inheritedRate > 0
                              ? inheritedRate.toInt().toString()
                              : 'Otomatis sesuai model',
                          helperText: helper,
                          helperMaxLines: 2,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              // Notes
              const Text(
                'Catatan Perangkat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF0F172A)),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: _airyAssetInputDecoration(),
              ),
              const SizedBox(height: 20),
              // Save Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                            final sn = _serialNumberController.text.trim();
                            final imei = _imei1Controller.text.trim();
                            final bh = _batteryHealthController.text.trim();

                            final rawHourlyLateFee =
                                _hourlyLateFeeController.text.trim();
                            final double? parsedHourlyLateFee =
                                rawHourlyLateFee.isNotEmpty
                                ? CurrencyFormatter.parse(rawHourlyLateFee)
                                : null;

                            final payload = <String, dynamic>{
                              'asset_code': _assetCodeController.text.trim(),
                              'serial_number': sn.isNotEmpty ? sn : null,
                              'imei_1': imei.isNotEmpty ? imei : null,
                              if (!isLocked) 'status': _status,
                              'condition_grade': _grade,
                              'battery_health': bh.isNotEmpty
                                  ? int.tryParse(bh)
                                  : null,
                              'hourly_late_fee': parsedHourlyLateFee,
                              'notes': _notesController.text.trim(),
                            };

                            await repo.updateAsset(assetId, payload);
                            nav.pop();
                            widget.onSuccess();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Perubahan data unit berhasil disimpan!',
                                ),
                              ),
                            );
                          } catch (e) {
                            if (mounted) {
                              setState(() => _isLoading = false);
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Gagal menyimpan: $e'),
                                  backgroundColor: AppColors.danger,
                                ),
                              );
                            }
                          }
                        },
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Simpan Perubahan',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text(
                    'Hapus / Arsipkan Unit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  onPressed: _isLoading ? null : () => _confirmDelete(context),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final assetCode = widget.asset['asset_code']?.toString() ?? '-';
    final assetId = widget.asset['id'] as int;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 24,
            ),
            SizedBox(width: 8),
            Text(
              'Hapus Unit Inventaris',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus unit "$assetCode"?\n\n'
          'Unit yang belum pernah disewa akan dihapus permanen. Unit dengan riwayat sewa akan otomatis diarsipkan (status Retired) demi menjaga integritas data akuntansi.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogCtx);
              setState(() => _isLoading = true);
              final messenger = ScaffoldMessenger.of(context);
              final nav = Navigator.of(context);

              try {
                final repo = ref.read(assetRepositoryProvider);
                final res = await repo.deleteAsset(assetId);
                nav.pop();
                widget.onSuccess();
                final msg =
                    res['message']?.toString() ??
                    'Unit inventaris berhasil diproses.';
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: AppColors.obsidian,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  setState(() => _isLoading = false);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Gagal menghapus unit: $e'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );
  }
}

class _ModelAssetGroup {
  final String groupKey;
  final Map<String, dynamic> model;
  final List<Map<String, dynamic>> allUnits;
  final List<Map<String, dynamic>> visibleUnits;
  final int readyCount;
  final int totalCount;

  const _ModelAssetGroup({
    required this.groupKey,
    required this.model,
    required this.allUnits,
    required this.visibleUnits,
    required this.readyCount,
    required this.totalCount,
  });
}

// ==========================================
// AIRY MODAL SHARED HELPERS & FILTER SHEET
// ==========================================
Widget _buildAiryModalHeader(
  BuildContext context, {
  required String title,
  String? subtitle,
  Widget? trailingAction,
  Key? closeKey,
}) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFCBD5E1),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
      Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.3,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailingAction != null) ...[
            trailingAction,
            const SizedBox(width: 8),
          ],
          InkWell(
            key: closeKey,
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    ],
  );
}

InputDecoration _airyAssetInputDecoration({
  String? hintText,
  String? prefixText,
  String? helperText,
  int? helperMaxLines,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF94A3B8)),
    prefixText: prefixText,
    helperText: helperText,
    helperMaxLines: helperMaxLines,
    helperStyle: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
    ),
  );
}

class _FilterAsetBottomSheet extends ConsumerWidget {
  const _FilterAsetBottomSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusFilter = ref.watch(selectedAssetStatusFilterProvider);
    final categoryFilter = ref.watch(selectedAssetCategoryFilterProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final hasActiveFilter = statusFilter != null || categoryFilter != null;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
              child: _buildAiryModalHeader(
                context,
                title: 'Filter Aset',
                trailingAction: hasActiveFilter
                    ? TextButton(
                        key: const Key('inventory_filter_reset_text_button'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        onPressed: () {
                          ref
                              .read(selectedAssetCategoryFilterProvider.notifier)
                              .setFilter(null);
                          ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter(null);
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      )
                    : null,
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status Unit',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildPill(
                          selected: statusFilter == null,
                          label: 'Semua Status',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter(null),
                        ),
                        _buildPill(
                          selected: statusFilter == 'ready',
                          label: 'Siap Sewa',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter('ready'),
                        ),
                        _buildPill(
                          selected: statusFilter == 'rented',
                          label: 'Sedang Sewa',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter('rented'),
                        ),
                        _buildPill(
                          selected: statusFilter == 'maintenance',
                          label: 'Perawatan',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter('maintenance'),
                        ),
                        _buildPill(
                          selected: statusFilter == 'in_transit',
                          label: 'Dalam Mutasi',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter('in_transit'),
                        ),
                        _buildPill(
                          selected: statusFilter == 'pending_approval',
                          label: 'Menunggu Persetujuan',
                          onTap: () => ref
                              .read(selectedAssetStatusFilterProvider.notifier)
                              .setFilter('pending_approval'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Kategori',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    categoriesAsync.when(
                      data: (categories) => Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildPill(
                            selected: categoryFilter == null,
                            label: 'Semua Kategori',
                            onTap: () => ref
                                .read(
                                  selectedAssetCategoryFilterProvider.notifier,
                                )
                                .setFilter(null),
                          ),
                          ...categories.map((cat) {
                            final catId = cat['id'] as int?;
                            final catName = cat['name']?.toString() ?? '';
                            return _buildPill(
                              selected: categoryFilter == catId,
                              label: catName,
                              onTap: () => ref
                                  .read(
                                    selectedAssetCategoryFilterProvider.notifier,
                                  )
                                  .setFilter(catId),
                            );
                          }),
                        ],
                      ),
                      loading: () => const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, _) => const Text(
                        'Gagal memuat kategori',
                        style: TextStyle(fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                ),
              ),
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Terapkan Filter',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPill({
    required bool selected,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF475569),
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }
}

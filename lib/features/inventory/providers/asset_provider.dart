import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/asset_repository.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository();
});

/// Sorts physical assets by newest created first (`created_at DESC`, fallback `id DESC`).
List<Map<String, dynamic>> sortAssetsNewestFirst(List<Map<String, dynamic>> items) {
  final sorted = List<Map<String, dynamic>>.from(items);
  sorted.sort((a, b) {
    final aCreated = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final bCreated = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (aCreated != null && bCreated != null) {
      final cmp = bCreated.compareTo(aCreated);
      if (cmp != 0) return cmp;
    } else if (bCreated != null) {
      return 1;
    } else if (aCreated != null) {
      return -1;
    }
    final aId = int.tryParse(a['id']?.toString() ?? '') ?? 0;
    final bId = int.tryParse(b['id']?.toString() ?? '') ?? 0;
    return bId.compareTo(aId);
  });
  return sorted;
}

class AssetStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() {
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    return null;
  }

  void setFilter(String? status) {
    state = status;
  }
}

final selectedAssetStatusFilterProvider = NotifierProvider<AssetStatusFilterNotifier, String?>(
  AssetStatusFilterNotifier.new,
);

class AssetCategoryFilterNotifier extends Notifier<int?> {
  @override
  int? build() {
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    return null;
  }

  void setFilter(int? categoryId) {
    state = categoryId;
  }
}

final selectedAssetCategoryFilterProvider = NotifierProvider<AssetCategoryFilterNotifier, int?>(
  AssetCategoryFilterNotifier.new,
);

class AssetSearchQueryNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    return '';
  }

  void setSearch(String query) {
    state = query;
  }
}

final assetSearchQueryProvider = NotifierProvider<AssetSearchQueryNotifier, String>(
  AssetSearchQueryNotifier.new,
);

class CatalogSearchQueryNotifier extends Notifier<String> {
  @override
  String build() {
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    return '';
  }

  void setSearch(String query) {
    state = query;
  }
}

final catalogSearchQueryProvider = NotifierProvider<CatalogSearchQueryNotifier, String>(
  CatalogSearchQueryNotifier.new,
);

final categoriesProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null) {
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  return repo.fetchCategories();
});

final productsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null) {
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  final search = ref.watch(catalogSearchQueryProvider);

  return repo.fetchProducts(
    categoryId: categoryId,
    search: search.isEmpty ? null : search,
  );
});

final inventoryListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null) {
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  final status = ref.watch(selectedAssetStatusFilterProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  final search = ref.watch(assetSearchQueryProvider);

  try {
    final list = await repo.fetchAssets(
      status: status,
      categoryId: categoryId,
      search: search.isEmpty ? null : search,
      branchId: bizState.activeBranchId,
      allBranches: bizState.isConsolidated,
    );
    final seenIds = <dynamic>{};
    final deduped = list.where((item) {
      final id = item['id'];
      return id == null || seenIds.add(id);
    }).toList();
    return sortAssetsNewestFirst(deduped);
  } catch (e) {
    rethrow;
  }
});

class PhysicalUnitsState {
  final List<Map<String, dynamic>> units;
  final bool isLoading;
  final String? error;

  const PhysicalUnitsState({
    this.units = const [],
    this.isLoading = false,
    this.error,
  });

  PhysicalUnitsState copyWith({
    List<Map<String, dynamic>>? units,
    bool? isLoading,
    String? error,
  }) {
    return PhysicalUnitsState(
      units: units ?? this.units,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class PhysicalUnitsNotifier extends Notifier<PhysicalUnitsState> {
  @override
  PhysicalUnitsState build() {
    return const PhysicalUnitsState();
  }

  Future<void> loadUnits({
    String? status,
    int? categoryId,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(assetRepositoryProvider);
      final fetchedUnits = await repo.fetchAssets(
        status: status,
        categoryId: categoryId,
        search: search,
        branchId: branchId,
        allBranches: allBranches,
      );

      final seenIds = <dynamic>{};
      final uniqueUnits = fetchedUnits.where((u) {
        final id = u['id'];
        return id == null || seenIds.add(id);
      }).toList();

      // State is replaced rather than appending ([...state.units, ...fetchedUnits])
      state = state.copyWith(
        units: sortAssetsNewestFirst(uniqueUnits),
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void reset() {
    state = const PhysicalUnitsState();
  }
}

final physicalUnitsProvider =
    NotifierProvider<PhysicalUnitsNotifier, PhysicalUnitsState>(
  PhysicalUnitsNotifier.new,
);

final catalogModelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null) {
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  return repo.fetchModels(categoryId: categoryId);
});

final allCatalogModelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null) {
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  return repo.fetchModels();
});


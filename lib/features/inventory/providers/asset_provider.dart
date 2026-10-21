import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/asset_repository.dart';

final assetRepositoryProvider = Provider<AssetRepository>((ref) {
  return AssetRepository();
});

class AssetStatusFilterNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setFilter(String? status) {
    state = status;
  }
}

final selectedAssetStatusFilterProvider = NotifierProvider<AssetStatusFilterNotifier, String?>(
  AssetStatusFilterNotifier.new,
);

class AssetCategoryFilterNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setFilter(int? categoryId) {
    state = categoryId;
  }
}

final selectedAssetCategoryFilterProvider = NotifierProvider<AssetCategoryFilterNotifier, int?>(
  AssetCategoryFilterNotifier.new,
);

class AssetSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setSearch(String query) {
    state = query;
  }
}

final assetSearchQueryProvider = NotifierProvider<AssetSearchQueryNotifier, String>(
  AssetSearchQueryNotifier.new,
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
  final search = ref.watch(assetSearchQueryProvider);

  return repo.fetchProducts(
    categoryId: categoryId,
    search: search.isEmpty ? null : search,
  );
});

final inventoryListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final bizState = ref.watch(businessProvider);
  print('>>> [INVENTORY_PROVIDER] bizState: activeBusinessId=${bizState.activeBusinessId}, activeBranchId=${bizState.activeBranchId}, isConsolidated=${bizState.isConsolidated}');
  if (bizState.activeBusinessId == null) {
    print('>>> [INVENTORY_PROVIDER] activeBusinessId is null, returning []');
    return [];
  }
  final repo = ref.watch(assetRepositoryProvider);
  final status = ref.watch(selectedAssetStatusFilterProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  final search = ref.watch(assetSearchQueryProvider);

  print('>>> [INVENTORY_PROVIDER] calling repo.fetchAssets with status=$status, cat=$categoryId, search=$search, branch=${bizState.activeBranchId}');
  try {
    final list = await repo.fetchAssets(
      status: status,
      categoryId: categoryId,
      search: search.isEmpty ? null : search,
      branchId: bizState.activeBranchId,
      allBranches: bizState.isConsolidated,
    );
    print('>>> [INVENTORY_PROVIDER] fetchAssets returned ${list.length} items');
    return list;
  } catch (e, st) {
    print('>>> [INVENTORY_PROVIDER] fetchAssets error: $e\n$st');
    rethrow;
  }
});

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


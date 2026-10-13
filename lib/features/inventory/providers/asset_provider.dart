import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final repo = ref.watch(assetRepositoryProvider);
  return repo.fetchCategories();
});

final productsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(assetRepositoryProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  final search = ref.watch(assetSearchQueryProvider);

  return repo.fetchProducts(
    categoryId: categoryId,
    search: search.isEmpty ? null : search,
  );
});

final inventoryListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(assetRepositoryProvider);
  final status = ref.watch(selectedAssetStatusFilterProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  final search = ref.watch(assetSearchQueryProvider);

  return repo.fetchAssets(
    status: status,
    categoryId: categoryId,
    search: search.isEmpty ? null : search,
  );
});

final catalogModelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(assetRepositoryProvider);
  final categoryId = ref.watch(selectedAssetCategoryFilterProvider);
  return repo.fetchModels(categoryId: categoryId);
});

final allCatalogModelsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(assetRepositoryProvider);
  return repo.fetchModels();
});


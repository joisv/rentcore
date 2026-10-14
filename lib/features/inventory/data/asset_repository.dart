import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class AssetRepository {
  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) queryParams['status'] = status;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (branchId != null) queryParams['branch_id'] = branchId;

    final response = await _client.dio.get(
      ApiConstants.assets,
      queryParameters: queryParams,
    );
    final data = response.data['data']['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async {
    final queryParams = <String, dynamic>{};
    if (categoryId != null) queryParams['category_id'] = categoryId;

    final response = await _client.dio.get(
      ApiConstants.assetModels,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final response = await _client.dio.get(
      ApiConstants.categories,
      queryParameters: {'all': true},
    );
    final data = response.data['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async {
    final queryParams = <String, dynamic>{'all': true};
    if (categoryId != null) queryParams['category_id'] = categoryId;
    if (search != null && search.isNotEmpty) queryParams['search'] = search;

    final response = await _client.dio.get(
      ApiConstants.products,
      queryParameters: queryParams,
    );
    final data = response.data['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> calculatePrice({
    required int modelId,
    required String durationUnit,
    required int durationValue,
    String? startAt,
  }) async {
    final payload = <String, dynamic>{
      'model_id': modelId,
      'duration_unit': durationUnit,
      'duration_value': durationValue,
    };
    if (startAt != null) payload['start_at'] = startAt;

    final response = await _client.dio.post(
      ApiConstants.calculatePrice,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> checkAssetAvailability({
    required int assetId,
    required String startAt,
    required String endAt,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.assetAvailability(assetId),
      queryParameters: {
        'start_at': startAt,
        'end_at': endAt,
      },
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.assets,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> updateAsset(int id, Map<String, dynamic> payload) async {
    final response = await _client.dio.put(
      ApiConstants.updateAsset(id),
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.categories,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.products,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> updateProductRates(
    int productId,
    List<Map<String, dynamic>> rates,
  ) async {
    final response = await _client.dio.put(
      ApiConstants.productRates(productId),
      data: {'rates': rates},
    );
    return response.data['data'];
  }
}

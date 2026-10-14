import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class DashboardRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    final queryParams = <String, dynamic>{};
    if (branchId != null) {
      queryParams['branch_id'] = branchId;
    }
    final response = await _client.dio.get(
      ApiConstants.dashboardKpi,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return response.data['data'];
  }
}

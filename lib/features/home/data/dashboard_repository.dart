import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class DashboardRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchKpi() async {
    final response = await _client.dio.get(ApiConstants.dashboardKpi);
    return response.data['data'];
  }
}

import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class DashboardRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    final queryParams = <String, dynamic>{};
    final headers = <String, dynamic>{};

    if (branchId != null) {
      queryParams['branch_id'] = branchId;
      headers['X-Branch-Id'] = branchId.toString();
    } else {
      queryParams['all_branches'] = '1';
      headers['X-Branch-Id'] = '';
    }

    final response = await _client.dio.get(
      ApiConstants.dashboardKpi,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: Options(headers: headers),
    );

    if (response.data != null && response.data['data'] is Map) {
      return Map<String, dynamic>.from(response.data['data'] as Map);
    }
    return <String, dynamic>{};
  }
}

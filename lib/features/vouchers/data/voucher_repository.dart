import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class VoucherRepository {
  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchVouchers({
    String? status,
    String? search,
    dynamic branchId,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (branchId != null) {
      queryParams['branch_id'] = branchId.toString();
    }

    final response = await _client.dio.get(
      ApiConstants.vouchers,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final data = response.data['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> getVoucher(int id) async {
    final response = await _client.dio.get('${ApiConstants.vouchers}/$id');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> createVoucher(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.vouchers,
      data: payload,
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateVoucher(int id, Map<String, dynamic> payload) async {
    final response = await _client.dio.put(
      '${ApiConstants.vouchers}/$id',
      data: payload,
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> toggleVoucherStatus(int id) async {
    final response = await _client.dio.patch('${ApiConstants.vouchers}/$id/toggle-status');
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<void> deleteVoucher(int id) async {
    await _client.dio.delete('${ApiConstants.vouchers}/$id');
  }

  Future<Map<String, dynamic>> validateVoucher(
    String code,
    double subtotal, {
    dynamic branchId,
    int? customerId,
  }) async {
    final payload = <String, dynamic>{
      'code': code,
      'subtotal': subtotal,
    };
    if (branchId != null) {
      payload['branch_id'] = branchId;
    }
    if (customerId != null) {
      payload['customer_id'] = customerId;
    }

    final response = await _client.dio.post(
      ApiConstants.validateVoucher,
      data: payload,
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> fetchPrintSlip(String code) async {
    final response = await _client.dio.get(ApiConstants.printVoucherSlip(code));
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}

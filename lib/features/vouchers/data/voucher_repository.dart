import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class VoucherRepository {
  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchVouchers() async {
    final response = await _client.dio.get(ApiConstants.vouchers);
    final data = response.data['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createVoucher(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.vouchers,
      data: payload,
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> validateVoucher(String code, double subtotal) async {
    final response = await _client.dio.post(
      ApiConstants.validateVoucher,
      data: {
        'code': code,
        'subtotal': subtotal,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }

  Future<Map<String, dynamic>> fetchPrintSlip(String code) async {
    final response = await _client.dio.get(ApiConstants.printVoucherSlip(code));
    return Map<String, dynamic>.from(response.data['data'] as Map);
  }
}

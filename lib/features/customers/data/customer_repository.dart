import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class CustomerRepository {
  final Dio _dio = ApiClient().dio;

  /// Quick lookup customer by phone number or NIK/identity number.
  Future<Map<String, dynamic>?> lookupCustomer(String query) async {
    try {
      final response = await _dio.get(
        ApiConstants.customerLookup,
        queryParameters: {'query': query.trim()},
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      throw Exception(e.error ?? 'Gagal mencari data pelanggan.');
    } catch (e) {
      throw Exception('Gagal mencari data pelanggan: $e');
    }
  }

  /// Search customers list with pagination and optional filter.
  Future<List<Map<String, dynamic>>> searchCustomers({String? query, bool? isBlacklisted}) async {
    try {
      final params = <String, dynamic>{};
      if (query != null && query.isNotEmpty) params['search'] = query;
      if (isBlacklisted != null) params['is_blacklisted'] = isBlacklisted;

      final response = await _dio.get(
        ApiConstants.customers,
        queryParameters: params,
      );

      if (response.data['success'] == true) {
        final list = response.data['data']['data'] as List? ?? [];
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal mengambil daftar pelanggan.');
    } catch (e) {
      throw Exception('Gagal mengambil daftar pelanggan: $e');
    }
  }

  /// Upload identity document photo (base64 or multipart) for an existing customer.
  Future<Map<String, dynamic>> uploadIdentityDocument({
    required int customerId,
    required String photoBase64,
    String identityType = 'KTP',
    String? identityNumber,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.customerIdentityDoc(customerId),
        data: {
          'identity_type': identityType,
          'identity_number': identityNumber,
          'photo': photoBase64,
        },
      );

      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal mengunggah dokumen.');
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal mengunggah dokumen identitas.');
    } catch (e) {
      throw Exception('Gagal mengunggah dokumen: $e');
    }
  }

  /// Toggle customer blacklist status.
  Future<Map<String, dynamic>> toggleBlacklist({
    required int customerId,
    required bool isBlacklisted,
    String? reason,
  }) async {
    try {
      final response = await _dio.put(
        ApiConstants.toggleCustomerBlacklist(customerId),
        data: {
          'is_blacklisted': isBlacklisted,
          'blacklist_reason': reason,
        },
      );

      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memperbarui status blacklist.');
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal memperbarui blacklist.');
    } catch (e) {
      throw Exception('Gagal memperbarui blacklist: $e');
    }
  }
}

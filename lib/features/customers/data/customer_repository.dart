import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/paginated_result.dart';
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
      if (isBlacklisted != null) params['is_blacklisted'] = isBlacklisted ? 1 : 0;

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

  /// Paginated customer retrieval for infinite scrolling directory.
  Future<PaginatedResult<Map<String, dynamic>>> fetchCustomersPaginated({
    int page = 1,
    String? search,
    bool? isBlacklisted,
  }) async {
    try {
      final params = <String, dynamic>{'page': page};
      if (search != null && search.isNotEmpty) params['search'] = search;
      if (isBlacklisted != null) params['is_blacklisted'] = isBlacklisted ? 1 : 0;

      final response = await _dio.get(
        ApiConstants.customers,
        queryParameters: params,
      );

      if (response.data['success'] == true && response.data['data'] != null) {
        final data = response.data['data'];
        final items = (data['data'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();

        return PaginatedResult<Map<String, dynamic>>(
          items: items,
          currentPage: data['current_page'] ?? page,
          lastPage: data['last_page'] ?? page,
          total: data['total'] ?? items.length,
          hasMore: (data['current_page'] ?? page) < (data['last_page'] ?? page),
        );
      }
      return PaginatedResult.empty();
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal mengambil data pelanggan.');
    } catch (e) {
      throw Exception('Gagal mengambil data pelanggan: $e');
    }
  }

  /// Register new customer.
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? identityNumber,
    String? identityType,
    String? identityPhotoBase64,
  }) async {
    try {
      final payload = <String, dynamic>{
        'name': name,
        'phone': phone,
      };
      if (email != null && email.isNotEmpty) payload['email'] = email;
      if (address != null && address.isNotEmpty) payload['address'] = address;
      if (identityNumber != null && identityNumber.isNotEmpty) {
        payload['identity_number'] = identityNumber;
        payload['identity_type'] = identityType ?? 'KTP';
      }
      if (identityPhotoBase64 != null && identityPhotoBase64.isNotEmpty) {
        payload['identity_photo'] = identityPhotoBase64;
      }

      final response = await _dio.post(
        ApiConstants.customers,
        data: payload,
      );

      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal mendaftarkan pelanggan.');
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal mendaftarkan pelanggan.');
    } catch (e) {
      throw Exception('Gagal mendaftarkan pelanggan: $e');
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
    String? managerPin,
  }) async {
    try {
      final payload = <String, dynamic>{
        'is_blacklisted': isBlacklisted,
      };
      if (reason != null && reason.isNotEmpty) payload['blacklist_reason'] = reason;
      if (managerPin != null && managerPin.isNotEmpty) payload['manager_pin'] = managerPin;

      final response = await _dio.put(
        ApiConstants.toggleCustomerBlacklist(customerId),
        data: payload,
      );

      if (response.data['success'] == true) {
        return Map<String, dynamic>.from(response.data['data']);
      }
      throw Exception(response.data['message'] ?? 'Gagal memperbarui status blacklist.');
    } on DioException catch (e) {
      throw Exception(e.error ?? 'Gagal memperbarui status blacklist.');
    } catch (e) {
      throw Exception('Gagal memperbarui status blacklist: $e');
    }
  }
}

import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class BookingRepository {
  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    final queryParams = <String, dynamic>{};
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;
    if (allBranches) {
      queryParams['all_branches'] = '1';
    } else if (branchId != null) {
      queryParams['branch_id'] = branchId.toString();
    }

    final response = await _client.dio.get(
      ApiConstants.bookings,
      queryParameters: queryParams,
    );
    final data = response.data['data']['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    final queryParams = <String, dynamic>{'status': 'ready'};
    if (branchId != null) queryParams['branch_id'] = branchId;

    final response = await _client.dio.get(
      ApiConstants.assets,
      queryParameters: queryParams,
    );
    final data = response.data['data']['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createRental(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.bookings,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> extendRental(int bookingId, int additionalHours, {double? fee}) async {
    final data = <String, dynamic>{
      'additional_hours': additionalHours,
    };
    if (fee != null) data['additional_fee'] = fee;

    final response = await _client.dio.post(
      ApiConstants.extendBooking(bookingId),
      data: data,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> processReturn(int bookingId, Map<String, dynamic> returnData) async {
    final response = await _client.dio.post(
      ApiConstants.returnBooking(bookingId),
      data: returnData,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    final response = await _client.dio.get(ApiConstants.bookingDetail(bookingId));
    return response.data['data'];
  }
}

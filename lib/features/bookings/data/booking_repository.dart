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
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData.whereType<Map<String, dynamic>>().toList();
    }
    if (rawData is Map && rawData['data'] is List) {
      return (rawData['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    final queryParams = <String, dynamic>{'status': 'ready'};
    if (branchId != null) queryParams['branch_id'] = branchId;

    final response = await _client.dio.get(
      ApiConstants.assets,
      queryParameters: queryParams,
    );
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData.whereType<Map<String, dynamic>>().toList();
    }
    if (rawData is Map && rawData['data'] is List) {
      return (rawData['data'] as List).whereType<Map<String, dynamic>>().toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createRental(Map<String, dynamic> payload) async {
    final response = await _client.dio.post(
      ApiConstants.bookings,
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> extendRental(
    int bookingId,
    int additionalHours, {
    double? fee,
    int? paymentMethodId,
    double? cashReceived,
    String? notes,
  }) async {
    final data = <String, dynamic>{
      'additional_hours': additionalHours,
    };
    if (fee != null) data['additional_fee'] = fee;
    if (paymentMethodId != null) data['payment_method_id'] = paymentMethodId;
    if (cashReceived != null) data['cash_received'] = cashReceived;
    if (notes != null) data['notes'] = notes;

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

  Future<Map<String, dynamic>> fetchAvailableReplacements(dynamic bookingId, {dynamic assetId}) async {
    final response = await _client.dio.get(
      ApiConstants.availableReplacements(bookingId, assetId: assetId),
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> exchangeRentalUnit(
    dynamic bookingId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.dio.post(
      ApiConstants.exchangeBooking(bookingId),
      data: payload,
    );
    return response.data as Map<String, dynamic>;
  }
}

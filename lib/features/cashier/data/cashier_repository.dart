import 'package:dio/dio.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class CashierRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    final queryParams = <String, dynamic>{};
    final headers = <String, dynamic>{};

    if (allBranches) {
      queryParams['all_branches'] = 1;
      headers['X-Branch-Id'] = '';
    } else if (branchId != null) {
      queryParams['branch_id'] = branchId;
      headers['X-Branch-Id'] = branchId.toString();
    }

    if (startDate != null && startDate.isNotEmpty && endDate != null && endDate.isNotEmpty) {
      queryParams['start_date'] = startDate;
      queryParams['end_date'] = endDate;
    } else if (date != null && date.isNotEmpty) {
      queryParams['date'] = date;
    }
    final response = await _client.dio.get(
      ApiConstants.closingSummary,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    final response = await _client.dio.get(ApiConstants.paymentMethods);
    final data = response.data['data'];
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int paymentMethodId,
    double? cashReceived,
    double? amount,
    String? paymentType,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'booking_id': bookingId,
      'payment_method_id': paymentMethodId,
    };
    if (cashReceived != null) payload['cash_received'] = cashReceived;
    if (amount != null) payload['amount'] = amount;
    if (paymentType != null) payload['payment_type'] = paymentType;
    if (notes != null) payload['notes'] = notes;

    final response = await _client.dio.post(
      ApiConstants.cashierPay,
      data: payload,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchReceipt(dynamic transactionOrReceiptId) async {
    final response = await _client.dio.get(ApiConstants.cashierReceipt(transactionOrReceiptId));
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    final queryParams = <String, dynamic>{
      'per_page': 25,
    };
    final headers = <String, dynamic>{};

    if (allBranches) {
      queryParams['all_branches'] = 1;
      headers['X-Branch-Id'] = '';
    } else if (branchId != null) {
      queryParams['branch_id'] = branchId;
      headers['X-Branch-Id'] = branchId.toString();
    }
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (paymentStatus != null && paymentStatus.isNotEmpty) {
      queryParams['payment_status'] = paymentStatus;
    }
    final response = await _client.dio.get(
      ApiConstants.bookings,
      queryParameters: queryParams,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    final response = await _client.dio.get('${ApiConstants.bookings}/$bookingId');
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}

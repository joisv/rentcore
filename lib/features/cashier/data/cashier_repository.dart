import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class CashierRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> fetchClosingSummary() async {
    final response = await _client.dio.get(ApiConstants.closingSummary);
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

  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({String? search, String? paymentStatus}) async {
    final response = await _client.dio.get(
      ApiConstants.bookings,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (paymentStatus != null && paymentStatus.isNotEmpty) 'payment_status': paymentStatus,
        'per_page': 25,
      },
    );
    final data = response.data['data'];
    if (data is Map && data['data'] is List) {
      return (data['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }
}

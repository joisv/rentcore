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
    String? idempotencyKey,
  }) async {
    final payload = <String, dynamic>{
      'booking_id': bookingId,
      'payment_method_id': paymentMethodId,
    };
    if (cashReceived != null) payload['cash_received'] = cashReceived;
    if (amount != null) payload['amount'] = amount;
    if (paymentType != null) payload['payment_type'] = paymentType;
    if (notes != null) payload['notes'] = notes;
    if (idempotencyKey != null) payload['idempotency_key'] = idempotencyKey;

    final headers = <String, dynamic>{};
    if (idempotencyKey != null) headers['X-Idempotency-Key'] = idempotencyKey;

    final response = await _client.dio.post(
      ApiConstants.cashierPay,
      data: payload,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> voidTransaction({
    required int transactionId,
    required String reason,
    String? managerPin,
  }) async {
    final payload = <String, dynamic>{
      'reason': reason,
    };
    if (managerPin != null && managerPin.isNotEmpty) {
      payload['manager_pin'] = managerPin;
    }

    final response = await _client.dio.post(
      ApiConstants.voidTransaction(transactionId),
      data: payload,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> voidExpense({
    required int expenseId,
    required String reason,
    String? managerPin,
  }) async {
    final payload = <String, dynamic>{
      'reason': reason,
    };
    if (managerPin != null && managerPin.isNotEmpty) {
      payload['manager_pin'] = managerPin;
    }

    final response = await _client.dio.post(
      ApiConstants.voidExpense(expenseId),
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

  Future<Map<String, dynamic>> fetchExpenses({
    int? branchId,
    bool allBranches = false,
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
    }

    final response = await _client.dio.get(
      ApiConstants.cashierExpenses,
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> createExpense({
    required String title,
    required double amount,
    required String category,
    required String paymentSource,
    int? branchId,
    String? notes,
    String? managerPin,
    String? receiptImageBase64,
  }) async {
    final payload = <String, dynamic>{
      'title': title,
      'amount': amount,
      'category': category,
      'payment_source': paymentSource,
    };
    if (branchId != null) payload['branch_id'] = branchId;
    if (notes != null && notes.isNotEmpty) payload['notes'] = notes;
    if (managerPin != null && managerPin.isNotEmpty) payload['manager_pin'] = managerPin;
    if (receiptImageBase64 != null && receiptImageBase64.isNotEmpty) {
      payload['receipt_image'] = receiptImageBase64;
    }

    final headers = <String, dynamic>{};
    if (branchId != null) headers['X-Branch-Id'] = branchId.toString();

    final response = await _client.dio.post(
      ApiConstants.cashierExpenses,
      data: payload,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    final headers = <String, dynamic>{};
    if (branchId != null) headers['X-Branch-Id'] = branchId.toString();

    final response = await _client.dio.get(
      ApiConstants.currentShift,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> openShift({
    required double openingCashFloat,
    int? branchId,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'opening_cash_float': openingCashFloat,
    };
    if (branchId != null) payload['branch_id'] = branchId;
    if (notes != null) payload['notes'] = notes;

    final headers = <String, dynamic>{};
    if (branchId != null) headers['X-Branch-Id'] = branchId.toString();

    final response = await _client.dio.post(
      ApiConstants.openShift,
      data: payload,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    final payload = <String, dynamic>{
      'actual_cash_counted': actualCashCounted,
    };
    if (shiftId != null) payload['shift_id'] = shiftId;
    if (differenceReason != null && differenceReason.isNotEmpty) {
      payload['difference_reason'] = differenceReason;
    }
    if (closingNotes != null && closingNotes.isNotEmpty) {
      payload['closing_notes'] = closingNotes;
    }

    final headers = <String, dynamic>{};
    if (branchId != null) headers['X-Branch-Id'] = branchId.toString();

    final response = await _client.dio.post(
      ApiConstants.closeShift,
      data: payload,
      options: headers.isNotEmpty ? Options(headers: headers) : null,
    );
    final data = response.data['data'];
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }
}

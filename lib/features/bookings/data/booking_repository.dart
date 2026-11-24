import 'package:dio/dio.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/models/paginated_result.dart';
import '../../../core/network/api_client.dart';

class BookingRepository {
  final ApiClient _client = ApiClient();

  String? _resolveIdempotencyKey(
    String? explicitKey,
    Map<String, dynamic> payload,
  ) {
    final trimmedExplicit = explicitKey?.trim();
    if (trimmedExplicit != null && trimmedExplicit.isNotEmpty) {
      return trimmedExplicit;
    }
    final payloadKey = payload['idempotency_key']?.toString().trim();
    if (payloadKey != null && payloadKey.isNotEmpty) {
      return payloadKey;
    }
    return null;
  }

  Map<String, dynamic> _attachIdempotencyKey(
    Map<String, dynamic> payload,
    String? idempotencyKey,
  ) {
    final key = _resolveIdempotencyKey(idempotencyKey, payload);
    if (key == null) return payload;
    return <String, dynamic>{...payload, 'idempotency_key': key};
  }

  Options? _idempotencyOptions(String? key) {
    if (key == null || key.isEmpty) return null;
    return Options(headers: {'X-Idempotency-Key': key});
  }

  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    final queryParams = <String, dynamic>{
      'per_page': '200',
    };
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

  Future<PaginatedResult<Map<String, dynamic>>> fetchBookingsPaginated({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
    int page = 1,
    int perPage = 15,
  }) async {
    final queryParams = <String, dynamic>{
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null) queryParams['status'] = status;
    if (search != null) queryParams['search'] = search;
    if (allBranches) {
      queryParams['all_branches'] = '1';
    } else if (branchId != null) {
      queryParams['branch_id'] = branchId.toString();
    }

    try {
      final response = await _client.dio.get(
        ApiConstants.bookings,
        queryParameters: queryParams,
      );

      final rawData = response.data['data'];
      if (rawData is Map) {
        final items = (rawData['data'] as List?)
            ?.whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList() ?? [];
        final currentPage = (rawData['current_page'] as num?)?.toInt() ?? page;
        final lastPage = (rawData['last_page'] as num?)?.toInt() ?? 1;
        final total = (rawData['total'] as num?)?.toInt() ?? items.length;
        final actualPerPage = (rawData['per_page'] as num?)?.toInt() ?? perPage;
        return PaginatedResult(
          items: items,
          currentPage: currentPage,
          lastPage: lastPage,
          total: total,
          perPage: actualPerPage,
          hasMore: currentPage < lastPage,
        );
      }
      if (rawData is List) {
        final items = rawData.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        return PaginatedResult(
          items: items,
          currentPage: 1,
          lastPage: 1,
          total: items.length,
          perPage: items.length,
          hasMore: false,
        );
      }
      return PaginatedResult.empty();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    if (branchId == null) {
      return [];
    }
    final queryParams = <String, dynamic>{
      'status': 'ready',
      'branch_id': branchId,
    };

    final response = await _client.dio.get(
      ApiConstants.assets,
      queryParameters: queryParams,
      options: Options(headers: {'X-Branch-Id': branchId.toString()}),
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

  /// Fetch ready physical units enriched with interval-overlap availability
  /// (`is_available_for_window`, `conflict_reason`) for a specific [startAt, endAt) window.
  Future<List<Map<String, dynamic>>> fetchAssetsForWindow({
    required int branchId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.assets,
      queryParameters: {
        'status': 'ready',
        'branch_id': branchId.toString(),
        'start_at': startAt.toUtc().toIso8601String(),
        'end_at': endAt.toUtc().toIso8601String(),
      },
      options: Options(headers: {'X-Branch-Id': branchId.toString()}),
    );
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (rawData is Map && rawData['data'] is List) {
      return (rawData['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    final body = _attachIdempotencyKey(payload, idempotencyKey);
    final effectiveKey = _resolveIdempotencyKey(idempotencyKey, body);
    Options? opts = _idempotencyOptions(effectiveKey);
    final rawBranch = body['branch_id'] ?? body['affiliate_id'];
    if (rawBranch != null && rawBranch.toString().trim().isNotEmpty) {
      opts = (opts ?? Options()).copyWith(
        headers: {
          ...?opts?.headers,
          'X-Branch-Id': rawBranch.toString().trim(),
        },
      );
    }
    final response = await _client.dio.post(
      ApiConstants.bookings,
      data: body,
      options: opts,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> extendRental(
    int bookingId,
    int additionalHours, {
    double? fee,
    int? paymentMethodId,
    String? paymentMethodCode,
    double? cashReceived,
    String? notes,
    String? idempotencyKey,
  }) async {
    final data = <String, dynamic>{
      'additional_hours': additionalHours,
    };
    if (fee != null) data['additional_fee'] = fee;
    if (paymentMethodId != null) data['payment_method_id'] = paymentMethodId;
    if (paymentMethodCode != null && paymentMethodCode.trim().isNotEmpty) {
      data['payment_method'] = paymentMethodCode.trim().toLowerCase();
      data['payment_channel'] = paymentMethodCode.trim().toLowerCase();
    }
    if (cashReceived != null) data['cash_received'] = cashReceived;
    if (notes != null) data['notes'] = notes;
    final body = _attachIdempotencyKey(data, idempotencyKey);
    final effectiveKey = _resolveIdempotencyKey(idempotencyKey, body);

    final response = await _client.dio.post(
      ApiConstants.extendBooking(bookingId),
      data: body,
      options: _idempotencyOptions(effectiveKey),
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> adjustDuration({
    required int bookingId,
    int? bookingItemId,
    required String direction,
    required int hoursDelta,
    double? additionalFee,
    int? paymentMethodId,
    String? paymentMethodCode,
    double? cashReceived,
    String? managerPin,
    String? reason,
    String? notes,
    String? idempotencyKey,
  }) async {
    final data = <String, dynamic>{
      'direction': direction,
      'hours_delta': hoursDelta,
    };
    if (bookingItemId != null) data['booking_item_id'] = bookingItemId;
    if (additionalFee != null) data['additional_fee'] = additionalFee;
    if (paymentMethodId != null) data['payment_method_id'] = paymentMethodId;
    if (paymentMethodCode != null && paymentMethodCode.trim().isNotEmpty) {
      data['payment_method'] = paymentMethodCode.trim().toLowerCase();
      data['payment_channel'] = paymentMethodCode.trim().toLowerCase();
    }
    if (cashReceived != null) data['cash_received'] = cashReceived;
    if (managerPin != null && managerPin.isNotEmpty) data['manager_pin'] = managerPin;
    if (reason != null && reason.isNotEmpty) data['reason'] = reason;
    if (notes != null && notes.isNotEmpty) data['notes'] = notes;
    final body = _attachIdempotencyKey(data, idempotencyKey);
    final effectiveKey = _resolveIdempotencyKey(idempotencyKey, body);

    final response = await _client.dio.post(
      ApiConstants.adjustBookingDuration(bookingId),
      data: body,
      options: _idempotencyOptions(effectiveKey),
    );
    final res = response.data;
    if (res is Map<String, dynamic>) {
      return (res['data'] is Map<String, dynamic>) ? res['data'] : res;
    }
    return {};
  }

  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> returnData, {
    String? idempotencyKey,
  }) async {
    final body = _attachIdempotencyKey(returnData, idempotencyKey);
    final effectiveKey = _resolveIdempotencyKey(idempotencyKey, body);
    final response = await _client.dio.post(
      ApiConstants.returnBooking(bookingId),
      data: body,
      options: _idempotencyOptions(effectiveKey),
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

  Future<List<Map<String, dynamic>>> fetchModelAvailability({
    required DateTime startAt,
    required DateTime endAt,
    int? branchId,
    int? categoryId,
    String? search,
  }) async {
    if (branchId == null) {
      throw Exception('Cabang aktif wajib dipilih sebelum mengecek ketersediaan booking.');
    }
    final queryParams = <String, dynamic>{
      'start_at': startAt.toUtc().toIso8601String(),
      'end_at': endAt.toUtc().toIso8601String(),
      'branch_id': branchId.toString(),
    };
    if (categoryId != null) queryParams['category_id'] = categoryId.toString();
    if (search != null && search.trim().isNotEmpty) {
      queryParams['search'] = search.trim();
    }

    final response = await _client.dio.get(
      ApiConstants.bookingAvailability,
      queryParameters: queryParams,
      options: Options(headers: {'X-Branch-Id': branchId.toString()}),
    );
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchAvailableUnitsForBooking(
    dynamic bookingId, {
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    final response = await _client.dio.get(
      ApiConstants.bookingAvailableUnits(bookingId),
      queryParameters: {
        if (startNow) 'start_now': true,
        if (keepOriginalEndAt) 'keep_original_end_at': true,
      },
    );
    final rawData = response.data['data'];
    if (rawData is List) {
      return rawData
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<Map<String, dynamic>> checkInBooking(
    dynamic bookingId, {
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    final payload = <String, dynamic>{};
    if (assetUnitId != null) payload['asset_unit_id'] = assetUnitId;
    if (collateralType != null && collateralType.isNotEmpty) {
      payload['collateral_type'] = collateralType;
    }
    if (collateralTypeId != null && collateralTypeId.isNotEmpty) {
      payload['collateral_type_id'] = collateralTypeId;
    }
    if (collateralTypeName != null && collateralTypeName.isNotEmpty) {
      payload['collateral_type_name'] = collateralTypeName;
    }
    if (collateralStorageSlot != null && collateralStorageSlot.isNotEmpty) {
      payload['collateral_storage_slot'] = collateralStorageSlot;
    }
    if (collateralDepositAmount != null && collateralDepositAmount > 0) {
      payload['collateral_deposit_amount'] = collateralDepositAmount;
    }
    if (startNow) {
      payload['start_now'] = true;
      payload['keep_original_end_at'] = keepOriginalEndAt;
    }

    final response = await _client.dio.post(
      ApiConstants.checkInBooking(bookingId),
      data: payload,
    );
    final raw = response.data;
    final data = raw is Map ? raw['data'] : null;
    final result = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    if (raw is Map && raw['notice'] != null) {
      result['_notice'] = raw['notice'].toString();
    }
    return result;
  }

  Future<Map<String, dynamic>> rescheduleBooking(
    dynamic bookingId, {
    required DateTime newStartAt,
    bool keepOriginalEndAt = false,
  }) async {
    final response = await _client.dio.patch(
      ApiConstants.rescheduleBooking(bookingId),
      data: {
        'new_start_at': newStartAt.toUtc().toIso8601String(),
        'keep_original_end_at': keepOriginalEndAt,
      },
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> markNoShow(
    dynamic bookingId, {
    String? reason,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.markBookingNoShow(bookingId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> markNoShowWithDisposition(
    dynamic bookingId, {
    String? reason,
    required String dpDisposition,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.markBookingNoShow(bookingId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
        'dp_disposition': dpDisposition,
      },
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> cancelBooking(
    dynamic bookingId, {
    String? reason,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.cancelBooking(bookingId),
      data: {
        if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      },
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> extendGracePeriod(
    dynamic bookingId, {
    int additionalMinutes = 30,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.extendBookingPickup(bookingId),
      data: {'additional_minutes': additionalMinutes},
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}

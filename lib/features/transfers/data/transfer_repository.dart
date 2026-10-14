import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

class TransferRepository {
  final ApiClient _client = ApiClient();

  Future<List<Map<String, dynamic>>> fetchTransfers({String? direction, String? status}) async {
    final queryParams = <String, dynamic>{};
    if (direction != null && direction.isNotEmpty) queryParams['direction'] = direction;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final response = await _client.dio.get(
      ApiConstants.transfers,
      queryParameters: queryParams,
    );
    final data = response.data['data']['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchDestinationAffiliates() async {
    final response = await _client.dio.get(ApiConstants.transferDestinations);
    final data = response.data['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRecipients(int branchId) async {
    final response = await _client.dio.get(ApiConstants.transferRecipients(branchId));
    final data = response.data['data'] as List;
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  Future<Map<String, dynamic>> createTransfer({
    required int assetId,
    required int toAffiliateId,
    required String recipientId,
    String? notes,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.transfers,
      data: {
        'asset_id': assetId,
        'to_affiliate_id': toAffiliateId,
        'recipient_id': recipientId,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> approveTransfer(int transferId) async {
    final response = await _client.dio.post(ApiConstants.approveTransfer(transferId));
    return response.data['data'];
  }

  Future<Map<String, dynamic>> rejectTransfer(int transferId, String reason) async {
    final response = await _client.dio.post(
      ApiConstants.rejectTransfer(transferId),
      data: {
        'rejection_reason': reason,
      },
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> receiveTransfer(int transferId) async {
    final response = await _client.dio.post(ApiConstants.receiveTransfer(transferId));
    return response.data['data'];
  }

  Future<Map<String, dynamic>> cancelTransfer(int transferId) async {
    final response = await _client.dio.post(ApiConstants.cancelTransfer(transferId));
    return response.data['data'];
  }
}

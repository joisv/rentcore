import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/secure_token_storage.dart';

class AuthRepository {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await _client.dio.post(
      ApiConstants.login,
      data: {
        'email': email,
        'password': password,
        'device_name': 'RentCore Mobile Handheld',
      },
    );

    final data = response.data['data'];
    final token = data['token'];
    final user = data['user'];

    // Persist API token in Encrypted Storage
    await SecureTokenStorage().saveToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_role', user['role'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    if (user['affiliate'] != null) {
      await prefs.setString('branch_name', user['affiliate']['name'] ?? '');
      await prefs.setString('branch_code', user['affiliate']['code'] ?? '');
      await prefs.setInt('active_branch_id', user['affiliate']['id'] ?? 0);
    }

    final businesses = data['businesses'] ?? user['businesses'];
    if (businesses is List && businesses.isNotEmpty) {
      final firstBiz = businesses.first;
      await prefs.setInt('active_business_id', firstBiz['id'] ?? 0);
      await prefs.setString('active_business_name', firstBiz['name'] ?? '');
      if (firstBiz['branches'] != null && (firstBiz['branches'] as List).isNotEmpty) {
        final firstBranch = (firstBiz['branches'] as List).first;
        await prefs.setInt('active_branch_id', firstBranch['id'] ?? 0);
        await prefs.setString('branch_name', firstBranch['name'] ?? '');
      } else {
        await prefs.remove('active_branch_id');
        await prefs.remove('branch_name');
        await prefs.remove('branch_code');
      }
    } else if (businesses is List && businesses.isEmpty) {
      await prefs.remove('active_business_id');
      await prefs.remove('active_business_name');
      await prefs.remove('active_branch_id');
      await prefs.remove('branch_name');
      await prefs.remove('branch_code');
    }

    return data;
  }

  Future<Map<String, dynamic>> googleSignIn({
    required String idToken,
    String? email,
    String? name,
    String? avatarUrl,
  }) async {
    final response = await _client.dio.post(
      ApiConstants.googleSignIn,
      data: {
        'id_token': idToken,
        'email': email,
        'name': name,
        'avatar_url': avatarUrl,
        'device_name': 'RentCore Flutter Mobile Handheld (Google)',
      },
    );

    final data = response.data['data'];
    final token = data['token'];
    final user = data['user'];

    // Persist API token in Encrypted Storage
    await SecureTokenStorage().saveToken(token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_role', user['role'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    if (user['avatar_url'] != null) {
      await prefs.setString('user_avatar', user['avatar_url']);
    }

    final businesses = data['businesses'] ?? user['businesses'];
    if (businesses is List && businesses.isNotEmpty) {
      final firstBiz = businesses.first;
      await prefs.setInt('active_business_id', firstBiz['id'] ?? 0);
      await prefs.setString('active_business_name', firstBiz['name'] ?? '');
      if (firstBiz['branches'] != null && (firstBiz['branches'] as List).isNotEmpty) {
        final firstBranch = (firstBiz['branches'] as List).first;
        await prefs.setInt('active_branch_id', firstBranch['id'] ?? 0);
        await prefs.setString('branch_name', firstBranch['name'] ?? '');
      } else {
        await prefs.remove('active_branch_id');
        await prefs.remove('branch_name');
        await prefs.remove('branch_code');
      }
    } else if (businesses is List && businesses.isEmpty) {
      await prefs.remove('active_business_id');
      await prefs.remove('active_business_name');
      await prefs.remove('active_branch_id');
      await prefs.remove('branch_name');
      await prefs.remove('branch_code');
    }

    return data;
  }

  Future<List<dynamic>> fetchBusinesses() async {
    final response = await _client.dio.get(ApiConstants.businesses);
    return response.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> createBusiness({
    required String name,
    required String city,
    String? address,
    String? phone,
    List<String>? businessCategories,
    String? initialBranchName,
    String? initialBranchCode,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'city': city,
    };
    if (address != null && address.isNotEmpty) payload['address'] = address;
    if (phone != null && phone.isNotEmpty) payload['phone'] = phone;
    if (businessCategories != null && businessCategories.isNotEmpty) {
      payload['business_categories'] = businessCategories;
    }
    if (initialBranchName != null && initialBranchName.isNotEmpty) {
      payload['initial_branch_name'] = initialBranchName;
    }
    if (initialBranchCode != null && initialBranchCode.isNotEmpty) {
      payload['initial_branch_code'] = initialBranchCode;
    }

    final response = await _client.dio.post(
      ApiConstants.businesses,
      data: payload,
    );
    final data = response.data['data'];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_business_id', data['id']);
    await prefs.setString('active_business_name', data['name']);
    if (data['branches'] != null && (data['branches'] as List).isNotEmpty) {
      final branch = (data['branches'] as List).first;
      await prefs.setInt('active_branch_id', branch['id']);
      await prefs.setString('branch_name', branch['name']);
    }
    return data;
  }

  Future<Map<String, dynamic>> updateBusiness(
    int businessId,
    Map<String, dynamic> payload,
  ) async {
    final response = await _client.dio.put(
      ApiConstants.businessDetail(businessId),
      data: payload,
    );
    final data = response.data['data'] as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    if (data.containsKey('name')) {
      await prefs.setString('active_business_name', data['name']);
    }
    return data;
  }

  Future<Map<String, dynamic>> createBranch(
    int businessId, {
    required String name,
    required String code,
    String? city,
    String? address,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
      'code': code,
    };
    if (city != null && city.isNotEmpty) payload['city'] = city;
    if (address != null && address.isNotEmpty) payload['address'] = address;
    if (phone != null && phone.isNotEmpty) payload['phone'] = phone;

    final response = await _client.dio.post(
      ApiConstants.businessBranches(businessId),
      data: payload,
    );
    return response.data['data'];
  }

  Future<List<dynamic>> fetchBranches(int businessId) async {
    final response = await _client.dio.get(
      ApiConstants.businessBranches(businessId),
    );
    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> fetchMembers(int businessId) async {
    final response = await _client.dio.get(
      ApiConstants.businessMembers(businessId),
    );
    return response.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> inviteMember(
    int businessId, {
    required String email,
    String? name,
    required String role,
    List<int>? branchIds,
  }) async {
    final payload = <String, dynamic>{
      'email': email,
      'role': role,
    };
    if (name != null && name.isNotEmpty) payload['name'] = name;
    if (branchIds != null && branchIds.isNotEmpty) payload['branch_ids'] = branchIds;

    final response = await _client.dio.post(
      ApiConstants.businessMembers(businessId),
      data: payload,
    );
    return response.data['data'];
  }

  Future<Map<String, dynamic>> reassignMemberBranch(
    int businessId,
    int memberId, {
    int? fromBranchId,
    required int toBranchId,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'to_branch_id': toBranchId,
    };
    if (fromBranchId != null) payload['from_branch_id'] = fromBranchId;
    if (reason != null && reason.isNotEmpty) payload['reason'] = reason;

    final response = await _client.dio.post(
      ApiConstants.reassignMemberBranch(businessId, memberId),
      data: payload,
    );
    final data = response.data['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  Future<void> removeMemberBranch(int businessId, int memberId, int branchId) async {
    await _client.dio.delete(
      ApiConstants.removeMemberBranch(businessId, memberId, branchId),
    );
  }

  Future<void> updateMemberRole(int businessId, int memberId, String role) async {
    await _client.dio.put(
      ApiConstants.businessMember(businessId, memberId),
      data: {'role': role},
    );
  }

  Future<void> removeMember(int businessId, int memberId) async {
    await _client.dio.delete(
      ApiConstants.businessMember(businessId, memberId),
    );
  }

  Future<void> setManagerPin(int businessId, int memberId, String pin) async {
    await _client.dio.put(
      ApiConstants.memberManagerPin(businessId, memberId),
      data: {'pin': pin},
    );
  }

  Future<void> revokeManagerPin(int businessId, int memberId) async {
    await _client.dio.delete(
      ApiConstants.memberManagerPin(businessId, memberId),
    );
  }

  Future<List<dynamic>> fetchResignationRequests(int businessId, {String? status}) async {
    final queryParams = <String, dynamic>{};
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }
    final response = await _client.dio.get(
      ApiConstants.resignationRequests(businessId),
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    return response.data['data'] ?? [];
  }

  Future<Map<String, dynamic>> submitResignation(int businessId, {String? reason}) async {
    final payload = <String, dynamic>{};
    if (reason != null && reason.trim().isNotEmpty) {
      payload['reason'] = reason.trim();
    }
    final response = await _client.dio.post(
      ApiConstants.resignationRequests(businessId),
      data: payload,
    );
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> cancelResignation(int businessId, int requestId) async {
    final response = await _client.dio.post(
      ApiConstants.cancelResignation(businessId, requestId),
    );
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> approveResignation(int businessId, int requestId, {String? decisionNotes}) async {
    final payload = <String, dynamic>{};
    if (decisionNotes != null && decisionNotes.trim().isNotEmpty) {
      payload['decision_notes'] = decisionNotes.trim();
    }
    final response = await _client.dio.post(
      ApiConstants.approveResignation(businessId, requestId),
      data: payload,
    );
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> rejectResignation(int businessId, int requestId, {String? decisionNotes}) async {
    final payload = <String, dynamic>{};
    if (decisionNotes != null && decisionNotes.trim().isNotEmpty) {
      payload['decision_notes'] = decisionNotes.trim();
    }
    final response = await _client.dio.post(
      ApiConstants.rejectResignation(businessId, requestId),
      data: payload,
    );
    return response.data['data'] ?? {};
  }

  Future<void> setActiveContext({required int businessId, required String businessName, int? branchId, String? branchName}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_business_id', businessId);
    await prefs.setString('active_business_name', businessName);
    if (branchId != null) {
      await prefs.setInt('active_branch_id', branchId);
    } else {
      await prefs.remove('active_branch_id');
    }
    if (branchName != null) {
      await prefs.setString('branch_name', branchName);
    } else {
      await prefs.remove('branch_name');
    }
  }

  Future<Map<String, dynamic>?> checkSession() async {
    final token = await SecureTokenStorage().getToken();
    if (token == null || token.isEmpty) return null;

    final prefs = await SharedPreferences.getInstance();
    try {
      final response = await _client.dio.get(ApiConstants.me);
      final resData = response.data['data'];
      final user = resData['user'];
      final businesses = resData['businesses'] ?? user['businesses'];
      // Ensure active business is set if available
      final currentBizId = prefs.getInt('active_business_id');
      if (businesses is List && businesses.isNotEmpty) {
        final matches = businesses.where((b) => b['id'] == currentBizId);
        if (currentBizId == null || currentBizId == 0 || matches.isEmpty) {
          final firstBiz = businesses.first;
          await prefs.setInt('active_business_id', firstBiz['id'] ?? 0);
          await prefs.setString('active_business_name', firstBiz['name'] ?? '');
          if (firstBiz['branches'] != null && (firstBiz['branches'] as List).isNotEmpty) {
            final firstBranch = (firstBiz['branches'] as List).first;
            await prefs.setInt('active_branch_id', firstBranch['id'] ?? 0);
            await prefs.setString('branch_name', firstBranch['name'] ?? '');
          } else {
            await prefs.remove('active_branch_id');
            await prefs.remove('branch_name');
            await prefs.remove('branch_code');
          }
        }
      } else if (businesses is List && businesses.isEmpty) {
        await prefs.remove('active_business_id');
        await prefs.remove('active_business_name');
        await prefs.remove('active_branch_id');
        await prefs.remove('branch_name');
        await prefs.remove('branch_code');
      }
      return {
        'user': user,
        'businesses': businesses,
      };
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> fetchRentalRules(int businessId) async {
    final response = await _client.dio.get(ApiConstants.businessRentalRules(businessId));
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> updateRentalRules(int businessId, Map<String, dynamic> payload) async {
    final response = await _client.dio.put(
      ApiConstants.businessRentalRules(businessId),
      data: payload,
    );
    final data = response.data['data'];
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> updateProfile({
    required String name,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'name': name,
    };
    if (phone != null) {
      payload['phone'] = phone;
    }

    final response = await _client.dio.put(
      ApiConstants.updateProfile,
      data: payload,
    );

    final resData = response.data['data'];
    final user = resData['user'];

    final prefs = await SharedPreferences.getInstance();
    if (user != null && user['name'] != null) {
      await prefs.setString('user_name', user['name']);
    }

    return Map<String, dynamic>.from(resData);
  }

  Future<Map<String, dynamic>> updatePassword({
    String? currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    final payload = <String, dynamic>{
      'new_password': newPassword,
      'new_password_confirmation': newPasswordConfirmation,
    };
    if (currentPassword != null && currentPassword.isNotEmpty) {
      payload['current_password'] = currentPassword;
    }

    final response = await _client.dio.put(
      ApiConstants.updatePassword,
      data: payload,
    );

    return Map<String, dynamic>.from(response.data);
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiConstants.logout);
    } catch (_) {}

    // Invalidate secure token storage defensively
    try {
      await SecureTokenStorage().clearToken();
    } catch (_) {}

    // Purge tenant-scoped session context and user profile from preferences while preserving
    // hardware configurations (thermal printer settings, paired Bluetooth devices)
    // and network setup (custom server base URL, google server client ID).
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('active_business_id');
      await prefs.remove('active_business_name');
      await prefs.remove('active_branch_id');
      await prefs.remove('branch_name');
      await prefs.remove('branch_code');
      await prefs.remove('user_name');
      await prefs.remove('user_role');
      await prefs.remove('user_email');
      await prefs.remove('user_avatar');
    } catch (_) {}
  }
}

import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';

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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_role', user['role'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    if (user['affiliate'] != null) {
      await prefs.setString('branch_name', user['affiliate']['name'] ?? '');
      await prefs.setString('branch_code', user['affiliate']['code'] ?? '');
    }

    return data;
  }

  Future<Map<String, dynamic>?> checkSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _client.dio.get(ApiConstants.me);
      return response.data['data']['user'];
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    try {
      await _client.dio.post(ApiConstants.logout);
    } catch (_) {}
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}

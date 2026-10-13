import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  String _baseUrl = ApiConstants.defaultBaseUrl;

  void Function(bool isConnected)? onConnectivityChanged;

  ApiClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('auth_token');
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          onConnectivityChanged?.call(true);
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          if (error.type == DioExceptionType.connectionError ||
              error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            onConnectivityChanged?.call(false);
          }
          // Format user-friendly error message with diagnostic hints
          String message = 'Terjadi kesalahan pada koneksi jaringan.';
          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            message = 'Waktu koneksi habis (Timeout). Pastikan server Laravel aktif.';
          } else if (error.type == DioExceptionType.connectionError) {
            message = 'Tidak dapat terhubung ke $_baseUrl.\n\nTips:\n1. Pastikan HP dan PC berada di satu jaringan Wi-Fi.\n2. Pastikan server backend Laravel aktif di PC (0.0.0.0:8000).';
          } else if (error.response?.data != null && error.response?.data is Map) {
            final data = error.response?.data as Map;
            if (data['message'] != null) {
              message = data['message'].toString();
            } else if (data['errors'] != null && data['errors'] is Map) {
              final errors = data['errors'] as Map;
              final firstError = errors.values.first;
              if (firstError is List && firstError.isNotEmpty) {
                message = firstError.first.toString();
              }
            }
          }

          final customError = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: message,
          );
          return handler.next(customError);
        },
      ),
    );
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      dio.options.baseUrl = savedUrl;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    _baseUrl = newUrl;
    dio.options.baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
  }

  String get currentBaseUrl => _baseUrl;
}

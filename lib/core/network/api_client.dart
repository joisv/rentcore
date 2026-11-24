import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../services/secure_token_storage.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;

  late Dio dio;
  String _baseUrl = AppConfig.effectiveDefaultBaseUrl;

  static bool isLoggingOut = false;

  void Function(bool isConnected)? onConnectivityChanged;
  void Function()? onUnauthorized;

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
          final token = await SecureTokenStorage().getToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          final prefs = await SharedPreferences.getInstance();
          final businessId = prefs.getInt('active_business_id');
          if (businessId != null && businessId > 0) {
            options.headers['X-Business-Id'] = businessId.toString();
          }
          if (!options.headers.containsKey('X-Branch-Id')) {
            final branchId = prefs.getInt('active_branch_id');
            if (branchId != null && branchId > 0) {
              options.headers['X-Branch-Id'] = branchId.toString();
            }
          } else if (options.headers['X-Branch-Id'] == '' || options.headers['X-Branch-Id'] == null) {
            options.headers.remove('X-Branch-Id');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          onConnectivityChanged?.call(true);
          return handler.next(response);
        },
        onError: (DioException error, handler) {
          final isLogoutRequest =
              error.requestOptions.path.contains('/auth/logout');
          final suppressSessionHooks = isLogoutRequest || isLoggingOut;

          if (!suppressSessionHooks &&
              (error.type == DioExceptionType.connectionError ||
                  error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.receiveTimeout ||
                  error.type == DioExceptionType.sendTimeout)) {
            onConnectivityChanged?.call(false);
          }

          if (!suppressSessionHooks && error.response?.statusCode == 401) {
            onUnauthorized?.call();
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
            message = extractMessageFromResponseData(
              error.response?.data as Map,
              fallback: message,
            );
          }

          final customError = DioException(
            requestOptions: error.requestOptions,
            response: error.response,
            type: error.type,
            error: message,
            message: message,
          );
          return handler.next(customError);
        },
      ),
    );
  }

  /// Extract a clean user-facing message from a Laravel JSON error payload.
  static String extractMessageFromResponseData(
    Map data, {
    String fallback = 'Terjadi kesalahan pada server.',
  }) {
    final errors = data['errors'];
    final rawMessage = data['message']?.toString().trim() ?? '';

    if (rawMessage.isNotEmpty &&
        rawMessage.toLowerCase() != 'the given data was invalid.') {
      return rawMessage;
    }

    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        final firstMsg = firstError.first.toString().trim();
        if (firstMsg.isNotEmpty) return firstMsg;
      } else if (firstError != null && firstError.toString().trim().isNotEmpty) {
        return firstError.toString().trim();
      }
    }

    return rawMessage.isNotEmpty ? rawMessage : fallback;
  }

  /// Extract a clean error message from any thrown error, unwrapping DioException payloads.
  static String extractErrorMessage(
    Object error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        return extractMessageFromResponseData(data, fallback: fallback);
      }
      final errText = error.error?.toString().trim();
      if (errText != null && errText.isNotEmpty) {
        return errText;
      }
      final msgText = error.message?.trim();
      if (msgText != null && msgText.isNotEmpty) {
        return msgText;
      }
      return fallback;
    }

    final raw = error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    return raw.isNotEmpty ? raw : fallback;
  }

  Future<void> init() async {
    if (AppConfig.isProduction) {
      _baseUrl = AppConfig.productionBaseUrl;
      dio.options.baseUrl = _baseUrl;
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('api_base_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      dio.options.baseUrl = savedUrl;
    } else {
      _baseUrl = ApiConstants.defaultBaseUrl;
      dio.options.baseUrl = _baseUrl;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    if (AppConfig.isProduction) {
      // Production builds lock base URL and ignore local server overrides.
      _baseUrl = AppConfig.productionBaseUrl;
      dio.options.baseUrl = _baseUrl;
      return;
    }

    _baseUrl = newUrl;
    dio.options.baseUrl = newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', newUrl);
  }

  String get currentBaseUrl =>
      AppConfig.isProduction ? AppConfig.productionBaseUrl : _baseUrl;
}

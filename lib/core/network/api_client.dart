import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../constants/api_constants.dart';
import '../services/secure_token_storage.dart';

/// Typed, user-friendly API exception mapped from HTTP status codes and Dio errors.
class ApiException implements Exception {
  static const String unauthorizedMessage =
      'Sesi login Anda telah berakhir. Silakan masuk kembali.';
  static const String forbiddenMessage =
      'Anda tidak memiliki izin untuk melakukan tindakan ini.';
  static const String notFoundMessage =
      'Data yang diminta tidak ditemukan atau sudah diperbarui.';
  static const String rateLimitedMessage =
      'Terlalu banyak permintaan. Tunggu beberapa detik lalu coba lagi.';
  static const String serverErrorMessage =
      'Server sedang mengalami gangguan sementara. Silakan coba beberapa saat lagi.';
  static const String networkTimeoutMessage =
      'Koneksi internet tidak stabil. Periksa jaringan Anda dan coba lagi.';
  static const String defaultValidationMessage =
      'Data yang dikirim tidak valid. Periksa kembali isian Anda.';
  static const String defaultErrorMessage =
      'Terjadi kesalahan. Silakan coba lagi.';

  final String message;
  final int? statusCode;
  final DioExceptionType? type;
  final Map<String, dynamic>? validationErrors;
  final Object? originalError;

  const ApiException({
    required this.message,
    this.statusCode,
    this.type,
    this.validationErrors,
    this.originalError,
  });

  factory ApiException.fromDioException(DioException error) {
    if (error.error is ApiException) {
      return error.error as ApiException;
    }

    // 1. Socket / Connectivity / Timeout failures
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError ||
        error.error is SocketException) {
      return ApiException(
        message: networkTimeoutMessage,
        statusCode: error.response?.statusCode,
        type: error.type,
        originalError: error,
      );
    }

    final statusCode = error.response?.statusCode;
    final rawData = error.response?.data;
    final Map<String, dynamic>? payloadMap =
        rawData is Map ? Map<String, dynamic>.from(rawData) : null;
    final Map<String, dynamic>? errorsMap = payloadMap?['errors'] is Map
        ? Map<String, dynamic>.from(payloadMap!['errors'] as Map)
        : null;

    // 2. HTTP Status Code Mapping
    switch (statusCode) {
      case 401:
        return ApiException(
          message: unauthorizedMessage,
          statusCode: 401,
          type: error.type,
          originalError: error,
        );
      case 403:
        return ApiException(
          message: forbiddenMessage,
          statusCode: 403,
          type: error.type,
          originalError: error,
        );
      case 404:
        return ApiException(
          message: notFoundMessage,
          statusCode: 404,
          type: error.type,
          originalError: error,
        );
      case 422:
        final validationMsg = payloadMap != null
            ? ApiClient.extractMessageFromResponseData(
                payloadMap,
                fallback: defaultValidationMessage,
              )
            : defaultValidationMessage;
        return ApiException(
          message: validationMsg,
          statusCode: 422,
          type: error.type,
          validationErrors: errorsMap,
          originalError: error,
        );
      case 429:
        return ApiException(
          message: rateLimitedMessage,
          statusCode: 429,
          type: error.type,
          originalError: error,
        );
      case 500:
      case 502:
      case 503:
      case 504:
        return ApiException(
          message: serverErrorMessage,
          statusCode: statusCode,
          type: error.type,
          originalError: error,
        );
    }

    // 3. Fallback for other 4xx responses with structured JSON message
    if (payloadMap != null) {
      final extracted = ApiClient.extractMessageFromResponseData(
        payloadMap,
        fallback: defaultErrorMessage,
      );
      return ApiException(
        message: extracted,
        statusCode: statusCode,
        type: error.type,
        validationErrors: errorsMap,
        originalError: error,
      );
    }

    return ApiException(
      message: defaultErrorMessage,
      statusCode: statusCode,
      type: error.type,
      originalError: error,
    );
  }

  @override
  String toString() => message;
}

/// Safe Dio retry interceptor that retries ONLY idempotent `GET` requests
/// on transient network/server errors (`429`, `502`, `503`, timeouts, socket errors)
/// with exponential backoff (`1s` -> `2s`) and `Retry-After` header support.
///
/// Mutating HTTP methods (`POST`, `PUT`, `PATCH`, `DELETE`) are NEVER retried
/// automatically to prevent duplicate writes or double charges.
class IdempotentGetRetryInterceptor extends Interceptor {
  static const String _retryCountExtraKey = '_idempotent_get_retry_count';
  static const Set<int> retryableStatusCodes = {429, 502, 503};

  final Dio dio;
  final int maxRetries;
  final Duration baseDelay;
  final Duration maxRetryAfterDelay;
  final Future<void> Function(Duration delay) sleep;

  IdempotentGetRetryInterceptor({
    required this.dio,
    this.maxRetries = 2,
    this.baseDelay = const Duration(seconds: 1),
    this.maxRetryAfterDelay = const Duration(seconds: 10),
    Future<void> Function(Duration delay)? sleep,
  }) : sleep = sleep ?? Future<void>.delayed;

  bool shouldRetry(DioException err) {
    final options = err.requestOptions;

    // Strictly GET only — never retry mutations blindly
    if (options.method.toUpperCase() != 'GET') {
      return false;
    }

    // Never retry explicitly cancelled requests
    if (err.type == DioExceptionType.cancel ||
        (options.cancelToken?.isCancelled ?? false)) {
      return false;
    }

    final attempt = (options.extra[_retryCountExtraKey] as int?) ?? 0;
    if (attempt >= maxRetries) {
      return false;
    }

    final statusCode = err.response?.statusCode;
    if (statusCode != null && retryableStatusCodes.contains(statusCode)) {
      return true;
    }

    return err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.sendTimeout ||
        err.type == DioExceptionType.connectionError ||
        err.error is SocketException;
  }

  Duration computeBackoffDelay(DioException err, int attemptIndex) {
    final retryAfterHeader = err.response?.headers.value('retry-after');
    if (retryAfterHeader != null && retryAfterHeader.trim().isNotEmpty) {
      final parsed = _parseRetryAfter(retryAfterHeader.trim());
      if (parsed != null && parsed > Duration.zero) {
        return parsed > maxRetryAfterDelay ? maxRetryAfterDelay : parsed;
      }
    }

    // Exponential backoff: attempt 0 -> 1s (baseDelay * 1), attempt 1 -> 2s (baseDelay * 2)
    final multiplier = 1 << attemptIndex;
    return Duration(milliseconds: baseDelay.inMilliseconds * multiplier);
  }

  Duration? _parseRetryAfter(String headerValue) {
    final seconds = int.tryParse(headerValue);
    if (seconds != null) {
      return Duration(seconds: seconds);
    }
    try {
      final retryDate = HttpDate.parse(headerValue);
      final diff = retryDate.difference(DateTime.now().toUtc());
      return diff.isNegative ? Duration.zero : diff;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (!shouldRetry(err)) {
      return handler.next(err);
    }

    final options = err.requestOptions;
    final attempt = (options.extra[_retryCountExtraKey] as int?) ?? 0;
    final delay = computeBackoffDelay(err, attempt);

    await sleep(delay);

    // Abort if request was cancelled while waiting for backoff
    if (options.cancelToken?.isCancelled ?? false) {
      return handler.next(err);
    }

    options.extra[_retryCountExtraKey] = attempt + 1;

    try {
      final response = await dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (retryErr) {
      return handler.next(retryErr);
    }
  }
}

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

    // 1. Auth & multi-tenant context headers
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
          } else if (options.headers['X-Branch-Id'] == '' ||
              options.headers['X-Branch-Id'] == null) {
            options.headers.remove('X-Branch-Id');
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          onConnectivityChanged?.call(true);
          return handler.next(response);
        },
      ),
    );

    // 2. Safe exponential backoff retry for idempotent GET requests only
    dio.interceptors.add(IdempotentGetRetryInterceptor(dio: dio));

    // 3. Centralized user-friendly HTTP error mapper & session lifecycle hooks
    dio.interceptors.add(
      createErrorMappingInterceptor(
        onConnectivityChanged: (connected) =>
            onConnectivityChanged?.call(connected),
        onUnauthorized: () => onUnauthorized?.call(),
      ),
    );
  }

  /// Creates the centralized error mapping interceptor.
  /// Exposed for unit testing with custom [Dio] instances and mock adapters.
  static InterceptorsWrapper createErrorMappingInterceptor({
    void Function(bool isConnected)? onConnectivityChanged,
    void Function()? onUnauthorized,
  }) {
    return InterceptorsWrapper(
      onError: (DioException error, handler) {
        if (error.type == DioExceptionType.cancel) {
          return handler.next(error);
        }

        final isLogoutRequest =
            error.requestOptions.path.contains('/auth/logout');
        final suppressSessionHooks = isLogoutRequest || isLoggingOut;

        if (!suppressSessionHooks &&
            (error.type == DioExceptionType.connectionError ||
                error.type == DioExceptionType.connectionTimeout ||
                error.type == DioExceptionType.receiveTimeout ||
                error.type == DioExceptionType.sendTimeout ||
                error.error is SocketException)) {
          onConnectivityChanged?.call(false);
        }

        if (!suppressSessionHooks && error.response?.statusCode == 401) {
          onUnauthorized?.call();
        }

        final apiException = ApiException.fromDioException(error);

        final mappedError = DioException(
          requestOptions: error.requestOptions,
          response: error.response,
          type: error.type,
          error: apiException,
          message: apiException.message,
        );
        return handler.next(mappedError);
      },
    );
  }

  /// Build an isolated [Dio] configured with [IdempotentGetRetryInterceptor]
  /// and centralized [ApiException] error mapping for unit testing.
  static Dio createDioForTesting({
    required HttpClientAdapter adapter,
    String baseUrl = 'https://api.rentcore.id/api/v1',
    int maxRetries = 2,
    Duration baseDelay = const Duration(seconds: 1),
    Future<void> Function(Duration delay)? sleep,
    void Function(bool isConnected)? onConnectivityChanged,
    void Function()? onUnauthorized,
  }) {
    final testDio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );
    testDio.httpClientAdapter = adapter;
    testDio.interceptors.add(
      IdempotentGetRetryInterceptor(
        dio: testDio,
        maxRetries: maxRetries,
        baseDelay: baseDelay,
        sleep: sleep,
      ),
    );
    testDio.interceptors.add(
      createErrorMappingInterceptor(
        onConnectivityChanged: onConnectivityChanged,
        onUnauthorized: onUnauthorized,
      ),
    );
    return testDio;
  }

  /// Map a [DioException] to a centralized human-readable [ApiException].
  static ApiException mapDioException(DioException error) {
    return ApiException.fromDioException(error);
  }

  /// Extract a clean user-facing message from a Laravel JSON error payload.
  static String extractMessageFromResponseData(
    Map data, {
    String fallback = 'Terjadi kesalahan pada server.',
  }) {
    final errors = data['errors'];
    final rawMessage = data['message']?.toString().trim() ?? '';

    if (errors is Map && errors.isNotEmpty) {
      final firstError = errors.values.first;
      if (firstError is List && firstError.isNotEmpty) {
        final firstMsg = firstError.first.toString().trim();
        if (firstMsg.isNotEmpty) return firstMsg;
      } else if (firstError != null && firstError.toString().trim().isNotEmpty) {
        return firstError.toString().trim();
      }
    }

    if (rawMessage.isNotEmpty &&
        rawMessage.toLowerCase() != 'the given data was invalid.') {
      return rawMessage;
    }

    return rawMessage.isNotEmpty ? rawMessage : fallback;
  }

  /// Extract a clean error message from any thrown error, unwrapping [ApiException]
  /// and [DioException] payloads into human-readable Indonesian messages.
  static String extractErrorMessage(
    Object error, {
    String fallback = 'Terjadi kesalahan. Silakan coba lagi.',
  }) {
    if (error is ApiException) {
      return error.message;
    }

    if (error is DioException) {
      if (error.error is ApiException) {
        return (error.error as ApiException).message;
      }
      final mapped = ApiException.fromDioException(error);
      if (mapped.message.isNotEmpty &&
          mapped.message != ApiException.defaultErrorMessage) {
        return mapped.message;
      }
      final errText = error.error?.toString().trim();
      if (errText != null &&
          errText.isNotEmpty &&
          !errText.startsWith('DioException')) {
        return errText;
      }
      return fallback;
    }

    final raw =
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
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

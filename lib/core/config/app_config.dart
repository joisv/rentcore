import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/api_constants.dart';

/// Build-time application environment modes.
enum AppEnvironment {
  development,
  production,
}

/// Centralized environment and endpoint configuration driven by compile-time
/// `--dart-define=APP_ENV=...` and Flutter build mode ([kReleaseMode]).
///
/// Release / Play Store build command:
/// `flutter build appbundle --release --dart-define=APP_ENV=production`
class AppConfig {
  AppConfig._();

  /// Compile-time environment identifier (`production` or `dev`).
  static const String rawAppEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: '',
  );

  /// Locked production API base URL for release / production builds.
  static const String productionBaseUrl = ApiConstants.productionBaseUrl;

  /// Default local development API base URL.
  static const String developmentBaseUrl = ApiConstants.defaultBaseUrl;

  /// Test-only override so unit and widget tests can exercise both modes
  /// within a single debug `flutter test` run without compile-time defines.
  @visibleForTesting
  static AppEnvironment? debugEnvironmentOverride;

  /// Resolves [AppEnvironment] strictly:
  /// - Production whenever `APP_ENV == 'production'` OR (`APP_ENV.isEmpty && kReleaseMode`).
  /// - Development whenever `APP_ENV == 'dev'` OR (`APP_ENV.isEmpty && !kReleaseMode`).
  static AppEnvironment resolveEnvironment({
    String rawEnv = rawAppEnv,
    bool isReleaseMode = kReleaseMode,
  }) {
    final normalized = rawEnv.trim().toLowerCase();
    if (normalized == 'production' || normalized == 'prod') {
      return AppEnvironment.production;
    }
    if (normalized == 'dev' || normalized == 'development') {
      return AppEnvironment.development;
    }
    return isReleaseMode
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  /// Active application environment.
  static AppEnvironment get environment =>
      debugEnvironmentOverride ?? resolveEnvironment();

  /// True when running in locked Production mode.
  static bool get isProduction => environment == AppEnvironment.production;

  /// True when running in Development mode (QA tools enabled).
  static bool get isDevelopment => environment == AppEnvironment.development;

  /// Default base URL for the active environment.
  static String get effectiveDefaultBaseUrl =>
      isProduction ? productionBaseUrl : developmentBaseUrl;
}

/// Exposes the resolved [AppEnvironment] to widgets and providers cleanly,
/// supporting test overrides via `ProviderScope`.
final appEnvironmentProvider = Provider<AppEnvironment>(
  (ref) => AppConfig.environment,
);

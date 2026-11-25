import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../network/api_client.dart';

class AppConfigData {
  final String minAndroidVersion;
  final String latestAndroidVersion;
  final String playStoreUrl;
  final bool maintenanceMode;
  final String? maintenanceMessage;
  final String? forceUpdateMessage;

  const AppConfigData({
    required this.minAndroidVersion,
    required this.latestAndroidVersion,
    required this.playStoreUrl,
    required this.maintenanceMode,
    this.maintenanceMessage,
    this.forceUpdateMessage,
  });

  factory AppConfigData.fromJson(Map<String, dynamic> json) {
    final rawPlayUrl = json['play_store_url']?.toString().trim() ?? '';
    return AppConfigData(
      minAndroidVersion: json['min_android_version']?.toString().trim().isNotEmpty == true
          ? json['min_android_version'].toString().trim()
          : '1.0.0',
      latestAndroidVersion: json['latest_android_version']?.toString().trim().isNotEmpty == true
          ? json['latest_android_version'].toString().trim()
          : '1.0.0',
      playStoreUrl: rawPlayUrl.isNotEmpty
          ? rawPlayUrl
          : 'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
      maintenanceMode: json['maintenance_mode'] == true,
      maintenanceMessage: _cleanNullable(json['maintenance_message']),
      forceUpdateMessage: _cleanNullable(json['force_update_message']),
    );
  }

  static String? _cleanNullable(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Parses a SemVer string like "1.2.10+4" or "v1.2.0-beta" into [major, minor, patch].
List<int> parseSemVer(String version) {
  final cleaned = version
      .trim()
      .replaceFirst(RegExp(r'^v', caseSensitive: false), '')
      .split('+')
      .first
      .split('-')
      .first;
  final parts = cleaned.split('.');
  int parsePart(int index) {
    if (index >= parts.length) return 0;
    return int.tryParse(parts[index].trim()) ?? 0;
  }

  return [parsePart(0), parsePart(1), parsePart(2)];
}

/// Compares two SemVer strings numerically: returns < 0 if [a] < [b], 0 if equal, > 0 if [a] > [b].
int compareSemVer(String a, String b) {
  final pa = parseSemVer(a);
  final pb = parseSemVer(b);
  for (var i = 0; i < 3; i++) {
    if (pa[i] != pb[i]) {
      return pa[i].compareTo(pb[i]);
    }
  }
  return 0;
}

/// Returns true strictly when [installedVersion] is lower than [minVersion].
bool isVersionLowerThan(String installedVersion, String minVersion) {
  return compareSemVer(installedVersion, minVersion) < 0;
}

class AppConfigService {
  final Dio? _overrideDio;

  AppConfigService({Dio? dio}) : _overrideDio = dio;

  Dio _buildDio() {
    if (_overrideDio != null) return _overrideDio;
    return Dio(
      BaseOptions(
        baseUrl: ApiClient().currentBaseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
        headers: const {
          'Accept': 'application/json',
        },
      ),
    );
  }

  /// Fetches `/api/v1/app-config` with a 4s timeout.
  /// Fail-open: returns `null` on any network/timeout/parsing error so offline
  /// or slow-network cashiers are never locked out.
  Future<AppConfigData?> fetchAppConfig() async {
    try {
      final response = await _buildDio().get<dynamic>(ApiConstants.appConfig);
      final body = response.data;
      if (body is Map<String, dynamic>) {
        final rawData = body['data'];
        if (rawData is Map<String, dynamic>) {
          return AppConfigData.fromJson(rawData);
        }
        if (rawData is Map) {
          return AppConfigData.fromJson(Map<String, dynamic>.from(rawData));
        }
      } else if (body is Map) {
        final mapBody = Map<String, dynamic>.from(body);
        final rawData = mapBody['data'];
        if (rawData is Map) {
          return AppConfigData.fromJson(Map<String, dynamic>.from(rawData));
        }
      }
      return null;
    } catch (e) {
      debugPrint('[AppConfigService] Fail-open on app-config fetch error: $e');
      return null;
    }
  }
}

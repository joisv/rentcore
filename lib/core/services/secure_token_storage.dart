import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureTokenStorage {
  static const _keyToken = 'auth_token';
  static final SecureTokenStorage _instance = SecureTokenStorage._internal();
  factory SecureTokenStorage() => _instance;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: true,
    ),
  );

  SecureTokenStorage._internal();

  /// Persist Sanctum bearer token in encrypted storage
  Future<void> saveToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  /// Retrieve active token
  Future<String?> getToken() async {
    return await _storage.read(key: _keyToken);
  }

  /// Invalidate and remove active token
  Future<void> clearToken() async {
    await _storage.delete(key: _keyToken);
  }
}

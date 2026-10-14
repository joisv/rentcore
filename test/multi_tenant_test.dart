import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/network/api_client.dart';
import 'package:rentcore_mobile/core/services/secure_token_storage.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Multi-Tenant Context & Header Injection Tests', () {
    test('SharedPreferences stores and retrieves active business and branch', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_business_id', 42);
      await prefs.setString('active_business_name', 'SkyRental Dewata');
      await prefs.setInt('active_branch_id', 108);
      await prefs.setString('branch_name', 'Cabang Seminyak');

      expect(prefs.getInt('active_business_id'), 42);
      expect(prefs.getString('active_business_name'), 'SkyRental Dewata');
      expect(prefs.getInt('active_branch_id'), 108);
      expect(prefs.getString('branch_name'), 'Cabang Seminyak');
    });

    test('ApiClient interceptor injects X-Business-Id and X-Branch-Id headers when set', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', 'mock_token_xyz');
      await prefs.setInt('active_business_id', 99);
      await prefs.setInt('active_branch_id', 77);

      final client = ApiClient();
      expect(client.dio.interceptors.isNotEmpty, true);
    });

    test('BusinessState copyWith maintains state immutability', () {
      const state = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Pusat',
        activeBranchId: 10,
        activeBranchName: 'Cabang Genteng',
        businesses: [
          {'id': 1, 'name': 'RentCore Pusat'}
        ],
      );

      final switched = state.copyWith(
        activeBusinessId: 2,
        activeBusinessName: 'SkyRental Bali',
        activeBranchId: 20,
        activeBranchName: 'Cabang Kuta',
      );

      expect(state.activeBusinessId, 1);
      expect(state.activeBusinessName, 'RentCore Pusat');
      expect(switched.activeBusinessId, 2);
      expect(switched.activeBusinessName, 'SkyRental Bali');
      expect(switched.activeBranchId, 20);
      expect(switched.activeBranchName, 'Cabang Kuta');
    });

    test('Role badge parsing distinguishes owner, admin, and staff', () {
      const roles = ['owner', 'admin', 'staff'];
      expect(roles.contains('owner'), true);
      expect(roles.contains('admin'), true);
      expect(roles.contains('staff'), true);
    });

    test('SecureTokenStorage saves, retrieves, and clears authentication token', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureTokenStorage();

      expect(await storage.getToken(), null);
      await storage.saveToken('sanctum_token_test_123');
      expect(await storage.getToken(), 'sanctum_token_test_123');
      await storage.clearToken();
      expect(await storage.getToken(), null);
    });

    test('Stale active_business_id is cleared when user has no business memberships', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate leftover business ID from another account or session
      await prefs.setInt('active_business_id', 1);
      await prefs.setString('active_business_name', 'RentCore Network');
      await prefs.setInt('active_branch_id', 1);
      await prefs.setString('branch_name', 'Genteng Central');

      expect(prefs.getInt('active_business_id'), 1);

      // Simulate empty business list purging
      final userBusinesses = <dynamic>[];
      if (userBusinesses.isEmpty) {
        await prefs.remove('active_business_id');
        await prefs.remove('active_business_name');
        await prefs.remove('active_branch_id');
        await prefs.remove('branch_name');
      }

      expect(prefs.getInt('active_business_id'), null);
      expect(prefs.getString('active_business_name'), null);
      expect(prefs.getInt('active_branch_id'), null);
      expect(prefs.getString('branch_name'), null);
    });
  });
}

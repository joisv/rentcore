import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/organization/providers/organization_provider.dart';
import 'package:rentcore_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:rentcore_mobile/features/vouchers/providers/voucher_provider.dart';

class _FakeAuthRepository extends AuthRepository {
  String? currentUserEmail;
  bool isLoggedOut = true;

  final Map<String, List<Map<String, dynamic>>> userBusinesses = {
    'user.a@rentcore.id': [
      {
        'id': 101,
        'name': 'Tenant Alpha Store',
        'role': 'owner',
        'branches': [
          {'id': 201, 'name': 'Alpha Central Branch', 'code': 'ALPH', 'is_central': true}
        ]
      }
    ],
    'user.b@rentcore.id': [
      {
        'id': 102,
        'name': 'Tenant Beta Store',
        'role': 'owner',
        'branches': [
          {'id': 202, 'name': 'Beta Central Branch', 'code': 'BETA', 'is_central': true}
        ]
      }
    ]
  };

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    currentUserEmail = email;
    isLoggedOut = false;
    final businesses = userBusinesses[email] ?? [];
    final user = {
      'id': email.hashCode,
      'name': email.startsWith('user.a') ? 'User Alpha' : 'User Beta',
      'email': email,
      'role': 'owner',
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user['name'] as String);
    await prefs.setString('user_email', user['email'] as String);

    if (businesses.isNotEmpty) {
      final firstBiz = businesses.first;
      await prefs.setInt('active_business_id', firstBiz['id'] as int);
      await prefs.setString('active_business_name', firstBiz['name'] as String);
      final branches = firstBiz['branches'] as List;
      if (branches.isNotEmpty) {
        final firstBranch = branches.first as Map<String, dynamic>;
        await prefs.setInt('active_branch_id', firstBranch['id'] as int);
        await prefs.setString('branch_name', firstBranch['name'] as String);
      }
    }

    return {
      'token': 'fake_jwt_token_for_$email',
      'user': user,
      'businesses': businesses,
    };
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    if (isLoggedOut || currentUserEmail == null) return [];
    return userBusinesses[currentUserEmail] ?? [];
  }

  @override
  Future<void> logout() async {
    isLoggedOut = true;
    currentUserEmail = null;
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
  }
}

class _FakeDashboardRepository extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    return {
      'is_empty_tenant': false,
      'stats': {
        'total_units': 15,
        'ready_units': 10,
        'rented_units': 5,
        'maintenance_units': 0,
        'today_revenue': 2500000,
        'active_rentals': 5,
        'overdue_count': 0,
      },
      'overdue_alerts': [],
      'recent_activities': [
        {'id': 1, 'action': 'Rental returned'}
      ],
    };
  }
}

class _FakeAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    int? categoryId,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return [
      {
        'id': 1,
        'asset_code': 'IP15-001',
        'status': 'ready',
        'model': {'name': 'iPhone 15 Pro'}
      },
      {
        'id': 2,
        'asset_code': 'IP15-002',
        'status': 'rented',
        'model': {'name': 'iPhone 15 Pro Max'}
      }
    ];
  }
}

class _FakeBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return [
      {
        'id': 1,
        'booking_code': 'RC-2026-001',
        'status': 'active',
        'total_amount': 500000,
      }
    ];
  }
}

class _FakeVoucherRepository extends VoucherRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchVouchers({
    String? status,
    String? search,
    dynamic branchId,
  }) async {
    return [
      {'id': 1, 'code': 'DISCOUNT10', 'name': 'Promo Diskon 10%'}
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'rentcore_printer_settings_v1': '{"paperWidth":"mm80"}',
      'api_base_url': 'http://192.168.1.101:8000/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Authentication Lifecycle & Post-Login Data Reload Tests', () {
    test('Complete cycle: Login -> Load Data -> Logout -> Relogin without restart reloads full account data', () async {
      final fakeAuthRepo = _FakeAuthRepository();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
          assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepository()),
          voucherRepositoryProvider.overrideWithValue(_FakeVoucherRepository()),
        ],
      );
      addTearDown(container.dispose);

      // --- STEP 1: INITIAL LOGIN (User Alpha) ---
      final authNotifier = container.read(authProvider.notifier);
      final loginSuccess = await authNotifier.login('user.a@rentcore.id', 'password');
      expect(loginSuccess, isTrue);

      final authState1 = container.read(authProvider);
      expect(authState1.isAuthenticated, isTrue);
      expect(authState1.user?['email'], 'user.a@rentcore.id');

      // Verify business context is loaded
      final bizState1 = container.read(businessProvider);
      expect(bizState1.activeBusinessId, 101);
      expect(bizState1.activeBusinessName, 'Tenant Alpha Store');
      expect(bizState1.activeBranchId, 201);
      expect(bizState1.businesses.length, 1);

      // Verify KPI data is loaded (NOT empty tenant zeroes)
      final kpi1 = await container.read(dashboardKpiProvider.future);
      expect(kpi1['is_empty_tenant'], isFalse);
      expect(kpi1['stats']['total_units'], 15);
      expect(kpi1['stats']['today_revenue'], 2500000);

      // Verify inventory data is loaded
      final inventory1 = await container.read(inventoryListProvider.future);
      expect(inventory1.length, 2);
      expect(inventory1.first['asset_code'], 'IP15-001');

      // Verify bookings data is loaded
      final bookings1 = await container.read(bookingsListProvider.future);
      expect(bookings1.length, 1);
      expect(bookings1.first['booking_code'], 'RC-2026-001');

      // Verify vouchers data is populated
      await container.read(voucherProvider.notifier).loadVouchers();
      expect(container.read(voucherProvider).vouchers.isNotEmpty, isTrue);

      // --- STEP 2: LOGOUT ---
      await authNotifier.logout();

      final authStateAfterLogout = container.read(authProvider);
      expect(authStateAfterLogout.isAuthenticated, isFalse);
      expect(authStateAfterLogout.user, isNull);

      final bizStateAfterLogout = container.read(businessProvider);
      expect(bizStateAfterLogout.activeBusinessId, isNull);
      expect(bizStateAfterLogout.businesses, isEmpty);

      // Verify voucher state is reset
      expect(container.read(voucherProvider).vouchers, isEmpty);

      // Verify hardware and base URL preferences preserved
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('active_business_id'), isNull);
      expect(prefs.getString('rentcore_printer_settings_v1'), '{"paperWidth":"mm80"}');
      expect(prefs.getString('api_base_url'), 'http://192.168.1.101:8000/api/v1');

      // --- STEP 3: SECOND LOGIN (SAME ACCOUNT, NO APP RESTART) ---
      final reloginSuccess = await authNotifier.login('user.a@rentcore.id', 'password');
      expect(reloginSuccess, isTrue);

      final authState2 = container.read(authProvider);
      expect(authState2.isAuthenticated, isTrue);

      // CRITICAL CHECK: Business context MUST be reloaded (was the bug!)
      final bizState2 = container.read(businessProvider);
      expect(bizState2.activeBusinessId, 101);
      expect(bizState2.activeBusinessName, 'Tenant Alpha Store');
      expect(bizState2.activeBranchId, 201);
      expect(bizState2.businesses.isNotEmpty, isTrue);

      // CRITICAL CHECK: Dashboard KPI reloads real data
      final kpi2 = await container.read(dashboardKpiProvider.future);
      expect(kpi2['is_empty_tenant'], isFalse);
      expect(kpi2['stats']['total_units'], 15);
      expect(kpi2['stats']['today_revenue'], 2500000);

      // CRITICAL CHECK: Inventory reloads non-empty devices
      final inventory2 = await container.read(inventoryListProvider.future);
      expect(inventory2.isNotEmpty, isTrue);
      expect(inventory2.length, 2);

      // CRITICAL CHECK: Bookings reloads
      final bookings2 = await container.read(bookingsListProvider.future);
      expect(bookings2.isNotEmpty, isTrue);
      expect(bookings2.length, 1);

      // CRITICAL CHECK: Vouchers reloads
      expect(container.read(voucherProvider).vouchers.isNotEmpty, isTrue);
    });

    test('Switching accounts: Logging into User Beta after User Alpha cleanly replaces tenant context', () async {
      final fakeAuthRepo = _FakeAuthRepository();

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
          assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepository()),
          voucherRepositoryProvider.overrideWithValue(_FakeVoucherRepository()),
        ],
      );
      addTearDown(container.dispose);

      // User A logs in
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('user.a@rentcore.id', 'password');
      expect(container.read(businessProvider).activeBusinessId, 101);

      // Populate voucher state
      await container.read(voucherProvider.notifier).loadVouchers();
      expect(container.read(voucherProvider).vouchers.isNotEmpty, isTrue);

      // User A logs out
      await authNotifier.logout();

      // Verify voucher state is reset
      expect(container.read(voucherProvider).vouchers, isEmpty);
      expect(container.read(organizationProvider).members, isEmpty);

      // User B logs in
      await authNotifier.login('user.b@rentcore.id', 'password');

      final authStateB = container.read(authProvider);
      expect(authStateB.user?['email'], 'user.b@rentcore.id');

      final bizStateB = container.read(businessProvider);
      expect(bizStateB.activeBusinessId, 102);
      expect(bizStateB.activeBusinessName, 'Tenant Beta Store');
      expect(bizStateB.activeBranchId, 202);
    });
  });
}

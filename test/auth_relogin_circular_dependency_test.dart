import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/core/models/paginated_result.dart';
import 'package:rentcore_mobile/core/network/network_status_provider.dart';
import 'package:rentcore_mobile/core/providers/app_config_provider.dart';
import 'package:rentcore_mobile/core/services/app_config_service.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/presentation/login_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/customers/data/customer_repository.dart';
import 'package:rentcore_mobile/features/customers/providers/customer_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';
import 'package:rentcore_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:rentcore_mobile/features/printer/providers/printer_provider.dart';
import 'package:rentcore_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:rentcore_mobile/features/vouchers/providers/voucher_provider.dart';
import 'package:rentcore_mobile/main.dart';

class _FakeAuthRepository extends AuthRepository {
  String? activeEmail;

  final Map<String, List<Map<String, dynamic>>> _businessesByEmail = {
    'owner.a@rentcore.id': [
      {
        'id': 101,
        'name': 'Alpha Rental Store',
        'role': 'owner',
        'branches': [
          {'id': 201, 'name': 'Alpha Central', 'code': 'ALP', 'is_central': true},
        ],
      },
      {
        'id': 102,
        'name': 'Alpha Secondary Store',
        'role': 'owner',
        'branches': [
          {'id': 202, 'name': 'Alpha Branch 2', 'code': 'AL2', 'is_central': true},
        ],
      },
    ],
    'owner.b@rentcore.id': [
      {
        'id': 301,
        'name': 'Beta Rental Store',
        'role': 'owner',
        'branches': [
          {'id': 401, 'name': 'Beta Central', 'code': 'BET', 'is_central': true},
        ],
      },
    ],
  };

  @override
  Future<Map<String, dynamic>?> checkSession() async => null;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    activeEmail = email;
    final businesses = _businessesByEmail[email] ?? [];
    final user = {
      'id': email == 'owner.a@rentcore.id' ? 1 : 2,
      'name': email == 'owner.a@rentcore.id' ? 'Owner Alpha' : 'Owner Beta',
      'email': email,
      'role': 'owner',
      'has_completed_walkthrough_v1': true,
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user['name'] as String);
    await prefs.setString('user_email', email);
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
      'token': 'token_for_$email',
      'user': user,
      'businesses': businesses,
    };
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    if (activeEmail == null) return [];
    return _businessesByEmail[activeEmail] ?? [];
  }

  @override
  Future<void> logout() async {
    activeEmail = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_business_id');
    await prefs.remove('active_business_name');
    await prefs.remove('active_branch_id');
    await prefs.remove('branch_name');
    await prefs.remove('branch_code');
    await prefs.remove('user_name');
    await prefs.remove('user_role');
    await prefs.remove('user_email');
  }
}

class _FakeDashboardRepository extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    return {
      'is_empty_tenant': false,
      'branch_id': branchId,
      'kpi': {
        'units_total': 10,
        'units_ready': 8,
        'units_rented': 2,
        'units_maintenance': 0,
        'today_revenue': 1500000,
        'active_rentals': 2,
        'overdue_count': 0,
      },
      'stats': {
        'total_units': 10,
        'ready_units': 8,
        'rented_units': 2,
        'maintenance_units': 0,
        'today_revenue': 1500000,
        'active_rentals': 2,
        'overdue_count': 0,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
      'recent_activities': [],
    };
  }
}

class _FakeBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async =>
      const [];
}

class _FakeAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    int? categoryId,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => const [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async =>
      const [];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      const [];
}

class _FakeCashierRepository extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async =>
      const {'shift_enforcement_enabled': false};

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async =>
      const {};

  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? paymentStatus,
    String? search,
  }) async =>
      const [];

  @override
  Future<Map<String, dynamic>> fetchExpenses({
    int? branchId,
    bool allBranches = false,
    String? startDate,
    String? endDate,
  }) async =>
      const {'expenses': [], 'total': 0};
}

class _FakeCustomerRepository extends CustomerRepository {
  @override
  Future<PaginatedResult<Map<String, dynamic>>> fetchCustomersPaginated({
    int page = 1,
    String? search,
    bool? isBlacklisted,
  }) async {
    return PaginatedResult.empty();
  }
}

class _FakeVoucherRepository extends VoucherRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchVouchers({
    String? status,
    String? search,
    dynamic branchId,
  }) async =>
      [
        {'id': 1, 'code': 'PROMO10', 'name': 'Diskon 10%'},
      ];
}

class _FakeAppConfigService extends AppConfigService {
  @override
  Future<AppConfigData?> fetchAppConfig() async => null;
}

class _IdleNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> fetchUnreadCountOnly() async {}
}

class _OnlineNetworkStatusNotifier extends NetworkStatusNotifier {
  @override
  NetworkStatus build() => NetworkStatus.online;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'api_base_url': 'http://127.0.0.1:8000/api/v1',
    });
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Login -> Logout -> Relogin Circular Dependency Regression Tests', () {
    test(
      'Full lifecycle in one ProviderContainer (with printerProvider, customerProvider, voucherProvider mounted) has zero CircularDependencyError',
      () async {
        final fakeAuthRepo = _FakeAuthRepository();
        final capturedErrors = <Object>[];

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepository()),
            assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
            cashierRepositoryProvider.overrideWithValue(_FakeCashierRepository()),
            customerRepositoryProvider.overrideWithValue(_FakeCustomerRepository()),
            voucherRepositoryProvider.overrideWithValue(_FakeVoucherRepository()),
          ],
        );
        addTearDown(container.dispose);

        // Keep auth, business, and printer providers actively listened to,
        // matching AuthRoutingGate + HomeScreen/StoreSettingsScreen.
        final authSub = container.listen(authProvider, (_, _) {});
        final bizSub = container.listen(businessProvider, (_, _) {});
        addTearDown(authSub.close);
        addTearDown(bizSub.close);

        // 1. Cold start (unauthenticated)
        await Future<void>.delayed(Duration.zero);
        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(container.read(businessProvider).activeBusinessId, isNull);

        // 2. First login() -> loads business/branch context successfully
        final firstLoginOk = await container
            .read(authProvider.notifier)
            .login('owner.a@rentcore.id', 'password');
        expect(firstLoginOk, isTrue);
        expect(container.read(authProvider).errorMessage, isNull);
        expect(container.read(authProvider).isAuthenticated, isTrue);

        final firstBiz = container.read(businessProvider);
        expect(firstBiz.activeBusinessId, 101);
        expect(firstBiz.activeBusinessName, 'Alpha Rental Store');
        expect(firstBiz.activeBranchId, 201);
        expect(firstBiz.activeBranchName, 'Alpha Central');

        // Mount downstream providers that previously formed circular dependencies:
        // - printerProvider listens to authProvider + businessProvider
        // - customerProvider & voucherProvider watch businessProvider
        // - onboardingProvider reads authProvider + businessProvider
        final printerSub = container.listen(
          printerProvider,
          (_, _) {},
          onError: (err, _) => capturedErrors.add(err),
        );
        final customerSub = container.listen(
          customerProvider,
          (_, _) {},
          onError: (err, _) => capturedErrors.add(err),
        );
        final voucherSub = container.listen(
          voucherProvider,
          (_, _) {},
          onError: (err, _) => capturedErrors.add(err),
        );
        final onboardingSub = container.listen(
          onboardingProvider,
          (_, _) {},
          onError: (err, _) => capturedErrors.add(err),
        );
        addTearDown(printerSub.close);
        addTearDown(customerSub.close);
        addTearDown(voucherSub.close);
        addTearDown(onboardingSub.close);

        await Future<void>.delayed(Duration.zero);
        expect(capturedErrors, isEmpty);

        // Verify switching business while customerProvider & voucherProvider are mounted
        // does NOT trigger CircularDependencyError in BusinessNotifier.
        final businesses = await fakeAuthRepo.fetchBusinesses();
        await container.read(businessProvider.notifier).selectBusiness(
          businesses[1] as Map<String, dynamic>,
        );
        expect(container.read(businessProvider).activeBusinessId, 102);

        // 3. Logout -> clears session and resets tenant state cleanly
        await container.read(authProvider.notifier).logout();
        await Future<void>.delayed(Duration.zero);

        final afterLogoutAuth = container.read(authProvider);
        expect(afterLogoutAuth.isAuthenticated, isFalse);
        expect(afterLogoutAuth.isLoading, isFalse);
        expect(afterLogoutAuth.user, isNull);

        final afterLogoutBiz = container.read(businessProvider);
        expect(afterLogoutBiz.activeBusinessId, isNull);
        expect(afterLogoutBiz.activeBranchId, isNull);
        expect(afterLogoutBiz.businesses, isEmpty);

        expect(container.read(printerProvider).hasEverConnectedPrinter, isFalse);

        // 4. Second login() -> succeeds with zero CircularDependencyError and restores context
        final secondLoginOk = await container
            .read(authProvider.notifier)
            .login('owner.a@rentcore.id', 'password');
        await Future<void>.delayed(Duration.zero);

        expect(secondLoginOk, isTrue);
        final afterSecondLoginAuth = container.read(authProvider);
        expect(afterSecondLoginAuth.isAuthenticated, isTrue);
        expect(afterSecondLoginAuth.errorMessage, isNull);

        final afterSecondLoginBiz = container.read(businessProvider);
        expect(afterSecondLoginBiz.activeBusinessId, 101);
        expect(afterSecondLoginBiz.activeBusinessName, 'Alpha Rental Store');
        expect(afterSecondLoginBiz.activeBranchId, 201);
        expect(afterSecondLoginBiz.activeBranchName, 'Alpha Central');
        expect(capturedErrors, isEmpty);

        // 5. Logout + login as a different account (owner.b) also succeeds cleanly
        await container.read(authProvider.notifier).logout();
        final thirdLoginOk = await container
            .read(authProvider.notifier)
            .login('owner.b@rentcore.id', 'password');
        await Future<void>.delayed(Duration.zero);

        expect(thirdLoginOk, isTrue);
        expect(container.read(authProvider).errorMessage, isNull);
        expect(container.read(businessProvider).activeBusinessId, 301);
        expect(container.read(businessProvider).activeBusinessName, 'Beta Rental Store');
        expect(container.read(businessProvider).activeBranchId, 401);
        expect(capturedErrors, isEmpty);
      },
    );

    testWidgets(
      'AuthRoutingGate widget tree survives Login -> HomeScreen/StoreSettingsScreen -> Logout -> Relogin without Circular dependency detected',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository();
        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            appConfigServiceProvider.overrideWithValue(_FakeAppConfigService()),
            networkStatusProvider.overrideWith(_OnlineNetworkStatusNotifier.new),
            notificationProvider.overrideWith(_IdleNotificationNotifier.new),
            dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepository()),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepository()),
            assetRepositoryProvider.overrideWithValue(_FakeAssetRepository()),
            cashierRepositoryProvider.overrideWithValue(_FakeCashierRepository()),
            customerRepositoryProvider.overrideWithValue(_FakeCustomerRepository()),
            voucherRepositoryProvider.overrideWithValue(_FakeVoucherRepository()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const AuthRoutingGate(),
              routes: {
                '/login': (_) => const AuthRoutingGate(),
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Cold start shows LoginScreen
        expect(find.byType(LoginScreen), findsOneWidget);

        // First login via UI button
        await tester.enterText(find.byType(TextField).at(0), 'owner.a@rentcore.id');
        await tester.enterText(find.byType(TextField).at(1), 'password');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(find.byType(MainShellScreen), findsOneWidget);
        expect(container.read(businessProvider).activeBusinessId, 101);
        expect(container.read(businessProvider).activeBranchId, 201);
        // printerProvider is now mounted by HomeScreen & StoreSettingsScreen
        expect(container.exists(printerProvider), isTrue);

        // Logout
        await container.read(authProvider.notifier).logout();
        await tester.pumpAndSettle();

        expect(find.byType(LoginScreen), findsOneWidget);
        expect(container.read(authProvider).isAuthenticated, isFalse);
        expect(container.read(businessProvider).activeBusinessId, isNull);

        // Second login via UI button
        await tester.enterText(find.byType(TextField).at(0), 'owner.a@rentcore.id');
        await tester.enterText(find.byType(TextField).at(1), 'password');
        await tester.tap(find.byKey(const Key('login_submit_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(container.read(authProvider).errorMessage, isNull);
        expect(container.read(authProvider).isAuthenticated, isTrue);
        expect(find.byType(MainShellScreen), findsOneWidget);
        expect(container.read(businessProvider).activeBusinessId, 101);
        expect(container.read(businessProvider).activeBranchId, 201);
      },
    );
  });
}

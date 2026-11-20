import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/core/network/api_client.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/presentation/login_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';
import 'package:rentcore_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';

class _ThrowingAuthRepository extends AuthRepository {
  int logoutCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchBusinesses() async => [
    {'id': 99, 'name': 'Active Rental Biz', 'role': 'owner'}
  ];

  @override
  Future<void> setActiveContext({
    required int businessId,
    required String businessName,
    int? branchId,
    String? branchName,
  }) async {}

  @override
  Future<void> logout() async {
    logoutCalls++;
    throw Exception('Simulated network/storage crash during logout');
  }
}

class _DelayedAuthRepository extends AuthRepository {
  final Completer<void> completer = Completer<void>();
  int logoutCalls = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchBusinesses() async => [
    {'id': 99, 'name': 'Active Rental Biz', 'role': 'owner'}
  ];

  @override
  Future<void> setActiveContext({
    required int businessId,
    required String businessName,
    int? branchId,
    String? branchName,
  }) async {}

  @override
  Future<void> logout() async {
    logoutCalls++;
    await completer.future;
  }
}

class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: {'id': 1, 'name': 'Hadi', 'role': 'owner'},
      );

  @override
  Future<void> checkCurrentSession() async {}
}

class _IdleNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> fetchUnreadCountOnly() async {}
}

class _CompletedOnboardingNotifier extends OnboardingNotifier {
  @override
  OnboardingState build() => const OnboardingState(
        hasCompletedWalkthrough: true,
        isLoading: false,
      );
}

class _MockAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [];

  @override
  Future<Map<String, dynamic>> updateAsset(int id, Map<String, dynamic> payload) async {
    return {'id': id, ...payload};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Issue 1: Logout Error & Preferences Preservation Tests', () {
    test('AuthRepository.logout() removes tenant session keys but preserves printer & config settings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_business_id', 1);
      await prefs.setString('active_business_name', 'RentCore Bali');
      await prefs.setInt('active_branch_id', 2);
      await prefs.setString('branch_name', 'Cabang Kuta');
      await prefs.setString('branch_code', 'KTA');
      await prefs.setString('api_base_url', 'http://192.168.1.101:8000/api/v1');
      await prefs.setString('google_server_client_id', 'custom-client-id.apps.googleusercontent.com');
      await prefs.setString('rentcore_printer_settings_v1', '{"paperWidth":"mm80"}');
      await prefs.setString('rentcore_printer_saved_device_v1', '{"name":"PT-210","mac":"00:11:22:33:44:55"}');

      final repo = AuthRepository();
      await repo.logout();

      // Tenant-specific session state must be wiped
      expect(prefs.getInt('active_business_id'), isNull);
      expect(prefs.getString('active_business_name'), isNull);
      expect(prefs.getInt('active_branch_id'), isNull);
      expect(prefs.getString('branch_name'), isNull);
      expect(prefs.getString('branch_code'), isNull);

      // Hardware and network configurations MUST be preserved across logout
      expect(prefs.getString('api_base_url'), 'http://192.168.1.101:8000/api/v1');
      expect(prefs.getString('google_server_client_id'), 'custom-client-id.apps.googleusercontent.com');
      expect(prefs.getString('rentcore_printer_settings_v1'), '{"paperWidth":"mm80"}');
      expect(prefs.getString('rentcore_printer_saved_device_v1'), '{"name":"PT-210","mac":"00:11:22:33:44:55"}');
    });

    test('AuthNotifier.logout() cleanly resets AuthState and BusinessState even when repository throws', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Populate business state as if a user was logged in
      final businessNotifier = container.read(businessProvider.notifier);
      await businessNotifier.selectBusiness({'id': 99, 'name': 'Active Rental Biz'});

      expect(container.read(businessProvider).activeBusinessId, 99);

      // Invoke logout which encounters the throwing repository
      await container.read(authProvider.notifier).logout();

      // Verify AuthState is unauthenticated and not loading
      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, false);
      expect(authState.isLoading, false);
      expect(authState.user, isNull);

      // Verify BusinessState is completely reset
      final bizState = container.read(businessProvider);
      expect(bizState.activeBusinessId, isNull);
      expect(bizState.activeBusinessName, isNull);
      expect(bizState.activeBranchId, isNull);
    });

    testWidgets('StoreSettingsScreen logout button prompts dialog and redirects cleanly to /login route', (tester) async {
      bool loginRoutePushed = false;

      final testBiz = const BusinessState(
        activeBusinessId: 99,
        activeBusinessName: 'Active Rental Biz',
        businesses: [
          {'id': 99, 'name': 'Active Rental Biz', 'role': 'owner'}
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
            businessProvider.overrideWith(() => _TestBusinessNotifier(testBiz)),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            routes: {
              '/login': (context) {
                loginRoutePushed = true;
                return const Scaffold(body: Text('LOGIN_SCREEN_LANDING'));
              },
            },
            home: const StoreSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to find and tap "Keluar Akun"
      final logoutTile = find.text('Keluar Akun');
      await tester.scrollUntilVisible(
        logoutTile,
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(logoutTile, findsOneWidget);
      await tester.tap(logoutTile);
      await tester.pumpAndSettle();

      // Confirm dialog appears
      expect(find.text('Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.'), findsOneWidget);
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Keluar');
      expect(confirmBtn, findsOneWidget);

      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Navigation backstack wiped and redirected to /login
      expect(loginRoutePushed, isTrue);
      expect(find.text('LOGIN_SCREEN_LANDING'), findsOneWidget);
    });

    test('AuthNotifier.logout() prevents duplicate concurrent calls and never gets stuck loading', () async {
      final delayedRepo = _DelayedAuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(delayedRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      final firstCall = notifier.logout();
      final duplicateCall = notifier.logout();

      expect(delayedRepo.logoutCalls, 1);
      expect(ApiClient.isLoggingOut, isTrue);

      delayedRepo.completer.complete();
      await Future.wait([firstCall, duplicateCall]);

      expect(delayedRepo.logoutCalls, 1);
      expect(ApiClient.isLoggingOut, isFalse);
      final state = container.read(authProvider);
      expect(state.isAuthenticated, isFalse);
      expect(state.isLoading, isFalse);
      expect(state.user, isNull);
    });

    test('ApiClient error interceptor skips onUnauthorized and connectivity drop for /auth/logout', () async {
      final client = ApiClient();
      int unauthorizedCalls = 0;
      int connectivityDrops = 0;
      client.onUnauthorized = () => unauthorizedCalls++;
      client.onConnectivityChanged = (connected) {
        if (!connected) connectivityDrops++;
      };
      addTearDown(() {
        client.onUnauthorized = null;
        client.onConnectivityChanged = null;
        ApiClient.isLoggingOut = false;
      });

      final interceptor = client.dio.interceptors.whereType<InterceptorsWrapper>().first;
      final handler = _RecordingErrorHandler();
      final logout401 = DioException(
        requestOptions: RequestOptions(path: '/auth/logout'),
        response: Response(
          requestOptions: RequestOptions(path: '/auth/logout'),
          statusCode: 401,
          data: {'message': 'Unauthenticated.'},
        ),
        type: DioExceptionType.badResponse,
      );

      interceptor.onError(logout401, handler);
      expect(unauthorizedCalls, 0);
      expect(connectivityDrops, 0);
      expect(handler.nextCalled, isTrue);
    });

    testWidgets('HomeScreen Left Drawer Keluar Akun clears session and renders LoginScreen without loading freeze', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final testBiz = const BusinessState(
        activeBusinessId: 99,
        activeBusinessName: 'Active Rental Biz',
        activeBranchId: 10,
        activeBranchName: 'Pusat',
        businesses: [
          {
            'id': 99,
            'name': 'Active Rental Biz',
            'role': 'owner',
            'branches': [
              {'id': 10, 'name': 'Pusat', 'is_central': true},
            ],
          },
        ],
      );

      final emptyKpi = <String, dynamic>{
        'kpi': {
          'total_revenue': 0,
          'active_rentals': 0,
          'overdue_rentals': 0,
          'ready_assets': 0,
          'rented_assets': 0,
          'maintenance_assets': 0,
          'fleet_total': 0,
          'today_bookings': 0,
          'today_returns': 0,
        },
        'overdue_list': [],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
            authProvider.overrideWith(() => _SignedInAuthNotifier()),
            businessProvider.overrideWith(() => _TestBusinessNotifier(testBiz)),
            onboardingProvider.overrideWith(() => _CompletedOnboardingNotifier()),
            notificationProvider.overrideWith(() => _IdleNotificationNotifier()),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyKpi)),
            dashboardQueueBookingsProvider.overrideWith((ref) => Future.value(const [])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Consumer(
              builder: (context, ref, _) {
                final auth = ref.watch(authProvider);
                if (!auth.isAuthenticated) {
                  return const LoginScreen();
                }
                if (auth.isLoading) {
                  return const Scaffold(body: Center(child: CircularProgressIndicator()));
                }
                return HomeScreen(onNavigateTab: (_) {});
              },
            ),
            routes: {
              '/login': (_) => const LoginScreen(),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open the Left Drawer via ScaffoldState
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold).first);
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('Keluar Akun'), findsOneWidget);
      await tester.tap(find.text('Keluar Akun'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('Issue 2: Inventory Device Detail Modal Tests', () {
    final mockBusiness = const BusinessState(
      activeBusinessId: 10,
      activeBusinessName: 'RentCore Store',
      businesses: [
        {'id': 10, 'name': 'RentCore Store'}
      ],
    );

    testWidgets('Tapping a rented asset card opens _EditAssetSheet without assertion error and displays locked banner', (tester) async {
      final rentedAsset = {
        'id': 101,
        'asset_code': 'IP15-001',
        'serial_number': 'SN-RENTED-999',
        'status': 'rented',
        'condition_grade': 'A',
        'battery_health': 98,
        'notes': 'Unit with active customer booking',
        'model': {
          'name': 'iPhone 15 Pro Max',
          'color': 'Natural Titanium',
          'storage_capacity': '256GB',
          'category': {'name': 'Smartphone'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([rentedAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card rendered
      expect(find.text('IP15-001'), findsOneWidget);
      expect(find.text('Sedang Sewa'), findsOneWidget);

      // Tap device card
      await tester.tap(find.text('IP15-001'));
      await tester.pumpAndSettle();

      // Verify sheet opened cleanly without assertion failure
      expect(find.text('Status Operasional Unit'), findsOneWidget);
      expect(find.text('Sedang Disewa (Terkunci)'), findsOneWidget);
      expect(find.textContaining('Unit sedang aktif disewa pelanggan'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
    });

    testWidgets('Tapping an in_transit asset card opens _EditAssetSheet without assertion error and displays mutasi banner', (tester) async {
      final inTransitAsset = {
        'id': 102,
        'asset_code': 'PS5-002',
        'serial_number': 'SN-TRANSIT-888',
        'status': 'in_transit',
        'condition_grade': 'B',
        'battery_health': null,
        'notes': 'Transfer to Kuta branch in progress',
        'model': {
          'name': 'PlayStation 5 Slim',
          'color': 'White',
          'storage_capacity': '1TB',
          'category': {'name': 'Game Console'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([inTransitAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PS5-002'), findsOneWidget);

      await tester.tap(find.text('PS5-002'));
      await tester.pumpAndSettle();

      expect(find.text('Status Operasional Unit'), findsOneWidget);
      expect(find.text('Dalam Mutasi (Terkunci)'), findsOneWidget);
      expect(find.textContaining('Unit sedang dalam perjalanan mutasi antar cabang'), findsOneWidget);
    });

    testWidgets('Tapping an asset with unknown status opens _EditAssetSheet gracefully with fallback item', (tester) async {
      final unknownStatusAsset = {
        'id': 103,
        'asset_code': 'CAM-003',
        'serial_number': 'SN-UNKNOWN-777',
        'status': 'audit_pending',
        'condition_grade': 'A',
        'battery_health': null,
        'notes': 'Custom backend status',
        'model': {
          'name': 'Sony Alpha A7 IV',
          'color': 'Black',
          'category': {'name': 'Kamera'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([unknownStatusAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAM-003'), findsOneWidget);

      await tester.tap(find.text('CAM-003'));
      await tester.pumpAndSettle();

      // Gracefully handles without throwing assertion error
      expect(find.text('audit_pending (Terkunci)'), findsOneWidget);
    });
  });
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

class _RecordingErrorHandler extends ErrorInterceptorHandler {
  bool nextCalled = false;

  @override
  void next(DioException err) {
    nextCalled = true;
  }
}

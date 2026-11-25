import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/home/data/dashboard_repository.dart';
import 'package:sewakasir/features/home/presentation/home_screen.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_profile_screen.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';
import 'package:sewakasir/shared/widgets/business_selector_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {
          'id': 1,
          'name': 'Raka Wirawan',
          'email': 'raka@kamehalabs.id',
          'role': 'owner',
        },
      );

  @override
  Future<void> checkCurrentSession() async {}
}

class _FakeAuthRepository extends AuthRepository {
  List<Map<String, dynamic>> businessesPayload;
  final bool failRefreshAfterUpdate;
  bool _hasUpdated = false;

  _FakeAuthRepository(
    this.businessesPayload, {
    this.failRefreshAfterUpdate = false,
  });

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    if (failRefreshAfterUpdate && _hasUpdated) {
      throw Exception('Simulated offline refresh');
    }
    return businessesPayload
        .map((b) => Map<String, dynamic>.from(b))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> updateBusiness(
    int businessId,
    Map<String, dynamic> payload,
  ) async {
    _hasUpdated = true;
    final targetKey = normalizeEntityId(businessId);
    Map<String, dynamic>? updated;
    businessesPayload = businessesPayload.map((b) {
      if (normalizeEntityId(b['id']) == targetKey) {
        final copy = Map<String, dynamic>.from(b);
        payload.forEach((k, v) => copy[k] = v);
        updated = copy;
        return copy;
      }
      return b;
    }).toList();
    return updated ?? <String, dynamic>{...payload, 'id': businessId};
  }
}

class _TrackingDashboardRepository extends DashboardRepository {
  final List<int?> requestedBranchIds = [];

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    requestedBranchIds.add(branchId);
    return {
      'is_empty_tenant': false,
      'branch_id': branchId,
      'is_consolidated': branchId == null,
      'kpi': {
        'units_total': branchId == 102 ? 8 : 14,
        'total_units': branchId == 102 ? 8 : 14,
        'units_ready': branchId == 102 ? 5 : 10,
        'units_rented': 3,
        'units_maintenance': 1,
        'active_rentals': 3,
        'pending_pickup_count': 0,
        'due_today_count': 0,
        'overdue_count': 0,
        'today_revenue': branchId == 102 ? 950000 : 1500000,
      },
    };
  }
}

class _EmptyBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async =>
      const [];
}

class _QuietNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final tenantBusinesses = [
    {
      'id': 10,
      'name': 'Kameha Rental Bali',
      'role': 'owner',
      'branches': [
        {
          'id': 101,
          'name': 'Cabang Pusat',
          'code': 'PST',
          'city': null,
          'address': null,
          'is_central': true,
        },
        {
          'id': 102,
          'name': 'Cabang Ubud',
          'code': 'UBD',
          'city': 'Gianyar',
          'is_central': false,
        },
      ],
    },
  ];

  group('BusinessNotifier single source of truth & reactive updates', () {
    test(
      'loadInitialContext prefers fresh API store & branch names over stale SharedPreferences and handles String IDs',
      () async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': '10',
          'active_business_name': 'Nama Usaha Lama',
          'active_branch_id': '101',
          'branch_name': 'Cabang Lama',
        });

        final stringIdBusinesses = [
          {
            'id': '10',
            'name': 'awansky',
            'role': 'owner',
            'branches': [
              {
                'id': '101',
                'name': 'Cabang Utama',
                'code': 'UTM',
                'city': null,
                'is_central': true,
              },
            ],
          },
        ];

        final fakeRepo = _FakeAuthRepository(stringIdBusinesses);
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();
        final bState = container.read(businessProvider);

        expect(bState.activeBusinessId, equals(10));
        expect(bState.resolvedStoreName, equals('awansky'));
        expect(bState.resolvedBranchName, equals('Cabang Utama'));
        expect(bState.activeBranch?['id'], equals('101'));

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('active_business_name'), equals('awansky'));
        expect(prefs.getString('branch_name'), equals('Cabang Utama'));
      },
    );

    test(
      'updateActiveBusinessProfile & updateActiveBranchMetadata update state & prefs immediately',
      () async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 10,
          'active_business_name': 'Kameha Rental Bali',
          'active_branch_id': 101,
          'branch_name': 'Cabang Pusat',
        });

        final fakeRepo = _FakeAuthRepository(tenantBusinesses);
        final container = ProviderContainer(
          overrides: [authRepositoryProvider.overrideWithValue(fakeRepo)],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        await container
            .read(businessProvider.notifier)
            .updateActiveBusinessProfile(10, {'name': 'Kameha Pro Gear'});
        await container
            .read(businessProvider.notifier)
            .updateActiveBranchMetadata(101, name: 'Cabang Seminyak');

        final updated = container.read(businessProvider);
        expect(updated.resolvedStoreName, equals('Kameha Pro Gear'));
        expect(updated.resolvedBranchName, equals('Cabang Seminyak'));
        expect(updated.activeBusiness?['name'], equals('Kameha Pro Gear'));
        expect(updated.activeBranch?['name'], equals('Cabang Seminyak'));

        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getString('active_business_name'),
          equals('Kameha Pro Gear'),
        );
        expect(prefs.getString('branch_name'), equals('Cabang Seminyak'));
      },
    );
  });

  group('Dashboard, Branch Selector, Store Profile & Settings consistency', () {
    testWidgets(
      'Dashboard header and Branch Selector render dynamic tenant names, omit null cities without Denpasar, and update on branch switch & rename',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 10,
          'active_business_name': 'Kameha Rental Bali',
          'active_branch_id': 101,
          'branch_name': 'Cabang Pusat',
        });

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository(tenantBusinesses);
        final trackingDashboardRepo = _TrackingDashboardRepository();

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            dashboardRepositoryProvider.overrideWithValue(
              trackingDashboardRepo,
            ),
            bookingRepositoryProvider.overrideWithValue(
              _EmptyBookingRepository(),
            ),
            notificationProvider.overrideWith(
              () => _QuietNotificationNotifier(),
            ),
            currentShiftByBranchProvider.overrideWith(
              (ref, branchId) async => {'has_active_shift': false},
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: HomeScreen(onNavigateTab: (_) {})),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kameha Rental Bali'), findsOneWidget);
        expect(find.text('Cabang Pusat'), findsOneWidget);
        expect(find.text('RentCore'), findsNothing);
        expect(find.textContaining('SkyRental'), findsNothing);
        expect(find.textContaining('Denpasar'), findsNothing);
        expect(trackingDashboardRepo.requestedBranchIds, contains(101));

        // Open Branch Selector modal and verify active store name + no Denpasar default
        await tester.tap(find.byKey(const Key('home_header_branch_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Cabang'), findsOneWidget);
        expect(find.text('Kameha Rental Bali'), findsWidgets);
        expect(find.textContaining('Rental Business'), findsNothing);
        expect(find.textContaining('Denpasar'), findsNothing);
        expect(find.text('Cabang Pusat'), findsWidgets);
        expect(find.text('Cabang Ubud'), findsOneWidget);

        // Switch branch to Cabang Ubud
        await tester.tap(find.text('Cabang Ubud'));
        await tester.pumpAndSettle();

        expect(find.text('Cabang Ubud'), findsOneWidget);
        expect(trackingDashboardRepo.requestedBranchIds, contains(102));

        // Rename active store & branch in memory
        await container
            .read(businessProvider.notifier)
            .updateActiveBusinessProfile(10, {'name': 'Kameha Nusantara'});
        await container
            .read(businessProvider.notifier)
            .updateActiveBranchMetadata(102, name: 'Cabang Ubud Raya');
        await tester.pumpAndSettle();

        expect(find.text('Kameha Nusantara'), findsOneWidget);
        expect(find.text('Cabang Ubud Raya'), findsOneWidget);
      },
    );

    testWidgets(
      'Renaming a business in StoreProfileScreen immediately updates HomeScreen header and BusinessSelectorSheet even with String JSON IDs and offline refresh',
      (tester) async {
        final stringBusinesses = [
          {
            'id': '15',
            'name': 'awanrental',
            'role': 'owner',
            'slogan': 'Sewa Kamera',
            'address': '',
            'phone': '08123456789',
            'branches': [
              {
                'id': '201',
                'name': 'Cabang Utama',
                'code': 'AWN',
                'city': null,
                'address': null,
                'is_central': true,
              },
            ],
          },
        ];

        SharedPreferences.setMockInitialValues({
          'active_business_id': '15',
          'active_business_name': 'awanrental',
          'active_branch_id': '201',
          'branch_name': 'Cabang Utama',
        });

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository(
          stringBusinesses,
          failRefreshAfterUpdate: true,
        );
        final trackingDashboardRepo = _TrackingDashboardRepository();

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            dashboardRepositoryProvider.overrideWithValue(
              trackingDashboardRepo,
            ),
            bookingRepositoryProvider.overrideWithValue(
              _EmptyBookingRepository(),
            ),
            notificationProvider.overrideWith(
              () => _QuietNotificationNotifier(),
            ),
            currentShiftByBranchProvider.overrideWith(
              (ref, branchId) async => {'has_active_shift': false},
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Builder(
                builder: (context) => HomeScreen(
                  onNavigateTab: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('awanrental'), findsOneWidget);

        // Push StoreProfileScreen directly on the Navigator to simulate Settings -> Profil Usaha & Toko
        final navigator = tester.state<NavigatorState>(find.byType(Navigator));
        navigator.push(
          MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
        );
        await tester.pumpAndSettle();

        final nameField = find.widgetWithText(TextFormField, 'awanrental');
        expect(nameField, findsOneWidget);
        await tester.enterText(nameField, 'awansky');
        await tester.pump();

        await tester.tap(find.text('Simpan Profil Toko'));
        await tester.pumpAndSettle();

        // Back on HomeScreen: header immediately reflects 'awansky' (not 'awanrental')
        expect(find.text('awansky'), findsOneWidget);
        expect(find.text('awanrental'), findsNothing);

        // Open BusinessSelectorSheet ("Pilih Cabang") and verify header + list show 'awansky' and no 'Denpasar'
        await tester.tap(find.byKey(const Key('home_header_branch_button')));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Cabang'), findsOneWidget);
        expect(find.text('awansky • 1 Cabang'), findsOneWidget);
        expect(find.text('awanrental'), findsNothing);
        expect(find.textContaining('Denpasar'), findsNothing);
      },
    );

    testWidgets(
      'BusinessSelectorSheet onboarding dialog starts with empty city (never Denpasar)',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 10,
          'active_business_name': 'Kameha Rental Bali',
          'active_branch_id': 101,
          'branch_name': 'Cabang Pusat',
        });

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository(tenantBusinesses);
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: BusinessSelectorSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Buat Usaha / Bisnis Baru'));
        await tester.pumpAndSettle();

        expect(find.text('Denpasar'), findsNothing);
        expect(find.textContaining('Denpasar'), findsNothing);
      },
    );

    testWidgets(
      'StoreSettingsScreen displays dynamic store & branch names and reacts immediately to renames',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 10,
          'active_business_name': 'Kameha Rental Bali',
          'active_branch_id': 101,
          'branch_name': 'Cabang Pusat',
        });

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository(tenantBusinesses);
        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: StoreSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Kameha Rental Bali • Cabang Pusat'), findsOneWidget);
        expect(find.text('Pengguna RentCore'), findsNothing);
        expect(find.text('Bisnis Rental'), findsNothing);

        await container
            .read(businessProvider.notifier)
            .updateActiveBusinessProfile(10, {'name': 'Kameha Nusantara'});
        await container
            .read(businessProvider.notifier)
            .updateActiveBranchMetadata(101, name: 'Cabang Kuta');
        await tester.pumpAndSettle();

        expect(find.text('Kameha Nusantara • Cabang Kuta'), findsOneWidget);
      },
    );

    testWidgets(
      'BusinessSelectorSheet refreshes stale DB store name on open and reacts immediately to branch edit',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          'active_business_id': 20,
          'active_business_name': 'AwanRental',
          'active_branch_id': 201,
          'branch_name': 'AwanRental Pusat',
        });

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeAuthRepo = _FakeAuthRepository([
          {
            'id': 20,
            'name': 'AwanRental',
            'role': 'owner',
            'branches': [
              {
                'id': 201,
                'name': 'AwanRental Pusat',
                'code': 'AWA',
                'city': 'Denpasar',
                'is_central': true,
              },
            ],
          },
        ]);

        final container = ProviderContainer(
          overrides: [
            authProvider.overrideWith(() => _MockAuthNotifier()),
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(businessProvider.notifier).loadInitialContext();

        // Simulate external DB rename to AwanRentalSky & clearing Denpasar city
        fakeAuthRepo.businessesPayload = [
          {
            'id': 20,
            'name': 'AwanRentalSky',
            'role': 'owner',
            'branches': [
              {
                'id': 201,
                'name': 'AwanRentalSky Pusat',
                'code': 'SKY',
                'city': null,
                'is_central': true,
              },
            ],
          },
        ];

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(body: BusinessSelectorSheet()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pilih Cabang'), findsOneWidget);
        expect(find.text('AwanRentalSky • 1 Cabang'), findsOneWidget);
        expect(find.text('AwanRentalSky Pusat'), findsOneWidget);
        expect(find.text('SKY'), findsOneWidget);
        expect(find.textContaining('Denpasar'), findsNothing);

        // Simulate branch edit clearing/changing name, code, and city
        await container
            .read(businessProvider.notifier)
            .updateActiveBranchMetadata(
              201,
              name: 'Cabang Surabaya',
              code: 'SBY',
              city: 'Surabaya',
              updateLocationFields: true,
            );
        await tester.pumpAndSettle();

        expect(find.text('Cabang Surabaya'), findsOneWidget);
        expect(find.text('SBY'), findsOneWidget);
        expect(find.text('Surabaya'), findsOneWidget);
      },
    );
  });
}

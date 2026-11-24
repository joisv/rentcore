import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/presentation/login_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';
import 'package:rentcore_mobile/features/onboarding/presentation/business_setup_wizard_screen.dart';
import 'package:rentcore_mobile/features/onboarding/presentation/feature_walkthrough_screen.dart';
import 'package:rentcore_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:rentcore_mobile/main.dart';

class _StubGateNotificationNotifier extends NotificationNotifier {
  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}
}

class _FakeGateAuthRepository extends AuthRepository {
  final Map<String, dynamic>? mockSessionData;
  final bool mockWalkthroughCompleted;

  _FakeGateAuthRepository({
    this.mockSessionData,
    this.mockWalkthroughCompleted = false,
  });

  @override
  Future<Map<String, dynamic>?> checkSession() async {
    return mockSessionData;
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    final list = mockSessionData?['businesses'];
    if (list is List) return list;
    return [];
  }

  @override
  Future<bool> isWalkthroughCompleted({String? userId}) async {
    return mockWalkthroughCompleted;
  }
}

class _FakeGateBookingRepository extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async => [];
}

class _FakeGateAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    int? branchId,
    String? status,
    int? categoryId,
    String? search,
    int page = 1,
    bool allBranches = false,
  }) async => [];

  @override
  Future<List<dynamic>> fetchAssetModels({int? categoryId}) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('AuthRoutingGate: Unauthenticated user routes to LoginScreen',
      (tester) async {
    final repo = _FakeGateAuthRepository(mockSessionData: null);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: AuthRoutingGate(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(BusinessSetupWizardScreen), findsNothing);
  });

  testWidgets('AuthRoutingGate: New Tenant Owner (0 businesses) routes to BusinessSetupWizardScreen',
      (tester) async {
    final repo = _FakeGateAuthRepository(
      mockSessionData: {
        'user': {
          'id': 'owner-uuid-1',
          'name': 'Budi Owner',
          'email': 'owner@rentcore.id',
          'role': 'staff', // System default role before store registration
          'is_platform_admin': false,
        },
        'businesses': [], // 0 businesses registered
      },
      mockWalkthroughCompleted: false,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: AuthRoutingGate(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(BusinessSetupWizardScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(MainShellScreen), findsNothing);
  });

  testWidgets('AuthRoutingGate: Invited Staff (with assigned store) bypasses wizard to FeatureWalkthroughScreen',
      (tester) async {
    final repo = _FakeGateAuthRepository(
      mockSessionData: {
        'user': {
          'id': 'staff-uuid-2',
          'name': 'Siti Kasir',
          'email': 'kasir@rentcore.id',
          'role': 'staff',
          'is_platform_admin': false,
        },
        'businesses': [
          {
            'id': 101,
            'name': 'Skyrental Jember',
            'role': 'staff', // Pre-bound invited staff membership
            'branches': [
              {'id': 201, 'name': 'Cabang Utama', 'code': 'JBR', 'is_central': true}
            ],
          }
        ],
      },
      mockWalkthroughCompleted: false, // First time on device
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
        child: const MaterialApp(
          home: AuthRoutingGate(),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(FeatureWalkthroughScreen), findsOneWidget);
    expect(find.byType(BusinessSetupWizardScreen), findsNothing);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('AuthRoutingGate: Existing user with completed walkthrough routes to MainShellScreen',
      (tester) async {
    final repo = _FakeGateAuthRepository(
      mockSessionData: {
        'user': {
          'id': 'owner-uuid-3',
          'name': 'Ahmad Owner',
          'email': 'ahmad@rentcore.id',
          'role': 'staff',
          'is_platform_admin': false,
          'has_completed_walkthrough_v1': true,
        },
        'businesses': [
          {
            'id': 101,
            'name': 'Skyrental Jember',
            'role': 'owner',
            'branches': [
              {'id': 201, 'name': 'Cabang Utama', 'code': 'JBR', 'is_central': true}
            ],
          }
        ],
      },
      mockWalkthroughCompleted: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          bookingRepositoryProvider.overrideWithValue(_FakeGateBookingRepository()),
          assetRepositoryProvider.overrideWithValue(_FakeGateAssetRepository()),
          dashboardKpiProvider.overrideWith((ref) => Future.value(<String, dynamic>{})),
          dashboardQueueBookingsProvider.overrideWith((ref) => Future.value([])),
          notificationProvider.overrideWith(_StubGateNotificationNotifier.new),
          closingSummaryProvider.overrideWith((ref) => Future.value(<String, dynamic>{})),
        ],
        child: const MaterialApp(
          home: AuthRoutingGate(),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(MainShellScreen), findsOneWidget);
    expect(find.byType(BusinessSetupWizardScreen), findsNothing);
    expect(find.byType(FeatureWalkthroughScreen), findsNothing);
  });
}

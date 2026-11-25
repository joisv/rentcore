import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/home/data/dashboard_repository.dart';
import 'package:sewakasir/features/home/presentation/home_screen.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDashboardRepo extends DashboardRepository {
  final Map<String, dynamic> data;
  _FakeDashboardRepo(this.data);

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => data;
}

class _FakeBookingRepo extends BookingRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async => [];
}

class _FakeAssetRepo extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({
    int? categoryId,
    String? search,
  }) async => [];
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Express',
    activeBranchId: 10,
    activeBranchName: 'Cabang Mataram Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Express',
        'role': 'owner',
        'branches': [
          {
            'id': 10,
            'name': 'Cabang Mataram Utama',
            'city': 'Mataram',
            'is_central': true,
          },
        ],
      },
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Kasir Utama', 'role': 'owner'},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('HomeScreen 2x2 Daily Operations Metrics Grid Tests', () {
    final testKpiData = {
      'is_empty_tenant': false,
      'branch_id': 10,
      'is_consolidated': false,
      'kpi': {
        'today_revenue': 1450000.0,
        'today_transactions_count': 8,
        'today_rentals_created': 8,
        'active_rentals': 6,
        'pending_pickup_count': 2,
        'due_today': 5,
        'due_today_count': 5,
        'overdue': 3,
        'overdue_count': 3,
        'units_ready': 12,
        'total_units_count': 20,
        'units_total': 20,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
    };

    Widget createTestApp({
      required WidgetRef? Function(WidgetRef)? onRefAvailable,
      ValueChanged<int>? onNavigateTab,
    }) {
      return ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          dashboardRepositoryProvider.overrideWithValue(
            _FakeDashboardRepo(testKpiData),
          ),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
          assetRepositoryProvider.overrideWithValue(_FakeAssetRepo()),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            onRefAvailable?.call(ref);
            return MaterialApp(
              theme: AppTheme.lightTheme,
              home: HomeScreen(
                onNavigateTab: onNavigateTab ?? (_) {},
                onOpenDirectRental: () {},
              ),
            );
          },
        ),
      );
    }

    testWidgets('1. Visual layout, typography, chevrons, and subtexts render correctly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestApp(onRefAvailable: null));
      await tester.pumpAndSettle();

      // Verify all 4 card labels
      expect(find.text('Pendapatan'), findsOneWidget);
      expect(find.text('Sewa Aktif'), findsOneWidget);
      expect(find.text('Pengembalian'), findsOneWidget);
      expect(find.text('Unit Tersedia'), findsOneWidget);

      // Verify primary metric values
      expect(find.text('Rp 1.450.000'), findsOneWidget);
      expect(find.text('6 Unit'), findsOneWidget);
      expect(find.text('5 Unit'), findsOneWidget);
      expect(find.text('12 Unit Siap'), findsOneWidget);

      // Verify contextual subtexts
      expect(find.text('Hari ini • 8 transaksi'), findsOneWidget);
      expect(find.text('2 menunggu diambil'), findsOneWidget);
      expect(find.text('3 terlambat • 5 hari ini'), findsOneWidget);
      expect(find.text('Dari total 20 unit'), findsOneWidget);

      // Verify 4 chevrons signalling clickability on the 4 metric cards
      final metricChevrons = find.byWidgetPredicate(
        (w) =>
            w is Icon &&
            w.icon == Icons.chevron_right_rounded &&
            w.color == const Color(0xFF94A3B8),
      );
      expect(metricChevrons, findsNWidgets(4));

      // Verify zero legacy icon clutter
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
      expect(find.byIcon(Icons.devices_other_rounded), findsNothing);

      // Verify InkWell and Material presence for tactile touch feedback
      expect(find.byType(InkWell), findsWidgets);
      expect(find.byType(Material), findsWidgets);

      // Verify unified 2x2 KPI matrix container and internal #F1F5F9 hairline dividers
      final matrixContainer = tester.widget<Container>(
        find.byKey(const Key('home_kpi_matrix_container')),
      );
      final matrixDecoration = matrixContainer.decoration as BoxDecoration;
      expect(matrixDecoration.color, const Color(0xFFFFFFFF));
      expect(matrixDecoration.borderRadius, BorderRadius.circular(16));
      expect(
        matrixDecoration.border,
        Border.all(color: const Color(0xFFE2E8F0)),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home_kpi_matrix_container')),
          matching: find.byWidgetPredicate(
            (w) => w is VerticalDivider && w.color == const Color(0xFFF1F5F9),
          ),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('home_kpi_matrix_container')),
          matching: find.byWidgetPredicate(
            (w) => w is Divider && w.color == const Color(0xFFF1F5F9),
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('2. Card 1 (Pendapatan) navigates to Laporan tab (index 1)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedTab = -1;
      await tester.pumpWidget(
        createTestApp(
          onRefAvailable: null,
          onNavigateTab: (idx) => navigatedTab = idx,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pendapatan'));
      await tester.pumpAndSettle();

      expect(navigatedTab, 1);
    });

    testWidgets('3. Card 2 (Sewa Aktif) keeps user on Beranda queue with Semua filter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedTab = -1;
      await tester.pumpWidget(
        createTestApp(
          onRefAvailable: null,
          onNavigateTab: (idx) => navigatedTab = idx,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sewa Aktif'));
      await tester.pumpAndSettle();

      expect(navigatedTab, -1);
      expect(find.text('Antrean Sewa Cabang'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
    });

    testWidgets('4. Card 3 (Pengembalian) filters Beranda queue to Terlambat', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      int navigatedTab = -1;
      await tester.pumpWidget(
        createTestApp(
          onRefAvailable: null,
          onNavigateTab: (idx) => navigatedTab = idx,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pengembalian'));
      await tester.pumpAndSettle();

      expect(navigatedTab, -1);
      expect(find.text('Tampilkan Semua'), findsOneWidget);
    });

    testWidgets('5. Card 4 (Unit Tersedia) navigates to InventoryScreen with ready filter', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      WidgetRef? testRef;
      await tester.pumpWidget(createTestApp(onRefAvailable: (ref) {
        testRef = ref;
        return ref;
      }));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Unit Tersedia'));
      await tester.pumpAndSettle();

      expect(find.byType(InventoryScreen), findsOneWidget);
      if (testRef != null) {
        expect(testRef!.read(selectedAssetStatusFilterProvider), 'ready');
      }
    });
  });
}

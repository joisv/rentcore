import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';

class _FakeDashboardRepository extends DashboardRepository {
  final List<int?> recordedBranchRequests = [];
  final Map<int?, Map<String, dynamic>> stubbedKpis = {};

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    recordedBranchRequests.add(branchId);
    if (stubbedKpis.containsKey(branchId)) {
      return stubbedKpis[branchId]!;
    }
    return {
      'stats': {
        'total_units': 10,
        'ready_units': 8,
        'rented_units': 2,
        'maintenance_units': 0,
        'today_revenue': 1500000,
      },
    };
  }
}

class _FakeCashierRepository extends CashierRepository {
  final List<int?> recordedClosingSummaryBranchRequests = [];
  final List<int?> recordedBookingsBranchRequests = [];

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    recordedClosingSummaryBranchRequests.add(branchId);
    return {
      'total_revenue': branchId == 10 ? 500000 : (branchId == 20 ? 300000 : 800000),
      'transactions_count': branchId == 10 ? 2 : (branchId == 20 ? 1 : 3),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    recordedBookingsBranchRequests.add(branchId);
    return [
      {'id': 1, 'affiliate_id': branchId ?? 10, 'booking_code': 'RC-001'},
    ];
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;

  void changeBranch(int? newBranchId, String? newBranchName) {
    state = state.copyWith(
      activeBranchId: newBranchId,
      activeBranchName: newBranchName,
      clearBranch: newBranchId == null,
    );
  }
}

void main() {
  group('Branch-Aware Dashboard KPI Tests', () {
    test('dashboardKpiProvider returns empty stats when no active business', () async {
      final fakeRepo = _FakeDashboardRepository();
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(
              const BusinessState(activeBusinessId: null, businesses: []),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final kpi = await container.read(dashboardKpiProvider.future);
      expect(kpi['is_empty_tenant'], true);
      expect(kpi['stats']['total_units'], 0);
      expect(fakeRepo.recordedBranchRequests, isEmpty);
    });

    test('dashboardKpiProvider scopes fetchKpi with activeBranchId', () async {
      final fakeRepo = _FakeDashboardRepository();
      fakeRepo.stubbedKpis[101] = {
        'stats': {
          'total_units': 5,
          'ready_units': 3,
          'rented_units': 2,
          'maintenance_units': 0,
          'today_revenue': 750000,
        },
      };

      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(
              const BusinessState(
                activeBusinessId: 1,
                activeBusinessName: 'RentCore Central',
                activeBranchId: 101,
                activeBranchName: 'Cabang Barat',
                businesses: [{'id': 1, 'name': 'RentCore Central'}],
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final kpi = await container.read(dashboardKpiProvider.future);
      expect(fakeRepo.recordedBranchRequests, contains(101));
      expect(kpi['stats']['today_revenue'], 750000);
      expect(kpi['stats']['total_units'], 5);
    });

    test('Switching activeBranchId invalidates and refetches dashboardKpiProvider', () async {
      final fakeRepo = _FakeDashboardRepository();
      fakeRepo.stubbedKpis[10] = {
        'stats': {'today_revenue': 500000, 'total_units': 3},
      };
      fakeRepo.stubbedKpis[20] = {
        'stats': {'today_revenue': 1200000, 'total_units': 7},
      };

      final notifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 1,
          activeBusinessName: 'RentCore Central',
          activeBranchId: 10,
          activeBranchName: 'Cabang 10',
          businesses: [{'id': 1, 'name': 'RentCore Central'}],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Branch 10
      final kpiBranch10 = await container.read(dashboardKpiProvider.future);
      expect(kpiBranch10['stats']['today_revenue'], 500000);
      expect(fakeRepo.recordedBranchRequests.last, 10);

      // Switch to Branch 20
      notifier.changeBranch(20, 'Cabang 20');
      final kpiBranch20 = await container.read(dashboardKpiProvider.future);
      expect(kpiBranch20['stats']['today_revenue'], 1200000);
      expect(fakeRepo.recordedBranchRequests.last, 20);

      // Switch to Consolidated view (activeBranchId: null)
      notifier.changeBranch(null, 'Semua Cabang (Konsolidasi)');
      final kpiConsolidated = await container.read(dashboardKpiProvider.future);
      expect(fakeRepo.recordedBranchRequests.last, isNull);
      expect(kpiConsolidated['stats']['today_revenue'], 1500000);
    });
  });

  group('Branch-Aware Cashier Summary & Bookings Tests', () {
    test('closingSummaryProvider scopes fetchClosingSummary with activeBranchId', () async {
      final fakeCashier = _FakeCashierRepository();
      final notifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 1,
          activeBranchId: 10,
          businesses: [{'id': 1, 'name': 'RentCore Central'}],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(fakeCashier),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final summary10 = await container.read(closingSummaryProvider.future);
      expect(fakeCashier.recordedClosingSummaryBranchRequests.last, 10);
      expect(summary10['total_revenue'], 500000);

      notifier.changeBranch(20, 'Cabang 20');
      final summary20 = await container.read(closingSummaryProvider.future);
      expect(fakeCashier.recordedClosingSummaryBranchRequests.last, 20);
      expect(summary20['total_revenue'], 300000);
    });

    test('cashierBookingsProvider scopes queries with activeBranchId', () async {
      final fakeCashier = _FakeCashierRepository();
      final notifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 1,
          activeBranchId: 15,
          businesses: [{'id': 1, 'name': 'RentCore Central'}],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          cashierRepositoryProvider.overrideWithValue(fakeCashier),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      final bookings = await container.read(cashierBookingsProvider(null).future);
      expect(fakeCashier.recordedBookingsBranchRequests.last, 15);
      expect(bookings, isNotEmpty);
      expect(bookings.first['affiliate_id'], 15);
    });
  });
}

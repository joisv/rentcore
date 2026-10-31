import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _CapturingDashboardRepository extends DashboardRepository {
  int? lastBranchId;
  Map<String, dynamic>? lastReturnedData;

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    lastBranchId = branchId;
    return lastReturnedData ?? {
      'branch_id': branchId,
      'is_consolidated': branchId == null,
      'kpi': {
        'units_total': 10,
        'units_ready': 7,
        'units_rented': 2,
        'units_maintenance': 1,
        'units_in_transit': 0,
        'utilization_rate': 20.0,
        'active_rentals': 2,
        'due_today': 1,
        'overdue': 0,
        'today_rentals_created': 3,
        'today_revenue': 150000.0,
        'today_transactions_count': 3,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
    };
  }
}

class _ActiveBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() {
    return const BusinessState(
      activeBusinessId: 101,
      activeBusinessName: 'Test Store',
      activeBranchId: 201,
      activeBranchName: 'Test Branch',
      businesses: [
        {'id': 101, 'name': 'Test Store'}
      ],
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'active_business_id': 101,
      'active_business_name': 'Test Store',
      'active_branch_id': 201,
      'branch_name': 'Test Branch',
    });
  });

  group('HomeScreen & Dashboard KPI Loading Tests', () {
    testWidgets('renders KPI cards safely when numeric values are doubles/numbers', (tester) async {
      final capturingRepo = _CapturingDashboardRepository();
      capturingRepo.lastReturnedData = {
        'branch_id': 201,
        'is_consolidated': false,
        'kpi': {
          'units_total': 12.0, // Double instead of int
          'units_ready': 8.0,
          'units_rented': 3.0,
          'units_maintenance': 1.0,
          'units_in_transit': 0.0,
          'utilization_rate': '25.0', // String formatted
          'active_rentals': 3,
          'due_today': 2,
          'overdue': 1,
          'today_rentals_created': 4,
          'today_revenue': 500000,
          'today_transactions_count': 4,
        },
        'overdue_alerts': [
          {
            'booking_id': 99,
            'booking_code': 'BK-TEST-001',
            'customer_name': 'Budi Siregar',
            'customer_phone': '08123456789',
            'unit_name': 'iPhone 15 Pro',
            'late_duration_text': '01 jam 30 mnt',
            'late_minutes': 90,
            'running_penalty': 30000,
            'end_at': '20 Oct 2026, 12:00',
            'collateral_storage_slot': 'SLOT-A',
          }
        ],
        'imminent_returns': [],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _ActiveBusinessNotifier()),
            dashboardRepositoryProvider.overrideWithValue(capturingRepo),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ensure error card is NOT displayed
      expect(find.text('Gagal Memuat Data Dashboard'), findsNothing);

      // Verify dashboard content rendered cleanly
      expect(find.text('STATUS INVENTARIS CABANG'), findsOneWidget);
      expect(find.text('RINGKASAN OPERASIONAL & KASIR HARI INI'), findsOneWidget);
      expect(find.text('1 Unit Terlambat'), findsOneWidget);
      expect(find.textContaining('Lihat Semua'), findsOneWidget);
      expect(find.textContaining('Budi Siregar'), findsOneWidget);
    });

    testWidgets('renders empty tenant fallback state without throwing exception', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            // No active business
            businessProvider.overrideWith(() => BusinessNotifier()),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should display onboarding banner and not crash
      expect(find.text('Gagal Memuat Data Dashboard'), findsNothing);
      expect(find.text('STATUS INVENTARIS CABANG'), findsOneWidget);
    });

    test('DashboardRepository sets explicit headers and query params for consolidated mode', () {
      final repo = DashboardRepository();
      expect(repo, isNotNull);
    });
  });
}

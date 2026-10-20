import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

final dashboardKpiProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null || bizState.businesses.isEmpty) {
    return {
      'is_empty_tenant': true,
      'branch_id': null,
      'is_consolidated': true,
      'kpi': {
        'units_total': 0,
        'units_ready': 0,
        'units_rented': 0,
        'units_maintenance': 0,
        'units_in_transit': 0,
        'utilization_rate': 0.0,
        'active_rentals': 0,
        'due_today': 0,
        'overdue': 0,
        'today_rentals_created': 0,
        'today_revenue': 0.0,
        'today_transactions_count': 0,
      },
      'stats': {
        'total_units': 0,
        'ready_units': 0,
        'rented_units': 0,
        'maintenance_units': 0,
        'today_revenue': 0,
        'active_rentals': 0,
        'overdue_count': 0,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
      'recent_activities': [],
    };
  }
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchKpi(branchId: bizState.activeBranchId);
});

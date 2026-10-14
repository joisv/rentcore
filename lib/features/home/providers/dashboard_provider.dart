import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) => DashboardRepository());

final dashboardKpiProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final bizState = ref.watch(businessProvider);
  if (bizState.activeBusinessId == null || bizState.businesses.isEmpty) {
    return {
      'is_empty_tenant': true,
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
      'recent_activities': [],
    };
  }
  final repo = ref.watch(dashboardRepositoryProvider);
  return repo.fetchKpi(branchId: bizState.activeBranchId);
});

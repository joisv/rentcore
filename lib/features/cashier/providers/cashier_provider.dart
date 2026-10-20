import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/cashier_repository.dart';

final cashierRepositoryProvider = Provider<CashierRepository>((ref) => CashierRepository());

/// Filter for POS Branch Selection:
/// null = follow businessProvider.activeBranchId (default)
/// -1 = force consolidated (all branches)
/// > 0 = specific branch ID
class PosFilterBranchIdNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void setBranchId(int? branchId) => state = branchId;
}

final posFilterBranchIdProvider = NotifierProvider<PosFilterBranchIdNotifier, int?>(
  PosFilterBranchIdNotifier.new,
);

class PosDateRangeState {
  final String label;
  final String? startDate;
  final String? endDate;

  const PosDateRangeState({
    required this.label,
    this.startDate,
    this.endDate,
  });
}

class PosDateRangeNotifier extends Notifier<PosDateRangeState> {
  @override
  PosDateRangeState build() => const PosDateRangeState(label: 'Hari Ini');

  void setDateRange({required String label, String? startDate, String? endDate}) {
    state = PosDateRangeState(label: label, startDate: startDate, endDate: endDate);
  }
}

final posDateRangeProvider = NotifierProvider<PosDateRangeNotifier, PosDateRangeState>(
  PosDateRangeNotifier.new,
);

final closingSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final bizState = ref.watch(businessProvider);
  final posBranchFilter = ref.watch(posFilterBranchIdProvider);
  final dateRange = ref.watch(posDateRangeProvider);
  final repo = ref.watch(cashierRepositoryProvider);

  final bool isConsolidated = posBranchFilter == -1 || (posBranchFilter == null && bizState.activeBranchId == null);
  final int? effectiveBranchId = isConsolidated ? null : (posBranchFilter ?? bizState.activeBranchId);

  return repo.fetchClosingSummary(
    branchId: effectiveBranchId,
    allBranches: isConsolidated,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

final paymentMethodsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(cashierRepositoryProvider);
  return repo.fetchPaymentMethods();
});

final cashierBookingsProvider = FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String?>((ref, search) async {
  final bizState = ref.watch(businessProvider);
  final posBranchFilter = ref.watch(posFilterBranchIdProvider);
  final repo = ref.watch(cashierRepositoryProvider);

  final bool isConsolidated = posBranchFilter == -1 || (posBranchFilter == null && bizState.activeBranchId == null);
  final int? effectiveBranchId = isConsolidated ? null : (posBranchFilter ?? bizState.activeBranchId);

  return repo.fetchBookingsForCashier(
    branchId: effectiveBranchId,
    allBranches: isConsolidated,
    search: search,
  );
});

final bookingDetailProvider = FutureProvider.autoDispose.family<Map<String, dynamic>, dynamic>((ref, bookingId) async {
  final repo = ref.watch(cashierRepositoryProvider);
  return repo.fetchBookingDetail(bookingId);
});

final cashierExpensesProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final bizState = ref.watch(businessProvider);
  final posBranchFilter = ref.watch(posFilterBranchIdProvider);
  final dateRange = ref.watch(posDateRangeProvider);
  final repo = ref.watch(cashierRepositoryProvider);

  final bool isConsolidated = posBranchFilter == -1 || (posBranchFilter == null && bizState.activeBranchId == null);
  final int? effectiveBranchId = isConsolidated ? null : (posBranchFilter ?? bizState.activeBranchId);

  return repo.fetchExpenses(
    branchId: effectiveBranchId,
    allBranches: isConsolidated,
    startDate: dateRange.startDate,
    endDate: dateRange.endDate,
  );
});

final currentShiftProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final bizState = ref.watch(businessProvider);
  final posBranchFilter = ref.watch(posFilterBranchIdProvider);
  final repo = ref.watch(cashierRepositoryProvider);

  final bool isConsolidated = posBranchFilter == -1 || (posBranchFilter == null && bizState.activeBranchId == null);
  final int? effectiveBranchId = isConsolidated ? null : (posBranchFilter ?? bizState.activeBranchId);

  return repo.fetchCurrentShift(branchId: effectiveBranchId);
});

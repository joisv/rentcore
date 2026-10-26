import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/business_provider.dart';
import '../data/voucher_repository.dart';

final voucherRepositoryProvider = Provider<VoucherRepository>((ref) => VoucherRepository());

class VoucherState {
  final bool isLoading;
  final bool isSubmitting;
  final List<Map<String, dynamic>> vouchers;
  final String statusFilter; // 'all', 'active', 'inactive', 'expired'
  final String searchQuery;
  final dynamic selectedBranchId;
  final String? error;

  const VoucherState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.vouchers = const [],
    this.statusFilter = 'all',
    this.searchQuery = '',
    this.selectedBranchId,
    this.error,
  });

  VoucherState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    List<Map<String, dynamic>>? vouchers,
    String? statusFilter,
    String? searchQuery,
    dynamic selectedBranchId,
    bool clearBranch = false,
    String? error,
  }) {
    return VoucherState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      vouchers: vouchers ?? this.vouchers,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      selectedBranchId: clearBranch ? null : (selectedBranchId ?? this.selectedBranchId),
      error: error,
    );
  }
}

class VoucherNotifier extends Notifier<VoucherState> {
  late final VoucherRepository _repository;

  @override
  VoucherState build() {
    _repository = ref.watch(voucherRepositoryProvider);
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    Future.microtask(() => loadVouchers());
    return const VoucherState();
  }

  Future<void> loadVouchers() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final list = await _repository.fetchVouchers(
        status: state.statusFilter,
        search: state.searchQuery,
        branchId: state.selectedBranchId,
      );
      if (!ref.mounted) return;
      state = state.copyWith(isLoading: false, vouchers: list);
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  void setStatusFilter(String status) {
    if (state.statusFilter == status) return;
    state = state.copyWith(statusFilter: status);
    loadVouchers();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    loadVouchers();
  }

  void setBranchFilter(dynamic branchId) {
    state = state.copyWith(selectedBranchId: branchId, clearBranch: branchId == null);
    loadVouchers();
  }

  Future<bool> createVoucher(Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _repository.createVoucher(payload);
      await loadVouchers();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<bool> updateVoucher(int id, Map<String, dynamic> payload) async {
    state = state.copyWith(isSubmitting: true);
    try {
      await _repository.updateVoucher(id, payload);
      await loadVouchers();
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<bool> toggleStatus(int id) async {
    try {
      await _repository.toggleVoucherStatus(id);
      await loadVouchers();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  Future<bool> deleteVoucher(int id) async {
    try {
      await _repository.deleteVoucher(id);
      await loadVouchers();
      return true;
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  void reset() {
    state = const VoucherState();
  }
}

final voucherProvider = NotifierProvider<VoucherNotifier, VoucherState>(VoucherNotifier.new);

/// Backward-compatible provider for legacy consumers
final vouchersListProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final repo = ref.watch(voucherRepositoryProvider);
  return repo.fetchVouchers();
});

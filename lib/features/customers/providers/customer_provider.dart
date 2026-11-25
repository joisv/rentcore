import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/debounced_search_controller.dart';
import '../../auth/providers/business_provider.dart';
import '../data/customer_repository.dart';

final customerRepositoryProvider = Provider<CustomerRepository>((ref) => CustomerRepository());

class CustomerState {
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting;
  final List<Map<String, dynamic>> customers;
  final String statusFilter; // 'all', 'active', 'blacklisted'
  final String searchQuery;
  final int currentPage;
  final bool hasMore;
  final String? error;

  const CustomerState({
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.customers = const [],
    this.statusFilter = 'all',
    this.searchQuery = '',
    this.currentPage = 1,
    this.hasMore = false,
    this.error,
  });

  CustomerState copyWith({
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    List<Map<String, dynamic>>? customers,
    String? statusFilter,
    String? searchQuery,
    int? currentPage,
    bool? hasMore,
    String? error,
  }) {
    return CustomerState(
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      customers: customers ?? this.customers,
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      error: error,
    );
  }
}

class CustomerNotifier extends Notifier<CustomerState> {
  CustomerRepository get _repository => ref.read(customerRepositoryProvider);
  CancelToken? _activeCancelToken;

  @override
  CustomerState build() {
    ref.watch(businessProvider.select((s) => s.activeBusinessId));
    ref.onDispose(() {
      if (_activeCancelToken != null && !_activeCancelToken!.isCancelled) {
        _activeCancelToken!.cancel('CustomerNotifier disposed');
      }
    });
    Future.microtask(() => loadCustomers(refresh: true));
    return const CustomerState();
  }

  Future<void> loadCustomers({
    bool refresh = false,
    CancelToken? cancelToken,
  }) async {
    if (!ref.mounted) return;

    if (refresh) {
      if (_activeCancelToken != null &&
          _activeCancelToken != cancelToken &&
          !_activeCancelToken!.isCancelled) {
        _activeCancelToken!.cancel('Superseded by newer customer search');
      }
      _activeCancelToken = cancelToken ?? CancelToken();
      state = state.copyWith(isLoading: true, error: null, currentPage: 1);
    }

    final effectiveToken = cancelToken ?? _activeCancelToken;

    try {
      final page = refresh ? 1 : state.currentPage;
      bool? isBlacklisted;
      if (state.statusFilter == 'blacklisted') {
        isBlacklisted = true;
      } else if (state.statusFilter == 'active') {
        isBlacklisted = false;
      }

      _repository.attachCancelToken(effectiveToken);
      final result = await _repository.fetchCustomersPaginated(
        page: page,
        search: state.searchQuery.isEmpty ? null : state.searchQuery,
        isBlacklisted: isBlacklisted,
      );

      if (!ref.mounted || (effectiveToken?.isCancelled ?? false)) return;

      final updatedList = refresh ? result.items : [...state.customers, ...result.items];
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        customers: updatedList,
        currentPage: result.currentPage,
        hasMore: result.hasMore,
        error: null,
      );
    } catch (e) {
      if (DebouncedSearchController.isCancelError(e) || !ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadNextPage() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    state = state.copyWith(currentPage: state.currentPage + 1);
    await loadCustomers(refresh: false);
  }

  void setSearchQuery(String query, {CancelToken? cancelToken}) {
    if (state.searchQuery == query) return;
    state = state.copyWith(searchQuery: query);
    loadCustomers(refresh: true, cancelToken: cancelToken);
  }

  void setStatusFilter(String filter) {
    if (state.statusFilter == filter) return;
    state = state.copyWith(statusFilter: filter);
    loadCustomers(refresh: true);
  }

  Future<bool> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? identityNumber,
    String? identityType,
    String? identityPhotoBase64,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.createCustomer(
        name: name,
        phone: phone,
        email: email,
        address: address,
        identityNumber: identityNumber,
        identityType: identityType,
        identityPhotoBase64: identityPhotoBase64,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await loadCustomers(refresh: true);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> toggleBlacklist({
    required int customerId,
    required bool isBlacklisted,
    String? reason,
    String? managerPin,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.toggleBlacklist(
        customerId: customerId,
        isBlacklisted: isBlacklisted,
        reason: reason,
        managerPin: managerPin,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await loadCustomers(refresh: true);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> uploadIdentityDocument({
    required int customerId,
    required String photoBase64,
    String identityType = 'KTP',
    String? identityNumber,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.uploadIdentityDocument(
        customerId: customerId,
        photoBase64: photoBase64,
        identityType: identityType,
        identityNumber: identityNumber,
      );
      if (!ref.mounted) return false;
      state = state.copyWith(isSubmitting: false);
      await loadCustomers(refresh: true);
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void reset() {
    state = const CustomerState();
  }
}

final customerProvider = NotifierProvider<CustomerNotifier, CustomerState>(CustomerNotifier.new);

// Legacy backward compatibility provider
final customerSearchQueryProvider = NotifierProvider<CustomerSearchQueryNotifier, String>(CustomerSearchQueryNotifier.new);

class CustomerSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String q) => state = q;
}

final customerSearchResultsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(customerSearchQueryProvider);
  final repo = ref.watch(customerRepositoryProvider);
  return repo.searchCustomers(query: query.isEmpty ? null : query);
});

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/auth_repository.dart';
import 'auth_provider.dart';

/// Picks the branch to use as the active context.
///
/// [branches] is the list returned by the backend for a membership, which already
/// contains only branches the member is authorized for (central branch first).
/// Returns the branch matching [storedBranchId] if it is still authorized, otherwise the
/// first authorized branch, or `null` if the member has no branches.
Map<String, dynamic>? resolveAuthorizedBranch(List<dynamic>? branches, int? storedBranchId) {
  if (branches == null || branches.isEmpty) return null;
  final typed = branches.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();
  if (typed.isEmpty) return null;
  if (storedBranchId != null) {
    final match = typed.where((b) => b['id'] == storedBranchId).firstOrNull;
    if (match != null) return match;
  }
  return typed.first;
}

class BusinessState {
  final bool isLoading;
  final int? activeBusinessId;
  final String? activeBusinessName;
  final int? activeBranchId;
  final String? activeBranchName;
  final List<dynamic> businesses;
  final String? error;

  const BusinessState({
    this.isLoading = false,
    this.activeBusinessId,
    this.activeBusinessName,
    this.activeBranchId,
    this.activeBranchName,
    this.businesses = const [],
    this.error,
  });

  Map<String, dynamic>? get currentBusiness {
    if (activeBusinessId == null) return null;
    return businesses.where((b) => b['id'] == activeBusinessId).firstOrNull as Map<String, dynamic>?;
  }

  Map<String, dynamic>? get currentBranch {
    if (activeBranchId == null) return null;
    final branches = currentBusiness?['branches'] as List<dynamic>?;
    return branches?.where((b) => b['id'] == activeBranchId).firstOrNull as Map<String, dynamic>?;
  }

  bool get isCentralBranch => currentBranch?['is_central'] == true;
  bool get isConsolidated => activeBusinessId != null && activeBranchId == null;

  List<String> get activeBusinessCategories {
    final raw = currentBusiness?['business_categories'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  bool isCategoryRelevant(String categoryKey) {
    if (activeBusinessCategories.isEmpty) return true;
    return activeBusinessCategories.contains(categoryKey);
  }

  BusinessState copyWith({
    bool? isLoading,
    int? activeBusinessId,
    String? activeBusinessName,
    int? activeBranchId,
    String? activeBranchName,
    bool clearBranch = false,
    bool clearError = false,
    List<dynamic>? businesses,
    String? error,
  }) {
    return BusinessState(
      isLoading: isLoading ?? this.isLoading,
      activeBusinessId: activeBusinessId ?? this.activeBusinessId,
      activeBusinessName: activeBusinessName ?? this.activeBusinessName,
      activeBranchId: clearBranch ? null : (activeBranchId ?? this.activeBranchId),
      activeBranchName: clearBranch ? null : (activeBranchName ?? this.activeBranchName),
      businesses: businesses ?? this.businesses,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BusinessNotifier extends Notifier<BusinessState> {
  late final AuthRepository _repository;

  @override
  BusinessState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const BusinessState();
  }

  Future<void> loadInitialContext({List<dynamic>? preloadedBusinesses}) async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final bizId = prefs.getInt('active_business_id');
    final bizName = prefs.getString('active_business_name');
    final branchId = prefs.getInt('active_branch_id');
    final branchName = prefs.getString('branch_name');

    try {
      final list = preloadedBusinesses ?? await _repository.fetchBusinesses();
      if (!ref.mounted) return;
      int? effectiveBizId;
      String? effectiveBizName;
      int? effectiveBranchId;
      String? effectiveBranchName;

      if (list.isEmpty) {
        // User has no business membership yet
        await prefs.remove('active_business_id');
        await prefs.remove('active_business_name');
        await prefs.remove('active_branch_id');
        await prefs.remove('branch_name');
        await prefs.remove('branch_code');
      } else {
        // Validate if previously stored business still exists in user's memberships
        final match = list.where((b) => b['id'] == bizId).firstOrNull;
        final targetBiz = match ?? list.first;
        effectiveBizId = targetBiz['id'];
        effectiveBizName = match != null ? (bizName ?? targetBiz['name']) : targetBiz['name'];
        if (match == null) {
          await prefs.setInt('active_business_id', effectiveBizId!);
          await prefs.setString('active_business_name', effectiveBizName!);
        }

        // The backend only lists branches this member is authorized for. A stored branch
        // that is not in that list (stale cache, or a default picked before assignment)
        // would make TenantContextMiddleware reject every request with 403, so fall back
        // to the first authorized branch instead.
        final keepConsolidated = match != null &&
            branchId == null &&
            (targetBiz['role'] as String?) == 'owner';
        final resolved = keepConsolidated
            ? null
            : resolveAuthorizedBranch(
                targetBiz['branches'] as List<dynamic>?,
                match != null ? branchId : null,
              );
        if (resolved != null) {
          effectiveBranchId = resolved['id'] as int;
          effectiveBranchName = (resolved['id'] == branchId && branchName != null)
              ? branchName
              : resolved['name'] as String?;
          if (effectiveBranchId != branchId) {
            await prefs.setInt('active_branch_id', effectiveBranchId);
            await prefs.setString('branch_name', effectiveBranchName ?? '');
          }
        } else {
          await prefs.remove('active_branch_id');
          await prefs.remove('branch_name');
        }
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        activeBusinessId: effectiveBizId,
        activeBusinessName: effectiveBizName,
        activeBranchId: effectiveBranchId,
        activeBranchName: effectiveBranchName,
        businesses: list,
        clearError: true,
      );
    } catch (e) {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        activeBusinessId: null,
        activeBusinessName: null,
        activeBranchId: null,
        activeBranchName: null,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  /// Atomically selects a business and branch context, persisting to local storage
  /// and updating in-memory state in a single synchronous operation to avoid race conditions.
  Future<void> selectContext({
    required Map<String, dynamic> business,
    Map<String, dynamic>? branch,
    bool isConsolidated = false,
  }) async {
    final bizId = business['id'] as int;
    final bizName = business['name'] as String;
    int? branchId;
    String? branchName;

    if (isConsolidated) {
      branchId = null;
      branchName = null;
    } else if (branch != null) {
      branchId = branch['id'] as int;
      branchName = branch['name'] as String;
    } else {
      final branches = business['branches'] as List<dynamic>?;
      final resolved = resolveAuthorizedBranch(branches, null);
      if (resolved != null) {
        branchId = resolved['id'] as int;
        branchName = resolved['name'] as String;
      }
    }

    await _repository.setActiveContext(
      businessId: bizId,
      businessName: bizName,
      branchId: branchId,
      branchName: branchName,
    );

    if (!ref.mounted) return;
    state = state.copyWith(
      activeBusinessId: bizId,
      activeBusinessName: bizName,
      activeBranchId: branchId,
      activeBranchName: branchName,
      clearBranch: branchId == null,
      clearError: true,
    );
  }

  Future<void> selectBusiness(
    Map<String, dynamic> business, {
    Map<String, dynamic>? branch,
    bool isConsolidated = false,
  }) =>
      selectContext(
        business: business,
        branch: branch,
        isConsolidated: isConsolidated,
      );

  Future<void> selectBranch(Map<String, dynamic>? branch) {
    final current = state.currentBusiness;
    if (current != null) {
      return selectContext(
        business: current,
        branch: branch,
        isConsolidated: branch == null && (current['role'] as String?) == 'owner',
      );
    }
    return Future.value();
  }

  Future<bool> registerNewBusiness({
    required String name,
    required String city,
    String? address,
    String? phone,
    List<String>? businessCategories,
    String? initialBranchName,
    String? initialBranchCode,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newBiz = await _repository.createBusiness(
        name: name,
        city: city,
        address: address,
        phone: phone,
        businessCategories: businessCategories,
        initialBranchName: initialBranchName,
        initialBranchCode: initialBranchCode,
      );

      final list = await _repository.fetchBusinesses();
      if (!ref.mounted) return false;

      final targetBiz = list.where((b) => b['id'] == newBiz['id']).firstOrNull ?? newBiz;
      await selectContext(business: targetBiz);

      if (!ref.mounted) return false;
      state = state.copyWith(
        isLoading: false,
        businesses: list,
        clearError: true,
      );
      return true;
    } catch (e) {
      if (!ref.mounted) return false;
      state = state.copyWith(isLoading: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    await loadInitialContext();
  }

  void reset() {
    state = const BusinessState();
  }
}

final businessProvider = NotifierProvider<BusinessNotifier, BusinessState>(BusinessNotifier.new);

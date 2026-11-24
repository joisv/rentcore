import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/collateral_helper.dart';
import '../../organization/providers/organization_provider.dart';
import '../data/auth_repository.dart';
import 'auth_repository_provider.dart';

String? normalizeEntityId(dynamic raw) {
  if (raw == null) return null;
  final text = raw.toString().trim();
  return text.isEmpty ? null : text;
}

int? parseEntityIntId(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return raw;
  return int.tryParse(raw.toString().trim());
}

/// Picks the branch to use as the active context.
///
/// [branches] is the list returned by the backend for a membership, which already
/// contains only branches the member is authorized for (central branch first).
/// Returns the branch matching [storedBranchId] if it is still authorized, otherwise the
/// first authorized branch, or `null` if the member has no branches.
Map<String, dynamic>? resolveAuthorizedBranch(List<dynamic>? branches, dynamic storedBranchId) {
  if (branches == null || branches.isEmpty) return null;
  final typed = branches.whereType<Map>().map((b) => Map<String, dynamic>.from(b)).toList();
  if (typed.isEmpty) return null;
  final targetKey = normalizeEntityId(storedBranchId);
  if (targetKey != null) {
    final match = typed.where((b) => normalizeEntityId(b['id']) == targetKey).firstOrNull;
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
    final activeKey = normalizeEntityId(activeBusinessId);
    if (activeKey == null) return null;
    final found = businesses
        .whereType<Map>()
        .where((b) => normalizeEntityId(b['id']) == activeKey)
        .firstOrNull;
    return found == null ? null : Map<String, dynamic>.from(found);
  }

  Map<String, dynamic>? get activeBusiness => currentBusiness;

  Map<String, dynamic>? get currentBranch {
    final activeKey = normalizeEntityId(activeBranchId);
    if (activeKey == null) return null;
    final branches = currentBusiness?['branches'] as List<dynamic>?;
    final found = branches
        ?.whereType<Map>()
        .where((b) => normalizeEntityId(b['id']) == activeKey)
        .firstOrNull;
    return found == null ? null : Map<String, dynamic>.from(found);
  }

  Map<String, dynamic>? get activeBranch => currentBranch;

  bool get isCentralBranch => currentBranch?['is_central'] == true;
  bool get isConsolidated => activeBusinessId != null && activeBranchId == null;

  String get resolvedStoreName {
    final fromActive = (activeBusinessName ?? '').trim();
    if (fromActive.isNotEmpty) return fromActive;
    return (currentBusiness?['name']?.toString() ?? '').trim();
  }

  String get resolvedBranchName {
    final fromActive = (activeBranchName ?? '').trim();
    if (fromActive.isNotEmpty) return fromActive;
    return (currentBranch?['name']?.toString() ?? '').trim();
  }

  String get resolvedBranchAddress {
    final branchAddr = (currentBranch?['address']?.toString() ?? '').trim();
    if (branchAddr.isNotEmpty) return branchAddr;
    return (currentBusiness?['address']?.toString() ?? '').trim();
  }

  String get resolvedBranchPhone {
    final branchPhone = (currentBranch?['whatsapp']?.toString() ??
            currentBranch?['phone']?.toString() ??
            '')
        .trim();
    if (branchPhone.isNotEmpty) return branchPhone;
    return (currentBusiness?['whatsapp']?.toString() ??
            currentBusiness?['phone']?.toString() ??
            '')
        .trim();
  }

  List<String> get activeBusinessCategories {
    final raw = currentBusiness?['business_categories'];
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    return const [];
  }

  Map<String, dynamic> get effectivePaymentMethodsConfig {
    final base = currentBusiness?['payment_methods_config'];
    final merged = base is Map
        ? Map<String, dynamic>.from(base)
        : <String, dynamic>{};
    final override = currentBranch?['payment_methods_config_override'];
    if (override is Map) {
      override.forEach((k, v) => merged[k.toString()] = v);
    }
    return merged;
  }

  bool get hasQrisImage {
    final cfg = effectivePaymentMethodsConfig;
    final url =
        (currentBranch?['qris_image_url'] ??
                currentBusiness?['qris_image_url'] ??
                cfg['qris_image_url'] ??
                cfg['qris_image_path'] ??
                '')
            .toString()
            .trim();
    return url.isNotEmpty;
  }

  bool get isQrisEnabled {
    final cfg = effectivePaymentMethodsConfig;
    return cfg['qris_statis_enabled'] == true ||
        cfg['is_qris_enabled'] == true;
  }

  bool get isQrisPaymentAvailable => isQrisEnabled && hasQrisImage;

  bool get isCollateralEnabled => resolveEnableCollateral(currentBusiness);

  bool get requireCollateral => resolveRequireCollateral(currentBusiness);

  List<CollateralTypeOption> get collateralTypes =>
      resolveBusinessCollateralTypes(currentBusiness);

  List<CollateralTypeOption> get activeCollateralTypes =>
      collateralTypes.where((t) => t.isActive).toList();

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
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  BusinessState build() {
    return const BusinessState();
  }

  Future<void> loadInitialContext({List<dynamic>? preloadedBusinesses}) async {
    state = state.copyWith(isLoading: true);
    final prefs = await SharedPreferences.getInstance();
    final bizId = parseEntityIntId(prefs.get('active_business_id'));
    final cachedBizName = prefs.getString('active_business_name');
    final branchId = parseEntityIntId(prefs.get('active_branch_id'));
    final cachedBranchName = prefs.getString('branch_name');

    final previousBusinessId = state.activeBusinessId;

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

        if (!ref.mounted) return;
        state = const BusinessState(
          isLoading: false,
          activeBusinessId: null,
          activeBusinessName: null,
          activeBranchId: null,
          activeBranchName: null,
          businesses: [],
          error: null,
        );
        if (previousBusinessId != null || bizId != null) {
          _invalidateTenantScopedProviders();
        }
        return;
      } else {
        // Validate if previously stored business still exists in user's memberships
        final targetKey = normalizeEntityId(bizId ?? previousBusinessId);
        final match = targetKey == null
            ? null
            : list
                .whereType<Map>()
                .where((b) => normalizeEntityId(b['id']) == targetKey)
                .firstOrNull;
        final ownedFallback = list
            .whereType<Map>()
            .where((b) => (b['role'] ?? '').toString() == 'owner')
            .firstOrNull;
        final targetBiz = match ?? ownedFallback ?? list.first;
        effectiveBizId = parseEntityIntId(targetBiz['id']);
        // Always prefer the fresh API business name so renames reflect immediately.
        effectiveBizName = (targetBiz['name']?.toString() ?? '').trim();
        if (effectiveBizId != null &&
            (match == null ||
                bizId != effectiveBizId ||
                cachedBizName != effectiveBizName)) {
          await prefs.setInt('active_business_id', effectiveBizId);
          await prefs.setString('active_business_name', effectiveBizName);
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
          effectiveBranchId = parseEntityIntId(resolved['id']);
          // Always prefer the fresh API branch name so renames reflect immediately.
          effectiveBranchName = (resolved['name']?.toString() ?? '').trim();
          if (effectiveBranchId != null &&
              (effectiveBranchId != branchId ||
                  cachedBranchName != effectiveBranchName)) {
            await prefs.setInt('active_branch_id', effectiveBranchId);
            await prefs.setString('branch_name', effectiveBranchName);
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
        clearBranch: effectiveBranchId == null,
        businesses: list,
        clearError: true,
      );

      if ((previousBusinessId != null && previousBusinessId != effectiveBizId) ||
          (bizId != null && bizId != effectiveBizId)) {
        _invalidateTenantScopedProviders();
      }
    } catch (e) {
      if (!ref.mounted) return;
      // Preserve an already-loaded active context during transient refresh errors
      // so in-memory updates (e.g. a store rename) are never wiped out.
      if (state.activeBusinessId != null && state.businesses.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString().replaceAll('Exception: ', ''),
        );
      } else {
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
  }

  /// Atomically selects a business and branch context, persisting to local storage
  /// and updating in-memory state in a single synchronous operation to avoid race conditions.
  Future<void> selectContext({
    required Map<String, dynamic> business,
    Map<String, dynamic>? branch,
    bool isConsolidated = false,
  }) async {
    final bizId = parseEntityIntId(business['id']) ?? 0;
    final bizName = (business['name']?.toString() ?? '').trim();
    int? branchId;
    String? branchName;

    if (isConsolidated) {
      branchId = null;
      branchName = null;
    } else if (branch != null) {
      branchId = parseEntityIntId(branch['id']);
      branchName = (branch['name']?.toString() ?? '').trim();
    } else {
      final branches = business['branches'] as List<dynamic>?;
      final resolved = resolveAuthorizedBranch(branches, null);
      if (resolved != null) {
        branchId = parseEntityIntId(resolved['id']);
        branchName = (resolved['name']?.toString() ?? '').trim();
      }
    }

    final previousBusinessId = state.activeBusinessId;
    final businessChanged = previousBusinessId != null &&
        normalizeEntityId(previousBusinessId) != normalizeEntityId(bizId);

    await _repository.setActiveContext(
      businessId: bizId,
      businessName: bizName,
      branchId: branchId,
      branchName: branchName,
    );

    if (!ref.mounted) return;
    final bizKey = normalizeEntityId(bizId);
    final updatedBusinesses = state.businesses.map((raw) {
      final b = Map<String, dynamic>.from(raw as Map);
      if (normalizeEntityId(b['id']) == bizKey && bizName.isNotEmpty) {
        b['name'] = bizName;
      }
      return b;
    }).toList();

    state = state.copyWith(
      businesses: updatedBusinesses,
      activeBusinessId: bizId,
      activeBusinessName: bizName,
      activeBranchId: branchId,
      activeBranchName: branchName,
      clearBranch: branchId == null,
      clearError: true,
    );

    if (businessChanged) {
      _invalidateTenantScopedProviders();
    }
  }

  void _invalidateTenantScopedProviders() {
    // Only reset/invalidate imperative notifiers that do not watch businessProvider directly;
    // reactive providers watching businessProvider (e.g. customerProvider, voucherProvider)
    // rebuild automatically on activeBusinessId change.
    if (ref.exists(organizationProvider)) {
      try { ref.read(organizationProvider.notifier).reset(); } catch (_) {}
      ref.invalidate(organizationProvider);
    }
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
    String? city,
    String? address,
    String? phone,
    String? nichePreset,
    List<String>? businessCategories,
    String? branchStructure,
    String? initialBranchName,
    String? initialBranchCode,
    int? pendingBusinessId,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final newBiz = await _repository.createBusiness(
        name: name,
        city: (city ?? '').trim(),
        address: address,
        phone: phone,
        nichePreset: nichePreset,
        businessCategories: businessCategories,
        branchStructure: branchStructure,
        initialBranchName: initialBranchName,
        initialBranchCode: initialBranchCode,
        pendingBusinessId: pendingBusinessId,
      );

      final list = await _repository.fetchBusinesses();
      if (!ref.mounted) return false;

      final newBizKey = normalizeEntityId(newBiz['id']);
      final targetBiz = list
              .whereType<Map>()
              .where((b) => normalizeEntityId(b['id']) == newBizKey)
              .map((b) => Map<String, dynamic>.from(b))
              .firstOrNull ??
          newBiz;
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

  /// Immediately updates the in-memory and persisted business fields
  /// so headers, selectors, and settings reflect store renames without restart.
  Future<void> updateActiveBusinessProfile(
    int businessId,
    Map<String, dynamic> updatedFields,
  ) async {
    final targetKey = normalizeEntityId(businessId);
    final updatedBusinesses = state.businesses.map((raw) {
      final b = Map<String, dynamic>.from(raw as Map);
      if (normalizeEntityId(b['id']) == targetKey) {
        updatedFields.forEach((key, value) {
          if (key == 'branches' && value == null) return;
          b[key] = value;
        });
      }
      return b;
    }).toList();

    final updatedName = updatedFields['name']?.toString().trim();
    final isActive = normalizeEntityId(state.activeBusinessId) == targetKey;
    if (isActive && updatedName != null && updatedName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_business_id', businessId);
      await prefs.setString('active_business_name', updatedName);
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      businesses: updatedBusinesses,
      activeBusinessName: (isActive && updatedName != null && updatedName.isNotEmpty)
          ? updatedName
          : state.activeBusinessName,
    );
  }

  /// Immediately updates a branch's name/metadata in memory and persists active branch_name.
  Future<void> updateActiveBranchMetadata(
    int branchId, {
    required String name,
    String? code,
    String? city,
    String? address,
    String? phone,
    bool updateLocationFields = false,
  }) async {
    final targetKey = normalizeEntityId(branchId);
    final trimmedName = name.trim();
    final updatedBusinesses = state.businesses.map((raw) {
      final b = Map<String, dynamic>.from(raw as Map);
      final branches = b['branches'];
      if (branches is List) {
        b['branches'] = branches.map((brRaw) {
          final br = Map<String, dynamic>.from(brRaw as Map);
          if (normalizeEntityId(br['id']) == targetKey) {
            if (trimmedName.isNotEmpty) br['name'] = trimmedName;
            if (code != null) br['code'] = code.trim().toUpperCase();
            if (updateLocationFields) {
              br['city'] =
                  (city != null && city.trim().isNotEmpty) ? city.trim() : null;
              br['address'] =
                  (address != null && address.trim().isNotEmpty)
                      ? address.trim()
                      : null;
              br['phone'] =
                  (phone != null && phone.trim().isNotEmpty)
                      ? phone.trim()
                      : null;
            } else {
              if (city != null) br['city'] = city;
              if (address != null) br['address'] = address;
              if (phone != null) br['phone'] = phone;
            }
          }
          return br;
        }).toList();
      }
      return b;
    }).toList();

    final isActiveBranch = normalizeEntityId(state.activeBranchId) == targetKey;
    if (isActiveBranch && trimmedName.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('branch_name', trimmedName);
    }

    if (!ref.mounted) return;
    state = state.copyWith(
      businesses: updatedBusinesses,
      activeBranchName: (isActiveBranch && trimmedName.isNotEmpty)
          ? trimmedName
          : state.activeBranchName,
    );
  }

  /// Refreshes business & branch list silently without flashing loading/error UI
  /// if data is already present (e.g. when opening BusinessSelectorSheet).
  Future<void> refreshSilently() async {
    final isWidgetTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (isWidgetTest && _repository.runtimeType == AuthRepository) {
      return;
    }
    try {
      final list = await _repository.fetchBusinesses();
      if (!ref.mounted) return;
      await loadInitialContext(preloadedBusinesses: list);
    } catch (_) {}
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

/// Alias for businessProfileProvider
final businessProfileProvider = businessProvider;

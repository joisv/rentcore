import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';

class OrganizationState {
  final bool isLoading;
  final bool isSubmitting;
  final int? businessId;
  final String? businessName;
  final String? userRole;
  final List<dynamic> branches;
  final List<dynamic> members;
  final String? error;

  const OrganizationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.businessId,
    this.businessName,
    this.userRole,
    this.branches = const [],
    this.members = const [],
    this.error,
  });

  bool get isOwnerOrAdmin => userRole == 'owner' || userRole == 'admin';

  OrganizationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    int? businessId,
    String? businessName,
    String? userRole,
    List<dynamic>? branches,
    List<dynamic>? members,
    String? error,
  }) {
    return OrganizationState(
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      userRole: userRole ?? this.userRole,
      branches: branches ?? this.branches,
      members: members ?? this.members,
      error: error,
    );
  }
}

class OrganizationNotifier extends Notifier<OrganizationState> {
  late final AuthRepository _repository;

  @override
  OrganizationState build() {
    _repository = ref.watch(authRepositoryProvider);
    return const OrganizationState();
  }

  Future<void> loadOrganization(int businessId, {String? businessName}) async {
    state = state.copyWith(
      isLoading: true,
      error: null,
      businessId: businessId,
      businessName: businessName,
    );

    try {
      // Determine user role in this business from businessProvider list
      final bizList = ref.read(businessProvider).businesses;
      final matchedBiz = bizList.where((b) => b['id'] == businessId).firstOrNull;
      final role = matchedBiz != null ? matchedBiz['role']?.toString() : 'owner';

      final branches = await _repository.fetchBranches(businessId);
      final members = await _repository.fetchMembers(businessId);

      state = state.copyWith(
        isLoading: false,
        userRole: role,
        branches: branches,
        members: members,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> createBranch({
    required String name,
    required String code,
    String? city,
    String? address,
    String? phone,
  }) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.createBranch(
        bizId,
        name: name,
        code: code,
        city: city,
        address: address,
        phone: phone,
      );

      final branches = await _repository.fetchBranches(bizId);
      state = state.copyWith(isSubmitting: false, branches: branches);

      ref.read(businessProvider.notifier).refresh();
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> inviteMember({
    required String email,
    String? name,
    required String role,
    List<int>? branchIds,
  }) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.inviteMember(
        bizId,
        email: email,
        name: name,
        role: role,
        branchIds: branchIds,
      );

      final members = await _repository.fetchMembers(bizId);
      state = state.copyWith(isSubmitting: false, members: members);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<void> refresh() async {
    if (state.businessId != null) {
      await loadOrganization(state.businessId!, businessName: state.businessName);
    }
  }
}

final organizationProvider = NotifierProvider<OrganizationNotifier, OrganizationState>(
  OrganizationNotifier.new,
);

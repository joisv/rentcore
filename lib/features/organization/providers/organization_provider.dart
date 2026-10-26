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
  final List<dynamic> resignationRequests;
  final Map<String, dynamic>? rentalRules;
  final String? error;

  const OrganizationState({
    this.isLoading = false,
    this.isSubmitting = false,
    this.businessId,
    this.businessName,
    this.userRole,
    this.branches = const [],
    this.members = const [],
    this.resignationRequests = const [],
    this.rentalRules,
    this.error,
  });

  bool get isOwnerOrAdmin => userRole == 'owner' || userRole == 'admin';
  List<dynamic> get pendingResignations => resignationRequests.where((r) => r['status'] == 'pending').toList();
  Map<String, dynamic>? get myActiveResignation => resignationRequests.where((r) => r['status'] == 'pending').firstOrNull;

  OrganizationState copyWith({
    bool? isLoading,
    bool? isSubmitting,
    int? businessId,
    String? businessName,
    String? userRole,
    List<dynamic>? branches,
    List<dynamic>? members,
    List<dynamic>? resignationRequests,
    Map<String, dynamic>? rentalRules,
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
      resignationRequests: resignationRequests ?? this.resignationRequests,
      rentalRules: rentalRules ?? this.rentalRules,
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
      List<dynamic> resignations = [];
      try {
        resignations = await _repository.fetchResignationRequests(businessId);
      } catch (_) {}
      Map<String, dynamic>? rentalRules;
      try {
        rentalRules = await _repository.fetchRentalRules(businessId);
      } catch (_) {}

      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        userRole: role,
        branches: branches,
        members: members,
        resignationRequests: resignations,
        rentalRules: rentalRules,
      );
    } catch (e) {
      if (!ref.mounted) return;
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

  Future<bool> reassignMemberBranch({
    required int memberId,
    int? fromBranchId,
    required int toBranchId,
    String? reason,
  }) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.reassignMemberBranch(
        bizId,
        memberId,
        fromBranchId: fromBranchId,
        toBranchId: toBranchId,
        reason: reason,
      );

      final members = await _repository.fetchMembers(bizId);
      state = state.copyWith(isSubmitting: false, members: members);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> removeMember(int memberId) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.removeMember(bizId, memberId);
      final members = await _repository.fetchMembers(bizId);
      state = state.copyWith(isSubmitting: false, members: members);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> setManagerPin({required int memberId, required String pin}) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.setManagerPin(bizId, memberId, pin);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> revokeManagerPin(int memberId) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.revokeManagerPin(bizId, memberId);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<bool> updateRentalRules(Map<String, dynamic> payload) async {
    final bizId = state.businessId;
    if (bizId == null) return false;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final updated = await _repository.updateRentalRules(bizId, payload);
      state = state.copyWith(isSubmitting: false, rentalRules: updated);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  Future<void> loadResignations() async {
    final bizId = state.businessId;
    if (bizId == null) return;
    try {
      final resignations = await _repository.fetchResignationRequests(bizId);
      state = state.copyWith(resignationRequests: resignations);
    } catch (_) {}
  }

  Future<bool> submitResignation({String? reason}) async {
    final bizId = state.businessId;
    if (bizId == null) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.submitResignation(bizId, reason: reason);
      final resignations = await _repository.fetchResignationRequests(bizId);
      state = state.copyWith(isSubmitting: false, resignationRequests: resignations);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> cancelResignation(int requestId) async {
    final bizId = state.businessId;
    if (bizId == null) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await _repository.cancelResignation(bizId, requestId);
      final resignations = await _repository.fetchResignationRequests(bizId);
      state = state.copyWith(isSubmitting: false, resignationRequests: resignations);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> reviewResignation(int requestId, {required bool approve, String? decisionNotes}) async {
    final bizId = state.businessId;
    if (bizId == null) return false;
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      if (approve) {
        await _repository.approveResignation(bizId, requestId, decisionNotes: decisionNotes);
      } else {
        await _repository.rejectResignation(bizId, requestId, decisionNotes: decisionNotes);
      }
      final members = await _repository.fetchMembers(bizId);
      final resignations = await _repository.fetchResignationRequests(bizId);
      state = state.copyWith(
        isSubmitting: false,
        members: members,
        resignationRequests: resignations,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> refresh() async {
    if (state.businessId != null) {
      await loadOrganization(state.businessId!, businessName: state.businessName);
    }
  }

  void reset() {
    state = const OrganizationState();
  }
}

final organizationProvider = NotifierProvider<OrganizationNotifier, OrganizationState>(
  OrganizationNotifier.new,
);

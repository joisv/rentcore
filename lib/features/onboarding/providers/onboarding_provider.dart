import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';

class OnboardingState {
  final bool isLoading;
  final bool hasCompletedWalkthrough;
  final int wizardStep;
  final bool isChecklistDismissed;

  const OnboardingState({
    this.isLoading = true,
    this.hasCompletedWalkthrough = false,
    this.wizardStep = 0,
    this.isChecklistDismissed = false,
  });

  OnboardingState copyWith({
    bool? isLoading,
    bool? hasCompletedWalkthrough,
    int? wizardStep,
    bool? isChecklistDismissed,
  }) {
    return OnboardingState(
      isLoading: isLoading ?? this.isLoading,
      hasCompletedWalkthrough:
          hasCompletedWalkthrough ?? this.hasCompletedWalkthrough,
      wizardStep: wizardStep ?? this.wizardStep,
      isChecklistDismissed:
          isChecklistDismissed ?? this.isChecklistDismissed,
    );
  }
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  late final AuthRepository _repository;

  @override
  OnboardingState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => checkStatus());
    return const OnboardingState();
  }

  Future<void> checkStatus() async {
    state = state.copyWith(isLoading: true);
    final user = ref.read(authProvider).user;
    final userId = user?['id']?.toString();
    final businessId = ref.read(businessProvider).activeBusinessId;

    // Check user model flag first if available, else local storage
    bool completed = false;
    if (user != null && user['has_completed_walkthrough_v1'] == true) {
      completed = true;
    } else {
      completed = await _repository.isWalkthroughCompleted(userId: userId);
    }

    final draft = await _repository.loadWizardDraft(userId: userId);
    final step = draft['step'] as int? ?? 0;
    final dismissed = await _repository.isChecklistDismissed(businessId);

    state = state.copyWith(
      isLoading: false,
      hasCompletedWalkthrough: completed,
      wizardStep: step,
      isChecklistDismissed: dismissed,
    );
  }

  Future<void> completeWalkthrough() async {
    final user = ref.read(authProvider).user;
    final userId = user?['id']?.toString();
    await _repository.completeWalkthrough(userId: userId);
    state = state.copyWith(hasCompletedWalkthrough: true);
  }

  Future<void> setWizardStep(int step) async {
    final user = ref.read(authProvider).user;
    final userId = user?['id']?.toString();
    final draft = await _repository.loadWizardDraft(userId: userId);
    await _repository.saveWizardDraft(
      userId: userId,
      step: step,
      name: draft['name'] as String?,
      branchStructure: draft['branch_structure'] as String?,
      categories: (draft['categories'] as List<dynamic>?)?.cast<String>(),
      pendingBusinessId: draft['pending_biz_id'] as int?,
    );
    state = state.copyWith(wizardStep: step);
  }

  void reset() {
    state = const OnboardingState();
  }

  Future<void> dismissChecklist(int businessId) async {
    await _repository.setChecklistDismissed(businessId, true);
    state = state.copyWith(isChecklistDismissed: true);
  }

  Future<void> resetChecklistDismissal(int businessId) async {
    await _repository.setChecklistDismissed(businessId, false);
    state = state.copyWith(isChecklistDismissed: false);
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);

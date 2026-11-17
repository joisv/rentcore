import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/navigation_keys.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../notifications/providers/notification_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';
import '../../organization/providers/organization_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../../transfers/providers/transfer_provider.dart';
import '../../vouchers/providers/voucher_provider.dart';
import '../data/auth_repository.dart';
import 'business_provider.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) => AuthRepository());

class AuthState {
  final bool isLoading;
  final bool isAuthenticated;
  final Map<String, dynamic>? user;
  final String? errorMessage;

  const AuthState({
    this.isLoading = false,
    this.isAuthenticated = false,
    this.user,
    this.errorMessage,
  });

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    Map<String, dynamic>? user,
    String? errorMessage,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      user: user ?? this.user,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    Future.microtask(() => checkCurrentSession());
    return const AuthState();
  }

  Future<void> checkCurrentSession() async {
    if (!ref.mounted) return;
    state = state.copyWith(isLoading: true);
    final sessionData = await _repository.checkSession();
    if (!ref.mounted) return;
    if (sessionData != null) {
      final user = (sessionData.containsKey('user') && sessionData['user'] is Map<String, dynamic>)
          ? sessionData['user'] as Map<String, dynamic>
          : sessionData;
      final businesses = sessionData['businesses'] is List ? sessionData['businesses'] as List : null;
      try {
        await ref.read(businessProvider.notifier).loadInitialContext(
          preloadedBusinesses: businesses,
        );
      } catch (e) {
        debugPrint('[AuthProvider] checkCurrentSession loadInitialContext error: $e');
      }

      if (!ref.mounted) return;
      if (ref.exists(voucherProvider)) {
        try {
          ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] checkCurrentSession loadVouchers error: $e');
        }
      }

      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
      if (ref.exists(printerProvider)) {
        ref.read(printerProvider.notifier).syncHasEverConnectedFlag();
      }
    } else {
      if (!ref.mounted) return;
      state = state.copyWith(
        isLoading: false,
        isAuthenticated: false,
        user: null,
      );
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _invalidateTenantAndUserData();
      final data = await _repository.login(email, password);
      final businesses = data['businesses'] ?? data['user']?['businesses'];
      try {
        await ref.read(businessProvider.notifier).loadInitialContext(
          preloadedBusinesses: businesses is List ? businesses : null,
        );
      } catch (e) {
        debugPrint('[AuthProvider] login loadInitialContext error: $e');
      }

      if (ref.exists(voucherProvider)) {
        try {
          await ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] login loadVouchers error: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
      );
      if (ref.exists(printerProvider)) {
        ref.read(printerProvider.notifier).syncHasEverConnectedFlag();
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> googleSignIn({
    required String idToken,
    String? email,
    String? name,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      _invalidateTenantAndUserData();
      final data = await _repository.googleSignIn(
        idToken: idToken,
        email: email,
        name: name,
        avatarUrl: avatarUrl,
      );
      final businesses = data['businesses'] ?? data['user']?['businesses'];
      try {
        await ref.read(businessProvider.notifier).loadInitialContext(
          preloadedBusinesses: businesses is List ? businesses : null,
        );
      } catch (e) {
        debugPrint('[AuthProvider] login loadInitialContext error: $e');
      }

      if (ref.exists(voucherProvider)) {
        try {
          await ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] login loadVouchers error: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
      );
      if (ref.exists(printerProvider)) {
        ref.read(printerProvider.notifier).syncHasEverConnectedFlag();
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updateProfile({
    required String name,
    String? phone,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final resData = await _repository.updateProfile(
        name: name,
        phone: phone,
      );
      final updatedUser = resData['user'];
      state = state.copyWith(
        isLoading: false,
        user: updatedUser is Map<String, dynamic> ? updatedUser : state.user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<bool> updatePassword({
    String? currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.updatePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        newPasswordConfirmation: newPasswordConfirmation,
      );
      if (state.user != null) {
        final updatedUser = Map<String, dynamic>.from(state.user!);
        updatedUser['has_password'] = true;
        state = state.copyWith(
          isLoading: false,
          user: updatedUser,
        );
      } else {
        state = state.copyWith(isLoading: false);
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.logout();
    } catch (e) {
      debugPrint('[AuthProvider] remote logout error (local session will still be cleared): $e');
    } finally {
      if (ref.mounted) {
        _invalidateTenantAndUserData();
        state = const AuthState();
      }
      try {
        rootNavigatorKey.currentState?.pushNamedAndRemoveUntil(
          '/login',
          (route) => false,
        );
      } catch (e) {
        debugPrint('[AuthProvider] logout navigation fallback: $e');
        rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    }
  }

  void _invalidateTenantAndUserData() {
    // 1. Business Profile & Tenant Context
    if (ref.exists(businessProvider)) {
      try { ref.read(businessProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(businessProvider);
    ref.invalidate(businessProfileProvider);

    // 2. Store Checklist & Onboarding
    if (ref.exists(onboardingProvider)) {
      try { ref.read(onboardingProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(onboardingProvider);
    ref.invalidate(storeChecklistProvider);

    // 3. Asset & Inventory
    ref.invalidate(assetRepositoryProvider);
    if (ref.exists(physicalUnitsProvider)) {
      try { ref.read(physicalUnitsProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(physicalUnitsProvider);
    ref.invalidate(inventoryListProvider);
    ref.invalidate(categoriesProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(catalogModelsProvider);
    ref.invalidate(allCatalogModelsProvider);
    if (ref.exists(selectedAssetStatusFilterProvider)) {
      try { ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(null); } catch (_) {}
    }
    if (ref.exists(selectedAssetCategoryFilterProvider)) {
      try { ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null); } catch (_) {}
    }
    if (ref.exists(assetSearchQueryProvider)) {
      try { ref.read(assetSearchQueryProvider.notifier).setSearch(''); } catch (_) {}
    }
    if (ref.exists(catalogSearchQueryProvider)) {
      try { ref.read(catalogSearchQueryProvider.notifier).setSearch(''); } catch (_) {}
    }

    // 4. Dashboard Summary & KPI
    ref.invalidate(dashboardRepositoryProvider);
    ref.invalidate(dashboardKpiProvider);
    ref.invalidate(dashboardSummaryProvider);
    ref.invalidate(dashboardQueueBookingsProvider);

    // 5. Cashier & Shifts
    ref.invalidate(cashierRepositoryProvider);
    ref.invalidate(currentShiftProvider);
    ref.invalidate(activeShiftProvider);
    ref.invalidate(currentShiftByBranchProvider);
    ref.invalidate(closingSummaryProvider);
    ref.invalidate(cashierBookingsProvider);
    ref.invalidate(bookingDetailProvider);
    ref.invalidate(cashierExpensesProvider);
    ref.invalidate(shiftHistoryProvider);
    ref.invalidate(shiftScheduleProvider);
    ref.invalidate(paymentMethodsProvider);
    ref.invalidate(paymentMethodsForBranchProvider);
    ref.invalidate(paymentSettingsProvider);
    if (ref.exists(posFilterBranchIdProvider)) {
      try { ref.read(posFilterBranchIdProvider.notifier).setBranchId(null); } catch (_) {}
    }
    if (ref.exists(posDateRangeProvider)) {
      try { ref.read(posDateRangeProvider.notifier).setDateRange(label: 'Hari Ini'); } catch (_) {}
    }

    // 6. Bookings
    ref.invalidate(bookingRepositoryProvider);
    ref.invalidate(bookingsListProvider);
    ref.invalidate(readyAssetsProvider);
    if (ref.exists(bookingFilterStatusProvider)) {
      try { ref.read(bookingFilterStatusProvider.notifier).setFilter('rented'); } catch (_) {}
    }
    if (ref.exists(bookingSearchQueryProvider)) {
      try { ref.read(bookingSearchQueryProvider.notifier).setQuery(''); } catch (_) {}
    }

    // 7. Customers
    ref.invalidate(customerRepositoryProvider);
    if (ref.exists(customerProvider)) {
      try { ref.read(customerProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(customerProvider);
    if (ref.exists(customerSearchQueryProvider)) {
      try { ref.read(customerSearchQueryProvider.notifier).setQuery(''); } catch (_) {}
    }
    ref.invalidate(customerSearchResultsProvider);

    // 8. Vouchers
    ref.invalidate(voucherRepositoryProvider);
    if (ref.exists(voucherProvider)) {
      try { ref.read(voucherProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(voucherProvider);
    ref.invalidate(vouchersListProvider);

    // 9. Organization
    if (ref.exists(organizationProvider)) {
      try { ref.read(organizationProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(organizationProvider);

    // 10. Transfers
    ref.invalidate(transferRepositoryProvider);
    ref.invalidate(transfersListProvider);
    ref.invalidate(destinationAffiliatesProvider);
    ref.invalidate(branchRecipientsProvider);
    if (ref.exists(selectedTransferDirectionProvider)) {
      try { ref.read(selectedTransferDirectionProvider.notifier).setDirection('all'); } catch (_) {}
    }
    if (ref.exists(selectedTransferStatusProvider)) {
      try { ref.read(selectedTransferStatusProvider.notifier).setStatus(null); } catch (_) {}
    }

    // 11. Thermal Printer
    if (ref.exists(printerProvider)) {
      try { ref.read(printerProvider.notifier).reset(); } catch (_) {}
    }
    ref.invalidate(printerProvider);

    // 12. Notifications
    ref.invalidate(notificationProvider);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

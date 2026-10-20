import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/navigation_keys.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../customers/providers/customer_provider.dart';
import '../../inventory/providers/asset_provider.dart';
import '../../organization/providers/organization_provider.dart';
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
  late final AuthRepository _repository;

  @override
  AuthState build() {
    _repository = ref.watch(authRepositoryProvider);
    Future.microtask(() => checkCurrentSession());
    return const AuthState();
  }

  Future<void> checkCurrentSession() async {
    state = state.copyWith(isLoading: true);
    final sessionData = await _repository.checkSession();
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

      if (ref.exists(voucherProvider)) {
        try {
          ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] checkCurrentSession loadVouchers error: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: user,
      );
    } else {
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
          ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] login loadVouchers error: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
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

  Future<bool> googleSignIn({
    required String idToken,
    String? email,
    String? name,
    String? avatarUrl,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
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
          ref.read(voucherProvider.notifier).loadVouchers();
        } catch (e) {
          debugPrint('[AuthProvider] login loadVouchers error: $e');
        }
      }

      state = state.copyWith(
        isLoading: false,
        isAuthenticated: true,
        user: data['user'],
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

  Future<void> logout() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      await _repository.logout();
    } catch (e) {
      debugPrint('[AuthProvider] remote logout error (local session will still be cleared): $e');
    } finally {
      if (ref.mounted) {
        if (ref.exists(businessProvider)) {
          ref.read(businessProvider.notifier).reset();
        }
        if (ref.exists(voucherProvider)) {
          try { ref.read(voucherProvider.notifier).reset(); } catch (_) {}
        }
        if (ref.exists(organizationProvider)) {
          try { ref.read(organizationProvider.notifier).reset(); } catch (_) {}
        }
        if (ref.exists(customerSearchQueryProvider)) {
          try { ref.read(customerSearchQueryProvider.notifier).setQuery(''); } catch (_) {}
        }
        if (ref.exists(bookingFilterStatusProvider)) {
          try { ref.read(bookingFilterStatusProvider.notifier).setFilter('rented'); } catch (_) {}
        }
        if (ref.exists(selectedAssetStatusFilterProvider)) {
          try { ref.read(selectedAssetStatusFilterProvider.notifier).setFilter(null); } catch (_) {}
        }
        if (ref.exists(selectedAssetCategoryFilterProvider)) {
          try { ref.read(selectedAssetCategoryFilterProvider.notifier).setFilter(null); } catch (_) {}
        }
        if (ref.exists(assetSearchQueryProvider)) {
          try { ref.read(assetSearchQueryProvider.notifier).setSearch(''); } catch (_) {}
        }
        if (ref.exists(posFilterBranchIdProvider)) {
          try { ref.read(posFilterBranchIdProvider.notifier).setBranchId(null); } catch (_) {}
        }
        if (ref.exists(posDateRangeProvider)) {
          try { ref.read(posDateRangeProvider.notifier).setDateRange(label: 'Hari Ini'); } catch (_) {}
        }
        if (ref.exists(selectedTransferDirectionProvider)) {
          try { ref.read(selectedTransferDirectionProvider.notifier).setDirection('all'); } catch (_) {}
        }
        if (ref.exists(selectedTransferStatusProvider)) {
          try { ref.read(selectedTransferStatusProvider.notifier).setStatus(null); } catch (_) {}
        }
        state = const AuthState();
      }
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

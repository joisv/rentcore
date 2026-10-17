import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/navigation_keys.dart';
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
    final user = await _repository.checkSession();
    if (user != null) {
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
    } catch (_) {
      // Regardless of remote API or storage errors, ensure local state is cleared
    } finally {
      if (ref.mounted) {
        ref.read(businessProvider.notifier).reset();
        state = const AuthState();
      }
      rootNavigatorKey.currentState?.popUntil((route) => route.isFirst);
    }
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

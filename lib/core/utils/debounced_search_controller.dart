import 'dart:async';

import 'package:dio/dio.dart';

/// Reusable search debounce controller with integrated Dio [CancelToken]
/// lifecycle management.
///
/// Waits [delay] (default 350ms) after the user stops typing and cancels any
/// in-flight HTTP request before dispatching the next search callback,
/// preventing out-of-order race conditions and wasted mobile data.
class DebouncedSearchController {
  final Duration delay;
  Timer? _debounceTimer;
  CancelToken? _activeCancelToken;
  bool _isDisposed = false;

  DebouncedSearchController({
    this.delay = const Duration(milliseconds: 350),
  });

  /// The currently active [CancelToken] for the latest dispatched search, if any.
  CancelToken? get activeCancelToken => _activeCancelToken;

  /// Whether a debounced search timer is currently pending.
  bool get hasPendingTimer => _debounceTimer?.isActive ?? false;

  /// Schedule a debounced search for [query].
  ///
  /// Cancels any pending timer and cancels any in-flight [CancelToken]
  /// immediately so stale network calls abort right away.
  /// When [immediate] is true (for example, on explicit clear button tap),
  /// executes [onSearch] synchronously with a fresh [CancelToken].
  void run(
    String query,
    void Function(String trimmedQuery, CancelToken cancelToken) onSearch, {
    bool immediate = false,
  }) {
    if (_isDisposed) return;

    _debounceTimer?.cancel();
    _cancelInFlight('Superseded by newer search query');

    final trimmed = query.trim();

    if (immediate) {
      final token = _issueToken();
      onSearch(trimmed, token);
      return;
    }

    _debounceTimer = Timer(delay, () {
      if (_isDisposed) return;
      final token = _issueToken();
      onSearch(trimmed, token);
    });
  }

  /// Cancel any previous in-flight request and issue a fresh [CancelToken]
  /// without waiting for the debounce timer (useful for manual button triggers).
  CancelToken nextCancelToken([String reason = 'Superseded by newer request']) {
    _cancelInFlight(reason);
    return _issueToken();
  }

  /// Cancel any pending debounce timer and in-flight HTTP request.
  void cancelPending([String reason = 'Search cancelled']) {
    _debounceTimer?.cancel();
    _debounceTimer = null;
    _cancelInFlight(reason);
  }

  /// Release timer and cancel any active network call when the widget disposes.
  void dispose() {
    _isDisposed = true;
    cancelPending('Controller disposed');
  }

  /// Returns true when [error] is an intentional Dio request cancellation.
  static bool isCancelError(Object error) {
    return error is DioException && error.type == DioExceptionType.cancel;
  }

  CancelToken _issueToken() {
    final token = CancelToken();
    _activeCancelToken = token;
    return token;
  }

  void _cancelInFlight(String reason) {
    final token = _activeCancelToken;
    if (token != null && !token.isCancelled) {
      token.cancel(reason);
    }
    _activeCancelToken = null;
  }
}

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/notification_item.dart';

class NotificationState {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final bool isLoading;
  final String selectedCategory; // 'all', 'unread', 'transfer', 'rental', 'membership', 'cashier'
  final String? errorMessage;

  const NotificationState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.selectedCategory = 'all',
    this.errorMessage,
  });

  NotificationState copyWith({
    List<NotificationItem>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? selectedCategory,
    String? errorMessage,
  }) {
    return NotificationState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      isLoading: isLoading ?? this.isLoading,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      errorMessage: errorMessage,
    );
  }
}

class NotificationNotifier extends Notifier<NotificationState> {
  @override
  NotificationState build() {
    return const NotificationState();
  }

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (state.isLoading && !refresh) return;

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final queryParams = <String, dynamic>{
        'per_page': 50,
      };

      if (state.selectedCategory == 'unread') {
        queryParams['unread_only'] = true;
      } else if (state.selectedCategory != 'all') {
        queryParams['category'] = state.selectedCategory;
      }

      final response = await ApiClient().dio.get(
        '/api/v1/notifications',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> dataList = response.data['data']?['data'] ?? [];
        final items = dataList.map((item) => NotificationItem.fromJson(item as Map<String, dynamic>)).toList();
        final unreadCount = (response.data['unread_count'] as num?)?.toInt() ?? 0;

        state = state.copyWith(
          notifications: items,
          unreadCount: unreadCount,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.data['message']?.toString() ?? 'Gagal memuat pemberitahuan.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Gagal memuat pemberitahuan: $e',
      );
    }
  }

  Future<void> fetchUnreadCountOnly() async {
    try {
      final response = await ApiClient().dio.get(
        '/api/v1/notifications',
        queryParameters: {'per_page': 1},
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final unreadCount = (response.data['unread_count'] as num?)?.toInt() ?? 0;
        state = state.copyWith(unreadCount: unreadCount);
      }
    } catch (_) {
      // Quiet fail for badge polling
    }
  }

  Future<void> markAsRead(int notificationId) async {
    try {
      final response = await ApiClient().dio.patch(
        '/api/v1/notifications/$notificationId/read',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final newUnreadCount = (response.data['unread_count'] as num?)?.toInt() ??
            (state.unreadCount > 0 ? state.unreadCount - 1 : 0);

        final updatedList = state.notifications.map((n) {
          if (n.id == notificationId) {
            return n.copyWith(readAt: DateTime.now());
          }
          return n;
        }).toList();

        state = state.copyWith(
          notifications: updatedList,
          unreadCount: newUnreadCount,
        );
      }
    } catch (_) {
      // Silent error or fallback
    }
  }

  Future<bool> markAllAsRead() async {
    try {
      final response = await ApiClient().dio.post(
        '/api/v1/notifications/read-all',
      );

      if (response.statusCode == 200 && response.data['success'] == true) {
        final updatedList = state.notifications.map((n) {
          return n.copyWith(readAt: n.readAt ?? DateTime.now());
        }).toList();

        state = state.copyWith(
          notifications: updatedList,
          unreadCount: 0,
        );
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  void setCategoryFilter(String category) {
    if (state.selectedCategory == category) return;
    state = state.copyWith(selectedCategory: category);
    fetchNotifications(refresh: true);
  }
}

final notificationProvider = NotifierProvider<NotificationNotifier, NotificationState>(() {
  return NotificationNotifier();
});

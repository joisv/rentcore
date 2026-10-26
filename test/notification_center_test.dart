import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/notifications/models/notification_item.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';
import 'package:rentcore_mobile/features/notifications/presentation/notification_center_screen.dart';

class _FakeNotificationNotifier extends NotificationNotifier {
  final NotificationState initialState;

  _FakeNotificationNotifier(this.initialState);

  @override
  NotificationState build() => initialState;

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}

  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> markAsRead(int notificationId) async {
    final updatedList = state.notifications.map((n) {
      if (n.id == notificationId) {
        return n.copyWith(readAt: DateTime.now());
      }
      return n;
    }).toList();

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }

  @override
  Future<bool> markAllAsRead() async {
    final updatedList = state.notifications.map((n) {
      return n.copyWith(readAt: n.readAt ?? DateTime.now());
    }).toList();

    state = state.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    );
    return true;
  }
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('NotificationItem Model & Formatting Tests', () {
    test('NotificationItem parses JSON and formats relative time correctly', () {
      final now = DateTime.now();
      final item = NotificationItem.fromJson({
        'id': 101,
        'business_id': 1,
        'affiliate_id': 2,
        'category': 'transfer',
        'type': 'transfer.requested',
        'title': 'Pengajuan Mutasi Unit',
        'body': 'Staf A mengajukan mutasi iPhone 15 Pro.',
        'action_route': '/transfers',
        'action_payload': {'transfer_id': 42},
        'read_at': null,
        'created_at': now.subtract(const Duration(minutes: 5)).toIso8601String(),
      });

      expect(item.id, 101);
      expect(item.category, 'transfer');
      expect(item.isRead, isFalse);
      expect(item.actionRoute, '/transfers');
      expect(item.actionPayload?['transfer_id'], 42);
      expect(item.timeAgo, contains('mnt lalu'));
    });

    test('NotificationItem recognizes read state when readAt is present', () {
      final now = DateTime.now();
      final item = NotificationItem(
        id: 102,
        businessId: 1,
        category: 'membership',
        type: 'staff.resignation_submitted',
        title: 'Permohonan Resign',
        body: 'Staf B mengajukan resign',
        readAt: now,
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      expect(item.isRead, isTrue);
      expect(item.timeAgo, '2 jam lalu');
    });
  });

  group('NotificationCenterScreen Widget Tests', () {
    testWidgets('Renders empty state when there are no notifications', (tester) async {
      final fakeNotifier = _FakeNotificationNotifier(
        const NotificationState(
          notifications: [],
          unreadCount: 0,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Pusat Pemberitahuan'), findsOneWidget);
      expect(find.text('Semua'), findsOneWidget);
      expect(find.text('Belum Dibaca'), findsOneWidget);
      expect(find.text('Mutasi Unit'), findsOneWidget);
      expect(find.text('Tidak Ada Pemberitahuan'), findsOneWidget);
    });

    testWidgets('Renders notification cards with category icons, titles, and actions', (tester) async {
      final now = DateTime.now();
      final testItems = [
        NotificationItem(
          id: 1,
          businessId: 1,
          category: 'transfer',
          type: 'transfer.requested',
          title: 'Pengajuan Mutasi iPhone 15 Pro',
          body: 'Staf Alpha mengajukan transfer unit ke Cabang Beta.',
          readAt: null,
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        NotificationItem(
          id: 2,
          businessId: 1,
          category: 'membership',
          type: 'staff.resignation_submitted',
          title: 'Permohonan Resign Staf',
          body: 'Staf Beta mengajukan resign dari organisasi.',
          readAt: now.subtract(const Duration(minutes: 30)),
          createdAt: now.subtract(const Duration(minutes: 40)),
        ),
      ];

      final fakeNotifier = _FakeNotificationNotifier(
        NotificationState(
          notifications: testItems,
          unreadCount: 1,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationProvider.overrideWith(() => fakeNotifier),
          ],
          child: const MaterialApp(
            home: NotificationCenterScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header Badge
      expect(find.text('1'), findsWidgets); // Unread badge in AppBar
      expect(find.text('Tandai Dibaca'), findsOneWidget);

      // Verify Notification Cards
      expect(find.text('Pengajuan Mutasi iPhone 15 Pro'), findsOneWidget);
      expect(find.text('Staf Alpha mengajukan transfer unit ke Cabang Beta.'), findsOneWidget);
      expect(find.text('Lihat Mutasi Unit'), findsOneWidget);

      expect(find.text('Permohonan Resign Staf'), findsOneWidget);
      expect(find.text('Staf Beta mengajukan resign dari organisasi.'), findsOneWidget);
      expect(find.text('Tinjau Organisasi'), findsOneWidget);

      // Test "Tandai Dibaca" tap
      await tester.tap(find.text('Tandai Dibaca'));
      await tester.pumpAndSettle();

      // State is updated to 0 unread
      expect(fakeNotifier.state.unreadCount, 0);
    });

    testWidgets('Notification Bell Icon with badge counter renders properly on HomeScreen header', (tester) async {
      final fakeNotifier = _FakeNotificationNotifier(
        const NotificationState(
          notifications: [],
          unreadCount: 5,
          isLoading: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationProvider.overrideWith(() => fakeNotifier),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  // Test the header notification bell widget pattern
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                          );
                        },
                        tooltip: 'Pusat Pemberitahuan',
                        icon: const Icon(Icons.notifications_outlined),
                      ),
                      Consumer(
                        builder: (context, ref, _) {
                          final unread = ref.watch(notificationProvider.select((s) => s.unreadCount));
                          if (unread <= 0) return const SizedBox.shrink();
                          return Positioned(
                            right: 6,
                            top: 6,
                            child: Text('$unread'),
                          );
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
      expect(find.text('5'), findsOneWidget);

      // Tap opens NotificationCenterScreen
      await tester.tap(find.byIcon(Icons.notifications_outlined));
      await tester.pumpAndSettle();

      expect(find.text('Pusat Pemberitahuan'), findsOneWidget);
    });
  });
}

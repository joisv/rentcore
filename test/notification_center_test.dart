import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/api_constants.dart';
import 'package:rentcore_mobile/core/network/api_client.dart';
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

    testWidgets('Renders rental overdue and inventory low stock notifications with specialized action buttons', (tester) async {
      final now = DateTime.now();
      final overdueItems = [
        NotificationItem(
          id: 301,
          businessId: 1,
          category: 'rental',
          type: 'rental.overdue',
          title: 'Unit Sewa Overdue (2 Jam)',
          body: 'Booking BKG-20261026-001 oleh John Doe telah melewati batas waktu.',
          actionRoute: '/bookings',
          actionPayload: {'booking_code': 'BKG-20261026-001', 'overdue_hours': 2},
          readAt: null,
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        NotificationItem(
          id: 302,
          businessId: 1,
          category: 'system',
          type: 'inventory.low_stock',
          title: 'Stok Siap Sewa Menipis (Cabang Utama)',
          body: 'Cabang Utama saat ini hanya memiliki 0 unit siap sewa.',
          actionRoute: '/inventory',
          actionPayload: {'branch_id': 1, 'ready_count': 0},
          readAt: null,
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
      ];

      final fakeNotifier = _FakeNotificationNotifier(
        NotificationState(
          notifications: overdueItems,
          unreadCount: 2,
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

      // Check overdue notification card
      expect(find.text('Unit Sewa Overdue (2 Jam)'), findsOneWidget);
      expect(find.text('Proses Pengembalian / Antrean'), findsOneWidget);
      expect(find.byIcon(Icons.alarm_on_rounded), findsOneWidget);

      // Check low stock notification card
      expect(find.text('Stok Siap Sewa Menipis (Cabang Utama)'), findsOneWidget);
      expect(find.text('Cek Stok Unit Siap'), findsOneWidget);
      expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget);
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

  group('Notification Endpoint Resolution Tests', () {
    test('ApiConstants notification endpoints do not contain duplicated api prefixes', () {
      expect(ApiConstants.notifications, '/notifications');
      expect(ApiConstants.markNotificationRead(42), '/notifications/42/read');
      expect(ApiConstants.markAllNotificationsRead, '/notifications/read-all');

      final dio = ApiClient().dio;
      final fullPath = '${dio.options.baseUrl}${ApiConstants.notifications}';
      expect(fullPath, isNot(contains('/api/v1/api/v1')));
      expect(fullPath, endsWith('/api/v1/notifications'));
    });

    testWidgets('Owner sees interactive Tolak and Setujui buttons for pending resignation notification and badges when resolved', (tester) async {
      final now = DateTime.now();
      final items = [
        NotificationItem(
          id: 501,
          businessId: 1,
          category: 'membership',
          type: 'staff.resignation_submitted',
          title: 'Pengajuan Resign Staf',
          body: 'Agus (Cabang Pusat) mengajukan pengunduran diri.',
          actionRoute: '/organization',
          actionPayload: {
            'resignation_request_id': 77,
            'staff_name': 'Agus',
            'branch_name': 'Cabang Pusat',
            'reason': 'Pindah domisili',
            'status': 'pending',
          },
          readAt: null,
          createdAt: now,
        ),
        NotificationItem(
          id: 502,
          businessId: 1,
          category: 'membership',
          type: 'staff.resignation_submitted',
          title: 'Pengajuan Resign Staf',
          body: 'Budi mengajukan pengunduran diri.',
          actionRoute: '/organization',
          actionPayload: {
            'resignation_request_id': 78,
            'staff_name': 'Budi',
            'status': 'approved',
          },
          readAt: now,
          createdAt: now.subtract(const Duration(hours: 2)),
        ),
      ];

      final fakeNotifier = _TrackingResignNotificationNotifier(
        NotificationState(
          notifications: items,
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

      expect(find.text('Staf: Agus • Cabang Pusat'), findsOneWidget);
      expect(find.text('Alasan: "Pindah domisili"'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
      expect(find.text('Setujui'), findsOneWidget);
      expect(find.text('Disetujui'), findsOneWidget);

      await tester.tap(find.text('Setujui'));
      await tester.pumpAndSettle();
      expect(find.text('Setujui Pengajuan Resign?'), findsOneWidget);

      // Confirm dialog Setujui
      await tester.tap(find.widgetWithText(ElevatedButton, 'Setujui').last);
      await tester.pumpAndSettle();

      expect(fakeNotifier.approvedResignationId, 77);
      expect(find.text('Disetujui'), findsNWidgets(2));
      expect(find.text('Tolak'), findsNothing);
    });
  });
}

class _TrackingResignNotificationNotifier extends _FakeNotificationNotifier {
  int? approvedResignationId;
  _TrackingResignNotificationNotifier(super.initialState);

  @override
  Future<String?> approveResignationNotification({
    required int resignationRequestId,
    required int notificationId,
  }) async {
    approvedResignationId = resignationRequestId;
    final updatedList = state.notifications.map((n) {
      if (n.id == notificationId) {
        final nextPayload = Map<String, dynamic>.from(n.actionPayload ?? {});
        nextPayload['status'] = 'approved';
        return n.copyWith(actionPayload: nextPayload, readAt: DateTime.now());
      }
      return n;
    }).toList();
    state = state.copyWith(
      notifications: updatedList,
      unreadCount: 0,
    );
    return null;
  }
}

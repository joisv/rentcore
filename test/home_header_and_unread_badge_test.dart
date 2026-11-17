import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/notifications/models/notification_item.dart';
import 'package:rentcore_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {'id': 1, 'name': 'Hadi Purwanto', 'role': 'owner'},
      );

  @override
  Future<void> checkCurrentSession() async {}
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;

  void switchToBranch(int? branchId, String? branchName) {
    state = state.copyWith(
      activeBranchId: branchId,
      activeBranchName: branchName,
      clearBranch: branchId == null,
    );
  }
}

class _TrackingNotificationNotifier extends NotificationNotifier {
  int fetchUnreadCountCalls = 0;
  int simulatedUnreadCountFromServer;
  final List<NotificationItem> simulatedItems;

  _TrackingNotificationNotifier({
    this.simulatedUnreadCountFromServer = 2,
    this.simulatedItems = const [],
  });

  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> fetchUnreadCountOnly() async {
    fetchUnreadCountCalls++;
    state = state.copyWith(unreadCount: simulatedUnreadCountFromServer);
  }

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {
    state = state.copyWith(
      notifications: simulatedItems,
      unreadCount: simulatedUnreadCountFromServer,
      isLoading: false,
    );
  }

  @override
  Future<bool> markAllAsRead() async {
    simulatedUnreadCountFromServer = 0;
    final now = DateTime.now();
    state = state.copyWith(
      notifications: state.notifications
          .map((n) => n.copyWith(readAt: n.readAt ?? now))
          .toList(),
      unreadCount: 0,
    );
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final emptyKpi = <String, dynamic>{
    'kpi': {
      'total_revenue': 0,
      'active_rentals': 0,
      'overdue_rentals': 0,
      'ready_assets': 0,
      'rented_assets': 0,
      'maintenance_assets': 0,
      'fleet_total': 0,
      'today_bookings': 0,
      'today_returns': 0,
    },
    'overdue_list': [],
  };

  testWidgets(
    'Two-line store & branch header renders cleanly at 360dp with uniform 22dp icons and eager unread dot',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final businessNotifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 1,
          activeBusinessName: 'Gwenn Rental Malang',
          activeBranchId: null,
          activeBranchName: null,
          businesses: [
            {
              'id': 1,
              'name': 'Gwenn Rental Malang',
              'role': 'owner',
              'branches': [
                {'id': 10, 'name': 'Gwenn Rental Pusat', 'is_central': true},
                {'id': 11, 'name': 'Cabang 1', 'is_central': false},
              ],
            },
          ],
        ),
      );

      final notificationNotifier = _TrackingNotificationNotifier(
        simulatedUnreadCountFromServer: 3,
        simulatedItems: [
          NotificationItem(
            id: 1,
            businessId: 1,
            category: 'transfer',
            type: 'transfer.requested',
            title: 'Pengajuan Mutasi Unit',
            body: 'Menunggu persetujuan Anda.',
            createdAt: DateTime.now(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier()),
            businessProvider.overrideWith(() => businessNotifier),
            notificationProvider.overrideWith(() => notificationNotifier),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyKpi)),
            dashboardQueueBookingsProvider.overrideWith(
              (ref) => Future.value(const []),
            ),
          ],
          child: MaterialApp(
            home: HomeScreen(onNavigateTab: (_) {}),
          ),
        ),
      );

      // Process initial microtask
      await tester.pumpAndSettle();

      // 1. Eager initial fetch happened immediately on mount BEFORE opening Notifikasi
      expect(notificationNotifier.fetchUnreadCountCalls, 1);

      // 2. Crimson 8x8 dot appears immediately on the bell icon
      final badgeFinder = find.byKey(const Key('home_header_notification_badge'));
      expect(badgeFinder, findsOneWidget);
      final badgeBox = tester.widget<Container>(badgeFinder);
      final decoration = badgeBox.decoration! as BoxDecoration;
      expect(decoration.color, const Color(0xFFEF4444));
      expect((decoration.border! as Border).top.width, 1.5);
      expect((decoration.border! as Border).top.color, Colors.white);

      // 3. Two-line store & active branch display clearly without truncation
      expect(find.text('Gwenn Rental Malang'), findsOneWidget);
      expect(find.text('Semua Cabang'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('home_header_branch_button')),
          matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
        ),
        findsOneWidget,
      );

      // 4. Right slot has 22dp bell icon & #1F2937 color (no search button in header)
      final bellIcon = tester.widget<Icon>(
        find.byIcon(Icons.notifications_none_rounded),
      );
      expect(bellIcon.size, 22);
      expect(bellIcon.color, const Color(0xFF1F2937));
      expect(find.byKey(const Key('home_header_search_button')), findsNothing);

      // No collision between center branch selector and bell icon at 360dp
      final branchRect = tester.getRect(
        find.byKey(const Key('home_header_branch_button')),
      );
      final bellRect = tester.getRect(
        find.byKey(const Key('home_header_notification_button')),
      );
      expect(branchRect.right <= bellRect.left, isTrue);

      // 5. Branch change triggers fetchUnreadCountOnly() and updates Line 2
      businessNotifier.switchToBranch(10, 'Gwenn Rental Pusat');
      await tester.pumpAndSettle();
      expect(notificationNotifier.fetchUnreadCountCalls, 2);
      expect(find.text('Gwenn Rental Pusat'), findsOneWidget);

      // 6. App resume triggers fetchUnreadCountOnly()
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(notificationNotifier.fetchUnreadCountCalls, 3);

      // 7. Marking read inside NotificationCenterScreen clears Dashboard red dot immediately
      await tester.tap(find.byKey(const Key('home_header_notification_button')));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationCenterScreen), findsOneWidget);

      await tester.tap(find.text('Tandai Dibaca'));
      await tester.pumpAndSettle();

      Navigator.of(tester.element(find.byType(NotificationCenterScreen))).pop();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('home_header_notification_badge')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

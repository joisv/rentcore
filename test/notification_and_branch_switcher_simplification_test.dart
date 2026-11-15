import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/notifications/models/notification_item.dart';
import 'package:rentcore_mobile/features/notifications/presentation/notification_center_screen.dart';
import 'package:rentcore_mobile/features/notifications/providers/notification_provider.dart';
import 'package:rentcore_mobile/shared/widgets/business_selector_sheet.dart';

class _FakeNotificationNotifier extends NotificationNotifier {
  final NotificationState _initialState;
  bool markAllCalled = false;
  int? lastMarkedReadId;

  _FakeNotificationNotifier(this._initialState);

  @override
  NotificationState build() => _initialState;

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}

  @override
  Future<bool> markAllAsRead() async {
    markAllCalled = true;
    final now = DateTime.now();
    state = state.copyWith(
      unreadCount: 0,
      notifications: state.notifications
          .map((n) => n.copyWith(readAt: n.readAt ?? now))
          .toList(),
    );
    return true;
  }

  @override
  Future<void> markAsRead(int id) async {
    lastMarkedReadId = id;
  }
}

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initialState;
  bool logoutCalled = false;

  _FakeAuthNotifier(this._initialState);

  @override
  AuthState build() => _initialState;

  @override
  Future<void> checkCurrentSession() async {}

  @override
  Future<void> logout() async {
    logoutCalled = true;
  }
}

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  Map<String, dynamic>? lastSelectedBranch;
  bool lastIsConsolidated = false;

  _FakeBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;

  @override
  Future<void> selectContext({
    required Map<String, dynamic> business,
    Map<String, dynamic>? branch,
    bool isConsolidated = false,
  }) async {
    lastSelectedBranch = branch;
    lastIsConsolidated = isConsolidated;
    state = state.copyWith(
      activeBusinessId: business['id'] as int?,
      activeBusinessName: business['name']?.toString(),
      activeBranchId: isConsolidated ? null : branch?['id'] as int?,
      activeBranchName: isConsolidated ? null : branch?['name']?.toString(),
      clearBranch: isConsolidated,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Part 1: Simplified NotificationCenterScreen at 360dp', () {
    testWidgets('renders clean header and flat feed rows with zero overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeNotifier = _FakeNotificationNotifier(
        NotificationState(
          unreadCount: 1,
          notifications: [
            NotificationItem(
              id: 42,
              businessId: 1,
              category: 'transfer',
              type: 'transfer.requested',
              title: 'Pengajuan Mutasi Unit',
              body:
                  'Joisvvb mengajukan mutasi iPhone 17 pro Max (TRF-261115-0001) menuju Gwenn Rental Pusat. Menunggu persetujuan Anda.',
              createdAt: DateTime.now(),
            ),
          ],
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

      // Header checks
      expect(find.text('Pusat Pemberitahuan'), findsNothing);
      expect(find.text('Notifikasi'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.text('Tandai Dibaca'), findsOneWidget);
      expect(find.byIcon(Icons.done_all_rounded), findsNothing);

      // Flat feed content checks (no nested OutlinedButton)
      expect(find.byType(OutlinedButton), findsNothing);
      expect(
        find.text('Pengajuan Mutasi Unit • Baru saja', findRichText: true),
        findsOneWidget,
      );
      expect(
        find.text(
          'Joisvvb mengajukan mutasi iPhone 17 pro Max (TRF-261115-0001) menuju Gwenn Rental Pusat. Menunggu persetujuan Anda.',
        ),
        findsOneWidget,
      );
      expect(find.text('Lihat Mutasi Unit ›'), findsOneWidget);

      // Action check
      await tester.tap(find.text('Tandai Dibaca'));
      await tester.pumpAndSettle();
      expect(fakeNotifier.markAllCalled, isTrue);

      expect(tester.takeException(), isNull);
    });
  });

  group('Part 2: Simplified BusinessSelectorSheet at 360dp', () {
    testWidgets('renders flat monochrome profile & branch rows without boxes or overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuth = _FakeAuthNotifier(
        const AuthState(
          isAuthenticated: true,
          user: {
            'id': 1,
            'name': 'Hadi Purwanto',
            'email': 'gwennrepair@gmail.com',
          },
        ),
      );

      final branches = [
        {
          'id': 10,
          'name': 'Gwenn Rental Pusat',
          'code': 'GRM',
          'city': 'Malang',
          'is_central': true,
        },
        {
          'id': 11,
          'name': 'cabang 1',
          'code': 'CBG001',
          'city': 'banyuwangi',
          'is_central': false,
        },
      ];

      final business = {
        'id': 1,
        'name': 'Gwenn Rental Malang',
        'role': 'owner',
        'branches': branches,
      };

      final fakeBusiness = _FakeBusinessNotifier(
        BusinessState(
          businesses: [business],
          activeBusinessId: 1,
          activeBusinessName: 'Gwenn Rental Malang',
          activeBranchId: 10,
          activeBranchName: 'Gwenn Rental Pusat',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => fakeAuth),
            businessProvider.overrideWith(() => fakeBusiness),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => BusinessSelectorSheet.show(context),
                    child: const Text('Open Switcher'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Switcher'));
      await tester.pumpAndSettle();

      // Verify zero ExpansionTile boxes & zero CircleAvatar
      expect(find.byType(ExpansionTile), findsNothing);
      expect(find.byType(CircleAvatar), findsNothing);

      // Top monochrome user header
      expect(find.text('H'), findsOneWidget);
      expect(find.text('Hadi Purwanto'), findsOneWidget);
      expect(find.text('gwennrepair@gmail.com'), findsOneWidget);
      expect(find.byIcon(Icons.logout_rounded), findsOneWidget);

      // Section & workspace header
      expect(find.text('USAHA & CABANG'), findsOneWidget);
      expect(find.text('+ Tambah'), findsOneWidget);
      expect(find.text('Gwenn Rental Malang • 2 Cabang'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);

      // Consolidated & branch rows + preserved details
      expect(find.text('Semua Cabang (Konsolidasi)'), findsOneWidget);
      expect(find.text('SEMUA'), findsOneWidget);
      expect(
        find.text('Laporan & analitik gabungan seluruh cabang'),
        findsOneWidget,
      );
      expect(find.text('Gwenn Rental Pusat'), findsOneWidget);
      expect(find.text('PUSAT'), findsOneWidget);
      expect(find.text('GRM • Malang'), findsOneWidget);
      expect(find.text('cabang 1'), findsOneWidget);
      expect(find.text('CBG001 • banyuwangi'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Bottom footer link
      expect(find.text('Kelola Tim & Cabang'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

      // Switching branch works
      await tester.tap(find.text('cabang 1'));
      await tester.pumpAndSettle();
      expect(fakeBusiness.lastSelectedBranch?['id'], 11);

      expect(tester.takeException(), isNull);
    });
  });
}

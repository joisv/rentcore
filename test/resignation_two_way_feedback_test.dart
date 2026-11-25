import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sewakasir/features/auth/presentation/user_profile_screen.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/notifications/models/notification_item.dart';
import 'package:sewakasir/features/notifications/presentation/notification_center_screen.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';
import 'package:sewakasir/features/organization/presentation/manage_organization_screen.dart';
import 'package:sewakasir/features/organization/providers/organization_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  final AuthState _state;
  _TestAuthNotifier(this._state);

  @override
  AuthState build() => _state;
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  int refreshCalls = 0;
  final bool dropRevokedBusinessOnRefresh;

  _TestBusinessNotifier(
    this._initial, {
    this.dropRevokedBusinessOnRefresh = false,
  });

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refreshSilently() async {
    refreshCalls++;
    if (dropRevokedBusinessOnRefresh) {
      state = const BusinessState(
        activeBusinessId: null,
        activeBusinessName: null,
        businesses: [],
      );
    }
  }

  @override
  Future<void> refresh() async {
    await refreshSilently();
  }
}

class _InteractiveOrgNotifier extends OrganizationNotifier {
  final OrganizationState _initial;
  String? lastSubmittedReason;
  int? lastReviewedRequestId;
  bool? lastReviewApprove;
  String? lastReviewNotes;

  _InteractiveOrgNotifier(this._initial);

  @override
  OrganizationState build() => _initial;

  @override
  Future<void> loadOrganization(int businessId, {String? businessName}) async {}

  @override
  Future<void> ensureBusinessResignationsLoaded(
    int businessId, {
    String? businessName,
  }) async {
    state = state.copyWith(
      businessId: businessId,
      businessName: businessName ?? state.businessName,
    );
  }

  @override
  Future<void> loadResignations() async {}

  @override
  Future<bool> submitResignation({String? reason, int? businessId}) async {
    lastSubmittedReason = reason;
    final req = {
      'id': 301,
      'business_id': businessId ?? state.businessId ?? 1,
      'user_id': 'staff-1',
      'status': 'pending',
      'reason': reason,
      'created_at': '2026-11-24T10:00:00Z',
    };
    state = state.copyWith(
      businessId: businessId ?? state.businessId ?? 1,
      isSubmitting: false,
      resignationRequests: [req],
    );
    return true;
  }

  @override
  Future<bool> reviewResignation(
    int requestId, {
    required bool approve,
    String? decisionNotes,
  }) async {
    lastReviewedRequestId = requestId;
    lastReviewApprove = approve;
    lastReviewNotes = decisionNotes;
    final updatedMembers = approve
        ? state.members
            .where(
              (m) => (m as Map<String, dynamic>)['user']?['id'] != 'staff-1',
            )
            .toList()
        : state.members;
    final updatedRequests = state.resignationRequests.map((r) {
      final map = Map<String, dynamic>.from(r as Map);
      if (map['id'] == requestId) {
        map['status'] = approve ? 'approved' : 'rejected';
        map['decision_notes'] = decisionNotes;
      }
      return map;
    }).toList();
    state = state.copyWith(
      isSubmitting: false,
      members: updatedMembers,
      resignationRequests: updatedRequests,
    );
    return true;
  }
}

class _StubNotificationNotifier extends NotificationNotifier {
  final NotificationState _initial;
  int? lastMarkedReadId;

  _StubNotificationNotifier(this._initial);

  @override
  NotificationState build() => _initial;

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}

  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> markAsRead(int notificationId) async {
    lastMarkedReadId = notificationId;
    state = state.copyWith(
      notifications: state.notifications
          .map(
            (n) => n.id == notificationId
                ? n.copyWith(readAt: DateTime.now())
                : n,
          )
          .toList(),
      unreadCount: state.unreadCount > 0 ? state.unreadCount - 1 : 0,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('UserProfileScreen Resignation Submission & Pending Pill Feedback', () {
    testWidgets(
      'Submitting resignation shows Airy Minimalist success dialog and transitions UserProfileScreen to Menunggu Persetujuan Resign',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final orgNotifier = _InteractiveOrgNotifier(
          const OrganizationState(
            businessId: 1,
            businessName: 'AwanRental',
            userRole: 'staff',
            resignationRequests: [],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _TestAuthNotifier(
                  const AuthState(
                    isAuthenticated: true,
                    user: {
                      'id': 'staff-1',
                      'name': 'Agus Pratama',
                      'email': 'agus@rentcore.id',
                      'role': 'staff',
                    },
                  ),
                ),
              ),
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'AwanRental',
                    businesses: [
                      {
                        'id': 1,
                        'name': 'AwanRental',
                        'role': 'staff',
                        'branches': [
                          {'id': 10, 'name': 'Cabang Pusat', 'is_central': true},
                        ],
                      },
                    ],
                  ),
                ),
              ),
              organizationProvider.overrideWith(() => orgNotifier),
            ],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final resignTile = find.byKey(const Key('user_profile_resign_tile'));
        expect(resignTile, findsOneWidget);
        await tester.ensureVisible(resignTile);
        await tester.tap(resignTile);
        await tester.pumpAndSettle();

        // Enter resignation reason in StaffResignationSheet
        await tester.enterText(
          find.widgetWithText(TextField, 'Alasan Pengunduran Diri (Opsional)'),
          'Pindah domisili keluar kota',
        );
        await tester.tap(find.text('Ajukan Pengunduran Diri'));
        await tester.pumpAndSettle();

        // Confirm alert
        await tester.tap(find.text('Ya, Ajukan Resign'));
        await tester.pumpAndSettle();

        expect(orgNotifier.lastSubmittedReason, 'Pindah domisili keluar kota');

        // Verify Airy Minimalist success dialog
        expect(find.text('Pengajuan Resign Terkirim'), findsOneWidget);
        expect(
          find.text('Pengajuan Anda telah diteruskan ke Owner untuk ditinjau.'),
          findsOneWidget,
        );
        final understandBtn = find.byKey(
          const Key('resign_success_understand_button'),
        );
        expect(understandBtn, findsOneWidget);

        await tester.tap(understandBtn);
        await tester.pumpAndSettle();

        // Back on UserProfileScreen -> immediately shows Menunggu Persetujuan Resign pill & reason
        expect(
          find.byKey(const Key('profile_resign_pending_pill')),
          findsOneWidget,
        );
        expect(find.text('Menunggu Persetujuan Resign'), findsOneWidget);
        expect(
          find.textContaining('Pindah domisili keluar kota'),
          findsOneWidget,
        );

        // Opening sheet again prevents duplicate submission (pending state + cancel only)
        await tester.ensureVisible(resignTile);
        await tester.tap(resignTile);
        await tester.pumpAndSettle();
        expect(find.text('Batalkan Pengajuan Resign'), findsOneWidget);
        expect(find.text('Ajukan Pengunduran Diri'), findsNothing);
      },
    );
  });

  group('ManageOrganizationScreen Tim & Staf Resignation Approval / Rejection', () {
    OrganizationState buildOrgStateWithPending() {
      return const OrganizationState(
        businessId: 1,
        businessName: 'AwanRental',
        userRole: 'owner',
        branches: [
          {'id': 10, 'name': 'Cabang Pusat', 'code': 'PST', 'is_central': true},
        ],
        members: [
          {
            'id': 1,
            'role': 'owner',
            'user': {
              'id': 'owner-1',
              'name': 'Owner Hadi',
              'email': 'owner@awan.id',
            },
            'branch_members': [],
          },
          {
            'id': 2,
            'role': 'staff',
            'user': {
              'id': 'staff-1',
              'name': 'Agus Pratama',
              'email': 'agus@awan.id',
            },
            'branch_members': [
              {
                'affiliate_id': 10,
                'branch': {'id': 10, 'name': 'Cabang Pusat'},
              },
            ],
          },
        ],
        resignationRequests: [
          {
            'id': 88,
            'business_id': 1,
            'business_member_id': 2,
            'user_id': 'staff-1',
            'status': 'pending',
            'reason': 'Fokus studi lanjut',
          },
        ],
      );
    }

    testWidgets(
      'Owner approving pending resignation updates team state and displays success confirmation',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final orgNotifier = _InteractiveOrgNotifier(buildOrgStateWithPending());
        final notifNotifier = _StubNotificationNotifier(const NotificationState());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              organizationProvider.overrideWith(() => orgNotifier),
              notificationProvider.overrideWith(() => notifNotifier),
            ],
            child: const MaterialApp(
              home: ManageOrganizationScreen(
                businessId: 1,
                businessName: 'AwanRental',
                initialTabIndex: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Pengajuan Resign'), findsOneWidget);
        final approveBtn = find.byKey(const Key('member_approve_resign_88'));
        expect(approveBtn, findsOneWidget);

        await tester.tap(approveBtn);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ya, Setujui & Cabut Akses'));
        await tester.pumpAndSettle();

        expect(orgNotifier.lastReviewedRequestId, 88);
        expect(orgNotifier.lastReviewApprove, isTrue);
        expect(
          find.text('Pengajuan resign Agus Pratama berhasil disetujui'),
          findsOneWidget,
        );
        expect(find.text('Pengajuan Resign'), findsNothing);
      },
    );

    testWidgets(
      'Owner rejecting pending resignation sends note, clears pending badge, and shows feedback',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final orgNotifier = _InteractiveOrgNotifier(buildOrgStateWithPending());
        final notifNotifier = _StubNotificationNotifier(const NotificationState());

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              organizationProvider.overrideWith(() => orgNotifier),
              notificationProvider.overrideWith(() => notifNotifier),
            ],
            child: const MaterialApp(
              home: ManageOrganizationScreen(
                businessId: 1,
                businessName: 'AwanRental',
                initialTabIndex: 1,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final rejectBtn = find.byKey(const Key('member_reject_resign_88'));
        await tester.tap(rejectBtn);
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Catatan Penolakan (Opsional)'),
          'Masih masa sibuk libur panjang',
        );
        await tester.tap(find.byKey(const Key('confirm_reject_resignation_button')));
        await tester.pumpAndSettle();

        expect(orgNotifier.lastReviewedRequestId, 88);
        expect(orgNotifier.lastReviewApprove, isFalse);
        expect(orgNotifier.lastReviewNotes, 'Masih masa sibuk libur panjang');
        expect(
          find.text('Pengajuan resign Agus Pratama ditolak'),
          findsOneWidget,
        );
        expect(find.text('Pengajuan Resign'), findsNothing);
      },
    );
  });

  group('NotificationCenterScreen Two-Way Resignation Deep-Link Routing', () {
    testWidgets(
      'Tapping resign_requested navigates Owner to ManageOrganizationScreen focused on Tim & Staf tab',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final orgNotifier = _InteractiveOrgNotifier(
          const OrganizationState(
            businessId: 1,
            businessName: 'AwanRental',
            userRole: 'owner',
            members: [
              {
                'id': 2,
                'role': 'staff',
                'user': {'id': 'staff-1', 'name': 'Agus', 'email': 'a@b.c'},
                'branch_members': [],
              },
            ],
          ),
        );

        final notifNotifier = _StubNotificationNotifier(
          NotificationState(
            unreadCount: 1,
            notifications: [
              NotificationItem(
                id: 501,
                businessId: 1,
                category: 'membership',
                type: 'staff.resignation_submitted',
                title: 'Pengajuan Resign Staf',
                body: 'Agus mengajukan pengunduran diri.',
                actionPayload: const {
                  'business_id': 1,
                  'business_name': 'AwanRental',
                  'target_route': 'manage_team',
                },
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationProvider.overrideWith(() => notifNotifier),
              organizationProvider.overrideWith(() => orgNotifier),
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'AwanRental',
                    businesses: [
                      {'id': 1, 'name': 'AwanRental', 'role': 'owner'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: NotificationCenterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Pengajuan Resign Staf • Baru saja', findRichText: true));
        await tester.pumpAndSettle();

        expect(find.byType(ManageOrganizationScreen), findsOneWidget);
        final orgScreen = tester.widget<ManageOrganizationScreen>(
          find.byType(ManageOrganizationScreen),
        );
        expect(orgScreen.initialTabIndex, 1);
        expect(find.text('Tinjau Pengajuan'), findsNothing);
      },
    );

    testWidgets(
      'Tapping resign_approved refreshes BusinessProvider safely and navigates Staff to UserProfileScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bizNotifier = _TestBusinessNotifier(
          const BusinessState(
            activeBusinessId: 1,
            activeBusinessName: 'AwanRental',
            businesses: [
              {'id': 1, 'name': 'AwanRental', 'role': 'staff'},
            ],
          ),
          dropRevokedBusinessOnRefresh: true,
        );

        final notifNotifier = _StubNotificationNotifier(
          NotificationState(
            unreadCount: 1,
            notifications: [
              NotificationItem(
                id: 601,
                businessId: 1,
                category: 'membership',
                type: 'staff.resignation_approved',
                title: 'Pengajuan Resign Disetujui',
                body:
                    'Pengajuan resign Anda dari AwanRental telah disetujui oleh Owner Hadi.',
                actionRoute: '/profile',
                actionPayload: const {
                  'business_id': 1,
                  'business_name': 'AwanRental',
                  'target_route': 'user_profile',
                  'status': 'approved',
                },
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationProvider.overrideWith(() => notifNotifier),
              businessProvider.overrideWith(() => bizNotifier),
              authProvider.overrideWith(
                () => _TestAuthNotifier(
                  const AuthState(
                    isAuthenticated: true,
                    user: {
                      'id': 'staff-1',
                      'name': 'Agus',
                      'email': 'agus@rentcore.id',
                      'role': 'staff',
                    },
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: NotificationCenterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Pengajuan Resign Disetujui • Baru saja', findRichText: true),
        );
        await tester.pumpAndSettle();

        expect(bizNotifier.refreshCalls, greaterThanOrEqualTo(1));
        expect(find.byType(UserProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Tapping resign_rejected navigates Staff to UserProfileScreen without revoking business context',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bizNotifier = _TestBusinessNotifier(
          const BusinessState(
            activeBusinessId: 1,
            activeBusinessName: 'AwanRental',
            businesses: [
              {'id': 1, 'name': 'AwanRental', 'role': 'staff'},
            ],
          ),
        );

        final notifNotifier = _StubNotificationNotifier(
          NotificationState(
            unreadCount: 1,
            notifications: [
              NotificationItem(
                id: 602,
                businessId: 1,
                category: 'membership',
                type: 'staff.resignation_rejected',
                title: 'Pengajuan Resign Ditolak',
                body:
                    'Pengajuan resign Anda di AwanRental ditolak oleh Owner Hadi. Catatan: Masih sibuk.',
                actionRoute: '/profile',
                actionPayload: const {
                  'business_id': 1,
                  'business_name': 'AwanRental',
                  'rejection_reason': 'Masih sibuk.',
                  'target_route': 'user_profile',
                  'status': 'rejected',
                },
                createdAt: DateTime.now(),
              ),
            ],
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              notificationProvider.overrideWith(() => notifNotifier),
              businessProvider.overrideWith(() => bizNotifier),
              authProvider.overrideWith(
                () => _TestAuthNotifier(
                  const AuthState(
                    isAuthenticated: true,
                    user: {
                      'id': 'staff-1',
                      'name': 'Agus',
                      'email': 'agus@rentcore.id',
                      'role': 'staff',
                    },
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: NotificationCenterScreen()),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.text('Pengajuan Resign Ditolak • Baru saja', findRichText: true),
        );
        await tester.pumpAndSettle();

        expect(bizNotifier.refreshCalls, 0);
        expect(find.byType(UserProfileScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

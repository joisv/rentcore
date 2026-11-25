import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/rental_queue_actions.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/home/presentation/home_screen.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  bool loggedOut = false;

  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {
          'id': 1,
          'name': 'Hadi Purwanto',
          'email': 'gwennrepair@gmail.com',
          'role': 'owner',
        },
      );

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Gwenn Rental Malang',
        activeBranchId: 10,
        activeBranchName: 'Gwenn Rental Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'Gwenn Rental Malang',
            'role': 'owner',
            'branches': [
              {
                'id': 10,
                'name': 'Gwenn Rental Pusat',
                'code': 'GRM',
                'city': 'Malang',
                'is_central': true,
              },
            ],
          },
        ],
      );
}

class _TestNotificationNotifier extends NotificationNotifier {
  @override
  NotificationState build() => const NotificationState();

  @override
  Future<void> fetchUnreadCountOnly() async {}
}

class _FakeOverlayBookingRepo extends BookingRepository {
  int? cancelledBookingId;
  String? cancelledReason;

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>> cancelBooking(
    dynamic bookingId, {
    String? reason,
  }) async {
    cancelledBookingId = (bookingId as num).toInt();
    cancelledReason = reason;
    return {'id': bookingId, 'status': 'cancelled'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Dashboard Overlays Revision', () {
    testWidgets(
      'HomeScreen left menu opens 78% slide-over Drawer with shift pill and bottom-pinned Keluar Akun',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final authNotifier = _TestAuthNotifier();
        final fakeRepo = _FakeOverlayBookingRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => authNotifier),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              notificationProvider.overrideWith(_TestNotificationNotifier.new),
              dashboardKpiProvider.overrideWith(
                (ref) => Future.value(<String, dynamic>{
                  'kpi': <String, dynamic>{},
                  'overdue_list': <dynamic>[],
                }),
              ),
              bookingRepositoryProvider.overrideWithValue(fakeRepo),
              currentShiftByBranchProvider.overrideWith(
                (ref, branchId) => Future.value(<String, dynamic>{
                  'has_active_shift': true,
                  'shift': {
                    'id': 9,
                    'status': 'open',
                    'shift_number': 'SHF-09',
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: HomeScreen(
                onNavigateTab: (_) {},
                onOpenDirectRental: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('home_header_menu_button')));
        await tester.pumpAndSettle();

        final drawerFinder = find.byType(Drawer);
        expect(drawerFinder, findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);

        final drawerBox = tester.getSize(drawerFinder);
        expect(drawerBox.width, closeTo(360 * 0.78, 1.0));

        expect(find.text('HP'), findsOneWidget);
        expect(find.text('Hadi Purwanto'), findsOneWidget);
        expect(find.text('Owner'), findsOneWidget);
        expect(find.text('Shift Aktif • SHF-09'), findsOneWidget);
        expect(find.text('Ganti Usaha / Cabang'), findsOneWidget);
        expect(find.text('Profil Pengguna'), findsOneWidget);
        expect(find.text('Keluar Akun'), findsOneWidget);

        // Verify Keluar Akun is pinned near the bottom of the drawer
        final logoutTop = tester.getTopLeft(find.text('Keluar Akun')).dy;
        final profileBottom = tester.getBottomLeft(find.text('Profil Pengguna')).dy;
        expect(logoutTop, greaterThan(profileBottom + 100));

        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();
        expect(authNotifier.loggedOut, isTrue);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'showOverflowActionsSheet for booked status filters strictly to booked actions with zero overflow at 360x640',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _FakeOverlayBookingRepo();
        final booking = <String, dynamic>{
          'id': 77,
          'booking_code': 'RC-261118-0007-OYS',
          'status': 'booked',
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => RentalQueueActions.showOverflowActionsSheet(
                        context,
                        ref,
                        booking,
                      ),
                      child: const Text('Open Overflow'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Overflow'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Aksi Transaksi'), findsOneWidget);
        expect(find.text('RC-261118-0007-OYS'), findsOneWidget);

        // Booked actions visible
        expect(find.text('Ubah Jadwal'), findsOneWidget);
        expect(find.text('Perpanjang Batas Ambil (+30 mnt)'), findsOneWidget);
        expect(find.text('Tandai No-Show'), findsOneWidget);
        expect(find.text('Batalkan Booking'), findsOneWidget);

        // Active-only actions hidden
        expect(find.text('Tambah Jam / Perpanjang'), findsNothing);
        expect(find.text('Ganti Unit Fisik'), findsNothing);
        expect(find.text('Cetak Ulang Struk'), findsNothing);

        // Cancel flow works
        await tester.tap(find.byKey(const Key('overflow_cancel_booking_tile')));
        await tester.pumpAndSettle();
        expect(find.text('Batalkan Booking'), findsOneWidget);
        await tester.tap(find.text('Konfirmasi Batal'));
        await tester.pumpAndSettle();
        expect(fakeRepo.cancelledBookingId, 77);
      },
    );

    testWidgets(
      'showOverflowActionsSheet for active status shows only active actions',
      (tester) async {
        final fakeRepo = _FakeOverlayBookingRepo();
        final booking = <String, dynamic>{
          'id': 88,
          'booking_code': 'RC-261118-0088-ACT',
          'status': 'active',
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => RentalQueueActions.showOverflowActionsSheet(
                        context,
                        ref,
                        booking,
                      ),
                      child: const Text('Open Active Overflow'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Active Overflow'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Tambah Jam / Perpanjang'), findsOneWidget);
        expect(find.text('Ganti Unit Fisik'), findsOneWidget);
        expect(find.text('Cetak Ulang Struk'), findsOneWidget);

        expect(find.text('Ubah Jadwal'), findsNothing);
        expect(find.text('Perpanjang Batas Ambil (+30 mnt)'), findsNothing);
        expect(find.text('Tandai No-Show'), findsNothing);
        expect(find.text('Batalkan Booking'), findsNothing);
      },
    );

    testWidgets(
      'showOverflowActionsSheet for returned status shows only Cetak Ulang Struk',
      (tester) async {
        final fakeRepo = _FakeOverlayBookingRepo();
        final booking = <String, dynamic>{
          'id': 99,
          'booking_code': 'RC-261118-0099-RET',
          'status': 'returned',
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => RentalQueueActions.showOverflowActionsSheet(
                        context,
                        ref,
                        booking,
                      ),
                      child: const Text('Open Returned Overflow'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open Returned Overflow'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Cetak Ulang Struk'), findsOneWidget);
        expect(find.text('Tambah Jam / Perpanjang'), findsNothing);
        expect(find.text('Ganti Unit Fisik'), findsNothing);
        expect(find.text('Ubah Jadwal'), findsNothing);
        expect(find.text('Tandai No-Show'), findsNothing);
        expect(find.text('Batalkan Booking'), findsNothing);
      },
    );

    testWidgets(
      'confirmMarkNoShow renders 2-segment DP toggle and aligned side-by-side Batal & Konfirmasi No-Show buttons',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _FakeOverlayBookingRepo();
        final booking = <String, dynamic>{
          'id': 123,
          'booking_code': 'RC-261121-0001-AMD',
          'status': 'late_pickup',
          'paid_amount': 50000,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              home: Consumer(
                builder: (context, ref, _) => Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => RentalQueueActions.confirmMarkNoShow(
                        context,
                        ref,
                        booking,
                      ),
                      child: const Text('Open No-Show'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open No-Show'));
        await tester.pumpAndSettle();

        expect(find.text('Tandai No-Show'), findsOneWidget);
        expect(find.text('Hanguskan DP'), findsOneWidget);
        expect(find.text('Refund DP'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Konfirmasi No-Show'), findsOneWidget);

        // Verify side-by-side alignment (identical Y coordinates & non-overlapping X)
        final cancelRect = tester.getRect(find.text('Batal'));
        final confirmRect = tester.getRect(find.text('Konfirmasi No-Show'));
        expect((cancelRect.center.dy - confirmRect.center.dy).abs(), lessThan(2.0));
        expect(confirmRect.left, greaterThan(cancelRect.right));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PosTransactionDetailSheet renders open hairline layout, full code, Cabang Siliragung, and sticky footer',
      (tester) async {
        tester.view.physicalSize = const Size(360, 780);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final booking = <String, dynamic>{
          'id': 404,
          'booking_code': 'RC-261121-0001-AMD',
          'status': 'late_pickup',
          'payment_status': 'partial',
          'total_bill': 50000,
          'subtotal_amount': 50000,
          'discount_amount': 0,
          'paid_amount': 33000,
          'start_at': DateTime.now()
              .subtract(const Duration(hours: 2))
              .toIso8601String(),
          'end_at': DateTime.now()
              .add(const Duration(hours: 22))
              .toIso8601String(),
          'affiliate': {'name': 'siliragung', 'is_central': false},
          'customer': {'name': 'Andi', 'phone': '081234567890'},
          'creator': {'name': 'Staff'},
          'items': [],
          'payments': [
            {'id': 1, 'type': 'dp', 'amount': 33000, 'payment_method': 'Tunai'},
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingDetailProvider(404).overrideWith((ref) => Future.value(booking)),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: PosTransactionDetailSheet(booking: booking),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Rincian Transaksi'), findsOneWidget);
        expect(find.text('RC-261121-0001-AMD'), findsOneWidget);
        expect(find.text('Sebagian'), findsOneWidget);
        expect(find.byKey(const Key('detail_late_pickup_badge')), findsOneWidget);
        expect(find.text('Cabang Siliragung'), findsOneWidget);
        expect(find.text('CABANG'), findsNothing);
        expect(find.byKey(const Key('detail_handover_button')), findsOneWidget);
        expect(find.text('Perpanjang (+30m)'), findsOneWidget);
        expect(find.byKey(const Key('detail_mark_noshow_button')), findsOneWidget);
        expect(find.byKey(const Key('reprint_receipt_button')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

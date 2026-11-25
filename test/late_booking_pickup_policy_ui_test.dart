import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/bookings_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeAuthRepository extends AuthRepository {
  int? lastBusinessId;
  Map<String, dynamic>? lastBusinessPayload;

  @override
  Future<Map<String, dynamic>> updateBusiness(
    int businessId,
    Map<String, dynamic> payload,
  ) async {
    lastBusinessId = businessId;
    lastBusinessPayload = Map<String, dynamic>.from(payload);
    return {'id': businessId, ...payload};
  }
}

class _FakeCashierRepository extends CashierRepository {
  final List<Map<String, dynamic>> bookings;
  _FakeCashierRepository(this.bookings);

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    return bookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => <String, dynamic>{},
    );
  }
}

class _FakeBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> bookings = [];
  int? lastExtendedBookingId;
  int? lastExtendedMinutes;
  int? lastNoShowBookingId;
  String? lastNoShowDisposition;

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return bookings;
  }

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    return bookings.firstWhere(
      (b) => b['id'] == bookingId,
      orElse: () => <String, dynamic>{},
    );
  }

  @override
  Future<Map<String, dynamic>> extendGracePeriod(
    dynamic bookingId, {
    int additionalMinutes = 30,
  }) async {
    lastExtendedBookingId = (bookingId as num).toInt();
    lastExtendedMinutes = additionalMinutes;
    return {'id': bookingId, 'status': 'booked'};
  }

  @override
  Future<Map<String, dynamic>> markNoShow(
    dynamic bookingId, {
    String? reason,
  }) async {
    lastNoShowBookingId = (bookingId as num).toInt();
    lastNoShowDisposition = 'forfeited';
    return {'id': bookingId, 'status': 'no_show'};
  }

  @override
  Future<Map<String, dynamic>> markNoShowWithDisposition(
    dynamic bookingId, {
    String? reason,
    required String dpDisposition,
  }) async {
    lastNoShowBookingId = (bookingId as num).toInt();
    lastNoShowDisposition = dpDisposition;
    return {'id': bookingId, 'status': 'no_show', 'dp_disposition': dpDisposition};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BusinessState createBusinessState({String role = 'owner'}) => BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Pusat',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Pusat',
            'role': role,
            'booking_grace_period_minutes': 60,
            'auto_expire_unpaid_booking': true,
            'auto_expire_paid_booking': false,
            'late_pickup_end_time_mode': 'keep_original_end',
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat', 'code': 'PST', 'is_central': true},
            ],
          },
        ],
      );

  testWidgets(
    'BookingsScreen shows Terlambat Ambil badge with elapsed minutes and Detail Sheet exposes late-pickup actions',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.now();
      final lateGrace = now.subtract(const Duration(minutes: 25));

      final fakeBookingRepo = _FakeBookingRepository()
        ..bookings = [
          {
            'id': 301,
            'booking_code': 'RC-LATE-301',
            'status': 'late_pickup',
            'is_late_pickup': true,
            'payment_status': 'partial',
            'paid_amount': 100000,
            'remaining_balance': 250000,
            'total_bill': 350000,
            'subtotal_amount': 350000,
            'discount_amount': 0,
            'start_at': lateGrace.subtract(const Duration(minutes: 60)).toIso8601String(),
            'end_at': now.add(const Duration(hours: 20)).toIso8601String(),
            'grace_expires_at': lateGrace.toIso8601String(),
            'customer': {'name': 'Dewi Anggraini', 'phone': '081234567890'},
            'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
            'items': [],
            'payments': [],
          },
        ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
            cashierRepositoryProvider.overrideWithValue(
              _FakeCashierRepository(fakeBookingRepo.bookings),
            ),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(
            home: BookingsScreen(initialFilter: 'booked'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // List card shows Terlambat Ambil (+Xm)
      expect(find.textContaining('Terlambat Ambil (+'), findsOneWidget);

      // Open Rincian (Detail Sheet)
      await tester.tap(find.text('Rincian'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('detail_late_pickup_badge')), findsOneWidget);
      expect(find.byKey(const Key('detail_handover_button')), findsOneWidget);
      expect(find.byKey(const Key('detail_extend_pickup_button')), findsOneWidget);
      expect(find.byKey(const Key('detail_mark_noshow_button')), findsOneWidget);

      // Tap Perpanjang Tunggu (+30m)
      await tester.tap(find.byKey(const Key('detail_extend_pickup_button')));
      await tester.pumpAndSettle();
      expect(fakeBookingRepo.lastExtendedBookingId, 301);
      expect(fakeBookingRepo.lastExtendedMinutes, 30);

      // Tap Tandai No-Show and choose Refund DP
      await tester.tap(find.byKey(const Key('detail_mark_noshow_button')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Refund DP'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Konfirmasi No-Show'));
      await tester.pumpAndSettle();

      expect(fakeBookingRepo.lastNoShowBookingId, 301);
      expect(fakeBookingRepo.lastNoShowDisposition, 'refunded');
    },
  );

  testWidgets(
    'StoreSettingsScreen opens Kebijakan Booking & No-Show sub-sheet and saves policy',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuthRepo = _FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  user: {'id': 'u-1', 'name': 'Owner', 'role': 'owner'},
                  isAuthenticated: true,
                ),
              ),
            ),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(home: StoreSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu_booking_policy')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('booking_policy_bottom_sheet')), findsOneWidget);
      expect(find.byKey(const Key('policy_grace_15')), findsOneWidget);
      expect(find.byKey(const Key('policy_grace_30')), findsOneWidget);
      expect(find.byKey(const Key('policy_grace_60')), findsOneWidget);
      expect(find.byKey(const Key('policy_grace_120')), findsOneWidget);

      await tester.tap(find.byKey(const Key('policy_grace_30')));
      await tester.tap(find.byKey(const Key('policy_toggle_auto_expire_unpaid')));
      await tester.tap(find.byKey(const Key('policy_end_mode_shift')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('policy_save_button')));
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.lastBusinessId, 1);
      expect(fakeAuthRepo.lastBusinessPayload, {
        'booking_grace_period_minutes': 30,
        'auto_expire_unpaid_booking': false,
        'late_pickup_end_time_mode': 'shift_if_available',
      });
    },
  );
}

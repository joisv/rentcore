import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/core/utils/date_formatter.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDashboardRepo extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => {
    'is_empty_tenant': false,
    'branch_id': 10,
    'is_consolidated': false,
    'kpi': {
      'today_revenue': 400000.0,
      'today_rentals_created': 2,
      'today_transactions_count': 2,
      'due_today': 0,
      'units_ready': 8,
      'units_total': 10,
      'units_rented': 1,
      'units_maintenance': 0,
      'utilization_rate': 10.0,
      'overdue': 0,
    },
    'overdue_alerts': [],
    'imminent_returns': [],
  };
}

class _FakeBookingRepo extends BookingRepository {
  final List<Map<String, dynamic>> bookings;
  _FakeBookingRepo(this.bookings);

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async => bookings;

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async =>
      bookings.firstWhere(
        (b) => b['id'].toString() == bookingId.toString(),
        orElse: () => bookings.first,
      );
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Express',
    activeBranchId: 10,
    activeBranchName: 'Cabang Mataram Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Express',
        'role': 'owner',
        'branches': [
          {
            'id': 10,
            'name': 'Cabang Mataram Utama',
            'city': 'Mataram',
            'is_central': true,
          },
        ],
      },
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Rian Kasir', 'role': 'owner'},
  );
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('DateFormatter.parseLocal converts UTC once and preserves naive local timestamps', () {
    final targetLocal = DateTime(2026, 11, 18, 23, 0);
    final utcIsoFromLaravel = targetLocal.toUtc().toIso8601String();
    final naiveLocalIso = '2026-11-18T23:00:00.000';

    expect(DateFormatter.parseLocal(utcIsoFromLaravel), targetLocal);
    expect(DateFormatter.parseLocal(targetLocal), targetLocal);
    expect(DateFormatter.parseLocal(naiveLocalIso), DateTime(2026, 11, 18, 23, 0));
    expect(DateFormatter.formatFull(DateFormatter.parseLocal(utcIsoFromLaravel)), '18 Nov 2026, 23:00');
  });

  testWidgets(
    'Antrean Sewa Cabang renders 18 Nov 2026, 23:00 matching Detail sheet and shows single-line + Add-on summary when present',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      // Represent 18 Nov 2026, 23:00 local time serialized cleanly as UTC ISO-8601
      final localStart = DateTime(2026, 11, 18, 23, 0);
      final localEnd = DateTime(2026, 11, 19, 23, 0);
      final utcStartStr = localStart.toUtc().toIso8601String();
      final utcEndStr = localEnd.toUtc().toIso8601String();

      final bookingWithAddons = {
        'id': 701,
        'booking_code': 'RC-ADD-701',
        'status': 'booked',
        'payment_status': 'partial',
        'total_bill': 415000.0,
        'remaining_balance': 315000.0,
        'start_at': utcStartStr,
        'end_at': utcEndStr,
        'grace_expires_at': localStart.add(const Duration(hours: 1)).toUtc().toIso8601String(),
        'collateral_storage_slot': 'Brankas A, Slot 03',
        'customer': {'name': 'Tariq Anwar', 'phone': '081234567890'},
        'asset_model': {'id': 5, 'name': 'iPhone 15 Pro'},
        'addons': [
          {'id': 1, 'name': 'Power Bank Anker', 'quantity': 2},
          {'id': 2, 'name': 'Fast Charger 67W', 'quantity': 1},
        ],
        'items': [],
        'payments': [
          {'type': 'dp', 'amount': 100000.0, 'status': 'completed'},
        ],
      };

      final bookingWithoutAddons = {
        'id': 702,
        'booking_code': 'RC-NOADD-702',
        'status': 'rented',
        'payment_status': 'paid',
        'total_bill': 350000.0,
        'start_at': utcStartStr,
        'end_at': utcEndStr,
        'collateral_storage_slot': 'Brankas A, Slot 04',
        'customer': {'name': 'Bima Pratama', 'phone': '081299887766'},
        'asset_unit': {
          'id': 12,
          'asset_code': 'IP15-012',
          'serial_number': 'SN-012',
          'model': {'id': 5, 'name': 'iPhone 15'},
        },
        'addons': [],
        'items': [],
        'payments': [
          {'type': 'settlement', 'amount': 350000.0, 'status': 'completed'},
        ],
      };

      final bookingRepo = _FakeBookingRepo([
        bookingWithAddons,
        bookingWithoutAddons,
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            bookingDetailProvider(701).overrideWith((ref) => Future.value(bookingWithAddons)),
            businessProvider.overrideWith(() => _TestBusinessNotifier()),
            authProvider.overrideWith(() => _TestAuthNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both cards display 18 Nov 2026, 23:00 (booked) and 19 Nov 2026, 23:00 (active) — zero +7h shift
      expect(
        find.text('Ambil: 18 Nov 2026, 23:00 • Batas 00:00'),
        findsOneWidget,
      );
      expect(find.text('Kembali: 19 Nov 2026, 23:00'), findsOneWidget);

      // Single-line add-on summary renders ONLY once (second card with no addons renders SizedBox.shrink)
      expect(find.byKey(const Key('queue_card_addons_summary')), findsOneWidget);
      expect(
        find.text('+ Add-on: Power Bank Anker (2x), Fast Charger 67W'),
        findsOneWidget,
      );

      // Open Detail screen for RC-ADD-701 and verify identical timestamps down to exact minute
      await tester.tap(find.text('Rincian').first);
      await tester.pumpAndSettle();
      expect(find.byType(PosTransactionDetailSheet), findsOneWidget);
      expect(find.text('18 Nov 2026, 23:00'), findsOneWidget);
      expect(find.text('19 Nov 2026, 23:00'), findsOneWidget);
    },
  );
}

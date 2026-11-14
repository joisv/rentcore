import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDashboardRepo extends DashboardRepository {
  final Map<String, dynamic> data;
  _FakeDashboardRepo(this.data);

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => data;
}

class _FakeBookingRepoForDashboard extends BookingRepository {
  List<Map<String, dynamic>> bookings = [];
  _FakeBookingRepoForDashboard(this.bookings);

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    var result = List<Map<String, dynamic>>.from(bookings);
    if (status != null && status != 'all') {
      result = result.where((b) => b['status'] == status).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      result = result.where((b) {
        final code = (b['booking_code'] ?? '').toString().toLowerCase();
        final name = (b['customer']?['name'] ?? '').toString().toLowerCase();
        final phone = (b['customer']?['phone'] ?? '').toString().toLowerCase();
        final items = (b['items'] as List?) ?? [];
        final itemNames = items
            .map((it) {
              if (it is Map) {
                final asset = it['asset'] as Map?;
                final model = asset?['model'] as Map?;
                return (model?['name'] ?? '').toString().toLowerCase();
              }
              return '';
            })
            .join(' ');
        return code.contains(s) ||
            name.contains(s) ||
            phone.contains(s) ||
            itemNames.contains(s);
      }).toList();
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    return bookings.firstWhere(
      (b) => b['id'] == bookingId || b['booking_code'] == bookingId,
      orElse: () => <String, dynamic>{},
    );
  }
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('HomeScreen Dashboard Refactor Test Suite', () {
    final now = DateTime.now();

    final testDashboardKpiData = {
      'is_empty_tenant': false,
      'branch_id': 10,
      'is_consolidated': false,
      'kpi': {
        'today_revenue': 1450000.0,
        'today_rentals_created': 8,
        'today_transactions_count': 8,
        'due_today': 5,
        'units_ready': 12,
        'units_total': 20,
        'units_rented': 7,
        'units_maintenance': 1,
        'utilization_rate': 35.0,
        'overdue': 1,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
    };

    final overdueBooking = {
      'id': 1,
      'booking_code': 'RC-OVERDUE-01',
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': now.subtract(const Duration(days: 2)).toIso8601String(),
      'end_at': now
          .subtract(const Duration(hours: 3))
          .toIso8601String(), // Overdue
      'total_bill': 250000.0,
      'customer': {'name': 'Joko Overdue', 'phone': '08111111111'},
      'items': [
        {
          'asset': {
            'model': {'name': 'Sony A7 IV'},
          },
        },
      ],
    };

    final dueTodayBooking = {
      'id': 2,
      'booking_code': 'RC-DUETODAY-02',
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': now.subtract(const Duration(hours: 5)).toIso8601String(),
      'end_at': now.add(const Duration(hours: 2)).toIso8601String(), // Due today
      'total_bill': 150000.0,
      'customer': {'name': 'Siti DueToday', 'phone': '08222222222'},
      'items': [
        {
          'asset': {
            'model': {'name': 'Canon EOS R6'},
          },
        },
      ],
    };

    final awaitingHandoverBooking = {
      'id': 3,
      'booking_code': 'RC-PENDING-03',
      'status': 'confirmed',
      'payment_status': 'unpaid',
      'start_at': now.add(const Duration(hours: 1)).toIso8601String(),
      'end_at': now.add(const Duration(days: 2)).toIso8601String(),
      'total_bill': 350000.0,
      'remaining_balance': 350000.0,
      'customer': {'name': 'Budi Handover', 'phone': '08333333333'},
      'items': [
        {
          'asset': {
            'model': {'name': 'iPad Pro M4'},
          },
        },
      ],
    };

    final activeBooking = {
      'id': 4,
      'booking_code': 'RC-ACTIVE-04',
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
      'end_at': now.add(const Duration(days: 3)).toIso8601String(),
      'total_bill': 400000.0,
      'customer': {'name': 'Rian Active', 'phone': '08444444444'},
      'items': [
        {
          'asset': {
            'model': {'name': 'MacBook Pro M3'},
          },
        },
      ],
    };

    final completedBooking = {
      'id': 5,
      'booking_code': 'RC-RETURNED-05',
      'status': 'returned',
      'payment_status': 'paid',
      'start_at': now.subtract(const Duration(days: 3)).toIso8601String(),
      'end_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
      'total_bill': 200000.0,
      'customer': {'name': 'Andi Completed', 'phone': '08555555555'},
      'items': [
        {
          'asset': {
            'model': {'name': 'Fujifilm X-T5'},
          },
        },
      ],
    };

    testWidgets('1. Consolidated Header & Clickable Branch Badge', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            businessProvider.overrideWith(_TestBusinessNotifier.new),
            dashboardRepositoryProvider.overrideWithValue(
              _FakeDashboardRepo(testDashboardKpiData),
            ),
            bookingRepositoryProvider.overrideWithValue(
              _FakeBookingRepoForDashboard([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(onNavigateTab: (_) {}, onOpenDirectRental: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Cashier greeting and name
      expect(find.textContaining('Hai, Rian Kasir'), findsOneWidget);

      // Clickable Branch Badge with branch name, city, and arrow
      expect(find.text('Cabang Mataram Utama'), findsOneWidget);
      expect(find.text(' • Mataram'), findsOneWidget);
      expect(find.byTooltip('Ganti Cabang'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsWidgets);

      // Notification icon
      expect(find.byTooltip('Pusat Pemberitahuan'), findsOneWidget);
      expect(find.byIcon(Icons.notifications_outlined), findsOneWidget);
    });

    testWidgets('2. 2x2 Daily Operations Summary Grid', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(_TestAuthNotifier.new),
            businessProvider.overrideWith(_TestBusinessNotifier.new),
            dashboardRepositoryProvider.overrideWithValue(
              _FakeDashboardRepo(testDashboardKpiData),
            ),
            bookingRepositoryProvider.overrideWithValue(
              _FakeBookingRepoForDashboard([]),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(onNavigateTab: (_) {}, onOpenDirectRental: () {}),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Metric 1: Pendapatan Hari Ini
      expect(find.text('PENDAPATAN HARI INI'), findsOneWidget);
      expect(find.text('Rp 1.450.000'), findsOneWidget);

      // Metric 2: Sewa Hari Ini
      expect(find.text('SEWA HARI INI'), findsOneWidget);
      expect(find.text('8 Transaksi'), findsOneWidget);

      // Metric 3: Pengembalian Hari Ini
      expect(find.text('PENGEMBALIAN HARI INI'), findsOneWidget);
      expect(find.text('5 Unit'), findsOneWidget);

      // Metric 4: Unit Tersedia
      expect(find.text('UNIT TERSEDIA'), findsOneWidget);
      expect(find.text('12 Unit Siap'), findsOneWidget);

      // Verify zero legacy icon clutter (no check_circle, no schedule, no build icons in cards)
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.build_circle_outlined), findsNothing);
      expect(find.byIcon(Icons.devices_other_rounded), findsNothing);
    });

    testWidgets(
      '3. Embedded Branch Rental Queue with Action-Priority Sorting',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Pass shuffled bookings list
        final bookingsRepo = _FakeBookingRepoForDashboard([
          completedBooking,
          activeBooking,
          dueTodayBooking,
          overdueBooking,
          awaitingHandoverBooking,
        ]);

        int navigatedTab = -1;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              dashboardRepositoryProvider.overrideWithValue(
                _FakeDashboardRepo(testDashboardKpiData),
              ),
              bookingRepositoryProvider.overrideWithValue(bookingsRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: HomeScreen(
                onNavigateTab: (tab) => navigatedTab = tab,
                onOpenDirectRental: () {},
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Section Header + Quick Status Filter Bar
        expect(find.text('Antrean Sewa Cabang'), findsOneWidget);
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Terlambat'), findsOneWidget);
        expect(find.text('Hari Ini'), findsOneWidget);
        expect(find.text('Booking'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);
        expect(navigatedTab, -1);

        // All 5 bookings rendered
        expect(find.text('RC-OVERDUE-01'), findsOneWidget);
        expect(find.text('RC-DUETODAY-02'), findsOneWidget);
        expect(find.text('RC-PENDING-03'), findsOneWidget);
        expect(find.text('RC-ACTIVE-04'), findsOneWidget);
        expect(find.text('RC-RETURNED-05'), findsOneWidget);

        // Action-Priority Order Verification:
        // Overdue (P1) < Due Today (P2) < Pending (P3) < Active (P4) < Completed (P5)
        final posOverdue = tester.getTopLeft(find.text('RC-OVERDUE-01')).dy;
        final posDueToday = tester.getTopLeft(find.text('RC-DUETODAY-02')).dy;
        final posPending = tester.getTopLeft(find.text('RC-PENDING-03')).dy;
        final posActive = tester.getTopLeft(find.text('RC-ACTIVE-04')).dy;
        final posCompleted = tester.getTopLeft(find.text('RC-RETURNED-05')).dy;

        expect(
          posOverdue,
          lessThan(posDueToday),
          reason: 'P1 Overdue must appear before P2 Due Today',
        );
        expect(
          posDueToday,
          lessThan(posPending),
          reason: 'P2 Due Today must appear before P3 Handover',
        );
        expect(
          posPending,
          lessThan(posActive),
          reason: 'P3 Handover must appear before P4 Active',
        );
        expect(
          posActive,
          lessThan(posCompleted),
          reason: 'P4 Active must appear before P5 Completed',
        );

        // Card Content & Status Pills (Antrean Sewa Cabang layout)
        expect(find.textContaining('Terlambat '), findsOneWidget);
        expect(find.text('Jatuh Tempo'), findsOneWidget);
        expect(find.text('Siap Diambil'), findsOneWidget);
        expect(find.textContaining('Sisa '), findsOneWidget);
        expect(find.text('SELESAI'), findsOneWidget);
        expect(find.text('Total Tagihan'), findsNWidgets(5));
        expect(find.textContaining('Batas sewa:'), findsNWidgets(5));

        // Action buttons
        expect(find.text('Rincian'), findsWidgets);
        expect(find.text('Kembalikan'), findsWidgets);
      },
    );

    testWidgets(
      '4. Responsive Live Quick Search Bar filters queue with 300ms debouncing',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookingsRepo = _FakeBookingRepoForDashboard([
          overdueBooking,
          dueTodayBooking,
          awaitingHandoverBooking,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              dashboardRepositoryProvider.overrideWithValue(
                _FakeDashboardRepo(testDashboardKpiData),
              ),
              bookingRepositoryProvider.overrideWithValue(bookingsRepo),
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

        // Initially all 3 bookings visible
        expect(find.text('RC-OVERDUE-01'), findsOneWidget);
        expect(find.text('RC-DUETODAY-02'), findsOneWidget);
        expect(find.text('RC-PENDING-03'), findsOneWidget);

        // Enter search query
        final searchInput = find.byType(TextField);
        expect(searchInput, findsOneWidget);
        await tester.enterText(searchInput, 'Canon');

        // Wait 100ms: not yet debounced
        await tester.pump(const Duration(milliseconds: 100));
        // Wait remaining 250ms (total > 300ms)
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();

        // Only Canon (RC-DUETODAY-02) should match
        expect(find.text('RC-DUETODAY-02'), findsOneWidget);
        expect(find.text('RC-OVERDUE-01'), findsNothing);
        expect(find.text('RC-PENDING-03'), findsNothing);

        // Clear button (x) is visible when text is present
        expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.clear_rounded));
        await tester.pumpAndSettle();

        // All 3 restored
        expect(find.text('RC-OVERDUE-01'), findsOneWidget);
        expect(find.text('RC-DUETODAY-02'), findsOneWidget);
        expect(find.text('RC-PENDING-03'), findsOneWidget);
      },
    );

    testWidgets(
      '5. Narrow 320x568 screen layout safety & safe bottom padding',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              dashboardRepositoryProvider.overrideWithValue(
                _FakeDashboardRepo(testDashboardKpiData),
              ),
              bookingRepositoryProvider.overrideWithValue(
                _FakeBookingRepoForDashboard([overdueBooking, dueTodayBooking]),
              ),
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

        // Verify zero RenderFlex overflow warnings
        expect(tester.takeException(), isNull);

        // Verify safe area bottom padding is 100
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(
          scrollView.padding,
          equals(
            const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
          ),
        );
      },
    );
  });
}

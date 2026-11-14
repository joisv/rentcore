import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/exchange_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/financial_hub_screen.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/shared/widgets/floating_capsule_dock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Kasir Utama', 'role': 'owner'},
  );
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBranchId: 10,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore',
        'membership': {'role': 'owner'},
        'branches': [
          {'id': 10, 'name': 'Cabang Pusat', 'is_central': true},
        ],
      },
    ],
  );
}

class _FakeDashboardRepo extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => {
    'is_empty_tenant': false,
    'branch_id': 10,
    'kpi': {
      'today_revenue': 1500000.0,
      'today_transactions_count': 4,
      'active_rentals': 3,
      'pending_pickup_count': 1,
      'due_today': 1,
      'overdue': 1,
      'units_ready': 8,
      'total_units_count': 11,
    },
    'overdue_alerts': [],
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
}

class _FakeFinancialRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async => {
    'total_revenue': 2400000,
    'total_transactions': 5,
    'total_expenses': 50000,
    'cash_drawer_expenses': 50000,
    'breakdown_by_method': {
      'Tunai': {'total_amount': 900000, 'count': 2},
      'QRIS': {'total_amount': 1500000, 'count': 3},
    },
    'breakdown_by_type': {
      'rental': {'total': 1800000, 'count': 4},
      'extension': {'total': 400000, 'count': 1},
      'penalty': {'total': 200000, 'count': 1},
    },
    'recent_transactions': [
      {
        'id': 101,
        'transaction_code': 'RC-PAID-101',
        'receipt_number': 'RC-PAID-101',
        'customer_name': 'Budi Santoso',
        'payment_method': 'QRIS',
        'type': 'settlement',
        'amount': 500000,
        'created_at': '2026-11-14T10:00:00Z',
      },
    ],
    'cash_reconciliation': {
      'opening_cash_float': 300000,
      'net_cash_revenue': 850000,
      'cash_drawer_expenses': 50000,
      'expected_cash_in_drawer': 1150000,
      'active_shift': {
        'id': 77,
        'shift_number': 7,
        'status': 'open',
        'opening_cash_float': 300000,
        'expected_cash_now': 1150000,
        'cashier_name': 'Kasir Utama',
      },
    },
  };

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
    'data': {
      'shift': {
        'id': 77,
        'shift_number': 7,
        'status': 'open',
        'opening_cash_float': 300000,
        'expected_cash_now': 1150000,
      },
    },
  };

  @override
  Future<List<Map<String, dynamic>>> fetchShiftHistory({
    int? branchId,
    bool allBranches = false,
    String? startDate,
    String? endDate,
  }) async => [
    {
      'id': 76,
      'shift_number': 6,
      'status': 'closed',
      'opened_at': '2026-11-13T08:00:00Z',
      'closed_at': '2026-11-13T17:00:00Z',
      'actual_cash_counted': 1250000,
      'expected_cash_at_close': 1250000,
      'variance': 0,
      'cashier': {'name': 'Kasir Pagi'},
    },
  ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('4-Tab Navigation & Beranda Queue Consolidation', () {
    testWidgets(
      'FloatingCapsuleDock preserves original active-only pill styling and highlights [ Laporan ] when Tab 2 is tapped to open FinancialHubScreen',
      (tester) async {
        final fakeRepo = _FakeFinancialRepo();
        int currentIndex = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: StatefulBuilder(
                builder: (context, setState) {
                  return Scaffold(
                    extendBody: true,
                    body: IndexedStack(
                      index: currentIndex,
                      children: const [
                        Center(child: Text('Tab Beranda')),
                        FinancialHubScreen(),
                        Center(child: Text('Tab Aset')),
                        Center(child: Text('Tab Pengaturan')),
                      ],
                    ),
                    bottomNavigationBar: FloatingCapsuleDock(
                      currentIndex: currentIndex,
                      onTabSelected: (idx) => setState(() => currentIndex = idx),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially Tab 0 (Beranda) shows active pill label; inactive tabs show icon-only
        expect(find.text('Beranda'), findsOneWidget);
        expect(find.text('Aset'), findsNothing);
        expect(find.text('Pengaturan'), findsNothing);
        expect(find.text('Sewa'), findsNothing);
        expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
        expect(find.byIcon(Icons.analytics_outlined), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

        // Tap Tab 2 icon -> highlights [ Laporan ] pill and opens FinancialHubScreen
        await tester.tap(find.byIcon(Icons.analytics_outlined));
        await tester.pumpAndSettle();

        expect(currentIndex, 1);
        expect(find.byIcon(Icons.analytics_rounded), findsOneWidget);
        expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
        expect(find.text('Beranda'), findsNothing);
        expect(
          find.descendant(
            of: find.byType(FloatingCapsuleDock),
            matching: find.text('Laporan'),
          ),
          findsOneWidget,
        );
        expect(find.byType(FinancialHubScreen), findsOneWidget);
        expect(find.text('Pendapatan'), findsOneWidget);
        expect(find.text('Kasir & Shift'), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen quick status filter pills & 3-element queue card actions cover return, extend, swap unit, and print',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final now = DateTime.now();
        final bookings = [
          {
            'id': 1,
            'booking_code': 'RC-TELAT',
            'status': 'rented',
            'payment_status': 'paid',
            'total_bill': 300000,
            'end_at': now.subtract(const Duration(hours: 3)).toIso8601String(),
            'customer': {'name': 'Andi Telat', 'phone': '08111'},
            'items': [
              {
                'id': 11,
                'item_type': 'unit',
                'duration_hours': 24,
                'price': 300000,
                'asset': {
                  'model': {'name': 'iPhone 15 Pro'},
                },
              },
            ],
          },
          {
            'id': 2,
            'booking_code': 'RC-BOOKING',
            'status': 'confirmed',
            'payment_status': 'unpaid',
            'total_bill': 250000,
            'end_at': now.add(const Duration(days: 2)).toIso8601String(),
            'customer': {'name': 'Budi Booking', 'phone': '08222'},
            'items': [
              {
                'id': 12,
                'item_type': 'unit',
                'duration_hours': 24,
                'price': 250000,
                'asset': {
                  'model': {'name': 'PS5 Digital'},
                },
              },
            ],
          },
          {
            'id': 3,
            'booking_code': 'RC-SELESAI',
            'status': 'returned',
            'payment_status': 'paid',
            'total_bill': 200000,
            'end_at': now.subtract(const Duration(hours: 1)).toIso8601String(),
            'customer': {'name': 'Citra Selesai', 'phone': '08333'},
            'items': [
              {
                'id': 13,
                'item_type': 'unit',
                'duration_hours': 12,
                'price': 200000,
                'asset': {
                  'model': {'name': 'Sony A7 III'},
                },
              },
            ],
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
              bookingRepositoryProvider.overrideWithValue(
                _FakeBookingRepo(bookings),
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

        // All 5 filter pills & + Sewa Baru FAB visible
        expect(find.text('Semua'), findsOneWidget);
        expect(find.text('Terlambat'), findsOneWidget);
        expect(find.text('Hari Ini'), findsOneWidget);
        expect(find.text('Booking'), findsOneWidget);
        expect(find.text('Selesai'), findsOneWidget);
        expect(find.widgetWithText(FloatingActionButton, 'Sewa Baru'), findsOneWidget);

        // 3 primary actions corresponding to statuses on initial 'Semua' list
        expect(find.text('Rincian'), findsNWidgets(3));
        expect(find.text('Kembalikan'), findsOneWidget);
        expect(find.text('Serahkan Unit'), findsOneWidget);
        expect(find.text('Cetak Struk'), findsOneWidget);
        expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(3));

        // Filter to 'Booking' -> only RC-BOOKING visible
        await tester.tap(find.text('Booking'));
        await tester.pumpAndSettle();
        expect(find.text('RC-BOOKING'), findsOneWidget);
        expect(find.text('RC-TELAT'), findsNothing);
        expect(find.text('RC-SELESAI'), findsNothing);

        // Tap 'Serahkan Unit' primary action
        await tester.tap(find.text('Serahkan Unit'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Penyerahan Unit'), findsOneWidget);
        // Close handover sheet cleanly
        Navigator.of(tester.element(find.textContaining('Penyerahan Unit'))).pop();
        await tester.pumpAndSettle();

        // Filter to 'Selesai' -> only RC-SELESAI visible
        await tester.tap(find.text('Selesai'));
        await tester.pumpAndSettle();
        expect(find.text('RC-SELESAI'), findsOneWidget);
        expect(find.text('Cetak Struk'), findsOneWidget);

        // Reset filter via 'Terlambat'
        await tester.tap(find.text('Terlambat'));
        await tester.pumpAndSettle();
        expect(find.text('RC-TELAT'), findsOneWidget);
        expect(find.text('Kembalikan'), findsOneWidget);

        // Open [ ⋮ ] overflow sheet and inspect extend / swap / print options
        await tester.tap(find.byIcon(Icons.more_vert_rounded).first);
        await tester.pumpAndSettle();
        expect(find.text('Tambah Jam / Perpanjang'), findsOneWidget);
        expect(find.text('Ganti Unit Fisik'), findsOneWidget);
        expect(find.text('Cetak Ulang Struk'), findsOneWidget);

        // Trigger 'Ganti Unit Fisik' -> navigates to ExchangeWizardScreen
        await tester.tap(find.text('Ganti Unit Fisik'));
        await tester.pumpAndSettle();
        expect(find.byType(ExchangeWizardScreen), findsOneWidget);
      },
    );

    testWidgets(
      'HomeScreen card Rincian button opens PosTransactionDetailSheet',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final bookings = [
          {
            'id': 1,
            'booking_code': 'RC-DETAIL-01',
            'status': 'rented',
            'payment_status': 'paid',
            'total_bill': 200000,
            'end_at': DateTime.now()
                .add(const Duration(hours: 6))
                .toIso8601String(),
            'customer': {'name': 'Dewi Rincian'},
            'items': [],
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
              dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
              bookingRepositoryProvider.overrideWithValue(
                _FakeBookingRepo(bookings),
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

        await tester.tap(find.text('Rincian'));
        await tester.pumpAndSettle();
        expect(find.byType(PosTransactionDetailSheet), findsOneWidget);
      },
    );
  });

  group('Laporan (FinancialHubScreen) 1-Tap Switcher Verification', () {
    testWidgets(
      'Renders Pendapatan and switches to Kasir & Shift in 1 tap with sticky closing bar',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _FakeFinancialRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                extendBody: true,
                body: const FinancialHubScreen(),
                bottomNavigationBar: FloatingCapsuleDock(
                  currentIndex: 1,
                  onTabSelected: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Sub-Tab 1: Pendapatan rendered by default
        expect(find.text('Laporan'), findsAtLeastNWidgets(1));
        expect(find.text('Pendapatan'), findsOneWidget);
        expect(find.text('Kasir & Shift'), findsOneWidget);
        expect(find.text('Minggu Ini'), findsOneWidget);
        expect(find.text('Bulan Lalu'), findsOneWidget);
        expect(find.text('Sewa Kontrak Pokok'), findsOneWidget);
        expect(find.text('Perpanjangan Sewa'), findsOneWidget);
        expect(find.text('Denda Keterlambatan'), findsOneWidget);
        expect(find.text('RC-PAID-101'), findsOneWidget);

        // 1 tap on 'Kasir & Shift' switches to Cashier drawer & closing
        await tester.tap(find.text('Kasir & Shift'));
        await tester.pumpAndSettle();

        expect(find.text('Shift Aktif'), findsOneWidget);
        expect(find.text('Riwayat Shift'), findsOneWidget);
        expect(find.text('Tutup Shift'), findsOneWidget);
        expect(find.text('Cetak Struk'), findsOneWidget);

        // Verify sticky 'Tutup Shift' button is positioned above FloatingCapsuleDock (zero overlap)
        final tutupBottom = tester.getBottomLeft(find.text('Tutup Shift')).dy;
        final dockTop = tester.getTopLeft(find.byType(FloatingCapsuleDock)).dy;
        expect(tutupBottom, lessThan(dockTop));

        // 1 tap on 'Riwayat Shift' loads closing history
        await tester.tap(find.text('Riwayat Shift'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Kasir Pagi'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

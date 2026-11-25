import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/cashier_screen.dart';
import 'package:sewakasir/features/cashier/presentation/financial_hub_screen.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/presentation/revenue_report_screen.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/home/presentation/home_screen.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _FakeRevenueRepo extends CashierRepository {
  int? requestedBranchId;
  bool recordedAllBranches = false;

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    requestedBranchId = branchId;
    recordedAllBranches = allBranches;

    final isConsolidated = allBranches || branchId == null;

    return {
      'branch_id': branchId,
      'is_consolidated': isConsolidated,
      'date': 'Hari Ini',
      'total_revenue': 12500000.0,
      'total_transactions': 18,
      'total_expenses': 250000.0,
      'cash_drawer_expenses': 50000.0,
      'breakdown_by_method': {
        'Tunai': {'total': 4500000.0, 'count': 8},
        'QRIS': {'total': 5000000.0, 'count': 6},
        'Transfer Bank': {'total': 3000000.0, 'count': 4},
      },
      'breakdown_by_type': {
        'rental': {
          'label': 'Sewa Kontrak Pokok',
          'total': 10000000.0,
          'count': 14,
        },
        'extension': {
          'label': 'Perpanjangan Sewa',
          'total': 1500000.0,
          'count': 2,
        },
        'penalty': {
          // Intentionally test raw debug text from backend to verify client sanitizes it
          'label': 'Denda Keterlambatan (Late Penalty Debug)',
          'total': 1000000.0,
          'count': 2,
        },
      },
      'breakdown_by_branch': [
        {
          'branch_id': 1,
          'branch_name': 'RentCore Pusat',
          'is_central': true,
          'total_revenue': 7500000.0,
          'cash_revenue': 2500000.0,
          'non_cash_revenue': 5000000.0,
          'transaction_count': 10,
        },
        {
          'branch_id': 2,
          'branch_name': 'RentCore Cabang Barat',
          'is_central': false,
          'total_revenue': 5000000.0,
          'cash_revenue': 2000000.0,
          'non_cash_revenue': 3000000.0,
          'transaction_count': 8,
        },
      ],
      'cash_reconciliation': {
        'opening_cash_float': 500000.0,
        'cash_inflow': 4500000.0,
        'cash_expenses': 50000.0,
        'expected_cash_in_drawer': 4950000.0,
        'active_shift': {
          'id': 10,
          'shift_number': 'SHF-20261112-001',
          'cashier_name': 'Budi Kasir',
          'branch_name': 'RentCore Pusat',
          'status': 'open',
          'opening_cash_float': 500000.0,
          'expected_cash_now': 4950000.0,
          'opened_at': '2026-11-12T08:00:00Z',
        },
      },
      'recent_transactions': [
        {
          'receipt_number': 'REC-PST-0001',
          'customer_name': 'Ahmad Fauzi',
          'branch_name': 'RentCore Pusat',
          'is_central': true,
          'amount': 500000.0,
          'payment_method': 'Tunai',
          'type': 'rental',
          'items_summary': 'MacBook Pro M3 Max 16"',
        },
        {
          'receipt_number': 'REC-BRT-0002',
          'customer_name': 'Siti Rahma',
          'branch_name': 'RentCore Cabang Barat',
          'is_central': false,
          'amount': 250000.0,
          'payment_method': 'QRIS',
          'type': 'penalty',
          'items_summary': 'Sony A7 IV Body Only',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'data': {
        'shift': {
          'id': 10,
          'shift_number': 'SHF-20261112-001',
          'cashier_name': 'Budi Kasir',
          'branch_name': 'RentCore Pusat',
          'status': 'open',
          'opening_cash_float': 500000.0,
          'expected_cash_now': 4950000.0,
          'opened_at': '2026-11-12T08:00:00Z',
        },
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchShiftHistory({
    int? branchId,
    bool allBranches = false,
    String? startDate,
    String? endDate,
  }) async {
    return [];
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

class _TestPosFilterNotifier extends PosFilterBranchIdNotifier {
  final int? _initial;
  _TestPosFilterNotifier(this._initial);

  @override
  int? build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  final multiBranchBusinessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Multi Corp',
    activeBranchId: 1,
    activeBranchName: 'RentCore Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Multi Corp',
        'membership': {'role': 'owner'},
        'branches': [
          {'id': 1, 'name': 'RentCore Pusat', 'is_central': true},
          {'id': 2, 'name': 'RentCore Cabang Barat', 'is_central': false},
        ],
      },
    ],
  );

  group('Dedicated RevenueReportScreen Suite', () {
    testWidgets('Renders Top Filter Bar with concise non-truncating pills', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(-1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Top Filter Bar concise labels
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Minggu Ini'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
      expect(find.text('Bulan Lalu'), findsOneWidget);
      expect(find.text('Kustom'), findsOneWidget);

      // Verify no RenderFlex errors
      expect(tester.takeException(), isNull);
    });

    testWidgets('Hero Revenue Card displays Omzet, Tx Count, and Tunai vs Non-Tunai split', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(-1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Total Omset (Hari Ini)'), findsOneWidget);
      expect(find.text('Konsolidasi'), findsOneWidget);
      expect(find.text('Rp 12.500.000'), findsOneWidget);
      expect(find.text('18 transaksi berhasil diselesaikan'), findsOneWidget);

      // Tunai vs Non-Tunai breakdown
      expect(find.text('Tunai (Cash)'), findsOneWidget);
      expect(find.text('Rp 4.500.000'), findsWidgets);
      expect(find.text('Non-Tunai'), findsOneWidget);
      expect(find.text('Rp 8.000.000'), findsWidgets);
    });

    testWidgets('Sumber Pendapatan strips English debug text and renders clean Indonesian labels', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(-1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sumber Pendapatan'), findsOneWidget);
      expect(find.text('Sewa Kontrak Pokok'), findsOneWidget);
      expect(find.text('Perpanjangan Sewa'), findsOneWidget);
      expect(find.text('Denda Keterlambatan'), findsOneWidget);

      // Ensure English debug string "(Late Penalty Debug)" was completely stripped
      expect(find.textContaining('Late Penalty'), findsNothing);
    });

    testWidgets('Kontribusi Omset per Cabang appears in consolidated mode', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(-1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kontribusi Omset per Cabang'), findsOneWidget);
      expect(find.text('2 Cabang Terdata'), findsOneWidget);
    });

    testWidgets('Kontribusi Omset per Cabang hides when filtered to a single branch', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kontribusi Omset per Cabang'), findsNothing);
    });

    testWidgets('Audit Rincian Transaksi: Shows clean 2-line subtitle and omits repetitive branch pills when filtered', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      // Filtered to branch 1
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Line 1: Customer Name • Unit Model
      expect(find.text('Ahmad Fauzi • MacBook Pro M3 Max 16"'), findsOneWidget);
      expect(find.text('Siti Rahma • Sony A7 IV Body Only'), findsOneWidget);

      // Line 2: Payment Method • Category (Sewa/Denda)
      expect(find.text('Tunai • Sewa'), findsOneWidget);
      expect(find.text('QRIS • Denda'), findsOneWidget);

      // In single-branch view, repetitive branch pill is NOT shown
      expect(find.text('REC-PST-0001'), findsOneWidget);
    });

    testWidgets('Tapping transaction row in RevenueReportScreen opens PosTransactionDetailSheet', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterNotifier(1)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const RevenueReportScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      final recItem = find.text('REC-PST-0001');
      expect(recItem, findsOneWidget);

      await tester.tap(recItem);
      await tester.pumpAndSettle();

      expect(find.byType(PosTransactionDetailSheet), findsOneWidget);
    });
  });

  group('Cleaned ShiftScreen (CashierScreen) Active Shift Suite', () {
    testWidgets('ShiftScreen displays "Kasir & Shift" title and strictly Drawer duties', (tester) async {
      final fakeRepo = _FakeRevenueRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CashierScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Title is Kasir & Shift
      expect(find.text('Kasir & Shift'), findsOneWidget);
      expect(find.text('Shift Aktif'), findsOneWidget);
      expect(find.text('Riwayat Shift'), findsOneWidget);

      // Shift Aktif Tab MUST NOT contain multi-date filter pills
      expect(find.text('7 Hari Terakhir'), findsNothing); // only in Tab 2

      // Shift Aktif Tab MUST NOT contain Black Revenue Card
      expect(find.textContaining('Total Omset ('), findsNothing);

      // Shift Aktif Tab MUST NOT contain Sumber Pendapatan breakdown
      expect(find.text('Sumber Pendapatan'), findsNothing);

      // Shift Aktif Tab MUST NOT contain red Logout button
      expect(find.text('Keluar dari Akun Kasir'), findsNothing);

      // Shift Aktif Tab MUST NOT contain duplicate Tutup Shift & Closing button inside scroll body
      expect(find.text('Tutup Shift & Closing'), findsNothing);

      // Text truncation fix: Total Kas Wajib di Laci
      expect(find.text('Total Kas Wajib di Laci'), findsOneWidget);

      // Quick action bar only has + Catat Beban Pengeluaran
      expect(find.text('+ Catat Beban Pengeluaran'), findsOneWidget);

      // Sticky Bottom Bar has [ Cetak Struk ] and [ Tutup Shift ]
      expect(find.text('Cetak Struk'), findsOneWidget);
      expect(find.text('Tutup Shift'), findsOneWidget);
    });

    testWidgets('ShiftScreen typedef alias works interchangeably with CashierScreen', (tester) async {
      expect(ShiftScreen, equals(CashierScreen));
    });
  });

  group('Dashboard Revenue Card Navigation Test', () {
    testWidgets('Tapping Pendapatan on HomeScreen switches to Laporan tab', (tester) async {
      final fakeRepo = _FakeRevenueRepo();
      int navigatedTab = -1;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(multiBranchBusinessState)),
            dashboardKpiProvider.overrideWith((ref) => Future.value({
              'kpi': {
                'today_revenue': 12500000.0,
                'today_rentals_created': 8,
                'due_today': 3,
                'units_ready': 15,
              },
              'overdue_alerts': [],
            })),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) {
                return HomeScreen(
                  onNavigateTab: (tab) => navigatedTab = tab,
                  onOpenDirectRental: () {},
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final revenueCard = find.text('Pendapatan');
      expect(revenueCard, findsOneWidget);

      await tester.tap(revenueCard);
      await tester.pumpAndSettle();

      expect(navigatedTab, 1);
    });
  });

  group('Airy Minimalist Reports Redesign Verification', () {
    testWidgets('FinancialHubScreen uses pure white canvas, segmented pill switchers, title-cased branch scope, and non-clipped filter pills', (tester) async {
      final fakeRepo = _FakeRevenueRepo();
      final singleBranchLowercaseState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore',
        activeBranchId: 1,
        activeBranchName: 'siliragung',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore',
            'membership': {'role': 'staff'},
            'branches': [
              {'id': 1, 'name': 'siliragung', 'is_central': false},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(
              () => _TestBusinessNotifier(singleBranchLowercaseState),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const FinancialHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Pure #FFFFFF canvas & 22sp Laporan title
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(scaffold.backgroundColor, Colors.white);
      final titleText = tester.widget<Text>(find.text('Laporan'));
      expect(titleText.style?.fontSize, 22.0);
      expect(titleText.style?.fontWeight, FontWeight.w700);
      expect(titleText.style?.color, const Color(0xFF0F172A));

      // Title-cased branch name + Cakupan: + Terkunci
      expect(find.text('Cakupan:'), findsOneWidget);
      expect(find.text('Siliragung'), findsOneWidget);
      expect(find.text('siliragung'), findsNothing);
      expect(find.text('Terkunci'), findsOneWidget);

      // Hari Ini pill starts cleanly at 20dp left edge (never clipped)
      final hariIniRect = tester.getRect(find.text('Hari Ini'));
      expect(hariIniRect.left, greaterThanOrEqualTo(20.0));

      // Transaksi Terbaru & Buku Kas Lengkap link
      expect(find.text('Transaksi Terbaru'), findsOneWidget);
      expect(find.text('Buku Kas Lengkap'), findsOneWidget);

      // Switch to Kasir & Shift and verify secondary segmented pill tabs
      await tester.tap(find.text('Kasir & Shift'));
      await tester.pumpAndSettle();

      expect(find.text('Shift Aktif'), findsOneWidget);
      expect(find.text('Riwayat Shift'), findsOneWidget);
      expect(
        find.textContaining('Shift #SHF-20261112-001 • Aktif'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

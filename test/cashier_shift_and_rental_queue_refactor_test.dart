import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/bookings_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/cashier_screen.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/shared/widgets/thermal_receipt_preview_dialog.dart';

class _FakeCashierShiftRepo extends CashierRepository {
  List<Map<String, dynamic>> historicalShifts = [];
  Map<String, dynamic>? activeShiftData;
  Map<String, dynamic>? closedShiftResult;
  bool shiftClosedCalled = false;

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'date': '2026-11-04',
      'total_revenue': 2500000.0,
      'total_transactions': 12,
      'is_consolidated': false,
      'cash_drawer_expenses': 50000.0,
      'total_expenses': 50000.0,
      'breakdown_by_type': {
        'rental': {
          'label': 'Sewa Kontrak Pokok',
          'total': 2000000.0,
          'count': 8,
        },
        'extension': {
          'label': 'Perpanjangan Sewa',
          'total': 400000.0,
          'count': 3,
        },
        'penalty': {
          'label': 'Denda Keterlambatan',
          'total': 100000.0,
          'count': 1,
        },
      },
      'breakdown_by_method': {
        'Tunai (Cash)': {'total': 1500000.0, 'count': 7},
        'QRIS': {'total': 1000000.0, 'count': 5},
      },
      'cash_reconciliation': {
        'opening_cash_float': 500000.0,
        'expected_cash_in_drawer': 1950000.0,
        'active_shift':
            activeShiftData ??
            {
              'id': 101,
              'shift_number': 'SHF-20261104-001',
              'status': 'open',
              'cashier_name': 'Dewi Kasir',
              'branch_name': 'Cabang Mataram Utama',
              'opened_at': '2026-11-04 08:00:00',
              'opening_cash_float': 500000.0,
              'expected_cash_now': '1950000.0',
            },
      },
    };
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'status': 'success',
      'data': {
        'shift':
            activeShiftData ??
            {
              'id': 101,
              'shift_number': 'SHF-20261104-001',
              'status': 'open',
              'cashier_name': 'Dewi Kasir',
              'branch_name': 'Cabang Mataram Utama',
              'opened_at': '2026-11-04 08:00:00',
              'opening_cash_float': 500000.0,
              'expected_cash_now': '1950000.0',
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
    return historicalShifts;
  }

  @override
  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    shiftClosedCalled = true;
    final res = {
      'id': shiftId ?? 101,
      'shift_number': 'SHF-20261104-001',
      'status': 'closed',
      'opening_cash_float': 500000.0,
      'cash_inflow': 1500000.0,
      'cash_expenses': 50000.0,
      'expected_cash_total': 1950000.0,
      'actual_cash_counted': actualCashCounted,
      'cash_difference': actualCashCounted - 1950000.0,
      'difference_reason': differenceReason,
      'closing_notes': closingNotes,
      'closed_at': '2026-11-04 16:30:00',
    };
    closedShiftResult = res;
    // Add to historical shifts
    historicalShifts.insert(0, {
      ...res,
      'cashier_name': 'Dewi Kasir',
      'branch_name': 'Cabang Mataram Utama',
      'opened_at': '2026-11-04 08:00:00',
      'total_sales': 1500000.0,
    });
    activeShiftData = null;
    return res;
  }
}

class _FakeBookingRepoForQueue extends BookingRepository {
  List<Map<String, dynamic>> bookings = [];

  _FakeBookingRepoForQueue(this.bookings);

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
        return code.contains(s) || name.contains(s) || phone.contains(s);
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

class _FakeBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore POS',
    activeBranchId: 1,
    activeBranchName: 'Cabang Mataram Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore POS',
        'role': 'owner',
        'branches': [
          {'id': 1, 'name': 'Cabang Mataram Utama', 'is_central': true},
        ],
      },
    ],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Cashier Screen & Rental Queue Refactor Suite', () {
    testWidgets(
      '1. CashierScreen Tab Structure: Displays "Shift Aktif" and "Riwayat Shift"',
      (tester) async {
        final repo = _FakeCashierShiftRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the 2 tab headers
        expect(find.text('Shift Aktif'), findsOneWidget);
        expect(find.text('Riwayat Shift'), findsOneWidget);

        // Verify old tab headers are completely absent
        expect(find.text('Meja Kasir POS'), findsNothing);
        expect(find.text('Rekap Shift & Closing'), findsNothing);
      },
    );

    testWidgets(
      '2. Tab 1: Shift Aktif displays Active Session Info, Real-Time Cash Summary & Quick Actions',
      (tester) async {
        final repo = _FakeCashierShiftRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Active Session Info
        expect(find.text('Sesi Kasir Berjalan'), findsOneWidget);
        expect(
          find.textContaining('Shift #SHF-20261104-001 • Aktif'),
          findsOneWidget,
        );
        expect(find.text('Kasir Bertugas'), findsOneWidget);
        expect(find.text('Dewi Kasir'), findsOneWidget);
        expect(find.text('Cabang Operasional'), findsOneWidget);
        expect(find.text('Cabang Mataram Utama'), findsWidgets);
        expect(find.text('Modal Kas Awal'), findsOneWidget);
        expect(find.text('Rp 500.000'), findsWidgets);

        // Real-Time Cash Summary
        expect(find.text('Kas Masuk Tunai'), findsOneWidget);
        expect(find.text('Rp 1.500.000'), findsWidgets);
        expect(
          find.text('Total Non-Tunai (QRIS / Bank / EDC)'),
          findsOneWidget,
        );
        expect(find.text('Rp 1.000.000'), findsWidgets);
        expect(
          find.text('Beban Pengeluaran Cabang (Kas Laci)'),
          findsOneWidget,
        );
        expect(find.text('-Rp 50.000'), findsOneWidget);
        expect(find.text('Total Fisik Kas Wajib di Laci'), findsOneWidget);
        expect(find.text('Rp 1.950.000'), findsWidgets);

        // Quick Action Bar
        expect(find.text('+ Catat Beban Pengeluaran'), findsOneWidget);
        expect(find.text('Tutup Shift & Closing'), findsNothing);
        expect(find.text('Tutup Shift'), findsOneWidget);

        // Verify no RenderFlex errors
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '3. Tab 2: Riwayat Shift displays Historical Shifts, Status Pills, and Actions',
      (tester) async {
        final repo = _FakeCashierShiftRepo();
        repo.historicalShifts = [
          {
            'id': 98,
            'shift_number': 'SHF-20261103-001',
            'cashier_name': 'Ahmad Fauzi',
            'branch_name': 'Cabang Mataram Utama',
            'opened_at': '2026-11-03 08:00:00',
            'closed_at': '2026-11-03 16:00:00',
            'opening_cash_float': 500000.0,
            'total_sales': 1200000.0,
            'actual_cash_counted': 1700000.0,
            'expected_cash_total': 1700000.0,
            'cash_difference': 0.0,
          },
          {
            'id': 97,
            'shift_number': 'SHF-20261102-001',
            'cashier_name': 'Budi Staff',
            'branch_name': 'Cabang Mataram Utama',
            'opened_at': '2026-11-02 08:00:00',
            'closed_at': '2026-11-02 16:00:00',
            'opening_cash_float': 500000.0,
            'total_sales': 1000000.0,
            'actual_cash_counted': 1480000.0,
            'expected_cash_total': 1500000.0,
            'cash_difference': -20000.0,
            'difference_reason': 'Selisih kembalian receh',
          },
          {
            'id': 96,
            'shift_number': 'SHF-20261101-001',
            'cashier_name': 'Siti Rahma',
            'branch_name': 'Cabang Mataram Utama',
            'opened_at': '2026-11-01 08:00:00',
            'closed_at': '2026-11-01 16:00:00',
            'opening_cash_float': 500000.0,
            'total_sales': 800000.0,
            'actual_cash_counted': 1315000.0,
            'expected_cash_total': 1300000.0,
            'cash_difference': 15000.0,
          },
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to Tab 2: Riwayat Shift
        await tester.tap(find.text('Riwayat Shift'));
        await tester.pumpAndSettle();

        // Verify Date Range Filter default chip: 7 Hari Terakhir
        expect(find.text('7 Hari Terakhir'), findsOneWidget);

        // Verify Status Pills for each historical shift
        expect(find.text('Sesuai'), findsOneWidget); // Shift 98 variance == 0
        expect(
          find.text('Kurang: Rp 20.000'),
          findsOneWidget,
        ); // Shift 97 variance < 0
        expect(
          find.text('Lebih: Rp 15.000'),
          findsOneWidget,
        ); // Shift 96 variance > 0

        // Verify Financial Breakdown items
        expect(find.text('Modal Awal'), findsNWidgets(3));
        expect(find.text('Penjualan'), findsNWidgets(3));
        expect(find.text('Kas Terhitung'), findsNWidgets(3));
        expect(find.text('Selisih'), findsNWidgets(3));

        // Verify Action buttons on shift cards
        expect(find.text('Lihat Rekap Lengkap'), findsNWidgets(3));
        expect(find.text('Cetak Ulang Struk'), findsNWidgets(3));

        // Tap 'Lihat Rekap Lengkap' on the second card (Shift 97 with discrepancy)
        final rekapBtn = find.text('Lihat Rekap Lengkap').at(1);
        await tester.ensureVisible(rekapBtn);
        await tester.tap(rekapBtn);
        await tester.pumpAndSettle();

        // Verify detailed shift modal (both card header & audit modal display Shift #SHF-20261102-001)
        expect(find.text('AUDIT REKAP SHIFT'), findsOneWidget);
        expect(find.text('Shift #SHF-20261102-001'), findsNWidgets(2));
        expect(find.text('Alasan Selisih Kas:'), findsOneWidget);
        expect(find.text('Selisih kembalian receh'), findsOneWidget);

        // Close modal
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // Tap 'Cetak Ulang Struk' on the first card
        final reprintBtn = find.text('Cetak Ulang Struk').first;
        await tester.ensureVisible(reprintBtn);
        await tester.pumpAndSettle();
        await tester.tap(reprintBtn);
        await tester.pumpAndSettle();

        // Verify ThermalReceiptPreviewDialog is opened
        expect(find.byType(ThermalReceiptPreviewDialog), findsOneWidget);
        expect(find.text('Preview Cetak Struk Closing'), findsOneWidget);

        // Dismiss dialog
        await tester.tap(
          find.descendant(
            of: find.byType(ThermalReceiptPreviewDialog),
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '4. Branch Rental Queue: Multi-level priority sorting & Action buttons',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final now = DateTime.now();

        final overdueBooking = {
          'id': 1,
          'booking_code': 'RC-OVERDUE-01',
          'status': 'rented',
          'payment_status': 'paid',
          'start_at': now.subtract(const Duration(days: 2)).toIso8601String(),
          'end_at': now
              .subtract(const Duration(hours: 4))
              .toIso8601String(), // Overdue!
          'total_bill': 200000.0,
          'customer': {'name': 'Joko Overdue', 'phone': '08111111111'},
          'items': [
            {
              'asset': {
                'model': {'name': 'Sony A7 IV'},
                'asset_code': 'CAM-01',
              },
            },
          ],
        };

        final dueTodayBooking = {
          'id': 2,
          'booking_code': 'RC-DUETODAY-02',
          'status': 'rented',
          'payment_status': 'paid',
          'start_at': now.subtract(const Duration(hours: 6)).toIso8601String(),
          'end_at': DateTime(
            now.year,
            now.month,
            now.day,
            20,
            0,
          ).toIso8601String(), // Due Today!
          'total_bill': 150000.0,
          'customer': {'name': 'Siti DueToday', 'phone': '08222222222'},
          'items': [
            {
              'asset': {
                'model': {'name': 'Canon R6'},
                'asset_code': 'CAM-02',
              },
            },
          ],
        };

        final awaitingHandoverBooking = {
          'id': 3,
          'booking_code': 'RC-PENDING-03',
          'status': 'confirmed',
          'payment_status': 'unpaid',
          'start_at': now.add(const Duration(hours: 2)).toIso8601String(),
          'end_at': now.add(const Duration(days: 1)).toIso8601String(),
          'total_bill': 300000.0,
          'customer': {'name': 'Budi Handover', 'phone': '08333333333'},
          'items': [
            {
              'asset': {
                'model': {'name': 'iPad Pro M4'},
                'asset_code': 'TAB-01',
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
          'end_at': now
              .add(const Duration(days: 3))
              .toIso8601String(), // Active future
          'total_bill': 500000.0,
          'customer': {'name': 'Rian Active', 'phone': '08444444444'},
          'items': [
            {
              'asset': {
                'model': {'name': 'MacBook Pro M3'},
                'asset_code': 'MAC-01',
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
          'end_at': now.subtract(const Duration(days: 1)).toIso8601String(),
          'total_bill': 250000.0,
          'customer': {'name': 'Andi Completed', 'phone': '08555555555'},
          'items': [
            {
              'asset': {
                'model': {'name': 'Fujifilm X-T5'},
                'asset_code': 'CAM-03',
              },
            },
          ],
        };

        // Shuffled input order
        final queueRepo = _FakeBookingRepoForQueue([
          completedBooking,
          activeBooking,
          dueTodayBooking,
          overdueBooking,
          awaitingHandoverBooking,
        ]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(queueRepo),
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const BookingsScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Switch to 'Semua' filter to view bookings of all statuses
        await tester.tap(find.text('Semua'));
        await tester.pumpAndSettle();

        // Verify that all 5 bookings appear
        expect(find.text('RC-OVERDUE-01'), findsOneWidget);
        expect(find.text('RC-DUETODAY-02'), findsOneWidget);
        expect(find.text('RC-PENDING-03'), findsOneWidget);
        expect(find.text('RC-ACTIVE-04'), findsOneWidget);
        expect(find.text('RC-RETURNED-05'), findsOneWidget);

        // Verify Multi-Level Priority Ordering:
        // RC-OVERDUE-01 must be above RC-DUETODAY-02, which is above RC-PENDING-03, which is above RC-ACTIVE-04
        final posOverdue = tester.getTopLeft(find.text('RC-OVERDUE-01')).dy;
        final posDueToday = tester.getTopLeft(find.text('RC-DUETODAY-02')).dy;
        final posPending = tester.getTopLeft(find.text('RC-PENDING-03')).dy;
        final posActive = tester.getTopLeft(find.text('RC-ACTIVE-04')).dy;

        expect(
          posOverdue,
          lessThan(posDueToday),
          reason: 'Overdue must appear before Due Today',
        );
        expect(
          posDueToday,
          lessThan(posPending),
          reason: 'Due Today must appear before Awaiting Handover',
        );
        expect(
          posPending,
          lessThan(posActive),
          reason: 'Awaiting Handover must appear before Active',
        );

        // Verify Action Buttons existence:
        // "Rincian", "Kembalikan", "Bayar", and "Cetak Struk"
        expect(find.text('Rincian'), findsWidgets);
        expect(find.text('Kembalikan'), findsWidgets);
        expect(
          find.text('Bayar'),
          findsOneWidget,
        ); // For RC-PENDING-03 which is unpaid
        expect(find.text('Cetak Struk'), findsWidgets);

        // Tap 'Rincian' on the first booking
        await tester.tap(find.text('Rincian').first);
        await tester.pumpAndSettle();

        // Verify PosTransactionDetailSheet opened
        expect(find.byType(PosTransactionDetailSheet), findsOneWidget);
        expect(find.text('Rincian Transaksi'), findsOneWidget);

        // Close bottom sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '5. Closing shift updates history log and prints closing slip without errors',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = _FakeCashierShiftRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_FakeBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap 'Tutup Shift' in sticky bottom bar
        await tester.tap(find.text('Tutup Shift'));
        await tester.pumpAndSettle();

        // Verify CashDrawerShiftModal opened
        expect(find.byType(CashDrawerShiftModal), findsOneWidget);
        expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsOneWidget);

        // Enter counted denominations (19 x 100k + 1 x 50k = 1.950.000)
        final formFields = find.descendant(
          of: find.byType(CashDrawerShiftModal),
          matching: find.byType(TextFormField),
        );
        expect(formFields, findsWidgets);

        // Index 0 is 100k, Index 1 is 50k
        await tester.enterText(formFields.at(0), '19');
        await tester.pumpAndSettle();
        await tester.enterText(formFields.at(1), '1');
        await tester.pumpAndSettle();

        // Tap "Tutup Shift & Rekapitulasi Kasir"
        final submitBtn = find.text('Tutup Shift & Rekapitulasi Kasir');
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // Verify closeShift was invoked on repository
        expect(repo.shiftClosedCalled, isTrue);

        // Verify closing slip print dialog opened
        expect(find.byType(ThermalReceiptPreviewDialog), findsOneWidget);
        expect(find.text('Struk Tutup Shift Kasir'), findsOneWidget);

        // Dismiss print dialog
        await tester.tap(
          find.descendant(
            of: find.byType(ThermalReceiptPreviewDialog),
            matching: find.byIcon(Icons.close_rounded),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Riwayat Shift tab
        await tester.tap(find.text('Riwayat Shift'));
        await tester.pumpAndSettle();

        // Verify historical shift card was updated and now visible in Riwayat Shift
        expect(find.textContaining('Shift #SHF-20261104-001'), findsOneWidget);
        expect(find.text('Sesuai'), findsOneWidget);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _MockClosingCashierRepo extends CashierRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    return [];
  }

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'date': '2026-10-30',
      'total_revenue': 1900000.0,
      'total_transactions': 8,
      'is_consolidated': false,
      'cash_drawer_expenses': 100000.0,
      'total_expenses': 100000.0,
      'breakdown_by_type': {
        'rental': {'label': 'Sewa Kontrak Pokok', 'total': 1500000.0, 'count': 5},
        'extension': {'label': 'Perpanjangan Sewa', 'total': 350000.0, 'count': 2},
        'penalty': {'label': 'Denda Keterlambatan', 'total': 50000.0, 'count': 1},
      },
      'breakdown_by_method': {
        'Tunai (Cash)': {'total': 1000000.0, 'count': 4},
        'QRIS': {'total': 650000.0, 'count': 3},
        'Transfer Bank': {'total': 250000.0, 'count': 1},
      },
      'cash_reconciliation': {
        'opening_cash_float': 500000.0,
        'expected_cash_in_drawer': 1400000.0,
        'active_shift': {
          'id': 99,
          'shift_number': 'SHF-20261030-99999-EXTRALONG-IDENTIFIER',
          'status': 'open',
          'expected_cash_now': '1400000.0',
        },
      },
      'breakdown_by_branch': [
        {
          'branch_name': 'Cabang Utama Mataram Barat Sangat Panjang Namanya',
          'is_central': true,
          'total_revenue': 1900000.0,
          'cash_revenue': 1000000.0,
          'non_cash_revenue': 900000.0,
          'transaction_count': 8,
        }
      ],
      'recent_transactions': [
        {
          'receipt_number': 'INV-20261030-POS-999999-EXTRA-LONG-CODE',
          'customer_name': 'Pelanggan Dengan Nama Yang Sangat Panjang Sekali Di Rental',
          'items_summary': 'MacBook Pro 16 M3 Max 64GB 2TB Space Black',
          'cashier_name': 'Ahmad Kasir Bertugas Pagi',
          'payment_method': 'Tunai',
          'amount': 1500000.0,
          'type': 'rental',
          'branch_name': 'Cabang Pusat',
          'is_central': true,
        }
      ],
    };
  }

  Future<List<Map<String, dynamic>>> fetchBranchExpenses({String? date, int? branchId}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
    ];
  }
}

class _MockClosingBizNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Store',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat Utama',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Store',
            'role': 'owner',
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat Utama', 'is_central': true},
            ],
          }
        ],
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Shift Summary & POS Closing Refactor Tests', () {
    testWidgets('Renders properly without overflow on compact 320x568 screen', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = _MockClosingCashierRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockClosingBizNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Rekap Shift & Closing tab
      await tester.tap(find.text('Rekap Shift & Closing'));
      await tester.pumpAndSettle();

      // Verify no RenderFlex errors were recorded
      expect(tester.takeException(), isNull);

      // 1. Verify Sentence Case Section Headers
      expect(find.text('Cakupan Kasir'), findsOneWidget);
      expect(find.text('Rekonsiliasi Kas Laci & Beban'), findsOneWidget);
      expect(find.text('Sumber Pendapatan'), findsOneWidget);
      expect(find.text('Rincian Metode Pembayaran'), findsOneWidget);
      expect(find.text('Kontribusi Omset per Cabang'), findsOneWidget);
      expect(find.text('Transaksi Terbaru (Audit Rincian)'), findsOneWidget);

      // Verify all-caps old labels are NOT present
      expect(find.text('CAKUPAN POS & REKAP KASIR'), findsNothing);
      expect(find.text('SUMBER PENDAPATAN (INCOME TYPE)'), findsNothing);
      expect(find.text('RINCIAN METODE PEMBAYARAN'), findsNothing);
      expect(find.text('KONTRIBUSI REVENUE PER CABANG'), findsNothing);
      expect(find.text('TRANSAKSI TERBARU (AUDIT RINCIAN)'), findsNothing);

      // 2. Verify Shift badge is displayed
      expect(find.textContaining('Shift #SHF-20261030-99999-EXTRALONG-IDENTIFIER Aktif'), findsOneWidget);

      // 3. Verify Cash Drawer Reconciliation structure & "+ Catat Beban Pengeluaran" button
      expect(find.text('Kas Masuk Bersih (Sistem)'), findsOneWidget);
      expect(find.text('Total Fisik Kas Wajib di Laci'), findsOneWidget);
      expect(find.text('+ Catat Beban Pengeluaran'), findsOneWidget);

      // 4. Verify Consolidated Revenue Sources list items inside a single card
      expect(find.text('Sewa Kontrak Pokok'), findsOneWidget);
      expect(find.text('Perpanjangan Sewa'), findsOneWidget);
      expect(find.text('Denda Keterlambatan'), findsOneWidget);

      // 5. Verify Consolidated Payment Methods
      expect(find.text('Tunai (Cash)'), findsWidgets); // May appear in revenue card and payment methods
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Transfer Bank'), findsOneWidget);

      // 6. Verify Sticky Bottom Navigation Bar buttons
      expect(find.text('Cetak Struk Closing'), findsOneWidget);
      expect(find.text('Tutup Shift'), findsOneWidget);

      // 7. Verify single clean text link for Buku Kas Lengkap
      expect(find.text('Buku Kas Lengkap'), findsOneWidget);
      // Duplicate old button title is gone
      expect(find.text('Buku Kas Lengkap (Audit Ledger Finansial)'), findsNothing);

      // 8. Verify compact filter chips
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);
    });

    testWidgets('Sticky Bottom Bar actions respond properly on standard 390x844 screen', (tester) async {
      tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final mockRepo = _MockClosingCashierRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockClosingBizNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Rekap Shift & Closing tab
      await tester.tap(find.text('Rekap Shift & Closing'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Find bottom bar buttons
      final printBtn = find.text('Cetak Struk Closing');
      final closeShiftBtn = find.text('Tutup Shift');

      expect(printBtn, findsOneWidget);
      expect(closeShiftBtn, findsOneWidget);

      // Tap Tutup Shift button -> should open CashDrawerShiftModal
      await tester.tap(closeShiftBtn);
      await tester.pumpAndSettle();

      // Verify modal is open and has sentence case title
      expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsOneWidget);
      expect(find.text('Hitung Fisik Uang Kas (Denominasi)'), findsOneWidget);

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsNothing);
    });
  });
}

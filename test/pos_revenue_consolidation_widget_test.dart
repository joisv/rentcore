import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _MockCashierRepository extends CashierRepository {
  int? lastRequestedBranchId;
  String? lastStartDate;
  String? lastEndDate;

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    lastRequestedBranchId = branchId;
    lastStartDate = startDate;
    lastEndDate = endDate;

    final isConsolidated = allBranches || branchId == null;
    return {
      'branch_id': branchId,
      'is_consolidated': isConsolidated,
      'date': startDate != null && endDate != null ? '$startDate s/d $endDate' : 'HARI INI',
      'total_revenue': isConsolidated ? 12500000.0 : 7500000.0,
      'total_transactions': isConsolidated ? 18 : 10,
      'breakdown_by_method': {
        'Tunai': {'count': 8, 'total': 4500000.0},
        'QRIS': {'count': 10, 'total': 8000000.0},
      },
      'breakdown_by_branch': [
        {
          'branch_id': 1,
          'branch_name': 'RentCore Pusat (Main Store)',
          'is_central': true,
          'transaction_count': 10,
          'total_revenue': 7500000.0,
          'cash_revenue': 2500000.0,
          'non_cash_revenue': 5000000.0,
        },
        {
          'branch_id': 2,
          'branch_name': 'RentCore Cabang Barat',
          'is_central': false,
          'transaction_count': 8,
          'total_revenue': 5000000.0,
          'cash_revenue': 2000000.0,
          'non_cash_revenue': 3000000.0,
        },
      ],
      'recent_transactions': [
        {
          'id': 101,
          'transaction_code': 'TX-261014-0001',
          'receipt_number': 'REC-PST-0001',
          'booking_id': 101,
          'booking_code': 'BK-PST-101',
          'customer_name': 'Ahmad Fauzi',
          'branch_id': 1,
          'branch_name': 'RentCore Pusat',
          'is_central': true,
          'cashier_name': 'Kasir Pusat',
          'amount': 450000.0,
          'payment_method': 'Tunai',
          'items_summary': 'iPhone 15 Pro Natural Titanium (SN: SN-APPLE-001)',
          'transacted_at': '2026-10-14 10:30:00',
        },
        {
          'id': 102,
          'transaction_code': 'TX-261014-0002',
          'receipt_number': 'REC-BRT-0001',
          'booking_id': 102,
          'booking_code': 'BK-BRT-102',
          'customer_name': 'Dewi Lestari',
          'branch_id': 2,
          'branch_name': 'Cabang Barat',
          'is_central': false,
          'cashier_name': 'Kasir Barat',
          'amount': 350000.0,
          'payment_method': 'QRIS',
          'items_summary': 'iPhone 13 Starlight (SN: SN-APPLE-002)',
          'transacted_at': '2026-10-14 11:15:00',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    return [
      {
        'id': 101,
        'booking_code': 'BK-PST-101',
        'status': 'rented',
        'payment_status': 'paid',
        'total_bill': 450000.0,
        'subtotal_amount': 450000.0,
        'discount_amount': 0.0,
        'duration_hours': 24,
        'start_at': '2026-10-14 09:00:00',
        'end_at': '2026-10-15 09:00:00',
        'customer': {'name': 'Ahmad Fauzi', 'phone': '081234567890'},
        'affiliate': {'id': 1, 'name': 'RentCore Pusat', 'is_central': true},
        'creator': {'name': 'Kasir Pusat'},
        'items': [
          {
            'asset': {
              'asset_code': 'IP15P-01',
              'serial_number': 'SN-APPLE-001',
              'imei_1': '351234567890123',
              'model': {'name': 'iPhone 15 Pro', 'storage_capacity': '256GB', 'color': 'Natural Titanium'},
            },
          },
        ],
        'payments': [
          {
            'receipt_number': 'REC-PST-0001',
            'amount': 450000.0,
            'type': 'settlement',
            'payment_method': {'name': 'Tunai'},
            'processor': {'name': 'Kasir Pusat'},
            'transacted_at': '2026-10-14 10:30:00',
          },
        ],
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    return {
      'id': bookingId,
      'booking_code': 'BK-PST-101',
      'status': 'rented',
      'payment_status': 'paid',
      'total_bill': 450000.0,
      'subtotal_amount': 450000.0,
      'discount_amount': 0.0,
      'duration_hours': 24,
      'start_at': '2026-10-14 09:00:00',
      'end_at': '2026-10-15 09:00:00',
      'customer': {'name': 'Ahmad Fauzi', 'phone': '081234567890'},
      'affiliate': {'id': 1, 'name': 'RentCore Pusat', 'is_central': true},
      'creator': {'name': 'Kasir Pusat'},
      'items': [
        {
          'asset': {
            'asset_code': 'IP15P-01',
            'serial_number': 'SN-APPLE-001',
            'imei_1': '351234567890123',
            'model': {'name': 'iPhone 15 Pro', 'storage_capacity': '256GB', 'color': 'Natural Titanium'},
          },
        },
      ],
      'payments': [
        {
          'receipt_number': 'REC-PST-0001',
          'amount': 450000.0,
          'type': 'settlement',
          'payment_method': {'name': 'Tunai'},
          'processor': {'name': 'Kasir Pusat'},
          'transacted_at': '2026-10-14 10:30:00',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
    ];
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

class _TestPosFilterBranchIdNotifier extends PosFilterBranchIdNotifier {
  final int? _initialValue;
  _TestPosFilterBranchIdNotifier([this._initialValue]);

  @override
  int? build() => _initialValue;
}

void main() {
  group('POS Revenue Consolidation & Multi-Branch Tests', () {
    testWidgets('Owner sees branch selector and consolidated revenue breakdown', (tester) async {
      final mockRepo = _MockCashierRepository();
      final businessState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Central Business',
        activeBranchId: 1,
        activeBranchName: 'RentCore Pusat (Main Store)',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Central Business',
            'membership': {'role': 'owner'},
            'branches': [
              {'id': 1, 'name': 'RentCore Pusat (Main Store)', 'is_central': true},
              {'id': 2, 'name': 'RentCore Cabang Barat', 'is_central': false},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
            posFilterBranchIdProvider.overrideWith(() => _TestPosFilterBranchIdNotifier(-1)), // Consolidated
          ],
          child: const MaterialApp(
            home: CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Verify branch selector header displays consolidated scope
      expect(find.text('CAKUPAN POS & REKAP KASIR'), findsOneWidget);
      expect(find.text('Semua Cabang (Konsolidasi)'), findsOneWidget);
      expect(find.text('Ganti'), findsOneWidget);

      // 2. Switch to Tab 2: Rekap Shift & Closing
      await tester.tap(find.text('Rekap Shift & Closing'));
      await tester.pumpAndSettle();

      // 3. Verify date filter chips rendered
      expect(find.text('Hari Ini'), findsOneWidget);
      expect(find.text('Kemarin'), findsOneWidget);
      expect(find.text('Bulan Ini'), findsOneWidget);

      // 4. Verify Consolidated Omset and KONSOLIDASI badge
      expect(find.text('KONSOLIDASI'), findsOneWidget);
      expect(find.text('Rp 12.500.000'), findsOneWidget);
      expect(find.text('18 transaksi berhasil diselesaikan'), findsOneWidget);

      // 5. Verify Tunai vs Non-Tunai split
      expect(find.text('Tunai (Cash)'), findsOneWidget);
      expect(find.text('Rp 4.500.000'), findsNWidgets(2)); // in quick summary and payment method list
      expect(find.text('Non-Tunai'), findsOneWidget);
      expect(find.text('Rp 8.000.000'), findsNWidgets(2)); // in quick summary and payment method list

      // 6. Verify Per-Branch Contribution Section
      expect(find.text('KONTRIBUSI REVENUE PER CABANG'), findsOneWidget);
      expect(find.text('RentCore Pusat (Main Store)'), findsOneWidget);
      expect(find.text('RentCore Cabang Barat'), findsOneWidget);
      expect(find.text('Rp 7.500.000'), findsOneWidget);
      expect(find.text('Rp 5.000.000'), findsOneWidget);

      // 7. Verify Recent Completed Transactions audit list
      expect(find.text('TRANSAKSI TERBARU (AUDIT RINCIAN)'), findsOneWidget);
      expect(find.text('REC-PST-0001'), findsOneWidget);
      expect(find.text('REC-BRT-0001'), findsOneWidget);
    });

    testWidgets('Tapping transaction opens PosTransactionDetailSheet with device identifiers', (tester) async {
      final mockRepo = _MockCashierRepository();
      final businessState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Central Business',
        activeBranchId: 1,
        activeBranchName: 'RentCore Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Central Business',
            'membership': {'role': 'owner'},
            'branches': [
              {'id': 1, 'name': 'RentCore Pusat', 'is_central': true},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // On Tab 1: Meja Kasir POS
      expect(find.text('BK-PST-101'), findsOneWidget);
      expect(find.text('Rincian'), findsOneWidget);

      // Tap 'Rincian' button
      await tester.tap(find.text('Rincian'));
      await tester.pumpAndSettle();

      // Verify PosTransactionDetailSheet opened
      expect(find.byType(PosTransactionDetailSheet), findsOneWidget);
      expect(find.text('Rincian Transaksi Rental POS'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PosTransactionDetailSheet),
          matching: find.text('Ahmad Fauzi'),
        ),
        findsOneWidget,
      );
      expect(find.text('SN: SN-APPLE-001'), findsOneWidget);
      expect(find.text('IMEI: 351234567890123'), findsOneWidget);
      expect(find.text('PERIODE & DURASI RENTAL'), findsOneWidget);
      expect(find.text('24 Jam'), findsOneWidget);
      expect(find.text('RINCIAN TAGIHAN & PEMBAYARAN'), findsOneWidget);
      expect(find.text('RIWAYAT TRANSAKSI PEMBAYARAN'), findsOneWidget);
    });
  });
}

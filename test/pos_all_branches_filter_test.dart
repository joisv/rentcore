import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _SpyCashierRepository extends CashierRepository {
  int? lastClosingBranchId;
  bool? lastClosingAllBranches;
  int? lastBookingsBranchId;
  bool? lastBookingsAllBranches;

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    lastClosingBranchId = branchId;
    lastClosingAllBranches = allBranches;

    final isConsolidated = allBranches || branchId == null;
    return {
      'branch_id': branchId,
      'is_consolidated': isConsolidated,
      'date': 'HARI INI',
      'total_revenue': isConsolidated ? 10000000.0 : 4000000.0,
      'total_transactions': isConsolidated ? 15 : 6,
      'breakdown_by_method': {
        'Tunai': {'count': 5, 'total': 3000000.0},
        'QRIS': {'count': 10, 'total': 7000000.0},
      },
      'breakdown_by_branch': isConsolidated
          ? [
              {
                'branch_id': 1,
                'branch_name': 'RentCore Pusat',
                'is_central': true,
                'transaction_count': 6,
                'total_revenue': 4000000.0,
                'cash_revenue': 1000000.0,
                'non_cash_revenue': 3000000.0,
              },
              {
                'branch_id': 2,
                'branch_name': 'RentCore Cabang Barat',
                'is_central': false,
                'transaction_count': 9,
                'total_revenue': 6000000.0,
                'cash_revenue': 2000000.0,
                'non_cash_revenue': 4000000.0,
              },
            ]
          : [
              {
                'branch_id': branchId,
                'branch_name': branchId == 2 ? 'RentCore Cabang Barat' : 'RentCore Pusat',
                'is_central': branchId != 2,
                'transaction_count': 6,
                'total_revenue': 4000000.0,
                'cash_revenue': 1000000.0,
                'non_cash_revenue': 3000000.0,
              },
            ],
      'recent_transactions': [
        {
          'id': 201,
          'transaction_code': 'TX-ALL-001',
          'receipt_number': 'REC-ALL-001',
          'booking_id': 201,
          'booking_code': 'BK-ALL-201',
          'customer_name': 'Andi Pratama',
          'branch_id': branchId ?? 1,
          'branch_name': branchId == 2 ? 'RentCore Cabang Barat' : 'RentCore Pusat',
          'is_central': branchId != 2,
          'cashier_name': 'Kasir Utama',
          'amount': 500000.0,
          'payment_method': 'Tunai',
          'items_summary': 'iPhone 15 Pro (SN: SN-001)',
          'transacted_at': '2026-10-14 10:00:00',
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
    lastBookingsBranchId = branchId;
    lastBookingsAllBranches = allBranches;

    return [
      {
        'id': 201,
        'booking_code': 'BK-ALL-201',
        'status': 'rented',
        'payment_status': 'paid',
        'total_bill': 500000.0,
        'subtotal_amount': 500000.0,
        'discount_amount': 0.0,
        'duration_hours': 24,
        'start_at': '2026-10-14 09:00:00',
        'end_at': '2026-10-15 09:00:00',
        'customer': {'name': 'Andi Pratama', 'phone': '081234567890'},
        'affiliate': {
          'id': branchId ?? 1,
          'name': branchId == 2 ? 'RentCore Cabang Barat' : 'RentCore Pusat',
          'is_central': branchId != 2,
        },
        'creator': {'name': 'Kasir Utama'},
        'items': [
          {
            'unit_price': 500000.0,
            'asset': {
              'serial_number': 'SN-001',
              'imei_1': '351234567890123',
              'model': {'name': 'iPhone 15 Pro'},
            },
          },
        ],
        'payments': [
          {
            'amount': 500000.0,
            'payment_method': {'name': 'Tunai'},
            'processed_by': {'name': 'Kasir Utama'},
            'transacted_at': '2026-10-14 09:00:00',
          },
        ],
      },
    ];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
    ];
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;
}

void main() {
  group('POS All Branches Revenue Filter Tests', () {
    testWidgets('Selecting All Branches sets allBranches flag and retrieves multi-branch data', (tester) async {
      final spyRepo = _SpyCashierRepository();
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
              {'id': 2, 'name': 'RentCore Cabang Barat', 'is_central': false},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(spyRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Initial State: activeBranchId is 1 (Pusat)
      expect(find.text('RentCore Pusat'), findsWidgets);

      // 2. Open Branch Scope Modal
      await tester.tap(find.text('Ganti'));
      await tester.pumpAndSettle();

      // 3. Select 'Semua Cabang (Konsolidasi)'
      expect(find.text('Semua Cabang (Konsolidasi)'), findsOneWidget);
      await tester.tap(find.text('Semua Cabang (Konsolidasi)'));
      await tester.pumpAndSettle();

      // 4. Verify Repository was called with allBranches = true
      expect(spyRepo.lastBookingsAllBranches, isTrue);
      expect(spyRepo.lastBookingsBranchId, isNull);

      // 5. Switch to Rekap Shift & Closing Tab
      await tester.tap(find.text('Rekap Shift & Closing'));
      await tester.pumpAndSettle();

      // 6. Verify closing summary called with allBranches = true
      expect(spyRepo.lastClosingAllBranches, isTrue);
      expect(spyRepo.lastClosingBranchId, isNull);

      // 7. Verify UI displays consolidated total and per-branch breakdown
      expect(find.text('KONSOLIDASI'), findsOneWidget);
      expect(find.text('Rp 10.000.000'), findsOneWidget);
      expect(find.text('KONTRIBUSI REVENUE PER CABANG'), findsOneWidget);
      expect(find.text('RentCore Cabang Barat'), findsOneWidget);

      // 8. Now switch to 'RentCore Cabang Barat'
      await tester.tap(find.text('Ganti'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'RentCore Cabang Barat'));
      await tester.pumpAndSettle();

      // 9. Verify Repository was called with branchId = 2 and allBranches = false
      expect(spyRepo.lastClosingBranchId, equals(2));
      expect(spyRepo.lastClosingAllBranches, isFalse);
      expect(spyRepo.lastBookingsBranchId, equals(2));
      expect(spyRepo.lastBookingsAllBranches, isFalse);

      // 10. Switch back to 'Semua Cabang (Konsolidasi)'
      await tester.tap(find.text('Ganti'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Semua Cabang (Konsolidasi)'));
      await tester.pumpAndSettle();

      expect(spyRepo.lastClosingAllBranches, isTrue);
      expect(spyRepo.lastClosingBranchId, isNull);
    });
  });
}

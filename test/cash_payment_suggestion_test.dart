import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/utils/cash_suggestion_helper.dart';
import 'package:rentcore_mobile/core/utils/currency_formatter.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _FakeCashierRepoForSuggestions extends CashierRepository {
  final List<Map<String, dynamic>> bookings;
  _FakeCashierRepoForSuggestions(this.bookings);

  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    return bookings;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
    ];
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
      'total_revenue': 0.0,
      'total_transactions': 0,
      'breakdown_by_type': {},
      'breakdown_by_method': {},
      'recent_transactions': [],
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;
}

void main() {
  group('CashPaymentSuggestionHelper Algorithm Tests', () {
    test('1. Total Rp70,000 suggests Rp70,000 and practical higher amounts such as Rp100,000', () {
      final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(70000);

      expect(suggestions, contains(70000));
      expect(suggestions, contains(100000));
      expect(suggestions.first, 70000);
      expect(suggestions, equals([70000, 100000, 200000, 500000]));
    });

    test('2. Total Rp500,000 never suggests amounts below Rp500,000', () {
      final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(500000);

      expect(suggestions.first, 500000);
      for (final s in suggestions) {
        expect(s >= 500000, isTrue, reason: 'Amount $s is less than 500000');
      }
      expect(suggestions.contains(50000), isFalse);
      expect(suggestions.contains(100000), isFalse);
      expect(suggestions.contains(200000), isFalse);
      expect(suggestions.contains(350000), isFalse);
      expect(suggestions, equals([500000, 1000000]));
    });

    test('3. Total Rp125,000 produces valid, useful suggestions in ascending order', () {
      final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(125000);

      expect(suggestions.first, 125000);
      expect(suggestions, containsAll([125000, 130000, 150000, 200000]));
      // Verify strictly ascending order
      for (int i = 0; i < suggestions.length - 1; i++) {
        expect(suggestions[i] < suggestions[i + 1], isTrue);
      }
    });

    test('4. Exact payment always produces zero change and zero shortage', () {
      const double amountDue = 125000.0;
      final change = CashPaymentSuggestionHelper.calculateChange(
        amountDue: amountDue,
        cashReceived: 125000.0,
      );
      final shortage = CashPaymentSuggestionHelper.calculateShortage(
        amountDue: amountDue,
        cashReceived: 125000.0,
      );

      expect(change, 0.0);
      expect(shortage, 0.0);
    });

    test('5. Selecting Rp100,000 for a Rp70,000 transaction produces Rp30,000 change', () {
      const double amountDue = 70000.0;
      const double cashReceived = 100000.0;

      final change = CashPaymentSuggestionHelper.calculateChange(
        amountDue: amountDue,
        cashReceived: cashReceived,
      );
      final shortage = CashPaymentSuggestionHelper.calculateShortage(
        amountDue: amountDue,
        cashReceived: cashReceived,
      );

      expect(change, 30000.0);
      expect(shortage, 0.0);
    });

    test('6. Changing total due dynamically refreshes the suggestions', () {
      var due = 70000;
      var suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(due);
      expect(suggestions.first, 70000);
      expect(suggestions, contains(100000));

      due = 350000;
      suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(due);
      expect(suggestions.first, 350000);
      expect(suggestions, containsAll([350000, 400000, 500000, 1000000]));
      expect(suggestions.contains(70000), isFalse);
    });

    test('7. Voucher discounts and charges affect suggestions through the final payable amount', () {
      const double basePrice = 150000.0;
      const double voucherDiscount = 25000.0;
      final finalPayable = basePrice - voucherDiscount; // 125000

      final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(finalPayable);
      expect(suggestions.first, 125000);
      expect(suggestions, contains(130000));
      expect(suggestions, contains(150000));
    });

    test('8. No duplicate suggestion amounts are displayed', () {
      final amountsToTest = [15000, 70000, 100000, 125000, 350000, 500000, 1000000, 1250000];

      for (final amt in amountsToTest) {
        final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(amt);
        final uniqueSet = suggestions.toSet();
        expect(suggestions.length, uniqueSet.length, reason: 'Duplicate found for amount $amt');
      }
    });

    test('9. No suggestion is below the amount due for full settlement', () {
      final amountsToTest = [20000, 70000, 125000, 250000, 500000, 650000, 1200000];

      for (final amt in amountsToTest) {
        final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(amt);
        for (final s in suggestions) {
          expect(s >= amt, isTrue, reason: 'Suggestion $s is below amount due $amt');
        }
      }
    });

    test('10. Suggestions use Indonesian Rupiah formatting', () {
      final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(70000);
      final formatted = suggestions.map((s) => CurrencyFormatter.format(s)).toList();

      expect(formatted.first, 'Rp 70.000');
      expect(formatted, contains('Rp 100.000'));
      expect(formatted, contains('Rp 200.000'));
      expect(formatted, contains('Rp 500.000'));
    });

    test('11. Manual cash entry shortage calculation works correctly', () {
      const double amountDue = 70000.0;
      const double manualCashReceived = 50000.0; // Underpaid

      final change = CashPaymentSuggestionHelper.calculateChange(
        amountDue: amountDue,
        cashReceived: manualCashReceived,
      );
      final shortage = CashPaymentSuggestionHelper.calculateShortage(
        amountDue: amountDue,
        cashReceived: manualCashReceived,
      );

      expect(change, 0.0);
      expect(shortage, 20000.0);
    });

    test('12. Non-cash payment methods bypass cash change calculation', () {
      const double amountDue = 350000.0;
      double getChangeForMethod({required String methodCode, required double cashReceived}) {
        if (methodCode != 'CASH') return 0.0;
        return CashPaymentSuggestionHelper.calculateChange(
          amountDue: amountDue,
          cashReceived: cashReceived,
        );
      }

      expect(getChangeForMethod(methodCode: 'QRIS', cashReceived: 400000.0), 0.0);
      expect(getChangeForMethod(methodCode: 'TRANSFER', cashReceived: 400000.0), 0.0);
      expect(getChangeForMethod(methodCode: 'CASH', cashReceived: 400000.0), 50000.0);
    });

    test('13. Zero or negative amount due returns empty list', () {
      expect(CashPaymentSuggestionHelper.getSuggestedAmounts(0), isEmpty);
      expect(CashPaymentSuggestionHelper.getSuggestedAmounts(-50000), isEmpty);
    });
  });

  group('POS Cash Payment Suggestions UI Widget Tests', () {
    final businessState = BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'RentCore Central Business',
      activeBranchId: 1,
      activeBranchName: 'Cabang Utama',
      businesses: [
        {
          'id': 1,
          'name': 'RentCore Central Business',
          'membership': {'role': 'owner'},
          'branches': [
            {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
          ],
        },
      ],
    );

    testWidgets('POS Payment Modal for Rp500,000 never shows chips below Rp500,000 and calculates change correctly', (tester) async {
      final fakeRepo = _FakeCashierRepoForSuggestions([
        {
          'id': 10,
          'booking_code': 'BK-500K-001',
          'customer': {'name': 'Andi Pratama', 'phone': '0811223344'},
          'items': [
            {
              'asset': {
                'asset_code': 'IP17-01',
                'model': {'name': 'iPhone 17'},
              }
            }
          ],
          'duration_hours': 24,
          'subtotal_amount': 500000.0,
          'discount_amount': 0.0,
          'total_bill': 500000.0,
          'payment_status': 'unpaid',
          'payments': [],
        }
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CashierScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap 'Bayar' button on cashier table
      final bayarButton = find.widgetWithText(ElevatedButton, 'Bayar');
      expect(bayarButton, findsOneWidget);
      await tester.tap(bayarButton);
      await tester.pumpAndSettle();

      // Check modal is open
      expect(find.text('TERMINAL KASIR POS'), findsOneWidget);
      expect(find.text('BK-500K-001'), findsAtLeastNWidgets(1));

      // Verify suggestions include Rp 500.000 and Rp 1.000.000
      expect(find.widgetWithText(ActionChip, 'Rp 500.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 1.000.000'), findsOneWidget);

      // Verify suggestions NEVER include chips below Rp 500,000
      expect(find.widgetWithText(ActionChip, 'Rp 50.000'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Rp 100.000'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Rp 200.000'), findsNothing);
      expect(find.widgetWithText(ActionChip, 'Rp 350.000'), findsNothing);

      // Tap Rp 1.000.000 chip
      await tester.tap(find.widgetWithText(ActionChip, 'Rp 1.000.000'));
      await tester.pumpAndSettle();

      // Verify Kembalian is Rp 500.000
      expect(find.text('Kembalian Pelanggan:'), findsOneWidget);
      expect(find.text('Rp 500.000'), findsAtLeastNWidgets(1));
    });

    testWidgets('POS Payment Modal for Rp70,000 suggests practical higher denominations and calculates change', (tester) async {
      final fakeRepo = _FakeCashierRepoForSuggestions([
        {
          'id': 11,
          'booking_code': 'BK-70K-001',
          'customer': {'name': 'Budi Santoso', 'phone': '0812345678'},
          'items': [
            {
              'asset': {
                'asset_code': 'ACC-01',
                'model': {'name': 'MagSafe Battery Pack'},
              }
            }
          ],
          'duration_hours': 24,
          'subtotal_amount': 70000.0,
          'discount_amount': 0.0,
          'total_bill': 70000.0,
          'payment_status': 'unpaid',
          'payments': [],
        }
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CashierScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find and tap 'Bayar' button
      final bayarButton = find.widgetWithText(ElevatedButton, 'Bayar');
      expect(bayarButton, findsOneWidget);
      await tester.tap(bayarButton);
      await tester.pumpAndSettle();

      // Verify suggestions include Rp 70.000, Rp 100.000, Rp 200.000, Rp 500.000
      expect(find.widgetWithText(ActionChip, 'Rp 70.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 100.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 200.000'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'Rp 500.000'), findsOneWidget);

      // Verify no suggestion below 70k (e.g. 50k)
      expect(find.widgetWithText(ActionChip, 'Rp 50.000'), findsNothing);

      // Tap Rp 100.000
      await tester.tap(find.widgetWithText(ActionChip, 'Rp 100.000'));
      await tester.pumpAndSettle();

      // Verify change is Rp 30.000
      expect(find.text('Kembalian Pelanggan:'), findsOneWidget);
      expect(find.text('Rp 30.000'), findsOneWidget);
    });
  });
}

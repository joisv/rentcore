import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:sewakasir/features/cashier/presentation/widgets/add_branch_expense_modal.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/shared/widgets/floating_capsule_dock.dart';

class _FakeFailingPinCashierRepository extends CashierRepository {
  int attempts = 0;

  @override
  Future<Map<String, dynamic>> voidTransaction({
    required int transactionId,
    required String reason,
    String? managerPin,
  }) async {
    attempts++;
    throw Exception('PIN Manager salah atau otorisasi ditolak.');
  }
}

void main() {
  group('Phase P1 — FloatingCapsuleDock 5-Slot Navigation Tests', () {
    testWidgets('Renders 4 icon-only tabs + centered + action and switches active filled icon', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: StatefulBuilder(
              builder: (context, setState) {
                return FloatingCapsuleDock(
                  currentIndex: selectedIndex,
                  onTabSelected: (idx) => setState(() => selectedIndex = idx),
                );
              },
            ),
          ),
        ),
      );

      // Verify all 4 tab items + center + button exist with zero text labels
      expect(find.byIcon(Icons.home_outlined), findsNothing); // Active item (index 0) has filled icon
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(FloatingCapsuleDock),
          matching: find.byType(Text),
        ),
        findsNothing,
      );

      // Tap index 2 (Aset / Inventaris)
      await tester.tap(find.byIcon(Icons.inventory_2_outlined));
      await tester.pumpAndSettle();

      expect(selectedIndex, equals(2));
      expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
    });
  });

  group('Phase P1 — POS Void Transaction Manager PIN Rate-Limiting Tests', () {
    testWidgets('Rate limits and locks out PIN after 3 failed attempts', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final fakeRepo = _FakeFailingPinCashierRepository();

      final mockBooking = {
        'id': 101,
        'booking_id': 101,
        'payments': [
          {
            'id': 501,
            'amount': 250000,
            'status': 'paid',
            'type': 'settlement',
            'payment_method': 'Tunai',
            'transaction_code': 'TX-501',
          }
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            bookingDetailProvider(101).overrideWith((ref) => Future.value(mockBooking)),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Scaffold(
              body: PosTransactionDetailSheet(booking: mockBooking),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "Batalkan" / Void on the payment item
      expect(find.byTooltip('Batalkan Pembayaran (Void)'), findsOneWidget);
      await tester.tap(find.byTooltip('Batalkan Pembayaran (Void)'));
      await tester.pumpAndSettle();

      // Void dialog opens
      expect(find.text('Batalkan Transaksi (Void)'), findsOneWidget);

      // Fill reason
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contoh: Salah input nominal, duplikasi, dsb.'),
        'Salah input nominal',
      );
      // Enter invalid PIN
      await tester.enterText(
        find.widgetWithText(TextFormField, '6 digit PIN Manager'),
        '000000',
      );

      // Attempt 1: Fail
      await tester.tap(find.text('Void Transaksi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PIN Manager salah (1/3 percobaan).'), findsOneWidget);
      expect(fakeRepo.attempts, equals(1));

      // Attempt 2: Fail
      await tester.tap(find.text('Void Transaksi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('PIN Manager salah (2/3 percobaan).'), findsOneWidget);
      expect(fakeRepo.attempts, equals(2));

      // Attempt 3: Fail -> Triggers 30s lockout
      await tester.tap(find.text('Void Transaksi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeRepo.attempts, equals(3));
      // Lockout alert banner should appear
      expect(find.textContaining('dikunci sementara'), findsOneWidget);
      expect(find.textContaining('Terkunci'), findsWidgets);

      // Dismiss dialog cleanly
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
    });
  });

  group('Phase P1 — AddBranchExpenseModal Inline Validation Tests', () {
    testWidgets('Validates required fields and manager PIN requirement for > 100k', (tester) async {
      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AddBranchExpenseModal(branchId: 1),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Submit immediately with empty inputs
      await tester.tap(find.text('Simpan Pengeluaran'));
      await tester.pumpAndSettle();

      expect(find.text('Judul pengeluaran wajib diisi.'), findsOneWidget);
      expect(find.text('Nominal pengeluaran harus lebih dari 0.'), findsOneWidget);

      // Fill title
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contoh: Token Listrik PLN 100k, Kertas Struk, dll.'),
        'Kertas Struk Kasir',
      );

      // Fill nominal 50k (no PIN needed)
      await tester.enterText(
        find.widgetWithText(TextFormField, '0'),
        '50000',
      );
      await tester.pumpAndSettle();

      expect(find.text('Otorisasi Manager Diperlukan'), findsNothing);

      // Change nominal to 150k (> 100k -> PIN required)
      await tester.enterText(
        find.widgetWithText(TextFormField, '50000'),
        '150000',
      );
      await tester.pumpAndSettle();

      expect(find.text('Otorisasi Manager Diperlukan'), findsOneWidget);

      // Tap submit with empty PIN
      await tester.tap(find.text('Simpan Pengeluaran'));
      await tester.pumpAndSettle();

      expect(find.text('PIN Manager wajib diisi untuk nominal > Rp 100.000.'), findsOneWidget);
    });
  });
}

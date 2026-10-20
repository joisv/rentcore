import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/features/cashier/presentation/widgets/add_branch_expense_modal.dart';
import 'package:rentcore_mobile/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';
import 'package:rentcore_mobile/shared/widgets/pos_numpad.dart';

void main() {
  group('Phase P3 — PosNumpad Unit & Touch Tests', () {
    testWidgets('Tapping digits, backspace, clear, quick add, and exact amount works as expected', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PosNumpad(
              controller: controller,
              exactAmount: 250000,
            ),
          ),
        ),
      );

      // 1. Enter 15000
      await tester.tap(find.text('1'));
      await tester.pump();
      await tester.tap(find.text('5'));
      await tester.pump();
      await tester.tap(find.text('0'));
      await tester.pump();
      await tester.tap(find.text('00'));
      await tester.pump();

      expect(controller.text, equals('15000'));

      // 2. Backspace
      await tester.tap(find.byIcon(Icons.backspace_outlined));
      await tester.pump();

      expect(controller.text, equals('1500'));

      // 3. Clear 'C'
      await tester.tap(find.text('C'));
      await tester.pump();

      expect(controller.text, equals(''));

      // 4. Quick Add (+50k)
      await tester.tap(find.text('+50k'));
      await tester.pump();

      expect(controller.text, equals('50000'));

      // 5. Exact Amount ("Pas")
      await tester.tap(find.textContaining('Pas'));
      await tester.pump();

      expect(controller.text, equals('250000'));
    });
  });

  group('Phase P3 — PaymentPage PosNumpad Integration Tests', () {
    testWidgets('Renders PosNumpad in cash mode and allows toggle', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dummyContext = PaymentContext.booking(
        customerName: 'Ahmad Faiz',
        customerPhone: '081234567890',
        deviceName: 'iPhone 15 Pro Max',
        totalAmount: 300000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentMethodsProvider.overrideWith((ref) => Future.value([
              {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
              {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
            ])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: Scaffold(
              body: PaymentPage(paymentContext: dummyContext),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Numpad is visible by default in cash mode
      expect(find.text('KEYPAD NUMERIK POS'), findsOneWidget);
      expect(find.text('Sembunyikan'), findsOneWidget);
      expect(find.byType(PosNumpad), findsOneWidget);

      // Toggle off
      await tester.tap(find.text('Sembunyikan'));
      await tester.pumpAndSettle();

      expect(find.text('Buka Keypad'), findsOneWidget);
      expect(find.byType(PosNumpad), findsNothing);

      // Toggle back on
      await tester.tap(find.text('Buka Keypad'));
      await tester.pumpAndSettle();

      expect(find.byType(PosNumpad), findsOneWidget);
    });
  });

  group('Phase P3 — Counter Cash Denomination Chips Tests', () {
    testWidgets('CashDrawerShiftModal quick float chips fill opening amount', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: CashDrawerShiftModal(activeShift: null),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rp 500.000'), findsOneWidget);
      await tester.tap(find.text('Rp 500.000'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '500000'), findsOneWidget);
    });

    testWidgets('AddBranchExpenseModal quick add buttons increment expense amount', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
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

      expect(find.text('+50k'), findsOneWidget);
      await tester.tap(find.text('+50k'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextFormField, '50000'), findsOneWidget);
    });
  });
}

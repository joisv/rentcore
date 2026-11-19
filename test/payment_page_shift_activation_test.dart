import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/widgets/quick_open_shift_modal.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class FakeCashierRepoForShiftTest extends CashierRepository {
  bool hasActiveShift;
  double? openedFloat;
  int? openedBranchId;
  int openShiftCallCount = 0;
  Completer<Map<String, dynamic>>? pendingShiftCheck;

  FakeCashierRepoForShiftTest({this.hasActiveShift = false, this.pendingShiftCheck});

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    if (pendingShiftCheck != null) {
      return pendingShiftCheck!.future;
    }
    if (hasActiveShift) {
      return {
        'has_active_shift': true,
        'shift': {
          'id': 10,
          'shift_number': 'SHF-2026-001',
          'status': 'open',
          'opening_cash_float': openedFloat ?? 100000.0,
        },
      };
    }
    return {
      'has_active_shift': false,
      'shift': null,
    };
  }

  @override
  Future<Map<String, dynamic>> openShift({
    required double openingCashFloat,
    int? branchId,
    String? notes,
  }) async {
    openShiftCallCount++;
    hasActiveShift = true;
    openedFloat = openingCashFloat;
    openedBranchId = branchId;
    return {
      'id': 10,
      'status': 'open',
      'opening_cash_float': openingCashFloat,
    };
  }
}

void main() {
  final defaultPaymentMethods = [
    {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
    {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'is_active': true},
    {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank', 'is_active': true},
  ];

  final testPaymentContext = PaymentContext(
    transactionType: PaymentTransactionType.booking,
    customerName: 'Ahmad Customer',
    customerPhone: '081234567890',
    deviceName: 'Sony A7 IV',
    bookingCode: 'BK-2026-0001',
    totalAmountDue: 150000.0,
    remainingDue: 150000.0,
    previouslyPaidAmount: 0.0,
    branchId: 1,
    branchName: 'Cabang Pusat',
  );

  group('PaymentPage In-Place Shift Activation Warning & Quick-Open Modal Tests', () {
    testWidgets(
      'Displays warning banner on PaymentPage when shift is inactive and disables checkout confirmation',
      (tester) async {
        final fakeRepo = FakeCashierRepoForShiftTest(hasActiveShift: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({
                  'config': {
                    'cash_enabled': true,
                    'qris_statis_enabled': true,
                    'bank_transfer_enabled': true,
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(paymentContext: testPaymentContext),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify compact single-line warning banner is rendered
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsOneWidget);
        expect(find.text('Shift kasir belum dibuka'), findsOneWidget);
        expect(find.text('Buka Shift ›'), findsOneWidget);
        expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
        expect(find.byKey(const Key('open_shift_now_button')), findsOneWidget);

        // 2. Open detail sewa sheet
        final detailLink = find.text('Detail Sewa');
        expect(detailLink, findsOneWidget);
        await tester.tap(detailLink);
        await tester.pumpAndSettle();

        // 3. In detail sheet, warning is displayed and "KONFIRMASI PEMBAYARAN" is disabled
        expect(find.text('KONFIRMASI PEMBAYARAN'), findsOneWidget);
        final confirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('detail_sheet_confirm_button')));
        expect(confirmBtn.onPressed, isNull);
      },
    );

    testWidgets(
      'Opens QuickOpenShiftModal, submits modal cash, and re-enables payment reactively without losing cart state',
      (tester) async {
        final fakeRepo = FakeCashierRepoForShiftTest(hasActiveShift: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({
                  'config': {
                    'cash_enabled': true,
                    'qris_statis_enabled': true,
                    'bank_transfer_enabled': true,
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(paymentContext: testPaymentContext),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Verify initial state has warning card
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsOneWidget);

        // 2. Tap "+ Buka Shift Sekarang" button
        final openShiftBtn = find.byKey(const Key('open_shift_now_button'));
        await tester.tap(openShiftBtn);
        await tester.pumpAndSettle();

        // 3. Verify QuickOpenShiftModal is open
        expect(find.byType(QuickOpenShiftModal), findsOneWidget);
        expect(find.text('Buka Shift Kasir'), findsOneWidget);
        expect(
          find.text('Masukkan uang modal awal di laci kasir sebelum memulai transaksi.'),
          findsOneWidget,
        );
        expect(find.text('Modal Kas Awal (Rp)'), findsOneWidget);

        // 4. Select preset chip Rp 250.000
        final presetChip = find.text('Rp 250.000');
        expect(presetChip, findsOneWidget);
        await tester.tap(presetChip);
        await tester.pumpAndSettle();

        // 5. Submit modal
        final submitBtn = find.byKey(const Key('quick_open_shift_submit_button'));
        expect(submitBtn, findsOneWidget);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        // 6. Verify repository was called
        expect(fakeRepo.openShiftCallCount, 1);
        expect(fakeRepo.openedFloat, 250000.0);
        expect(fakeRepo.hasActiveShift, isTrue);

        // 7. Verify modal dismissed and warning banner is gone
        expect(find.byType(QuickOpenShiftModal), findsNothing);
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);

        // 8. Verify original rental cart context remains intact
        expect(find.text('Rp150.000'), findsOneWidget);
        expect(find.text('Total Tagihan'), findsOneWidget);

        // 9. Open detail sewa sheet and verify "KONFIRMASI PEMBAYARAN" is now active
        final detailLink = find.text('Detail Sewa');
        await tester.tap(detailLink);
        await tester.pumpAndSettle();

        final activeConfirmBtn = tester.widget<ElevatedButton>(find.byKey(const Key('detail_sheet_confirm_button')));
        expect(activeConfirmBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Opening Cash payment sheet with inactive shift shows warning, disables process button, and enables reactively upon shift opening',
      (tester) async {
        final fakeRepo = FakeCashierRepoForShiftTest(hasActiveShift: false);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({
                  'config': {
                    'cash_enabled': true,
                    'qris_statis_enabled': true,
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(paymentContext: testPaymentContext),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap the Tunai card to open Cash Sheet
        final tunaiCard = find.text('Tunai');
        expect(tunaiCard, findsOneWidget);
        await tester.tap(tunaiCard);
        await tester.pumpAndSettle();

        // Verify Cash Sheet is open and button is disabled
        expect(find.text('PEMBAYARAN TUNAI'), findsOneWidget);
        final processBtn = tester.widget<ElevatedButton>(find.byKey(const Key('cash_sheet_process_button')));
        expect(processBtn.onPressed, isNull);

        // Tap "+ Buka Shift Sekarang" inside Cash Sheet (target the active bottom sheet one)
        final openShiftBtn = find.byKey(const Key('open_shift_now_button')).last;
        await tester.tap(openShiftBtn);
        await tester.pumpAndSettle();

        // Verify QuickOpenShiftModal appears
        expect(find.byType(QuickOpenShiftModal), findsOneWidget);

        // Submit opening shift with default float
        final submitModalBtn = find.byKey(const Key('quick_open_shift_submit_button'));
        await tester.tap(submitModalBtn);
        await tester.pumpAndSettle();

        // Verify QuickOpenShiftModal closed and process button in cash sheet is now enabled!
        expect(find.byType(QuickOpenShiftModal), findsNothing);
        expect(find.text('PEMBAYARAN TUNAI'), findsOneWidget);

        final activeProcessBtn = tester.widget<ElevatedButton>(find.byKey(const Key('cash_sheet_process_button')));
        expect(activeProcessBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'Zero flash/blip while active shift check is loading and remains hidden when shift is already open',
      (tester) async {
        final shiftCompleter = Completer<Map<String, dynamic>>();
        final fakeRepo = FakeCashierRepoForShiftTest(
          hasActiveShift: true,
          pendingShiftCheck: shiftCompleter,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({
                  'config': {
                    'cash_enabled': true,
                    'qris_statis_enabled': true,
                    'bank_transfer_enabled': true,
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(paymentContext: testPaymentContext),
            ),
          ),
        );

        // Initial frame & intermediate loading frames: banner must remain hidden (zero blip)
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);
        expect(find.text('Shift kasir belum dibuka'), findsNothing);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);
        expect(find.text('Shift kasir belum dibuka'), findsNothing);

        // Complete with an already-open shift
        shiftCompleter.complete({
          'has_active_shift': true,
          'shift': {
            'id': 10,
            'shift_number': 'SHF-2026-001',
            'status': 'open',
            'opening_cash_float': 100000.0,
          },
        });
        await tester.pumpAndSettle();

        // Banner still must not appear
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);
        expect(find.text('Shift kasir belum dibuka'), findsNothing);
        expect(find.text('QRIS'), findsOneWidget);
        expect(find.text('Tunai'), findsOneWidget);
        expect(find.text('Lainnya'), findsOneWidget);
      },
    );

    testWidgets(
      'Remains hidden during loading and shows compact single-line banner once unopened shift is confirmed',
      (tester) async {
        final shiftCompleter = Completer<Map<String, dynamic>>();
        final fakeRepo = FakeCashierRepoForShiftTest(
          hasActiveShift: false,
          pendingShiftCheck: shiftCompleter,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentMethodsProvider.overrideWith(
                (ref) => Future.value(defaultPaymentMethods),
              ),
              paymentSettingsProvider(1).overrideWith(
                (ref) => Future.value({
                  'config': {
                    'cash_enabled': true,
                    'qris_statis_enabled': true,
                    'bank_transfer_enabled': true,
                  },
                }),
              ),
            ],
            child: MaterialApp(
              home: PaymentPage(paymentContext: testPaymentContext),
            ),
          ),
        );

        // Still loading -> hidden
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsNothing);

        // Complete with unopened shift
        shiftCompleter.complete({
          'has_active_shift': false,
          'shift': null,
        });
        await tester.pumpAndSettle();

        // Compact single-line banner appears right above payment buttons
        expect(find.byKey(const Key('shift_activation_warning_banner')), findsOneWidget);
        expect(find.text('Shift kasir belum dibuka'), findsOneWidget);
        expect(find.text('Buka Shift ›'), findsOneWidget);
        final bannerRect = tester.getRect(find.byKey(const Key('shift_activation_warning_banner')));
        final tunaiRect = tester.getRect(find.text('Tunai'));
        expect(bannerRect.bottom, lessThan(tunaiRect.top));
      },
    );
  });
}

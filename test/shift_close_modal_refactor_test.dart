import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';

class _FakeCashierShiftModalRepo extends CashierRepository {
  bool closeShiftCalled = false;
  double? submittedActualCash;

  @override
  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    closeShiftCalled = true;
    submittedActualCash = actualCashCounted;
    return {
      'id': shiftId ?? 10,
      'shift_number': 'SHF-20261030-001',
      'status': 'closed',
      'opening_cash_float': 500000.0,
      'cash_inflow': 500000.0,
      'cash_expenses': 0.0,
      'expected_cash_total': 1000000.0,
      'actual_cash_counted': actualCashCounted,
      'cash_difference': actualCashCounted - 1000000.0,
      'difference_reason': differenceReason,
      'closing_notes': closingNotes,
    };
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  group('Tutup Shift & Rekonsiliasi Kas Modal Bottom Sheet Refactor Tests', () {
    final activeShiftSample = {
      'id': 10,
      'shift_number': 'SHF-20261030-001',
      'status': 'open',
      'opened_at': '2026-10-30T02:40:04+00:00',
      'opening_cash_float': 500000.0,
      'current_cash_inflow': 500000.0,
      'current_cash_refund': 0.0,
      'current_cash_expenses': 0.0,
      'expected_cash_now': '1000000.0',
    };

    testWidgets(
      '1. Header & Date Format: Shows title, close button, and localized subtitle row',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: activeShiftSample,
                  expectedDrawerCash: 1000000.0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Title and Close button
        expect(find.text('Tutup Shift & Rekonsiliasi Kas'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Combined Shift ID & Localized date string in subtitle
        // Raw: 2026-10-30T02:40:04+00:00 -> Localized WIB (e.g. 30 Okt 2026, ... WIB)
        expect(find.textContaining('SHF-20261030-001'), findsWidgets);
        expect(find.textContaining('WIB'), findsOneWidget);
        expect(find.textContaining('30 Okt 2026'), findsOneWidget);
      },
    );

    testWidgets(
      '2. Dual Cash Count Modes: Segment toggle switches between Lembaran and Total Langsung',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final fakeRepo = _FakeCashierShiftModalRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: activeShiftSample,
                  expectedDrawerCash: 1000000.0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // 1. Initial Mode: "Hitung Lembaran"
        expect(find.text('Hitung Lembaran'), findsOneWidget);
        expect(find.text('Input Total Langsung'), findsOneWidget);

        // Denominations are present
        expect(find.text('Rp 100.000'), findsOneWidget);
        expect(find.text('Rp  50.000'), findsOneWidget);
        expect(find.text('Koin / Lain'), findsOneWidget);
        expect(find.text('Total Uang Fisik di Laci'), findsNothing);

        // 2. Switch to "Input Total Langsung"
        await tester.tap(find.text('Input Total Langsung'));
        await tester.pumpAndSettle();

        // Denominations should now be hidden
        expect(find.text('Rp 100.000'), findsNothing);
        expect(find.text('Rp  50.000'), findsNothing);

        // Prominent Total Uang Fisik di Laci input is displayed
        expect(find.text('Total Uang Fisik di Laci'), findsOneWidget);

        // Enter 1.000.000 directly
        final directField = find.widgetWithText(TextFormField, '');
        expect(directField, findsWidgets);
        await tester.enterText(directField.first, '1000000');
        await tester.pumpAndSettle();

        // Blind Close: expected cash & live variance must NOT appear while closing
        expect(find.text('Fisik Kas Wajib Ada'), findsNothing);
        expect(find.text('Status: Selisih Nihil (Cocok)'), findsNothing);
        expect(find.text('Mode Blind Close Aktif'), findsOneWidget);
        expect(find.text('Uang Fisik yang Anda Hitung'), findsOneWidget);
        expect(find.text('Rp 1.000.000'), findsWidgets);

        // Submit Shift in direct lump-sum mode
        await tester.tap(find.text('Tutup Shift & Rekapitulasi Kasir'));
        await tester.pumpAndSettle();

        expect(fakeRepo.closeShiftCalled, isTrue);
        expect(fakeRepo.submittedActualCash, 1000000.0);
      },
    );

    testWidgets(
      '3. Denomination Rows Clean-up: No "lbr =" label, 44px height inputs, and Koin direct Rupiah',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: activeShiftSample,
                  expectedDrawerCash: 1000000.0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Repetitive "lbr =" must be removed completely
        expect(find.text('lbr ='), findsNothing);
        expect(find.textContaining('lbr'), findsNothing);

        // Check 44px height constraint on denomination text field containers
        final sizedBoxes = tester.widgetList<SizedBox>(find.byType(SizedBox));
        final has44pxInput = sizedBoxes.any((s) => s.height == 44.0 && s.width == 70.0);
        expect(has44pxInput, isTrue);

        // "Koin / Lain" is present with direct rupiah input
        expect(find.text('Koin / Lain'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Sticky Summary Blind Close: Shows only actual counted total without leaking variance before close',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2.0, 844 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: activeShiftSample,
                  expectedDrawerCash: 1000000.0,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Blind close: live variance indicators & expected total must stay hidden
        expect(find.text('Fisik Kas Wajib Ada'), findsNothing);
        expect(find.text('Status: Selisih Kurang'), findsNothing);
        expect(find.text('Status: Selisih Nihil (Cocok)'), findsNothing);
        expect(find.text('Status: Selisih Lebih'), findsNothing);
        expect(find.text('-Rp 1.000.000'), findsNothing);
        expect(find.text('Uang Fisik yang Anda Hitung'), findsOneWidget);
        expect(find.text('Rp 0'), findsWidgets);

        // Count 10 x 100k = 1.000.000 -> updates only counted total
        final formFields = find.descendant(
          of: find.byType(CashDrawerShiftModal),
          matching: find.byType(TextFormField),
        );
        await tester.enterText(formFields.at(0), '10');
        await tester.pumpAndSettle();

        expect(find.text('Rp 1.000.000'), findsWidgets);
        expect(find.text('Status: Selisih Nihil (Cocok)'), findsNothing);
      },
    );

    testWidgets(
      '5. Layout & Keyboard Handling: Bottom sheet wrapped with viewInsets padding',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2.0, 568 * 2.0); // Compact screen
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Material(
                child: MediaQuery(
                  data: MediaQueryData(
                    size: Size(320, 568),
                    viewInsets: EdgeInsets.only(bottom: 220),
                  ),
                  child: CashDrawerShiftModal(
                    activeShift: null, // Open mode
                    expectedDrawerCash: 500000.0,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify root Padding has bottom inset padding (220)
        final rootPaddingFinder = find.descendant(
          of: find.byType(CashDrawerShiftModal),
          matching: find.byType(Padding),
        );
        final Padding rootPadding = tester.widget<Padding>(rootPaddingFinder.first);
        expect(rootPadding.padding, const EdgeInsets.only(bottom: 220.0));

        // Verify no RenderFlex errors occur with keyboard open on 320 screen
        expect(tester.takeException(), isNull);
      },
    );
  });
}

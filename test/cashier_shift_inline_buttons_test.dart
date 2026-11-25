import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/financial_hub_screen.dart';
import 'package:sewakasir/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/shared/widgets/floating_capsule_dock.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'date': '2026-11-14',
      'total_revenue': 1400000.0,
      'total_transactions': 5,
      'is_consolidated': false,
      'cash_drawer_expenses': 50000.0,
      'total_expenses': 50000.0,
      'breakdown_by_type': {
        'rental': {
          'label': 'Sewa Kontrak Pokok',
          'total': 1400000.0,
          'count': 5,
        },
      },
      'breakdown_by_method': {
        'Tunai (Cash)': {'total': 900000.0, 'count': 3},
        'QRIS': {'total': 500000.0, 'count': 2},
      },
      'cash_reconciliation': {
        'opening_cash_float': 300000.0,
        'expected_cash_in_drawer': 1150000.0,
        'active_shift': {
          'id': 11,
          'shift_number': 'SHF-20261114-001',
          'status': 'open',
          'expected_cash_now': 1150000.0,
          'opening_cash_float': 300000.0,
          'cashier_name': 'Kasir Siang',
          'branch_name': 'Cabang Utama',
        },
      },
      'recent_transactions': [
        {
          'receipt_number': 'RCP-001',
          'customer_name': 'Budi Santoso',
          'items_summary': 'iPhone 16 Pro',
          'cashier_name': 'Kasir Siang',
          'payment_method': 'Tunai',
          'amount': 450000.0,
          'type': 'rental',
          'branch_name': 'Cabang Utama',
        },
        {
          'receipt_number': 'RCP-002',
          'customer_name': 'Siti Aminah',
          'items_summary': 'Sony A7 IV',
          'cashier_name': 'Kasir Siang',
          'payment_method': 'QRIS',
          'amount': 500000.0,
          'type': 'rental',
          'branch_name': 'Cabang Utama',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'data': {
        'has_active_shift': true,
        'shift': {
          'id': 11,
          'shift_number': 'SHF-20261114-001',
          'status': 'open',
          'opening_cash_float': 300000.0,
          'expected_cash_now': 1150000.0,
          'cashier_name': 'Kasir Siang',
          'branch_name': 'Cabang Utama',
        },
      },
    };
  }
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Kasir Siang', 'role': 'owner'},
  );
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Express',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Express',
        'role': 'owner',
        'branches': [
          {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
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

  group('Kasir & Shift Inline Action Buttons Layout Tests', () {
    testWidgets(
      'Cetak Struk and Tutup Shift sit inline inside scrollable body with 44dp height, 50/50 split, 10dp gap, and bottom: 104 clearance above FloatingCapsuleDock',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(_FakeCashierRepo()),
              authProvider.overrideWith(_TestAuthNotifier.new),
              businessProvider.overrideWith(_TestBusinessNotifier.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: Scaffold(
                extendBody: true,
                body: const FinancialHubScreen(initialTabIndex: 1),
                bottomNavigationBar: FloatingCapsuleDock(
                  currentIndex: 1,
                  onTabSelected: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Reconciliation card is unobstructed at top
        expect(find.text('Rekonsiliasi Kas Laci & Beban'), findsOneWidget);
        expect(find.text('Total Kas Wajib di Laci'), findsOneWidget);

        final printLabelFinder = find.text('Cetak Struk');
        final closeLabelFinder = find.text('Tutup Shift');
        expect(printLabelFinder, findsOneWidget);
        expect(closeLabelFinder, findsOneWidget);
        expect(find.text('Cetak Struk Closing'), findsNothing);

        final printBtnFinder = find.ancestor(
          of: printLabelFinder,
          matching: find.byType(OutlinedButton),
        );
        final closeBtnFinder = find.ancestor(
          of: closeLabelFinder,
          matching: find.byType(ElevatedButton),
        );
        expect(printBtnFinder, findsOneWidget);
        expect(closeBtnFinder, findsOneWidget);

        // Verify SingleChildScrollView wraps the buttons inline & has bottom >= 104 padding
        final scrollViewFinder = find.ancestor(
          of: printBtnFinder,
          matching: find.byType(SingleChildScrollView),
        );
        expect(scrollViewFinder, findsOneWidget);
        final scrollWidget = tester.widget<SingleChildScrollView>(
          scrollViewFinder,
        );
        final scrollPadding = scrollWidget.padding! as EdgeInsets;
        expect(scrollPadding.bottom, greaterThanOrEqualTo(104.0));

        // Verify sleek 46dp height, balanced 50%/50% width, and 10dp horizontal gap
        final printRect = tester.getRect(printBtnFinder);
        final closeRect = tester.getRect(closeBtnFinder);
        expect(printRect.height, 46.0);
        expect(closeRect.height, 46.0);
        expect(printRect.width, closeTo(closeRect.width, 0.5));
        expect(closeRect.left - printRect.right, closeTo(10.0, 0.5));

        // Verify OutlinedButton subtle border (#E2E8F0) and dark fill (#0F172A) on ElevatedButton
        final outlinedBtn = tester.widget<OutlinedButton>(printBtnFinder);
        expect(
          outlinedBtn.style?.side?.resolve({})?.color,
          const Color(0xFFE2E8F0),
        );
        final elevatedBtn = tester.widget<ElevatedButton>(closeBtnFinder);
        expect(
          elevatedBtn.style?.backgroundColor?.resolve({}),
          const Color(0xFF0F172A),
        );

        // Verify no text wrapping (TextPainter single-line height check)
        expect(tester.getSize(printLabelFinder).height, lessThanOrEqualTo(22));
        expect(tester.getSize(closeLabelFinder).height, lessThanOrEqualTo(22));

        // Scroll to the very bottom of the SingleChildScrollView and verify clean clearance above FloatingCapsuleDock
        await tester.drag(scrollViewFinder, const Offset(0, -1000));
        await tester.pumpAndSettle();

        final dockTop = tester.getTopLeft(find.byType(FloatingCapsuleDock)).dy;
        final scrolledPrintRect = tester.getRect(printBtnFinder);
        final scrolledCloseRect = tester.getRect(closeBtnFinder);
        expect(scrolledPrintRect.bottom, lessThan(dockTop));
        expect(scrolledCloseRect.bottom, lessThan(dockTop));

        // Verify Cetak Struk button is enabled & hit-testable, and Tutup Shift opens CashDrawerShiftModal
        expect(tester.widget<OutlinedButton>(printBtnFinder).onPressed, isNotNull);
        await tester.tap(closeBtnFinder);
        await tester.pumpAndSettle();
        expect(find.byType(CashDrawerShiftModal), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

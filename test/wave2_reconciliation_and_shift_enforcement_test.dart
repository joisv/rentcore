import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/cashier_screen.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';

class _FakeWave2CashierRepo extends CashierRepository {
  final bool shiftEnforcementEnabled;
  final bool hasActiveShift;
  final double cashDrawerExpenses;
  final double totalExpenses;

  _FakeWave2CashierRepo({
    this.shiftEnforcementEnabled = true,
    this.hasActiveShift = false,
    this.cashDrawerExpenses = 0.0,
    this.totalExpenses = 500000.0,
  });

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'is_active': true},
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': hasActiveShift,
      'shift_enforcement_enabled': shiftEnforcementEnabled,
      'shift': hasActiveShift
          ? {
              'id': 15,
              'shift_number': 'SHF-W2-001',
              'status': 'open',
              'opening_cash_float': 500000.0,
              'is_blind_close': true,
            }
          : null,
    };
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
      'date': '2026-11-19',
      'total_revenue': 1000000.0,
      'total_transactions': 2,
      'is_consolidated': false,
      'cash_drawer_expenses': cashDrawerExpenses,
      'total_expenses': totalExpenses,
      'breakdown_by_type': {},
      'breakdown_by_method': {
        'Tunai (Cash)': {'total': 1000000.0, 'count': 2},
      },
      'cash_reconciliation': {
        'opening_cash_float': 500000.0,
        'active_shift': hasActiveShift
            ? {
                'id': 15,
                'shift_number': 'SHF-W2-001',
                'status': 'open',
                'opening_cash_float': 500000.0,
                'is_blind_close': true,
              }
            : null,
      },
      'recent_transactions': [],
    };
  }
}

class _Wave2TestAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Kasir W2', 'role': 'staff'},
  );
}

class _Wave2TestBiz extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Wave 2: Expense Drawer Binding Display & Shift Enforcement Respect', () {
    testWidgets(
      'CashierScreen Active Shift tab displays Rp 0 (not -totalExpenses) when cash_drawer_expenses is 0 despite bank_transfer total_expenses',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeWave2CashierRepo(
          hasActiveShift: false,
          cashDrawerExpenses: 0.0,
          totalExpenses: 500000.0,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              authProvider.overrideWith(_Wave2TestAuth.new),
              businessProvider.overrideWith(_Wave2TestBiz.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Beban Kas Keluar (Laci)'), findsOneWidget);
        expect(find.text('-Rp 500.000'), findsNothing);
        expect(find.text('Rp 0'), findsWidgets);
      },
    );

    testWidgets(
      'PaymentPage enables checkout buttons when shift_enforcement_enabled is false and shift is null',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeWave2CashierRepo(
          shiftEnforcementEnabled: false,
          hasActiveShift: false,
        );

        final ctx = PaymentContext.booking(
          customerName: 'Rafi',
          deviceName: 'iPhone 16',
          totalAmount: 250000.0,
          branchId: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_Wave2TestBiz.new),
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
              theme: AppTheme.lightTheme,
              home: PaymentPage(paymentContext: ctx),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Warning banner must stay hidden when shift enforcement is off
        expect(
          find.byKey(const Key('shift_activation_warning_banner')),
          findsNothing,
        );

        // Cash sheet PROSES PEMBAYARAN button must be enabled
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();

        final processBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('cash_sheet_process_button')),
        );
        expect(processBtn.onPressed, isNotNull);
      },
    );

    testWidgets(
      'PaymentPage disables PROSES PEMBAYARAN when shift_enforcement_enabled is true and shift is null',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _FakeWave2CashierRepo(
          shiftEnforcementEnabled: true,
          hasActiveShift: false,
        );

        final ctx = PaymentContext.booking(
          customerName: 'Rafi',
          deviceName: 'iPhone 16',
          totalAmount: 250000.0,
          branchId: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              businessProvider.overrideWith(_Wave2TestBiz.new),
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
              theme: AppTheme.lightTheme,
              home: PaymentPage(paymentContext: ctx),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const Key('shift_activation_warning_banner')),
          findsOneWidget,
        );

        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();

        final processBtn = tester.widget<ElevatedButton>(
          find.byKey(const Key('cash_sheet_process_button')),
        );
        expect(processBtn.onPressed, isNull);
      },
    );
  });
}

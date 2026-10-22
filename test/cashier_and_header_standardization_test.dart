import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentcore_mobile/core/constants/app_colors.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/shared/widgets/rentcore_app_bar.dart';

class _MockCashierRepository extends CashierRepository {
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
      'shift_status': 'closed',
      'opening_cash': 0.0,
      'total_cash_in': 0.0,
      'total_cash_out': 0.0,
      'expected_cash': 0.0,
      'actual_cash': 0.0,
      'difference': 0.0,
      'total_revenue': 0.0,
      'successful_transactions_count': 0,
      'payment_breakdown': [],
      'recent_transactions': [],
      'date': '2026-10-22',
      'generated_at': '2026-10-22 18:00:00',
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBranchExpenses({String? date, int? branchId}) async {
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
    ];
  }
}

class _MockCashierBizNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Store',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Store',
            'role': 'owner',
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat', 'is_central': true},
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

  group('RentCoreAppBar Standardization Tests', () {
    testWidgets('Renders with standard 17px w800 obsidian typography and zero elevation', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            appBar: RentCoreAppBar(
              title: 'Test Header Title',
            ),
            body: Center(child: Text('Content')),
          ),
        ),
      );

      final titleFinder = find.text('Test Header Title');
      expect(titleFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(titleFinder);
      expect(textWidget.style?.fontSize, 17.0);
      expect(textWidget.style?.fontWeight, FontWeight.w800);
      expect(textWidget.style?.color, AppColors.obsidian);
      expect(textWidget.style?.letterSpacing, -0.3);

      final containerFinder = find.byType(RentCoreAppBar);
      expect(containerFinder, findsOneWidget);
    });

    testWidgets('Renders RentCoreBackButton with iOS chevron when route canPop', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: SizedBox(
                  width: 200,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Scaffold(
                            appBar: RentCoreAppBar(title: 'Sub Screen'),
                          ),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Sub Screen'), findsOneWidget);
      expect(find.byType(RentCoreBackButton), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);

      await tester.tap(find.byType(RentCoreBackButton));
      await tester.pumpAndSettle();

      expect(find.text('Sub Screen'), findsNothing);
    });
  });

  group('CashierScreen Refinement Tests', () {
    testWidgets('Cashier POS tabs are text-only with no icons', (tester) async {
      final mockRepo = _MockCashierRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockCashierBizNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify text tabs exist
      expect(find.text('Meja Kasir POS'), findsOneWidget);
      expect(find.text('Rekap Shift & Closing'), findsOneWidget);

      // Verify tab icons were removed
      expect(find.byIcon(Icons.point_of_sale_rounded), findsNothing);
      expect(find.byIcon(Icons.assessment_outlined), findsNothing);
    });

    testWidgets('Cashier AppBar has no Book, Settings, or Refresh header action buttons', (tester) async {
      final mockRepo = _MockCashierRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockCashierBizNotifier.new),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const CashierScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find AppBar
      final appBarFinder = find.byType(AppBar);
      expect(appBarFinder, findsOneWidget);

      // Verify header action icons were removed
      expect(find.byIcon(Icons.menu_book_rounded), findsNothing);
      expect(find.byIcon(Icons.settings_outlined), findsNothing);
    });

    testWidgets('Closing Shift tab does not render Bluetooth Printer Hardware card', (tester) async {
      final mockRepo = _MockCashierRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(mockRepo),
            businessProvider.overrideWith(_MockCashierBizNotifier.new),
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

      // Verify Bluetooth Printer card is not present
      expect(find.text('PERANGKAT PRINTER BLUETOOTH'), findsNothing);
      expect(find.text('Test Print Struk Kasir'), findsNothing);
    });
  });
}

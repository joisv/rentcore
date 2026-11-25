import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/widgets/skeleton_loading.dart';
import 'package:sewakasir/features/home/presentation/home_screen.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:sewakasir/features/bookings/presentation/bookings_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/cashier/presentation/cashier_screen.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:sewakasir/features/organization/presentation/store_profile_screen.dart';
import 'package:sewakasir/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Skeleton Primitives & Visual Spec Tests', () {
    testWidgets('SkeletonBox renders with correct defaults and pulse color', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonPulseWrapper(
              child: SkeletonBox(
                width: 100,
                height: 20,
                borderRadius: 8,
              ),
            ),
          ),
        ),
      );

      final boxFinder = find.byType(SkeletonBox);
      expect(boxFinder, findsOneWidget);

      final container = tester.widget<Container>(find.descendant(
        of: boxFinder,
        matching: find.byType(Container),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
      // Initial color starts at #EEEEEE (Colors.grey.shade200)
      expect(decoration.color, const Color(0xFFEEEEEE));

      // Advance animation halfway (600ms of 1200ms)
      await tester.pump(const Duration(milliseconds: 600));
      final containerMid = tester.widget<Container>(find.descendant(
        of: boxFinder,
        matching: find.byType(Container),
      ));
      final decorationMid = containerMid.decoration as BoxDecoration;
      // Pulse color transitions towards #F5F5F5 (Colors.grey.shade100)
      expect(decorationMid.color, isNot(const Color(0xFFEEEEEE)));
    });

    testWidgets('SkeletonCard renders with 12dp border radius and grey.shade200 border', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      final cardFinder = find.byType(SkeletonCard);
      expect(cardFinder, findsOneWidget);

      final container = tester.widget<Container>(find.descendant(
        of: cardFinder,
        matching: find.byType(Container),
      ));
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(12));
      expect(decoration.color, Colors.white);
      expect(decoration.border?.top.color, const Color(0xFFEEEEEE));
    });
  });

  group('Composite Skeletons Zero RenderFlex Overflow Tests', () {
    testWidgets('DashboardSummaryGridSkeleton renders 4 cards with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonPulseWrapper(
              child: SingleChildScrollView(
                child: DashboardSummaryGridSkeleton(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets('RentalQueueListSkeleton renders 5 booking cards with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SkeletonPulseWrapper(
              child: RentalQueueListSkeleton(count: 5),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(BookingCardSkeleton), findsNWidgets(5));
    });

    testWidgets('PhysicalUnitsTabSkeleton renders 5 compact unit cards with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PhysicalUnitsTabSkeleton(count: 5),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonCard), findsNWidgets(5));
    });

    testWidgets('CatalogTabSkeleton renders 4 catalog cards with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CatalogTabSkeleton(count: 4),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SkeletonCard), findsNWidgets(4));
    });

    testWidgets('ActiveShiftSkeleton and ShiftHistoryTabSkeleton render with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  ActiveShiftSkeleton(),
                  SizedBox(height: 16),
                  ShiftHistoryTabSkeleton(count: 4),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ActiveShiftSkeleton), findsOneWidget);
      expect(find.byType(ShiftHistoryTabSkeleton), findsOneWidget);
    });

    testWidgets('SettingsGroupSkeleton and DetailViewSkeleton render with no overflow', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: 300, child: SettingsGroupSkeleton(groupCount: 2, itemsPerGroup: 3)),
                  SizedBox(height: 400, child: DetailViewSkeleton(rowCount: 6)),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsGroupSkeleton), findsOneWidget);
      expect(find.byType(DetailViewSkeleton), findsOneWidget);
    });
  });

  group('Primary Screen Skeleton Loading Integration Tests', () {
    testWidgets('HomeScreen displays DashboardSkeletonView when KPI is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardKpiProvider.overrideWith((ref) => Completer<Map<String, dynamic>>().future),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DashboardSkeletonView), findsOneWidget);
      expect(find.byType(DashboardSummaryGridSkeleton), findsOneWidget);
      // No CircularProgressIndicator on initial empty load!
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('BookingsScreen displays RentalQueueListSkeleton when bookings list is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingsListProvider.overrideWith((ref) => Completer<List<Map<String, dynamic>>>().future),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(RentalQueueListSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('InventoryScreen displays PhysicalUnitsTabSkeleton when units are loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(const BusinessState(
              activeBusinessId: 101,
              businesses: [{'id': 101, 'name': 'Rentcore Test'}],
            ))),
            categoriesProvider.overrideWith((ref) => Future.value(<Map<String, dynamic>>[])),
            inventoryListProvider.overrideWith((ref) => Completer<List<Map<String, dynamic>>>().future),
            productsProvider.overrideWith((ref) => Completer<List<Map<String, dynamic>>>().future),
          ],
          child: const MaterialApp(
            home: InventoryScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(PhysicalUnitsTabSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('CashierScreen displays ActiveShiftSkeleton when closing summary is loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            closingSummaryProvider.overrideWith((ref) => Completer<Map<String, dynamic>>().future),
            currentShiftProvider.overrideWith((ref) => Completer<Map<String, dynamic>>().future),
            shiftHistoryProvider.overrideWith((ref) => Completer<List<Map<String, dynamic>>>().future),
          ],
          child: const MaterialApp(
            home: CashierScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(ActiveShiftSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('PaymentMethodSettingsScreen displays SettingsGroupSkeleton when settings are loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            paymentSettingsProvider.overrideWith((ref, branchId) => Completer<Map<String, dynamic>>().future),
          ],
          child: const MaterialApp(
            home: PaymentMethodSettingsScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsGroupSkeleton), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('StoreProfileScreen displays SettingsGroupSkeleton when initializing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(const BusinessState(
              isLoading: true,
              activeBusinessId: null,
              businesses: [],
            ))),
          ],
          child: const MaterialApp(
            home: StoreProfileScreen(),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsGroupSkeleton), findsOneWidget);
    });

    testWidgets('PosTransactionDetailSheet displays DetailViewSkeleton when booking is empty and loading', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingDetailProvider.overrideWith((ref, bookingId) => Completer<Map<String, dynamic>>().future),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PosTransactionDetailSheet(booking: {}),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(DetailViewSkeleton), findsOneWidget);
    });
  });
}

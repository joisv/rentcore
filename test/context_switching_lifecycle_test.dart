import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/shared/widgets/business_selector_sheet.dart';

class _FakeAuthRepository extends AuthRepository {
  final Map<String, dynamic> storedContext = {};

  @override
  Future<void> setActiveContext({
    required int businessId,
    required String businessName,
    int? branchId,
    String? branchName,
  }) async {
    storedContext['active_business_id'] = businessId;
    storedContext['active_business_name'] = businessName;
    storedContext['active_branch_id'] = branchId;
    storedContext['branch_name'] = branchName;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('active_business_id', businessId);
    await prefs.setString('active_business_name', businessName);
    if (branchId != null) {
      await prefs.setInt('active_branch_id', branchId);
    } else {
      await prefs.remove('active_branch_id');
    }
    if (branchName != null) {
      await prefs.setString('branch_name', branchName);
    } else {
      await prefs.remove('branch_name');
    }
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    return [
      {
        'id': 1,
        'name': 'Employer Rental A',
        'role': 'staff',
        'city': 'Denpasar',
        'branches': [
          {'id': 10, 'name': 'Cabang Sanur', 'code': 'SNR', 'is_central': false},
        ],
      },
      {
        'id': 2,
        'name': 'My Independent Rental B',
        'role': 'owner',
        'city': 'Badung',
        'branches': [
          {'id': 20, 'name': 'Pusat Kuta', 'code': 'KTA', 'is_central': true},
          {'id': 21, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': false},
        ],
      },
    ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeAuthRepository fakeAuthRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    fakeAuthRepo = _FakeAuthRepository();
  });

  group('Context Switching & Membership Lifecycle Tests', () {
    test('selectContext atomically persists business and branch without disk/memory race condition', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      final businesses = await fakeAuthRepo.fetchBusinesses();
      final employerBiz = businesses[0];
      final ownedBiz = businesses[1];

      // 1. Initial State: User is in Owned Business 2, Branch 20
      await container.read(businessProvider.notifier).selectContext(
        business: ownedBiz,
        branch: ownedBiz['branches'][0],
      );

      var state = container.read(businessProvider);
      expect(state.activeBusinessId, 2);
      expect(state.activeBranchId, 20);

      var prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('active_business_id'), 2);
      expect(prefs.getInt('active_branch_id'), 20);

      // 2. Switch context back to Employer Business 1, Branch 10
      await container.read(businessProvider.notifier).selectContext(
        business: employerBiz,
        branch: employerBiz['branches'][0],
      );

      state = container.read(businessProvider);
      expect(state.activeBusinessId, 1);
      expect(state.activeBranchId, 10);

      prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('active_business_id'), 1);
      expect(prefs.getInt('active_branch_id'), 10);
    });

    test('selectContext with consolidated mode clears branchId', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      final businesses = await fakeAuthRepo.fetchBusinesses();
      final ownedBiz = businesses[1];

      await container.read(businessProvider.notifier).selectContext(
        business: ownedBiz,
        isConsolidated: true,
      );

      final state = container.read(businessProvider);
      expect(state.activeBusinessId, 2);
      expect(state.activeBranchId, isNull);
      expect(state.isConsolidated, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('active_business_id'), 2);
      expect(prefs.getInt('active_branch_id'), isNull);
    });

    test('Switching active business automatically resets stale provider filters', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      final businesses = await fakeAuthRepo.fetchBusinesses();
      final employerBiz = businesses[0];
      final ownedBiz = businesses[1];

      // Start in Owned Business 2
      await container.read(businessProvider.notifier).selectContext(
        business: ownedBiz,
        branch: ownedBiz['branches'][0],
      );

      // User sets filters while in Owned Business 2
      container.read(posFilterBranchIdProvider.notifier).setBranchId(21);
      container.read(selectedAssetCategoryFilterProvider.notifier).setFilter(99);
      container.read(selectedAssetStatusFilterProvider.notifier).setFilter('maintenance');
      container.read(assetSearchQueryProvider.notifier).setSearch('MacBook Pro');
      container.read(bookingSearchQueryProvider.notifier).setQuery('RENT-2026');

      expect(container.read(posFilterBranchIdProvider), 21);
      expect(container.read(selectedAssetCategoryFilterProvider), 99);
      expect(container.read(selectedAssetStatusFilterProvider), 'maintenance');
      expect(container.read(assetSearchQueryProvider), 'MacBook Pro');
      expect(container.read(bookingSearchQueryProvider), 'RENT-2026');

      // Now switch to Employer Business 1
      await container.read(businessProvider.notifier).selectContext(
        business: employerBiz,
        branch: employerBiz['branches'][0],
      );

      // Verify that all filters were automatically reset to avoid cross-tenant contamination
      expect(container.read(posFilterBranchIdProvider), isNull);
      expect(container.read(selectedAssetCategoryFilterProvider), isNull);
      expect(container.read(selectedAssetStatusFilterProvider), isNull);
      expect(container.read(assetSearchQueryProvider), '');
      expect(container.read(bookingSearchQueryProvider), '');
    });

    testWidgets('BusinessSelectorSheet correctly triggers atomic selectContext on branch tap', (tester) async {
      final businesses = await fakeAuthRepo.fetchBusinesses();
      final employerBiz = businesses[0];
      final ownedBiz = businesses[1];

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      // Preload context in Owned Business 2
      await container.read(businessProvider.notifier).loadInitialContext(
        preloadedBusinesses: businesses,
      );
      await container.read(businessProvider.notifier).selectContext(
        business: ownedBiz,
        branch: ownedBiz['branches'][0],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => BusinessSelectorSheet.show(context),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap button to open sheet
      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('PILIH USAHA RENTAL AKTIF'), findsOneWidget);
      expect(find.text('Employer Rental A'), findsOneWidget);
      expect(find.text('My Independent Rental B'), findsOneWidget);

      // Tap Employer Rental A expansion tile to reveal branches
      await tester.tap(find.text('Employer Rental A'));
      await tester.pumpAndSettle();

      // Tap Cabang Sanur (Employer's Branch)
      expect(find.text('Cabang Sanur'), findsOneWidget);
      await tester.tap(find.text('Cabang Sanur'));
      await tester.pumpAndSettle();

      // Verify sheet is closed
      expect(find.text('PILIH USAHA RENTAL AKTIF'), findsNothing);

      // Verify state was atomically switched to Employer Business 1 and Branch 10
      final state = container.read(businessProvider);
      expect(state.activeBusinessId, 1);
      expect(state.activeBranchId, 10);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('active_business_id'), 1);
      expect(prefs.getInt('active_branch_id'), 10);
    });
  });
}

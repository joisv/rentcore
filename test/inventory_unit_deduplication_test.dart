import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/core/models/paginated_result.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';

class _DuplicateMockAssetRepository extends AssetRepository {
  final List<Map<String, dynamic>> rawUnits;

  _DuplicateMockAssetRepository(this.rawUnits);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Smartphones', 'slug': 'smartphones'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async => [
    {
      'id': 10,
      'name': 'iPhone 15 Pro 128GB',
      'brand': 'Apple',
      'category': {'id': 1, 'name': 'Smartphones'},
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async => rawUnits;

  @override
  Future<PaginatedResult<Map<String, dynamic>>> fetchAssetsPaginated({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
    int page = 1,
    int perPage = 20,
  }) async {
    return PaginatedResult(
      items: rawUnits,
      currentPage: page,
      lastPage: 1,
      total: rawUnits.length,
      perPage: perPage,
      hasMore: false,
    );
  }
}

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

  final mockBusiness = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'Rentcore Test Rental',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
    businesses: [
      {'id': 1, 'name': 'Rentcore Test Rental'},
    ],
  );

  final duplicateUnitsList = [
    {
      'id': 101,
      'asset_code': 'IP15P-MTR-001',
      'serial_number': 'SN111111',
      'status': 'ready',
      'condition_grade': 'A',
      'battery_health': 98,
      'model': {
        'id': 10,
        'name': 'iPhone 15 Pro 128GB',
        'category': {'id': 1, 'name': 'Smartphones'},
      },
    },
    // Duplicate of unit 101 (e.g., from unconstrained join)
    {
      'id': 101,
      'asset_code': 'IP15P-MTR-001',
      'serial_number': 'SN111111',
      'status': 'ready',
      'condition_grade': 'A',
      'battery_health': 98,
      'model': {
        'id': 10,
        'name': 'iPhone 15 Pro 128GB',
        'category': {'id': 1, 'name': 'Smartphones'},
      },
    },
    {
      'id': 102,
      'asset_code': 'IP15P-MTR-002',
      'serial_number': 'SN222222',
      'status': 'rented',
      'condition_grade': 'B',
      'battery_health': 92,
      'model': {
        'id': 10,
        'name': 'iPhone 15 Pro 128GB',
        'category': {'id': 1, 'name': 'Smartphones'},
      },
    },
  ];

  test('PhysicalUnitsNotifier loadUnits replaces state and deduplicates items', () async {
    final mockRepo = _DuplicateMockAssetRepository(duplicateUnitsList);
    final container = ProviderContainer(
      overrides: [
        assetRepositoryProvider.overrideWithValue(mockRepo),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(physicalUnitsProvider.notifier);

    // Initial state is empty
    expect(container.read(physicalUnitsProvider).units, isEmpty);

    // Call loadUnits
    await notifier.loadUnits();

    final state = container.read(physicalUnitsProvider);
    expect(state.isLoading, isFalse);
    expect(state.error, isNull);
    // Even though raw list has 3 items (with duplicate ID 101), state has exactly 2 unique items
    expect(state.units.length, equals(2));
    expect(state.units.map((u) => u['id']).toList(), equals([101, 102]));

    // Calling loadUnits again replaces the state (does not append to state.units)
    await notifier.loadUnits();
    expect(container.read(physicalUnitsProvider).units.length, equals(2));
  });

  testWidgets('InventoryScreen renders each physical unit exactly once on initial load', (tester) async {
    final mockRepo = _DuplicateMockAssetRepository(duplicateUnitsList);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          assetRepositoryProvider.overrideWithValue(mockRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(mockBusiness),
          ),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          home: const InventoryScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify unified Daftar Aset screen is rendered
    expect(find.text('Daftar Aset'), findsOneWidget);
    expect(find.text('Unit Fisik (Inventaris)'), findsNothing);

    // Verify unit 101 (IP15P-MTR-001) is rendered EXACTLY once, not duplicated
    expect(find.text('IP15P-MTR-001'), findsOneWidget);

    // Verify unit 102 (IP15P-MTR-002) is rendered EXACTLY once
    expect(find.text('IP15P-MTR-002'), findsOneWidget);
  });
}

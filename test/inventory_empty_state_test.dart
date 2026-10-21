import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _ConfigurableAssetRepository extends AssetRepository {
  List<Map<String, dynamic>> assetsToReturn;
  List<Map<String, dynamic>> productsToReturn;
  List<Map<String, dynamic>> modelsToReturn;
  List<Map<String, dynamic>> categoriesToReturn;

  _ConfigurableAssetRepository({
    this.assetsToReturn = const [],
    this.productsToReturn = const [],
    this.modelsToReturn = const [],
    this.categoriesToReturn = const [],
  });

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => categoriesToReturn;

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async => modelsToReturn;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async {
    if (search != null && search.isNotEmpty) {
      return productsToReturn.where((p) => (p['name'] as String).toLowerCase().contains(search.toLowerCase())).toList();
    }
    if (categoryId != null) {
      return productsToReturn.where((p) => p['category']?['id'] == categoryId).toList();
    }
    return productsToReturn;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async {
    var result = List<Map<String, dynamic>>.from(assetsToReturn);
    if (search != null && search.isNotEmpty) {
      result = result.where((a) {
        final code = (a['asset_code'] as String? ?? '').toLowerCase();
        final sn = (a['serial_number'] as String? ?? '').toLowerCase();
        final modelName = (a['model']?['name'] as String? ?? '').toLowerCase();
        final s = search.toLowerCase();
        return code.contains(s) || sn.contains(s) || modelName.contains(s);
      }).toList();
    }
    if (status != null && status.isNotEmpty) {
      result = result.where((a) => a['status'] == status).toList();
    }
    if (categoryId != null) {
      result = result.where((a) => a['model']?['category']?['id'] == categoryId).toList();
    }
    return result;
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

  final baseBusinessState = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'Alpha Rental Store',
    activeBranchId: 101,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {'id': 1, 'name': 'Alpha Rental Store'}
    ],
  );

  Widget createTestWidget({
    required _ConfigurableAssetRepository repo,
    int initialTabIndex = 0,
    String? initialStatusFilter,
  }) {
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(() => _TestBusinessNotifier(baseBusinessState)),
        assetRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: InventoryScreen(
          initialTabIndex: initialTabIndex,
          initialStatusFilter: initialStatusFilter,
        ),
      ),
    );
  }

  group('Inventory Empty State Tests', () {
    testWidgets('Empty Physical Units tab displays context-appropriate empty state with actions', (tester) async {
      final repo = _ConfigurableAssetRepository(
        assetsToReturn: [],
        productsToReturn: [],
        modelsToReturn: [],
        categoriesToReturn: [
          {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
        ],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 0));
      await tester.pumpAndSettle();

      // Should show the True Empty State for Units
      expect(find.text('Belum Ada Unit Inventaris'), findsOneWidget);
      expect(find.textContaining('Bisnis rental Anda belum memiliki unit fisik terdaftar'), findsOneWidget);
      expect(find.text('Registrasi Unit Baru'), findsOneWidget);
      expect(find.text('Tambah Model & Tarif'), findsOneWidget);
    });

    testWidgets('Search query with no matching units displays search empty state and Reset Pencarian button', (tester) async {
      final repo = _ConfigurableAssetRepository(
        assetsToReturn: [
          {
            'id': 50,
            'asset_code': 'CAM-001',
            'serial_number': 'SN-CAM-1',
            'status': 'ready',
            'condition_grade': 'A',
            'battery_health': null,
            'model': {
              'id': 10,
              'name': 'Sony Alpha A7 IV',
              'category': {'id': 1, 'name': 'Kamera'},
            },
          },
        ],
        categoriesToReturn: [],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 0));
      await tester.pumpAndSettle();

      // Initially, asset is found
      expect(find.text('CAM-001'), findsOneWidget);

      // Enter search query that doesn't match
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'NonExistentDevice');
      await tester.pumpAndSettle();

      // Now should show search empty state
      expect(find.text('Tidak Ada Unit Ditemukan'), findsOneWidget);
      expect(find.textContaining('Tidak ada unit inventaris yang cocok dengan pencarian "NonExistentDevice"'), findsOneWidget);
      expect(find.text('Reset Pencarian'), findsOneWidget);

      // Tap Reset Pencarian
      await tester.tap(find.text('Reset Pencarian'));
      await tester.pumpAndSettle();

      // Original asset restored
      expect(find.text('CAM-001'), findsOneWidget);
    });

    testWidgets('Status filter with no matching units displays filter empty state and Reset Semua Filter button', (tester) async {
      final repo = _ConfigurableAssetRepository(
        assetsToReturn: [
          {
            'id': 50,
            'asset_code': 'CAM-001',
            'serial_number': 'SN-CAM-1',
            'status': 'ready',
            'condition_grade': 'A',
            'battery_health': null,
            'model': {
              'id': 10,
              'name': 'Sony Alpha A7 IV',
              'category': {'id': 1, 'name': 'Kamera'},
            },
          },
        ],
        categoriesToReturn: [],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 0));
      await tester.pumpAndSettle();

      expect(find.text('CAM-001'), findsOneWidget);

      // Tap 'Sedang Sewa' filter chip (which has 0 units)
      await tester.tap(find.text('Sedang Sewa'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Unit Sesuai Filter'), findsOneWidget);
      expect(find.textContaining('Tidak ditemukan unit inventaris dengan status atau kategori yang dipilih'), findsOneWidget);
      expect(find.text('Reset Semua Filter'), findsOneWidget);

      // Tap Reset Semua Filter
      await tester.tap(find.text('Reset Semua Filter'));
      await tester.pumpAndSettle();

      // Original asset restored
      expect(find.text('CAM-001'), findsOneWidget);
    });

    testWidgets('Empty Catalog tab displays context-appropriate empty state with Add Model button', (tester) async {
      final repo = _ConfigurableAssetRepository(
        assetsToReturn: [],
        productsToReturn: [],
        modelsToReturn: [],
        categoriesToReturn: [],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Katalog Produk'), findsOneWidget);
      expect(find.textContaining('Bisnis rental Anda belum memiliki katalog model atau paket tarif sewa'), findsOneWidget);
      expect(find.text('+ Tambah Model & Tarif Baru'), findsOneWidget);
    });

    testWidgets('Catalog product with 0 units displays Belum Ada Unit Fisik and + Daftarkan Unit button', (tester) async {
      final repo = _ConfigurableAssetRepository(
        productsToReturn: [
          {
            'id': 10,
            'name': 'PlayStation 5 Slim',
            'brand': 'Sony',
            'category': {'id': 3, 'name': 'Konsol Game'},
            'ready_units_count': 0,
            'assets_count': 0,
            'pricing_tiers': [],
          },
        ],
        modelsToReturn: [
          {
            'id': 10,
            'name': 'PlayStation 5 Slim',
            'brand': 'Sony',
            'category': {'id': 3, 'name': 'Konsol Game'},
          },
        ],
        categoriesToReturn: [],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('PlayStation 5 Slim'), findsOneWidget);
      expect(find.text('0 Unit • Belum Ada Unit Fisik'), findsOneWidget);
      expect(find.text('+ Daftarkan Unit'), findsOneWidget);

      // Tapping + Daftarkan Unit opens registration sheet with preselected model
      await tester.tap(find.text('+ Daftarkan Unit'));
      await tester.pumpAndSettle();

      expect(find.text('Registrasi Unit Baru'), findsOneWidget);
      expect(find.textContaining('PlayStation 5 Slim'), findsWidgets);
    });

    testWidgets('Catalog tab search with no matching products displays search empty state and Reset button', (tester) async {
      final repo = _ConfigurableAssetRepository(
        productsToReturn: [
          {
            'id': 10,
            'name': 'MacBook Pro M3 Max',
            'brand': 'Apple',
            'category': {'id': 2, 'name': 'Laptop'},
            'ready_units_count': 1,
            'assets_count': 1,
            'pricing_tiers': [],
          },
        ],
        categoriesToReturn: [],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('MacBook Pro M3 Max'), findsOneWidget);

      // Search for non-existent product
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Drone4K');
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Katalog Ditemukan'), findsOneWidget);
      expect(find.textContaining('Tidak ada model produk yang cocok dengan pencarian "Drone4K"'), findsOneWidget);
      expect(find.text('Reset Pencarian'), findsOneWidget);

      // Tap Reset Pencarian
      await tester.tap(find.text('Reset Pencarian'));
      await tester.pumpAndSettle();

      expect(find.text('MacBook Pro M3 Max'), findsOneWidget);
    });

    testWidgets('Catalog tab category filter with no products displays category empty state', (tester) async {
      final repo = _ConfigurableAssetRepository(
        productsToReturn: [
          {
            'id': 10,
            'name': 'MacBook Pro M3',
            'brand': 'Apple',
            'category': {'id': 2, 'name': 'Laptop'},
            'ready_units_count': 1,
            'assets_count': 1,
            'pricing_tiers': [],
          },
        ],
        categoriesToReturn: [
          {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
          {'id': 2, 'name': 'Laptop', 'slug': 'laptop'},
        ],
      );

      await tester.pumpWidget(createTestWidget(repo: repo, initialTabIndex: 1));
      await tester.pumpAndSettle();

      expect(find.text('MacBook Pro M3'), findsOneWidget);

      // Filter by Kamera (which has 0 products)
      await tester.tap(find.text('Kamera'));
      await tester.pumpAndSettle();

      expect(find.text('Tidak Ada Katalog Dalam Kategori Ini'), findsOneWidget);
      expect(find.textContaining('Belum ada model produk terdaftar untuk kategori yang dipilih'), findsOneWidget);
      expect(find.text('Tampilkan Semua Kategori'), findsOneWidget);

      // Tap Tampilkan Semua Kategori
      await tester.tap(find.text('Tampilkan Semua Kategori'));
      await tester.pumpAndSettle();

      expect(find.text('MacBook Pro M3'), findsOneWidget);
    });

    testWidgets('Loading and error states remain distinct from empty state', (tester) async {
      // Create a widget where inventoryListProvider errors out
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(baseBusinessState)),
            inventoryListProvider.overrideWith((ref) => Future.error('Connection timeout')),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(initialTabIndex: 0),
          ),
        ),
      );
      await tester.pump();

      // Loading or Error state is active, NOT empty state
      expect(find.text('Belum Ada Unit Inventaris'), findsNothing);
      expect(find.text('Tidak Ada Unit Ditemukan'), findsNothing);

      await tester.pumpAndSettle();

      // Should show error view with retry button
      expect(find.textContaining('Gagal memuat inventaris: Connection timeout'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      // Empty state widgets should still not be present
      expect(find.text('Belum Ada Unit Inventaris'), findsNothing);
    });
  });

  group('AssetRepository extractList Resilience Tests', () {
    test('Handles null, empty lists, paginated maps, and unexpected structures safely', () {
      final repo = AssetRepository();

      // Null payload
      expect(repo.extractList(null), isEmpty);

      // Empty list
      expect(repo.extractList([]), isEmpty);

      // Flat list
      final flat = [
        {'id': 1, 'name': 'Unit 1'},
        {'id': 2, 'name': 'Unit 2'},
      ];
      expect(repo.extractList(flat), hasLength(2));

      // Paginated Map with empty data
      final paginatedEmpty = {
        'current_page': 1,
        'data': [],
        'total': 0,
      };
      expect(repo.extractList(paginatedEmpty), isEmpty);

      // Paginated Map with items
      final paginatedItems = {
        'current_page': 1,
        'data': [
          {'id': 10, 'asset_code': 'AST-10'},
        ],
        'total': 1,
      };
      final extracted = repo.extractList(paginatedItems);
      expect(extracted, hasLength(1));
      expect(extracted.first['asset_code'], 'AST-10');

      // Paginated Map with null data
      final paginatedNull = {
        'current_page': 1,
        'data': null,
      };
      expect(repo.extractList(paginatedNull), isEmpty);

      // Unexpected primitive types
      expect(repo.extractList('invalid string'), isEmpty);
      expect(repo.extractList(999), isEmpty);
      expect(repo.extractList(false), isEmpty);
    });
  });
}

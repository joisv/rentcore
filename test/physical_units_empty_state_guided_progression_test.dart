import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/add_product_sheet.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _ConfigurableAssetRepo extends AssetRepository {
  final List<Map<String, dynamic>> assets;
  final List<Map<String, dynamic>> products;
  final List<Map<String, dynamic>> models;
  final List<Map<String, dynamic>> categories;

  _ConfigurableAssetRepo({
    this.assets = const [],
    this.products = const [],
    this.models = const [],
    this.categories = const [],
  });

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => categories;

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      models;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async => products;

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async => assets;
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
    activeBusinessName: 'Rentcore Testing Hub',
    activeBranchId: 10,
    activeBranchName: 'HQ Branch',
    businesses: [
      {'id': 1, 'name': 'Rentcore Testing Hub'},
    ],
  );

  Widget createTestWidget({
    required _ConfigurableAssetRepo repo,
    int initialTabIndex = 0,
  }) {
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(
          () => _TestBusinessNotifier(baseBusinessState),
        ),
        assetRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: InventoryScreen(
          initialTabIndex: initialTabIndex,
        ),
      ),
    );
  }

  group('Physical Units Empty State Guided Progression Tests', () {
    testWidgets(
      'When zero models exist (assetModels.isEmpty): shows single primary CTA, hides secondary unit CTA and hides FAB',
      (tester) async {
        final repo = _ConfigurableAssetRepo(
          assets: [],
          products: [],
          models: [],
          categories: [
            {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
          ],
        );

        await tester.pumpWidget(createTestWidget(repo: repo));
        await tester.pumpAndSettle();

        // 1. Unified tab-free view & concise empty state copy (search bar hidden)
        expect(find.byKey(const Key('inventory_tab_units')), findsNothing);
        expect(find.byKey(const Key('inventory_tab_catalog')), findsNothing);
        expect(find.byKey(const Key('inventory_unified_search_field')), findsNothing);
        expect(find.byKey(const Key('inventory_filter_button')), findsNothing);
        expect(find.text('Belum Ada Inventaris'), findsOneWidget);
        expect(
          find.text('Buat model katalog terlebih dahulu sebelum mendaftarkan unit fisik.'),
          findsOneWidget,
        );

        // 2. Single-numbered hierarchy step cards
        expect(find.text('Model & Tarif'), findsOneWidget);
        expect(
          find.textContaining('Tipe barang dan harga sewa'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('inventory_empty_step_2_title')), findsOneWidget);
        expect(
          find.textContaining('Stok nyata siap sewa lengkap'),
          findsOneWidget,
        );

        // 3. Full-width Primary CTA shows + Buat Model Pertama
        expect(find.text('+ Buat Model Pertama'), findsOneWidget);

        // 4. Secondary button ('Registrasi Unit Baru') & Floating Action Button (+) are HIDDEN
        expect(find.text('Registrasi Unit Baru'), findsNothing);
        expect(find.byKey(const Key('inventory_expandable_main_fab')), findsNothing);

        // 5. Verify icon is inventory_2_outlined
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

        // 6. Tapping primary CTA opens AddProductSheet
        await tester.tap(find.text('+ Buat Model Pertama'));
        await tester.pumpAndSettle();
        expect(find.byType(AddProductSheet), findsOneWidget);
      },
    );

    testWidgets(
      'When models exist but physical units are empty: renders model card with inline empty-unit strip and + Tambah Unit preselects model',
      (tester) async {
        final sampleProducts = [
          {
            'id': 101,
            'name': 'Sony Alpha A7 IV',
            'brand': 'Sony',
            'category': {'id': 1, 'name': 'Kamera'},
            'ready_units_count': 0,
            'assets_count': 0,
            'pricing_tiers': [],
          },
        ];

        final repo = _ConfigurableAssetRepo(
          assets: [],
          products: sampleProducts,
          models: sampleProducts,
          categories: [
            {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
          ],
        );

        await tester.pumpWidget(createTestWidget(repo: repo));
        await tester.pumpAndSettle();

        // 1. Unified card shown with search bar and inline empty unit strip
        expect(find.byKey(const Key('inventory_unified_search_field')), findsOneWidget);
        expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
        expect(find.text('Belum ada unit fisik terdaftar'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, '+ Tambah Unit'), findsOneWidget);
        expect(find.byKey(const Key('inventory_expandable_main_fab')), findsNothing);

        // 2. Tapping + Tambah Unit opens unit registration sheet with Sony Alpha A7 IV pre-selected
        await tester.tap(find.widgetWithText(ElevatedButton, '+ Tambah Unit'));
        await tester.pumpAndSettle();

        expect(find.text('Registrasi Unit Baru'), findsOneWidget);
        expect(find.textContaining('Sony Alpha A7 IV'), findsWidgets);
      },
    );
  });
}

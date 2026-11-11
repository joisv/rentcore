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

        // 1. Heading and explanation
        expect(find.text('Mulai Catat Inventaris Rental Anda'), findsOneWidget);
        expect(
          find.text('Sebelum mendaftarkan unit fisik, pahami hierarki inventaris rental berikut:'),
          findsOneWidget,
        );

        // 2. Hierarchy concept cards
        expect(find.text('1. Model / Katalog'), findsOneWidget);
        expect(
          find.textContaining('Tipe barang dan tarif sewanya'),
          findsOneWidget,
        );
        expect(find.text('2. Unit Fisik'), findsOneWidget);
        expect(
          find.textContaining('Barang nyata yang diserahkan ke pelanggan'),
          findsOneWidget,
        );

        // 3. Primary CTA has clean label with single '+' without icon duplication
        expect(find.text('+ Buat Model Pertama'), findsOneWidget);

        // 4. Secondary button ('Registrasi Unit Baru') is HIDDEN because no parent models exist
        expect(find.text('Registrasi Unit Baru'), findsNothing);

        // 5. Floating Action Button (+) is HIDDEN to eliminate bottom-right clutter
        expect(find.byKey(const Key('inventory_expandable_main_fab')), findsNothing);

        // 6. Verify icon is inventory_2_outlined
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);

        // 7. Tapping primary CTA opens AddProductSheet
        await tester.tap(find.text('+ Buat Model Pertama'));
        await tester.pumpAndSettle();
        expect(find.byType(AddProductSheet), findsOneWidget);
      },
    );

    testWidgets(
      'When models exist but physical units are empty: prompts unit registration, shows secondary model CTA and shows FAB',
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

        // 1. Heading and guidance for model-ready state
        expect(find.text('Model Sudah Tersedia'), findsOneWidget);
        expect(
          find.text('Model sudah tersedia. Daftarkan unit fisik pertama Anda.'),
          findsOneWidget,
        );

        // 2. Action buttons: Primary is + Registrasi Unit Pertama, Secondary is + Buat Model Baru
        expect(find.text('+ Registrasi Unit Pertama'), findsOneWidget);
        expect(find.text('+ Buat Model Baru'), findsOneWidget);

        // 3. Floating Action Button IS visible because models exist
        expect(find.byKey(const Key('inventory_expandable_main_fab')), findsOneWidget);

        // 4. Tapping + Registrasi Unit Pertama opens unit registration sheet
        await tester.tap(find.text('+ Registrasi Unit Pertama'));
        await tester.pumpAndSettle();

        // Sheet title is 'Registrasi Unit Baru'
        expect(find.text('Registrasi Unit Baru'), findsOneWidget);

        // Dismiss sheet
        await tester.tap(find.byIcon(Icons.close_rounded));
        await tester.pumpAndSettle();

        // 5. Tapping + Buat Model Baru opens AddProductSheet
        await tester.tap(find.text('+ Buat Model Baru'));
        await tester.pumpAndSettle();
        expect(find.byType(AddProductSheet), findsOneWidget);
      },
    );
  });
}

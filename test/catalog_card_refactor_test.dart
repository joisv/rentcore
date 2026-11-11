import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _FakeAssetRepository extends AssetRepository {
  final List<Map<String, dynamic>> products;

  _FakeAssetRepository(this.products);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
    {'id': 2, 'name': 'Smartphone', 'slug': 'smartphones'},
    {'id': 3, 'name': 'Aksesoris', 'slug': 'aksesoris'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      products;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async => products;
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sampleProducts = [
    {
      'id': 1,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'category': {'id': 1, 'name': 'Kamera'},
      'color': 'Hitam',
      'storage_capacity': null,
      'ready_units_count': 3,
      'assets_count': 5,
      'pricing_tiers': [
        {
          'id': 101,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 250000.0,
        },
      ],
    },
    {
      'id': 2,
      'name': 'iPhone 15 Pro Max',
      'brand': 'Apple',
      'category': {'id': 2, 'name': 'Smartphone'},
      'color': 'Natural Titanium',
      'storage_capacity': '128', // Test numeric specification -> 128 GB
      'ready_units_count': 1,
      'assets_count': 1,
      'pricing_tiers': [
        {
          'id': 201,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 175000.0,
        },
      ],
    },
    {
      'id': 3,
      'name': 'Anker PowerCore 10K',
      'brand': 'Anker',
      'category': {'id': 3, 'name': 'Aksesoris'},
      'color': 'Putih',
      'storage_capacity':
          '10000 MahGB', // Test bug concatenation fix -> 10.000 mAh
      'ready_units_count': 0,
      'assets_count': 0,
      'pricing_tiers': [
        {
          'id': 301,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 35000.0,
        },
      ],
    },
    {
      'id': 4,
      'name': 'iPad Pro M4 11 Inch',
      'brand': 'Apple',
      'category': {'id': 2, 'name': 'Tablet'},
      'color': 'Space Black',
      'storage_capacity': '1TB', // Test TB specification -> 1 TB
      'ready_units_count': 2,
      'assets_count': 4,
      'pricing_tiers': [
        {
          'id': 401,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 300000.0,
        },
      ],
    },
  ];

  Widget buildCatalogScreen({required List<Map<String, dynamic>> products}) {
    final repo = _FakeAssetRepository(products);
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(
          () => _TestBusinessNotifier(
            BusinessState(
              activeBusinessId: 1,
              activeBusinessName: 'RentCore Store',
              businesses: [
                {'id': 1, 'name': 'RentCore Store', 'role': 'owner'},
              ],
            ),
          ),
        ),
        assetRepositoryProvider.overrideWithValue(repo),
        inventoryListProvider.overrideWith((ref) => Future.value([])),
        productsProvider.overrideWith((ref) => Future.value(products)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const InventoryScreen(initialTabIndex: 1),
      ),
    );
  }

  group('Catalog Card Refactor UI & Layout Tests', () {
    testWidgets(
      'renders daily rate at top-right aligned with title and compact action row',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
        await tester.pumpAndSettle();

        // 1. Verify Top-Right Daily Rate
        expect(find.text('Rp 250.000 / hari'), findsOneWidget);
        expect(find.text('Rp 175.000 / hari'), findsOneWidget);
        expect(find.text('Rp 35.000 / hari'), findsOneWidget);
        expect(find.text('Rp 300.000 / hari'), findsOneWidget);

        // 2. Verify Single Action Row: Edit Tarif (left) and + Tambah Unit (right)
        expect(find.text('Edit Tarif'), findsNWidgets(4));
        expect(find.text('+ Tambah Unit'), findsNWidgets(4));

        // 3. Verify old stacked buttons are removed
        expect(find.text('+ Registrasi Unit Tipe Ini'), findsNothing);
        expect(find.text('Edit Model & Tarif'), findsNothing);
        expect(find.text('+ Daftarkan Unit'), findsNothing);
      },
    );

    testWidgets('formats stock availability badge as clean compact pill', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
      await tester.pumpAndSettle();

      // Clean pills
      expect(find.text('3 Siap Sewa • 5 Total'), findsOneWidget);
      expect(find.text('1 Siap Sewa • 1 Total'), findsOneWidget);
      expect(find.text('0 Siap Sewa • 0 Total'), findsOneWidget);
      expect(find.text('2 Siap Sewa • 4 Total'), findsOneWidget);

      // Old "Total Unit" text is removed
      expect(find.text('3 Siap Sewa • 5 Total Unit'), findsNothing);
    });

    testWidgets(
      'fixes specification string bug and formats metadata correctly',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
        await tester.pumpAndSettle();

        // Anker PowerCore: "10000 MahGB" -> "10.000 mAh"
        expect(
          find.text('Anker • Aksesoris • Putih / 10.000 mAh'),
          findsOneWidget,
        );
        expect(find.textContaining('10000 MahGB'), findsNothing);

        // iPhone 15 Pro Max: "128" -> "128 GB"
        expect(
          find.text('Apple • Smartphone • Natural Titanium / 128 GB'),
          findsOneWidget,
        );

        // iPad Pro M4: "1TB" -> "1 TB"
        expect(
          find.text('Apple • Tablet • Space Black / 1 TB'),
          findsOneWidget,
        );

        // Sony: no spec, only color
        expect(find.text('Sony • Kamera • Hitam'), findsOneWidget);
      },
    );

    testWidgets(
      'renders neat rounded avatar with first letter instead of generic phone icon',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
        await tester.pumpAndSettle();

        // Avatars with initial letters
        expect(find.text('S'), findsOneWidget); // Sony
        expect(find.text('I'), findsNWidgets(2)); // iPhone & iPad
        expect(find.text('A'), findsOneWidget); // Anker

        // Static style icon is removed
        expect(find.byIcon(Icons.style_rounded), findsNothing);
      },
    );

    testWidgets('bottom safe area padding is at least 96.0 on ListView', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
      await tester.pumpAndSettle();

      final listViews = tester.widgetList<ListView>(find.byType(ListView));
      final catalogList = listViews.firstWhere(
        (lv) => lv.padding != null && (lv.padding as EdgeInsets).bottom >= 96.0,
      );
      final padding = catalogList.padding as EdgeInsets;
      expect(padding.bottom, 96.0);
    });

    testWidgets(
      'renders cards across narrow (320px) screens with zero RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
        expect(find.text('Rp 250.000 / hari'), findsOneWidget);
        expect(find.text('Edit Tarif'), findsWidgets);
        expect(find.text('+ Tambah Unit'), findsWidgets);
      },
    );

    testWidgets('tapping Edit Tarif opens AddProductSheet for editing', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Tarif').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Model & Tarif Sewa'), findsOneWidget);
    });

    testWidgets(
      'tapping + Tambah Unit opens AddAssetSheet with preselected model',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildCatalogScreen(products: sampleProducts));
        await tester.pumpAndSettle();

        await tester.tap(find.text('+ Tambah Unit').first);
        await tester.pumpAndSettle();

        expect(find.text('Registrasi Unit Baru'), findsOneWidget);
      },
    );
  });
}

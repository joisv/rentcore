import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';

class _FakeAssetRepositoryForPolish extends AssetRepository {
  final List<Map<String, dynamic>> products;
  _FakeAssetRepositoryForPolish(this.products);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Smartphone'},
        {'id': 2, 'name': 'Kamera'},
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async {
    return products;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async =>
      [];
}

class _TestBusinessNotifierForPolish extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifierForPolish(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  final sampleProducts = [
    {
      'id': 1,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'category': {'id': 2, 'name': 'Kamera'},
      'color': 'hitam pekat', // Test lowercase multi-word -> should format to 'Hitam Pekat'
      'storage_capacity': 'standar', // Test non-numeric spec -> should format to 'Standar'
      'ready_units_count': 2,
      'assets_count': 3,
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
      'name': 'iPhone 15 Pro',
      'brand': 'Apple',
      'category': {'id': 1, 'name': 'Smartphone'},
      'color': 'hijau', // Test single lowercase word -> should format to 'Hijau'
      'storage_capacity': '256', // Test numeric capacity -> 256 GB
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
  ];

  Widget buildTestApp() {
    final repo = _FakeAssetRepositoryForPolish(sampleProducts);
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(
          () => _TestBusinessNotifierForPolish(
            const BusinessState(
              activeBusinessId: 1,
              activeBusinessName: 'Rentcore Store',
              businesses: [
                {'id': 1, 'name': 'Rentcore Store', 'role': 'owner'},
              ],
            ),
          ),
        ),
        assetRepositoryProvider.overrideWithValue(repo),
        inventoryListProvider.overrideWith((ref) => Future.value([])),
        productsProvider.overrideWith((ref) => Future.value(sampleProducts)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: const InventoryScreen(initialTabIndex: 1), // Start directly on Katalog & Tarif tab
      ),
    );
  }

  group('Katalog & Tarif Refactor & Polish Tests', () {
    testWidgets(
      '1. Primary action button displays "+ Tambah Unit" with no duplicate plus and no icon clutter',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Verify primary button label is "+ Tambah Unit"
        expect(find.widgetWithText(ElevatedButton, '+ Tambah Unit'), findsNWidgets(2));
        expect(find.text('+ + Unit Baru'), findsNothing);
        expect(find.text('+ Unit Baru'), findsNothing);

        // Verify primary button is an ElevatedButton with text child only (no Icons.add icon widget inside action row)
        final elevatedButtonFinder = find.widgetWithText(ElevatedButton, '+ Tambah Unit');
        expect(elevatedButtonFinder, findsNWidgets(2));
      },
    );

    testWidgets(
      '2. Secondary Edit Tarif button removes decorative pencil icon and keeps clean flat outline',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Verify Edit Tarif text is present
        expect(find.text('Edit Tarif'), findsNWidgets(2));

        // Verify pencil icon (Icons.edit_outlined) is NOT present inside catalog cards
        expect(find.byIcon(Icons.edit_outlined), findsNothing);

        // Verify button is OutlinedButton
        expect(find.widgetWithText(OutlinedButton, 'Edit Tarif'), findsNWidgets(2));
      },
    );

    testWidgets(
      '3. Search field placeholder is normalized to "Cari model, kode unit, atau serial number..."',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Verify unified search hint text
        expect(find.text('Cari model, kode unit, atau serial number...'), findsOneWidget);
      },
    );

    testWidgets(
      '4. Enforces Title-Case formatting on metadata and specifications (e.g. hijau -> Hijau)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // "hitam pekat" should format to "Hitam Pekat" and "standar" to "Standar"
        expect(find.textContaining('Hitam Pekat / Standar'), findsOneWidget);
        expect(find.textContaining('hitam pekat'), findsNothing);

        // "hijau" should format to "Hijau"
        expect(find.textContaining('Hijau / 256 GB'), findsOneWidget);
        expect(find.textContaining('hijau /'), findsNothing);
      },
    );

    testWidgets(
      '5. Header has "+ Model Baru" button without FAB, and unified ListView has bottom: 96.0 padding',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        // Verify Header "+ Model Baru" button and zero floating FAB
        expect(find.byKey(const Key('inventory_add_model_button')), findsOneWidget);
        expect(find.text('+ Model Baru'), findsOneWidget);
        expect(find.byKey(const Key('inventory_expandable_main_fab')), findsNothing);

        // Verify ListView bottom padding clearance (96.0)
        final listViewFinder = find.byWidgetPredicate((widget) {
          if (widget is ListView && widget.padding is EdgeInsets) {
            final padding = widget.padding as EdgeInsets;
            return padding.bottom == 96.0;
          }
          return false;
        });
        expect(listViewFinder, findsOneWidget);
      },
    );
  });
}

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

class _TrackingAssetRepository extends AssetRepository {
  Map<String, dynamic>? lastUpdatedAssetPayload;
  int? lastUpdatedAssetId;
  Map<String, dynamic>? lastUpdatedProductPayload;
  int? lastUpdatedProductId;

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
    {'id': 2, 'name': 'Smartphone', 'slug': 'smartphones'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async => [
    {
      'id': 10,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'category': {'id': 1, 'name': 'Kamera'},
    },
    {
      'id': 20,
      'name': 'iPhone 15 Pro Max',
      'brand': 'Apple',
      'category': {'id': 2, 'name': 'Smartphone'},
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [
    {
      'id': 10,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'category': {'id': 1, 'name': 'Kamera'},
      'color': 'Hitam',
      'storage_capacity': null,
      'description': 'Full-frame mirrorless camera',
      'requires_frp_check': false,
      'ready_units_count': 3,
      'assets_count': 5,
      'pricing_tiers': [
        {
          'id': 101,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 300000.00,
          'extension_hourly_rate': 25000.00,
        },
        {
          'id': 102,
          'duration_unit': 'day',
          'duration_value': 3,
          'price': 800000.00,
          'extension_hourly_rate': 25000.00,
        },
      ],
    },
  ];

  @override
  Future<Map<String, dynamic>> updateAsset(int id, Map<String, dynamic> payload) async {
    lastUpdatedAssetId = id;
    lastUpdatedAssetPayload = payload;
    return {'id': id, ...payload};
  }

  @override
  Future<Map<String, dynamic>> updateProduct(int id, Map<String, dynamic> payload) async {
    lastUpdatedProductId = id;
    lastUpdatedProductPayload = payload;
    return {'id': id, ...payload};
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
    activeBusinessId: 10,
    activeBusinessName: 'RentCore Store',
    activeBranchId: 1,
    activeBranchName: 'Pusat',
    businesses: [
      {'id': 10, 'name': 'RentCore Store'}
    ],
  );

  final sampleAsset = {
    'id': 101,
    'model_id': 10,
    'asset_code': 'CAM-001',
    'serial_number': 'SN-CAM-001',
    'imei_1': '351234567890123',
    'status': 'ready',
    'condition_grade': 'A',
    'battery_health': 98,
    'notes': 'Unit mulus dengan lensa kit',
    'model': {
      'id': 10,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'color': 'Hitam',
      'category': {'id': 1, 'name': 'Kamera'},
    },
  };

  group('Inventory Unit & Catalog Editing Tests', () {
    testWidgets('InventoryScreen renders TabBar with Unit Fisik and Katalog & Tarif tabs', (tester) async {
      final repo = _TrackingAssetRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(repo),
            inventoryListProvider.overrideWith((ref) => Future.value([sampleAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Unit Fisik (Inventaris)'), findsOneWidget);
      expect(find.text('Katalog & Tarif'), findsOneWidget);
      expect(find.text('CAM-001'), findsOneWidget);
      expect(find.text('Edit Unit'), findsOneWidget);
    });

    testWidgets('Tapping Edit Unit opens _EditAssetSheet with prefilled values and submits updates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _TrackingAssetRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(repo),
            inventoryListProvider.overrideWith((ref) => Future.value([sampleAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap the prominent Edit Unit button
      await tester.tap(find.text('Edit Unit'));
      await tester.pumpAndSettle();

      // Verify fields prefilled
      expect(find.text('CAM-001'), findsAtLeast(1));
      expect(find.text('SN-CAM-001'), findsAtLeast(1));
      expect(find.text('351234567890123'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);

      // Submit changes
      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(repo.lastUpdatedAssetId, 101);
      expect(repo.lastUpdatedAssetPayload?['asset_code'], 'CAM-001');
      expect(repo.lastUpdatedAssetPayload?['serial_number'], 'SN-CAM-001');
    });

    testWidgets('Switching to Katalog & Tarif tab displays products with Edit Model & Tarif action', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _TrackingAssetRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(repo),
            inventoryListProvider.overrideWith((ref) => Future.value([sampleAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(initialTabIndex: 1),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify product card in catalog tab
      expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
      expect(find.text('3 Siap Sewa • 5 Total Unit'), findsOneWidget);
      expect(find.text('Edit Model & Tarif'), findsOneWidget);

      // Tap Edit Model & Tarif to open prefilled AddProductSheet
      await tester.tap(find.text('Edit Model & Tarif'));
      await tester.pumpAndSettle();

      expect(find.text('Edit Model & Tarif Sewa'), findsOneWidget);
      expect(find.text('Perbarui informasi katalog & konfigurasi paket harga'), findsOneWidget);
      expect(find.text('Simpan Perubahan Katalog'), findsOneWidget);

      // Verify rates loaded
      expect(find.text('300000'), findsOneWidget);
      expect(find.text('800000'), findsOneWidget);

      // Submit product edits
      await tester.ensureVisible(find.text('Simpan Perubahan Katalog'));
      await tester.tap(find.text('Simpan Perubahan Katalog'));
      await tester.pumpAndSettle();

      expect(repo.lastUpdatedProductId, 10);
      expect(repo.lastUpdatedProductPayload?['name'], 'Sony Alpha A7 IV');
      expect(repo.lastUpdatedProductPayload?['brand'], 'Sony');
    });

    testWidgets('Active rented unit shows locked banner and allows safe descriptive updates', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _TrackingAssetRepository();
      final rentedAsset = {
        ...sampleAsset,
        'status': 'rented',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(repo),
            inventoryListProvider.overrideWith((ref) => Future.value([rentedAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Edit Unit'));
      await tester.pumpAndSettle();

      expect(find.text('Sedang Disewa (Terkunci)'), findsOneWidget);
      expect(find.textContaining('Unit sedang aktif disewa pelanggan'), findsOneWidget);

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(repo.lastUpdatedAssetId, 101);
      // Status is locked so not sent or preserved
      expect(repo.lastUpdatedAssetPayload?.containsKey('status'), isFalse);
    });
  });
}

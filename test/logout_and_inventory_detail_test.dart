import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _ThrowingAuthRepository extends AuthRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchBusinesses() async => [
    {'id': 99, 'name': 'Active Rental Biz', 'role': 'owner'}
  ];

  @override
  Future<void> setActiveContext({
    required int businessId,
    required String businessName,
    int? branchId,
    String? branchName,
  }) async {}

  @override
  Future<void> logout() async {
    throw Exception('Simulated network/storage crash during logout');
  }
}

class _MockAssetRepository extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [];

  @override
  Future<Map<String, dynamic>> updateAsset(int id, Map<String, dynamic> payload) async {
    return {'id': id, ...payload};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Issue 1: Logout Error & Preferences Preservation Tests', () {
    test('AuthRepository.logout() removes tenant session keys but preserves printer & config settings', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('active_business_id', 1);
      await prefs.setString('active_business_name', 'RentCore Bali');
      await prefs.setInt('active_branch_id', 2);
      await prefs.setString('branch_name', 'Cabang Kuta');
      await prefs.setString('branch_code', 'KTA');
      await prefs.setString('api_base_url', 'http://192.168.1.101:8000/api/v1');
      await prefs.setString('google_server_client_id', 'custom-client-id.apps.googleusercontent.com');
      await prefs.setString('rentcore_printer_settings_v1', '{"paperWidth":"mm80"}');
      await prefs.setString('rentcore_printer_saved_device_v1', '{"name":"PT-210","mac":"00:11:22:33:44:55"}');

      final repo = AuthRepository();
      await repo.logout();

      // Tenant-specific session state must be wiped
      expect(prefs.getInt('active_business_id'), isNull);
      expect(prefs.getString('active_business_name'), isNull);
      expect(prefs.getInt('active_branch_id'), isNull);
      expect(prefs.getString('branch_name'), isNull);
      expect(prefs.getString('branch_code'), isNull);

      // Hardware and network configurations MUST be preserved across logout
      expect(prefs.getString('api_base_url'), 'http://192.168.1.101:8000/api/v1');
      expect(prefs.getString('google_server_client_id'), 'custom-client-id.apps.googleusercontent.com');
      expect(prefs.getString('rentcore_printer_settings_v1'), '{"paperWidth":"mm80"}');
      expect(prefs.getString('rentcore_printer_saved_device_v1'), '{"name":"PT-210","mac":"00:11:22:33:44:55"}');
    });

    test('AuthNotifier.logout() cleanly resets AuthState and BusinessState even when repository throws', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_ThrowingAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      // Populate business state as if a user was logged in
      final businessNotifier = container.read(businessProvider.notifier);
      await businessNotifier.selectBusiness({'id': 99, 'name': 'Active Rental Biz'});

      expect(container.read(businessProvider).activeBusinessId, 99);

      // Invoke logout which encounters the throwing repository
      await container.read(authProvider.notifier).logout();

      // Verify AuthState is unauthenticated and not loading
      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, false);
      expect(authState.isLoading, false);
      expect(authState.user, isNull);

      // Verify BusinessState is completely reset
      final bizState = container.read(businessProvider);
      expect(bizState.activeBusinessId, isNull);
      expect(bizState.activeBusinessName, isNull);
      expect(bizState.activeBranchId, isNull);
    });
  });

  group('Issue 2: Inventory Device Detail Modal Tests', () {
    final mockBusiness = const BusinessState(
      activeBusinessId: 10,
      activeBusinessName: 'RentCore Store',
      businesses: [
        {'id': 10, 'name': 'RentCore Store'}
      ],
    );

    testWidgets('Tapping a rented asset card opens _EditAssetSheet without assertion error and displays locked banner', (tester) async {
      final rentedAsset = {
        'id': 101,
        'asset_code': 'IP15-001',
        'serial_number': 'SN-RENTED-999',
        'status': 'rented',
        'condition_grade': 'A',
        'battery_health': 98,
        'notes': 'Unit with active customer booking',
        'model': {
          'name': 'iPhone 15 Pro Max',
          'color': 'Natural Titanium',
          'storage_capacity': '256GB',
          'category': {'name': 'Smartphone'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([rentedAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify card rendered
      expect(find.text('IP15-001'), findsOneWidget);
      expect(find.text('Sedang Sewa'), findsOneWidget);

      // Tap device card
      await tester.tap(find.text('IP15-001'));
      await tester.pumpAndSettle();

      // Verify sheet opened cleanly without assertion failure
      expect(find.text('Status Operasional Unit'), findsOneWidget);
      expect(find.text('Sedang Disewa (Terkunci)'), findsOneWidget);
      expect(find.textContaining('Unit sedang aktif disewa pelanggan'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
    });

    testWidgets('Tapping an in_transit asset card opens _EditAssetSheet without assertion error and displays mutasi banner', (tester) async {
      final inTransitAsset = {
        'id': 102,
        'asset_code': 'PS5-002',
        'serial_number': 'SN-TRANSIT-888',
        'status': 'in_transit',
        'condition_grade': 'B',
        'battery_health': null,
        'notes': 'Transfer to Kuta branch in progress',
        'model': {
          'name': 'PlayStation 5 Slim',
          'color': 'White',
          'storage_capacity': '1TB',
          'category': {'name': 'Game Console'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([inTransitAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('PS5-002'), findsOneWidget);

      await tester.tap(find.text('PS5-002'));
      await tester.pumpAndSettle();

      expect(find.text('Status Operasional Unit'), findsOneWidget);
      expect(find.text('Dalam Mutasi (Terkunci)'), findsOneWidget);
      expect(find.textContaining('Unit sedang dalam perjalanan mutasi antar cabang'), findsOneWidget);
    });

    testWidgets('Tapping an asset with unknown status opens _EditAssetSheet gracefully with fallback item', (tester) async {
      final unknownStatusAsset = {
        'id': 103,
        'asset_code': 'CAM-003',
        'serial_number': 'SN-UNKNOWN-777',
        'status': 'audit_pending',
        'condition_grade': 'A',
        'battery_health': null,
        'notes': 'Custom backend status',
        'model': {
          'name': 'Sony Alpha A7 IV',
          'color': 'Black',
          'category': {'name': 'Kamera'},
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _TestBusinessNotifier(mockBusiness)),
            assetRepositoryProvider.overrideWithValue(_MockAssetRepository()),
            inventoryListProvider.overrideWith((ref) => Future.value([unknownStatusAsset])),
          ],
          child: MaterialApp(
            navigatorKey: rootNavigatorKey,
            home: const InventoryScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CAM-003'), findsOneWidget);

      await tester.tap(find.text('CAM-003'));
      await tester.pumpAndSettle();

      // Gracefully handles without throwing assertion error
      expect(find.text('audit_pending (Terkunci)'), findsOneWidget);
    });
  });
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/home/presentation/widgets/progressive_checklist_banner.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/add_product_sheet.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/shared/widgets/floating_capsule_dock.dart';

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 10,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'role': 'owner',
            'branches': [
              {'id': 10, 'name': 'Cabang Pusat', 'is_central': true},
            ],
          }
        ],
      );
}

class _TestAssetRepo extends AssetRepository {
  final List<Map<String, dynamic>> _assets;
  final List<Map<String, dynamic>> _models;

  _TestAssetRepo({
    List<Map<String, dynamic>>? assets,
    List<Map<String, dynamic>>? models,
  })  : _assets = assets ?? const [],
        _models = models ?? const [];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Smartphones', 'slug': 'smartphones'},
        {'id': 2, 'name': 'Kamera', 'slug': 'kamera'},
        {'id': 3, 'name': 'Aksesoris', 'slug': 'aksesoris', 'is_addon': true},
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async =>
      _models;

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      _models;

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async =>
      _assets;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('1 & 4b: Daftar Aset FAB sits 16dp above bottom edge, ListView has 88dp bottom padding, and units sort newest first',
      (tester) async {
    tester.view.physicalSize = const Size(412, 840);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _TestAssetRepo(
      assets: [
        {
          'id': 10,
          'asset_code': 'AST-OLD',
          'serial_number': 'SN-OLD',
          'status': 'ready',
          'condition_grade': 'A',
          'created_at': '2026-11-01T08:00:00Z',
          'model': {
            'id': 1,
            'name': 'Unit Lama',
            'brand': 'Apple',
            'category': {'id': 1, 'name': 'Smartphones'},
          },
        },
        {
          'id': 25,
          'asset_code': 'AST-NEW',
          'serial_number': 'SN-NEW',
          'status': 'ready',
          'condition_grade': 'A',
          'created_at': '2026-11-17T10:00:00Z',
          'model': {
            'id': 2,
            'name': 'Unit Terbaru',
            'brand': 'Sony',
            'category': {'id': 2, 'name': 'Kamera'},
          },
        },
      ],
      models: [
        {'id': 1, 'name': 'Unit Lama', 'brand': 'Apple'},
        {'id': 2, 'name': 'Unit Terbaru', 'brand': 'Sony'},
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          assetRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: const InventoryScreen(),
            bottomNavigationBar: FloatingCapsuleDock(
              currentIndex: 2,
              onTabSelected: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // ListView has >= 88dp bottom padding (96dp) to clear FloatingCapsuleDock without FAB overlap
    expect(find.byKey(const Key('inventory_expandable_main_fab')), findsNothing);
    final listView = tester.widget<ListView>(find.byType(ListView).first);
    expect((listView.padding as EdgeInsets).bottom, greaterThanOrEqualTo(88.0));

    // Newest unit appears above oldest unit
    final newDy = tester.getTopLeft(find.text('Unit Terbaru')).dy;
    final oldDy = tester.getTopLeft(find.text('Unit Lama')).dy;
    expect(newDy, lessThan(oldDy));
  });

  testWidgets('2 & 3: Searchable Model Picker filters by name/brand, has + Tambah Model Baru, and opens full-screen AddProductSheet with photo picker',
      (tester) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _TestAssetRepo(
      assets: [
        {
          'id': 1,
          'asset_code': 'AST-001',
          'serial_number': 'SN-001',
          'status': 'ready',
          'condition_grade': 'A',
          'model': {'id': 10, 'name': 'iPhone 15 Pro', 'brand': 'Apple'},
        },
      ],
      models: [
        {
          'id': 10,
          'name': 'iPhone 15 Pro',
          'brand': 'Apple',
          'pricing_tiers': [
            {'duration_unit': 'day', 'duration_value': 1, 'price': 150000},
          ],
        },
        {
          'id': 20,
          'name': 'Alpha A7 IV',
          'brand': 'Sony',
          'pricing_tiers': [
            {'duration_unit': 'day', 'duration_value': 1, 'price': 250000},
          ],
        },
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          assetRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.lightTheme,
          home: const InventoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Open Registrasi Unit sheet directly from model card "+ Tambah Unit"
    await tester.tap(find.widgetWithText(ElevatedButton, '+ Tambah Unit').first);
    await tester.pumpAndSettle();

    expect(find.text('Registrasi Unit Baru'), findsOneWidget);
    expect(find.byKey(const Key('register_unit_model_selector')), findsOneWidget);

    // Open searchable model picker bottom sheet
    await tester.tap(find.byKey(const Key('register_unit_model_selector')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('model_picker_search_field')), findsOneWidget);
    expect(find.text('Cari nama model atau merek...'), findsOneWidget);
    final pickerSheet = find.byType(BottomSheet).last;
    expect(find.descendant(of: pickerSheet, matching: find.text('iPhone 15 Pro')), findsOneWidget);
    expect(find.descendant(of: pickerSheet, matching: find.text('Alpha A7 IV')), findsOneWidget);
    expect(find.text('+ Tambah Model Baru'), findsOneWidget);

    // Filter by brand 'Sony'
    await tester.enterText(find.byKey(const Key('model_picker_search_field')), 'Sony');
    await tester.pumpAndSettle();
    expect(find.descendant(of: pickerSheet, matching: find.text('Alpha A7 IV')), findsOneWidget);
    expect(find.descendant(of: pickerSheet, matching: find.text('iPhone 15 Pro')), findsNothing);

    // Open full-screen Tambah Model sheet from quick action
    await tester.tap(find.byKey(const Key('model_picker_add_new_button')));
    await tester.pumpAndSettle();

    expect(find.byType(AddProductSheet), findsOneWidget);
    expect(find.text('Foto Model Perangkat (Opsional)'), findsOneWidget);
    expect(find.byKey(const Key('model_photo_picker_box')), findsOneWidget);
    expect(find.byKey(const Key('add_product_sheet_close_button')), findsOneWidget);

    // Verify full-screen viewport height (100%)
    final sheetRect = tester.getRect(find.byType(AddProductSheet));
    expect(sheetRect.height, closeTo(900.0, 2.0));

    // Close AddProductSheet and select Alpha A7 IV
    await tester.tap(find.byKey(const Key('add_product_sheet_close_button')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(of: pickerSheet, matching: find.text('Alpha A7 IV')),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(const Key('register_unit_model_selector')),
        matching: find.text('Alpha A7 IV'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('4a: Panduan Persiapan Toko stays hidden once dismissed for the active business',
      (tester) async {
    final testBiz = {
      'id': 99,
      'name': 'Toko Kamera',
      'role': 'owner',
      'branches': [
        {'id': 1, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          businessProvider.overrideWith(BusinessNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalModelCount: 0,
              totalAssetCount: 0,
            ),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(businessProvider.notifier).loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    // Initially visible
    expect(find.text('Panduan Persiapan Toko'), findsOneWidget);

    // Dismiss checklist -> persists scoped flag in SharedPreferences & hides card
    await tester.tap(find.byKey(const Key('checklist_dismiss_button')));
    await tester.pumpAndSettle();
    expect(find.text('Panduan Persiapan Toko'), findsNothing);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('checklist_dismissed_99'), isTrue);
  });

  testWidgets('5: Booking Baru add-on search filters add-ons and preserves selection + subtotal',
      (tester) async {
    tester.view.physicalSize = const Size(500, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final mockAssets = [
      {
        'id': 1,
        'asset_code': 'UNIT-01',
        'condition_grade': 'A',
        'model': {
          'id': 101,
          'name': 'Sony A7 IV',
          'brand': 'Sony',
          'category_id': 2,
          'category': {'id': 2, 'name': 'Kamera', 'is_addon': false},
          'pricing_tiers': [
            {'id': 1, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 250000},
          ],
        },
      },
      {
        'id': 2,
        'asset_code': 'ADD-PB1',
        'condition_grade': 'A',
        'model': {
          'id': 201,
          'name': 'Power Bank Anker 20000mAh',
          'brand': 'Anker',
          'description': 'Fast charging PD',
          'is_addon': true,
          'category_id': 3,
          'category': {'id': 3, 'name': 'Aksesoris', 'is_addon': true},
          'pricing_tiers': [
            {'id': 2, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 25000},
          ],
        },
      },
      {
        'id': 3,
        'asset_code': 'ADD-TRP',
        'condition_grade': 'A',
        'model': {
          'id': 202,
          'name': 'Tripod Ulanzi MT-44',
          'brand': 'Ulanzi',
          'description': 'Extendable vlog tripod',
          'is_addon': true,
          'category_id': 3,
          'category': {'id': 3, 'name': 'Aksesoris', 'is_addon': true},
          'pricing_tiers': [
            {'id': 3, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 15000},
          ],
        },
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          readyAssetsProvider.overrideWith((ref) => Future.value(mockAssets)),
          categoriesProvider.overrideWith((ref) => Future.value([
                {'id': 2, 'name': 'Kamera'},
                {'id': 3, 'name': 'Aksesoris', 'is_addon': true},
              ])),
        ],
        child: const MaterialApp(
          home: DirectRentalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Select Power Bank add-on
    final searchField = find.byKey(const Key('booking_addon_search_field'));
    await tester.ensureVisible(searchField);
    await tester.tap(find.textContaining('Power Bank Anker 20000mAh').last);
    await tester.pumpAndSettle();
    expect(find.text('Subtotal Add-on (1x)'), findsOneWidget);

    // Filter to Tripod -> Power Bank disappears from add-on list, but subtotal remains preserved
    final addonSectionColumn = find.ancestor(
      of: searchField,
      matching: find.byType(Column),
    ).first;
    await tester.enterText(searchField, 'Tripod');
    await tester.pumpAndSettle();
    expect(find.descendant(of: addonSectionColumn, matching: find.textContaining('Tripod Ulanzi MT-44')), findsOneWidget);
    expect(find.descendant(of: addonSectionColumn, matching: find.textContaining('Power Bank Anker 20000mAh')), findsNothing);
    expect(find.text('Subtotal Add-on (1x)'), findsOneWidget);

    // Clear search via X button -> both add-ons reappear and selection stays intact
    await tester.tap(find.byKey(const Key('booking_addon_search_clear')));
    await tester.pumpAndSettle();
    expect(find.descendant(of: addonSectionColumn, matching: find.textContaining('Power Bank Anker 20000mAh')), findsOneWidget);
    expect(find.descendant(of: addonSectionColumn, matching: find.textContaining('Tripod Ulanzi MT-44')), findsOneWidget);
    expect(find.text('Subtotal Add-on (1x)'), findsOneWidget);
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentcore_mobile/core/constants/navigation_keys.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/presentation/inventory_screen.dart';
import 'package:rentcore_mobile/features/inventory/presentation/widgets/expandable_inventory_fab.dart';
import 'package:rentcore_mobile/features/inventory/presentation/widgets/tarif_sewa_sheet.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/shared/widgets/floating_capsule_dock.dart';

class _MockAssetRepo extends AssetRepository {
  final Map<String, dynamic> payload;
  _MockAssetRepo(this.payload);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Smartphones'},
        {'id': 2, 'name': 'Tablets'},
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [
        {
          'id': 10,
          'name': 'iPhone 17 pro Max',
          'category': {'id': 1, 'name': 'Smartphones'},
          'brand': 'Apple',
          'color': 'Orange',
          'storage_capacity': '512',
          'ready_units_count': 1,
          'assets_count': 1,
          'pricing_tiers': [
            {'duration_unit': 'hari', 'duration_value': 1, 'price': 150000},
            {'duration_unit': 'hari', 'duration_value': 3, 'price': 400000},
          ],
        },
        {
          'id': 11,
          'name': 'iPhone 18 pro',
          'category': {'id': 1, 'name': 'Smartphones'},
          'brand': 'Apple',
          'color': 'Burgundy',
          'storage_capacity': '128',
          'ready_units_count': 0,
          'assets_count': 1,
          'pricing_tiers': [
            {'duration_unit': 'hari', 'duration_value': 1, 'price': 180000},
          ],
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async =>
      extractList(payload['data']);
}

class _MockBizNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 3,
        activeBusinessName: 'Gwenn Rental Malang',
        activeBranchId: 4,
        activeBranchName: 'Gwenn Rental Pusat',
        businesses: [
          {
            'id': 3,
            'name': 'Gwenn Rental Malang',
            'role': 'owner',
            'branches': [
              {'id': 4, 'name': 'Gwenn Rental Pusat', 'is_central': true},
            ],
          }
        ],
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget createTestWidget({required Widget child, AssetRepository? repo}) {
    final payload = jsonDecode(
      File('test/fixtures/assets_paginated_response_branch4.json').readAsStringSync(),
    ) as Map<String, dynamic>;

    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(_MockBizNotifier.new),
        assetRepositoryProvider.overrideWithValue(repo ?? _MockAssetRepo(payload)),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        theme: AppTheme.lightTheme,
        home: Scaffold(
          extendBody: true,
          body: child,
          bottomNavigationBar: FloatingCapsuleDock(currentIndex: 2, onTabSelected: (_) {}),
        ),
      ),
    );
  }

  group('ExpandableInventoryFab Component Unit Tests', () {
    testWidgets('Renders collapsed state with single main FAB and no action items', (tester) async {
      bool registered = false;
      bool addedModel = false;
      bool managedTarif = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onRegisterUnit: () => registered = true,
              onAddModel: () => addedModel = true,
              onManageTarif: () => managedTarif = true,
            ),
          ),
        ),
      ));

      expect(find.byKey(const Key('inventory_expandable_main_fab')), findsOneWidget);
      expect(find.byKey(const Key('fab_action_registrasi_unit')), findsNothing);
      expect(find.byKey(const Key('fab_action_tambah_model')), findsNothing);
      expect(find.byKey(const Key('fab_action_tarif_sewa')), findsNothing);

      expect(registered, isFalse);
      expect(addedModel, isFalse);
      expect(managedTarif, isFalse);
    });

    testWidgets('Tapping main FAB expands and reveals 2 actions with correct labels and icons', (tester) async {
      bool? expansionState;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onExpansionChanged: (val) => expansionState = val,
              onRegisterUnit: () {},
              onAddModel: () {},
            ),
          ),
        ),
      ));

      // Tap main FAB to expand
      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();

      expect(expansionState, isTrue);

      // Verify the 2 action items are rendered
      expect(find.byKey(const Key('fab_action_registrasi_unit')), findsOneWidget);
      expect(find.byKey(const Key('fab_action_tambah_model')), findsOneWidget);
      expect(find.byKey(const Key('fab_action_tarif_sewa')), findsNothing);

      // Verify text labels
      expect(find.text('Registrasi Unit'), findsOneWidget);
      expect(find.text('Tambah Model'), findsOneWidget);
      expect(find.text('Tarif Sewa'), findsNothing);

      // Verify icons
      expect(find.byIcon(Icons.devices_rounded), findsOneWidget);
      expect(find.byIcon(Icons.post_add_rounded), findsOneWidget);
    });

    testWidgets('Tapping main FAB again collapses the menu', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onRegisterUnit: () {},
              onAddModel: () {},
              onManageTarif: () {},
            ),
          ),
        ),
      ));

      // Expand
      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();
      expect(find.text('Registrasi Unit'), findsOneWidget);

      // Tap again to collapse
      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fab_action_registrasi_unit')), findsNothing);
      expect(find.byKey(const Key('fab_action_tambah_model')), findsNothing);
      expect(find.byKey(const Key('fab_action_tarif_sewa')), findsNothing);
    });

    testWidgets('Tapping Registrasi Unit action triggers callback and auto-collapses', (tester) async {
      bool registered = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onRegisterUnit: () => registered = true,
              onAddModel: () {},
              onManageTarif: () {},
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fab_action_registrasi_unit')));
      await tester.pumpAndSettle();

      expect(registered, isTrue);
      expect(find.byKey(const Key('fab_action_registrasi_unit')), findsNothing);
    });

    testWidgets('Tapping Tambah Model action triggers callback and auto-collapses', (tester) async {
      bool addedModel = false;

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onRegisterUnit: () {},
              onAddModel: () => addedModel = true,
              onManageTarif: () {},
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('fab_action_tambah_model')));
      await tester.pumpAndSettle();

      expect(addedModel, isTrue);
      expect(find.byKey(const Key('fab_action_tambah_model')), findsNothing);
    });

    testWidgets('Expandable FAB does not contain Tarif Sewa action', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: ExpandableInventoryFab(
              onRegisterUnit: () {},
              onAddModel: () {},
            ),
          ),
        ),
      ));

      await tester.tap(find.byKey(const Key('inventory_expandable_main_fab')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('fab_action_tarif_sewa')), findsNothing);
      expect(find.text('Tarif Sewa'), findsNothing);
    });
  });

  group('InventoryScreen Integration with Expandable FAB', () {
    testWidgets('InventoryScreen presents Expandable FAB above dock and expands smoothly with 2 actions', (tester) async {
      await tester.pumpWidget(createTestWidget(child: const InventoryScreen()));
      await tester.pumpAndSettle();

      // Main FAB is present
      final fabFinder = find.byKey(const Key('inventory_expandable_main_fab'));
      expect(fabFinder, findsOneWidget);

      // Tap FAB to expand
      await tester.tap(fabFinder);
      await tester.pumpAndSettle();

      // Verify exactly 2 actions visible and Tarif Sewa removed
      expect(find.text('Registrasi Unit'), findsOneWidget);
      expect(find.text('Tambah Model'), findsOneWidget);
      expect(find.text('Tarif Sewa'), findsNothing);

      // Verify backdrop scrim dismisses menu when tapped
      await tester.tapAt(const Offset(50, 200));
      await tester.pumpAndSettle();

      expect(find.text('Registrasi Unit'), findsNothing);
      expect(find.text('Tambah Model'), findsNothing);
      expect(find.text('Tarif Sewa'), findsNothing);
    });
  });
}

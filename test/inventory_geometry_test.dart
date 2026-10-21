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
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/shared/widgets/floating_capsule_dock.dart';

class _Repo extends AssetRepository {
  final Map<String, dynamic> payload;
  _Repo(this.payload);
  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Smartphones'},
        {'id': 2, 'name': 'Tablets'},
        {'id': 3, 'name': 'Laptops'},
      ];
  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [];
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

class _Biz extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 3,
        activeBusinessName: 'Gwenn Rental Malang',
        activeBranchId: 4,
        activeBranchName: 'Gwenn Rental Pusat',
        businesses: [
          {'id': 3, 'name': 'Gwenn Rental Malang', 'role': 'owner', 'branches': [
            {'id': 4, 'name': 'Gwenn Rental Pusat', 'is_central': true},
          ]}
        ],
      );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  for (final scale in const [1.0, 1.15, 1.3])
  for (final vp in const [Size(1138, 711), Size(1138, 640)]) {
    testWidgets('geometry at ${vp.width}x${vp.height} scale $scale', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.view.physicalSize = vp * 2;
      tester.view.devicePixelRatio = 2;
      tester.view.padding = const FakeViewPadding(top: 48, bottom: 96); // 24dp status + 48dp nav bar
      addTearDown(tester.view.reset);

      final payload = jsonDecode(File('test/fixtures/assets_paginated_response_branch4.json').readAsStringSync())
          as Map<String, dynamic>;
      await tester.pumpWidget(ProviderScope(
        overrides: [
          businessProvider.overrideWith(_Biz.new),
          assetRepositoryProvider.overrideWithValue(_Repo(payload)),
        ],
        child: MaterialApp(
          navigatorKey: rootNavigatorKey,
          theme: AppTheme.lightTheme,
          home: Scaffold(
            extendBody: true,
            body: Column(children: [
              Expanded(child: IndexedStack(index: 0, children: const [InventoryScreen()])),
            ]),
            bottomNavigationBar: FloatingCapsuleDock(currentIndex: 2, onTabSelected: (_) {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final dockTop = tester.getTopLeft(find.byType(FloatingCapsuleDock)).dy;
      final listFinder = find.byType(ListView).last;
      final listRect = tester.getRect(listFinder);
      final firstCard = find.text('HGCGHVJG');
      expect(firstCard, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}

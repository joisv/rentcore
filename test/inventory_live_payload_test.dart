import 'dart:convert';
import 'dart:io';

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

/// Repository that replays the real `GET /api/v1/assets` paginated payload
/// captured from the backend, run through the production `extractList` parser.
class _LivePayloadAssetRepository extends AssetRepository {
  final Map<String, dynamic> payload;
  final List<int?> requestedBranches = [];
  final List<String?> requestedStatuses = [];

  _LivePayloadAssetRepository(this.payload);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({int? categoryId, String? search}) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
    bool allBranches = false,
  }) async {
    requestedBranches.add(branchId);
    requestedStatuses.add(status);
    final all = extractList(payload['data']);
    if (status == null) return all;
    return all.where((a) => a['status'] == status).toList();
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

  late Map<String, dynamic> livePayload;

  setUpAll(() {
    livePayload = jsonDecode(
      File('test/fixtures/assets_paginated_response.json').readAsStringSync(),
    ) as Map<String, dynamic>;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  const bizState = BusinessState(
    activeBusinessId: 3,
    activeBusinessName: 'Gwenn Rental Malang',
    activeBranchId: 5,
    activeBranchName: 'cabang 1',
    businesses: [
      {
        'id': 3,
        'name': 'Gwenn Rental Malang',
        'role': 'owner',
        'branches': [
          {'id': 4, 'name': 'Gwenn Rental Pusat', 'is_central': true},
          {'id': 5, 'name': 'cabang 1', 'is_central': false},
        ],
      }
    ],
  );

  Widget buildScreen(_LivePayloadAssetRepository repo, {String? initialStatusFilter}) {
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(() => _TestBusinessNotifier(bizState)),
        assetRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: InventoryScreen(initialStatusFilter: initialStatusFilter),
      ),
    );
  }

  test('extractList parses the real paginated assets payload', () {
    final list = AssetRepository().extractList(livePayload['data']);
    expect(list.length, 2);
    expect(list.map((a) => a['asset_code']), containsAll(['FCHGTS42555', 'HJHSUKH6596']));
  });

  testWidgets('Real assets payload renders every unit (rented + maintenance) without errors', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    final repo = _LivePayloadAssetRepository(livePayload);
    await tester.pumpWidget(buildScreen(repo));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('FCHGTS42555'), findsOneWidget);
    expect(find.text('HJHSUKH6596'), findsOneWidget);
    expect(find.text('Belum Ada Unit Inventaris'), findsNothing);
    expect(repo.requestedBranches.last, 5);
    expect(repo.requestedStatuses.last, isNull);
  });

  testWidgets('Phone-size IndexedStack shell (as in main.dart) still renders the units', (tester) async {
    tester.view.physicalSize = const Size(720, 1480); // 360x740 logical
    tester.view.devicePixelRatio = 2.0;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final payload4 = jsonDecode(
      File('test/fixtures/assets_paginated_response_branch4.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final repo = _LivePayloadAssetRepository(payload4);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        businessProvider.overrideWith(() => _TestBusinessNotifier(bizState)),
        assetRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        home: Scaffold(
          body: Column(children: [
            Expanded(
              child: IndexedStack(index: 1, children: [
                const SizedBox(),
                const InventoryScreen(),
              ]),
            ),
          ]),
          bottomNavigationBar: const SizedBox(height: 72),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('HGCGHVJG'), findsOneWidget);
  });
}

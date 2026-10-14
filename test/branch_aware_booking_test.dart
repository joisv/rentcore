import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/inventory/data/asset_repository.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _FakeAssetRepository extends AssetRepository {
  final List<int?> recordedBranchRequests = [];
  final List<Map<String, dynamic>> stubbedAssets;

  _FakeAssetRepository({this.stubbedAssets = const []});

  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    String? search,
    int? categoryId,
    int? branchId,
  }) async {
    recordedBranchRequests.add(branchId);
    if (branchId == null) {
      return stubbedAssets;
    }
    return stubbedAssets.where((a) => a['affiliate_id'] == branchId).toList();
  }
}

class _FakeBookingRepository extends BookingRepository {
  final List<int?> recordedBranchRequests = [];
  final List<Map<String, dynamic>> stubbedAssets;

  _FakeBookingRepository({this.stubbedAssets = const []});

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    recordedBranchRequests.add(branchId);
    if (branchId == null) {
      return stubbedAssets;
    }
    return stubbedAssets.where((a) => a['affiliate_id'] == branchId).toList();
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;

  void changeBranch(int newBranchId, String newBranchName) {
    state = state.copyWith(
      activeBranchId: newBranchId,
      activeBranchName: newBranchName,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Branch-Aware Booking Inventory Tests', () {
    final sampleUnits = [
      {
        'id': 1,
        'asset_code': 'AST-A1-001',
        'affiliate_id': 1,
        'status': 'ready',
        'model': {'name': 'iPhone 15 Pro'},
      },
      {
        'id': 2,
        'asset_code': 'AST-A2-001',
        'affiliate_id': 2,
        'status': 'ready',
        'model': {'name': 'iPhone 15 Pro Max'},
      },
    ];

    test('readyAssetsProvider returns empty list when no active business', () async {
      final fakeRepo = _FakeBookingRepository(stubbedAssets: sampleUnits);
      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(const BusinessState(
              activeBusinessId: null,
              businesses: [],
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(readyAssetsProvider.future);
      expect(result, isEmpty);
      expect(fakeRepo.recordedBranchRequests, isEmpty);
    });

    test('readyAssetsProvider scopes fetchReadyAssets with activeBranchId', () async {
      final fakeRepo = _FakeBookingRepository(stubbedAssets: sampleUnits);
      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(const BusinessState(
              activeBusinessId: 10,
              activeBranchId: 1,
              businesses: [{'id': 10, 'name': 'Mega Jaya'}],
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final units = await container.read(readyAssetsProvider.future);
      expect(fakeRepo.recordedBranchRequests, contains(1));
      expect(units.length, 1);
      expect(units.first['asset_code'], 'AST-A1-001');
      expect(units.first['affiliate_id'], 1);
    });

    test('Switching activeBranchId invalidates and queries destination branch units', () async {
      final fakeRepo = _FakeBookingRepository(stubbedAssets: sampleUnits);
      final notifier = _TestBusinessNotifier(const BusinessState(
        activeBusinessId: 10,
        activeBranchId: 1,
        businesses: [{'id': 10, 'name': 'Mega Jaya'}],
      ));

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // 1. Initial query at Branch 1
      var units = await container.read(readyAssetsProvider.future);
      expect(units.length, 1);
      expect(units.first['id'], 1);

      // 2. User switches to Branch 2
      notifier.changeBranch(2, 'Cabang Surabaya');

      // 3. Provider re-evaluates automatically with Branch 2
      units = await container.read(readyAssetsProvider.future);
      expect(fakeRepo.recordedBranchRequests, contains(2));
      expect(units.length, 1);
      expect(units.first['id'], 2);
      expect(units.first['affiliate_id'], 2);
    });

    test('Transferred asset moving from Branch 1 to Branch 2 reflects in filtered readyAssets', () async {
      final dynamicUnits = [
        {
          'id': 1,
          'asset_code': 'AST-TRANSFER-UNIT',
          'affiliate_id': 1, // Initially at Branch 1
          'status': 'ready',
          'model': {'name': 'iPhone 15 Pro'},
        },
      ];

      final fakeRepo = _FakeBookingRepository(stubbedAssets: dynamicUnits);
      final notifier = _TestBusinessNotifier(const BusinessState(
        activeBusinessId: 10,
        activeBranchId: 1,
        businesses: [{'id': 10, 'name': 'Mega Jaya'}],
      ));

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Query Branch 1: unit exists
      var unitsAtBranch1 = await container.read(readyAssetsProvider.future);
      expect(unitsAtBranch1.map((u) => u['id']), contains(1));

      // Simulate transfer receipt confirmation: asset affiliate_id moves to Branch 2
      dynamicUnits[0]['affiliate_id'] = 2;

      // Invalidate provider as done in TransfersScreen._confirmReceiveTransfer
      container.invalidate(readyAssetsProvider);

      // Query Branch 1 again: unit is now EXCLUDED from Branch 1
      unitsAtBranch1 = await container.read(readyAssetsProvider.future);
      expect(unitsAtBranch1, isEmpty);

      // Switch to Branch 2
      notifier.changeBranch(2, 'Cabang Barat');
      final unitsAtBranch2 = await container.read(readyAssetsProvider.future);
      expect(unitsAtBranch2.map((u) => u['id']), contains(1));
    });
  });

  group('Branch-Aware Inventory List Tests', () {
    final inventoryUnits = [
      {
        'id': 101,
        'asset_code': 'AST-INV-BR1',
        'affiliate_id': 1,
        'status': 'ready',
        'model': {'name': 'iPhone 15 Pro'},
      },
      {
        'id': 102,
        'asset_code': 'AST-INV-BR2',
        'affiliate_id': 2,
        'status': 'ready',
        'model': {'name': 'iPhone 15 Plus'},
      },
    ];

    test('inventoryListProvider scopes fetchAssets with activeBranchId', () async {
      final fakeAssetRepo = _FakeAssetRepository(stubbedAssets: inventoryUnits);
      final container = ProviderContainer(
        overrides: [
          assetRepositoryProvider.overrideWithValue(fakeAssetRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(const BusinessState(
              activeBusinessId: 10,
              activeBranchId: 1,
              businesses: [{'id': 10, 'name': 'Mega Jaya'}],
            )),
          ),
        ],
      );
      addTearDown(container.dispose);

      final units = await container.read(inventoryListProvider.future);
      expect(fakeAssetRepo.recordedBranchRequests, contains(1));
      expect(units.length, 1);
      expect(units.first['asset_code'], 'AST-INV-BR1');
    });

    test('inventoryListProvider dynamically reflects transferred iPhone across branches', () async {
      final dynamicInventory = [
        {
          'id': 101,
          'asset_code': 'AST-PURPLE-11',
          'affiliate_id': 1, // Currently at Branch 1
          'status': 'ready',
          'model': {'name': 'iPhone 11 Purple'},
        },
      ];

      final fakeAssetRepo = _FakeAssetRepository(stubbedAssets: dynamicInventory);
      final notifier = _TestBusinessNotifier(const BusinessState(
        activeBusinessId: 10,
        activeBranchId: 1,
        businesses: [{'id': 10, 'name': 'Mega Jaya'}],
      ));

      final container = ProviderContainer(
        overrides: [
          assetRepositoryProvider.overrideWithValue(fakeAssetRepo),
          businessProvider.overrideWith(() => notifier),
        ],
      );
      addTearDown(container.dispose);

      // Branch 1 initially has the Purple iPhone
      var branch1Assets = await container.read(inventoryListProvider.future);
      expect(branch1Assets.map((u) => u['id']), contains(101));

      // Simulate receipt confirmation: authoritative branch becomes Branch 2
      dynamicInventory[0]['affiliate_id'] = 2;
      container.invalidate(inventoryListProvider);

      // Branch 1 immediately loses access to the device
      branch1Assets = await container.read(inventoryListProvider.future);
      expect(branch1Assets, isEmpty);

      // Switch to Branch 2: Device is now listed in Branch 2 inventory
      notifier.changeBranch(2, 'Cabang Surabaya');
      final branch2Assets = await container.read(inventoryListProvider.future);
      expect(branch2Assets.map((u) => u['id']), contains(101));
    });
  });
}

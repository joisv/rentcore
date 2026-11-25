import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/organization/presentation/manage_organization_screen.dart';
import 'package:sewakasir/features/organization/providers/organization_provider.dart';

class _RecordingOrgNotifier extends OrganizationNotifier {
  final OrganizationState _initial;
  Map<String, dynamic>? lastSavedRules;

  _RecordingOrgNotifier(this._initial);

  @override
  OrganizationState build() => _initial;

  @override
  Future<void> loadOrganization(int businessId, {String? businessName}) async {
    state = _initial;
  }

  @override
  Future<bool> updateRentalRules(Map<String, dynamic> rules) async {
    lastSavedRules = Map<String, dynamic>.from(rules);
    state = state.copyWith(
      rentalRules: {...?state.rentalRules, ...rules},
    );
    return true;
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

class _GovernanceAssetRepository extends AssetRepository {
  int? approvedAssetId;
  int? rejectedAssetId;
  String? rejectedReason;
  Map<String, dynamic>? createdAssetPayload;

  final List<Map<String, dynamic>> sampleProducts = [
    {
      'id': 10,
      'name': 'Sony Alpha A7 IV',
      'brand': 'Sony',
      'category': {'id': 1, 'name': 'Kamera'},
      'color': 'Hitam',
      'ready_units_count': 1,
      'assets_count': 2,
      'pricing_tiers': [
        {
          'id': 101,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 300000.0,
        },
      ],
    },
    {
      'id': 20,
      'name': 'iPhone 15 Pro Max',
      'brand': 'Apple',
      'category': {'id': 2, 'name': 'Smartphone'},
      'color': 'Natural Titanium',
      'storage_capacity': '256 GB',
      'ready_units_count': 1,
      'assets_count': 1,
      'pricing_tiers': [
        {
          'id': 201,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 250000.0,
        },
      ],
    },
    {
      'id': 30,
      'name': 'DJI Osmo Pocket 3',
      'brand': 'DJI',
      'category': {'id': 1, 'name': 'Kamera'},
      'color': 'Hitam',
      'ready_units_count': 0,
      'assets_count': 0,
      'pricing_tiers': [
        {
          'id': 301,
          'duration_unit': 'day',
          'duration_value': 1,
          'price': 150000.0,
        },
      ],
    },
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
        {'id': 2, 'name': 'Smartphone', 'slug': 'smartphones'},
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      sampleProducts;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async =>
      sampleProducts;

  @override
  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> payload) async {
    createdAssetPayload = Map<String, dynamic>.from(payload);
    return {'id': 999, ...payload, 'status': 'pending_approval'};
  }

  @override
  Future<Map<String, dynamic>> approveAsset(int id) async {
    approvedAssetId = id;
    return {'id': id, 'status': 'ready'};
  }

  @override
  Future<Map<String, dynamic>> rejectAsset(int id, {String? reason}) async {
    rejectedAssetId = id;
    rejectedReason = reason;
    return {'id': id, 'status': 'rejected', 'rejection_reason': reason};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Branch Unit Registration Governance & Keyboard-Safe Model Picker', () {
    testWidgets(
      'Owner can change Kebijakan Registrasi Unit Cabang in ManageOrganizationScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final orgNotifier = _RecordingOrgNotifier(
          const OrganizationState(
            businessId: 10,
            businessName: 'RentCore Bali',
            userRole: 'owner',
            branches: [
              {'id': 1, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
            ],
            members: [
              {
                'id': 1,
                'role': 'owner',
                'user': {'name': 'Owner', 'email': 'owner@rentcore.id'},
                'branch_members': [],
              },
            ],
            rentalRules: {
              'id_document_limit_enabled': true,
              'max_primary_devices_per_id': 1,
              'addons_enabled': true,
              'max_addons_per_rental': 5,
              'branch_unit_registration_policy': 'self_service',
            },
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              organizationProvider.overrideWith(() => orgNotifier),
            ],
            child: const MaterialApp(
              home: ManageOrganizationScreen(
                businessId: 10,
                businessName: 'RentCore Bali',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kebijakan'));
        await tester.pumpAndSettle();

        expect(find.text('Kebijakan Registrasi Unit Cabang'), findsOneWidget);
        expect(find.text('Bebas Daftarkan Sendiri'), findsOneWidget);
        expect(find.text('Wajib Persetujuan Owner'), findsOneWidget);
        expect(find.text('Hanya Owner'), findsOneWidget);

        final requireApprovalOption = find.byKey(
          const Key('unit_reg_policy_option_require_owner_approval'),
        );
        await tester.ensureVisible(requireApprovalOption);
        await tester.tap(requireApprovalOption);
        await tester.pumpAndSettle();

        final saveButton = find.text('Simpan Kebijakan Rental');
        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(orgNotifier.lastSavedRules, isNotNull);
        expect(
          orgNotifier.lastSavedRules!['branch_unit_registration_policy'],
          'require_owner_approval',
        );

        // Dismiss SnackBar before second save
        ScaffoldMessenger.of(
          tester.element(find.byType(ManageOrganizationScreen)),
        ).hideCurrentSnackBar();
        await tester.pumpAndSettle();

        // Switch to owner_only and save again
        final ownerOnlyOption = find.byKey(
          const Key('unit_reg_policy_option_owner_only'),
        );
        await tester.ensureVisible(ownerOnlyOption);
        await tester.tap(ownerOnlyOption);
        await tester.pumpAndSettle();

        await tester.ensureVisible(saveButton);
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(
          orgNotifier.lastSavedRules!['branch_unit_registration_policy'],
          'owner_only',
        );
      },
    );

    testWidgets(
      'Non-owner UI hides add controls and shows read-only notice under owner_only policy',
      (tester) async {
        final repo = _GovernanceAssetRepository();
        final staffOwnerOnlyBiz = BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Bali',
          activeBranchId: 2,
          activeBranchName: 'Cabang Ubud',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Bali',
              'role': 'staff',
              'branch_unit_registration_policy': 'owner_only',
            },
          ],
        );

        final readyAsset = {
          'id': 101,
          'model_id': 10,
          'asset_code': 'CAM-001',
          'status': 'ready',
          'condition_grade': 'A',
          'model': repo.sampleProducts.first,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(staffOwnerOnlyBiz),
              ),
              assetRepositoryProvider.overrideWithValue(repo),
              inventoryListProvider.overrideWith(
                (ref) => Future.value([readyAsset]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const InventoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('inventory_add_model_button')), findsNothing);
        expect(find.widgetWithText(ElevatedButton, '+ Tambah Unit'), findsNothing);
        expect(find.byKey(const Key('inventory_owner_only_notice')), findsOneWidget);
      },
    );

    testWidgets(
      'Pending approval unit shows Menunggu Persetujuan badge; Owner can Approve & Reject while Staff cannot',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final repo = _GovernanceAssetRepository();
        final pendingAsset = {
          'id': 202,
          'model_id': 10,
          'asset_code': 'CAM-PENDING-01',
          'serial_number': 'SN-PEND-202',
          'status': 'pending_approval',
          'condition_grade': 'A',
          'model': repo.sampleProducts.first,
        };

        // 1. Staff view under require_owner_approval
        final staffApprovalBiz = BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Bali',
          activeBranchId: 2,
          activeBranchName: 'Cabang Ubud',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Bali',
              'role': 'staff',
              'branch_unit_registration_policy': 'require_owner_approval',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(staffApprovalBiz),
              ),
              assetRepositoryProvider.overrideWithValue(repo),
              inventoryListProvider.overrideWith(
                (ref) => Future.value([pendingAsset]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const InventoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Menunggu Persetujuan'), findsOneWidget);
        expect(find.byKey(const Key('approve_unit_btn_202')), findsNothing);
        expect(find.byKey(const Key('reject_unit_btn_202')), findsNothing);

        // 2. Owner view under require_owner_approval
        final ownerApprovalBiz = BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Bali',
          activeBranchId: 1,
          activeBranchName: 'Pusat',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Bali',
              'role': 'owner',
              'branch_unit_registration_policy': 'require_owner_approval',
            },
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('owner_approval_scope'),
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(ownerApprovalBiz),
              ),
              assetRepositoryProvider.overrideWithValue(repo),
              inventoryListProvider.overrideWith(
                (ref) => Future.value([pendingAsset]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const InventoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Menunggu Persetujuan'), findsOneWidget);
        expect(find.byKey(const Key('approve_unit_btn_202')), findsOneWidget);
        expect(find.byKey(const Key('reject_unit_btn_202')), findsOneWidget);

        // Tap Setujui
        await tester.tap(find.byKey(const Key('approve_unit_btn_202')));
        await tester.pumpAndSettle();
        expect(repo.approvedAssetId, 202);

        // Tap Tolak and confirm with reason
        await tester.tap(find.byKey(const Key('reject_unit_btn_202')));
        await tester.pumpAndSettle();
        expect(find.text('Tolak Pengajuan Unit'), findsOneWidget);
        await tester.enterText(
          find.byType(TextField).last,
          'Nomor seri tidak valid',
        );
        await tester.tap(find.text('Tolak Unit'));
        await tester.pumpAndSettle();

        expect(repo.rejectedAssetId, 202);
        expect(repo.rejectedReason, 'Nomor seri tidak valid');
      },
    );

    testWidgets(
      'Registrasi Unit Baru opens keyboard-safe Pilih Model Perangkat picker, filters models with active keyboard inset, and selects model cleanly',
      (tester) async {
        // Simulate standard mobile phone viewport (390x844 logical px)
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
          tester.view.resetViewInsets();
        });

        final repo = _GovernanceAssetRepository();
        final ownerBiz = BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Bali',
          activeBranchId: 1,
          activeBranchName: 'Pusat',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Bali',
              'role': 'owner',
              'branch_unit_registration_policy': 'self_service',
            },
          ],
        );

        final readyAsset = {
          'id': 101,
          'model_id': 10,
          'asset_code': 'CAM-001',
          'status': 'ready',
          'condition_grade': 'A',
          'model': repo.sampleProducts.first,
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(ownerBiz),
              ),
              assetRepositoryProvider.overrideWithValue(repo),
              inventoryListProvider.overrideWith(
                (ref) => Future.value([readyAsset]),
              ),
            ],
            child: MaterialApp(
              navigatorKey: rootNavigatorKey,
              home: const InventoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Open Registrasi Unit Baru via '+ Tambah Unit'
        await tester.tap(find.widgetWithText(ElevatedButton, '+ Tambah Unit').first);
        await tester.pumpAndSettle();

        expect(find.text('Registrasi Unit Baru'), findsOneWidget);
        expect(find.byKey(const Key('register_unit_model_selector')), findsOneWidget);

        // Tap model selector to open Pilih Model Perangkat picker
        await tester.tap(find.byKey(const Key('register_unit_model_selector')));
        await tester.pumpAndSettle();

        expect(find.text('Pilih Model Perangkat'), findsOneWidget);
        expect(find.byKey(const Key('model_picker_search_field')), findsOneWidget);
        expect(find.byKey(const Key('model_picker_results_list')), findsOneWidget);

        // Simulate soft keyboard covering bottom 320px of screen
        tester.view.viewInsets = const FakeViewPadding(bottom: 320.0);
        await tester.pumpAndSettle();

        // Pinned search field must stay visible near top, well above keyboard (844 - 320 = 524)
        final searchFieldRect = tester.getRect(
          find.byKey(const Key('model_picker_search_field')),
        );
        expect(searchFieldRect.bottom, lessThan(320));

        // Filter by model/brand via pinned search field
        await tester.enterText(
          find.byKey(const Key('model_picker_search_field')),
          'Apple',
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('model_picker_row_20')), findsOneWidget);
        expect(find.byKey(const Key('model_picker_row_10')), findsNothing);
        expect(find.byKey(const Key('model_picker_row_30')), findsNothing);

        // Verify filtered result row is visible above keyboard (y < 524)
        final rowRect = tester.getRect(find.byKey(const Key('model_picker_row_20')));
        expect(rowRect.bottom, lessThan(524));

        // Clear search button restores all models
        await tester.tap(find.byKey(const Key('model_picker_search_clear')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('model_picker_row_10')), findsOneWidget);
        expect(find.byKey(const Key('model_picker_row_20')), findsOneWidget);
        expect(find.byKey(const Key('model_picker_row_30')), findsOneWidget);

        // Filter by category name ('Smartphone') and select iPhone 15 Pro Max
        await tester.enterText(
          find.byKey(const Key('model_picker_search_field')),
          'Smartphone',
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('model_picker_row_20')), findsOneWidget);

        await tester.tap(find.byKey(const Key('model_picker_row_20')));
        await tester.pumpAndSettle();

        // Picker closed & selected model updated inside Registrasi Unit Baru
        expect(find.text('Pilih Model Perangkat'), findsNothing);
        expect(
          find.descendant(
            of: find.byKey(const Key('register_unit_model_selector')),
            matching: find.text('iPhone 15 Pro Max'),
          ),
          findsOneWidget,
        );
      },
    );
  });
}

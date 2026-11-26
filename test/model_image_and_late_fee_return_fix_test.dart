import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/constants/api_constants.dart';
import 'package:sewakasir/core/network/api_client.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/presentation/return_wizard_screen.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';

class _TestAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _TestAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _TestAuthRepository extends AuthRepository {
  Map<String, dynamic>? lastPayload;

  @override
  Future<Map<String, dynamic>> updateBusiness(
    int businessId,
    Map<String, dynamic> payload,
  ) async {
    lastPayload = Map<String, dynamic>.from(payload);
    return {'id': businessId, ...payload};
  }
}

class _TestAssetRepository extends AssetRepository {
  final List<Map<String, dynamic>> modelsFixture;

  _TestAssetRepository(this.modelsFixture);

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
  ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async =>
      modelsFixture;

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async => modelsFixture;
}

BusinessState _buildBusinessState({double defaultRate = 15000.0}) {
  return BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'SewaKasir Flagship',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
    businesses: [
      {
        'id': 1,
        'name': 'SewaKasir Flagship',
        'role': 'owner',
        'return_grace_period_minutes': 15,
        'late_fee_grace_minutes': 15,
        'late_fee_grace_mode': 'forfeit',
        'late_fee_rounding_mode': 'hourly_ceil',
        'late_fee_rounding': 'hourly_ceil',
        'cap_late_fee_at_daily_rate': true,
        'late_fee_cap_daily': true,
        'default_hourly_late_fee': defaultRate,
        'late_fee_default_rate': defaultRate,
        'late_fee_default_type': 'fixed',
        'allow_cashier_late_fee_waiver': true,
        'branches': [
          {'id': 1, 'name': 'Cabang Pusat', 'is_central': true},
        ],
      },
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('1. ApiConstants.resolveMediaUrl', () {
    test('resolves relative /storage/ and storage/ paths against active ApiClient base host', () async {
      await ApiClient().updateBaseUrl('http://192.168.1.50:8000/api/v1');

      expect(
        ApiConstants.resolveMediaUrl('/storage/models/iphone-15.jpg'),
        'http://192.168.1.50:8000/storage/models/iphone-15.jpg',
      );
      expect(
        ApiConstants.resolveMediaUrl('storage/models/ps5.png'),
        'http://192.168.1.50:8000/storage/models/ps5.png',
      );
      expect(
        ApiConstants.resolveMediaUrl('models/sony-a7iv.webp'),
        'http://192.168.1.50:8000/storage/models/sony-a7iv.webp',
      );
      expect(
        ApiConstants.resolveMediaUrl(r'public\models\iphone-xr-putih.jpg'),
        'http://192.168.1.50:8000/storage/models/iphone-xr-putih.jpg',
      );
      expect(
        ApiConstants.resolveMediaUrl(
          '/storage/models/iphone-xr.jpg',
          baseUrlOverride: 'https://api.sewakasir.id/api/v1',
        ),
        'https://api.sewakasir.id/storage/models/iphone-xr.jpg',
      );
      expect(
        ApiConstants.resolveMediaUrl(
          '/storage/models/iphone-xr.jpg',
          baseUrlOverride: 'http://192.168.1.50/sewakasir_backend/public/api/v1',
        ),
        'http://192.168.1.50/sewakasir_backend/public/storage/models/iphone-xr.jpg',
      );
    });

    test('rewrites stale rentcore_backend / localhost / 127.0.0.1 origins to active ApiClient host', () async {
      await ApiClient().updateBaseUrl('http://10.0.2.2:8000/api/v1');

      expect(
        ApiConstants.resolveMediaUrl(
          'http://rentcore_backend.test/storage/models/cam.jpg',
        ),
        'http://10.0.2.2:8000/storage/models/cam.jpg',
      );
      expect(
        ApiConstants.resolveMediaUrl(
          'http://127.0.0.1:8000/storage/models/cam.jpg',
        ),
        'http://10.0.2.2:8000/storage/models/cam.jpg',
      );
      expect(
        ApiConstants.resolveMediaUrl('http://localhost/storage/models/cam.jpg'),
        'http://10.0.2.2:8000/storage/models/cam.jpg',
      );
      // Preserves valid external CDN URLs
      expect(
        ApiConstants.resolveMediaUrl('https://cdn.sewakasir.id/models/a7.jpg'),
        'https://cdn.sewakasir.id/models/a7.jpg',
      );
      // Rejects null, empty, and base64 blobs
      expect(ApiConstants.resolveMediaUrl(null), isNull);
      expect(ApiConstants.resolveMediaUrl('   '), isNull);
      expect(
        ApiConstants.resolveMediaUrl('data:image/png;base64,iVBORw0KGgo='),
        isNull,
      );
    });
  });

  group('2. 2-Level Late Fee Hierarchy (Registrasi Unit Baru & Store Settings)', () {
    testWidgets(
      'Registrasi Unit Baru has zero unit-level penalty input and displays inherited model or store late fee rate',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final modelsFixture = [
          {
            'id': 10,
            'brand': 'Sony',
            'name': 'Alpha A7 IV',
            'late_fee_per_hour': 25000.0,
            'hourly_late_fee': 25000.0,
            'has_serial_number': true,
            'pricing_tiers': [
              {'duration_unit': 'day', 'duration_value': 1, 'price': 300000},
            ],
          },
          {
            'id': 11,
            'brand': 'Canon',
            'name': 'EOS R6',
            'late_fee_per_hour': null,
            'hourly_late_fee': null,
            'has_serial_number': true,
            'pricing_tiers': [
              {'duration_unit': 'day', 'duration_value': 1, 'price': 250000},
            ],
          },
        ];

        final assetRepo = _TestAssetRepository(modelsFixture);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              assetRepositoryProvider.overrideWithValue(assetRepo),
              inventoryListProvider.overrideWith((ref) => Future.value([])),
              productsProvider.overrideWith((ref) => Future.value(modelsFixture)),
              allCatalogModelsProvider.overrideWith(
                (ref) => Future.value(modelsFixture),
              ),
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(_buildBusinessState(defaultRate: 15000.0)),
              ),
            ],
            child: const MaterialApp(home: InventoryScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Tap "+ Tambah Unit" on Sony Alpha A7 IV (model override = Rp 25.000/jam)
        await tester.tap(find.text('+ Tambah Unit').first);
        await tester.pumpAndSettle();

        expect(find.text('Registrasi Unit Baru'), findsOneWidget);
        // Zero unit-level penalty input
        expect(find.byKey(const Key('add_unit_hourly_late_fee_input')), findsNothing);
        expect(find.text('Denda / Jam (Opsional)'), findsNothing);
        // Shows read-only inherited model rate chip
        expect(find.byKey(const Key('unit_inherited_late_fee_chip')), findsOneWidget);
        expect(find.text('Tarif Denda Model: Rp 25.000/jam'), findsOneWidget);

        // Switch model to Canon EOS R6 (no model override -> inherits Store Default Rp 15.000/jam)
        await tester.tap(find.byKey(const Key('register_unit_model_selector')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('model_picker_row_11')));
        await tester.pumpAndSettle();

        expect(find.text('Mengikuti Tarif Toko: Rp 15.000/jam'), findsOneWidget);
      },
    );

    testWidgets(
      'StoreSettingsScreen shows 2-level hierarchy helper note and immediately updates BusinessProvider on save',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final authRepo = _TestAuthRepository();
        late ProviderContainer container;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(authRepo),
              authProvider.overrideWith(
                () => _TestAuthNotifier(
                  const AuthState(
                    user: {'id': 'u1', 'name': 'Owner', 'role': 'owner'},
                    isAuthenticated: true,
                  ),
                ),
              ),
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(_buildBusinessState(defaultRate: 15000.0)),
              ),
            ],
            child: Consumer(
              builder: (ctx, ref, _) {
                container = ProviderScope.containerOf(ctx);
                return const MaterialApp(home: StoreSettingsScreen());
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('menu_late_fee_policy')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('late_fee_hierarchy_note')), findsOneWidget);
        expect(
          find.text(
            'Tarif default toko berlaku untuk semua model, kecuali model tersebut memiliki tarif denda khusus di katalog.',
          ),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(const Key('late_fee_default_rate_input')),
          '18000',
        );
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.byKey(const Key('late_fee_save_button')));
        await tester.tap(find.byKey(const Key('late_fee_save_button')));
        await tester.pumpAndSettle();

        // BusinessProvider state is updated immediately in memory
        final updatedBiz = container.read(businessProvider).activeBusiness;
        expect(updatedBiz?['late_fee_default_rate'], 18000.0);
        expect(updatedBiz?['default_hourly_late_fee'], 18000.0);
      },
    );
  });

  group('3. ReturnWizardScreen Non-Zero Late Fee Breakdown', () {
    testWidgets(
      'renders accurate non-zero breakdown from late_fee_breakdown payload and local fallback when snapshot was 0',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        // Case A: Booking overdue 130 minutes with legacy 0.00 snapshot & no preview -> local fallback computes 3h * 25.000 = Rp 75.000
        final overdueBookingZeroSnapshot = <String, dynamic>{
          'id': 801,
          'booking_code': 'SK-FIX-801',
          'status': 'rented',
          'end_at': DateTime.now()
              .subtract(const Duration(minutes: 130))
              .toIso8601String(),
          'customer': {'id': 1, 'name': 'Budi Hartono'},
          'items': [
            {
              'id': 1,
              'item_type': 'primary',
              'status': 'active',
              'applied_hourly_late_fee': 0.0,
              'asset': {
                'id': 10,
                'asset_code': 'CAM-01',
                'model': {
                  'id': 5,
                  'name': 'Sony A7 IV',
                  'late_fee_per_hour': 25000.0,
                },
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(_buildBusinessState(defaultRate: 15000.0)),
              ),
            ],
            child: MaterialApp(
              home: ReturnWizardScreen(booking: overdueBookingZeroSnapshot),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('late_fee_breakdown_card')), findsOneWidget);
        expect(find.byKey(const Key('late_fee_rate_source_row')), findsOneWidget);
        expect(find.byKey(const Key('late_fee_total_row')), findsOneWidget);
        expect(find.text('Tarif Berlaku & Sumber'), findsOneWidget);
        expect(find.text('Total Denda Keterlambatan'), findsOneWidget);
        expect(find.textContaining('Rp 25.000/jam • Tarif Model'), findsOneWidget);
        expect(find.textContaining('75.000'), findsWidgets);
        expect(find.text('Rp 0'), findsNothing);

        // Case B: Booking with authoritative backend late_fee_breakdown key
        final overdueBookingWithBreakdown = <String, dynamic>{
          'id': 802,
          'booking_code': 'SK-FIX-802',
          'status': 'rented',
          'end_at': DateTime.now()
              .subtract(const Duration(minutes: 95))
              .toIso8601String(),
          'customer': {'id': 2, 'name': 'Citra Dewi'},
          'late_fee_breakdown': {
            'is_late': true,
            'raw_overdue_minutes': 95,
            'billable_minutes': 95,
            'billed_units': 2,
            'unit_label': 'jam',
            'billable_hours': 2.0,
            'applied_rate': 15000.0,
            'rate_source': 'business_default',
            'cap_applied': false,
            'calculated_fee': 30000.0,
          },
          'items': [
            {
              'id': 2,
              'item_type': 'primary',
              'status': 'active',
              'asset': {
                'id': 11,
                'asset_code': 'CAM-02',
                'model': {
                  'id': 6,
                  'name': 'Canon R6',
                },
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('breakdown_scope'),
            overrides: [
              businessProvider.overrideWith(
                () => _TestBusinessNotifier(_buildBusinessState(defaultRate: 15000.0)),
              ),
            ],
            child: MaterialApp(
              home: ReturnWizardScreen(booking: overdueBookingWithBreakdown),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Rp 15.000/jam • Tarif Default Toko'),
          findsOneWidget,
        );
        expect(find.textContaining('30.000'), findsWidgets);
      },
    );
  });
}

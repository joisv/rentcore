import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/return_wizard_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/add_product_sheet.dart';
import 'package:sewakasir/features/inventory/presentation/inventory_screen.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';

class _FakeAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _FakeAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _FakeBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeAuthRepository extends AuthRepository {
  int? lastBusinessId;
  Map<String, dynamic>? lastBusinessPayload;

  @override
  Future<Map<String, dynamic>> updateBusiness(
    int businessId,
    Map<String, dynamic> payload,
  ) async {
    lastBusinessId = businessId;
    lastBusinessPayload = Map<String, dynamic>.from(payload);
    return {'id': businessId, ...payload};
  }
}

class _FakeAssetRepository extends AssetRepository {
  Map<String, dynamic>? lastCreatedProduct;
  Map<String, dynamic>? lastCreatedAsset;
  Map<String, dynamic>? lastUpdatedAsset;

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
        {'id': 1, 'name': 'Kamera', 'slug': 'kamera', 'is_addon': false},
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchModels({int? categoryId}) async => [
        {
          'id': 10,
          'brand': 'Sony',
          'name': 'Alpha A7 IV',
          'hourly_late_fee': 25000.0,
          'has_serial_number': true,
          'pricing_tiers': [
            {'duration_unit': 'day', 'duration_value': 1, 'price': 300000},
          ],
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> fetchProducts({
    int? categoryId,
    String? search,
  }) async => fetchModels(categoryId: categoryId);

  @override
  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> payload,
  ) async {
    lastCreatedProduct = Map<String, dynamic>.from(payload);
    return {'id': 99, ...payload};
  }

  @override
  Future<Map<String, dynamic>> createAsset(Map<String, dynamic> payload) async {
    lastCreatedAsset = Map<String, dynamic>.from(payload);
    return {'id': 101, ...payload};
  }

  @override
  Future<Map<String, dynamic>> updateAsset(
    int id,
    Map<String, dynamic> payload,
  ) async {
    lastUpdatedAsset = Map<String, dynamic>.from(payload);
    return {'id': id, ...payload};
  }
}

class _FakeReturnBookingRepository extends BookingRepository {
  int? lastReturnBookingId;
  Map<String, dynamic>? lastReturnPayload;

  @override
  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    lastReturnBookingId = bookingId;
    lastReturnPayload = Map<String, dynamic>.from(payload);
    return {
      'id': 501,
      'booking_id': bookingId,
      'late_fee': payload['late_fee'] ?? 0,
      'total_penalty': payload['total_penalty'] ?? 0,
      'deposit_refunded': 0,
      'booking': {
        'id': bookingId,
        'booking_code': 'RC-LATE-FEE-1',
        'status': 'returned',
      },
    };
  }
}

class _FakeCashierRepository extends CashierRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  BusinessState createBusinessState() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 1,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'role': 'owner',
            'booking_grace_period_minutes': 60,
            'auto_expire_unpaid_booking': true,
            'late_pickup_end_time_mode': 'keep_original_end',
            'return_grace_period_minutes': 15,
            'late_fee_grace_mode': 'deductive',
            'late_fee_rounding_mode': 'hourly_ceil',
            'cap_late_fee_at_daily_rate': true,
            'default_hourly_late_fee': 15000.0,
            'late_fee_default_type': 'fixed',
            'allow_cashier_late_fee_waiver': true,
            'branches': [
              {'id': 1, 'name': 'Cabang Pusat', 'code': 'PST', 'is_central': true},
            ],
          },
        ],
      );

  testWidgets(
    'StoreSettingsScreen opens Aturan Denda Keterlambatan sub-sheet and saves policy',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAuthRepo = _FakeAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeAuthRepo),
            authProvider.overrideWith(
              () => _FakeAuthNotifier(
                const AuthState(
                  user: {'id': 'u-1', 'name': 'Owner', 'role': 'owner'},
                  isAuthenticated: true,
                ),
              ),
            ),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(home: StoreSettingsScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('menu_late_fee_policy')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('late_fee_policy_bottom_sheet')), findsOneWidget);

      await tester.tap(find.byKey(const Key('late_fee_grace_30')));
      await tester.tap(find.byKey(const Key('late_fee_rounding_half')));
      await tester.tap(find.byKey(const Key('late_fee_toggle_daily_cap')));
      await tester.enterText(
        find.byKey(const Key('late_fee_default_rate_input')),
        '22000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('late_fee_save_button')));
      await tester.pumpAndSettle();

      expect(fakeAuthRepo.lastBusinessId, 1);
      expect(fakeAuthRepo.lastBusinessPayload?['return_grace_period_minutes'], 30);
      expect(fakeAuthRepo.lastBusinessPayload?['late_fee_grace_minutes'], 30);
      expect(fakeAuthRepo.lastBusinessPayload?['late_fee_rounding_mode'], 'half_hourly_ceil');
      expect(fakeAuthRepo.lastBusinessPayload?['late_fee_rounding'], 'half_hourly_ceil');
      expect(fakeAuthRepo.lastBusinessPayload?['cap_late_fee_at_daily_rate'], false);
      expect(fakeAuthRepo.lastBusinessPayload?['late_fee_cap_daily'], false);
      expect(fakeAuthRepo.lastBusinessPayload?['default_hourly_late_fee'], 22000.0);
      expect(fakeAuthRepo.lastBusinessPayload?['late_fee_default_rate'], 22000.0);
    },
  );

  testWidgets(
    'AddProductSheet renders Denda Keterlambatan / Jam field',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAssetRepo = _FakeAssetRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetRepositoryProvider.overrideWithValue(fakeAssetRepo),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: AddProductSheet(onSuccess: () {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Denda Keterlambatan / Jam'), findsOneWidget);
      expect(find.byKey(const Key('model_hourly_late_fee_input')), findsOneWidget);
    },
  );

  testWidgets(
    'Inventory Edit Unit shows inherited rate helper and preserves null override',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeAssetRepo = _FakeAssetRepository();
      final sampleAsset = {
        'id': 101,
        'model_id': 10,
        'asset_code': 'CAM-001',
        'serial_number': 'SN-CAM-001',
        'status': 'ready',
        'condition_grade': 'A',
        'hourly_late_fee': null,
        'model': {
          'id': 10,
          'brand': 'Sony',
          'name': 'Alpha A7 IV',
          'hourly_late_fee': 25000.0,
          'has_serial_number': true,
        },
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            assetRepositoryProvider.overrideWithValue(fakeAssetRepo),
            inventoryListProvider.overrideWith((ref) => Future.value([sampleAsset])),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: const MaterialApp(home: InventoryScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('edit_unit_btn_101')));
      await tester.pumpAndSettle();

      expect(find.text('Denda / Jam (Opsional)'), findsOneWidget);
      expect(
        find.textContaining('Kosongkan untuk mengikuti tarif model:'),
        findsOneWidget,
      );
      expect(find.textContaining('25.000'), findsWidgets);

      await tester.ensureVisible(find.text('Simpan Perubahan'));
      await tester.tap(find.text('Simpan Perubahan'));
      await tester.pumpAndSettle();

      expect(fakeAssetRepo.lastUpdatedAsset?['hourly_late_fee'], isNull);
    },
  );

  testWidgets(
    'ReturnWizardScreen shows breakdown formula, requires reason on waiver, and submits waived_late_fee',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeReturnRepo = _FakeReturnBookingRepository();
      final fakeCashierRepo = _FakeCashierRepository();

      // Due 135 minutes ago; grace = 15m -> 120m chargeable = 2 hours @ 25,000 = 50,000
      final overdueBooking = {
        'id': 77,
        'booking_code': 'RC-LATE-FEE-1',
        'status': 'rented',
        'end_at': DateTime.now()
            .subtract(const Duration(minutes: 135))
            .toIso8601String(),
        'customer': {'name': 'Budi Santoso'},
        'items': [
          {
            'id': 901,
            'item_type': 'primary',
            'status': 'active',
            'applied_hourly_late_fee': 25000.0,
            'applied_grace_period_minutes': 15,
            'applied_daily_rate_cap': 300000.0,
            'applied_late_fee_rounding_mode': 'hourly_ceil',
            'asset': {
              'id': 55,
              'asset_code': 'CAM-99',
              'model': {
                'id': 10,
                'name': 'Sony Alpha A7 IV',
                'category': {'name': 'Kamera', 'slug': 'kamera'},
              },
            },
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeReturnRepo),
            cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
            businessProvider.overrideWith(
              () => _FakeBusinessNotifier(createBusinessState()),
            ),
          ],
          child: MaterialApp(home: ReturnWizardScreen(booking: overdueBooking)),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('late_fee_breakdown_formula')),
        findsOneWidget,
      );
      expect(find.textContaining('Toleransi 15 menit = 2 jam'), findsWidgets);
      expect(find.textContaining('50.000'), findsWidgets);

      // Enable waiver and waive 100%
      await tester.ensureVisible(find.byKey(const Key('waiver_toggle')));
      await tester.tap(find.byKey(const Key('waiver_toggle')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('waiver_full_chip')));
      await tester.pumpAndSettle();

      // Submitting without reason shows validation snackbar
      await tester.ensureVisible(find.text('Selesaikan Pengembalian'));
      await tester.tap(find.text('Selesaikan Pengembalian'));
      await tester.pumpAndSettle();

      expect(fakeReturnRepo.lastReturnBookingId, isNull);
      expect(
        find.text('Alasan keringanan / pembebasan denda wajib diisi.'),
        findsOneWidget,
      );

      // Provide reason and submit
      await tester.enterText(
        find.byKey(const Key('waiver_reason_input')),
        'Pelanggan konfirmasi keterlambatan ke admin cabang',
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Selesaikan Pengembalian'));
      await tester.tap(find.text('Selesaikan Pengembalian'));
      await tester.pumpAndSettle();

      expect(fakeReturnRepo.lastReturnBookingId, 77);
      expect(fakeReturnRepo.lastReturnPayload?['waived_late_fee'], 50000.0);
      expect(fakeReturnRepo.lastReturnPayload?['late_fee'], 0.0);
      expect(
        fakeReturnRepo.lastReturnPayload?['late_fee_waive_reason'],
        'Pelanggan konfirmasi keterlambatan ke admin cabang',
      );
    },
  );
}

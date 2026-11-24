import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/presentation/rental_queue_actions.dart';
import 'package:rentcore_mobile/features/bookings/presentation/return_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/collateral_settings_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';

class _FakeCollateralAuthRepository extends AuthRepository {
  bool enableCollateral;
  bool requireCollateral;
  List<Map<String, dynamic>> collateralTypes;
  int saveCalls = 0;

  _FakeCollateralAuthRepository({
    this.enableCollateral = false,
    this.requireCollateral = false,
    List<Map<String, dynamic>>? initialTypes,
  }) : collateralTypes = initialTypes ??
            [
              {
                'id': 'cash_deposit',
                'name': 'Deposit Tunai',
                'input_mode': 'cash_deposit',
                'is_active': true,
              },
              {
                'id': 'ektp',
                'name': 'e-KTP',
                'input_mode': 'vault_slot',
                'is_active': true,
              },
            ];

  @override
  Future<Map<String, dynamic>> getCollateralSettings(int businessId) async => {
        'enable_collateral': enableCollateral,
        'require_collateral': requireCollateral,
        'collateral_types': collateralTypes,
      };

  @override
  Future<Map<String, dynamic>> updateCollateralSettings(
    int businessId, {
    required bool enableCollateral,
    required bool requireCollateral,
    required List<Map<String, dynamic>> collateralTypes,
  }) async {
    saveCalls++;
    this.enableCollateral = enableCollateral;
    this.requireCollateral = requireCollateral;
    this.collateralTypes = collateralTypes;
    return {
      'enable_collateral': enableCollateral,
      'require_collateral': requireCollateral,
      'collateral_types': collateralTypes,
    };
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async => [
        {
          'id': 1,
          'name': 'RentCore Flagship',
          'role': 'owner',
          'enable_collateral': enableCollateral,
          'require_collateral': requireCollateral,
          'collateral_types': collateralTypes,
          'branches': [
            {'id': 10, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
          ],
        },
      ];
}

class _FakeCollateralAuthNotifier extends AuthNotifier {
  final String role = 'owner';

  @override
  AuthState build() => AuthState(
        isAuthenticated: true,
        isLoading: false,
        user: {'id': 'u1', 'name': 'Owner Test', 'role': role},
      );
}

class _FakeCollateralBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeCollateralBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;

  @override
  Future<void> refresh() async {}
}

class _FakeCollateralBookingRepo extends BookingRepository {
  int checkInCalls = 0;
  String? lastCollateralType;
  String? lastCollateralTypeId;
  String? lastCollateralStorageSlot;
  double? lastCollateralDepositAmount;

  @override
  Future<List<Map<String, dynamic>>> fetchAssetsForWindow({
    required int branchId,
    required DateTime startAt,
    required DateTime endAt,
  }) async => [];

  @override
  Future<Map<String, dynamic>> checkInBooking(
    dynamic bookingId, {
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool startNow = false,
    bool keepOriginalEndAt = false,
  }) async {
    checkInCalls++;
    lastCollateralType = collateralType;
    lastCollateralTypeId = collateralTypeId;
    lastCollateralStorageSlot = collateralStorageSlot;
    lastCollateralDepositAmount = collateralDepositAmount;
    return {'id': bookingId, 'status': 'rented'};
  }

  @override
  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async => {
        'id': bookingId,
        'status': 'returned',
        'total_penalty': 0,
      };
}

class _FakeCollateralCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
        'has_active_shift': true,
        'shift': {'id': 1, 'status': 'open'},
      };

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async => [
        {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
      ];
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'StoreSettings shows Nonaktif by default, CollateralSettings hides types until enabled, then saves',
    (tester) async {
      final fakeRepo = _FakeCollateralAuthRepository(
        enableCollateral: false,
        requireCollateral: false,
      );
      final bizState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 10,
        activeBranchName: 'Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'role': 'owner',
            'enable_collateral': false,
            'require_collateral': false,
            'collateral_types': fakeRepo.collateralTypes,
            'branches': [
              {'id': 10, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
            ],
          }
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(fakeRepo),
            authProvider.overrideWith(() => _FakeCollateralAuthNotifier()),
            businessProvider.overrideWith(BusinessNotifier.new),
          ],
          child: const MaterialApp(home: StoreSettingsScreen()),
        ),
      );

      final container = ProviderScope.containerOf(
        tester.element(find.byType(StoreSettingsScreen)),
      );
      await container
          .read(businessProvider.notifier)
          .loadInitialContext(preloadedBusinesses: bizState.businesses);
      await tester.pumpAndSettle();

      // Default OFF entry row under OPERASIONAL KASIR
      final menuFinder = find.byKey(const Key('menu_collateral_settings'));
      await tester.drag(find.byType(ListView).first, const Offset(0, -350));
      await tester.pumpAndSettle();
      expect(find.text('Jaminan & Deposit'), findsOneWidget);
      expect(find.text('Nonaktif'), findsOneWidget);

      await tester.tap(menuFinder);
      await tester.pumpAndSettle();
      expect(find.byType(CollateralSettingsScreen), findsOneWidget);

      // Master toggle OFF: strip visible, require toggle + type list hidden
      expect(find.byKey(const Key('switch_enable_collateral')), findsOneWidget);
      expect(
        find.byKey(const Key('collateral_disabled_status_strip')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('switch_require_collateral')), findsNothing);
      expect(find.byKey(const Key('add_collateral_type_button')), findsNothing);

      // Turn master toggle ON -> reveals Deposit Tunai + require toggle + add button
      await tester.tap(find.byKey(const Key('switch_enable_collateral')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('collateral_disabled_status_strip')),
        findsNothing,
      );
      expect(find.byKey(const Key('switch_require_collateral')), findsOneWidget);
      expect(find.text('Deposit Tunai'), findsAtLeastNWidgets(1));

      // Add custom type: Paspor (note_only)
      await tester.tap(find.byKey(const Key('add_collateral_type_button')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('collateral_type_name_input')),
        'Paspor',
      );
      await tester.tap(find.byKey(const Key('collateral_mode_chip_note_only')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm_collateral_type_button')));
      await tester.pumpAndSettle();

      expect(find.text('Paspor'), findsOneWidget);
      expect(find.text('Catatan / No. ID'), findsOneWidget);

      // Save settings
      await tester.tap(find.byKey(const Key('save_collateral_settings_button')));
      await tester.pumpAndSettle();

      expect(fakeRepo.saveCalls, 1);
      expect(fakeRepo.enableCollateral, isTrue);
      expect(fakeRepo.requireCollateral, isFalse);
      expect(fakeRepo.collateralTypes.length, 3);
      expect(fakeRepo.collateralTypes.last['name'], 'Paspor');
      expect(fakeRepo.collateralTypes.last['input_mode'], 'note_only');
    },
  );

  testWidgets(
    'DirectRentalScreen hides collateral/deposit UI in Step 2 & Step 3 when disabled by default',
    (tester) async {
      final readyAssets = [
        {
          'id': 1,
          'affiliate_id': 10,
          'asset_code': 'PS5-01',
          'status': 'ready',
          'is_addon': false,
          'model': {
            'id': 1,
            'name': 'PlayStation 5',
            'is_addon': false,
            'category_id': 1,
            'category': {'id': 1, 'name': 'Konsol', 'is_addon': false},
            'pricing_tiers': [
              {
                'id': 1,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 150000,
              },
            ],
          },
        },
      ];

      final bizState = const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 10,
        activeBranchName: 'Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'role': 'owner',
            'enable_collateral': false,
            'require_collateral': false,
            'branches': [
              {'id': 10, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
            ],
          }
        ],
      );

      final bookingRepo = _FakeCollateralBookingRepo();
      final cashierRepo = _FakeCollateralCashierRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            paymentRepositoryProvider.overrideWithValue(
              PaymentRepository(cashierRepo: cashierRepo, bookingRepo: bookingRepo),
            ),
            paymentMethodsProvider.overrideWith(
              (ref) => Future.value([
                {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
              ]),
            ),
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(bizState),
            ),
            readyAssetsProvider.overrideWith((ref) => Future.value(readyAssets)),
            readyAssetsByBranchProvider.overrideWith(
              (ref, _) => Future.value(readyAssets),
            ),
            categoriesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Step 1 -> select unit -> Step 2
      await tester.tap(find.text('PlayStation 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      // Collateral inputs completely absent in Step 2
      expect(find.byKey(const Key('step2_collateral_dropdown')), findsNothing);
      expect(find.byKey(const Key('collateral_deposit_amount_input')), findsNothing);
      expect(find.byKey(const Key('collateral_type_pill_none')), findsNothing);
      expect(find.text('Jaminan'), findsNothing);

      await tester.enterText(find.byKey(const Key('step2_name_field')), 'Budi');
      await tester.enterText(
        find.byKey(const Key('step2_phone_field')),
        '081234567890',
      );
      await tester.enterText(
        find.byKey(const Key('step2_address_field')),
        'Jl. Merdeka No. 10 Malang',
      );

      // Step 2 -> Step 3 without collateral
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('RINGKASAN'), findsOneWidget);
      expect(find.text('Jaminan'), findsNothing);
      expect(find.text('Tanpa Jaminan'), findsNothing);
    },
  );

  testWidgets(
    'Serahkan Unit sheet hides collateral inputs and submits null collateral when disabled',
    (tester) async {
      final bookingRepo = _FakeCollateralBookingRepo();
      final cashierRepo = _FakeCollateralCashierRepo();
      final bizState = const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 10,
        activeBranchName: 'Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'enable_collateral': false,
            'require_collateral': false,
          }
        ],
      );

      final booking = {
        'id': 77,
        'booking_code': 'RC-261124-0077',
        'status': 'booked',
        'asset_unit_id': 501,
        'start_at':
            DateTime.now().subtract(const Duration(minutes: 5)).toIso8601String(),
        'end_at': DateTime.now().add(const Duration(hours: 24)).toIso8601String(),
        'total_bill': 150000,
        'paid_amount': 150000,
        'customer': {'id': 7, 'name': 'Andi', 'phone': '0812999888'},
        'items': [],
        'payments': [],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(bizState),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () {
                    RentalQueueActions.handleHandoverUnit(
                      context,
                      ref,
                      booking,
                    );
                  },
                  child: const Text('Buka Serahkan Unit'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Buka Serahkan Unit'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('handover_collateral_field')), findsNothing);
      expect(find.byKey(const Key('collateral_deposit_amount_input')), findsNothing);
      expect(find.textContaining('Tipe Jaminan'), findsNothing);

      await tester.tap(find.byKey(const Key('confirm_checkin_button')));
      await tester.pumpAndSettle();

      expect(bookingRepo.checkInCalls, 1);
      expect(bookingRepo.lastCollateralType, isNull);
      expect(bookingRepo.lastCollateralTypeId, isNull);
      expect(bookingRepo.lastCollateralStorageSlot, isNull);
      expect(bookingRepo.lastCollateralDepositAmount, isNull);
    },
  );

  testWidgets(
    'DirectRentalScreen shows Deposit Tunai & Tanpa Jaminan flow when enable_collateral is true',
    (tester) async {
      final readyAssets = [
        {
          'id': 1,
          'affiliate_id': 10,
          'asset_code': 'PS5-01',
          'status': 'ready',
          'is_addon': false,
          'model': {
            'id': 1,
            'name': 'PlayStation 5',
            'is_addon': false,
            'category_id': 1,
            'category': {'id': 1, 'name': 'Konsol', 'is_addon': false},
            'pricing_tiers': [
              {
                'id': 1,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 150000,
              },
            ],
          },
        },
      ];

      final bizState = const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Flagship',
        activeBranchId: 10,
        activeBranchName: 'Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Flagship',
            'role': 'owner',
            'enable_collateral': true,
            'require_collateral': false,
            'collateral_types': [
              {
                'id': 'ektp',
                'name': 'e-KTP',
                'input_mode': 'vault_slot',
                'is_active': true,
              },
              {
                'id': 'cash_deposit',
                'name': 'Deposit Tunai',
                'input_mode': 'cash_deposit',
                'is_active': true,
              },
            ],
            'branches': [
              {'id': 10, 'name': 'Pusat', 'code': 'PST', 'is_central': true},
            ],
          }
        ],
      );

      final bookingRepo = _FakeCollateralBookingRepo();
      final cashierRepo = _FakeCollateralCashierRepo();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            paymentRepositoryProvider.overrideWithValue(
              PaymentRepository(cashierRepo: cashierRepo, bookingRepo: bookingRepo),
            ),
            paymentMethodsProvider.overrideWith(
              (ref) => Future.value([
                {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
              ]),
            ),
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(bizState),
            ),
            readyAssetsProvider.overrideWith((ref) => Future.value(readyAssets)),
            readyAssetsByBranchProvider.overrideWith(
              (ref, _) => Future.value(readyAssets),
            ),
            categoriesProvider.overrideWith((ref) => Future.value([])),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(showAppBar: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('PlayStation 5'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('step2_name_field')), 'Budi');
      await tester.enterText(
        find.byKey(const Key('step2_phone_field')),
        '081234567890',
      );
      await tester.enterText(
        find.byKey(const Key('step2_address_field')),
        'Jl. Merdeka No. 10 Malang',
      );

      // e-KTP shows Slot Brankas dropdown
      expect(find.byKey(const Key('step2_collateral_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('collateral_type_pill_none')), findsOneWidget);

      // Tap Deposit Tunai -> shows Nominal Deposit Tunai (Rp)
      await tester.tap(find.byKey(const Key('collateral_type_pill_cash_deposit')));
      await tester.pumpAndSettle();
      expect(find.text('Nominal Deposit Tunai (Rp) *'), findsOneWidget);
      expect(
        find.byKey(const Key('collateral_deposit_amount_input')),
        findsOneWidget,
      );

      await tester.enterText(
        find.byKey(const Key('collateral_deposit_amount_input')),
        '200000',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Deposit Tunai • Rp 200.000'), findsOneWidget);

      // Back to Step 2 -> select Tanpa Jaminan -> Step 3 shows Tanpa Jaminan
      await tester.tap(find.text('Kembali'));
      await tester.pumpAndSettle();
      final nonePill = find.byKey(const Key('collateral_type_pill_none'));
      await tester.ensureVisible(nonePill);
      await tester.pumpAndSettle();
      await tester.tap(nonePill);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Tanpa Jaminan'), findsOneWidget);
    },
  );

  testWidgets(
    'PosTransactionDetailSheet and ReturnWizardScreen hide collateral when disabled & no record, preserve historical deposit records',
    (tester) async {
      final disabledBiz = const BusinessState(
        activeBusinessId: 1,
        activeBranchId: 10,
        businesses: [
          {'id': 1, 'enable_collateral': false, 'require_collateral': false},
        ],
      );
      final bookingRepo = _FakeCollateralBookingRepo();

      final bookingNoCollateral = {
        'id': 41,
        'booking_code': 'RC-261124-0041',
        'status': 'rented',
        'start_at':
            DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'end_at':
            DateTime.now().add(const Duration(hours: 22)).toIso8601String(),
        'duration_hours': 24,
        'total_bill': 150000,
        'subtotal_amount': 150000,
        'customer': {'id': 7, 'name': 'Siti', 'phone': '081234567890'},
        'items': [],
        'payments': [],
      };

      // 1a. PosTransactionDetailSheet omits Jaminan row when disabled & no record
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(disabledBiz),
            ),
            bookingDetailProvider(41)
                .overrideWith((ref) => Future.value(bookingNoCollateral)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PosTransactionDetailSheet(booking: bookingNoCollateral),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jaminan'), findsNothing);
      expect(find.text('Tanpa Jaminan'), findsNothing);

      // 1b. ReturnWizardScreen + Unit Berhasil Kembali dialog omit collateral rows & reminders
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(disabledBiz),
            ),
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
          ],
          child: MaterialApp(
            home: ReturnWizardScreen(booking: bookingNoCollateral),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jaminan'), findsNothing);
      expect(find.text('Tanpa Jaminan'), findsNothing);
      expect(find.textContaining('Kembalikan jaminan'), findsNothing);
      expect(find.textContaining('Kembalikan deposit'), findsNothing);

      final finishReturnBtn1 = find.text('Selesaikan Pengembalian');
      await tester.ensureVisible(finishReturnBtn1);
      await tester.pumpAndSettle();
      await tester.tap(finishReturnBtn1);
      await tester.pumpAndSettle();
      expect(find.text('Unit Berhasil Kembali'), findsOneWidget);
      expect(find.textContaining('Kembalikan jaminan'), findsNothing);
      expect(find.textContaining('Kembalikan deposit'), findsNothing);
      expect(find.textContaining('Sewa tanpa jaminan'), findsNothing);

      // 2. Historical record with cash deposit still displays even when enable_collateral is false
      final bookingWithDeposit = {
        ...bookingNoCollateral,
        'id': 42,
        'booking_code': 'RC-261124-0042',
        'collateral_type_id': 'cash_deposit',
        'collateral_type_name': 'Deposit Tunai',
        'collateral_type': 'Deposit Tunai',
        'collateral_deposit_amount': 200000,
      };

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(disabledBiz),
            ),
            bookingDetailProvider(42)
                .overrideWith((ref) => Future.value(bookingWithDeposit)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PosTransactionDetailSheet(booking: bookingWithDeposit),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Deposit Tunai • Rp 200.000'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(
              () => _FakeCollateralBusinessNotifier(disabledBiz),
            ),
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
          ],
          child: MaterialApp(
            home: ReturnWizardScreen(booking: bookingWithDeposit),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Jaminan: Deposit Tunai • Rp 200.000'), findsOneWidget);
      expect(
        find.text('Kembalikan deposit: Deposit Tunai • Rp 200.000'),
        findsOneWidget,
      );

      final finishReturnBtn2 = find.text('Selesaikan Pengembalian');
      await tester.ensureVisible(finishReturnBtn2);
      await tester.pumpAndSettle();
      await tester.tap(finishReturnBtn2);
      await tester.pumpAndSettle();
      expect(find.text('Unit Berhasil Kembali'), findsOneWidget);
      expect(find.textContaining('Kembalikan deposit tunai:'), findsOneWidget);
      expect(find.textContaining('200.000'), findsAtLeastNWidgets(1));
    },
  );
}

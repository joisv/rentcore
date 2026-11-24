import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/exchange_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _StaticAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: {
      'id': 'owner-1',
      'name': 'Owner Hadi',
      'email': 'owner@rentcore.id',
      'role': 'owner',
    },
    isAuthenticated: true,
  );
}

class _StaticBusinessNotifier extends BusinessNotifier {
  final BusinessState _state;
  _StaticBusinessNotifier(this._state);

  @override
  BusinessState build() => _state;
}

class _QrisGuardCashierRepo extends CashierRepository {
  Map<String, dynamic> settingsData;
  List<Map<String, dynamic>> methods;

  _QrisGuardCashierRepo({
    required this.settingsData,
    required this.methods,
  });

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
    'has_active_shift': true,
    'shift': {'id': 1, 'branch_id': branchId ?? 1, 'status': 'open'},
  };

  @override
  Future<Map<String, dynamic>> fetchPaymentSettings({int? branchId}) async =>
      settingsData;

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({
    int? branchId,
  }) async => methods;

  @override
  Future<Map<String, dynamic>> updatePaymentSettings(dynamic payload) async =>
      settingsData;
}

class _SpyQrisPaymentRepo extends PaymentRepository {
  int? lastPaymentMethodId;
  String? lastPaymentMethodCode;
  String? lastPaymentMethodName;

  _SpyQrisPaymentRepo({required CashierRepository cashierRepo})
    : super(cashierRepo: cashierRepo);

  @override
  Future<PaymentResult> executePayment({
    required PaymentContext context,
    required int? paymentMethodId,
    required String paymentMethodCode,
    required String paymentMethodName,
    required double amountToPay,
    required double cashReceived,
    String? notes,
    String? externalReference,
    String? idempotencyKey,
  }) async {
    lastPaymentMethodId = paymentMethodId;
    lastPaymentMethodCode = paymentMethodCode;
    lastPaymentMethodName = paymentMethodName;
    return PaymentResult(
      status: PaymentStatus.completed,
      transactionCode: 'TX-QRIS-001',
      receiptNumber: 'RCP-QRIS-001',
      amountPaid: amountToPay,
      cashReceived: cashReceived,
      cashChange: 0.0,
      paymentMethodCode: paymentMethodCode,
      paymentMethodName: paymentMethodName,
    );
  }
}

class _FakeExchangeBookingRepo extends BookingRepository {
  @override
  Future<Map<String, dynamic>> fetchAvailableReplacements(
    dynamic bookingId, {
    dynamic assetId,
  }) async {
    return {
      'current_asset': {'asset_id': 10, 'model_name': 'Unit Lama', 'asset_code': 'U-10'},
      'candidates': [
        {
          'asset_id': 20,
          'asset_code': 'U-20',
          'condition_grade': 'A',
          'calculated_rate': 150000,
          'model': {'name': 'Unit Upgrade Pro'},
          'tier_category': 'upgrade',
          'price_differential': 50000,
        },
      ],
    };
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('BusinessState.isQrisPaymentAvailable computed getter', () {
    test('returns false when qris is enabled without uploaded image', () {
      const state = BusinessState(
        activeBusinessId: 1,
        businesses: [
          {
            'id': 1,
            'name': 'RentCore',
            'payment_methods_config': {
              'qris_statis_enabled': true,
              'qris_image_url': null,
            },
          },
        ],
      );

      expect(state.isQrisEnabled, isTrue);
      expect(state.hasQrisImage, isFalse);
      expect(state.isQrisPaymentAvailable, isFalse);
    });

    test('returns false when qris image exists but qris is disabled', () {
      const state = BusinessState(
        activeBusinessId: 1,
        businesses: [
          {
            'id': 1,
            'name': 'RentCore',
            'qris_image_url': 'http://rentcore.test/qris.png',
            'payment_methods_config': {
              'qris_statis_enabled': false,
              'is_qris_enabled': false,
            },
          },
        ],
      );

      expect(state.hasQrisImage, isTrue);
      expect(state.isQrisEnabled, isFalse);
      expect(state.isQrisPaymentAvailable, isFalse);
    });

    test('returns true only when both qris is enabled and image is uploaded', () {
      const state = BusinessState(
        activeBusinessId: 1,
        businesses: [
          {
            'id': 1,
            'name': 'RentCore',
            'qris_image_url': 'http://rentcore.test/qris.png',
            'payment_methods_config': {
              'qris_statis_enabled': true,
            },
          },
        ],
      );

      expect(state.hasQrisImage, isTrue);
      expect(state.isQrisEnabled, isTrue);
      expect(state.isQrisPaymentAvailable, isTrue);
    });
  });

  group('PaymentMethodSettingsScreen QRIS image guards', () {
    testWidgets(
      'Disables QRIS Statis & Dinamis switches and shows banner when no QRIS image is uploaded',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _QrisGuardCashierRepo(
          methods: const [],
          settingsData: {
            'business_id': 1,
            'branch_id': null,
            'is_branch_override': false,
            'is_owner_or_admin': true,
            'config': {
              'qris_statis_enabled': true,
              'is_dynamic_qris_enabled': true,
              'qris_raw_payload': '0002010102116304ABCD',
              'qris_image_path': null,
              'qris_image_url': null,
              'cash_enabled': true,
              'ewallet_enabled': true,
              'bank_transfer_enabled': true,
            },
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentSettingsProvider(null)
                  .overrideWith((ref) => Future.value(fakeRepo.settingsData)),
              authProvider.overrideWith(_StaticAuthNotifier.new),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'RentCore',
                    businesses: [
                      {'id': 1, 'name': 'RentCore', 'role': 'owner'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: PaymentMethodSettingsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        final staticSwitch = tester.widget<Switch>(
          find.byKey(const Key('qris_statis_toggle')),
        );
        expect(staticSwitch.value, isFalse);
        expect(staticSwitch.onChanged, isNull);

        final dynamicSwitch = tester.widget<Switch>(
          find.byKey(const Key('is_dynamic_qris_enabled_toggle')),
        );
        expect(dynamicSwitch.value, isFalse);
        expect(dynamicSwitch.onChanged, isNull);

        expect(
          find.byKey(const Key('qris_upload_required_banner')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Unggah gambar barcode QRIS terlebih dahulu untuk mengaktifkan pembayaran QRIS.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Deleting uploaded QRIS image automatically turns off and disables both QRIS switches',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _QrisGuardCashierRepo(
          methods: const [],
          settingsData: {
            'business_id': 1,
            'branch_id': null,
            'is_branch_override': false,
            'is_owner_or_admin': true,
            'config': {
              'qris_statis_enabled': true,
              'is_dynamic_qris_enabled': true,
              'qris_raw_payload': '0002010102116304ABCD',
              'qris_image_path': 'qris/merchant.png',
              'qris_image_url': 'http://rentcore.test/qris.png',
              'cash_enabled': true,
              'ewallet_enabled': true,
              'bank_transfer_enabled': true,
            },
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentSettingsProvider(null)
                  .overrideWith((ref) => Future.value(fakeRepo.settingsData)),
              authProvider.overrideWith(_StaticAuthNotifier.new),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'RentCore',
                    businesses: [
                      {'id': 1, 'name': 'RentCore', 'role': 'owner'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: PaymentMethodSettingsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Initially unlocked and ON when image exists
        var staticSwitch = tester.widget<Switch>(
          find.byKey(const Key('qris_statis_toggle')),
        );
        var dynamicSwitch = tester.widget<Switch>(
          find.byKey(const Key('is_dynamic_qris_enabled_toggle')),
        );
        expect(staticSwitch.value, isTrue);
        expect(staticSwitch.onChanged, isNotNull);
        expect(dynamicSwitch.value, isTrue);
        expect(dynamicSwitch.onChanged, isNotNull);

        // Tap Hapus to delete existing QRIS barcode image
        await tester.ensureVisible(find.text('Hapus'));
        await tester.tap(find.text('Hapus'));
        await tester.pumpAndSettle();

        staticSwitch = tester.widget<Switch>(
          find.byKey(const Key('qris_statis_toggle')),
        );
        dynamicSwitch = tester.widget<Switch>(
          find.byKey(const Key('is_dynamic_qris_enabled_toggle')),
        );
        expect(staticSwitch.value, isFalse);
        expect(staticSwitch.onChanged, isNull);
        expect(dynamicSwitch.value, isFalse);
        expect(dynamicSwitch.onChanged, isNull);
        expect(
          find.byKey(const Key('qris_upload_required_banner')),
          findsOneWidget,
        );
      },
    );
  });

  group('Checkout PaymentPage QRIS selection & unconfigured guard', () {
    testWidgets(
      'Disables QRIS card with QRIS belum diunggah and skips QRIS default when image is missing',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final settings = {
          'config': {
            'cash_enabled': false,
            'qris_statis_enabled': true,
            'qris_image_url': null,
            'qris_image_path': null,
            'bank_transfer_enabled': true,
            'ewallet_enabled': true,
          },
        };
        final cashierRepo = _QrisGuardCashierRepo(
          settingsData: settings,
          methods: const [
            {'id': 1, 'code': 'SHOPEEPAY', 'name': 'ShopeePay', 'is_active': true},
            {'id': 2, 'code': 'TRANSFER', 'name': 'Transfer Bank', 'is_active': true},
          ],
        );
        final paymentRepo = _SpyQrisPaymentRepo(cashierRepo: cashierRepo);

        final ctx = PaymentContext.booking(
          customerName: 'Andi',
          customerPhone: '08123456789',
          deviceName: 'Sony A7',
          totalAmount: 150000,
          branchId: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(cashierRepo),
              paymentRepositoryProvider.overrideWithValue(paymentRepo),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(settings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: ctx)),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.byKey(const Key('payment_method_card_qris')), findsOneWidget);
        expect(find.text('QRIS belum diunggah'), findsOneWidget);

        // Tapping disabled QRIS must not open QRIS sheet or pay
        await tester.tap(find.byKey(const Key('payment_method_card_qris')));
        await tester.pumpAndSettle();
        expect(find.text('QRIS STATIS'), findsNothing);
        expect(paymentRepo.lastPaymentMethodCode, isNull);
      },
    );

    testWidgets(
      'Selecting QRIS sends QRIS (never ShopeePay ID 1) even when SHOPEEPAY is id 1 and QRIS row is missing from cache',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final settings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'qris_image_url': 'http://rentcore.test/qris.png',
            'bank_transfer_enabled': true,
            'ewallet_enabled': true,
          },
        };
        // Reproduces legacy production DB state where e-wallet migration seeded SHOPEEPAY at id=1
        // without seeding QRIS/CASH in payment_methods.
        final cashierRepo = _QrisGuardCashierRepo(
          settingsData: settings,
          methods: const [
            {'id': 1, 'code': 'SHOPEEPAY', 'name': 'ShopeePay', 'is_active': true},
            {'id': 2, 'code': 'DANA', 'name': 'DANA', 'is_active': true},
          ],
        );
        final paymentRepo = _SpyQrisPaymentRepo(cashierRepo: cashierRepo);

        final ctx = PaymentContext.booking(
          customerName: 'Rina',
          customerPhone: '08123456789',
          deviceName: 'iPhone 15 Pro',
          totalAmount: 200000,
          branchId: 1,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(cashierRepo),
              paymentRepositoryProvider.overrideWithValue(paymentRepo),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(settings)),
            ],
            child: MaterialApp(home: PaymentPage(paymentContext: ctx)),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('payment_method_card_qris')));
        await tester.pumpAndSettle();

        expect(find.text('QRIS STATIS'), findsOneWidget);

        final processBtn = find.byKey(const Key('qris_sheet_process_button'));
        await tester.ensureVisible(processBtn);
        await tester.pumpAndSettle();
        await tester.tap(processBtn);
        await tester.pumpAndSettle();

        // Must record explicit QRIS code and NEVER fall back to id=1 (SHOPEEPAY)
        expect(paymentRepo.lastPaymentMethodCode, 'QRIS');
        expect(paymentRepo.lastPaymentMethodName, 'QRIS');
        expect(paymentRepo.lastPaymentMethodId, isNull);
        expect(find.text('ShopeePay'), findsNothing);
      },
    );
  });

  group('ExchangeWizardScreen QRIS disabled state without image', () {
    testWidgets(
      'Marks QRIS dropdown item disabled and auto-selects Tunai when QRIS image is unconfigured',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final settings = {
          'config': {
            'cash_enabled': true,
            'qris_statis_enabled': true,
            'qris_image_url': null,
            'qris_image_path': null,
          },
        };
        final cashierRepo = _QrisGuardCashierRepo(
          settingsData: settings,
          methods: const [
            {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'is_active': true},
            {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(_FakeExchangeBookingRepo()),
              cashierRepositoryProvider.overrideWithValue(cashierRepo),
              paymentSettingsProvider(1)
                  .overrideWith((ref) => Future.value(settings)),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'RentCore',
                    activeBranchId: 1,
                    activeBranchName: 'Cabang Pusat',
                    businesses: [
                      {'id': 1, 'name': 'RentCore', 'role': 'owner'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              home: ExchangeWizardScreen(
                booking: {
                  'id': 55,
                  'booking_code': 'BK-EX-55',
                  'customer': {'name': 'Doni'},
                  'items': [
                    {
                      'asset_id': 10,
                      'asset': {
                        'id': 10,
                        'asset_code': 'U-10',
                        'model': {'name': 'Unit Lama', 'requires_frp_check': false},
                      },
                    },
                  ],
                },
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Step 0 -> enter complaint and advance
        await tester.enterText(find.byType(TextField).first, 'Tombol macet');
        await tester.tap(find.text('Lanjut ➔'));
        await tester.pumpAndSettle();

        // Step 1 -> select candidate and advance
        await tester.tap(find.textContaining('Unit Upgrade Pro'));
        await tester.tap(find.text('Lanjut ➔'));
        await tester.pumpAndSettle();

        // Step 2 -> Dropdown must select CASH (1) and render QRIS item disabled
        final dropdown = tester.widget<DropdownButton<int>>(
          find.byType(DropdownButton<int>),
        );
        expect(dropdown.value, 1);

        final qrisItem = dropdown.items!.firstWhere((i) => i.value == 2);
        expect(qrisItem.enabled, isFalse);

        await tester.tap(find.byType(DropdownButton<int>));
        await tester.pumpAndSettle();
        expect(find.text('QRIS — QRIS belum diunggah'), findsWidgets);
      },
    );
  });
}

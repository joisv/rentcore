import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/models/receipt_document_data.dart';
import 'package:sewakasir/core/services/thermal_receipt_escpos_builder.dart';
import 'package:sewakasir/core/widgets/unified_thermal_receipt_preview.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/return_wizard_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/presentation/add_product_sheet.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';

class _CapturingAuthRepo extends AuthRepository {
  Map<String, dynamic>? lastBusinessPayload;
  int? lastBusinessId;

  @override
  Future<Map<String, dynamic>> updateBusiness(
    int id,
    Map<String, dynamic> data,
  ) async {
    lastBusinessId = id;
    lastBusinessPayload = Map<String, dynamic>.from(data);
    return {'id': id, ...data};
  }
}

class _CapturingBookingRepo extends BookingRepository {
  Map<String, dynamic>? lastReturnPayload;

  @override
  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> returnData, {
    String? idempotencyKey,
  }) async {
    lastReturnPayload = Map<String, dynamic>.from(returnData);
    return {
      'id': 901,
      'booking_id': bookingId,
      'calculated_late_fee': 40000.0,
      'waived_late_fee': returnData['waived_late_fee'] ?? 0.0,
      'late_fee': returnData['final_late_fee'] ?? returnData['late_fee'] ?? 0.0,
      'total_penalty':
          returnData['final_late_fee'] ?? returnData['late_fee'] ?? 0.0,
      'late_fee_waiver_reason': returnData['late_fee_waiver_reason'],
    };
  }
}

class _CapturingAssetRepo extends AssetRepository {
  Map<String, dynamic>? lastCreatedProductPayload;

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [
    {'id': 1, 'name': 'Kamera', 'slug': 'kamera'},
  ];

  @override
  Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> payload,
  ) async {
    lastCreatedProductPayload = Map<String, dynamic>.from(payload);
    return {'id': 501, ...payload};
  }
}

class _StubBusinessNotifier extends BusinessNotifier {
  final BusinessState _state;
  _StubBusinessNotifier(this._state);

  @override
  BusinessState build() => _state;

  @override
  Future<void> refresh() async {}
}

BusinessState _makeBusinessState({
  String role = 'owner',
  Map<String, dynamic>? extraPolicy,
}) {
  final biz = <String, dynamic>{
    'id': 1,
    'name': 'SewaKasir Flagship',
    'code': 'SK-01',
    'role': role,
    'return_grace_period_minutes': 15,
    'late_fee_grace_minutes': 15,
    'late_fee_grace_mode': 'forfeit',
    'late_fee_rounding_mode': 'hourly_ceil',
    'late_fee_rounding': 'hourly_ceil',
    'cap_late_fee_at_daily_rate': true,
    'late_fee_cap_daily': true,
    'default_hourly_late_fee': 15000,
    'late_fee_default_rate': 15000,
    'late_fee_default_type': 'fixed',
    'allow_cashier_late_fee_waiver': true,
    'branches': [
      {
        'id': 1,
        'name': 'Cabang Utama',
        'address': 'Jl. Sudirman No. 1',
        'phone': '081234567890',
        'is_central': true,
      },
    ],
    ...?extraPolicy,
  };

  return BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'SewaKasir Flagship',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
    businesses: [biz],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Late Fee Engine UI & Receipt Integration Tests', () {
    testWidgets(
      'StoreSettingsScreen Aturan Denda sheet persists forfeit/exact_minute/percent_daily/cashier waiver toggle',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final authRepo = _CapturingAuthRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(authRepo),
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(_makeBusinessState()),
              ),
            ],
            child: const MaterialApp(home: StoreSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final lateFeeTile = find.text('Aturan Denda Keterlambatan');
        await tester.ensureVisible(lateFeeTile);
        await tester.tap(lateFeeTile);
        await tester.pumpAndSettle();

        // Select 10 min grace, Forfeit mode, Exact minute rounding, % Tarif Harian, rate 10, disable cashier waiver
        await tester.tap(find.byKey(const Key('late_fee_grace_10')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('late_fee_grace_mode_forfeit')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('late_fee_rounding_exact')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('late_fee_default_type_percent')));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(const Key('late_fee_default_rate_input')),
          '10',
        );
        await tester.pumpAndSettle();

        final allowWaiverSwitch = find.byKey(
          const Key('late_fee_toggle_allow_waiver'),
        );
        await tester.ensureVisible(allowWaiverSwitch);
        await tester.tap(allowWaiverSwitch);
        await tester.pumpAndSettle();

        final saveBtn = find.byKey(const Key('late_fee_save_button'));
        await tester.ensureVisible(saveBtn);
        await tester.tap(saveBtn);
        await tester.pumpAndSettle();

        expect(authRepo.lastBusinessId, 1);
        expect(authRepo.lastBusinessPayload, isNotNull);
        expect(authRepo.lastBusinessPayload!['late_fee_grace_minutes'], 10);
        expect(authRepo.lastBusinessPayload!['late_fee_grace_mode'], 'forfeit');
        expect(authRepo.lastBusinessPayload!['late_fee_rounding'], 'exact_minute');
        expect(authRepo.lastBusinessPayload!['late_fee_default_type'], 'percent_daily');
        expect(authRepo.lastBusinessPayload!['late_fee_default_rate'], 10.0);
        expect(authRepo.lastBusinessPayload!['allow_cashier_late_fee_waiver'], false);
      },
    );

    testWidgets(
      'ReturnWizardScreen displays transparent #F8FAFC breakdown card with forfeit mode and model rate source',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final booking = <String, dynamic>{
          'id': 301,
          'booking_code': 'SK-LATE-301',
          'status': 'rented',
          'end_at': DateTime.now()
              .subtract(const Duration(minutes: 70))
              .toIso8601String(),
          'customer': {'id': 1, 'name': 'Sinta Dewi'},
          'items': [
            {
              'id': 11,
              'item_type': 'primary',
              'status': 'active',
              'asset': {
                'id': 20,
                'asset_code': 'CAM-01',
                'model': {
                  'id': 5,
                  'name': 'Sony A7 IV',
                  'late_fee_per_hour': 20000,
                },
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(_makeBusinessState()),
              ),
            ],
            child: MaterialApp(home: ReturnWizardScreen(booking: booking)),
          ),
        );
        await tester.pumpAndSettle();

        final cardFinder = find.byKey(const Key('late_fee_breakdown_card'));
        expect(cardFinder, findsOneWidget);
        final cardContainer = tester.widget<Container>(cardFinder);
        final decoration = cardContainer.decoration! as BoxDecoration;
        expect(decoration.color, const Color(0xFFF8FAFC));

        expect(find.text('Jadwal Kembali'), findsOneWidget);
        expect(find.text('Waktu Aktual'), findsOneWidget);
        expect(find.text('Durasi Terlambat'), findsOneWidget);
        expect(find.text('Perhitungan'), findsOneWidget);
        expect(find.text('Denda Keterlambatan'), findsOneWidget);

        // 70 mins in forfeit mode with hourly_ceil -> 2 jam x Rp 20.000 = Rp 40.000 • Tarif Model
        final formulaWidget = tester.widget<Text>(
          find.byKey(const Key('late_fee_breakdown_formula')),
        );
        expect(formulaWidget.data, contains('2 jam'));
        expect(formulaWidget.data, contains('20.000'));
        expect(formulaWidget.data, contains('Tarif Model'));
        expect(find.textContaining('40.000'), findsWidgets);
      },
    );

    testWidgets(
      'ReturnWizardScreen hides waiver controls for staff when allow_cashier_late_fee_waiver is false, but allows Owner',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final booking = <String, dynamic>{
          'id': 302,
          'booking_code': 'SK-GUARD-302',
          'status': 'rented',
          'end_at': DateTime.now()
              .subtract(const Duration(minutes: 70))
              .toIso8601String(),
          'customer': {'id': 2, 'name': 'Budi'},
          'items': [
            {
              'id': 12,
              'item_type': 'primary',
              'status': 'active',
              'asset': {
                'id': 21,
                'asset_code': 'PS5-01',
                'model': {
                  'id': 6,
                  'name': 'PlayStation 5',
                  'late_fee_per_hour': 20000,
                },
              },
            },
          ],
        };

        // 1. Staff with allow_cashier_late_fee_waiver = false
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('staff_scope'),
            overrides: [
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(
                  _makeBusinessState(
                    role: 'staff',
                    extraPolicy: {'allow_cashier_late_fee_waiver': false},
                  ),
                ),
              ),
            ],
            child: MaterialApp(home: ReturnWizardScreen(booking: booking)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('waiver_toggle')), findsNothing);
        expect(find.byKey(const Key('waiver_owner_only_notice')), findsOneWidget);

        // 2. Owner with allow_cashier_late_fee_waiver = false -> STILL ALLOWED
        await tester.pumpWidget(
          ProviderScope(
            key: const ValueKey('owner_scope'),
            overrides: [
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(
                  _makeBusinessState(
                    role: 'owner',
                    extraPolicy: {'allow_cashier_late_fee_waiver': false},
                  ),
                ),
              ),
            ],
            child: MaterialApp(home: ReturnWizardScreen(booking: booking)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('waiver_toggle')), findsOneWidget);
        expect(find.byKey(const Key('waiver_owner_only_notice')), findsNothing);
      },
    );

    testWidgets(
      'ReturnWizardScreen quick reason chip populates waiver reason, submits canonical payload, and renders UnifiedThermalReceiptPreview',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final bookingRepo = _CapturingBookingRepo();
        final booking = <String, dynamic>{
          'id': 303,
          'booking_code': 'SK-WAIVE-303',
          'status': 'rented',
          'end_at': DateTime.now()
              .subtract(const Duration(minutes: 70))
              .toIso8601String(),
          'customer': {'id': 3, 'name': 'Rina'},
          'items': [
            {
              'id': 13,
              'item_type': 'primary',
              'status': 'active',
              'asset': {
                'id': 22,
                'asset_code': 'CAM-02',
                'model': {
                  'id': 7,
                  'name': 'Canon R6',
                  'late_fee_per_hour': 20000,
                },
              },
            },
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookingRepositoryProvider.overrideWithValue(bookingRepo),
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(_makeBusinessState(role: 'staff')),
              ),
            ],
            child: MaterialApp(home: ReturnWizardScreen(booking: booking)),
          ),
        );
        await tester.pumpAndSettle();

        // Enable waiver & tap 100% waive + quick reason chip "Macet / Hujan"
        await tester.ensureVisible(find.byKey(const Key('waiver_toggle')));
        await tester.tap(find.byKey(const Key('waiver_toggle')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('waiver_full_chip')));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('waiver_reason_chip_macet')));
        await tester.pumpAndSettle();

        final submitBtn = find.text('Selesaikan Pengembalian');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(bookingRepo.lastReturnPayload, isNotNull);
        expect(bookingRepo.lastReturnPayload!['final_late_fee'], 0.0);
        expect(bookingRepo.lastReturnPayload!['waived_late_fee'], 40000.0);
        expect(
          bookingRepo.lastReturnPayload!['late_fee_waiver_reason'],
          'Macet / Hujan',
        );

        // Tap Cetak Bukti to open UnifiedThermalReceiptPreview with late fee & waiver lines
        expect(find.text('Unit Berhasil Kembali'), findsOneWidget);
        await tester.tap(find.text('Cetak Bukti'));
        await tester.pumpAndSettle();

        final receiptPreview = find.byType(UnifiedThermalReceiptPreview);
        expect(receiptPreview, findsOneWidget);
        expect(
          find.descendant(
            of: receiptPreview,
            matching: find.textContaining('Denda Telat'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: receiptPreview,
            matching: find.textContaining('Keringanan Denda'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: receiptPreview,
            matching: find.textContaining('Macet / Hujan'),
          ),
          findsOneWidget,
        );
      },
    );

    test(
      'ThermalReceiptEscPosBuilder prints late fee, waiver discount, and reason matching preview',
      () {
        final doc = ReceiptDocumentData(
          storeName: 'SewaKasir Flagship',
          branchName: 'Cabang Utama',
          title: 'BUKTI PENGEMBALIAN UNIT',
          transactionCode: 'SK-WAIVE-303',
          printedAt: '25 Nov 2026 18:30',
          cashierName: 'Kasir',
          customerName: 'Rina',
          items: const [
            ReceiptDocumentItem(
              name: 'Canon R6',
              variantOrCode: 'CAM-02',
              unitPrice: 0,
              totalPrice: 0,
            ),
          ],
          subtotal: 0,
          penaltyAmount: 10000,
          calculatedLateFee: 40000,
          waivedLateFee: 30000,
          lateFeeWaiverReason: 'Macet / Hujan',
          totalAmount: 10000,
          paidAmount: 10000,
          paymentMethodLabel: 'Lunas Denda',
        );

        final rawText = latin1.decode(ThermalReceiptEscPosBuilder.build(doc));
        expect(rawText, contains('Denda Telat'));
        expect(rawText, contains('Rp 40.000'));
        expect(rawText, contains('Keringanan Denda'));
        expect(rawText, contains('-Rp 30.000'));
        expect(rawText, contains('Alasan'));
        expect(rawText, contains('Macet / Hujan'));
      },
    );

    testWidgets(
      'AddProductSheet Paket Tarif Sewa rows omit per-tier penalty fields and submit single model-level Denda Keterlambatan / Jam',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final assetRepo = _CapturingAssetRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              assetRepositoryProvider.overrideWithValue(assetRepo),
              businessProvider.overrideWith(
                () => _StubBusinessNotifier(_makeBusinessState()),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: AddProductSheet(onSuccess: () {})),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select category, brand, model name
        await tester.tap(find.byType(DropdownButtonFormField<int>).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Kamera').last);
        await tester.pumpAndSettle();

        final textFormFields = find.byType(TextFormField);
        await tester.enterText(textFormFields.at(0), 'Sony');
        await tester.enterText(textFormFields.at(1), 'A7 IV');

        // Verify zero per-tier late fee inputs exist
        expect(find.textContaining('Denda / Overtime'), findsNothing);
        expect(find.text('Paket / Durasi'), findsOneWidget);
        expect(find.text('Harga Sewa (Rp)'), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_row_0')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_duration_0')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_unit_0')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_price_0')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_delete_0')), findsNothing);

        // Fill first tier price and add a second tier via preset
        await tester.enterText(
          find.byKey(const Key('rate_tier_price_0')),
          '200000',
        );
        final preset3Days = find.text('3 Hari');
        await tester.ensureVisible(preset3Days);
        await tester.tap(preset3Days);
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('rate_tier_row_1')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_delete_0')), findsOneWidget);
        expect(find.byKey(const Key('rate_tier_delete_1')), findsOneWidget);
        await tester.enterText(
          find.byKey(const Key('rate_tier_price_1')),
          '550000',
        );

        // Single model-level Denda Keterlambatan / Jam below tiers with helper text
        expect(find.text('Denda Keterlambatan / Jam'), findsOneWidget);
        expect(
          find.textContaining(
            'Berlaku untuk semua paket sewa model ini. Kosongkan untuk memakai tarif default toko.',
          ),
          findsOneWidget,
        );
        final modelLateFeeInput = find.byKey(
          const Key('model_hourly_late_fee_input'),
        );
        await tester.ensureVisible(modelLateFeeInput);
        await tester.enterText(modelLateFeeInput, '25000');

        // Submit form
        final submitBtn = find.text('Simpan Produk & Tarif ke Katalog');
        await tester.ensureVisible(submitBtn);
        await tester.tap(submitBtn);
        await tester.pumpAndSettle();

        expect(assetRepo.lastCreatedProductPayload, isNotNull);
        expect(assetRepo.lastCreatedProductPayload!['hourly_late_fee'], 25000.0);
        expect(assetRepo.lastCreatedProductPayload!['late_fee_per_hour'], 25000.0);

        final rates = assetRepo.lastCreatedProductPayload!['rates'] as List;
        expect(rates, hasLength(2));
        for (final rate in rates.cast<Map<String, dynamic>>()) {
          expect(rate.containsKey('extension_hourly_rate'), isFalse);
          expect(rate.containsKey('late_fee'), isFalse);
          expect(rate.keys, containsAll(['duration_unit', 'duration_value', 'price']));
        }
        expect(rates[0]['price'], 200000.0);
        expect(rates[1]['price'], 550000.0);
      },
    );
  });
}

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sewakasir/core/network/api_client.dart';
import 'package:sewakasir/core/theme/app_theme.dart';
import 'package:sewakasir/core/utils/idempotency_helper.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/presentation/cashier_screen.dart';
import 'package:sewakasir/features/cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';

class _BlindCloseCashierRepo extends CashierRepository {
  int closeCalls = 0;
  final List<double> countedAmounts = [];
  final List<String?> reasons = [];

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'date': '2026-11-19',
      'total_revenue': 900000.0,
      'total_transactions': 3,
      'is_consolidated': false,
      'cash_drawer_expenses': 0.0,
      'total_expenses': 0.0,
      'breakdown_by_type': {},
      'breakdown_by_method': {
        'Tunai (Cash)': {'total': 900000.0, 'count': 3},
      },
      'cash_reconciliation': {
        'is_blind_close': true,
        'opening_cash_float': 500000.0,
        'active_shift': {
          'id': 42,
          'shift_number': 'SHF-BLIND-001',
          'status': 'open',
          'opening_cash_float': 500000.0,
          'is_blind_close': true,
        },
      },
      'recent_transactions': [],
    };
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': true,
      'shift_enforcement_enabled': true,
      'shift': {
        'id': 42,
        'shift_number': 'SHF-BLIND-001',
        'status': 'open',
        'opening_cash_float': 500000.0,
        'is_blind_close': true,
      },
    };
  }

  @override
  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    closeCalls++;
    countedAmounts.add(actualCashCounted);
    reasons.add(differenceReason);

    // First submission simulates server 422 asking for difference_reason when variance > 5000
    if (differenceReason == null || differenceReason.trim().isEmpty) {
      throw DioException(
        requestOptions: RequestOptions(path: '/cashier/shift/close'),
        response: Response(
          requestOptions: RequestOptions(path: '/cashier/shift/close'),
          statusCode: 422,
          data: {
            'message': 'Alasan selisih kas wajib diisi.',
            'errors': {
              'difference_reason': ['Alasan selisih kas wajib diisi.'],
            },
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return {
      'id': shiftId ?? 42,
      'shift_number': 'SHF-BLIND-001',
      'status': 'closed',
      'opening_cash_float': 500000.0,
      'cash_inflow': 900000.0,
      'cash_expenses': 0.0,
      'expected_cash_total': 1400000.0,
      'actual_cash_counted': actualCashCounted,
      'cash_difference': actualCashCounted - 1400000.0,
      'difference_reason': differenceReason,
    };
  }
}

class _SpyCashierRepo extends CashierRepository {
  final List<String?> capturedKeys = [];
  bool shouldFailNext = false;

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH', 'is_active': true},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS', 'is_active': true},
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'data': {
        'has_active_shift': true,
        'shift': {'id': 10, 'status': 'open'},
      },
    };
  }

  @override
  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int? paymentMethodId,
    String? paymentMethodCode,
    double? amount,
    String? paymentType,
    double? cashReceived,
    String? notes,
    String? idempotencyKey,
    String? externalReference,
    bool? frpCleared,
    bool? accountRemoved,
    bool? isHandoverSettlement,
    int? assetUnitId,
    String? collateralType,
    String? collateralTypeId,
    String? collateralTypeName,
    String? collateralStorageSlot,
    double? collateralDepositAmount,
    bool? startNow,
    bool? keepOriginalEndAt,
  }) async {
    capturedKeys.add(idempotencyKey);
    if (shouldFailNext) {
      shouldFailNext = false;
      throw Exception('Network timeout temporary');
    }
    return {
      'receipt_number': 'REC-IDEMP-001',
      'cash_change': 0.0,
      'payment': {'id': 99, 'transaction_code': 'TX-IDEMP-001'},
    };
  }
}

class _SpyBookingRepo extends BookingRepository {
  final List<String?> createKeys = [];
  final List<String?> extendKeys = [];
  final List<String?> adjustKeys = [];
  final List<String?> returnKeys = [];
  bool failNextCreate = false;

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    createKeys.add(idempotencyKey);
    if (failNextCreate) {
      failNextCreate = false;
      throw Exception('Temporary gateway error');
    }
    return {
      'id': 321,
      'booking_code': 'RC-IDEMP-321',
      'payment_status': 'paid',
      'payments': [
        {
          'id': 1,
          'transaction_code': 'TX-BK-321',
          'receipt_number': 'REC-BK-321',
        },
      ],
    };
  }

  @override
  Future<Map<String, dynamic>> extendRental(
    int bookingId,
    int additionalHours, {
    double? fee,
    int? paymentMethodId,
    String? paymentMethodCode,
    double? cashReceived,
    String? notes,
    String? idempotencyKey,
  }) async {
    extendKeys.add(idempotencyKey);
    return {
      'receipt_number': 'REC-EXT-321',
      'extension': {'id': 11},
      'payment': {'transaction_code': 'TX-EXT-321', 'cash_change': 0.0},
    };
  }

  @override
  Future<Map<String, dynamic>> adjustDuration({
    required int bookingId,
    int? bookingItemId,
    required String direction,
    required int hoursDelta,
    double? additionalFee,
    int? paymentMethodId,
    String? paymentMethodCode,
    double? cashReceived,
    String? managerPin,
    String? reason,
    String? notes,
    String? idempotencyKey,
  }) async {
    adjustKeys.add(idempotencyKey);
    return {
      'receipt_number': 'REC-ADJ-321',
      'adjustment': {'id': 12},
      'payment': {'transaction_code': 'TX-ADJ-321', 'cash_change': 0.0},
    };
  }

  @override
  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> returnData, {
    String? idempotencyKey,
  }) async {
    returnKeys.add(idempotencyKey);
    return {
      'id': 77,
      'booking': {
        'payments': [
          {
            'type': 'penalty',
            'transaction_code': 'TX-PEN-321',
            'receipt_number': 'REC-PEN-321',
            'amount': 50000.0,
          },
        ],
      },
    };
  }
}

class _TestAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Kasir Blind', 'role': 'staff'},
  );
}

class _TestBiz extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
  );
}

void main() {
  final uuidV4Regex = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Wave 1: True Blind Close & UUID v4 Idempotency Key', () {
    test('IdempotencyHelper generates valid unique UUID v4 strings', () {
      final k1 = IdempotencyHelper.generateUuidV4();
      final k2 = IdempotencyHelper.generateUuidV4();
      expect(uuidV4Regex.hasMatch(k1), isTrue);
      expect(uuidV4Regex.hasMatch(k2), isTrue);
      expect(k1, isNot(equals(k2)));
    });

    testWidgets(
      'CashierScreen Active Shift tab redacts Total Kas Wajib di Laci when blind close is active',
      (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _BlindCloseCashierRepo();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
              authProvider.overrideWith(_TestAuth.new),
              businessProvider.overrideWith(_TestBiz.new),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const CashierScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total Kas Laci (Blind Close)'), findsOneWidget);
        expect(
          find.text(
            'Nominal kas laci disembunyikan hingga shift ditutup (Mode Blind Close).',
          ),
          findsOneWidget,
        );
        expect(find.text('Total Kas Wajib di Laci'), findsNothing);
        expect(find.text('Kas Masuk Tunai'), findsNothing);
        expect(find.text('Rp 900.000'), findsNothing);
        expect(find.text('Rp 1.400.000'), findsNothing);
        expect(find.text('Disembunyikan'), findsOneWidget);
      },
    );

    testWidgets(
      'CashDrawerShiftModal submits blind count, handles 422 difference_reason without exposing expected cash, then shows post-close comparison',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _BlindCloseCashierRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: {
                    'id': 42,
                    'shift_number': 'SHF-BLIND-001',
                    'status': 'open',
                    'is_blind_close': true,
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expected cash must NOT be shown pre-close
        expect(find.text('Fisik Kas Wajib Ada'), findsNothing);
        expect(find.text('Status: Selisih Kurang'), findsNothing);
        expect(find.text('Mode Blind Close Aktif'), findsOneWidget);

        // Switch to direct total & enter 1.350.000
        await tester.tap(find.text('Input Total Langsung'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '1350000');
        await tester.pumpAndSettle();

        // First submit triggers server 422 requiring difference_reason
        await tester.tap(find.text('Tutup Shift & Rekapitulasi Kasir'));
        await tester.pumpAndSettle();

        expect(repo.closeCalls, 1);
        expect(find.text('Alasan Selisih Kas *'), findsOneWidget);

        // Enter discrepancy reason & resubmit
        await tester.enterText(
          find.widgetWithText(TextFormField, 'Jelaskan penyebab selisih uang kas fisik...'),
          'Uang receh kembalian tercecer',
        );
        await tester.tap(find.text('Tutup Shift & Rekapitulasi Kasir'));
        await tester.pumpAndSettle();

        expect(repo.closeCalls, 2);
        expect(repo.countedAmounts.last, 1350000.0);
        expect(repo.reasons.last, 'Uang receh kembalian tercecer');

        // Post-close preview dialog now reveals system expected vs counted comparison
        expect(find.text('Hasil Rekonsiliasi Tutup Shift'), findsOneWidget);
        expect(find.text('Modal Awal Laci:'), findsOneWidget);
        expect(find.text('Penerimaan Tunai:'), findsOneWidget);
        expect(find.text('Pengeluaran/Refund Tunai:'), findsOneWidget);
        expect(find.text('Ekspektasi Kas Sistem:'), findsOneWidget);
        expect(find.text('Uang Fisik Dihitung:'), findsOneWidget);
        expect(find.text('Selisih Kas (Kurang):'), findsOneWidget);
        expect(find.text('Rp 1.400.000'), findsOneWidget);
        expect(find.text('Rp 1.350.000'), findsOneWidget);
      },
    );

    test(
      'PaymentRepository.executePayment forwards deterministic idempotencyKey across booking, extend, adjustDuration, processReturn, and processPayment',
      () async {
        final spyBooking = _SpyBookingRepo();
        final spyCashier = _SpyCashierRepo();
        final paymentRepo = PaymentRepository(
          cashierRepo: spyCashier,
          bookingRepo: spyBooking,
        );

        const explicitKey = '11111111-2222-4333-8444-555555555555';

        await paymentRepo.executePayment(
          context: PaymentContext.booking(
            customerName: 'Andi',
            deviceName: 'iPhone 15',
            totalAmount: 150000,
            bookingPayload: {'asset_model_id': 1},
          ),
          paymentMethodId: 1,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
          amountToPay: 150000,
          cashReceived: 150000,
          idempotencyKey: explicitKey,
        );
        expect(spyBooking.createKeys, [explicitKey]);

        await paymentRepo.executePayment(
          context: PaymentContext.extension(
            bookingId: 10,
            additionalHours: 24,
            extensionFee: 100000,
          ),
          paymentMethodId: 1,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
          amountToPay: 100000,
          cashReceived: 100000,
          idempotencyKey: explicitKey,
        );
        expect(spyBooking.extendKeys, [explicitKey]);

        await paymentRepo.executePayment(
          context: PaymentContext.extension(
            bookingId: 10,
            additionalHours: 24,
            extensionFee: 100000,
            extraPayload: {'booking_item_id': 99},
          ),
          paymentMethodId: 1,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
          amountToPay: 100000,
          cashReceived: 100000,
          idempotencyKey: explicitKey,
        );
        expect(spyBooking.adjustKeys, [explicitKey]);

        await paymentRepo.executePayment(
          context: PaymentContext.penalty(
            bookingId: 10,
            penaltyDue: 50000,
            extraPayload: {
              'is_return_workflow': true,
              'return_payload': {'condition_grade': 'A'},
            },
          ),
          paymentMethodId: 1,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
          amountToPay: 50000,
          cashReceived: 50000,
          idempotencyKey: explicitKey,
        );
        expect(spyBooking.returnKeys, [explicitKey]);

        await paymentRepo.executePayment(
          context: PaymentContext.settlement(
            booking: {'id': 10, 'total_bill': 300000},
            remainingDue: 200000,
          ),
          paymentMethodId: 1,
          paymentMethodCode: 'CASH',
          paymentMethodName: 'Tunai',
          amountToPay: 200000,
          cashReceived: 200000,
          idempotencyKey: explicitKey,
        );
        expect(spyCashier.capturedKeys, [explicitKey]);
      },
    );

    testWidgets(
      'PaymentPage reuses identical UUID v4 idempotency_key across retry of the same attempt and generates a new key for a new PaymentPage session',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final spyBooking = _SpyBookingRepo()..failNextCreate = true;
        final spyCashier = _SpyCashierRepo();
        final paymentRepo = PaymentRepository(
          cashierRepo: spyCashier,
          bookingRepo: spyBooking,
        );

        final ctx = PaymentContext.booking(
          customerName: 'Budi',
          deviceName: 'iPhone 16 Pro',
          totalAmount: 200000,
          bookingPayload: {'asset_model_id': 1},
        );

        Widget buildPaymentScreen(Key key) => ProviderScope(
              overrides: [
                cashierRepositoryProvider.overrideWithValue(spyCashier),
                bookingRepositoryProvider.overrideWithValue(spyBooking),
                paymentRepositoryProvider.overrideWithValue(paymentRepo),
                businessProvider.overrideWith(_TestBiz.new),
              ],
              child: MaterialApp(
                theme: AppTheme.lightTheme,
                home: PaymentPage(key: key, paymentContext: ctx),
              ),
            );

        // Attempt 1: initial submit fails, then user retries in same PaymentPage state
        await tester.pumpWidget(buildPaymentScreen(const ValueKey('attempt-1')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cash_sheet_process_button')));
        await tester.pumpAndSettle();

        expect(spyBooking.createKeys.length, 1);
        final firstKey = spyBooking.createKeys[0]!;
        expect(uuidV4Regex.hasMatch(firstKey), isTrue);

        // Dismiss error SnackBar before tapping retry in same PaymentPage state
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cash_sheet_process_button')));
        await tester.pumpAndSettle();

        expect(spyBooking.createKeys.length, 2);
        expect(spyBooking.createKeys[1], equals(firstKey));

        // Attempt 2: brand new PaymentPage instance (new checkout attempt)
        await tester.pumpWidget(buildPaymentScreen(const ValueKey('attempt-2')));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tunai'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('cash_sheet_process_button')));
        await tester.pumpAndSettle();

        expect(spyBooking.createKeys.length, 3);
        final thirdKey = spyBooking.createKeys[2]!;
        expect(uuidV4Regex.hasMatch(thirdKey), isTrue);
        expect(thirdKey, isNot(equals(firstKey)));
      },
    );

    testWidgets(
      'CashDrawerShiftModal extracts clean Indonesian message from DioException without raw null prefix',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final repo = _Failing422CashierRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(repo),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              home: const Scaffold(
                body: CashDrawerShiftModal(
                  activeShift: {
                    'id': 13,
                    'shift_number': 'SHF-HAL-261104-0001',
                    'status': 'open',
                    'is_blind_close': true,
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Input Total Langsung'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, '270000');
        await tester.pumpAndSettle();

        await tester.tap(find.text('Tutup Shift & Rekapitulasi Kasir'));
        await tester.pumpAndSettle();

        expect(
          find.text('Tidak ada shift kasir yang sedang aktif untuk ditutup.'),
          findsOneWidget,
        );
        expect(find.textContaining('DioException'), findsNothing);
        expect(find.textContaining('bad response'), findsNothing);
      },
    );

    test('ApiClient.extractErrorMessage extracts clean JSON message from DioException', () {
      final dioErr = DioException(
        requestOptions: RequestOptions(path: '/cashier/shift/close'),
        response: Response(
          requestOptions: RequestOptions(path: '/cashier/shift/close'),
          statusCode: 422,
          data: {
            'message': 'Tidak ada shift kasir yang sedang aktif untuk ditutup.',
          },
        ),
        type: DioExceptionType.badResponse,
      );

      expect(
        ApiClient.extractErrorMessage(dioErr),
        equals('Tidak ada shift kasir yang sedang aktif untuk ditutup.'),
      );
    });
  });
}

class _Failing422CashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> closeShift({
    required double actualCashCounted,
    int? shiftId,
    String? differenceReason,
    String? closingNotes,
    int? branchId,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/cashier/shift/close'),
      response: Response(
        requestOptions: RequestOptions(path: '/cashier/shift/close'),
        statusCode: 422,
        data: {
          'message': 'Tidak ada shift kasir yang sedang aktif untuk ditutup.',
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

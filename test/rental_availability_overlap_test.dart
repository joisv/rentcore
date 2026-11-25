import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';

class _OverlapAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {'id': 1, 'name': 'Kasir Toko', 'role': 'owner'},
      );
}

class _OverlapBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Kameha Rental',
        activeBranchId: 10,
        activeBranchName: 'Cabang Utama',
        businesses: [
          {
            'id': 1,
            'name': 'Kameha Rental',
            'role': 'owner',
            'branches': [
              {
                'id': 10,
                'name': 'Cabang Utama',
                'is_central': true,
                'allow_floating_unit_booking': true,
              },
            ],
          },
        ],
      );
}

class _ShiftOpenCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': true,
      'shift_enforcement_enabled': true,
      'shift': {'id': 1, 'status': 'open'},
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
    ];
  }
}

class _OverlapBookingRepo extends BookingRepository {
  final String conflictMessage;
  int windowFetchCalls = 0;

  _OverlapBookingRepo(this.conflictMessage);

  final Map<String, dynamic> _unit = {
    'id': 501,
    'affiliate_id': 10,
    'asset_code': 'XR-001',
    'serial_number': 'SN-XR-001',
    'status': 'ready',
    'model_id': 88,
    'model': {
      'id': 88,
      'name': 'iPhone XR Putih',
      'brand': 'Apple',
      'category_id': 1,
      'category': {'id': 1, 'name': 'Smartphones'},
      'pricing_tiers': [
        {
          'id': 901,
          'duration_unit': 'day',
          'duration_value': 1,
          'duration_hours': 24,
          'price': 150000,
        },
      ],
    },
  };

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    return [Map<String, dynamic>.from(_unit)];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchAssetsForWindow({
    required int branchId,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    windowFetchCalls++;
    return [
      {
        ..._unit,
        'is_available_for_schedule': false,
        'is_available_for_window': false,
        'conflict_reason': conflictMessage,
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    throw DioException(
      requestOptions: RequestOptions(path: '/bookings'),
      response: Response(
        requestOptions: RequestOptions(path: '/bookings'),
        statusCode: 422,
        data: {
          'message': conflictMessage,
          'errors': {
            'asset_ids': [conflictMessage],
          },
        },
      ),
      type: DioExceptionType.badResponse,
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID');
  });

  const conflictMessage =
      'Stok iPhone XR Putih tidak mencukupi untuk durasi tersebut karena sudah terikat jadwal sewa/booking pada 22 Nov 09:00 - 23 Nov 09:00.';

  testWidgets(
    'DirectRentalScreen shows backend window conflict reason in walk-in mode and blocks proceeding with clear dialog',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bookingRepo = _OverlapBookingRepo(conflictMessage);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _OverlapAuthNotifier()),
            businessProvider.overrideWith(() => _OverlapBusinessNotifier()),
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            cashierRepositoryProvider.overrideWithValue(_ShiftOpenCashierRepo()),
            categoriesProvider.overrideWith(
              (ref) async => [
                {'id': 1, 'name': 'Smartphones'},
              ],
            ),
          ],
          child: const MaterialApp(home: DirectRentalScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Immediate window availability check ran automatically on open
      expect(bookingRepo.windowFetchCalls, greaterThanOrEqualTo(1));
      expect(find.textContaining('Stok iPhone XR Putih tidak mencukupi'), findsWidgets);

      // Select the conflicting unit and verify conflict banner + Lanjut button stays disabled
      await tester.tap(find.text('iPhone XR Putih'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Stok iPhone XR Putih tidak mencukupi'), findsWidgets);
      final lanjutBtn = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Lanjut'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(lanjutBtn.onPressed, isNull);
    },
  );

  testWidgets(
    'PaymentPage displays clear 422 schedule conflict AlertDialog when backend rejects overlapping rental',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bookingRepo = _OverlapBookingRepo(conflictMessage);
      final cashierRepo = _ShiftOpenCashierRepo();
      final paymentContext = PaymentContext.booking(
        customerName: 'Budi Santoso',
        customerPhone: '081234567890',
        deviceName: 'iPhone XR Putih',
        assetCode: 'XR-001',
        totalAmount: 150000,
        branchId: 10,
        branchName: 'Cabang Utama',
        additionalHours: 24,
        extraPayload: {
          'booking_mode': 'direct',
          'is_scheduled': false,
          'asset_ids': [501],
          'duration_hours': 24,
          'duration_unit': 'day',
          'duration_value': 1,
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _OverlapBusinessNotifier()),
            bookingRepositoryProvider.overrideWithValue(bookingRepo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            paymentRepositoryProvider.overrideWithValue(
              PaymentRepository(
                cashierRepo: cashierRepo,
                bookingRepo: bookingRepo,
              ),
            ),
            paymentMethodsProvider.overrideWith(
              (ref) async => [
                {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
              ],
            ),
            paymentSettingsProvider(10).overrideWith(
              (ref) async => {
                'config': {
                  'cash_enabled': true,
                  'qris_statis_enabled': false,
                  'bank_transfer_enabled': false,
                },
              },
            ),
          ],
          child: MaterialApp(
            home: PaymentPage(paymentContext: paymentContext),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open Tunai sheet & tap PROSES PEMBAYARAN
      final tunaiBtn = find.text('Tunai');
      expect(tunaiBtn, findsOneWidget);
      await tester.tap(tunaiBtn);
      await tester.pumpAndSettle();

      final processBtn = find.byKey(const Key('cash_sheet_process_button'));
      expect(processBtn, findsOneWidget);
      await tester.tap(processBtn);
      await tester.pumpAndSettle();

      // Expect explicit 422 AlertDialog instead of generic error
      expect(find.text('Jadwal / Stok Tidak Tersedia'), findsOneWidget);
      expect(find.text(conflictMessage), findsOneWidget);
    },
  );
}

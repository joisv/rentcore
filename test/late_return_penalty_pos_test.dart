import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/presentation/cashier_screen.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _FakeCashierRepository extends CashierRepository {
  int? paidBookingId;
  String? lastPaymentType;
  double? lastAmount;

  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    bool allBranches = false,
    String? date,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'branch_id': branchId,
      'is_consolidated': false,
      'date': '2026-10-16',
      'total_revenue': 275000.0,
      'total_transactions': 2,
      'breakdown_by_type': {
        'rental': {
          'label': 'Sewa Kontrak Pokok',
          'count': 1,
          'total': 200000.0,
        },
        'extension': {
          'label': 'Perpanjangan Sewa',
          'count': 0,
          'total': 0.0,
        },
        'penalty': {
          'label': 'Denda Keterlambatan',
          'count': 1,
          'total': 75000.0,
        },
      },
      'breakdown_by_method': {
        'Tunai': {'count': 2, 'total': 275000.0},
      },
      'recent_transactions': [
        {
          'id': 101,
          'booking_id': 1,
          'receipt_number': 'REC-KASIR-001',
          'amount': 200000.0,
          'payment_method': 'Tunai',
          'cashier_name': 'Kasir Utama',
          'customer_name': 'Budi Santoso',
          'branch_name': 'Cabang Utama',
          'is_central': true,
          'items_summary': 'iPhone 15 Pro',
          'type': 'rental',
          'type_label': 'Sewa Rental',
        },
        {
          'id': 102,
          'booking_id': 2,
          'receipt_number': 'REC-KASIR-002',
          'amount': 75000.0,
          'payment_method': 'Tunai',
          'cashier_name': 'Kasir Utama',
          'customer_name': 'Siti Rahma',
          'branch_name': 'Cabang Utama',
          'is_central': true,
          'items_summary': 'iPad Air M2',
          'type': 'penalty',
          'type_label': 'Denda Keterlambatan',
        },
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchBookingsForCashier({
    int? branchId,
    bool allBranches = false,
    String? search,
    String? paymentStatus,
  }) async {
    return [
      {
        'id': 2,
        'booking_code': 'BK-LATE-001',
        'customer': {'name': 'Siti Rahma', 'phone': '08123456789'},
        'items': [
          {
            'asset': {
              'asset_code': 'IPD-01',
              'model': {'name': 'iPad Air M2'},
            }
          }
        ],
        'duration_hours': 24,
        'subtotal_amount': 150000.0,
        'discount_amount': 0.0,
        'total_bill': 150000.0,
        'payment_status': 'partial',
        'return_inspection': {
          'late_fee': 75000.0,
          'damage_fee': 0.0,
          'total_penalty': 75000.0,
        },
        'payments': [
          {
            'id': 201,
            'amount': 150000.0,
            'type': 'rental',
            'payment_method': {'name': 'Tunai'},
          }
        ],
      }
    ];
  }

  @override
  Future<Map<String, dynamic>> fetchBookingDetail(dynamic bookingId) async {
    return {
      'id': 2,
      'booking_code': 'BK-LATE-001',
      'customer': {'name': 'Siti Rahma', 'phone': '08123456789'},
      'affiliate': {'name': 'Cabang Utama', 'is_central': true},
      'items': [
        {
          'asset': {
            'asset_code': 'IPD-01',
            'model': {'name': 'iPad Air M2'},
          }
        }
      ],
      'duration_hours': 24,
      'subtotal_amount': 150000.0,
      'discount_amount': 0.0,
      'total_bill': 150000.0,
      'payment_status': 'partial',
      'return_inspection': {
        'late_fee': 75000.0,
        'damage_fee': 0.0,
        'total_penalty': 75000.0,
      },
      'payments': [
        {
          'id': 201,
          'amount': 150000.0,
          'type': 'rental',
          'payment_method': {'name': 'Tunai'},
        }
      ],
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      {'id': 2, 'name': 'QRIS', 'code': 'QRIS'},
    ];
  }

  @override
  Future<Map<String, dynamic>> processPayment({
    required int bookingId,
    required int paymentMethodId,
    double? cashReceived,
    double? amount,
    String? paymentType,
    String? notes,
    String? idempotencyKey,
  }) async {
    paidBookingId = bookingId;
    lastPaymentType = paymentType;
    lastAmount = amount;
    return {
      'receipt_number': 'REC-PEN-001',
      'cash_change': 0.0,
      'amount': amount,
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;
}

class _FakeBookingRepositoryForQueue extends BookingRepository {
  final List<Map<String, dynamic>> returnData;
  _FakeBookingRepositoryForQueue(this.returnData);

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return returnData;
  }
}

void main() {
  group('Late Return Penalty Revenue UI & Flow Tests', () {
    testWidgets('Closing shift tab displays breakdown by income type including late penalty and badge', (tester) async {
      final fakeRepo = _FakeCashierRepository();
      final businessState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Central Business',
        activeBranchId: 1,
        activeBranchName: 'Cabang Utama',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Central Business',
            'membership': {'role': 'owner'},
            'branches': [
              {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: CashierScreen(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch to Tab 2: Rekap Shift & Closing
      final closingTabFinder = find.text('Rekap Shift & Closing');
      expect(closingTabFinder, findsOneWidget);
      await tester.tap(closingTabFinder);
      await tester.pumpAndSettle();

      // Verify Income Type section header is displayed
      expect(find.text('SUMBER PENDAPATAN (INCOME TYPE)'), findsOneWidget);

      // Verify Rental & Penalty Breakdown rows
      expect(find.text('Sewa Kontrak Pokok'), findsOneWidget);
      expect(find.text('Denda Keterlambatan'), findsAtLeastNWidgets(1));

      // Verify Penalty badge in recent transactions list
      expect(find.text('Denda'), findsOneWidget);
    });

    testWidgets('PosTransactionDetailSheet includes late penalty in total bill and remaining due', (tester) async {
      final fakeRepo = _FakeCashierRepository();

      final bookingData = {
        'id': 2,
        'booking_code': 'BK-LATE-001',
        'customer': {'name': 'Siti Rahma', 'phone': '08123456789'},
        'affiliate': {'name': 'Cabang Utama', 'is_central': true},
        'items': [
          {
            'asset': {
              'asset_code': 'IPD-01',
              'model': {'name': 'iPad Air M2'},
            }
          }
        ],
        'duration_hours': 24,
        'subtotal_amount': 150000.0,
        'discount_amount': 0.0,
        'total_bill': 150000.0,
        'payment_status': 'partial',
        'return_inspection': {
          'late_fee': 75000.0,
          'damage_fee': 0.0,
          'total_penalty': 75000.0,
        },
        'payments': [
          {
            'id': 201,
            'amount': 150000.0,
            'type': 'rental',
            'payment_method': {'name': 'Tunai'},
          }
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PosTransactionDetailSheet(
                booking: bookingData,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Denda Keterlambatan item row is rendered
      expect(find.text('Denda Keterlambatan'), findsAtLeastNWidgets(1));

      // Verify 'Bayar di Kasir' button is present because remainingDue (Rp 75.000) > 0
      expect(find.text('Bayar di Kasir'), findsOneWidget);
    });

    testWidgets('PosTransactionDetailSheet passes deep resolved booking with return_inspection to onPaymentRequested callback', (tester) async {
      final fakeRepo = _FakeCashierRepository();
      Map<String, dynamic>? receivedBooking;

      // Pass an initial booking that lacks return_inspection (simulating stale list data)
      final initialBooking = {
        'id': 2,
        'booking_code': 'BK-LATE-001',
        'customer': {'name': 'Siti Rahma', 'phone': '08123456789'},
        'items': [
          {
            'asset': {
              'asset_code': 'IPD-01',
              'model': {'name': 'iPad Air M2'},
            }
          }
        ],
        'duration_hours': 24,
        'subtotal_amount': 150000.0,
        'discount_amount': 0.0,
        'total_bill': 150000.0,
        'payment_status': 'partial',
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PosTransactionDetailSheet(
                booking: initialBooking,
                onPaymentRequested: (b) => receivedBooking = b,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Scroll until 'Bayar di Kasir' button is visible, then tap
      final payBtn = find.text('Bayar di Kasir');
      await tester.scrollUntilVisible(payBtn, 200);
      expect(payBtn, findsOneWidget);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      // Assert that receivedBooking contains the deep return_inspection data from fetchBookingDetail
      expect(receivedBooking, isNotNull);
      expect(receivedBooking!['return_inspection'], isNotNull);
      expect(receivedBooking!['return_inspection']['total_penalty'], 75000.0);
    });

    testWidgets('BookingsScreen renders SELESAI (DENDA BELUM LUNAS) warning badge and (+ Denda) total for returned booking with partial payment status', (tester) async {
      final returnedBookingWithPenalty = {
        'id': 105,
        'booking_code': 'RC-RET-PEN-01',
        'affiliate_id': 1,
        'business_id': 1,
        'status': 'returned',
        'payment_status': 'partial',
        'start_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
        'end_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'total_bill': 150000.0,
        'customer': {
          'id': 5,
          'name': 'Dewi Lestari',
          'phone': '081299998888',
        },
        'items': [
          {
            'id': 10,
            'asset': {
              'id': 80,
              'asset_code': 'MAC-01',
              'model': {'id': 9, 'name': 'MacBook Pro M3'},
            },
          },
        ],
        'return_inspection': {
          'late_minutes': 120,
          'late_fee': 50000.0,
          'damage_fee': 0.0,
          'total_penalty': 50000.0,
        },
      };

      final fakeBookingRepo = _FakeBookingRepositoryForQueue([returnedBookingWithPenalty]);
      final businessState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'RentCore Central Business',
        activeBranchId: 1,
        activeBranchName: 'Cabang Utama',
        businesses: [
          {
            'id': 1,
            'name': 'RentCore Central Business',
            'branches': [
              {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
            ],
          },
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify that badge says 'SELESAI (DENDA BELUM LUNAS)'
      expect(find.text('SELESAI (DENDA BELUM LUNAS)'), findsOneWidget);

      // Verify that total includes the late penalty (+ Denda) -> Rp 200.000 (+ Denda)
      expect(find.textContaining('(+ Denda)'), findsOneWidget);
      expect(find.textContaining('200.000'), findsOneWidget);
    });
  });
}

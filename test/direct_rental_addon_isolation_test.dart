import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/payments/data/payment_repository.dart';

class _FakeIsolationBookingRepository extends BookingRepository {
  final List<Map<String, dynamic>> mockModels;
  _FakeIsolationBookingRepository({this.mockModels = const []});

  @override
  Future<List<Map<String, dynamic>>> fetchAssetsForWindow({
    required int branchId,
    required DateTime startAt,
    required DateTime endAt,
  }) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchModelAvailability({
    required DateTime startAt,
    required DateTime endAt,
    int? branchId,
    int? categoryId,
    String? search,
  }) async => mockModels;
}

class _FakeIsolationCashierRepository extends CashierRepository {
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

class _FakeIsolationBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _FakeIsolationBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  const konzBusinessState = BusinessState(
    activeBusinessId: 2,
    activeBusinessName: 'Konz',
    activeBranchId: 3,
    activeBranchName: 'Konz Pusat',
    businesses: [
      {
        'id': 2,
        'name': 'Konz',
        'branches': [
          {
            'id': 3,
            'name': 'Konz Pusat',
            'allow_floating_unit_booking': true,
            'booking_grace_period_minutes': 60,
          },
        ],
      },
    ],
  );

  Widget buildScreen({
    required List<Map<String, dynamic>> readyAssets,
    List<Map<String, dynamic>> categories = const [],
    List<Map<String, dynamic>> floatingModels = const [],
  }) {
    final bookingRepo = _FakeIsolationBookingRepository(mockModels: floatingModels);
    final cashierRepo = _FakeIsolationCashierRepository();

    return ProviderScope(
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
          () => _FakeIsolationBusinessNotifier(konzBusinessState),
        ),
        readyAssetsProvider.overrideWith((ref) => Future.value(readyAssets)),
        readyAssetsByBranchProvider.overrideWith(
          (ref, _) => Future.value(readyAssets),
        ),
        categoriesProvider.overrideWith((ref) => Future.value(categories)),
      ],
      child: const MaterialApp(
        home: DirectRentalScreen(showAppBar: false),
      ),
    );
  }

  testWidgets(
    'PlayStation 4 (is_addon: false, even under addon-flagged category) renders ONLY in Main Unit Selector and never in ADD-ON (OPSIONAL)',
    (tester) async {
      final readyAssets = [
        {
          'id': 12,
          'affiliate_id': 3,
          'asset_code': 'AST-568362',
          'condition_grade': 'A',
          'status': 'ready',
          'is_addon': false,
          'model': {
            'id': 3,
            'brand': 'Sony',
            'name': 'PlayStation 4',
            'is_addon': false,
            'category_id': 4,
            // Deliberately simulate seeded category with is_addon: true
            'category': {'id': 4, 'name': 'Stik & Controller', 'is_addon': true},
            'pricing_tiers': [
              {
                'id': 1,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 120000,
              },
            ],
          },
        },
        // Add-on unit belonging to a different branch (must also be excluded)
        {
          'id': 99,
          'affiliate_id': 999,
          'asset_code': 'ADD-OTHER',
          'status': 'ready',
          'is_addon': true,
          'model': {
            'id': 88,
            'brand': 'Sony',
            'name': 'DualShock 4 Cabang Lain',
            'is_addon': true,
            'category_id': 4,
            'category': {'id': 4, 'name': 'Stik & Controller', 'is_addon': true},
            'pricing_tiers': [
              {
                'id': 2,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 25000,
              },
            ],
          },
        },
      ];

      await tester.pumpWidget(
        buildScreen(
          readyAssets: readyAssets,
          categories: const [
            {'id': 3, 'name': 'PlayStation 5 & 4', 'is_addon': false},
            {'id': 4, 'name': 'Stik & Controller', 'is_addon': true},
          ],
        ),
      );
      await tester.pumpAndSettle();

      // PlayStation 4 appears strictly once (only in Main Unit List)
      expect(find.text('PlayStation 4'), findsOneWidget);

      // ADD-ON (OPSIONAL) shows empty state with zero items and zero search field
      expect(find.text('ADD-ON (OPSIONAL)'), findsOneWidget);
      expect(find.byKey(const Key('booking_addon_empty_state')), findsOneWidget);
      expect(
        find.text('Belum ada unit add-on tersedia di cabang ini.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('booking_addon_search_field')), findsNothing);
      expect(find.text('DualShock 4 Cabang Lain'), findsNothing);
    },
  );

  testWidgets(
    'Add-on unit renders strictly inside ADD-ON (OPSIONAL) and never pollutes Main Unit Selector',
    (tester) async {
      final readyAssets = [
        {
          'id': 12,
          'affiliate_id': 3,
          'asset_code': 'AST-568362',
          'status': 'ready',
          'is_addon': false,
          'model': {
            'id': 3,
            'brand': 'Sony',
            'name': 'PlayStation 4',
            'is_addon': false,
            'category_id': 3,
            'category': {'id': 3, 'name': 'PlayStation 5 & 4', 'is_addon': false},
            'pricing_tiers': [
              {
                'id': 1,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 120000,
              },
            ],
          },
        },
        {
          'id': 15,
          'affiliate_id': 3,
          'asset_code': 'ADD-STK-01',
          'status': 'ready',
          'is_addon': true,
          'model': {
            'id': 7,
            'brand': 'Sony',
            'name': 'Stik DualShock 4 Ekstra',
            'is_addon': true,
            'category_id': 4,
            'category': {'id': 4, 'name': 'Stik & Controller', 'is_addon': true},
            'pricing_tiers': [
              {
                'id': 2,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 25000,
              },
            ],
          },
        },
      ];

      await tester.pumpWidget(buildScreen(readyAssets: readyAssets));
      await tester.pumpAndSettle();

      // Main unit appears once; add-on search box & add-on unit appear strictly in Add-on section
      expect(find.text('PlayStation 4'), findsOneWidget);
      expect(find.byKey(const Key('booking_addon_search_field')), findsOneWidget);
      expect(find.textContaining('Stik DualShock 4 Ekstra'), findsOneWidget);
    },
  );
}

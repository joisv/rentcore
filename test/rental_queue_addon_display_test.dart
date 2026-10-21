import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';

class _FakeQueueBookingRepository extends BookingRepository {
  List<Map<String, dynamic>> queueData = [];

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    var result = List<Map<String, dynamic>>.from(queueData);
    if (status != null && status.isNotEmpty) {
      result = result.where((b) => b['status'] == status).toList();
    }
    if (search != null && search.isNotEmpty) {
      result = result.where((b) {
        final code = (b['booking_code'] ?? '').toString().toLowerCase();
        final cust = (b['customer']?['name'] ?? '').toString().toLowerCase();
        return code.contains(search.toLowerCase()) || cust.contains(search.toLowerCase());
      }).toList();
    }
    return result;
  }
}

class _TestQueueBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestQueueBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

void main() {
  group('Rental Queue Primary Device + Add-on Display Tests', () {
    late _FakeQueueBookingRepository fakeRepo;

    setUp(() {
      fakeRepo = _FakeQueueBookingRepository();
    });

    testWidgets('1. Device-only rental displays primary device and no add-on section', (tester) async {
      fakeRepo.queueData = [
        {
          'id': 101,
          'booking_code': 'RC-DEV-001',
          'affiliate_id': 1,
          'business_id': 10,
          'status': 'rented',
          'total_bill': 150000.0,
          'primary_subtotal': 150000.0,
          'addon_subtotal': 0.0,
          'customer': {'id': 1, 'name': 'Budi Santoso', 'phone': '08123456789'},
          'collateral_storage_slot': 'Slot A1',
          'items': [
            {
              'id': 1,
              'item_type': 'primary',
              'asset': {
                'id': 50,
                'asset_code': 'IPHONE-13-01',
                'serial_number': 'SN-IP13-01',
                'model': {'id': 5, 'name': 'iPhone 13 128GB — Midnight', 'is_addon': false},
              },
            },
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestQueueBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBranchId: 1,
                activeBranchName: 'Cabang Utama',
                businesses: [
                  {
                    'id': 10,
                    'name': 'RentCore Store',
                    'branches': [
                      {'id': 1, 'name': 'Cabang Utama'},
                    ],
                  }
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BookingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Check Primary Device is displayed
      expect(find.text('iPhone 13 128GB — Midnight'), findsOneWidget);
      expect(find.textContaining('IPHONE-13-01'), findsOneWidget);
      expect(find.textContaining('Budi Santoso'), findsOneWidget);
      expect(find.text('RC-DEV-001'), findsOneWidget);

      // Add-on section should NOT appear
      expect(find.textContaining('Item Add-on'), findsNothing);

      // Verify total
      expect(find.textContaining('Total: Rp 150.000'), findsOneWidget);
    });

    testWidgets('2. Device plus multiple add-ons displays primary device and every add-on cleanly', (tester) async {
      fakeRepo.queueData = [
        {
          'id': 102,
          'booking_code': 'RC-ADD-002',
          'affiliate_id': 1,
          'business_id': 10,
          'status': 'rented',
          'total_bill': 190000.0,
          'primary_subtotal': 150000.0,
          'addon_subtotal': 40000.0,
          'customer': {'id': 2, 'name': 'John Doe', 'phone': '0899999999'},
          'collateral_storage_slot': 'Slot B2',
          'items': [
            // Intentionally putting the add-on first in the items list to simulate higher ID / reverse retrieval
            {
              'id': 202,
              'item_type': 'addon',
              'unit_price': 25000.0,
              'asset': {
                'id': 61,
                'asset_code': 'PB-ANKER-01',
                'model': {'id': 12, 'name': 'Power Bank Anker 10000mAh', 'is_addon': true},
              },
            },
            {
              'id': 203,
              'item_type': 'addon',
              'unit_price': 15000.0,
              'asset': {
                'id': 62,
                'asset_code': 'CHG-BASEUS-01',
                'model': {'id': 13, 'name': 'Fast Charger 67W', 'is_addon': true},
              },
            },
            // Primary item
            {
              'id': 201,
              'item_type': 'primary',
              'unit_price': 150000.0,
              'asset': {
                'id': 50,
                'asset_code': 'IPHONE-13-01',
                'serial_number': 'SN-IP13-01',
                'model': {'id': 5, 'name': 'iPhone 13 128GB — Midnight', 'is_addon': false},
              },
            },
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestQueueBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBranchId: 1,
                activeBranchName: 'Cabang Utama',
                businesses: [
                  {
                    'id': 10,
                    'name': 'RentCore Store',
                    'branches': [
                      {'id': 1, 'name': 'Cabang Utama'},
                    ],
                  }
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BookingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Primary device must STILL be iPhone, NOT Power Bank!
      expect(find.text('iPhone 13 128GB — Midnight'), findsOneWidget);
      expect(find.textContaining('IPHONE-13-01'), findsOneWidget);

      // Customer name
      expect(find.textContaining('John Doe'), findsOneWidget);

      // Add-on section is rendered with both items
      expect(find.text('Item Add-on (2):'), findsOneWidget);
      expect(find.textContaining('Power Bank Anker 10000mAh'), findsOneWidget);
      expect(find.textContaining('Fast Charger 67W'), findsOneWidget);

      // Subtotals & total are rendered
      expect(find.textContaining('Utama: Rp 150.000 • Add-on: Rp 40.000'), findsOneWidget);
      expect(find.textContaining('Total: Rp 190.000'), findsOneWidget);

      // Ensure only 1 booking card is rendered (no duplicate queue rows)
      expect(find.text('RC-ADD-002'), findsOneWidget);
    });

    testWidgets('3. Add-on does not overwrite primary device title in queue', (tester) async {
      fakeRepo.queueData = [
        {
          'id': 103,
          'booking_code': 'RC-ADD-003',
          'status': 'rented',
          'total_bill': 175000.0,
          'items': [
            {
              'id': 99,
              'item_type': 'addon',
              'asset': {
                'id': 61,
                'asset_code': 'PB-001',
                'model': {'id': 12, 'name': 'Power Bank', 'is_addon': true},
              },
            },
            {
              'id': 50,
              'item_type': 'primary',
              'asset': {
                'id': 1,
                'asset_code': 'IPHONE-MAIN',
                'model': {'id': 1, 'name': 'iPhone 15 Pro', 'is_addon': false},
              },
            },
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestQueueBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBranchId: 1,
                businesses: [
                  {
                    'id': 10,
                    'name': 'RentCore Store',
                    'branches': [
                      {'id': 1, 'name': 'Cabang Utama'},
                    ],
                  }
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BookingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Main header must be iPhone 15 Pro, NOT Power Bank
      expect(find.text('iPhone 15 Pro'), findsOneWidget);
      expect(find.textContaining('IPHONE-MAIN'), findsOneWidget);
      expect(find.text('Item Add-on (1):'), findsOneWidget);
      expect(find.textContaining('Power Bank (PB-001)'), findsOneWidget);
    });

    testWidgets('4. Missing or malformed relationships are handled safely without crashing', (tester) async {
      fakeRepo.queueData = [
        {
          'id': 104,
          'booking_code': 'RC-MALFORMED-001',
          'status': 'rented',
          'total_bill': 100000.0,
          'items': [
            // Malformed items with null assets or missing models
            {'id': 1, 'item_type': 'primary', 'asset': null},
            {'id': 2, 'item_type': 'addon', 'asset': {'id': 99, 'asset_code': null, 'model': null}},
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestQueueBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBranchId: 1,
                businesses: [
                  {
                    'id': 10,
                    'name': 'RentCore Store',
                    'branches': [
                      {'id': 1, 'name': 'Cabang Utama'},
                    ],
                  }
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BookingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Fallback text should be rendered cleanly without throwing exceptions
      expect(find.text('Perangkat Sewa'), findsOneWidget);
      expect(find.text('RC-MALFORMED-001'), findsOneWidget);
    });

    testWidgets('5. Multiple add-ons do not create duplicate queue entries', (tester) async {
      fakeRepo.queueData = [
        {
          'id': 105,
          'booking_code': 'RC-MULTI-005',
          'status': 'rented',
          'total_bill': 250000.0,
          'items': [
            {
              'id': 1,
              'item_type': 'primary',
              'asset': {'id': 1, 'asset_code': 'IP-13', 'model': {'name': 'iPhone 13'}},
            },
            {
              'id': 2,
              'item_type': 'addon',
              'asset': {'id': 2, 'asset_code': 'PB-1', 'model': {'name': 'Power Bank'}},
            },
            {
              'id': 3,
              'item_type': 'addon',
              'asset': {'id': 3, 'asset_code': 'CHG-1', 'model': {'name': 'Charger'}},
            },
            {
              'id': 4,
              'item_type': 'addon',
              'asset': {'id': 4, 'asset_code': 'CAB-1', 'model': {'name': 'Cable'}},
            },
          ],
        },
      ];

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestQueueBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBranchId: 1,
                businesses: [
                  {
                    'id': 10,
                    'name': 'RentCore Store',
                    'branches': [
                      {'id': 1, 'name': 'Cabang Utama'},
                    ],
                  }
                ],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: BookingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Exactly ONE booking card for RC-MULTI-005
      expect(find.text('RC-MULTI-005'), findsOneWidget);
      // Main item is iPhone 13
      expect(find.text('iPhone 13'), findsOneWidget);
      // All 3 add-ons are counted
      expect(find.text('Item Add-on (3):'), findsOneWidget);
      expect(find.textContaining('Power Bank'), findsOneWidget);
      expect(find.textContaining('Charger'), findsOneWidget);
      expect(find.textContaining('Cable'), findsOneWidget);
    });
  });
}

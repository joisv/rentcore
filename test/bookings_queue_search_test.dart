import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';

class _FakeSearchBookingRepository extends BookingRepository {
  String? lastStatus;
  String? lastSearch;
  int? lastBranchId;
  List<Map<String, dynamic>> returnData = [];

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    lastStatus = status;
    lastSearch = search;
    lastBranchId = branchId;

    var list = returnData;
    if (status != null && status != 'all') {
      list = list.where((b) => b['status'] == status).toList();
    }
    if (search != null && search.isNotEmpty) {
      final s = search.toLowerCase();
      list = list.where((b) {
        final code = (b['booking_code'] ?? '').toString().toLowerCase();
        final name = (b['customer']?['name'] ?? '').toString().toLowerCase();
        return code.contains(s) || name.contains(s);
      }).toList();
    }
    return list;
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

void main() {
  group('Rental Queue Search UI Tests', () {
    late _FakeSearchBookingRepository fakeRepo;
    late BusinessState businessState;

    final dummyBooking1 = {
      'id': 101,
      'booking_code': 'RC-261024-0001',
      'affiliate_id': 1,
      'business_id': 1,
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 21)).toIso8601String(),
      'total_bill': 300000.0,
      'customer': {
        'id': 10,
        'name': 'Budi Santoso',
        'phone': '08123456789',
      },
      'items': [
        {
          'id': 1,
          'asset': {
            'id': 20,
            'asset_code': 'AST-01',
            'model': {'id': 5, 'name': 'iPhone 15 Pro'},
          },
        },
      ],
    };

    final dummyBooking2 = {
      'id': 102,
      'booking_code': 'RC-261024-0002',
      'affiliate_id': 1,
      'business_id': 1,
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 19)).toIso8601String(),
      'total_bill': 500000.0,
      'customer': {
        'id': 11,
        'name': 'Siti Rahma',
        'phone': '08987654321',
      },
      'items': [
        {
          'id': 2,
          'asset': {
            'id': 21,
            'asset_code': 'MAC-02',
            'model': {'id': 6, 'name': 'MacBook Pro M3'},
          },
        },
      ],
    };

    setUp(() {
      fakeRepo = _FakeSearchBookingRepository()
        ..returnData = [dummyBooking1, dummyBooking2];

      businessState = BusinessState(
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
    });

    testWidgets('renders search input bar with search icon and placeholder', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Cari kode booking, nama, telp, atau unit...'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.text('RC-261024-0001'), findsOneWidget);
      expect(find.text('RC-261024-0002'), findsOneWidget);
    });

    testWidgets('typing query in search bar triggers debounced search and filters results', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query 'Siti'
      await tester.enterText(find.byType(TextField), 'Siti');
      // Wait for 300ms debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastSearch, 'Siti');
      expect(find.text('RC-261024-0002'), findsOneWidget);
      expect(find.text('RC-261024-0001'), findsNothing);
    });

    testWidgets('clear button appears and clearing resets search to full list', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Initially clear button is not visible
      expect(find.byIcon(Icons.clear_rounded), findsNothing);

      // Enter search query
      await tester.enterText(find.byType(TextField), 'Budi');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.clear_rounded), findsOneWidget);
      expect(find.text('RC-261024-0001'), findsOneWidget);
      expect(find.text('RC-261024-0002'), findsNothing);

      // Tap clear button
      await tester.tap(find.byIcon(Icons.clear_rounded));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastSearch, isNull);
      expect(find.text('RC-261024-0001'), findsOneWidget);
      expect(find.text('RC-261024-0002'), findsOneWidget);
    });

    testWidgets('displays search-specific empty state with reset button when no records match', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(fakeRepo),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessState)),
          ],
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Enter non-matching query
      await tester.enterText(find.byType(TextField), 'NonExistentItem');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.search_off_rounded), findsOneWidget);
      expect(find.text('Tidak ditemukan transaksi sewa yang cocok.'), findsOneWidget);
      expect(find.text('Kata kunci: "NonExistentItem"'), findsOneWidget);
      expect(find.text('Reset Pencarian'), findsOneWidget);

      // Tap 'Reset Pencarian'
      await tester.tap(find.text('Reset Pencarian'));
      await tester.pumpAndSettle();

      expect(fakeRepo.lastSearch, isNull);
      expect(find.text('RC-261024-0001'), findsOneWidget);
      expect(find.text('RC-261024-0002'), findsOneWidget);
    });
  });
}

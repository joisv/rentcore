import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';

class _FakeBookingRepository extends BookingRepository {
  String? lastStatus;
  String? lastSearch;
  int? lastBranchId;
  bool lastAllBranches = false;

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
    lastAllBranches = allBranches;

    if (status == 'overdue') {
      return returnData.where((b) {
        if (b['status'] != 'rented') return false;
        final endAt = b['end_at'] != null ? DateTime.tryParse(b['end_at']) : null;
        return endAt != null && endAt.isBefore(DateTime.now());
      }).toList();
    } else if (status == 'rented') {
      return returnData.where((b) => b['status'] == 'rented').toList();
    } else if (status == 'returned') {
      return returnData.where((b) => b['status'] == 'returned').toList();
    }

    return returnData;
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;

  void changeBranch(int? newBranchId, String? newBranchName) {
    state = state.copyWith(
      activeBranchId: newBranchId,
      activeBranchName: newBranchName,
      clearBranch: newBranchId == null,
    );
  }
}

void main() {
  group('Branch Rental Queue Overdue Filter Tests', () {
    late _FakeBookingRepository fakeRepo;

    final dummyOverdueBooking = {
      'id': 101,
      'booking_code': 'RC-OD-001',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'rented',
      'start_at': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'end_at': DateTime.now().subtract(const Duration(hours: 4)).toIso8601String(),
      'customer': {
        'id': 1,
        'name': 'Budi Santoso',
        'phone': '081234567890',
      },
      'items': [
        {
          'id': 1,
          'asset': {
            'id': 50,
            'asset_code': 'IPHONE-15PM-01',
            'model': {
              'id': 5,
              'name': 'iPhone 15 Pro Max',
            },
          },
        },
      ],
    };

    final dummyActiveBooking = {
      'id': 102,
      'booking_code': 'RC-ACT-002',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'rented',
      'start_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 22)).toIso8601String(),
      'customer': {
        'id': 2,
        'name': 'Siti Rahma',
        'phone': '089876543210',
      },
      'items': [
        {
          'id': 2,
          'asset': {
            'id': 51,
            'asset_code': 'IPHONE-15-02',
            'model': {
              'id': 6,
              'name': 'iPhone 15',
            },
          },
        },
      ],
    };

    final dummyReturnedBooking = {
      'id': 103,
      'booking_code': 'RC-RET-003',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'returned',
      'start_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
      'end_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
      'customer': {
        'id': 3,
        'name': 'Ahmad Fauzi',
        'phone': '081122334455',
      },
      'items': [
        {
          'id': 3,
          'asset': {
            'id': 52,
            'asset_code': 'IPHONE-14-03',
            'model': {
              'id': 7,
              'name': 'iPhone 14',
            },
          },
        },
      ],
    };

    setUp(() {
      fakeRepo = _FakeBookingRepository();
      fakeRepo.returnData = [
        dummyOverdueBooking,
        dummyActiveBooking,
        dummyReturnedBooking,
      ];
    });

    testWidgets('Selecting Terlambat chip fetches overdue bookings with active branchId', (tester) async {
      final testNotifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Store',
          activeBranchId: 1,
          activeBranchName: 'Cabang Pusat',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Store',
              'branches': [
                {'id': 1, 'name': 'Cabang Pusat'},
                {'id': 2, 'name': 'Cabang Barat'},
              ],
            }
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => testNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // By default, filter is 'rented'
      expect(fakeRepo.lastStatus, 'rented');
      expect(fakeRepo.lastBranchId, 1);
      expect(find.text('RC-OD-001'), findsOneWidget);
      expect(find.text('RC-ACT-002'), findsOneWidget);

      // Tap on 'Terlambat' chip
      final overdueChip = find.text('Terlambat');
      expect(overdueChip, findsOneWidget);
      await tester.tap(overdueChip);
      await tester.pumpAndSettle();

      // Verify repo was called with overdue status and branchId: 1
      expect(fakeRepo.lastStatus, 'overdue');
      expect(fakeRepo.lastBranchId, 1);

      // Verify overdue booking is displayed and active booking is excluded
      expect(find.text('RC-OD-001'), findsOneWidget);
      expect(find.textContaining('Budi Santoso'), findsOneWidget);
      expect(find.text('iPhone 15 Pro Max'), findsOneWidget);
      expect(find.text('RC-ACT-002'), findsNothing);
      expect(find.text('RC-RET-003'), findsNothing);

      // Verify action buttons exist for overdue booking
      expect(find.text('Tambah Jam'), findsOneWidget);
      expect(find.text('Pengembalian'), findsOneWidget);
    });

    testWidgets('Switching branch updates branchId parameter in bookingsListProvider', (tester) async {
      final testNotifier = _TestBusinessNotifier(
        const BusinessState(
          activeBusinessId: 10,
          activeBusinessName: 'RentCore Store',
          activeBranchId: 1,
          activeBranchName: 'Cabang Pusat',
          businesses: [
            {
              'id': 10,
              'name': 'RentCore Store',
              'branches': [
                {'id': 1, 'name': 'Cabang Pusat'},
                {'id': 2, 'name': 'Cabang Barat'},
              ],
            }
          ],
        ),
      );

      final container = ProviderContainer(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(() => testNotifier),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: BookingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(fakeRepo.lastBranchId, 1);

      // Switch active branch to Branch 2
      testNotifier.changeBranch(2, 'Cabang Barat');
      await tester.pumpAndSettle();

      expect(fakeRepo.lastBranchId, 2);
    });
  });
}

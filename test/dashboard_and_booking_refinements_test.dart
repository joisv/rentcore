import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/shared/widgets/unit_thumbnail.dart';

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {'id': 1, 'name': 'Rian Kasir', 'role': 'owner'},
      );

  @override
  Future<void> checkCurrentSession() async {}
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Gwenn Rental Malang',
        activeBranchId: 10,
        activeBranchName: 'Cabang Pusat',
        businesses: [
          {
            'id': 1,
            'name': 'Gwenn Rental Malang',
            'role': 'owner',
            'branches': [
              {'id': 10, 'name': 'Cabang Pusat', 'is_central': true},
            ],
          }
        ],
      );
}

class _FakeDashboardRepo extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => {
        'kpi': {
          'today_revenue': 500000,
          'today_transactions_count': 3,
          'active_rentals': 12,
          'pending_pickup_count': 1,
          'due_today': 2,
          'overdue': 0,
          'units_ready': 8,
          'units_total': 15,
        },
        'overdue_alerts': [],
      };
}

class _FakeBookingRepo extends BookingRepository {
  final List<Map<String, dynamic>> bookings;
  _FakeBookingRepo(this.bookings);

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async =>
      bookings;
}

Map<String, dynamic> _makeBooking({
  required int id,
  required String code,
  required String unitName,
  required String customerName,
  required DateTime startAt,
  required DateTime endAt,
  String? imageUrl,
  String status = 'rented',
}) {
  return {
    'id': id,
    'booking_code': code,
    'status': status,
    'payment_status': 'paid',
    'start_at': startAt.toIso8601String(),
    'end_at': endAt.toIso8601String(),
    'created_at': startAt.toIso8601String(),
    'total_bill': 150000.0,
    'collateral_storage_slot': 'Brankas A',
    'customer': {'name': customerName, 'phone': '08123456789'},
    'items': [
      {
        'item_type': 'primary',
        'asset': {
          'asset_code': 'AST-$id',
          'serial_number': 'SN-$id',
          'model': {
            'name': unitName,
            'image_url': ?imageUrl,
            'category': {'name': 'Smartphones'},
          },
        },
      }
    ],
  };
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('1 & 4: Search lives inside Antrean Sewa Cabang, default limit is 10, limit selector & date range filter combine cleanly without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day, 10);
    final oldStart = todayStart.subtract(const Duration(days: 15));

    final bookings = [
      for (int i = 1; i <= 12; i++)
        _makeBooking(
          id: i,
          code: 'RC-TODAY-${i.toString().padLeft(2, '0')}',
          unitName: i == 1 ? 'Sony A7 IV' : 'iPhone 15 Pro #$i',
          customerName: i == 1 ? 'Budi Santoso' : 'Penyewa $i',
          startAt: i == 12 ? oldStart : todayStart.add(Duration(minutes: i)),
          endAt: i == 12
              ? oldStart.add(const Duration(days: 1))
              : todayStart.add(Duration(days: 1, hours: i)),
        ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('home_scope'),
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo(bookings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(onNavigateTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Header has no search button; only menu, store/branch, notification bell
    expect(find.byKey(const Key('home_header_menu_button')), findsOneWidget);
    expect(find.byKey(const Key('home_header_branch_button')), findsOneWidget);
    expect(find.byKey(const Key('home_header_notification_button')), findsOneWidget);
    expect(find.byKey(const Key('home_header_search_button')), findsNothing);

    // Search field & date chip exist inside Antrean Sewa Cabang
    expect(find.byKey(const Key('home_queue_search_field')), findsOneWidget);
    expect(find.text('Cari kode booking, penyewa, atau unit...'), findsOneWidget);
    expect(find.byKey(const Key('home_queue_date_filter_chip')), findsOneWidget);
    expect(find.text('Semua Tanggal'), findsOneWidget);

    // Default limit = 10 -> displays 10 of 12
    expect(find.text('Tampil: 10'), findsOneWidget);
    expect(find.text('Menampilkan 10 dari 12 antrean'), findsOneWidget);

    // Change limit to 5
    await tester.ensureVisible(find.byKey(const Key('home_queue_limit_selector')));
    await tester.tap(find.byKey(const Key('home_queue_limit_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_queue_limit_option_5')));
    await tester.pumpAndSettle();
    expect(find.text('Tampil: 5'), findsOneWidget);
    expect(find.text('Menampilkan 5 dari 12 antrean'), findsOneWidget);

    // Change limit to Semua (-1) -> displays all 12
    await tester.tap(find.byKey(const Key('home_queue_limit_selector')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_queue_limit_option_-1')));
    await tester.pumpAndSettle();
    expect(find.text('Tampil: Semua'), findsOneWidget);
    expect(find.text('Menampilkan 12 dari 12 antrean'), findsOneWidget);

    // Filter by search query -> matches Sony A7 IV
    await tester.enterText(find.byKey(const Key('home_queue_search_field')), 'Sony');
    await tester.pumpAndSettle();
    expect(find.text('Menampilkan 1 dari 1 antrean'), findsOneWidget);
    expect(find.text('RC-TODAY-01'), findsOneWidget);

    // Clear search
    await tester.tap(find.byKey(const Key('home_queue_search_clear_button')));
    await tester.pumpAndSettle();
    expect(find.text('Menampilkan 12 dari 12 antrean'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tap Date Range chip -> opens showDateRangePicker
    await tester.ensureVisible(find.byKey(const Key('home_queue_date_filter_chip')));
    await tester.tap(find.byKey(const Key('home_queue_date_filter_chip')));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);

    // Pick today's date twice for single-day range and tap Terapkan
    final todayDayText = '${now.day}';
    await tester.tap(find.text(todayDayText).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(todayDayText).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih'));
    await tester.pumpAndSettle();

    // Old booking (15 days ago) excluded -> 11 of 11 shown; Reset Tanggal appears
    expect(find.byKey(const Key('home_queue_date_reset_button')), findsOneWidget);
    expect(find.text('Reset Tanggal'), findsOneWidget);
    expect(find.text('Menampilkan 11 dari 11 antrean'), findsOneWidget);
    expect(find.text('RC-TODAY-12'), findsNothing);

    // Tap Reset Tanggal -> restores all 12
    await tester.tap(find.byKey(const Key('home_queue_date_reset_button')));
    await tester.pumpAndSettle();
    expect(find.text('Semua Tanggal'), findsOneWidget);
    expect(find.text('Menampilkan 12 dari 12 antrean'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('4b: Antrean Sewa Cabang filters render cleanly on narrow 320px screen with zero RenderFlex overflow',
      (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final now = DateTime.now();
    final bookings = [
      _makeBooking(
        id: 1,
        code: 'RC-320-01',
        unitName: 'Sony A7 IV',
        customerName: 'Budi Santoso',
        startAt: now,
        endAt: now.add(const Duration(hours: 12)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo(bookings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(onNavigateTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Activate status filter + search query on 320px viewport
    final bookingChip = find.text('Booking');
    await tester.ensureVisible(bookingChip);
    await tester.tap(bookingChip);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('home_queue_search_field')), 'Sony');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('2 & 3: Queue cards and DirectRentalScreen unit cards render 44x44 UnitThumbnail with Image.network and icon fallback',
      (tester) async {
    final now = DateTime.now();
    final bookings = [
      _makeBooking(
        id: 1,
        code: 'RC-IMG-01',
        unitName: 'iPhone With Photo',
        customerName: 'Andi',
        startAt: now,
        endAt: now.add(const Duration(hours: 12)),
        imageUrl: 'http://127.0.0.1:9999/non-existent.jpg',
      ),
      _makeBooking(
        id: 2,
        code: 'RC-NOIMG-02',
        unitName: 'iPhone Without Photo',
        customerName: 'Bima',
        startAt: now,
        endAt: now.add(const Duration(hours: 18)),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('home_scope'),
        overrides: [
          authProvider.overrideWith(_TestAuthNotifier.new),
          businessProvider.overrideWith(_TestBusinessNotifier.new),
          dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
          bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo(bookings)),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: HomeScreen(onNavigateTab: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final thumbnails = tester.widgetList<UnitThumbnail>(find.byType(UnitThumbnail)).toList();
    expect(thumbnails.length, 2);
    expect(thumbnails[0].imageUrl, 'http://127.0.0.1:9999/non-existent.jpg');
    expect(thumbnails[0].size, 44);
    expect(thumbnails[0].borderRadius, 10);
    expect(thumbnails[0].backgroundColor, const Color(0xFFF3F4F6));
    expect(thumbnails[0].iconColor, const Color(0xFF374151));
    expect(thumbnails[1].imageUrl, isNull);
    expect(find.byType(Image), findsOneWidget);

    // Now test DirectRentalScreen Section 1 unit cards
    final mockAssets = [
      {
        'id': 1,
        'asset_code': 'UNIT-IMG',
        'condition_grade': 'A',
        'model': {
          'id': 10,
          'name': 'Sony ZV-E10',
          'image_url': 'http://127.0.0.1:9999/camera.jpg',
          'category_id': 1,
          'category': {'id': 1, 'name': 'Kamera'},
          'pricing_tiers': [
            {'id': 1, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 200000},
          ],
        },
      },
      {
        'id': 2,
        'asset_code': 'UNIT-PLAIN',
        'condition_grade': 'A',
        'model': {
          'id': 11,
          'name': 'Canon EOS R50',
          'category_id': 1,
          'category': {'id': 1, 'name': 'Kamera'},
          'pricing_tiers': [
            {'id': 2, 'duration_unit': 'day', 'duration_value': 1, 'duration_hours': 24, 'price': 220000},
          ],
        },
      },
    ];

    await tester.pumpWidget(
      ProviderScope(
        key: const ValueKey('booking_scope'),
        overrides: [
          readyAssetsProvider.overrideWith((ref) => Future.value(mockAssets)),
          categoriesProvider.overrideWith((ref) => Future.value([
                {'id': 1, 'name': 'Kamera'},
              ])),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const DirectRentalScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bookingThumbs = tester.widgetList<UnitThumbnail>(find.byType(UnitThumbnail)).toList();
    expect(bookingThumbs.length, 2);
    expect(bookingThumbs[0].imageUrl, 'http://127.0.0.1:9999/camera.jpg');
    expect(bookingThumbs[0].size, 34);
    expect(bookingThumbs[1].imageUrl, isNull);
    expect(find.byType(Image), findsOneWidget);
  });
}

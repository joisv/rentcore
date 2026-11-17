import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/constants/app_colors.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/core/utils/date_formatter.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/shared/widgets/status_badge.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDashboardRepo extends DashboardRepository {
  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async => {
    'is_empty_tenant': false,
    'branch_id': 10,
    'is_consolidated': false,
    'kpi': {
      'today_revenue': 280000.0,
      'today_rentals_created': 1,
      'today_transactions_count': 1,
      'due_today': 0,
      'units_ready': 8,
      'units_total': 10,
      'units_rented': 2,
      'units_maintenance': 0,
      'utilization_rate': 20.0,
      'overdue': 0,
    },
    'overdue_alerts': [],
    'imminent_returns': [],
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
  }) async => bookings;
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Express',
    activeBranchId: 10,
    activeBranchName: 'Cabang Mataram Utama',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Express',
        'role': 'owner',
        'branches': [
          {
            'id': 10,
            'name': 'Cabang Mataram Utama',
            'city': 'Mataram',
            'is_central': true,
          },
        ],
      },
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    isAuthenticated: true,
    user: {'id': '1', 'name': 'Rian Kasir', 'role': 'owner'},
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildHome(List<Map<String, dynamic>> bookings) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(_TestAuthNotifier.new),
        businessProvider.overrideWith(_TestBusinessNotifier.new),
        dashboardRepositoryProvider.overrideWithValue(_FakeDashboardRepo()),
        bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo(bookings)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(onNavigateTab: (_) {}, onOpenDirectRental: () {}),
      ),
    );
  }

  group('HomeScreen Queue Card Detailed Layout Mirror Tests', () {
    testWidgets(
      'Renders Antrean Sewa Cabang upper/middle layout and preserves bottom 3-element action row',
      (tester) async {
        tester.view.physicalSize = const Size(430, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final endAt = DateTime.now().add(const Duration(hours: 24));
        final bookings = [
          {
            'id': 101,
            'booking_code': 'RC-261114-0001-O7Q',
            'status': 'rented',
            'payment_status': 'paid',
            'end_at': endAt.toIso8601String(),
            'total_bill': 280000.0,
            'collateral_storage_slot': 'Brankas B, Slot 02',
            'customer': {'name': 'jois', 'phone': '083146838432'},
            'items': [
              {
                'item_type': 'primary',
                'asset': {
                  'asset_code': 'FCHGTS42555',
                  'serial_number': 'JVYJFHHFVYU',
                  'model': {'name': 'iPhone 17 pro Max'},
                },
              },
            ],
          },
        ];

        await tester.pumpWidget(buildHome(bookings));
        await tester.pumpAndSettle();

        // 1. Top Header Row: Booking Code pill + soft blue remaining time badge
        expect(find.text('RC-261114-0001-O7Q'), findsOneWidget);
        final statusBadge = tester.widget<StatusBadge>(
          find.byType(StatusBadge).first,
        );
        expect(statusBadge.label, startsWith('Sisa '));
        expect(statusBadge.textColor, AppColors.info);
        expect(statusBadge.backgroundColor, AppColors.infoLight);

        // 2. Deadline Sub-row: clock icon + Batas sewa: <formatted>
        expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
        expect(
          find.text('Batas sewa: ${DateFormatter.formatFull(endAt)}'),
          findsOneWidget,
        );

        // 3. Unit & Customer Info Block: 44x44 UnitThumbnail category icon box + 4 detail lines
        final iconFinder = find.byIcon(Icons.phone_iphone_rounded);
        expect(iconFinder, findsOneWidget);
        final iconContainerFinder = find.ancestor(
          of: iconFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.minWidth == 44 &&
                w.constraints?.minHeight == 44,
          ),
        );
        expect(iconContainerFinder, findsOneWidget);

        expect(find.text('iPhone 17 pro Max'), findsOneWidget);
        final metaText = tester.widget<Text>(
          find.text('FCHGTS42555 • SN: JVYJFHHFVYU'),
        );
        expect(metaText.style?.fontFamily, 'monospace');
        expect(find.text('jois • 083146838432'), findsOneWidget);
        expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
        expect(find.text('Jaminan: Brankas B, Slot 02'), findsOneWidget);

        // 4. Total Tagihan Strip: Colors.grey.shade100 + tabularFigures
        expect(find.text('Total Tagihan'), findsOneWidget);
        final totalTextFinder = find.text('Total: Rp 280.000');
        expect(totalTextFinder, findsOneWidget);
        final totalTextWidget = tester.widget<Text>(totalTextFinder);
        expect(
          totalTextWidget.style?.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        final totalStripFinder = find.ancestor(
          of: totalTextFinder,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration as BoxDecoration).color == Colors.grey.shade100,
          ),
        );
        expect(totalStripFinder, findsOneWidget);

        // 5. Bottom action row preserved untouched
        expect(find.widgetWithText(OutlinedButton, 'Rincian'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Kembalikan'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.more_vert_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Displays amber Jatuh Tempo and red Terlambat pills accurately and handles compact 320px width with zero RenderFlex overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 1200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          errors.add(details);
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        final now = DateTime.now();
        final bookings = [
          {
            'id': 201,
            'booking_code': 'RC-261114-0002-LONG-CODE-CHECK',
            'status': 'rented',
            'payment_status': 'paid',
            'end_at': now.subtract(const Duration(hours: 2)).toIso8601String(),
            'total_bill': 12500000.0,
            'collateral_storage_slot':
                'Brankas Utama Lantai 2, Slot Sangat Panjang 09',
            'customer': {
              'name': 'Muhammad Alexander Panjang Banget',
              'phone': '08123456789012',
            },
            'items': [
              {
                'item_type': 'primary',
                'asset': {
                  'asset_code': 'CAM-SONY-FX3-SUPER-LONG',
                  'serial_number': 'SN9988776655443322',
                  'model': {
                    'name': 'Sony A7 IV Kamera Mirrorless Full Frame',
                  },
                },
              },
            ],
          },
          {
            'id': 202,
            'booking_code': 'RC-261114-0003-DUE',
            'status': 'rented',
            'payment_status': 'paid',
            'end_at': DateTime(now.year, now.month, now.day, 23, 55)
                .toIso8601String(),
            'total_bill': 350000.0,
            'customer': {'name': 'Budi', 'phone': '08222222222'},
            'items': [
              {
                'item_type': 'primary',
                'asset': {
                  'asset_code': 'DRONE-01',
                  'model': {'name': 'DJI Mavic 3 Pro'},
                },
              },
            ],
          },
        ];

        await tester.pumpWidget(buildHome(bookings));
        await tester.pumpAndSettle();

        final badges = tester
            .widgetList<StatusBadge>(find.byType(StatusBadge))
            .toList();
        expect(badges.any((b) => b.textColor == AppColors.danger), isTrue);
        expect(
          badges.any(
            (b) => b.label == 'Jatuh Tempo' && b.textColor == AppColors.warning,
          ),
          isTrue,
        );
        expect(find.byIcon(Icons.camera_alt_rounded), findsOneWidget);
        expect(find.byIcon(Icons.flight_takeoff_rounded), findsOneWidget);
        expect(find.text('Total: Rp 12.500.000'), findsOneWidget);
        expect(find.text('Total: Rp 350.000'), findsOneWidget);
        expect(errors, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  });
}

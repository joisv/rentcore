import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/constants/app_colors.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/bookings_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';

class _FakeBookingRepositoryForPolish extends BookingRepository {
  List<Map<String, dynamic>> returnData = [];

  @override
  Future<List<Map<String, dynamic>>> fetchBookings({
    String? status,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return returnData;
  }

  @override
  Future<Map<String, dynamic>> adjustDuration({
    required int bookingId,
    int? bookingItemId,
    required String direction,
    required int hoursDelta,
    double? additionalFee,
    int? paymentMethodId,
    double? cashReceived,
    String? managerPin,
    String? reason,
    String? notes,
  }) async {
    return {
      'success': true,
      'message': 'Success',
      'data': {'id': bookingId},
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _TestBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

void main() {
  group('Rental Queue & Duration Sheet UI Polish & Visual Hierarchy Tests', () {
    late _FakeBookingRepositoryForPolish fakeRepo;

    final dummyCampingBooking = {
      'id': 301,
      'booking_code': 'RC-CAMP-001',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'rented',
      'duration_hours': 48,
      'start_at': DateTime.now().subtract(const Duration(hours: 5)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 43)).toIso8601String(),
      'total_bill': 120000.0,
      'collateral_storage_slot': 'Slot Kemah A-01',
      'customer': {
        'id': 20,
        'name': 'Fajar Nugraha',
        'phone': '08123456789',
      },
      'items': [
        {
          'id': 31,
          'item_type': 'primary',
          'duration_value': 48,
          'unit_price': 120000.0,
          'asset': {
            'id': 101,
            'asset_code': 'TND-001',
            'model': {
              'id': 15,
              'name': 'Tenda Dome 4P (Tenda 001)',
              'category': {'name': 'Camping & Outdoor'},
              'pricing_tiers': [
                {'duration_hours': 24, 'duration_value': 1, 'duration_unit': 'day', 'price': 60000.0, 'is_active': true},
                {'duration_hours': 48, 'duration_value': 2, 'duration_unit': 'day', 'price': 110000.0, 'is_active': true},
              ],
            },
          },
        },
      ],
    };

    final dummyPhoneBooking = {
      'id': 302,
      'booking_code': 'RC-IPH-002',
      'affiliate_id': 1,
      'business_id': 10,
      'status': 'rented',
      'duration_hours': 24,
      'start_at': DateTime.now().subtract(const Duration(hours: 26)).toIso8601String(),
      'end_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(), // Overdue
      'total_bill': 150000.0,
      'collateral_storage_slot': 'Brankas Cabang B-02',
      'customer': {
        'id': 21,
        'name': 'Dina Marlina',
        'phone': '08987654321',
      },
      'items': [
        {
          'id': 32,
          'item_type': 'primary',
          'duration_value': 24,
          'unit_price': 150000.0,
          'asset': {
            'id': 102,
            'asset_code': 'IP15-02',
            'model': {
              'id': 16,
              'name': 'iPhone 15 Pro',
              'category': {'name': 'Smartphone'},
              'pricing_tiers': [
                {'duration_hours': 6, 'duration_value': 6, 'duration_unit': 'hour', 'price': 50000.0, 'is_active': true},
                {'duration_hours': 12, 'duration_value': 12, 'duration_unit': 'hour', 'price': 80000.0, 'is_active': true},
                {'duration_hours': 24, 'duration_value': 1, 'duration_unit': 'day', 'price': 150000.0, 'is_active': true},
              ],
            },
          },
        },
      ],
    };

    setUp(() {
      fakeRepo = _FakeBookingRepositoryForPolish();
      fakeRepo.returnData = [dummyCampingBooking, dummyPhoneBooking];
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          bookingRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(
            () => _TestBusinessNotifier(
              const BusinessState(
                activeBusinessId: 10,
                activeBusinessName: 'RentCore Store',
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
        child: const MaterialApp(
          home: BookingsScreen(),
        ),
      );
    }

    testWidgets('1. Dynamic category icon adapts to item: Camping renders cabin icon, iPhone renders phone icon', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Camping gear should render cabin_rounded icon rather than smartphone
      expect(find.byIcon(Icons.cabin_rounded), findsOneWidget);

      // Phone item should render phone_iphone_rounded icon
      expect(find.byIcon(Icons.phone_iphone_rounded), findsOneWidget);
    });

    testWidgets('2. Action Button styling harmony: Ganti Unit uses monochrome style without blue border', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      final gantiUnitButtons = find.widgetWithText(OutlinedButton, 'Ganti Unit');
      expect(gantiUnitButtons, findsAtLeastNWidgets(1));

      // Inspect first OutlinedButton for Ganti Unit: side border should NOT be blue (AppColors.info)
      final outlinedBtn = tester.widget<OutlinedButton>(gantiUnitButtons.first);
      final side = outlinedBtn.style?.side?.resolve({});
      expect(side?.color, isNot(AppColors.info));

      // Pengembalian button is ElevatedButton with dark background
      final returnButtons = find.widgetWithText(ElevatedButton, 'Pengembalian');
      expect(returnButtons, findsAtLeastNWidgets(1));
      final returnBtn = tester.widget<ElevatedButton>(returnButtons.first);
      final bg = returnBtn.style?.backgroundColor?.resolve({});
      expect(bg, AppColors.obsidian);
    });

    testWidgets('3. Original return deadline is displayed adjacent to duration badge and Total Bill is prominent', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Verify "Batas sewa:" label appears for both bookings
      expect(find.textContaining('Batas sewa:'), findsNWidgets(2));

      // Verify Total bill is prominently displayed
      expect(find.textContaining('Total: Rp 120.000'), findsOneWidget);
      expect(find.textContaining('Total: Rp 150.000'), findsOneWidget);
    });

    testWidgets('4. "Atur Durasi Sewa" sheet displays segmented controls, styled ChoiceChip, cost breakdown Divider, and high-contrast Pay Later button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap "Tambah Jam" on first booking
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam').first);
      await tester.pumpAndSettle();

      // Verify Modal Title
      expect(find.text('Atur Durasi Sewa'), findsOneWidget);

      // Verify Segmented Controls
      expect(find.text('+ Tambah Jam'), findsOneWidget);
      expect(find.text('- Kurangi Jam'), findsOneWidget);

      // Verify Duration ChoiceChip has rounded corners (radius 12)
      final durationChipFinder = find.ancestor(of: find.textContaining('Jam'), matching: find.byType(ChoiceChip));
      expect(durationChipFinder, findsAtLeastNWidgets(1));
      final chipWidget = tester.widget<ChoiceChip>(durationChipFinder.first);
      expect(chipWidget.shape, isA<RoundedRectangleBorder>());
      final shape = chipWidget.shape as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12));

      // Verify Cost Breakdown elements
      expect(find.text('Biaya Tambahan:'), findsOneWidget);
      expect(find.text('Estimasi Total Tagihan Baru:'), findsOneWidget);
      expect(find.byType(Divider), findsAtLeastNWidgets(1));

      // Verify high-contrast Pay Later action button with inline icon
      expect(find.text('Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)'), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
    });

    testWidgets('5. Layout safety: renders without RenderFlex overflow on compact 320x568 screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap "Tambah Jam" on compact screen
      await tester.tap(find.widgetWithText(OutlinedButton, 'Tambah Jam').first);
      await tester.pumpAndSettle();

      // Verify bottom sheet renders without crashing or throwing overflow
      expect(find.text('Atur Durasi Sewa'), findsOneWidget);
      expect(find.text('+ Tambah Jam'), findsOneWidget);
      expect(find.text('Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)'), findsOneWidget);
    });
  });
}

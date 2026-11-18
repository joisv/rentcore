import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/return_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';

class _FakeBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Flagship',
    activeBranchId: 1,
    activeBranchName: 'Cabang Pusat',
  );
}

class _FakeReturnBookingRepository extends BookingRepository {
  int? lastReturnBookingId;
  Map<String, dynamic>? lastReturnPayload;
  int processReturnCalls = 0;

  @override
  Future<Map<String, dynamic>> processReturn(
    int bookingId,
    Map<String, dynamic> returnData,
  ) async {
    processReturnCalls++;
    lastReturnBookingId = bookingId;
    lastReturnPayload = Map<String, dynamic>.from(returnData);
    return {'id': 900, 'total_penalty': 0};
  }
}

class _FakeCashierRepo extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchClosingSummary({
    int? branchId,
    String? date,
    String? startDate,
    String? endDate,
    bool allBranches = false,
  }) async => {};
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  Widget buildReturnScreen(
    Map<String, dynamic> booking,
    _FakeReturnBookingRepository repo,
  ) {
    return ProviderScope(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(repo),
        cashierRepositoryProvider.overrideWithValue(_FakeCashierRepo()),
        businessProvider.overrideWith(_FakeBusinessNotifier.new),
      ],
      child: MaterialApp(home: ReturnWizardScreen(booking: booking)),
    );
  }

  testWidgets(
    'Booking with add-ons blocks return until all add-ons are verified via checkbox or Centang Semua, then sends addons_returned and returned_addon_ids',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _FakeReturnBookingRepository();
      final bookingWithAddons = {
        'id': 321,
        'booking_code': 'RC-RET-321',
        'status': 'rented',
        'end_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'collateral_storage_slot': 'Brankas A, Slot 01',
        'customer': {'name': 'Nadia Putri'},
        'addons': [
          {
            'id': 101,
            'model_id': 71,
            'name': 'Charger 20W',
            'quantity': 1,
            'item_ids': [101],
          },
          {
            'id': 201,
            'model_id': 72,
            'name': 'Power Bank Anker',
            'quantity': 2,
            'item_ids': [201, 202],
          },
        ],
        'items': [
          {
            'id': 100,
            'item_type': 'primary',
            'asset': {
              'id': 10,
              'asset_code': 'IP15P-010',
              'model': {'id': 5, 'name': 'iPhone 15 Pro', 'brand': 'Apple'},
            },
          },
        ],
      };

      await tester.pumpWidget(buildReturnScreen(bookingWithAddons, repo));
      await tester.pumpAndSettle();

      // Add-on completeness card + Centang Semua + incomplete helper are visible
      expect(find.byKey(const Key('addon_checklist_card')), findsOneWidget);
      expect(find.text('Kelengkapan Add-on (0/2)'), findsOneWidget);
      expect(find.text('Centang Semua'), findsOneWidget);
      expect(find.text('Charger 20W • 1x'), findsOneWidget);
      expect(find.text('Power Bank Anker • 2x'), findsOneWidget);
      expect(
        find.text('Pastikan semua add-on dikembalikan lengkap'),
        findsOneWidget,
      );

      // Clear Apple iCloud switch first -> button STILL disabled because add-ons are 0/2
      await tester.tap(
        find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'),
      );
      await tester.pumpAndSettle();

      ElevatedButton submitBtn() => tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian'),
      );
      expect(submitBtn().onPressed, isNull);

      // Check 1 of 2 add-ons -> counter updates (1/2) and button stays disabled
      await tester.tap(find.byKey(const Key('addon_checkbox_71')));
      await tester.pumpAndSettle();
      expect(find.text('Kelengkapan Add-on (1/2)'), findsOneWidget);
      expect(submitBtn().onPressed, isNull);

      // Tap "Centang Semua" -> counter becomes 2/2, helper & Centang Semua disappear, button enables
      await tester.tap(find.byKey(const Key('addon_check_all_button')));
      await tester.pumpAndSettle();
      expect(find.text('Kelengkapan Add-on (2/2)'), findsOneWidget);
      expect(find.byKey(const Key('addon_check_all_button')), findsNothing);
      expect(find.byKey(const Key('addon_incomplete_helper')), findsNothing);
      expect(submitBtn().onPressed, isNotNull);

      // Submit return -> sends addons_returned: true and returned_addon_ids: [101, 201, 202]
      await tester.ensureVisible(find.text('Selesaikan Pengembalian'));
      await tester.tap(find.text('Selesaikan Pengembalian'));
      await tester.pumpAndSettle();

      expect(repo.processReturnCalls, 1);
      expect(repo.lastReturnBookingId, 321);
      expect(repo.lastReturnPayload?['addons_returned'], isTrue);
      expect(repo.lastReturnPayload?['returned_addon_ids'], [101, 201, 202]);
    },
  );

  testWidgets(
    'Booking without add-ons renders zero add-on checklist UI and submits standard return normally',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _FakeReturnBookingRepository();
      final standardBooking = {
        'id': 322,
        'booking_code': 'RC-STD-322',
        'status': 'rented',
        'end_at': DateTime.now().add(const Duration(hours: 2)).toUtc().toIso8601String(),
        'collateral_storage_slot': 'Brankas B, Slot 02',
        'customer': {'name': 'Andi Wijaya'},
        'addons': [],
        'items': [
          {
            'id': 105,
            'item_type': 'primary',
            'asset': {
              'id': 11,
              'asset_code': 'PS5-001',
              'model': {
                'id': 8,
                'name': 'PlayStation 5',
                'category': {'name': 'Konsol'},
              },
            },
          },
        ],
      };

      await tester.pumpWidget(buildReturnScreen(standardBooking, repo));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('addon_checklist_card')), findsNothing);
      expect(find.byKey(const Key('addon_incomplete_helper')), findsNothing);

      final submitBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian'),
      );
      expect(submitBtn.onPressed, isNotNull);

      await tester.ensureVisible(find.text('Selesaikan Pengembalian'));
      await tester.tap(find.text('Selesaikan Pengembalian'));
      await tester.pumpAndSettle();

      expect(repo.processReturnCalls, 1);
      expect(repo.lastReturnPayload?.containsKey('addons_returned'), isFalse);
    },
  );
}

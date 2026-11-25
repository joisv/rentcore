import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/bookings/presentation/direct_rental_screen.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/home/providers/dashboard_provider.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeDashboardData = <String, dynamic>{
    'kpi': {
      'total_revenue': 1500000,
      'active_rentals': 3,
      'overdue_rentals': 0,
      'ready_assets': 5,
      'rented_assets': 3,
      'maintenance_assets': 0,
      'fleet_total': 8,
      'today_bookings': 1,
      'today_returns': 1,
    },
    'overdue_list': [],
  };

  final fakeAssets = List<Map<String, dynamic>>.generate(
    5,
    (index) => {
      'id': index + 1,
      'unit_code': 'RC-00${index + 1}',
      'status': 'ready',
      'model': {
        'id': 10 + index,
        'name': 'iPhone ${13 + index} Pro',
        'brand': 'Apple',
        'category_id': 1,
        'category': {'id': 1, 'name': 'Smartphones'},
        'pricing_tiers': [
          {
            'id': 100 + index,
            'duration_unit': 'day',
            'duration_value': 1,
            'duration_hours': 24,
            'price': 250000,
          },
        ],
      },
    },
  );

  final fakeCategories = [
    {'id': 1, 'name': 'Smartphones'},
  ];

  Widget buildMainShellApp() {
    return ProviderScope(
      overrides: [
        dashboardKpiProvider.overrideWith((ref) => Future.value(fakeDashboardData)),
        readyAssetsProvider.overrideWith((ref) => Future.value(fakeAssets)),
        categoriesProvider.overrideWith((ref) => Future.value(fakeCategories)),
      ],
      child: const MaterialApp(home: MainShellScreen()),
    );
  }

  group('New Booking Modal Non-Draggable & PopScope Guard Tests', () {
    testWidgets(
      'Modal disables drag-to-dismiss, removes drag pill, keeps top-left 40x40 close button, and ignores rapid scroll/fling',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildMainShellApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byKey(const Key('nav_center_add_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.byType(DirectRentalScreen), findsOneWidget);
        expect(find.byType(DraggableScrollableSheet), findsNothing);

        // Close button is 40x40 and positioned to the left of the title
        final closeBtnFinder = find.byKey(
          const Key('new_booking_modal_close_button'),
        );
        expect(closeBtnFinder, findsOneWidget);
        final closeBtnRect = tester.getRect(closeBtnFinder);
        final titleRect = tester.getRect(find.text('Sewa / Booking Baru'));
        expect(closeBtnRect.size, const Size(40, 40));
        expect(closeBtnRect.left, lessThan(titleRect.left));

        // Verify no custom drag-handle pill (40x4) exists anywhere inside DirectRentalScreen
        final pillFinder = find.descendant(
          of: find.byType(DirectRentalScreen),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.maxWidth == 40 &&
                w.constraints?.maxHeight == 4,
          ),
        );
        expect(pillFinder, findsNothing);

        // Rapidly scroll down & up inside the booking form, then fling down on header
        final scrollFinder = find.descendant(
          of: find.byType(DirectRentalScreen),
          matching: find.byType(SingleChildScrollView),
        );
        await tester.fling(scrollFinder, const Offset(0, -800), 2000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.fling(scrollFinder, const Offset(0, 800), 2000);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.fling(
          find.text('Sewa / Booking Baru'),
          const Offset(0, 700),
          1500,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // Tapping near status bar edge does not dismiss (isDismissible: false)
        await tester.tapAt(const Offset(540, 5));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(DirectRentalScreen), findsOneWidget);

        // Untouched form closes immediately on X button tap with zero dialog
        await tester.tap(closeBtnFinder);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Batalkan Booking?'), findsNothing);
        expect(find.byType(DirectRentalScreen), findsNothing);
      },
    );

    testWidgets(
      'PopScope intercepts close and system back when unit is selected, allowing Lanjut Isi or Ya, Tutup',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildMainShellApp());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        await tester.tap(find.byKey(const Key('nav_center_add_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Select a unit (marks form dirty)
        await tester.tap(find.text('iPhone 13 Pro').first);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Tap X button -> confirmation dialog appears
        await tester.tap(find.byKey(const Key('new_booking_modal_close_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Batalkan Booking?'), findsOneWidget);
        expect(find.text('Lanjut Isi'), findsOneWidget);
        expect(find.text('Ya, Tutup'), findsOneWidget);

        // Tap Lanjut Isi -> stays open
        await tester.tap(find.text('Lanjut Isi'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Batalkan Booking?'), findsNothing);
        expect(find.byType(DirectRentalScreen), findsOneWidget);

        // Simulate Android system back via Navigator.maybePop -> confirmation dialog appears again
        final BuildContext innerContext = tester.element(
          find.byKey(const Key('new_booking_modal_close_button')),
        );
        await Navigator.of(innerContext).maybePop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Batalkan Booking?'), findsOneWidget);

        // Tap Ya, Tutup -> modal closes cleanly
        await tester.tap(find.text('Ya, Tutup'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DirectRentalScreen), findsNothing);
      },
    );

    testWidgets(
      'PopScope protects typed customer info when navigating back from DirectRentalScreen',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              readyAssetsProvider.overrideWith((ref) => Future.value(fakeAssets)),
              categoriesProvider.overrideWith(
                (ref) => Future.value(fakeCategories),
              ),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        enableDrag: false,
                        showDragHandle: false,
                        isDismissible: false,
                        useSafeArea: true,
                        builder: (_) => const SizedBox.expand(
                          child: DirectRentalScreen(showAppBar: false),
                        ),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();

        // Select unit + duration, proceed to Step 2, clear or type customer info
        await tester.tap(find.text('iPhone 13 Pro').first);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('1 Hari').first);
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();

        final textFields = find.byType(TextFormField);
        await tester.enterText(textFields.first, 'Budi Santoso');
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('new_booking_modal_close_button')));
        await tester.pumpAndSettle();
        expect(find.text('Batalkan Booking?'), findsOneWidget);

        await tester.tap(find.text('Ya, Tutup'));
        await tester.pumpAndSettle();
        expect(find.byType(DirectRentalScreen), findsNothing);
      },
    );
  });
}

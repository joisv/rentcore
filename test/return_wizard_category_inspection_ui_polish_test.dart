import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/return_wizard_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/data/payment_repository.dart';

class _FakeCashierRepo extends CashierRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async => [
        {'id': 1, 'name': 'Tunai', 'code': 'CASH'},
      ];
}

class _FakeBookingRepo extends BookingRepository {
  Map<String, dynamic>? submittedPayload;

  @override
  Future<Map<String, dynamic>> processReturn(int bookingId, Map<String, dynamic> returnData) async {
    submittedPayload = returnData;
    return {
      'id': 1,
      'booking_id': bookingId,
      'booking': {'id': bookingId, 'status': 'returned', 'payment_status': 'paid'},
    };
  }
}

class _TestBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() {
    return const BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'RentCore Central Business',
      activeBranchId: 1,
      activeBranchName: 'Cabang Utama',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCashierRepo fakeCashierRepo;
  late _FakeBookingRepo fakeBookingRepo;

  setUp(() {
    fakeCashierRepo = _FakeCashierRepo();
    fakeBookingRepo = _FakeBookingRepo();
  });

  Widget buildScreen(Map<String, dynamic> booking) {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
        businessProvider.overrideWith(() => _TestBusinessNotifier()),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(cashierRepo: fakeCashierRepo, bookingRepo: fakeBookingRepo),
        ),
      ],
      child: MaterialApp(
        home: ReturnWizardScreen(booking: booking),
      ),
    );
  }

  testWidgets('Apple booking renders iCloud card, mobile checklist, and simplified copy without decorative icons', (tester) async {
    tester.view.physicalSize = const Size(360, 800); // Standard mobile width
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final appleBooking = {
      'id': 301,
      'booking_code': 'RC-IPH-001',
      'collateral_storage_slot': 'Brankas A, Slot 05',
      'customer': {'name': 'Budi Santoso'},
      'start_at': DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
      'end_at': DateTime.now().subtract(const Duration(minutes: 1483)).toIso8601String(),
      'items': [
        {
          'asset': {
            'asset_code': 'IPH15-01',
            'model': {
              'brand': 'Apple',
              'name': 'iPhone 15 Pro Max',
              'pricing_tiers': [
                {'extension_hourly_rate': 20000.0},
              ],
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(appleBooking));
    await tester.pumpAndSettle();

    // 1. Collateral copy & no user icon
    expect(find.text('Jaminan: KTP (Brankas A, Slot 05)'), findsOneWidget);
    expect(find.byIcon(Icons.person_outline_rounded), findsNothing);

    // 2. Overdue formatted as '24j 43m' instead of '1483 mnt'
    expect(find.textContaining('24j 43m'), findsWidgets);
    expect(find.textContaining('1483 mnt'), findsNothing);

    // 3. Smartphone Account Clearance Card rendered with unified copy and without decorative alert/cross icon
    expect(find.text('Pemeriksaan Akun Perangkat'), findsOneWidget);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsOneWidget);
    expect(find.text('Wajib dipastikan sebelum unit diterima kembali'), findsOneWidget);
    expect(find.textContaining('Unit Terkunci / Lupa Sandi (Masuk Karantina)'), findsOneWidget);
    expect(find.byIcon(Icons.gpp_bad_rounded), findsNothing);
    expect(find.byIcon(Icons.warning_amber_rounded), findsNothing);

    // 4. Physical inspection card header and mobile checklist items
    expect(find.text('Kondisi & Kelengkapan'), findsOneWidget);
    expect(find.text('Layar sentuh & kamera'), findsOneWidget);
    expect(find.text('Kabel charger'), findsOneWidget);
    expect(find.text('Adaptor charger'), findsOneWidget);

    // 5. Grade A, B, C expanded buttons take equal 1/3 width without horizontal overflow
    expect(find.text('Grade A'), findsOneWidget);
    expect(find.text('Grade B'), findsOneWidget);
    expect(find.text('Grade C'), findsOneWidget);

    // 6. Staff notes without notes/hamburger icon
    expect(find.text('Catatan Staf (Opsional)'), findsOneWidget);
    expect(find.byIcon(Icons.notes_rounded), findsNothing);

    // 7. Penalty payment card without receipt icon and with restructured stacked options
    expect(find.text('Penyelesaian Denda'), findsOneWidget);
    expect(find.byIcon(Icons.receipt_long_rounded), findsNothing);
    expect(find.text('Bayar Sekarang'), findsOneWidget);
    expect(find.text('Bayar Nanti (Catat ke Tagihan)'), findsOneWidget);

    // 8. Submit button label and subtitle reminder
    expect(find.text('Selesaikan Pengembalian'), findsOneWidget);
    expect(find.text('Kembalikan jaminan fisik (Brankas A, Slot 05) ke pelanggan'), findsOneWidget);

    // 9. Verify iPhone return payload strictly includes iCloud and excludes Google FRP
    final icloudSwitch = find.byType(Switch).first;
    await tester.tap(icloudSwitch);
    await tester.pumpAndSettle();

    final payLaterFinder = find.text('Bayar Nanti (Catat ke Tagihan)');
    await tester.ensureVisible(payLaterFinder);
    await tester.tap(payLaterFinder);
    await tester.pumpAndSettle();

    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results['icloud_removed'], isTrue);
    expect(results['device_platform'], equals('ios'));
    expect(results.containsKey('frp_removed'), isFalse);
    expect(results.containsKey('google_account_removed'), isFalse);
    expect(results['screen_ok'], isTrue);
    expect(results['camera_ok'], isTrue);
    expect(find.text('Unit Berhasil Kembali!'), findsOneWidget);
  });

  testWidgets('Outdoor gear booking (Tenda 001) hides iCloud card, renders tent checklist, and returns successfully', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final tentBooking = {
      'id': 302,
      'booking_code': 'RC-TND-001',
      'collateral_storage_slot': 'Rak Outdoor B-03',
      'customer': {'name': 'Rian Petualang'},
      'start_at': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(), // On time
      'items': [
        {
          'asset': {
            'asset_code': 'TND-001',
            'model': {
              'name': 'Tenda Dome 4P (Tenda 001)',
              'category': {'name': 'Camping & Outdoor'},
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(tentBooking));
    await tester.pumpAndSettle();

    // 1. iCloud card is completely hidden for outdoor gear
    expect(find.text('Pemeriksaan Akun Perangkat'), findsNothing);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsNothing);
    expect(find.textContaining('Find My'), findsNothing);
    expect(find.textContaining('Perangkat non-smartphone'), findsNothing);

    // 2. Outdoor-specific checklist items are rendered
    expect(find.text('Frame & tiang tenda'), findsOneWidget);
    expect(find.text('Pasak & tali tenda'), findsOneWidget);
    expect(find.text('Kain tenda & ritsleting'), findsOneWidget);
    expect(find.text('Tas tenda (carry bag)'), findsOneWidget);

    // Mobile items are NOT present
    expect(find.text('Layar sentuh & kamera'), findsNothing);

    // 3. Can complete return directly without any iCloud block
    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results['tent_poles'], isTrue);
    expect(results['guy_lines'], isTrue);
    expect(results['tent_fabric'], isTrue);
    expect(results['carry_bag'], isTrue);
    expect(results.containsKey('icloud_removed'), isFalse);
    expect(find.text('Unit Berhasil Kembali!'), findsOneWidget);
  });

  testWidgets('PlayStation console booking renders console checklist and hides iCloud card', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final consoleBooking = {
      'id': 303,
      'booking_code': 'RC-PS5-001',
      'collateral_storage_slot': 'Loker Gaming 01',
      'customer': {'name': 'Dimas Gamer'},
      'start_at': DateTime.now().subtract(const Duration(hours: 24)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
      'items': [
        {
          'asset': {
            'asset_code': 'PS5-001',
            'model': {
              'brand': 'Sony',
              'name': 'PlayStation 5 Disc Edition',
              'category': {'name': 'Konsol Game'},
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(consoleBooking));
    await tester.pumpAndSettle();

    // 1. iCloud card is completely hidden
    expect(find.text('Pemeriksaan Akun Perangkat'), findsNothing);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsNothing);

    // 2. Console checklist items
    expect(find.text('Controller / Gamepad'), findsOneWidget);
    expect(find.text('Kabel HDMI'), findsOneWidget);
    expect(find.text('Kabel power'), findsOneWidget);
    expect(find.text('Bodi konsol'), findsOneWidget);

    // 3. Can complete return and payload is strictly console-scoped
    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results.containsKey('icloud_removed'), isFalse);
    expect(results['controller'], isTrue);
    expect(results['hdmi_cable'], isTrue);
    expect(results['power_cable'], isTrue);
    expect(results['console_chassis'], isTrue);
    final accessories = fakeBookingRepo.submittedPayload!['accessories_returned'] as Map;
    expect(accessories.containsKey('cable'), isFalse);
    expect(accessories.containsKey('adapter'), isFalse);
    expect(accessories['controller'], isTrue);
    expect(accessories['hdmi_cable'], isTrue);
    expect(accessories['power_cable'], isTrue);
  });

  testWidgets('Drone booking (DJI Mavic) renders general checklist, hides iCloud card, and completes return', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final droneBooking = {
      'id': 304,
      'booking_code': 'RC-DRN-001',
      'collateral_storage_slot': 'Loker Drone 02',
      'customer': {'name': 'Riko Pilot'},
      'start_at': DateTime.now().subtract(const Duration(hours: 12)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 12)).toIso8601String(),
      'items': [
        {
          'asset': {
            'asset_code': 'DRN-001',
            'model': {
              'brand': 'DJI',
              'name': 'DJI Mavic Air 2 Fly More Combo',
              'category': {'name': 'Drone & Aerial'},
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(droneBooking));
    await tester.pumpAndSettle();

    // 1. iCloud card is completely hidden
    expect(find.text('Pemeriksaan Akun Perangkat'), findsNothing);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsNothing);

    // 2. General checklist items
    expect(find.text('Unit berfungsi normal'), findsOneWidget);
    expect(find.text('Aksesoris standar lengkap'), findsOneWidget);
    expect(find.text('Bodi bebas kerusakan parah'), findsOneWidget);

    // 3. Complete return
    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results.containsKey('icloud_removed'), isFalse);
    expect(results['unit_operational'], isTrue);
    expect(results['accessories_complete'], isTrue);
    expect(results['body_intact'], isTrue);
    final accessories = fakeBookingRepo.submittedPayload!['accessories_returned'] as Map;
    expect(accessories['accessories_complete'], isTrue);
  });

  testWidgets('Powerbank booking renders general checklist and bypasses iCloud/phone checks', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final powerbankBooking = {
      'id': 305,
      'booking_code': 'RC-PWR-001',
      'collateral_storage_slot': 'Laci Aksesoris A-1',
      'customer': {'name': 'Siti Rahma'},
      'start_at': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 18)).toIso8601String(),
      'items': [
        {
          'asset': {
            'asset_code': 'PWR-001',
            'model': {
              'brand': 'Anker',
              'name': 'Anker 737 Power Bank 24000mAh',
              'category': {'name': 'Powerbank & Baterai'},
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(powerbankBooking));
    await tester.pumpAndSettle();

    // 1. iCloud card is completely hidden
    expect(find.text('Pemeriksaan Akun Perangkat'), findsNothing);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsNothing);

    // 2. Submit return
    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results.containsKey('icloud_removed'), isFalse);
    expect(results['unit_operational'], isTrue);
    expect(find.text('Unit Berhasil Kembali!'), findsOneWidget);
  });
}

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
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async => {
        'has_active_shift': true,
        'shift': {'id': 1, 'status': 'open'},
      };

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
  final BusinessState _initialState;
  _TestBusinessNotifier(this._initialState) : super();

  @override
  BusinessState build() => _initialState;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _FakeCashierRepo fakeCashierRepo;
  late _FakeBookingRepo fakeBookingRepo;

  final appleBooking = {
    'id': 201,
    'booking_code': 'BK-APPLE-201',
    'affiliate_id': 1,
    'business_id': 1,
    'status': 'rented',
    'payment_status': 'paid',
    'start_at': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
    'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    'total_bill': 150000.0,
    'collateral_storage_slot': 'Slot B-01',
    'customer': {'id': 1, 'name': 'Siti Apple', 'phone': '081234567890'},
    'items': [
      {
        'id': 1,
        'asset': {
          'id': 50,
          'asset_code': 'IPH15-01',
          'model': {'id': 10, 'brand': 'Apple', 'name': 'iPhone 15 Pro Max', 'requires_frp_check': true},
        },
      },
    ],
  };

  final androidBooking = {
    'id': 202,
    'booking_code': 'BK-ANDROID-202',
    'affiliate_id': 1,
    'business_id': 1,
    'status': 'rented',
    'payment_status': 'paid',
    'start_at': DateTime.now().subtract(const Duration(hours: 10)).toIso8601String(),
    'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
    'total_bill': 120000.0,
    'collateral_storage_slot': 'Slot B-02',
    'customer': {'id': 2, 'name': 'Budi Android', 'phone': '081234567891'},
    'items': [
      {
        'id': 2,
        'asset': {
          'id': 60,
          'asset_code': 'SMG24-01',
          'model': {'id': 20, 'brand': 'Samsung', 'name': 'Galaxy S24 Ultra', 'requires_frp_check': true},
        },
      },
    ],
  };

  final testBusinessState = const BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Central Business',
    activeBranchId: 1,
    activeBranchName: 'Cabang Utama',
  );

  setUp(() {
    fakeCashierRepo = _FakeCashierRepo();
    fakeBookingRepo = _FakeBookingRepo();
  });

  Widget buildScreen(Map<String, dynamic> booking) {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(fakeCashierRepo),
        bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
        businessProvider.overrideWith(() => _TestBusinessNotifier(testBusinessState)),
        paymentRepositoryProvider.overrideWithValue(
          PaymentRepository(cashierRepo: fakeCashierRepo, bookingRepo: fakeBookingRepo),
        ),
      ],
      child: MaterialApp(
        home: ReturnWizardScreen(booking: booking),
      ),
    );
  }

  testWidgets('Apple device renders unified smartphone account clearance card and requires confirmation', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(appleBooking));
    await tester.pumpAndSettle();

    expect(find.text('Pemeriksaan Akun Perangkat'), findsOneWidget);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsOneWidget);
    expect(find.text('Wajib dipastikan sebelum unit diterima kembali'), findsOneWidget);
    expect(find.textContaining('Unit Terkunci / Lupa Sandi'), findsOneWidget);

    final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian');
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNull);
  });

  testWidgets('Android smartphone shows account clearance card, guards submit until checked, and sends frp_cleared payload', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(androidBooking));
    await tester.pumpAndSettle();

    expect(find.text('Pemeriksaan Akun Perangkat'), findsOneWidget);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsOneWidget);
    expect(find.text('Wajib dipastikan sebelum unit diterima kembali'), findsOneWidget);

    // Submit disabled until confirmation switch is toggled
    final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian');
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNull);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNotNull);

    await tester.ensureVisible(submitBtnFinder);
    await tester.tap(submitBtnFinder);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    expect(fakeBookingRepo.submittedPayload!['frp_cleared'], isTrue);
    expect(fakeBookingRepo.submittedPayload!['account_removed'], isTrue);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results['frp_cleared'], isTrue);
    expect(results['account_removed'], isTrue);
    expect(results['frp_removed'], isTrue);
    expect(results['google_account_removed'], isTrue);
    expect(results['device_platform'], equals('android'));
  });

  testWidgets('Smartphone category normalization & RC-261030-0003-MYA penalty settlement sends frp_cleared', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    for (final catLabel in ['Smartphone', 'Handphone', 'HP', 'Phone', 'Mobile']) {
      final phoneBooking = {
        'id': 203,
        'booking_code': 'RC-261030-0003-MYA',
        'status': 'rented',
        'payment_status': 'dp_paid',
        'start_at': DateTime.now().subtract(const Duration(hours: 30)).toIso8601String(),
        'end_at': DateTime.now().add(const Duration(hours: 2)).toIso8601String(),
        'collateral_storage_slot': 'Slot C-03',
        'customer': {'id': 3, 'name': 'Maya'},
        'items': [
          {
            'asset': {
              'id': 70,
              'asset_code': 'HP-003',
              'model': {
                'id': 30,
                'brand': 'BrandX',
                'name': 'Generic Unit X',
                'category': {'name': catLabel},
              },
            },
          },
        ],
      };

      await tester.pumpWidget(buildScreen(phoneBooking));
      await tester.pumpAndSettle();
      expect(
        find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'),
        findsOneWidget,
        reason: 'Category "$catLabel" must show smartphone account clearance toggle',
      );
    }

    // Now test overdue RC-261030-0003-MYA return + Tunai penalty settlement
    final overduePhoneBooking = {
      'id': 204,
      'booking_code': 'RC-261030-0003-MYA',
      'status': 'rented',
      'payment_status': 'dp_paid',
      'start_at': DateTime.now().subtract(const Duration(hours: 48)).toIso8601String(),
      'end_at': DateTime.now().subtract(const Duration(hours: 3)).toIso8601String(),
      'collateral_storage_slot': 'Slot C-03',
      'customer': {'id': 3, 'name': 'Maya'},
      'items': [
        {
          'asset': {
            'id': 70,
            'asset_code': 'HP-003',
            'model': {
              'id': 30,
              'brand': 'Oppo',
              'name': 'Reno 11',
              'category': {'name': 'Handphone'},
              'pricing_tiers': [
                {'extension_hourly_rate': 15000.0},
              ],
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(overduePhoneBooking));
    await tester.pumpAndSettle();

    final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian');
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNull);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNotNull);

    await tester.ensureVisible(submitBtnFinder);
    await tester.tap(submitBtnFinder);
    await tester.pumpAndSettle();

    expect(find.text('Pembayaran Denda'), findsOneWidget);
    final tunaiCard = find.text('Tunai');
    await tester.ensureVisible(tunaiCard);
    await tester.tap(tunaiCard);
    await tester.pumpAndSettle();

    final payBtn = find.widgetWithText(ElevatedButton, 'PROSES PEMBAYARAN');
    await tester.ensureVisible(payBtn);
    await tester.tap(payBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    expect(fakeBookingRepo.submittedPayload!['frp_cleared'], isTrue);
    expect(fakeBookingRepo.submittedPayload!['account_removed'], isTrue);
    expect(fakeBookingRepo.submittedPayload!['penalty_payment_method_id'], 1);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results['frp_removed'], isTrue);
    expect(results['google_account_removed'], isTrue);
    expect(results['frp_cleared'], isTrue);
    expect(results['account_removed'], isTrue);
  });

  testWidgets('Non-smartphone unit (Camera) hides smartphone account toggle and allows direct submit', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final cameraBooking = {
      'id': 205,
      'booking_code': 'BK-CAM-205',
      'status': 'rented',
      'payment_status': 'paid',
      'start_at': DateTime.now().subtract(const Duration(hours: 6)).toIso8601String(),
      'end_at': DateTime.now().add(const Duration(hours: 6)).toIso8601String(),
      'collateral_storage_slot': 'Rak Kamera A-2',
      'customer': {'id': 4, 'name': 'Deni'},
      'items': [
        {
          'asset': {
            'id': 80,
            'asset_code': 'CAM-01',
            'model': {
              'id': 40,
              'brand': 'Sony',
              'name': 'Sony Alpha A7 IV',
              'category': {'name': 'Kamera & Lensa'},
            },
          },
        },
      ],
    };

    await tester.pumpWidget(buildScreen(cameraBooking));
    await tester.pumpAndSettle();

    expect(find.text('Pemeriksaan Akun Perangkat'), findsNothing);
    expect(find.text('Akun Perangkat (iCloud / Google / FRP) Sudah Dikeluarkan'), findsNothing);

    final submitBtnFinder = find.widgetWithText(ElevatedButton, 'Selesaikan Pengembalian');
    expect(tester.widget<ElevatedButton>(submitBtnFinder).onPressed, isNotNull);

    await tester.ensureVisible(submitBtnFinder);
    await tester.tap(submitBtnFinder);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    expect(fakeBookingRepo.submittedPayload!.containsKey('frp_cleared'), isFalse);
  });

  testWidgets('Quarantine flow validates staff notes and sends quarantine payload', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(appleBooking));
    await tester.pumpAndSettle();

    // 1. Tap Karantina Unit
    final quarantineBtn = find.textContaining('Unit Terkunci / Lupa Sandi');
    await tester.tap(quarantineBtn);
    await tester.pumpAndSettle();

    // Verify amber badge and note requirement
    expect(find.text('CATATAN TINDAK LANJUT KARANTINA (WAJIB)'), findsOneWidget);

    // 2. Attempt submit without notes -> SnackBar warning
    final submitBtn = find.text('Selesaikan Pengembalian');
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(find.textContaining('Catatan staf wajib diisi jika perangkat dikarantina'), findsOneWidget);
    expect(fakeBookingRepo.submittedPayload, isNull);

    // 3. Enter staff notes
    final noteField = find.byType(TextFormField).first;
    await tester.ensureVisible(noteField);
    await tester.enterText(noteField, 'Pelanggan lupa sandi Apple ID. Dalam proses pemulihan akun.');
    await tester.pumpAndSettle();

    // 4. Submit again -> Success
    await tester.ensureVisible(submitBtn);
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    expect(fakeBookingRepo.submittedPayload, isNotNull);
    final results = fakeBookingRepo.submittedPayload!['checklist_results'] as Map;
    expect(results['account_quarantined'], isTrue);
    expect(results['account_status'], equals('quarantined'));
    expect(results['icloud_removed'], isFalse);
    expect(fakeBookingRepo.submittedPayload!['staff_notes'], equals('Pelanggan lupa sandi Apple ID. Dalam proses pemulihan akun.'));
  });
}

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
  Future<List<Map<String, dynamic>>> fetchPaymentMethods() async => [
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
  _TestBusinessNotifier(BusinessState state) : super() {
    this.state = state;
  }
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

  testWidgets('Apple device renders Apple-specific guard header', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(appleBooking));
    await tester.pumpAndSettle();

    expect(find.text('iCLOUD & APPLE ACTIVATION GUARD (WAJIB)'), findsOneWidget);
    expect(find.textContaining('Find My dinonaktifkan'), findsOneWidget);
    expect(find.textContaining('Karantina Unit'), findsOneWidget);
  });

  testWidgets('Android device renders Google FRP-specific guard header', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(androidBooking));
    await tester.pumpAndSettle();

    expect(find.text('GOOGLE ACCOUNT & FRP GUARD (WAJIB)'), findsOneWidget);
    expect(find.textContaining('FRP aman'), findsOneWidget);
  });

  testWidgets('Quarantine flow validates staff notes and sends quarantine payload', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(buildScreen(appleBooking));
    await tester.pumpAndSettle();

    // 1. Tap Karantina Unit
    final quarantineBtn = find.textContaining('Karantina Unit');
    await tester.tap(quarantineBtn);
    await tester.pumpAndSettle();

    // Verify amber badge and note requirement
    expect(find.text('CATATAN TINDAK LANJUT KARANTINA (WAJIB)'), findsOneWidget);

    // 2. Attempt submit without notes -> SnackBar warning
    final submitBtn = find.text('Selesaikan Pengembalian & Ambil KTP 📥');
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

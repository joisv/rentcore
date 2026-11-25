import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:sewakasir/core/services/qris_service.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/cashier/data/cashier_repository.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:sewakasir/features/payments/models/payment_context.dart';
import 'package:sewakasir/features/payments/presentation/payment_page.dart';

const kSampleStaticPayload =
    '00020101021126580014ID.LINKAJA.WWW0118936009180000000001020712345675204581253033605802ID5911RENTCORE POS6007JAKARTA6105123406304A1B2';

class _TestAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _TestAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _TestBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _TestBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

class _FakeCashierRepoForDynamicQris extends CashierRepository {
  bool isDynamicQris;
  bool hasPayload;
  Map<String, dynamic>? lastUpdatedPayload;

  _FakeCashierRepoForDynamicQris({
    this.isDynamicQris = false,
    this.hasPayload = false,
  });

  @override
  Future<Map<String, dynamic>> fetchPaymentSettings({int? branchId}) async {
    return {
      'business_id': 1,
      'branch_id': branchId,
      'is_owner_or_admin': true,
      'config': {
        'ewallet_enabled': true,
        'ewallet_providers': {
          'shopeepay': true,
          'dana': true,
          'linkaja': true,
          'ovo': true,
        },
        'qris_statis_enabled': true,
        'is_dynamic_qris_enabled': isDynamicQris,
        'qris_raw_payload': hasPayload ? kSampleStaticPayload : null,
        'qris_image_path': hasPayload ? 'qris/sample.png' : null,
        'qris_image_url': hasPayload ? 'http://example.com/qris.png' : null,
        'cash_enabled': true,
        'bank_transfer_enabled': true,
      },
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchPaymentMethods({int? branchId}) async {
    return [
      {'id': 1, 'name': 'Tunai', 'code': 'CASH', 'is_active': true},
      {
        'id': 2,
        'name': 'QRIS',
        'code': 'QRIS',
        'is_active': true,
        'qris_image_url': hasPayload ? 'http://example.com/qris.png' : null,
        'is_dynamic_qris_enabled': isDynamicQris,
        'qris_raw_payload': hasPayload ? kSampleStaticPayload : null,
      },
      {'id': 3, 'name': 'Transfer Bank', 'code': 'TRANSFER', 'is_active': true},
    ];
  }

  @override
  Future<Map<String, dynamic>> updatePaymentSettings(dynamic payload) async {
    if (payload is Map<String, dynamic>) {
      lastUpdatedPayload = payload;
    }
    return fetchPaymentSettings(branchId: 1);
  }
}

class _FakeBookingRepo extends BookingRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final authStateOwner = AuthState(user: {'id': 1, 'role': 'owner'});
  final businessStateOwner = BusinessState(
    activeBusinessId: 1,
    activeBusinessName: 'RentCore Main',
    activeBranchId: 1,
    activeBranchName: 'Central Hub',
    businesses: [
      {
        'id': 1,
        'name': 'RentCore Main',
        'membership': {'role': 'owner'},
        'branches': [
          {'id': 1, 'name': 'Central Hub', 'is_central': true},
        ],
      },
    ],
  );

  group('Dynamic QRIS End-to-End Tests', () {
    testWidgets('Settings Screen: Toggle guard disabled when qris_raw_payload is null', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: false, hasPayload: false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: PaymentMethodSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Guard message must be displayed
      expect(
        find.text('Unggah gambar QRIS statis terlebih dahulu untuk mengaktifkan QRIS Dinamis.'),
        findsOneWidget,
      );

      // Switch toggle must be disabled (onChanged == null)
      final switchFinder = find.byKey(const Key('is_dynamic_qris_enabled_toggle'));
      expect(switchFinder, findsOneWidget);
      final Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.onChanged, isNull);
    });

    testWidgets('Settings Screen: Toggle guard active & interactive when qris_raw_payload exists', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: false, hasPayload: true);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: PaymentMethodSettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Ready banner must be visible
      expect(
        find.text('Barcode QRIS terdeteksi & siap untuk nominal otomatis.'),
        findsOneWidget,
      );

      // Switch toggle must be enabled and interactive
      final switchFinder = find.byKey(const Key('is_dynamic_qris_enabled_toggle'));
      expect(switchFinder, findsOneWidget);
      Switch switchWidget = tester.widget(switchFinder);
      expect(switchWidget.onChanged, isNotNull);
      expect(switchWidget.value, isFalse);

      // Tap to toggle on
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      switchWidget = tester.widget(switchFinder);
      expect(switchWidget.value, isTrue);
    });

    testWidgets('Universal Payment Screen: Renders Static QRIS when is_dynamic_qris_enabled is false', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: false, hasPayload: true);

      final context = PaymentContext.booking(
        customerName: 'John Doe',
        deviceName: 'iPhone 15 Pro',
        totalAmount: 50000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
          ],
          child: MaterialApp(
            home: PaymentPage(paymentContext: context),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on QRIS bottom method card
      final qrisCardFinder = find.text('QRIS');
      expect(qrisCardFinder, findsWidgets);
      await tester.tap(qrisCardFinder.first);
      await tester.pumpAndSettle();

      // Static modal title and subtitle must be shown
      expect(find.text('QRIS STATIS'), findsOneWidget);
      expect(
        find.text('Pastikan jumlah yang Anda ketik sesuai\ndengan total pada struk/layar kasir.'),
        findsOneWidget,
      );

      // Amount displayed correctly
      expect(find.byKey(const Key('qris_modal_amount_text')), findsOneWidget);
      expect(find.text('Rp 50.000'), findsOneWidget);

      // Dynamic QR widget must NOT be present
      expect(find.byKey(const Key('dynamic_qris_qr_image')), findsNothing);
    });

    testWidgets('Universal Payment Screen: Live Binding for New Booking (Rp 150.000) generates Dynamic QRIS', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: true, hasPayload: true);

      // New Booking: Rp 150.000
      final context = PaymentContext.booking(
        customerName: 'Sarah Connor',
        deviceName: 'PlayStation 5',
        totalAmount: 150000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
          ],
          child: MaterialApp(
            home: PaymentPage(paymentContext: context),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('QRIS').first);
      await tester.pumpAndSettle();

      // Dynamic modal title and caption must be shown
      expect(find.text('QRIS DINAMIS'), findsOneWidget);
      expect(
        find.text('Pindai untuk membayar. Nominal otomatis terisi dan terkunci di aplikasi pelanggan.'),
        findsOneWidget,
      );

      // Formatted amount beneath QR code
      expect(find.text('Rp 150.000'), findsOneWidget);

      // Native QR widget rendered
      expect(find.byKey(const Key('dynamic_qris_qr_image')), findsOneWidget);
      expect(find.byType(QrImageView), findsOneWidget);

      // Verify dynamic payload transformation with QrisService
      final dynamicPayload = QrisService.generateDynamicQris(kSampleStaticPayload, 150000);
      expect(dynamicPayload.contains('010212'), isTrue);
      expect(dynamicPayload.contains('5406150000'), isTrue);
    });

    testWidgets('Universal Payment Screen: Live Binding for Late Penalty Settlement (Rp 75.000)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: true, hasPayload: true);

      // Late Penalty Settlement: Rp 75.000
      final context = PaymentContext.penalty(
        customerName: 'Ahmad Late',
        deviceModel: 'Sony A7IV',
        penaltyDue: 75000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
          ],
          child: MaterialApp(
            home: PaymentPage(paymentContext: context),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('QRIS').first);
      await tester.pumpAndSettle();

      expect(find.text('QRIS DINAMIS'), findsOneWidget);
      expect(find.text('Rp 75.000'), findsOneWidget);

      expect(find.byKey(const Key('dynamic_qris_qr_image')), findsOneWidget);

      final dynamicPayload = QrisService.generateDynamicQris(kSampleStaticPayload, 75000);
      expect(dynamicPayload.contains('540575000'), isTrue);
    });

    testWidgets('Universal Payment Screen: Live Binding for Duration Extension (Rp 35.000)', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final repo = _FakeCashierRepoForDynamicQris(isDynamicQris: true, hasPayload: true);

      // Duration Extension: Rp 35.000
      final context = PaymentContext.extension(
        customerName: 'Budi Extension',
        deviceModel: 'DJI RS3 Pro',
        additionalHours: 4,
        extensionFee: 35000,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _TestAuthNotifier(authStateOwner)),
            businessProvider.overrideWith(() => _TestBusinessNotifier(businessStateOwner)),
            cashierRepositoryProvider.overrideWithValue(repo),
            bookingRepositoryProvider.overrideWithValue(_FakeBookingRepo()),
          ],
          child: MaterialApp(
            home: PaymentPage(paymentContext: context),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('QRIS').first);
      await tester.pumpAndSettle();

      expect(find.text('QRIS DINAMIS'), findsOneWidget);
      expect(find.text('Rp 35.000'), findsOneWidget);

      expect(find.byKey(const Key('dynamic_qris_qr_image')), findsOneWidget);

      final dynamicPayload = QrisService.generateDynamicQris(kSampleStaticPayload, 35000);
      expect(dynamicPayload.contains('540535000'), isTrue);
    });
  });
}

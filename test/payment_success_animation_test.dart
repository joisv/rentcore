import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/widgets/animated_success_checkmark.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/payments/models/payment_context.dart';
import 'package:rentcore_mobile/features/payments/presentation/payment_page.dart';

class _FakeCashierRepoForAnimationTest extends CashierRepository {
  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    return {
      'has_active_shift': true,
      'shift': {
        'id': 1,
        'status': 'open',
        'opening_cash_float': 50000.0,
      },
    };
  }
}

void main() {
  const testContext = PaymentContext(
    transactionType: PaymentTransactionType.booking,
    customerName: 'Raka Pratama',
    customerPhone: '081234567890',
    deviceName: 'Sony A7 IV',
    bookingCode: 'RC-ANIM-001',
    totalAmountDue: 200000.0,
    remainingDue: 200000.0,
    previouslyPaidAmount: 0.0,
    branchId: 1,
    branchName: 'Cabang Utama',
  );

  final qrisResult = PaymentResult(
    status: PaymentStatus.completed,
    transactionCode: 'TRX-ANIM-001',
    receiptNumber: 'RCP-ANIM-001',
    amountPaid: 200000.0,
    cashReceived: 200000.0,
    cashChange: 0.0,
    paymentMethodCode: 'QRIS',
    paymentMethodName: 'QRIS Dinamis / Statis',
  );

  Widget buildPaymentSuccessWidget() {
    return ProviderScope(
      overrides: [
        cashierRepositoryProvider.overrideWithValue(
          _FakeCashierRepoForAnimationTest(),
        ),
        paymentMethodsProvider.overrideWith(
          (ref) => Future.value([
            {
              'id': 2,
              'code': 'QRIS',
              'name': 'QRIS Dinamis / Statis',
              'is_active': true,
            },
          ]),
        ),
        paymentSettingsProvider(1).overrideWith(
          (ref) => Future.value({
            'config': {'qris_statis_enabled': true},
          }),
        ),
      ],
      child: MaterialApp(
        home: PaymentPage(
          paymentContext: testContext,
          initialResult: qrisResult,
        ),
      ),
    );
  }

  group('Payment Success Native Animation Tests', () {
    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets(
      'AnimatedSuccessCheckmark triggers mediumImpact haptic on mount and maintains fixed 88x88 size across animation frames',
      (tester) async {
        final hapticCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call);
          }
          return null;
        });

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: Center(
                child: AnimatedSuccessCheckmark(size: 88),
              ),
            ),
          ),
        );

        expect(hapticCalls.length, 1);
        expect(hapticCalls.first.arguments, 'HapticFeedbackType.mediumImpact');

        final badgeFinder = find.byType(AnimatedSuccessCheckmark);
        expect(badgeFinder, findsOneWidget);
        expect(tester.getSize(badgeFinder), const Size(88, 88));

        // Verify CustomPaint is mounted inside the badge
        expect(
          find.descendant(
            of: badgeFinder,
            matching: find.byType(CustomPaint),
          ),
          findsOneWidget,
        );

        // Advance through key keyframes (200ms, 350ms, 520ms, 700ms) with zero layout shift
        await tester.pump(const Duration(milliseconds: 200));
        expect(tester.getSize(badgeFinder), const Size(88, 88));

        await tester.pump(const Duration(milliseconds: 150)); // 350ms
        expect(tester.getSize(badgeFinder), const Size(88, 88));

        await tester.pump(const Duration(milliseconds: 170)); // 520ms
        expect(tester.getSize(badgeFinder), const Size(88, 88));

        await tester.pump(const Duration(milliseconds: 180)); // 700ms
        expect(tester.getSize(badgeFinder), const Size(88, 88));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'PaymentPage renders AnimatedSuccessCheckmark(size: 88) and staggers header, receipt card, and action buttons smoothly without overflow',
      (tester) async {
        final hapticCalls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCalls.add(call);
          }
          return null;
        });

        await tester.pumpWidget(buildPaymentSuccessWidget());
        await tester.pump();

        expect(hapticCalls.length, 1);
        expect(hapticCalls.first.arguments, 'HapticFeedbackType.mediumImpact');

        final badgeFinder = find.byKey(const Key('payment_success_squircle_badge'));
        expect(badgeFinder, findsOneWidget);
        expect(tester.getSize(badgeFinder), const Size(64, 64));
        final badgeDecoration =
            tester.widget<Container>(badgeFinder).decoration as BoxDecoration;
        expect(badgeDecoration.color, const Color(0xFFECFDF5));
        expect(badgeDecoration.borderRadius, BorderRadius.circular(20));

        FadeTransition fadeOfText(String text) => tester.widget<FadeTransition>(
              find.ancestor(
                of: find.text(text),
                matching: find.byType(FadeTransition),
              ).first,
            );

        SlideTransition slideOfText(String text) => tester.widget<SlideTransition>(
              find.ancestor(
                of: find.text(text),
                matching: find.byType(SlideTransition),
              ).first,
            );

        // At t = 0ms, all 3 staggered sections start hidden & offset by (0, 0.06)
        expect(fadeOfText('Pembayaran Berhasil Dicatat!').opacity.value, 0.0);
        expect(slideOfText('Pembayaran Berhasil Dicatat!').position.value, const Offset(0, 0.06));
        expect(fadeOfText('No. Struk').opacity.value, 0.0);
        expect(fadeOfText('Cetak Struk Transaksi').opacity.value, 0.0);

        // At t = 400ms, header is already fading in ahead of card & action buttons
        await tester.pump(const Duration(milliseconds: 400));
        final headerOpacity400 = fadeOfText('Pembayaran Berhasil Dicatat!').opacity.value;
        final cardOpacity400 = fadeOfText('No. Struk').opacity.value;
        final actionsOpacity400 = fadeOfText('Cetak Struk Transaksi').opacity.value;
        expect(headerOpacity400, greaterThan(cardOpacity400));
        expect(cardOpacity400, greaterThanOrEqualTo(actionsOpacity400));

        // At t = 700ms, all staggered transitions reach full opacity & Offset.zero
        await tester.pump(const Duration(milliseconds: 300));
        expect(fadeOfText('Pembayaran Berhasil Dicatat!').opacity.value, 1.0);
        expect(slideOfText('Pembayaran Berhasil Dicatat!').position.value, Offset.zero);
        expect(fadeOfText('No. Struk').opacity.value, 1.0);
        expect(slideOfText('No. Struk').position.value, Offset.zero);
        expect(fadeOfText('Cetak Struk Transaksi').opacity.value, 1.0);
        expect(slideOfText('Cetak Struk Transaksi').position.value, Offset.zero);

        expect(find.text('LUNAS OTOMATIS'), findsOneWidget);
        expect(tester.getSize(badgeFinder), const Size(64, 64));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Disposes AnimationControllers cleanly both mid-animation and after completion',
      (tester) async {
        // Dispose mid-animation (at 150ms)
        await tester.pumpWidget(buildPaymentSuccessWidget());
        await tester.pump(const Duration(milliseconds: 150));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        expect(tester.takeException(), isNull);

        // Dispose after completion (at 800ms)
        await tester.pumpWidget(buildPaymentSuccessWidget());
        await tester.pump(const Duration(milliseconds: 800));
        await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
        expect(tester.takeException(), isNull);
      },
    );
  });
}

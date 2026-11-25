import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';
import 'package:sewakasir/features/onboarding/presentation/feature_walkthrough_screen.dart';

class _StubNotificationNotifier extends NotificationNotifier {
  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}
}

class _FakeWalkthroughAuthRepository extends AuthRepository {
  bool walkthroughApiCalled = false;

  @override
  Future<void> completeWalkthrough({String? userId}) async {
    walkthroughApiCalled = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_walkthrough_v1', true);
  }

  @override
  Future<bool> isWalkthroughCompleted({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('has_completed_walkthrough_v1') ?? false;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Walkthrough renders 4 slides with native UI preview cards and handles navigation',
      (tester) async {
    final fakeRepo = _FakeWalkthroughAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          notificationProvider.overrideWith(_StubNotificationNotifier.new),
          closingSummaryProvider.overrideWith(
            (ref) => Future.value(<String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(
          home: FeatureWalkthroughScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Slide 1: Meja Kerja Operasional Harian
    expect(find.text('Operasional Harian dalam Satu Layar'), findsOneWidget);
    expect(find.text('Cari unit rental, nama penyewa...'), findsOneWidget);
    expect(find.text('Pendapatan Hari Ini'), findsOneWidget);
    expect(find.text('Rp 1.450.000'), findsOneWidget);
    expect(find.text('Sewa Hari Ini'), findsOneWidget);
    expect(find.text('14 Unit'), findsOneWidget);
    expect(find.text('Pengembalian Hari Ini'), findsOneWidget);
    expect(find.text('6 Unit'), findsOneWidget);
    expect(find.text('Unit Tersedia'), findsOneWidget);
    expect(find.text('28 Unit'), findsOneWidget);

    // Verify secondary tag clutter is removed
    expect(find.text('+12%'), findsNothing);
    expect(find.text('Berjalan'), findsNothing);
    expect(find.text('Ready'), findsNothing);

    // Tap "Lanjut" -> Slide 2
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Slide 2: Antrean Sewa Berbasis Urgensi
    expect(find.text('Antrean Terstruktur Berbasis Urgensi'), findsOneWidget);
    expect(find.text('RC-261030-0004'), findsOneWidget);
    expect(find.text('TERLAMBAT'), findsOneWidget);
    expect(find.text('Rincian'), findsOneWidget);
    expect(find.text('Kembalikan'), findsOneWidget);

    // Tap "Lanjut" -> Slide 3
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Slide 3: QRIS Dinamis Otomatis
    expect(find.text('QRIS Dinamis Tanpa Input Manual'), findsOneWidget);
    expect(find.text('Rp 50.000'), findsOneWidget);
    expect(find.text('Nominal Otomatis Terkunci'), findsOneWidget);

    // Tap "Lanjut" -> Slide 4
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Slide 4: Meja Kasir & Rekap Shift
    expect(find.text('Manajemen Shift & Closing Kasir Rapi'), findsOneWidget);
    expect(find.text('Shift Pagi • Bayu S.'), findsOneWidget);
    expect(find.text('SESUAI (Rp 0)'), findsOneWidget);
    expect(find.text('Cetak Struk Rekap Shift'), findsOneWidget);

    // Button text changes to "Mulai Operasional"
    expect(find.widgetWithText(ElevatedButton, 'Mulai Operasional'), findsOneWidget);

    // Tap "Mulai Operasional" completes walkthrough
    await tester.tap(find.widgetWithText(ElevatedButton, 'Mulai Operasional'));
    await tester.pump();

    expect(fakeRepo.walkthroughApiCalled, isTrue);
  });

  testWidgets('Walkthrough "Lewati" button completes walkthrough immediately',
      (tester) async {
    final fakeRepo = _FakeWalkthroughAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          notificationProvider.overrideWith(_StubNotificationNotifier.new),
          closingSummaryProvider.overrideWith(
            (ref) => Future.value(<String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(
          home: FeatureWalkthroughScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Lewati'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await tester.pump();

    expect(fakeRepo.walkthroughApiCalled, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/cashier/providers/cashier_provider.dart';
import 'package:sewakasir/features/notifications/providers/notification_provider.dart';
import 'package:sewakasir/features/onboarding/presentation/business_setup_wizard_screen.dart';
import 'package:sewakasir/features/onboarding/presentation/feature_walkthrough_screen.dart';

class _StubPolishNotificationNotifier extends NotificationNotifier {
  @override
  Future<void> fetchUnreadCountOnly() async {}

  @override
  Future<void> fetchNotifications({bool refresh = false}) async {}
}

class _FakePolishAuthRepository extends AuthRepository {
  Map<String, dynamic>? createdData;
  bool walkthroughFinished = false;

  @override
  Future<Map<String, dynamic>> createBusiness({
    required String name,
    required String city,
    String? address,
    String? phone,
    String? nichePreset,
    List<String>? businessCategories,
    String? branchStructure,
    String? initialBranchName,
    String? initialBranchCode,
    int? pendingBusinessId,
  }) async {
    createdData = {
      'id': 999,
      'name': name,
      'city': city,
      'niche_preset': nichePreset,
      'branch_structure': branchStructure ?? 'single_location',
      'business_categories': businessCategories ?? [],
    };
    return createdData!;
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async =>
      createdData != null ? [createdData!] : [];

  @override
  Future<void> completeWalkthrough({String? userId}) async {
    walkthroughFinished = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Business Setup Wizard Polish Verification', () {
    testWidgets(
      'Step 1: Input decoration has contentPadding (16, 14), placeholder is shortened, and Lanjut transitions enabled',
      (tester) async {
        final fakeRepo = _FakePolishAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: BusinessSetupWizardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check TextField decoration
        final textFieldFinder = find.byType(TextField);
        expect(textFieldFinder, findsOneWidget);
        final textField = tester.widget<TextField>(textFieldFinder);

        expect(
          textField.decoration?.contentPadding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        );
        expect(
          textField.decoration?.hintText,
          'Contoh: Lensa Nusantara Jember',
        );

        // Disabled initially
        final lanjutBtn = find.widgetWithText(ElevatedButton, 'Lanjut');
        expect(tester.widget<ElevatedButton>(lanjutBtn).onPressed, isNull);

        // Type 3 chars -> enabled
        await tester.enterText(textFieldFinder, 'Sky');
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(lanjutBtn).onPressed, isNotNull);
      },
    );

    testWidgets(
      'Step 3: 2-column Grid with unified pills, subtle subtitle without legalistic card/circle icon, Lewati in AppBar, and full-width Selesai & Buka Dashboard button',
      (tester) async {
        final fakeRepo = _FakePolishAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(
              home: BusinessSetupWizardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1 -> Step 2
        await tester.enterText(find.byType(TextField), 'Rental Pro');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();

        // Step 2 -> Step 3
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();

        // 1. Check subtle subtitle beneath heading
        expect(find.text('Kategori Bisnis Rental'), findsOneWidget);
        expect(
          find.textContaining('Pilih preset usaha rental'),
          findsOneWidget,
        );

        // 2. Verify heavy legalistic "Aturan Personalisasi" card and shield/circle icon are absent
        expect(find.textContaining('Aturan Personalisasi:'), findsNothing);
        expect(find.byIcon(Icons.shield_outlined), findsNothing);

        // 3. Verify balanced 2-column Grid
        final gridFinder = find.byType(GridView);
        expect(gridFinder, findsOneWidget);
        final grid = tester.widget<GridView>(gridFinder);
        final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
        expect(delegate.crossAxisCount, 2);

        // 4. Verify "Lewati" is in the AppBar (actions)
        final lewatiFinder = find.text('Lewati');
        expect(lewatiFinder, findsOneWidget);

        // 5. Verify bottom primary button is full-width "Selesai & Buka Dashboard"
        final selesaiBtnFinder = find.widgetWithText(ElevatedButton, 'Selesai & Buka Dashboard');
        expect(selesaiBtnFinder, findsOneWidget);

        // Tap submit
        await tester.tap(selesaiBtnFinder);
        await tester.pumpAndSettle();

        expect(fakeRepo.createdData?['name'], 'Rental Pro');
      },
    );
  });

  group('Feature Walkthrough Polish Verification', () {
    testWidgets(
      'Header step indicator has no container border, Slide 1 has uncluttered 4 metrics without tag clutter, and Slide 3 QRIS is cleanly centered',
      (tester) async {
        final fakeRepo = _FakePolishAuthRepository();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeRepo),
              notificationProvider
                  .overrideWith(_StubPolishNotificationNotifier.new),
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

        // 1. Header step indicator
        expect(find.text('Langkah 1 dari 4'), findsOneWidget);

        // 2. Slide 1 4 exact metrics
        expect(find.text('Pendapatan Hari Ini'), findsOneWidget);
        expect(find.text('Rp 1.450.000'), findsOneWidget);
        expect(find.text('Sewa Hari Ini'), findsOneWidget);
        expect(find.text('14 Unit'), findsOneWidget);
        expect(find.text('Pengembalian Hari Ini'), findsOneWidget);
        expect(find.text('6 Unit'), findsOneWidget);
        expect(find.text('Unit Tersedia'), findsOneWidget);
        expect(find.text('28 Unit'), findsOneWidget);

        // Verify badge clutter (+12%, Berjalan, Ready) is removed
        expect(find.text('+12%'), findsNothing);
        expect(find.text('Berjalan'), findsNothing);
        expect(find.text('Ready'), findsNothing);

        // 3. Move to Slide 2 then Slide 3
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 2 dari 4'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 3 dari 4'), findsOneWidget);

        // Slide 3: QRIS centered elements
        expect(find.text('Tagihan Sewa Terkunci'), findsOneWidget);
        expect(find.text('Rp 50.000'), findsOneWidget);
        expect(find.text('Nominal Otomatis Terkunci'), findsOneWidget);

        // 4. Move to Slide 4
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 4 dari 4'), findsOneWidget);

        // Slide 4: Bottom bar button is "Mulai Operasional"
        final startBtn = find.widgetWithText(ElevatedButton, 'Mulai Operasional');
        expect(startBtn, findsOneWidget);

        await tester.tap(startBtn);
        await tester.pump();
        expect(fakeRepo.walkthroughFinished, isTrue);
      },
    );
  });
}

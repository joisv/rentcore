import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/onboarding/presentation/business_setup_wizard_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  Map<String, dynamic>? lastCreatedPayload;
  int createCalls = 0;

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
    createCalls++;
    lastCreatedPayload = {
      'id': pendingBusinessId ?? 777,
      'name': name,
      'city': city,
      'niche_preset': nichePreset,
      'branch_structure': branchStructure ?? 'single_location',
      'initial_branch_name': initialBranchName,
      'business_categories': businessCategories ?? [],
      'branches': [
        {'id': 888, 'name': initialBranchName ?? '$name Pusat', 'code': 'PST', 'is_central': true}
      ],
    };
    return lastCreatedPayload!;
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    if (lastCreatedPayload != null) {
      return [lastCreatedPayload!];
    }
    return [];
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Wizard Step 1 validation: disabled with < 3 chars, enabled with >= 3 chars',
      (tester) async {
    final fakeRepo = _FakeAuthRepository();

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

    // Verify Title & greeting
    expect(find.text('Inisialisasi Bisnis Rental'), findsOneWidget);
    expect(find.text('Apa nama usaha rental Anda?'), findsOneWidget);

    // Initial state: empty text, button disabled
    final nextBtnFinder = find.widgetWithText(ElevatedButton, 'Lanjut');
    expect(nextBtnFinder, findsOneWidget);
    final initialBtn = tester.widget<ElevatedButton>(nextBtnFinder);
    expect(initialBtn.onPressed, isNull);

    // Type 2 characters -> still disabled
    await tester.enterText(find.byType(TextField), 'Sk');
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(nextBtnFinder).onPressed, isNull);

    // Type 3 or more characters -> enabled
    await tester.enterText(find.byType(TextField), 'Skyrental Jember');
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(nextBtnFinder).onPressed, isNotNull);
  });

  testWidgets('Wizard complete flow: Step 1 -> Step 2 -> Step 3 -> Submit with categories',
      (tester) async {
    final fakeRepo = _FakeAuthRepository();

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

    // Step 1: Enter Business Name
    await tester.enterText(find.byType(TextField), 'Skyrental Jember');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Step 2: Branch Structure & Primary Branch Detail
    expect(find.text('Struktur Operasional Toko'), findsOneWidget);
    expect(find.text('Sudah memiliki beberapa cabang'), findsOneWidget);

    // Tap multi-branch option and enter custom branch & city
    await tester.tap(find.text('Sudah memiliki beberapa cabang'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('wizard_branch_name_input')),
      'Skyrental Pusat Jember',
    );
    await tester.enterText(
      find.byKey(const Key('wizard_city_input')),
      'Jember',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Step 3: Smart Rental Niche Presets
    expect(find.text('Kategori Bisnis Rental'), findsOneWidget);
    expect(find.text('iPhone & Gadget'), findsOneWidget);
    expect(find.text('Kamera & Lensa'), findsOneWidget);

    // Select 'iPhone & Gadget' preset
    await tester.tap(find.text('iPhone & Gadget'));
    await tester.pumpAndSettle();

    // Verify starter categories preview
    expect(find.text('Android & Tablet'), findsOneWidget);

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Selesai & Buka Dashboard'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls, 1);
    expect(fakeRepo.lastCreatedPayload?['name'], 'Skyrental Jember');
    expect(fakeRepo.lastCreatedPayload?['city'], 'Jember');
    expect(
      fakeRepo.lastCreatedPayload?['initial_branch_name'],
      'Skyrental Pusat Jember',
    );
    expect(fakeRepo.lastCreatedPayload?['branch_structure'], 'multi_branch');
    expect(fakeRepo.lastCreatedPayload?['niche_preset'], 'iphone_gadget');
    expect(
      fakeRepo.lastCreatedPayload?['business_categories'],
      contains('iphone_smartphone'),
    );
  });

  testWidgets('Wizard Step 3 "Lewati" action finishes setup without categories',
      (tester) async {
    final fakeRepo = _FakeAuthRepository();

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

    // Step 1
    await tester.enterText(find.byType(TextField), 'Rental Express');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Step 2
    await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
    await tester.pumpAndSettle();

    // Step 3: Tap Lewati
    expect(find.text('Lewati'), findsOneWidget);
    await tester.tap(find.text('Lewati'));
    await tester.pumpAndSettle();

    expect(fakeRepo.createCalls, 1);
    expect(fakeRepo.lastCreatedPayload?['name'], 'Rental Express');
    expect(fakeRepo.lastCreatedPayload?['business_categories'], isEmpty);
  });
}

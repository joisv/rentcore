import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/constants/navigation_keys.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/onboarding/presentation/business_setup_wizard_screen.dart';
import 'package:sewakasir/features/onboarding/providers/onboarding_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  Widget buildTestApp({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        routes: {
          '/login': (_) => const Scaffold(body: Text('LOGIN_SCREEN')),
        },
        home: const BusinessSetupWizardScreen(),
      ),
    );
  }

  group('Cross-Account Onboarding Data Isolation Unit Tests', () {
    test('Scoped keys: User A draft does not leak into User B lookup', () async {
      final repo = AuthRepository();

      // 1. User A saves an onboarding draft
      await repo.saveWizardDraft(
        userId: 'user_101',
        step: 1,
        name: 'Kamera Bali User A',
        branchStructure: 'multi_branch',
        categories: ['camera', 'outdoor'],
        pendingBusinessId: 55,
      );

      final prefs = await SharedPreferences.getInstance();
      // Verify keys are properly namespaced by User A ID
      expect(prefs.getString('user_user_101_onboarding_business_name'), 'Kamera Bali User A');
      expect(prefs.getInt('user_user_101_onboarding_wizard_step'), 1);
      expect(prefs.getString('user_user_101_onboarding_branch_structure'), 'multi_branch');
      expect(prefs.getStringList('user_user_101_onboarding_categories'), ['camera', 'outdoor']);

      // 2. User B looks up wizard draft on the exact same device
      final userBDraft = await repo.loadWizardDraft(userId: 'user_202');

      // User B must receive completely pristine, empty default values
      expect(userBDraft['name'], '');
      expect(userBDraft['step'], 0);
      expect(userBDraft['branch_structure'], 'single_location');
      expect(userBDraft['categories'], isEmpty);
      expect(userBDraft['pending_biz_id'], isNull);

      // User A's draft is still preserved when User A loads it
      final userADraft = await repo.loadWizardDraft(userId: 'user_101');
      expect(userADraft['name'], 'Kamera Bali User A');
      expect(userADraft['step'], 1);
    });

    test('Logout purges all onboarding and wizard caches while preserving hardware configs', () async {
      final repo = AuthRepository();
      final prefs = await SharedPreferences.getInstance();

      // Seed User A draft keys and unscoped keys
      await repo.saveWizardDraft(
        userId: 'user_101',
        step: 2,
        name: 'Store A',
        categories: ['vehicle'],
      );
      await prefs.setString('wizard_draft_name', 'Legacy Store');
      await prefs.setString('rentcore_printer_settings_v1', '{"paperWidth":"mm58"}');
      await prefs.setString('api_base_url', 'http://127.0.0.1:8000/api/v1');

      // Execute logout
      await repo.logout();

      // All onboarding and wizard keys must be purged
      expect(prefs.getString('user_user_101_onboarding_business_name'), isNull);
      expect(prefs.getInt('user_user_101_onboarding_wizard_step'), isNull);
      expect(prefs.getString('wizard_draft_name'), isNull);

      // Hardware and network configurations must be preserved
      expect(prefs.getString('rentcore_printer_settings_v1'), '{"paperWidth":"mm58"}');
      expect(prefs.getString('api_base_url'), 'http://127.0.0.1:8000/api/v1');
    });
  });

  group('Cross-Account Onboarding Form UI Isolation Tests', () {
    testWidgets('Switching accounts presents a pristine blank form without User A data',
        (tester) async {
      final repo = AuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // 1. User A logs in
      container.read(authProvider.notifier).state = const AuthState(
        isAuthenticated: true,
        user: {'id': 101, 'name': 'User A'},
      );

      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pumpAndSettle();

      // User A enters store name and saves draft
      final nameField = find.byType(TextField);
      await tester.enterText(nameField, 'User A Gadget Hub');
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_101_onboarding_business_name'), 'User A Gadget Hub');

      // 2. User A logs out
      await container.read(authProvider.notifier).logout();
      await tester.pumpAndSettle();

      // Onboarding provider state is reset
      expect(container.read(onboardingProvider).wizardStep, 0);

      // 3. User B logs in on identical physical device
      container.read(authProvider.notifier).state = const AuthState(
        isAuthenticated: true,
        user: {'id': 202, 'name': 'User B'},
      );
      rootNavigatorKey.currentState?.pushReplacement(
        MaterialPageRoute(builder: (_) => const BusinessSetupWizardScreen()),
      );
      await tester.pumpAndSettle();

      // Verify User B's screen has a completely blank input and disabled submit button
      final userBNameField = tester.widget<TextField>(find.byType(TextField));
      expect(userBNameField.controller?.text, '');

      final lanjutBtn = find.widgetWithText(ElevatedButton, 'Lanjut');
      expect(tester.widget<ElevatedButton>(lanjutBtn).onPressed, isNull);

      // User B enters their own store name
      await tester.enterText(find.byType(TextField), 'User B Studio');
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(lanjutBtn).onPressed, isNotNull);
      expect(prefs.getString('user_202_onboarding_business_name'), 'User B Studio');
      // User A's data was purged on logout and not overwritten by User B
      expect(prefs.getString('user_101_onboarding_business_name'), isNull);
    });

    testWidgets('In-memory form controller resets dynamically when auth state changes',
        (tester) async {
      final repo = AuthRepository();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      // User A logged in
      container.read(authProvider.notifier).state = const AuthState(
        isAuthenticated: true,
        user: {'id': 101, 'name': 'User A'},
      );

      await tester.pumpWidget(buildTestApp(container: container));
      await tester.pumpAndSettle();

      // User A types in controller
      await tester.enterText(find.byType(TextField), 'Temporary Unsaved Store');
      await tester.pumpAndSettle();
      expect(find.text('Temporary Unsaved Store'), findsOneWidget);

      // Auth state changes to User B while screen is mounted
      container.read(authProvider.notifier).state = const AuthState(
        isAuthenticated: true,
        user: {'id': 202, 'name': 'User B'},
      );
      await tester.pumpAndSettle();

      // Input controller must be wiped clean immediately
      expect(find.text('Temporary Unsaved Store'), findsNothing);
      final textWidget = tester.widget<TextField>(find.byType(TextField));
      expect(textWidget.controller?.text, '');
    });
  });
}

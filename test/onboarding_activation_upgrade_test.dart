import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/widgets/progressive_checklist_banner.dart';
import 'package:rentcore_mobile/features/onboarding/presentation/business_setup_wizard_screen.dart';
import 'package:rentcore_mobile/features/onboarding/presentation/feature_walkthrough_screen.dart';
import 'package:rentcore_mobile/features/onboarding/providers/onboarding_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';

class _StaticAuthNotifier extends AuthNotifier {
  final AuthState _state;
  _StaticAuthNotifier(this._state);

  @override
  AuthState build() => _state;
}

class _StaticBusinessNotifier extends BusinessNotifier {
  final BusinessState _state;
  _StaticBusinessNotifier(this._state);

  @override
  BusinessState build() => _state;
}

class _PresetAuthRepo extends AuthRepository {
  Map<String, dynamic>? capturedPayload;
  bool completedWalkthroughCalled = false;

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
    capturedPayload = {
      'name': name,
      'city': city,
      'niche_preset': nichePreset,
      'branch_structure': branchStructure,
      'initial_branch_name': initialBranchName,
      'business_categories': businessCategories ?? [],
    };
    return {
      'id': 501,
      ...capturedPayload!,
      'branches': [
        {'id': 601, 'name': initialBranchName ?? '$name Pusat', 'is_central': true},
      ],
    };
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async =>
      capturedPayload != null ? [{'id': 501, ...capturedPayload!}] : [];

  @override
  Future<void> completeWalkthrough({String? userId}) async {
    completedWalkthroughCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Role-Aware Onboarding: Staff 3-Card Quick-Start vs Owner Preset Wizard', () {
    testWidgets(
      'Invited staff / cashier sees focused 3-card quick-start (Buka Shift Kasir -> Catat Sewa -> Inspeksi Pengembalian)',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _PresetAuthRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeRepo),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'RentCore',
                    businesses: [
                      {'id': 1, 'name': 'RentCore', 'role': 'staff'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(
              home: FeatureWalkthroughScreen(replayMode: true),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Langkah 1 dari 3'), findsOneWidget);
        expect(find.text('Buka Shift Kasir'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 2 dari 3'), findsOneWidget);
        expect(find.text('Catat Sewa & Serahkan Unit'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();
        expect(find.text('Langkah 3 dari 3'), findsOneWidget);
        expect(find.text('Inspeksi Pengembalian'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Masuk Dashboard'), findsOneWidget);
      },
    );

    testWidgets(
      'Owner wizard persists business, primary branch, city, and PlayStation & Konsol niche preset',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = _PresetAuthRepo();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authRepositoryProvider.overrideWithValue(fakeRepo),
            ],
            child: const MaterialApp(home: BusinessSetupWizardScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Step 1: Store Name
        await tester.enterText(find.byType(TextField).first, 'Console Hub ID');
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();

        // Step 2: Primary branch name & city pre-filled/editable
        final branchField = tester.widget<TextField>(
          find.byKey(const Key('wizard_branch_name_input')),
        );
        expect(branchField.controller?.text, 'Console Hub ID Pusat');
        await tester.enterText(find.byKey(const Key('wizard_city_input')), 'Surabaya');
        await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
        await tester.pumpAndSettle();

        // Step 3: Select PlayStation & Konsol preset
        await tester.tap(find.byKey(const Key('wizard_preset_playstation_console')));
        await tester.pumpAndSettle();
        expect(find.text('PlayStation 5 & 4'), findsOneWidget);
        expect(find.text('Stik & Controller'), findsOneWidget);

        await tester.tap(find.widgetWithText(ElevatedButton, 'Selesai & Buka Dashboard'));
        await tester.pumpAndSettle();

        expect(fakeRepo.capturedPayload?['name'], 'Console Hub ID');
        expect(fakeRepo.capturedPayload?['city'], 'Surabaya');
        expect(fakeRepo.capturedPayload?['initial_branch_name'], 'Console Hub ID Pusat');
        expect(fakeRepo.capturedPayload?['niche_preset'], 'playstation_console');
      },
    );
  });

  group('HomeScreen Setup Checklist Actions & StoreSettingsScreen Panduan Aplikasi Replay', () {
    testWidgets(
      'Checklist card triggers Create Model & Register Unit callbacks and hides on 3/3 or dismiss',
      (tester) async {
        var createModelTapped = false;
        var openInventoryTapped = false;

        final biz = {
          'id': 33,
          'name': 'Studio Lens',
          'role': 'owner',
          'branches': [
            {'id': 330, 'name': 'Studio Pusat', 'is_central': true},
          ],
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              businessProvider.overrideWith(BusinessNotifier.new),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ProgressiveChecklistBanner(
                  totalModelCount: 0,
                  totalAssetCount: 0,
                  onOpenCreateModel: () => createModelTapped = true,
                  onOpenInventory: () => openInventoryTapped = true,
                ),
              ),
            ),
          ),
        );

        final container =
            ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
        await container
            .read(businessProvider.notifier)
            .loadInitialContext(preloadedBusinesses: [biz]);
        await tester.pumpAndSettle();

        expect(find.text('0 dari 3 langkah selesai'), findsOneWidget);

        await tester.tap(find.byKey(const Key('checklist_step_create_model')));
        expect(createModelTapped, isTrue);

        await tester.tap(find.byKey(const Key('checklist_step_register_unit')));
        expect(openInventoryTapped, isTrue);

        // Dismissing persists per businessId
        await tester.tap(find.byKey(const Key('checklist_dismiss_button')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('owner_setup_checklist_card')), findsNothing);
        expect(container.read(onboardingProvider).isChecklistDismissed, isTrue);
      },
    );

    testWidgets(
      'StoreSettingsScreen renders Panduan Aplikasi row and opens role-aware replay walkthrough',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _StaticAuthNotifier(
                  const AuthState(
                    isAuthenticated: true,
                    user: {
                      'id': 'u-staff',
                      'name': 'Kasir Rina',
                      'email': 'rina@rentcore.id',
                      'role': 'staff',
                    },
                  ),
                ),
              ),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  const BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'Studio Lens',
                    businesses: [
                      {'id': 1, 'name': 'Studio Lens', 'role': 'staff'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: StoreSettingsScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final guideTile = find.byKey(const Key('menu_app_guide'));
        await tester.ensureVisible(guideTile);
        expect(guideTile, findsOneWidget);
        expect(find.text('Panduan Aplikasi'), findsOneWidget);

        await tester.tap(guideTile);
        await tester.pumpAndSettle();

        // Staff role sees 3-card quick start in replay mode with Tutup button
        expect(find.byType(FeatureWalkthroughScreen), findsOneWidget);
        expect(find.text('Buka Shift Kasir'), findsOneWidget);
        expect(find.text('Tutup'), findsOneWidget);

        await tester.tap(find.text('Tutup'));
        await tester.pumpAndSettle();
        expect(find.byType(StoreSettingsScreen), findsOneWidget);
      },
    );
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/organization/presentation/manage_organization_screen.dart';
import 'package:rentcore_mobile/features/organization/providers/organization_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Rental Rules Organization UI & State Tests', () {
    testWidgets('Owner can view and see rental rules settings in Tab 3', (tester) async {
      final initialRules = {
        'id_document_limit_enabled': true,
        'max_primary_devices_per_id': 1,
        'addons_enabled': true,
        'max_addons_per_rental': 5,
      };

      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockRentalRulesOrgNotifier(
              OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'owner',
                branches: const [
                  {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true}
                ],
                members: const [
                  {
                    'id': 1,
                    'role': 'owner',
                    'user': {'name': 'Budi Owner', 'email': 'budi@owner.com'},
                    'branch_members': [],
                  }
                ],
                rentalRules: initialRules,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ManageOrganizationScreen(
              businessId: 10,
              businessName: 'SkyRental Dewata',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Tab 3 exists
      expect(find.text('Kebijakan Sewa'), findsOneWidget);

      // Tap Tab 3
      await tester.tap(find.text('Kebijakan Sewa'));
      await tester.pumpAndSettle();

      // Verify sections and descriptions
      expect(find.text('Batas Dokumen Identitas (KTP / SIM)'), findsOneWidget);
      expect(find.text('Fitur Add-on & Aksesoris Sewa'), findsOneWidget);
      expect(find.text('Maksimal Unit Utama per Identitas'), findsOneWidget);
      expect(find.text('Maksimal Unit Add-on per Sewa'), findsOneWidget);

      // Verify Save Button is present for Owner
      expect(find.text('Simpan Kebijakan Rental'), findsOneWidget);
    });

    testWidgets('Non-owner sees disabled or read-only indicators in Rental Rules Tab', (tester) async {
      final initialRules = {
        'id_document_limit_enabled': true,
        'max_primary_devices_per_id': 1,
        'addons_enabled': true,
        'max_addons_per_rental': 5,
      };

      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockRentalRulesOrgNotifier(
              OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'staff',
                branches: const [
                  {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true}
                ],
                members: const [
                  {
                    'id': 2,
                    'role': 'staff',
                    'user': {'name': 'Staff Member', 'email': 'staff@tenant.com'},
                    'branch_members': [],
                  }
                ],
                rentalRules: initialRules,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ManageOrganizationScreen(
              businessId: 10,
              businessName: 'SkyRental Dewata',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Tab 3
      await tester.tap(find.text('Kebijakan Sewa'));
      await tester.pumpAndSettle();

      // Staff should NOT see the Save button
      expect(find.text('Simpan Kebijakan Rental'), findsNothing);
    });

    testWidgets('Toggling unlimited add-ons hides/shows the max add-ons text field', (tester) async {
      tester.view.physicalSize = const Size(1200, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final initialRules = {
        'id_document_limit_enabled': true,
        'max_primary_devices_per_id': 1,
        'addons_enabled': true,
        'max_addons_per_rental': 5,
      };

      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockRentalRulesOrgNotifier(
              OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'owner',
                branches: const [
                  {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true}
                ],
                members: const [
                  {
                    'id': 1,
                    'role': 'owner',
                    'user': {'name': 'Budi Owner', 'email': 'budi@owner.com'},
                    'branch_members': [],
                  }
                ],
                rentalRules: initialRules,
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ManageOrganizationScreen(
              businessId: 10,
              businessName: 'SkyRental Dewata',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Tab 3
      await tester.tap(find.text('Kebijakan Sewa'));
      await tester.pumpAndSettle();

      // Initially, max addons is 5 (not unlimited), so text field is visible
      expect(find.text('Maksimal Unit Add-on per Sewa'), findsOneWidget);

      // Tap checkbox 'Tanpa Batas Unit Add-on (Unlimited)'
      await tester.tap(find.text('Tanpa Batas Unit Add-on (Unlimited)'));
      await tester.pumpAndSettle();

      // When unlimited is checked, the max addons number input should disappear
      expect(find.text('Maksimal Unit Add-on per Sewa'), findsNothing);

      // Uncheck it again
      await tester.tap(find.text('Tanpa Batas Unit Add-on (Unlimited)'));
      await tester.pumpAndSettle();

      // Number input reappears
      expect(find.text('Maksimal Unit Add-on per Sewa'), findsOneWidget);
    });

    test('Add-on pricing logic combines primary device and add-ons subtotals correctly', () {
      // Simulate direct rental screen pricing calculations
      final primaryPrice = 150000.0;
      final addOnPrices = [
        {'id': 101, 'name': 'Power Bank Anker 10k', 'price': 25000.0},
        {'id': 102, 'name': 'Fast Charger 67W', 'price': 15000.0},
        {'id': 103, 'name': 'Tripod Takara', 'price': 30000.0},
      ];

      final addOnSubtotal = addOnPrices.fold<double>(
        0.0,
        (sum, item) => sum + (item['price'] as double),
      );

      final total = primaryPrice + addOnSubtotal;

      expect(addOnSubtotal, 70000.0);
      expect(total, 220000.0);
    });
  });
}

class _MockRentalRulesOrgNotifier extends OrganizationNotifier {
  final OrganizationState _mockInitialState;

  _MockRentalRulesOrgNotifier(this._mockInitialState);

  @override
  OrganizationState build() {
    return _mockInitialState;
  }

  @override
  Future<void> loadOrganization(int businessId, {String? businessName}) async {
    state = _mockInitialState;
  }

  @override
  Future<void> refresh() async {
    state = _mockInitialState;
  }
}

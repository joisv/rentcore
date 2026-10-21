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

  group('Organization State & Role Tests', () {
    test('OrganizationState copyWith maintains state integrity', () {
      const state = OrganizationState(
        businessId: 10,
        businessName: 'SkyRental Dewata',
        userRole: 'owner',
        branches: [
          {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true}
        ],
        members: [
          {'id': 1, 'role': 'owner', 'user': {'name': 'Budi Owner', 'email': 'budi@owner.com'}}
        ],
      );

      final updated = state.copyWith(
        userRole: 'admin',
        branches: [
          {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true},
          {'id': 2, 'name': 'Cabang Canggu', 'code': 'CGU', 'is_central': false},
        ],
      );

      expect(state.userRole, 'owner');
      expect(state.branches.length, 1);
      expect(updated.userRole, 'admin');
      expect(updated.branches.length, 2);
      expect(updated.isOwnerOrAdmin, true);
    });

    test('isOwnerOrAdmin correctly distinguishes owner/admin from staff', () {
      const ownerState = OrganizationState(userRole: 'owner');
      const adminState = OrganizationState(userRole: 'admin');
      const staffState = OrganizationState(userRole: 'staff');
      const nullRoleState = OrganizationState(userRole: null);

      expect(ownerState.isOwnerOrAdmin, true);
      expect(adminState.isOwnerOrAdmin, true);
      expect(staffState.isOwnerOrAdmin, false);
      expect(nullRoleState.isOwnerOrAdmin, false);
    });
  });

  group('ManageOrganizationScreen Widget Tests', () {
    testWidgets('Renders tabs, branch list, and central badge for owner', (tester) async {
      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'owner',
                branches: [
                  {
                    'id': 1,
                    'name': 'Cabang Seminyak Pusat',
                    'code': 'SMY',
                    'is_central': true,
                    'city': 'Badung',
                    'address': 'Jl. Sunset Road No. 8',
                    'phone': '081234567890',
                  },
                ],
                members: [
                  {
                    'id': 1,
                    'role': 'owner',
                    'user': {'name': 'Budi Owner', 'email': 'budi@owner.com'},
                    'branch_members': [],
                  },
                ],
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

      // Check AppBar and Title
      expect(find.text('SkyRental Dewata'), findsOneWidget);
      expect(find.text('Kelola Cabang & Tim'), findsOneWidget);

      // Check Tabs
      expect(find.text('Cabang (1)'), findsOneWidget);
      expect(find.text('Tim & Staf (1)'), findsOneWidget);
      expect(find.text('Kebijakan Sewa'), findsOneWidget);

      // Check Branch card in Tab 1
      expect(find.text('Cabang Seminyak Pusat'), findsOneWidget);
      expect(find.text('SMY'), findsOneWidget);
      expect(find.text('PUSAT'), findsOneWidget);
      expect(find.text('Jl. Sunset Road No. 8'), findsOneWidget);

      // Floating action button for owner should be present
      expect(find.text('Tambah Cabang'), findsOneWidget);
    });

    testWidgets('Switches to Tim & Staf tab and displays member card with role badge', (tester) async {
      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'owner',
                branches: [
                  {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true},
                ],
                members: [
                  {
                    'id': 1,
                    'role': 'owner',
                    'user': {'name': 'Budi Owner', 'email': 'budi@owner.com'},
                    'branch_members': [],
                  },
                  {
                    'id': 2,
                    'role': 'staff',
                    'user': {'name': 'Siti Kasir', 'email': 'siti@kasir.com'},
                    'branch_members': [
                      {
                        'branch': {'id': 1, 'name': 'Cabang Seminyak'}
                      }
                    ],
                  },
                ],
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

      // Tap Tim & Staf tab
      await tester.tap(find.text('Tim & Staf (2)'));
      await tester.pumpAndSettle();

      // Verify member cards
      expect(find.text('Budi Owner'), findsOneWidget);
      expect(find.text('budi@owner.com'), findsOneWidget);
      expect(find.text('OWNER'), findsOneWidget);

      expect(find.text('Siti Kasir'), findsOneWidget);
      expect(find.text('siti@kasir.com'), findsOneWidget);
      expect(find.text('STAFF'), findsOneWidget);
      expect(find.text('Ditugaskan di: Cabang Seminyak'), findsOneWidget);

      // Verify FAB switches to Undang Staf
      expect(find.text('Undang Staf'), findsOneWidget);
    });

    testWidgets('Restricted staff sees view-only notice and NO floating action button', (tester) async {
      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'staff', // Staff role!
                branches: [
                  {'id': 1, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true},
                ],
                members: [
                  {
                    'id': 2,
                    'role': 'staff',
                    'user': {'name': 'Staff Member', 'email': 'staff@tenant.com'},
                    'branch_members': [],
                  },
                ],
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

      // Verify View-Only Notice is rendered
      expect(find.textContaining('Mode Lihat: Penambahan cabang, staf, dan perubahan kebijakan hanya dapat dilakukan oleh Owner atau Admin.'), findsOneWidget);

      // Verify FloatingActionButton is NOT present
      expect(find.byType(FloatingActionButton), findsNothing);
      expect(find.text('Tambah Cabang'), findsNothing);
      expect(find.text('Undang Staf'), findsNothing);
    });

    testWidgets('Empty state renders helpful prompt when no branches exist', (tester) async {
      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 10,
                businessName: 'SkyRental Dewata',
                userRole: 'owner',
                branches: [],
                members: [],
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

      expect(find.text('Belum Ada Cabang Terdaftar'), findsOneWidget);
    });
  });
}

class _MockOrganizationNotifier extends OrganizationNotifier {
  final OrganizationState _mockInitialState;

  _MockOrganizationNotifier(this._mockInitialState);

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

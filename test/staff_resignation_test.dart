import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/manage_organization_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/widgets/staff_resignation_sheet.dart';
import 'package:rentcore_mobile/features/organization/providers/organization_provider.dart';

class _MockOrganizationNotifier extends OrganizationNotifier {
  final OrganizationState _initialState;
  _MockOrganizationNotifier(this._initialState);

  @override
  OrganizationState build() => _initialState;

  @override
  Future<void> loadOrganization(int businessId, {String? businessName}) async {}

  @override
  Future<void> loadResignations() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Staff Resignation State & Helper Tests', () {
    test('OrganizationState handles resignation requests correctly', () {
      const state = OrganizationState(
        businessId: 1,
        userRole: 'owner',
        resignationRequests: [
          {'id': 101, 'user_id': 'user-1', 'status': 'pending', 'reason': 'Pindah kota'},
          {'id': 102, 'user_id': 'user-2', 'status': 'approved'},
          {'id': 103, 'user_id': 'user-3', 'status': 'rejected'},
        ],
      );

      expect(state.resignationRequests.length, 3);
      expect(state.pendingResignations.length, 1);
      expect(state.pendingResignations.first['id'], 101);
      expect(state.myActiveResignation, isNotNull);
      expect(state.myActiveResignation!['reason'], 'Pindah kota');

      final updated = state.copyWith(
        resignationRequests: [
          {'id': 101, 'user_id': 'user-1', 'status': 'approved'},
        ],
      );

      expect(updated.pendingResignations.isEmpty, true);
      expect(updated.myActiveResignation, isNull);
    });
  });

  group('ManageOrganizationScreen Resignation Review Tests', () {
    testWidgets('Owner sees pending resignation banner and badge on staff card', (tester) async {
      final container = ProviderContainer(
        overrides: [
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 1,
                businessName: 'Kamera Dewata Rental',
                userRole: 'owner',
                branches: [
                  {'id': 10, 'name': 'Cabang Seminyak', 'code': 'SMY', 'is_central': true},
                ],
                members: [
                  {
                    'id': 1,
                    'role': 'owner',
                    'user': {'id': 'owner-uuid', 'name': 'Owner Bos', 'email': 'owner@dewata.com'},
                    'branch_members': [],
                  },
                  {
                    'id': 2,
                    'role': 'staff',
                    'user': {'id': 'staff-uuid', 'name': 'Agus Pratama', 'email': 'agus@gmail.com'},
                    'branch_members': [
                      {
                        'affiliate_id': 10,
                        'branch': {'id': 10, 'name': 'Cabang Seminyak'},
                      }
                    ],
                  },
                ],
                resignationRequests: [
                  {
                    'id': 99,
                    'business_id': 1,
                    'business_member_id': 2,
                    'user_id': 'staff-uuid',
                    'status': 'pending',
                    'reason': 'Pindah domisili ke luar kota',
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
              businessId: 1,
              businessName: 'Kamera Dewata Rental',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Tim & Staf Tab
      final staffTab = find.textContaining('Tim & Staf');
      expect(staffTab, findsOneWidget);
      await tester.tap(staffTab);
      await tester.pumpAndSettle();

      // Verify pending resignation banner appears at top of tab
      expect(find.text('1 Permohonan Resign Menunggu Peninjauan'), findsOneWidget);
      expect(find.text('Tinjau'), findsOneWidget);

      // Verify staff card has 'Resign' badge
      expect(find.text('Agus Pratama'), findsOneWidget);
      expect(find.text('Resign'), findsOneWidget);
    });
  });

  group('StaffResignationSheet Widget Tests', () {
    testWidgets('Renders resignation sheet form with employer name and reason input', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _MockAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': 'staff-uuid', 'name': 'Agus Pratama', 'role': 'staff'},
              ),
            ),
          ),
          businessProvider.overrideWith(
            () => _MockBusinessNotifier(
              const BusinessState(
                activeBusinessId: 1,
                activeBusinessName: 'Kamera Dewata Rental',
                businesses: [
                  {
                    'id': 1,
                    'name': 'Kamera Dewata Rental',
                    'role': 'staff',
                    'branches': [
                      {'id': 10, 'name': 'Cabang Seminyak', 'is_central': true},
                    ],
                  }
                ],
              ),
            ),
          ),
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 1,
                businessName: 'Kamera Dewata Rental',
                userRole: 'staff',
                resignationRequests: [],
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: StaffResignationSheet(
                businessId: 1,
                businessName: 'Kamera Dewata Rental',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Status Kepegawaian'), findsOneWidget);
      expect(find.text('Kamera Dewata Rental'), findsOneWidget);
      expect(find.text('STAFF'), findsOneWidget);
      expect(find.text('Cabang Seminyak'), findsOneWidget);
      expect(find.text('Ajukan Pengunduran Diri'), findsOneWidget);
    });

    testWidgets('Renders pending status and cancel button when resignation is pending', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(
            () => _MockAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': 'staff-uuid', 'name': 'Agus Pratama', 'role': 'staff'},
              ),
            ),
          ),
          businessProvider.overrideWith(
            () => _MockBusinessNotifier(
              const BusinessState(
                activeBusinessId: 1,
                activeBusinessName: 'Kamera Dewata Rental',
                businesses: [
                  {
                    'id': 1,
                    'name': 'Kamera Dewata Rental',
                    'role': 'staff',
                    'branches': [],
                  }
                ],
              ),
            ),
          ),
          organizationProvider.overrideWith(
            () => _MockOrganizationNotifier(
              const OrganizationState(
                businessId: 1,
                businessName: 'Kamera Dewata Rental',
                userRole: 'staff',
                resignationRequests: [
                  {
                    'id': 88,
                    'user_id': 'staff-uuid',
                    'status': 'pending',
                    'reason': 'Pindah ke Surabaya',
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
            home: Scaffold(
              body: StaffResignationSheet(
                businessId: 1,
                businessName: 'Kamera Dewata Rental',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Menunggu Persetujuan Owner'), findsOneWidget);
      expect(find.textContaining('Pindah ke Surabaya'), findsOneWidget);
      expect(find.text('Batalkan Pengajuan Resign'), findsOneWidget);
    });
  });
}

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _mockState;
  _MockAuthNotifier(this._mockState);

  @override
  AuthState build() => _mockState;
}

class _MockBusinessNotifier extends BusinessNotifier {
  final BusinessState _mockState;
  _MockBusinessNotifier(this._mockState);

  @override
  BusinessState build() => _mockState;
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';

void main() {
  group('BusinessState Model & Computed Properties', () {
    final mockBusiness = {
      'id': 100,
      'name': 'RentCore Enterprise',
      'role': 'owner',
      'branches': [
        {'id': 1, 'name': 'Pusat Dago', 'city': 'Bandung', 'code': 'BDG-01', 'is_central': true},
        {'id': 2, 'name': 'Cabang Timur', 'city': 'Bandung', 'code': 'BDG-02', 'is_central': false},
      ],
    };

    test('isConsolidated returns true when business is active but branch is null', () {
      final state = BusinessState(
        activeBusinessId: 100,
        activeBusinessName: 'RentCore Enterprise',
        activeBranchId: null,
        businesses: [mockBusiness],
      );

      expect(state.isConsolidated, isTrue);
      expect(state.currentBusiness?['name'], equals('RentCore Enterprise'));
      expect(state.currentBranch, isNull);
    });

    test('isCentralBranch correctly distinguishes central vs sub-branch', () {
      final centralState = BusinessState(
        activeBusinessId: 100,
        activeBusinessName: 'RentCore Enterprise',
        activeBranchId: 1,
        activeBranchName: 'Pusat Dago',
        businesses: [mockBusiness],
      );

      expect(centralState.isConsolidated, isFalse);
      expect(centralState.isCentralBranch, isTrue);

      final subState = BusinessState(
        activeBusinessId: 100,
        activeBusinessName: 'RentCore Enterprise',
        activeBranchId: 2,
        activeBranchName: 'Cabang Timur',
        businesses: [mockBusiness],
      );

      expect(subState.isConsolidated, isFalse);
      expect(subState.isCentralBranch, isFalse);
    });

    test('clearError resets error property in copyWith', () {
      const stateWithError = BusinessState(
        activeBusinessId: null,
        error: 'Network connection failed',
      );
      expect(stateWithError.error, equals('Network connection failed'));

      final stateCleared = stateWithError.copyWith(clearError: true);
      expect(stateCleared.error, isNull);
    });
  });

  group('HomeScreen Active Context & Safety Banner UI Tests', () {
    final sampleBusiness = {
      'id': 42,
      'name': 'SkyRental Studio',
      'role': 'owner',
      'branches': [
        {'id': 10, 'name': 'Cabang Utama Jakarta', 'city': 'Jakarta Selatan', 'code': 'JKT-01', 'is_central': true},
        {'id': 11, 'name': 'Cabang Depok', 'city': 'Depok', 'code': 'DPK-01', 'is_central': false},
      ],
    };

    final emptyDashboardData = {
      'is_empty_tenant': false,
      'branch_id': null,
      'is_consolidated': true,
      'kpi': {
        'units_total': 10,
        'units_ready': 8,
        'units_rented': 2,
        'units_maintenance': 0,
        'units_in_transit': 0,
        'utilization_rate': 20.0,
        'active_rentals': 2,
        'due_today': 0,
        'overdue': 0,
        'today_rentals_created': 1,
        'today_revenue': 500000.0,
        'today_transactions_count': 1,
      },
      'stats': {
        'total_units': 10,
        'ready_units': 8,
        'rented_units': 2,
        'maintenance_units': 0,
        'today_revenue': 500000,
        'active_rentals': 2,
        'overdue_count': 0,
      },
      'overdue_alerts': [],
      'imminent_returns': [],
      'recent_activities': [],
    };

    testWidgets('Displays prominent KONSOLIDASI warning banner in consolidated mode', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StaticAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': '1', 'name': 'Alex Boss', 'role': 'owner'},
              ),
            )),
            businessProvider.overrideWith(() => _StaticBusinessNotifier(
              BusinessState(
                activeBusinessId: 42,
                activeBusinessName: 'SkyRental Studio',
                activeBranchId: null,
                activeBranchName: null,
                businesses: [sampleBusiness],
              ),
            )),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyDashboardData)),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header greeting and role badge
      expect(find.text('PEMILIK (OWNER)'), findsOneWidget);
      expect(find.textContaining('Alex Boss'), findsOneWidget);

      // Check prominent consolidated banner
      expect(find.text('KONSOLIDASI'), findsOneWidget);
      expect(find.text('SkyRental Studio'), findsWidgets);
      expect(find.textContaining('Mode Konsolidasi'), findsOneWidget);
      expect(find.text('Pilih Cabang'), findsOneWidget);
    });

    testWidgets('Displays CABANG UTAMA badge when central branch is active', (tester) async {
      final adminBusiness = Map<String, dynamic>.from(sampleBusiness)..['role'] = 'admin';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StaticAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': '1', 'name': 'Budi Manager', 'role': 'admin'},
              ),
            )),
            businessProvider.overrideWith(() => _StaticBusinessNotifier(
              BusinessState(
                activeBusinessId: 42,
                activeBusinessName: 'SkyRental Studio',
                activeBranchId: 10,
                activeBranchName: 'Cabang Utama Jakarta',
                businesses: [adminBusiness],
              ),
            )),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyDashboardData)),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('ADMIN USAHA'), findsOneWidget);
      expect(find.text('CABANG UTAMA'), findsOneWidget);
      expect(find.text('Cabang Utama Jakarta'), findsOneWidget);
    });

    testWidgets('Displays SUB-CABANG badge when non-central branch is active', (tester) async {
      final staffBusiness = Map<String, dynamic>.from(sampleBusiness)..['role'] = 'staff';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StaticAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': '2', 'name': 'Siti Staff', 'role': 'staff'},
              ),
            )),
            businessProvider.overrideWith(() => _StaticBusinessNotifier(
              BusinessState(
                activeBusinessId: 42,
                activeBusinessName: 'SkyRental Studio',
                activeBranchId: 11,
                activeBranchName: 'Cabang Depok',
                businesses: [staffBusiness],
              ),
            )),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyDashboardData)),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('STAFF KASIR'), findsOneWidget);
      expect(find.text('SUB-CABANG'), findsOneWidget);
      expect(find.text('Cabang Depok'), findsOneWidget);
    });

    testWidgets('Displays diagnostic error card on business sync failure without false onboarding banner', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _StaticAuthNotifier(
              const AuthState(
                isAuthenticated: true,
                user: {'id': '1', 'name': 'Rian Cashier', 'role': 'staff'},
              ),
            )),
            businessProvider.overrideWith(() => _StaticBusinessNotifier(
              const BusinessState(
                activeBusinessId: null,
                error: '503 Service Unavailable: Database offline',
                businesses: [],
              ),
            )),
            dashboardKpiProvider.overrideWith((ref) => Future.value(emptyDashboardData)),
          ],
          child: MaterialApp(
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Diagnostic error card should be displayed
      expect(find.text('Gagal Menyinkronkan Konteks Bisnis'), findsOneWidget);
      expect(find.textContaining('503 Service Unavailable'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Misleading "Mulai Bisnis Rental Anda" onboarding banner must NOT appear
      expect(find.text('Mulai Bisnis Rental Anda'), findsNothing);
      expect(find.text('Daftarkan Bisnis Rental Baru'), findsNothing);
    });
  });
}

class _StaticAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _StaticAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _StaticBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _StaticBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

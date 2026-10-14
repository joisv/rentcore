import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';

class _FakeAuthRepository extends AuthRepository {
  final List<Map<String, dynamic>> stubbedBusinesses;
  _FakeAuthRepository(this.stubbedBusinesses);

  @override
  Future<List<Map<String, dynamic>>> fetchBusinesses() async {
    return stubbedBusinesses;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('Branch Context & Authorized Branch Resolver Tests', () {
    test('resolveAuthorizedBranch picks stored branch when authorized', () {
      final branches = [
        {'id': 4, 'name': 'Pusat (Main Store)', 'is_central': true},
        {'id': 5, 'name': 'Cabang A', 'is_central': false},
      ];

      final picked = resolveAuthorizedBranch(branches, 5);
      expect(picked, isNotNull);
      expect(picked!['id'], 5);
      expect(picked['name'], 'Cabang A');
    });

    test('resolveAuthorizedBranch falls back to first authorized branch when stored branch is unauthorized/stale', () {
      // E.g. User is staff assigned ONLY to Cabang A (id 5)
      // but SharedPreferences had stored id 4 (Pusat / Main store)
      final authorizedBranches = [
        {'id': 5, 'name': 'Cabang A', 'is_central': false},
      ];

      final picked = resolveAuthorizedBranch(authorizedBranches, 4);
      expect(picked, isNotNull);
      expect(picked!['id'], 5, reason: 'Must fall back to authorized branch 5 instead of stale branch 4');
      expect(picked['name'], 'Cabang A');
    });

    test('resolveAuthorizedBranch returns null for empty or null branch list', () {
      expect(resolveAuthorizedBranch([], 5), isNull);
      expect(resolveAuthorizedBranch(null, 5), isNull);
    });

    test('BusinessNotifier.loadInitialContext heals stale branch in SharedPreferences', () async {
      final prefs = await SharedPreferences.getInstance();
      // Simulate stored stale branch 4 (Main store)
      await prefs.setInt('active_business_id', 3);
      await prefs.setString('active_business_name', 'Gwenn Rental');
      await prefs.setInt('active_branch_id', 4);
      await prefs.setString('branch_name', 'Pusat');

      // The backend returns only branch 5 for this staff member
      final fakeRepo = _FakeAuthRepository([
        {
          'id': 3,
          'name': 'Gwenn Rental',
          'role': 'staff',
          'branches': [
            {'id': 5, 'name': 'Cabang A', 'is_central': false},
          ],
        }
      ]);

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(businessProvider.notifier);
      await notifier.loadInitialContext();

      final state = container.read(businessProvider);
      expect(state.activeBranchId, 5, reason: 'Active branch should be healed to authorized branch 5');
      expect(state.activeBranchName, 'Cabang A');

      // Verify SharedPreferences were updated so ApiClient uses the correct branch
      expect(prefs.getInt('active_branch_id'), 5);
      expect(prefs.getString('branch_name'), 'Cabang A');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/models/thermal_printer_models.dart';
import 'package:sewakasir/features/auth/data/auth_repository.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/customers/data/customer_repository.dart';
import 'package:sewakasir/features/customers/providers/customer_provider.dart';
import 'package:sewakasir/features/home/presentation/widgets/progressive_checklist_banner.dart';
import 'package:sewakasir/features/inventory/data/asset_repository.dart';
import 'package:sewakasir/features/inventory/providers/asset_provider.dart';
import 'package:sewakasir/features/onboarding/providers/onboarding_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_profile_screen.dart';
import 'package:sewakasir/features/organization/providers/organization_provider.dart';
import 'package:sewakasir/features/printer/providers/printer_provider.dart';
import 'package:sewakasir/features/vouchers/data/voucher_repository.dart';
import 'package:sewakasir/features/vouchers/providers/voucher_provider.dart';

class _MockAuthRepo extends AuthRepository {
  Map<String, dynamic>? updatedPayload;
  int? updatedBizId;

  final Map<String, List<Map<String, dynamic>>> userBusinesses = {
    'alice@rentcore.id': [
      {
        'id': 1,
        'name': 'Alice Rentals',
        'role': 'owner',
        'phone': '0811111111',
        'address': 'Jl. Alice No. 1',
        'slogan': 'Best cameras',
        'branches': [
          {'id': 10, 'name': 'Main', 'code': 'ALC', 'is_central': true}
        ]
      }
    ],
    'bob@rentcore.id': [
      {
        'id': 2,
        'name': 'Bob Laptops',
        'role': 'owner',
        'phone': '',
        'address': '',
        'slogan': '',
        'branches': [
          {'id': 20, 'name': 'Branch B', 'code': 'BOB', 'is_central': true}
        ]
      }
    ]
  };

  String? loggedInEmail;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    loggedInEmail = email;
    final biz = userBusinesses[email] ?? [];
    return {
      'token': 'mock-jwt-token',
      'user': {
        'id': email.hashCode,
        'name': email.split('@').first,
        'email': email,
        'role': 'owner',
      },
      'businesses': biz,
    };
  }

  @override
  Future<List<dynamic>> fetchBusinesses() async {
    if (loggedInEmail == null) return [];
    return userBusinesses[loggedInEmail] ?? [];
  }

  @override
  Future<Map<String, dynamic>?> checkSession() async {
    if (loggedInEmail == null) return null;
    return {
      'user': {
        'id': loggedInEmail.hashCode,
        'name': loggedInEmail!.split('@').first,
        'email': loggedInEmail,
        'role': 'owner',
      },
      'businesses': userBusinesses[loggedInEmail] ?? [],
    };
  }

  @override
  Future<void> logout() async {
    loggedInEmail = null;
  }

  @override
  Future<Map<String, dynamic>> updateBusiness(int businessId, Map<String, dynamic> data) async {
    updatedBizId = businessId;
    updatedPayload = data;
    if (loggedInEmail != null && userBusinesses.containsKey(loggedInEmail)) {
      final list = userBusinesses[loggedInEmail]!;
      final idx = list.indexWhere((b) => b['id'] == businessId);
      if (idx != -1) {
        list[idx] = {
          ...list[idx],
          ...data,
        };
      }
    }
    return {'success': true, 'data': data};
  }
}

class _MockCustomerRepo extends CustomerRepository {
  @override
  Future<Map<String, dynamic>> fetchCustomers({
    int page = 1,
    int perPage = 20,
    String? search,
    bool? isBlacklisted,
  }) async {
    return {'data': <Map<String, dynamic>>[], 'current_page': 1, 'last_page': 1};
  }
}

class _MockVoucherRepo extends VoucherRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchVouchers({
    String? status,
    String? search,
    dynamic branchId,
  }) async {
    return [];
  }
}

class _MockAssetRepo extends AssetRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchAssets({
    String? status,
    int? categoryId,
    String? search,
    int? branchId,
    bool allBranches = false,
  }) async {
    return [];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Provider Invalidation & LateInitializationError Elimination Tests', () {
    test('Repeated invalidation of printerProvider does NOT throw LateInitializationError', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Read initial state
      final s1 = container.read(printerProvider);
      expect(s1.status, PrinterConnectionStatus.disconnected);
      await null; // allow microtask to complete

      // Invalidate multiple times simulating repeated checklist interactions & account switches
      container.invalidate(printerProvider);
      final s2 = container.read(printerProvider);
      expect(s2.status, PrinterConnectionStatus.disconnected);
      await null;

      container.invalidate(printerProvider);
      final s3 = container.read(printerProvider);
      expect(s3.status, PrinterConnectionStatus.disconnected);
      await null;
    });

    test('Repeated invalidation of all tenant and repository providers succeeds without error', () async {
      final mockAuthRepo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          customerRepositoryProvider.overrideWithValue(_MockCustomerRepo()),
          voucherRepositoryProvider.overrideWithValue(_MockVoucherRepo()),
          assetRepositoryProvider.overrideWithValue(_MockAssetRepo()),
        ],
      );
      addTearDown(container.dispose);

      // Read providers
      container.read(authProvider);
      container.read(businessProvider);
      container.read(businessProfileProvider);
      container.read(onboardingProvider);
      container.read(storeChecklistProvider);
      container.read(customerProvider);
      container.read(voucherProvider);
      container.read(organizationProvider);
      container.read(physicalUnitsProvider);
      container.read(printerProvider);
      await null;

      // Invalidate all
      container.invalidate(authProvider);
      container.invalidate(businessProvider);
      container.invalidate(businessProfileProvider);
      container.invalidate(onboardingProvider);
      container.invalidate(storeChecklistProvider);
      container.invalidate(customerProvider);
      container.invalidate(voucherProvider);
      container.invalidate(organizationProvider);
      container.invalidate(physicalUnitsProvider);
      container.invalidate(printerProvider);

      // Re-read after invalidation: no LateInitializationError or ProviderException
      expect(() => container.read(authProvider), returnsNormally);
      expect(() => container.read(businessProvider), returnsNormally);
      expect(() => container.read(businessProfileProvider), returnsNormally);
      expect(() => container.read(onboardingProvider), returnsNormally);
      expect(() => container.read(storeChecklistProvider), returnsNormally);
      expect(() => container.read(customerProvider), returnsNormally);
      expect(() => container.read(voucherProvider), returnsNormally);
      expect(() => container.read(organizationProvider), returnsNormally);
      expect(() => container.read(physicalUnitsProvider), returnsNormally);
      expect(() => container.read(printerProvider), returnsNormally);
      await null;
    });

    test('Account Switch Lifecycle: Alice -> Logout -> Bob -> Logout -> Alice', () async {
      final mockAuthRepo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
          customerRepositoryProvider.overrideWithValue(_MockCustomerRepo()),
          voucherRepositoryProvider.overrideWithValue(_MockVoucherRepo()),
          assetRepositoryProvider.overrideWithValue(_MockAssetRepo()),
        ],
      );
      addTearDown(container.dispose);

      final authNotifier = container.read(authProvider.notifier);

      // 1. Login Alice
      final login1 = await authNotifier.login('alice@rentcore.id', 'pw');
      expect(login1, isTrue);
      expect(container.read(authProvider).user?['name'], 'alice');
      expect(container.read(businessProvider).activeBusinessName, 'Alice Rentals');

      // 2. Logout Alice
      await authNotifier.logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);
      expect(container.read(businessProvider).activeBusinessId, isNull);

      // 3. Login Bob (different account, same device lifecycle)
      final login2 = await authNotifier.login('bob@rentcore.id', 'pw');
      expect(login2, isTrue);
      expect(container.read(authProvider).user?['name'], 'bob');
      expect(container.read(businessProvider).activeBusinessName, 'Bob Laptops');

      // 4. Logout Bob
      await authNotifier.logout();
      expect(container.read(authProvider).isAuthenticated, isFalse);

      // 5. Re-login Alice (existing account relogin without app restart)
      final login3 = await authNotifier.login('alice@rentcore.id', 'pw');
      expect(login3, isTrue);
      expect(container.read(authProvider).user?['name'], 'alice');
      expect(container.read(businessProvider).activeBusinessName, 'Alice Rentals');
    });
  });

  group('Store Profile Save & Checklist Navigation Flow Tests', () {
    testWidgets('StoreProfileScreen saves cleanly, invalidates checklist, and pops back', (tester) async {
      final mockAuthRepo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      // Setup initial logged-in user Bob who has empty profile
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('bob@rentcore.id', 'pw');

      bool popped = false;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        final res = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                        );
                        if (res == true) {
                          popped = true;
                        }
                      },
                      child: const Text('Open Profile'),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open StoreProfileScreen
      await tester.tap(find.text('Open Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(StoreProfileScreen), findsOneWidget);

      // Fill in Slogan, Phone, Address
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'Laptop Terbaik',
      );
      await tester.enterText(
        find.byType(TextFormField).at(2),
        '08987654321',
      );
      await tester.enterText(
        find.byType(TextFormField).at(3),
        'Jl. Raya Laptop No. 99',
      );
      await tester.pumpAndSettle();

      // Tap Simpan Profil Toko
      await tester.tap(find.text('Simpan Profil Toko'));
      await tester.pumpAndSettle();

      // Verify popped back
      expect(popped, isTrue);
      expect(find.byType(StoreProfileScreen), findsNothing);

      // Verify repo was updated
      expect(mockAuthRepo.updatedBizId, 2);
      expect(mockAuthRepo.updatedPayload?['phone'], '08987654321');
      expect(mockAuthRepo.updatedPayload?['slogan'], 'Laptop Terbaik');
      expect(mockAuthRepo.updatedPayload?['address'], 'Jl. Raya Laptop No. 99');

      // Verify businessProvider reflects updated profile
      final bState = container.read(businessProvider);
      expect(bState.currentBusiness?['phone'], '08987654321');
      expect(bState.currentBusiness?['slogan'], 'Laptop Terbaik');
      expect(bState.currentBusiness?['address'], 'Jl. Raya Laptop No. 99');
    });

    testWidgets('ProgressiveChecklistBanner renders updated profile after save without ProviderException', (tester) async {
      final mockAuthRepo = _MockAuthRepo();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuthRepo),
        ],
      );
      addTearDown(container.dispose);

      // Login Bob (empty profile initially)
      final authNotifier = container.read(authProvider.notifier);
      await authNotifier.login('bob@rentcore.id', 'pw');

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: ProgressiveChecklistBanner(totalAssetCount: 0),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Panduan Persiapan Toko'), findsOneWidget);
      // Initially 0 of 4 complete
      expect(find.text('0 dari 4 Selesai'), findsOneWidget);

      // Tap Lengkapi Profil Usaha
      await tester.tap(find.text('Lengkapi Profil Usaha'));
      await tester.pumpAndSettle();
      expect(find.byType(StoreProfileScreen), findsOneWidget);

      // Fill in phone
      await tester.enterText(
        find.byType(TextFormField).at(2),
        '081234567890',
      );
      await tester.pumpAndSettle();

      // Tap Simpan
      await tester.tap(find.text('Simpan Profil Toko'));
      await tester.pumpAndSettle();

      // Back on dashboard checklist banner without any ProviderException!
      expect(find.byType(StoreProfileScreen), findsNothing);
      expect(find.text('Panduan Persiapan Toko'), findsOneWidget);
      // Now 1 of 4 completed (hasProfile is true!)
      expect(find.text('1 dari 4 Selesai'), findsOneWidget);
    });
  });
}

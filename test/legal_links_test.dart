import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/network/api_client.dart';
import 'package:sewakasir/core/utils/legal_links.dart';
import 'package:sewakasir/features/auth/presentation/login_screen.dart';
import 'package:sewakasir/features/auth/presentation/user_profile_screen.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient().updateBaseUrl('https://api.rentcore.example/api/v1');
  });

  test('LegalLinks derives web URLs cleanly from ApiClient baseUrl', () {
    expect(LegalLinks.webBaseUrl, equals('https://api.rentcore.example'));
    expect(
      LegalLinks.privacyPolicyUri.toString(),
      equals('https://api.rentcore.example/privacy-policy'),
    );
    expect(
      LegalLinks.accountDeletionUri.toString(),
      equals('https://api.rentcore.example/account-deletion'),
    );
  });

  testWidgets('LoginScreen shows Kebijakan Privasi footer link', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('login_privacy_policy_button')), findsOneWidget);
    expect(find.text('Kebijakan Privasi'), findsOneWidget);
  });

  testWidgets('UserProfileScreen and StoreSettingsScreen show Kebijakan Privasi and Hapus Akun links', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_MockAuthNotifier.new),
          businessProvider.overrideWith(_MockBusinessNotifier.new),
        ],
        child: const MaterialApp(home: UserProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('profile_privacy_policy_tile')), findsOneWidget);
    expect(find.byKey(const Key('profile_account_deletion_tile')), findsOneWidget);
    expect(find.text('Kebijakan Privasi'), findsOneWidget);
    expect(find.text('Hapus Akun'), findsOneWidget);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_MockAuthNotifier.new),
          businessProvider.overrideWith(_MockBusinessNotifier.new),
        ],
        child: const MaterialApp(home: StoreSettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PRIVASI & LEGAL'), findsOneWidget);
    expect(find.text('Kebijakan Privasi'), findsOneWidget);
    expect(find.text('Hapus Akun'), findsOneWidget);
  });
}

class _MockAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
        isAuthenticated: true,
        user: {'id': 'u1', 'name': 'Rina Kasir', 'email': 'rina@example.com', 'role': 'staff'},
      );
}

class _MockBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Kamera Nusantara',
      );
}

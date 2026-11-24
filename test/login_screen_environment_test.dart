import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/config/app_config.dart';
import 'package:rentcore_mobile/core/constants/api_constants.dart';
import 'package:rentcore_mobile/core/network/api_client.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/presentation/login_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';

class _IdleFakeAuthRepository extends AuthRepository {
  String? lastEmail;
  String? lastPassword;
  int loginCalls = 0;

  @override
  Future<Map<String, dynamic>?> checkSession() async => null;

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    loginCalls++;
    lastEmail = email;
    lastPassword = password;
    return {
      'token': 'fake_token',
      'user': {'id': 1, 'name': 'Test User', 'email': email, 'role': 'owner'},
      'businesses': [],
    };
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AppConfig.debugEnvironmentOverride = null;
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    await ApiClient().init();
  });

  tearDown(() async {
    AppConfig.debugEnvironmentOverride = null;
    await ApiClient().updateBaseUrl(ApiConstants.defaultBaseUrl);
  });

  group('AppConfig & ApiClient Environment Separation', () {
    test('resolveEnvironment applies strict production vs development rules', () {
      expect(
        AppConfig.resolveEnvironment(rawEnv: 'production', isReleaseMode: false),
        AppEnvironment.production,
      );
      expect(
        AppConfig.resolveEnvironment(rawEnv: '', isReleaseMode: true),
        AppEnvironment.production,
      );
      expect(
        AppConfig.resolveEnvironment(rawEnv: 'dev', isReleaseMode: true),
        AppEnvironment.development,
      );
      expect(
        AppConfig.resolveEnvironment(rawEnv: '', isReleaseMode: false),
        AppEnvironment.development,
      );
    });

    test('Production mode locks ApiClient baseUrl and ignores local server overrides', () async {
      SharedPreferences.setMockInitialValues({
        'api_base_url': 'http://192.168.1.101:8000/api/v1',
      });
      AppConfig.debugEnvironmentOverride = AppEnvironment.production;

      await ApiClient().init();
      expect(ApiClient().currentBaseUrl, AppConfig.productionBaseUrl);
      expect(ApiClient().dio.options.baseUrl, AppConfig.productionBaseUrl);

      await ApiClient().updateBaseUrl('http://127.0.0.1:8000/api/v1');
      expect(ApiClient().currentBaseUrl, AppConfig.productionBaseUrl);
      expect(ApiClient().dio.options.baseUrl, AppConfig.productionBaseUrl);
    });

    test('Development mode respects persisted and updated local baseUrl', () async {
      SharedPreferences.setMockInitialValues({
        'api_base_url': 'http://10.0.2.2:8000/api/v1',
      });
      AppConfig.debugEnvironmentOverride = AppEnvironment.development;

      await ApiClient().init();
      expect(ApiClient().currentBaseUrl, 'http://10.0.2.2:8000/api/v1');

      await ApiClient().updateBaseUrl('http://127.0.0.1:8000/api/v1');
      expect(ApiClient().currentBaseUrl, 'http://127.0.0.1:8000/api/v1');
    });
  });

  group('LoginScreen Production vs Development UI Tests', () {
    Widget buildLoginSubject({
      required AppEnvironment environment,
      required AuthRepository authRepo,
    }) {
      return ProviderScope(
        overrides: [
          appEnvironmentProvider.overrideWithValue(environment),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
        child: const MaterialApp(home: LoginScreen()),
      );
    }

    testWidgets(
      'Production mode hides demo accounts & server config, initializes empty fields, and renders Airy Minimalist controls cleanly',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);
        addTearDown(() => FlutterError.onError = prevOnError);

        AppConfig.debugEnvironmentOverride = AppEnvironment.production;
        final fakeRepo = _IdleFakeAuthRepository();

        await tester.pumpWidget(
          buildLoginSubject(
            environment: AppEnvironment.production,
            authRepo: fakeRepo,
          ),
        );
        await tester.pumpAndSettle();

        // Status bar style uses dark icons against #FFFFFF canvas
        final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>).first,
        );
        expect(region.value, SystemUiOverlayStyle.dark);

        // Zero dev chrome or demo credentials exist in widget tree
        expect(find.byKey(const Key('login_dev_badge')), findsNothing);
        expect(find.byKey(const Key('login_server_config_button')), findsNothing);
        expect(find.byKey(const Key('login_demo_section')), findsNothing);
        expect(find.text('PILIHAN AKUN DEMO RESMI'), findsNothing);
        expect(find.text('Kasir Genteng'), findsNothing);
        expect(find.text('Manager Genteng'), findsNothing);
        expect(find.text('Owner'), findsNothing);

        // Email and password fields start empty
        final emailField = tester.widget<TextField>(
          find.byKey(const Key('login_email_field')),
        );
        final passwordField = tester.widget<TextField>(
          find.byKey(const Key('login_password_field')),
        );
        expect(emailField.controller?.text, isEmpty);
        expect(passwordField.controller?.text, isEmpty);

        // Crisp Airy Minimalist branding, form labels, CTAs & onboarding footer exist
        expect(find.text('RENTCORE'), findsOneWidget);
        expect(find.text('Electronic Rental Operating System'), findsOneWidget);
        expect(find.text('Email'), findsOneWidget);
        expect(find.text('Kata Sandi'), findsOneWidget);
        expect(find.byKey(const Key('login_forgot_password_button')), findsOneWidget);
        expect(find.text('Masuk'), findsOneWidget);
        expect(find.byKey(const Key('login_google_button')), findsOneWidget);
        expect(find.text('Masuk dengan Google'), findsOneWidget);
        expect(find.text('Belum punya akun usaha?'), findsOneWidget);
        expect(find.byKey(const Key('login_register_button')), findsOneWidget);
        expect(find.text('Daftar Gratis'), findsOneWidget);
        expect(find.byKey(const Key('login_privacy_policy_button')), findsOneWidget);

        // Tapping Daftar Gratis opens onboarding registration sheet cleanly
        await tester.ensureVisible(find.byKey(const Key('login_register_button')));
        await tester.tap(find.byKey(const Key('login_register_button')));
        await tester.pumpAndSettle();
        expect(find.text('Daftar Akun Usaha Gratis'), findsOneWidget);
        expect(find.text('Daftar dengan Google'), findsOneWidget);
        await tester.tap(find.text('Nanti Saja'));
        await tester.pumpAndSettle();

        // Tapping Lupa Kata Sandi opens help sheet cleanly
        await tester.ensureVisible(find.byKey(const Key('login_forgot_password_button')));
        await tester.tap(find.byKey(const Key('login_forgot_password_button')));
        await tester.pumpAndSettle();
        expect(find.text('Bantuan Kata Sandi'), findsOneWidget);
        await tester.tap(find.text('Kembali'));
        await tester.pumpAndSettle();

        FlutterError.onError = prevOnError;
        final overflowErrors =
            errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty);
      },
    );

    testWidgets(
      'Development mode shows DEV badge, server config icon, and non-clipped quick-fill demo pills',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final errors = <FlutterErrorDetails>[];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) => errors.add(details);
        addTearDown(() => FlutterError.onError = prevOnError);

        AppConfig.debugEnvironmentOverride = AppEnvironment.development;
        final fakeRepo = _IdleFakeAuthRepository();

        await tester.pumpWidget(
          buildLoginSubject(
            environment: AppEnvironment.development,
            authRepo: fakeRepo,
          ),
        );
        await tester.pumpAndSettle();

        // DEV badge & server switcher icon visible
        expect(find.byKey(const Key('login_dev_badge')), findsOneWidget);
        expect(find.text('DEV'), findsOneWidget);
        expect(
          find.byKey(const Key('login_server_config_button')),
          findsOneWidget,
        );

        // Demo quick-fill section visible with all 3 roles
        expect(find.byKey(const Key('login_demo_section')), findsOneWidget);
        expect(find.text('PILIHAN AKUN DEMO RESMI'), findsOneWidget);
        expect(find.byKey(const Key('demo_fill_kasir')), findsOneWidget);
        expect(find.byKey(const Key('demo_fill_manager')), findsOneWidget);
        expect(find.byKey(const Key('demo_fill_owner')), findsOneWidget);

        // Scroll to demo section and quick-fill Owner, Manager, Kasir
        await tester.ensureVisible(find.byKey(const Key('demo_fill_owner')));
        await tester.tap(find.byKey(const Key('demo_fill_owner')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_email_field')))
              .controller
              ?.text,
          'superadmin@rentcore.id',
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_password_field')))
              .controller
              ?.text,
          'password',
        );

        await tester.tap(find.byKey(const Key('demo_fill_manager')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_email_field')))
              .controller
              ?.text,
          'manager.genteng@rentcore.id',
        );

        await tester.tap(find.byKey(const Key('demo_fill_kasir')));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextField>(find.byKey(const Key('login_email_field')))
              .controller
              ?.text,
          'kasir.genteng@rentcore.id',
        );

        // Collapsing & re-expanding demo section works cleanly
        await tester.ensureVisible(find.byKey(const Key('login_demo_toggle')));
        await tester.tap(find.byKey(const Key('login_demo_toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('demo_fill_kasir')), findsNothing);

        await tester.tap(find.byKey(const Key('login_demo_toggle')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('demo_fill_kasir')), findsOneWidget);

        // Open server settings dialog in DEV mode
        await tester.ensureVisible(
          find.byKey(const Key('login_server_config_button')),
        );
        await tester.tap(find.byKey(const Key('login_server_config_button')));
        await tester.pumpAndSettle();
        expect(find.text('Pengaturan Server & OAuth'), findsOneWidget);
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();

        FlutterError.onError = prevOnError;
        final overflowErrors =
            errors.where((e) => e.toString().contains('overflowed')).toList();
        expect(overflowErrors, isEmpty);
      },
    );
  });
}

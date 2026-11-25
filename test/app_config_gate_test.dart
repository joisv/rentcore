import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/core/providers/app_config_provider.dart';
import 'package:sewakasir/core/services/app_config_service.dart';
import 'package:sewakasir/shared/widgets/app_gate_overlay.dart';

void main() {
  group('SemVer Comparison Tests', () {
    test('compares major, minor, and patch numerically rather than lexicographically', () {
      expect(compareSemVer('1.10.0', '1.2.0'), greaterThan(0));
      expect(compareSemVer('1.2.0', '1.10.0'), lessThan(0));
      expect(compareSemVer('2.0.0', '1.99.99'), greaterThan(0));
      expect(compareSemVer('1.2.3+14', '1.2.3'), equals(0));
      expect(compareSemVer('v1.2.0-beta', '1.2.0'), equals(0));
      expect(compareSemVer('1.2', '1.2.0'), equals(0));

      expect(isVersionLowerThan('1.0.0', '1.0.1'), isTrue);
      expect(isVersionLowerThan('1.2.0', '1.10.0'), isTrue);
      expect(isVersionLowerThan('1.10.0', '1.2.0'), isFalse);
      expect(isVersionLowerThan('1.2.0', '1.2.0'), isFalse);
    });
  });

  group('AppConfigService & Gate Fail-Open Tests', () {
    test('returns null (fail-open) on network timeout or DioException', () async {
      final failingDio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.reject(
                DioException.connectionTimeout(
                  timeout: const Duration(seconds: 4),
                  requestOptions: options,
                ),
              );
            },
          ),
        );

      final service = AppConfigService(dio: failingDio);
      final result = await service.fetchAppConfig();
      expect(result, isNull);
    });

    test('AppConfigNotifier fails open to AppGateStatus.ok when fetchAppConfig returns null', () async {
      final container = ProviderContainer(
        overrides: [
          appConfigServiceProvider.overrideWithValue(_FakeAppConfigService([null])),
          packageVersionLoaderProvider.overrideWithValue(() async => '1.0.0'),
        ],
      );
      addTearDown(container.dispose);

      await container.read(appConfigProvider.notifier).checkGate();
      final state = container.read(appConfigProvider);

      expect(state.gateStatus, equals(AppGateStatus.ok));
      expect(state.installedVersion, equals('1.0.0'));
    });
  });

  group('AppConfigGateObserver UI Overlay Tests', () {
    testWidgets('shows Maintenance overlay with Coba Lagi and recovers on retry', (tester) async {
      final fakeService = _FakeAppConfigService([
        const AppConfigData(
          minAndroidVersion: '1.0.0',
          latestAndroidVersion: '1.0.0',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
          maintenanceMode: true,
          maintenanceMessage: 'Upgrade database 5 menit.',
        ),
        const AppConfigData(
          minAndroidVersion: '1.0.0',
          latestAndroidVersion: '1.0.0',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
          maintenanceMode: false,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigServiceProvider.overrideWithValue(fakeService),
            packageVersionLoaderProvider.overrideWithValue(() async => '1.0.0'),
          ],
          child: const MaterialApp(
            home: AppConfigGateObserver(
              child: Scaffold(body: Center(child: Text('App Content'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sistem Sedang Pemeliharaan'), findsOneWidget);
      expect(find.text('Upgrade database 5 menit.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('maintenance_retry_button')));
      await tester.pumpAndSettle();

      expect(find.text('Sistem Sedang Pemeliharaan'), findsNothing);
      expect(find.text('App Content'), findsOneWidget);
    });

    testWidgets('shows Force Update overlay when version < min_android_version and re-checks on resume', (tester) async {
      Uri? launchedUri;
      final fakeService = _FakeAppConfigService([
        const AppConfigData(
          minAndroidVersion: '1.2.0',
          latestAndroidVersion: '1.3.0',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
          maintenanceMode: false,
          forceUpdateMessage: 'Wajib update ke versi 1.2.0.',
        ),
        const AppConfigData(
          minAndroidVersion: '1.0.0',
          latestAndroidVersion: '1.3.0',
          playStoreUrl: 'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
          maintenanceMode: false,
        ),
      ]);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigServiceProvider.overrideWithValue(fakeService),
            packageVersionLoaderProvider.overrideWithValue(() async => '1.1.9'),
          ],
          child: MaterialApp(
            home: AppConfigGateObserver(
              onLaunchStoreUrl: (uri) async {
                launchedUri = uri;
                return true;
              },
              child: const Scaffold(body: Center(child: Text('App Content'))),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pembaruan Aplikasi Diperlukan'), findsOneWidget);
      expect(find.text('Wajib update ke versi 1.2.0.'), findsOneWidget);
      expect(find.textContaining('v1.1.9'), findsOneWidget);

      await tester.tap(find.byKey(const Key('force_update_store_button')));
      await tester.pumpAndSettle();
      expect(launchedUri.toString(), equals('https://play.google.com/store/apps/details?id=id.sewakasir.mobile'));

      // Simulate app resume -> triggers second fetchAppConfig where minAndroidVersion is 1.0.0
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text('Pembaruan Aplikasi Diperlukan'), findsNothing);
      expect(find.text('App Content'), findsOneWidget);
    });
  });
}

class _FakeAppConfigService extends AppConfigService {
  final List<AppConfigData?> responses;
  int _index = 0;

  _FakeAppConfigService(this.responses);

  @override
  Future<AppConfigData?> fetchAppConfig() async {
    final item = responses[_index < responses.length ? _index : responses.length - 1];
    _index++;
    return item;
  }
}

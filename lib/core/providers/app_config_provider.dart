import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../services/app_config_service.dart';

enum AppGateStatus {
  ok,
  maintenance,
  forceUpdate,
}

class AppConfigState {
  final AppGateStatus gateStatus;
  final String installedVersion;
  final AppConfigData? config;
  final bool isChecking;

  const AppConfigState({
    this.gateStatus = AppGateStatus.ok,
    this.installedVersion = '1.0.0',
    this.config,
    this.isChecking = false,
  });

  AppConfigState copyWith({
    AppGateStatus? gateStatus,
    String? installedVersion,
    AppConfigData? config,
    bool? isChecking,
  }) {
    return AppConfigState(
      gateStatus: gateStatus ?? this.gateStatus,
      installedVersion: installedVersion ?? this.installedVersion,
      config: config ?? this.config,
      isChecking: isChecking ?? this.isChecking,
    );
  }
}

final appConfigServiceProvider = Provider<AppConfigService>((ref) {
  return AppConfigService();
});

final packageVersionLoaderProvider = Provider<Future<String> Function()>((ref) {
  return () async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  };
});

final appConfigProvider = NotifierProvider<AppConfigNotifier, AppConfigState>(
  AppConfigNotifier.new,
);

class AppConfigNotifier extends Notifier<AppConfigState> {
  @override
  AppConfigState build() => const AppConfigState();

  Future<void> checkGate() async {
    if (state.isChecking) return;
    state = state.copyWith(isChecking: true);

    String installedVersion = state.installedVersion;
    try {
      final loader = ref.read(packageVersionLoaderProvider);
      final loaded = (await loader()).trim();
      if (loaded.isNotEmpty) {
        installedVersion = loaded;
      }
    } catch (_) {
      // Keep fallback installedVersion if PackageInfo is unavailable in tests
    }

    final service = ref.read(appConfigServiceProvider);
    final config = await service.fetchAppConfig();

    if (!ref.mounted) return;

    if (config == null) {
      // Fail-open on network/timeout errors so cashiers are never locked out
      state = state.copyWith(
        gateStatus: AppGateStatus.ok,
        installedVersion: installedVersion,
        isChecking: false,
      );
      return;
    }

    final nextGate = config.maintenanceMode
        ? AppGateStatus.maintenance
        : (isVersionLowerThan(installedVersion, config.minAndroidVersion)
            ? AppGateStatus.forceUpdate
            : AppGateStatus.ok);

    state = state.copyWith(
      gateStatus: nextGate,
      installedVersion: installedVersion,
      config: config,
      isChecking: false,
    );
  }
}

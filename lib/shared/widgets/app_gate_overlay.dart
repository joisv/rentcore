import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/providers/app_config_provider.dart';

class AppConfigGateObserver extends ConsumerStatefulWidget {
  final Widget child;
  final Future<bool> Function(Uri uri)? onLaunchStoreUrl;

  const AppConfigGateObserver({
    super.key,
    required this.child,
    this.onLaunchStoreUrl,
  });

  @override
  ConsumerState<AppConfigGateObserver> createState() =>
      _AppConfigGateObserverState();
}

class _AppConfigGateObserverState extends ConsumerState<AppConfigGateObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() {
      if (mounted) {
        ref.read(appConfigProvider.notifier).checkGate();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.read(appConfigProvider.notifier).checkGate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final gateState = ref.watch(appConfigProvider);

    return Stack(
      children: [
        widget.child,
        if (gateState.gateStatus == AppGateStatus.maintenance)
          Positioned.fill(
            child: _BlockingGateScreen(
              icon: Icons.build_circle_outlined,
              iconColor: AppColors.warning,
              iconBackground: AppColors.warningLight,
              title: 'Sistem Sedang Pemeliharaan',
              message:
                  gateState.config?.maintenanceMessage ??
                  'Kami sedang melakukan pemeliharaan server untuk meningkatkan layanan. Silakan coba kembali beberapa saat lagi.',
              primaryButtonKey: const Key('maintenance_retry_button'),
              primaryLabel: gateState.isChecking ? 'Memeriksa...' : 'Coba Lagi',
              isLoading: gateState.isChecking,
              onPrimaryPressed: gateState.isChecking
                  ? null
                  : () => ref.read(appConfigProvider.notifier).checkGate(),
            ),
          )
        else if (gateState.gateStatus == AppGateStatus.forceUpdate)
          Positioned.fill(
            child: _BlockingGateScreen(
              icon: Icons.system_update_rounded,
              iconColor: AppColors.obsidian,
              iconBackground: AppColors.surfaceMuted,
              title: 'Pembaruan Aplikasi Diperlukan',
              subtitle:
                  'Versi terpasang: v${gateState.installedVersion} • Minimal: v${gateState.config?.minAndroidVersion ?? "1.0.0"}',
              message:
                  gateState.config?.forceUpdateMessage ??
                  'Versi terbaru aplikasi tersedia di Google Play Store dengan peningkatan performa dan keamanan. Mohon perbarui aplikasi untuk melanjutkan.',
              primaryButtonKey: const Key('force_update_store_button'),
              primaryLabel: 'Update di Play Store',
              onPrimaryPressed: () => _openPlayStore(
                context,
                gateState.config?.playStoreUrl ??
                    'https://play.google.com/store/apps/details?id=id.sewakasir.mobile',
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _openPlayStore(BuildContext context, String rawUrl) async {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return;

    bool launched = false;
    try {
      if (widget.onLaunchStoreUrl != null) {
        launched = await widget.onLaunchStoreUrl!(uri);
      } else {
        launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Tidak dapat membuka Google Play Store. Silakan buka Play Store secara manual.'),
            backgroundColor: AppColors.danger,
          ),
        );
    }
  }
}

class _BlockingGateScreen extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String? subtitle;
  final String message;
  final Key primaryButtonKey;
  final String primaryLabel;
  final bool isLoading;
  final VoidCallback? onPrimaryPressed;

  const _BlockingGateScreen({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    this.subtitle,
    required this.message,
    required this.primaryButtonKey,
    required this.primaryLabel,
    this.isLoading = false,
    this.onPrimaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Material(
        color: AppColors.background,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 76,
                        height: 76,
                        decoration: BoxDecoration(
                          color: iconBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(icon, size: 38, color: iconColor),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            subtitle!,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton(
                      key: primaryButtonKey,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: onPrimaryPressed,
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              primaryLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

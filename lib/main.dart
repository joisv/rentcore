import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/navigation_keys.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/providers/business_provider.dart';
import 'features/onboarding/presentation/business_setup_wizard_screen.dart';
import 'features/onboarding/presentation/feature_walkthrough_screen.dart';
import 'features/onboarding/providers/onboarding_provider.dart';
import 'features/cashier/presentation/financial_hub_screen.dart';
import 'features/bookings/presentation/direct_rental_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'features/inventory/presentation/inventory_screen.dart';
import 'features/organization/presentation/store_settings_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/network/api_client.dart';
import 'core/constants/app_colors.dart';
import 'core/network/network_status_provider.dart';
import 'shared/widgets/app_gate_overlay.dart';
import 'shared/widgets/floating_capsule_dock.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID', null);
  await ApiClient().init();
  runApp(const ProviderScope(child: RentCoreApp()));
}

class RentCoreApp extends ConsumerWidget {
  const RentCoreApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      title: 'SewaKasir',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const AppConfigGateObserver(child: AuthRoutingGate()),
      routes: {
        '/login': (context) => const AppConfigGateObserver(child: AuthRoutingGate()),
      },
    );
  }
}

class AuthRoutingGate extends ConsumerWidget {
  const AuthRoutingGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isAuthenticated) {
      return const LoginScreen();
    }

    final businessState = ref.watch(businessProvider);
    final onboardingState = ref.watch(onboardingProvider);

    // Initial session & business resolution in progress
    if (authState.isLoading || businessState.isLoading || onboardingState.isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.obsidian,
            strokeWidth: 2.5,
          ),
        ),
      );
    }

    // Tenant Owner setup gate: 0 businesses registered
    final isPlatformAdmin = authState.user?['is_platform_admin'] == true;
    if (businessState.businesses.isEmpty && !isPlatformAdmin) {
      return const BusinessSetupWizardScreen();
    }

    // Feature Walkthrough gate (Owners & Cashiers)
    if (!onboardingState.hasCompletedWalkthrough) {
      return const FeatureWalkthroughScreen();
    }

    // Active Dashboard Workspace
    return const MainShellScreen();
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentTabIndex = 0;

  void _openNewBookingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      showDragHandle: false,
      isDismissible: false,
      useSafeArea: true,
      useRootNavigator: true,
      backgroundColor: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => const SizedBox.expand(
        child: DirectRentalScreen(showAppBar: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);

    return Scaffold(
      body: Column(
        children: [
          if (networkStatus == NetworkStatus.offline)
            Container(
              width: double.infinity,
              color: AppColors.danger,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SafeArea(
                bottom: false,
                child: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Koneksi Terputus (Mode Offline). Menunggu jaringan...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => ref.read(networkStatusProvider.notifier).checkConnectivity(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Coba Ulang',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (networkStatus == NetworkStatus.checking)
            Container(
              width: double.infinity,
              color: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: const SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Memeriksa ketersediaan server...',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _currentTabIndex,
              children: [
                HomeScreen(
                  onNavigateTab: (index) => setState(() => _currentTabIndex = index),
                ),
                const FinancialHubScreen(),
                const InventoryScreen(),
                const StoreSettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingCapsuleDock(
        currentIndex: _currentTabIndex,
        onTabSelected: (index) => setState(() => _currentTabIndex = index),
        onAddTap: () => _openNewBookingSheet(context),
      ),
    );
  }
}

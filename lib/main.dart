import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/bookings/presentation/bookings_screen.dart';
import 'features/bookings/presentation/direct_rental_screen.dart';
import 'features/cashier/presentation/cashier_screen.dart';
import 'features/home/presentation/home_screen.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/network/api_client.dart';
import 'core/constants/app_colors.dart';
import 'core/network/network_status_provider.dart';
import 'features/vouchers/presentation/voucher_screen.dart';
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
    final authState = ref.watch(authProvider);

    return MaterialApp(
      title: 'RentCore Mobile',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: authState.isAuthenticated
          ? const MainShellScreen()
          : const LoginScreen(),
    );
  }
}

class MainShellScreen extends ConsumerStatefulWidget {
  const MainShellScreen({super.key});

  @override
  ConsumerState<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends ConsumerState<MainShellScreen> {
  int _currentTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final networkStatus = ref.watch(networkStatusProvider);

    return Scaffold(
      extendBody: true,
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
                  onOpenDirectRental: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DirectRentalScreen()),
                    );
                  },
                ),
                const BookingsScreen(),
                const VoucherScreen(),
                const CashierScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: FloatingCapsuleDock(
        currentIndex: _currentTabIndex,
        onTabSelected: (index) => setState(() => _currentTabIndex = index),
      ),
    );
  }
}

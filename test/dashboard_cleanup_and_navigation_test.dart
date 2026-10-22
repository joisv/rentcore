import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/presentation/user_profile_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';
import 'package:rentcore_mobile/shared/widgets/floating_capsule_dock.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final fakeDashboardData = <String, dynamic>{
    'kpi': {
      'total_revenue': 1500000,
      'active_rentals': 3,
      'overdue_rentals': 0,
      'ready_assets': 10,
      'rented_assets': 3,
      'maintenance_assets': 1,
      'fleet_total': 14,
      'today_bookings': 2,
      'today_returns': 1,
    },
    'overdue_list': [],
  };

  group('FloatingCapsuleDock 4-Tab Navigation Tests', () {
    testWidgets('renders exactly 4 navigation items and Pengaturan at index 3', (tester) async {
      int selectedIndex = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: FloatingCapsuleDock(
              currentIndex: selectedIndex,
              onTabSelected: (idx) => selectedIndex = idx,
            ),
          ),
        ),
      );

      // Verify 4 dock items exist
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Sewa'), findsNothing); // Unselected tabs don't show text label, only icon
      expect(find.byIcon(Icons.dashboard_outlined), findsNothing);
      expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
      expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

      // Verify Voucher and old Kasir icons are completely removed from dock
      expect(find.byIcon(Icons.confirmation_number_outlined), findsNothing);
      expect(find.byIcon(Icons.point_of_sale_outlined), findsNothing);

      // Tap index 3 (Pengaturan)
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      expect(selectedIndex, 3);
    });
  });

  group('HomeScreen Header & Quick Actions Cleanup Tests', () {
    testWidgets('renders New Rental FAB, branch switcher icon in header, and removes Return/Inventory shortcuts', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      bool directRentalOpened = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardKpiProvider.overrideWith((ref) => Future.value(fakeDashboardData)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: HomeScreen(
                onNavigateTab: (_) {},
                onOpenDirectRental: () {
                  directRentalOpened = true;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. FAB: FloatingActionButton.extended with 'Sewa Baru' exists and triggers onOpenDirectRental
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.widgetWithText(FloatingActionButton, 'Sewa Baru'), findsOneWidget);
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Sewa Baru'));
      await tester.pumpAndSettle();
      expect(directRentalOpened, isTrue);

      // 2. Return & Inventory shortcuts are removed from the dashboard body
      expect(find.text('Pengembalian'), findsNothing);
      expect(find.text('Inventaris'), findsNothing);
      expect(find.text('Transfer Unit'), findsNothing);
      expect(find.text('Voucher'), findsNothing);
      expect(find.text('Kasir'), findsNothing);
      expect(find.text('Kelola Tim'), findsNothing);

      // 3. Profile header has branch switcher icon and NOT settings icon or logout icon
      expect(find.byTooltip('Pengaturan'), findsNothing);
      expect(find.byTooltip('Keluar'), findsNothing);
      expect(find.byTooltip('Ganti Cabang'), findsOneWidget);
      expect(find.byIcon(Icons.storefront_rounded), findsWidgets);

      // 4. Separate "Pilih Cabang" button below user's name is removed
      expect(find.text('Pilih Cabang'), findsNothing);

      // 5. Tapping the header branch switch icon opens BusinessSelectorSheet
      await tester.tap(find.byTooltip('Ganti Cabang'));
      await tester.pumpAndSettle();
      expect(find.text('Belum Terhubung ke Usaha Rental'), findsOneWidget); // Empty business selector sheet opens
    });
  });

  group('SettingsScreen List-Based Menu Tests', () {
    testWidgets('renders all categorized settings list items and logout dialog', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: StoreSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify headers and menu items
      expect(find.text('PROFIL & IDENTITAS'), findsOneWidget);
      expect(find.text('Profil Saya & Keamanan'), findsOneWidget);
      expect(find.text('Profil Usaha & Slogan'), findsOneWidget);

      expect(find.text('OPERASIONAL & PERANGKAT'), findsOneWidget);
      expect(find.text('Printer Thermal & Kasir'), findsOneWidget);
      expect(find.text('Voucher Promo & Diskon'), findsOneWidget);
      expect(find.text('Mutasi / Transfer Unit'), findsOneWidget);
      expect(find.text('Kasir & Tutup Buku Shift'), findsOneWidget);

      expect(find.text('ORGANISASI'), findsOneWidget);
      expect(find.text('Kelola Tim & Staf Cabang'), findsOneWidget);

      expect(find.text('SESI AKUN'), findsOneWidget);
      expect(find.text('Keluar Akun'), findsOneWidget);

      // Tap Keluar Akun and verify confirmation dialog appears
      await tester.tap(find.text('Keluar Akun'));
      await tester.pumpAndSettle();

      expect(find.text('Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Batal'), findsNothing);
    });
  });

  group('UserProfileScreen Google and Password Tests', () {
    testWidgets('displays Google account badge and Buat Kata Sandi when user has no password', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockGoogleAuthNotifier()),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Google Account'), findsOneWidget);
      expect(find.text('Buat Kata Sandi Akun'), findsOneWidget);
      expect(find.text('Buat Kata Sandi Sekarang'), findsOneWidget);
      expect(find.text('Kata Sandi Saat Ini *'), findsNothing); // Not required for first-time Google user!
    });

    testWidgets('displays Ubah Kata Sandi with current password field when user has existing password', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => _MockPasswordAuthNotifier()),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ubah Kata Sandi'), findsOneWidget);
      expect(find.text('Kata Sandi Saat Ini *'), findsOneWidget);
      expect(find.text('Perbarui Kata Sandi'), findsOneWidget);
    });

    testWidgets('saving personal profile triggers updateProfile and shows success message', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = _MockGoogleAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter new name
      final nameFinder = find.widgetWithText(TextFormField, 'Nama Lengkap *');
      await tester.enterText(nameFinder, 'Updated Staff Name');
      await tester.pumpAndSettle();

      // Tap Simpan Perubahan Profil
      await tester.tap(find.text('Simpan Perubahan Profil'));
      await tester.pumpAndSettle();

      expect(notifier.lastUpdatedName, 'Updated Staff Name');
      expect(find.text('Profil berhasil diperbarui.'), findsOneWidget);
    });

    testWidgets('google user creates password successfully without current password', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final notifier = _MockGoogleAuthNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(() => notifier),
          ],
          child: const MaterialApp(
            home: UserProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Enter new password and confirmation
      final newPwdFinder = find.widgetWithText(TextFormField, 'Buat Kata Sandi Baru *');
      final confirmPwdFinder = find.widgetWithText(TextFormField, 'Konfirmasi Kata Sandi Baru *');

      await tester.enterText(newPwdFinder, 'secretPass123');
      await tester.enterText(confirmPwdFinder, 'secretPass123');
      await tester.pumpAndSettle();

      // Tap Buat Kata Sandi Sekarang
      await tester.tap(find.text('Buat Kata Sandi Sekarang'));
      await tester.pumpAndSettle();

      expect(notifier.lastNewPassword, 'secretPass123');
      expect(notifier.lastCurrentPassword, isNull);
      expect(find.text('Kata sandi berhasil dibuat. Anda dapat login dengan email dan kata sandi.'), findsOneWidget);
    });
  });
}

class _MockGoogleAuthNotifier extends AuthNotifier {
  String? lastUpdatedName;
  String? lastUpdatedPhone;
  String? lastCurrentPassword;
  String? lastNewPassword;

  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: {
        'id': 'usr-google-1',
        'name': 'Google Counter Staff',
        'email': 'staff.google@rentcore.id',
        'phone': '081234567890',
        'role': 'staff',
        'google_id': 'g-sub-12345',
        'has_password': false,
      },
    );
  }

  @override
  Future<bool> updateProfile({required String name, String? phone}) async {
    lastUpdatedName = name;
    lastUpdatedPhone = phone;
    state = state.copyWith(
      user: {
        ...?state.user,
        'name': name,
        'phone': phone,
      },
    );
    return true;
  }

  @override
  Future<bool> updatePassword({
    String? currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    state = state.copyWith(
      user: {
        ...?state.user,
        'has_password': true,
      },
    );
    return true;
  }
}

class _MockPasswordAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: {
        'id': 'usr-pwd-1',
        'name': 'Local Password Staff',
        'email': 'staff.pwd@rentcore.id',
        'phone': '08987654321',
        'role': 'staff',
        'has_password': true,
      },
    );
  }
}

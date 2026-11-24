import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/presentation/user_profile_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';
import 'package:rentcore_mobile/main.dart';
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

  group('FloatingCapsuleDock 5-Slot Icon-Only Navigation Tests', () {
    testWidgets(
      'renders 4 tab icons + centered squircle + action with zero text labels and white surface',
      (tester) async {
        int selectedIndex = 0;
        bool addTapped = false;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              bottomNavigationBar: FloatingCapsuleDock(
                currentIndex: selectedIndex,
                onTabSelected: (idx) => selectedIndex = idx,
                onAddTap: () => addTapped = true,
              ),
            ),
          ),
        );

        // Verify zero text labels exist inside the bottom navigation bar
        expect(
          find.descendant(
            of: find.byType(FloatingCapsuleDock),
            matching: find.byType(Text),
          ),
          findsNothing,
        );

        // Verify 5-slot icons: active Home filled, others outlined, plus centered add button
        expect(find.byIcon(Icons.home_outlined), findsNothing);
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
        expect(find.byIcon(Icons.settings_outlined), findsOneWidget);

        // Tap index 1 (Laporan) by icon
        await tester.tap(find.byIcon(Icons.receipt_long_outlined));
        await tester.pumpAndSettle();
        expect(selectedIndex, 1);

        // Tap index 3 (Pengaturan) by icon
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(selectedIndex, 3);

        // Tap center + action button
        await tester.tap(find.byKey(const Key('nav_center_add_button')));
        await tester.pumpAndSettle();
        expect(addTapped, isTrue);
      },
    );

    testWidgets(
      'MainShellScreen switches across all 4 tabs and opens DirectRentalScreen in modal bottom sheet from any tab',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardKpiProvider.overrideWith(
                (ref) => Future.value(fakeDashboardData),
              ),
              readyAssetsProvider.overrideWith((ref) => Future.value([])),
              categoriesProvider.overrideWith((ref) => Future.value([])),
            ],
            child: const MaterialApp(
              home: MainShellScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Tab 0 (Beranda) active initially
        expect(find.byIcon(Icons.home_rounded), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);

        // Switch to Tab 1 (Laporan) and open center + bottom sheet
        await tester.tap(find.byIcon(Icons.receipt_long_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byIcon(Icons.receipt_long_rounded), findsOneWidget);

        await tester.tap(find.byKey(const Key('nav_center_add_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DraggableScrollableSheet), findsNothing);
        expect(find.byType(DirectRentalScreen), findsOneWidget);
        expect(find.text('Sewa / Booking Baru'), findsOneWidget);
        expect(find.byIcon(Icons.close_rounded), findsOneWidget);

        // Verify full-screen 100% height coverage above bottom navigation bar
        final sheetRect = tester.getRect(find.byType(DirectRentalScreen));
        final screenRect = tester.getRect(find.byType(MainShellScreen));
        expect(sheetRect.height, closeTo(screenRect.height, 1.0));

        // Dismiss sheet cleanly via the close (X) button
        await tester.tap(find.byKey(const Key('new_booking_modal_close_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DirectRentalScreen), findsNothing);

        await tester.tap(find.byIcon(Icons.inventory_2_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byIcon(Icons.inventory_2_rounded), findsOneWidget);

        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

        // Open center + bottom sheet from Tab 3 (Pengaturan) and verify downward swipe does NOT dismiss
        await tester.tap(find.byKey(const Key('nav_center_add_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DirectRentalScreen), findsOneWidget);
        await tester.fling(
          find.text('Sewa / Booking Baru'),
          const Offset(0, 600),
          1200,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DirectRentalScreen), findsOneWidget);

        await tester.tap(find.byKey(const Key('new_booking_modal_close_button')));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(DirectRentalScreen), findsNothing);
      },
    );
  });

  group('HomeScreen Header & Quick Actions Cleanup Tests', () {
    testWidgets(
      'removes duplicate Sewa Baru FAB, uses bottom: 24 scroll padding, and removes Return/Inventory shortcuts',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardKpiProvider.overrideWith(
                (ref) => Future.value(fakeDashboardData),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: HomeScreen(
                  onNavigateTab: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Duplicate '+ Sewa Baru' FAB is removed from Dashboard
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Sewa Baru'), findsNothing);

        // Scroll padding uses bottom: 24
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView).first,
        );
        expect((scrollView.padding! as EdgeInsets).bottom, 24.0);

        // 2. Legacy Return & Inventory quick action shortcuts are removed from the dashboard body
        expect(find.byIcon(Icons.assignment_return_outlined), findsNothing);
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
        expect(
          find.text('Belum Terhubung ke Usaha Rental'),
          findsOneWidget,
        ); // Empty business selector sheet opens
      },
    );

    testWidgets(
      'Threads-style header exposes left menu sheet, notification bell navigation, and no header search icon',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dashboardKpiProvider.overrideWith(
                (ref) => Future.value(fakeDashboardData),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: HomeScreen(onNavigateTab: (_) {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Header search icon & legacy expandable header search are removed
        expect(find.byKey(const Key('home_header_search_button')), findsNothing);
        expect(
          find.text('Cari kode booking, penyewa, atau no. telp...'),
          findsNothing,
        );

        // Search input is embedded directly in Antrean Sewa Cabang
        expect(find.byKey(const Key('home_queue_search_field')), findsOneWidget);
        expect(
          find.text('Cari kode booking, penyewa, atau unit...'),
          findsOneWidget,
        );

        // Tap left two-line menu button -> opens account drawer
        await tester.tap(find.byKey(const Key('home_header_menu_button')));
        await tester.pumpAndSettle();
        expect(find.text('Kasir'), findsNWidgets(2));
        expect(find.text('Ganti Usaha / Cabang'), findsOneWidget);
        expect(find.text('Profil Pengguna'), findsOneWidget);
        expect(find.text('Keluar Akun'), findsOneWidget);

        // Close menu sheet
        Navigator.of(tester.element(find.text('Keluar Akun'))).pop();
        await tester.pumpAndSettle();

        // Tap notification bell -> opens NotificationCenterScreen
        await tester.tap(find.byTooltip('Pusat Pemberitahuan'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        expect(find.text('Notifikasi'), findsOneWidget);
      },
    );
  });

  group('SettingsScreen List-Based Menu Tests', () {
    testWidgets(
      'renders all categorized settings list items and logout dialog',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          const ProviderScope(child: MaterialApp(home: StoreSettingsScreen())),
        );
        await tester.pumpAndSettle();

        // Verify headers and menu items
        expect(find.text('AKUN & TOKO'), findsOneWidget);
        expect(find.text('Profil Pengguna'), findsOneWidget);
        expect(find.text('Profil Usaha & Cabang'), findsOneWidget);

        expect(find.text('OPERASIONAL KASIR'), findsOneWidget);
        expect(find.text('Metode Pembayaran'), findsOneWidget);
        expect(find.text('Jam Operasional Shift'), findsOneWidget);
        expect(find.text('Kasir & Tutup Buku Shift'), findsNothing);
        expect(find.text('Voucher & Promo'), findsOneWidget);
        expect(find.text('Printer Thermal'), findsOneWidget);

        expect(find.text('INVENTARIS & PELANGGAN'), findsOneWidget);
        expect(find.text('Direktori Pelanggan & Blacklist'), findsOneWidget);
        expect(find.text('Mutasi Unit'), findsOneWidget);
        expect(find.text('Kelola Tim & Staf'), findsOneWidget);

        expect(find.text('Ganti Usaha / Cabang'), findsOneWidget);
        expect(find.text('Keluar Akun'), findsOneWidget);

        // Tap Keluar Akun and verify confirmation dialog appears
        await tester.tap(find.text('Keluar Akun'));
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.',
          ),
          findsOneWidget,
        );
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Keluar'), findsOneWidget);

        // Cancel dialog
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.text('Batal'), findsNothing);
      },
    );
  });

  group('UserProfileScreen Google and Password Tests', () {
    testWidgets(
      'displays Google account badge and Buat Kata Sandi when user has no password',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _MockGoogleAuthNotifier()),
            ],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Google Account'), findsOneWidget);
        expect(find.text('Buat Kata Sandi Akun'), findsOneWidget);
        expect(find.text('Buat Kata Sandi Sekarang'), findsOneWidget);
        expect(
          find.text('Kata Sandi Saat Ini *'),
          findsNothing,
        ); // Not required for first-time Google user!
      },
    );

    testWidgets(
      'displays Ubah Kata Sandi with current password field when user has existing password',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(() => _MockPasswordAuthNotifier()),
            ],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Ubah Kata Sandi'), findsOneWidget);
        expect(find.text('Kata Sandi Saat Ini *'), findsOneWidget);
        expect(find.text('Perbarui Kata Sandi'), findsOneWidget);
      },
    );

    testWidgets(
      'saving personal profile triggers updateProfile and shows success message',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final notifier = _MockGoogleAuthNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => notifier)],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Enter new name
        final nameFinder = find.byKey(const Key('profile_name_field'));
        await tester.enterText(nameFinder, 'Updated Staff Name');
        await tester.pumpAndSettle();

        // Tap Simpan Perubahan Profil
        await tester.tap(find.text('Simpan Perubahan Profil'));
        await tester.pumpAndSettle();

        expect(notifier.lastUpdatedName, 'Updated Staff Name');
        expect(find.text('Profil berhasil diperbarui.'), findsOneWidget);
      },
    );

    testWidgets(
      'google user creates password successfully without current password',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        final notifier = _MockGoogleAuthNotifier();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [authProvider.overrideWith(() => notifier)],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        // Enter new password and confirmation
        final newPwdFinder = find.byKey(const Key('profile_new_password_field'));
        final confirmPwdFinder = find.byKey(
          const Key('profile_confirm_password_field'),
        );

        await tester.enterText(newPwdFinder, 'secretPass123');
        await tester.enterText(confirmPwdFinder, 'secretPass123');
        await tester.pumpAndSettle();

        // Tap Buat Kata Sandi Sekarang
        await tester.tap(find.text('Buat Kata Sandi Sekarang'));
        await tester.pumpAndSettle();

        expect(notifier.lastNewPassword, 'secretPass123');
        expect(notifier.lastCurrentPassword, isNull);
        expect(
          find.text(
            'Kata sandi berhasil dibuat. Anda dapat login dengan email dan kata sandi.',
          ),
          findsOneWidget,
        );
      },
    );
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
      user: {...?state.user, 'name': name, 'phone': phone},
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
    state = state.copyWith(user: {...?state.user, 'has_password': true});
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

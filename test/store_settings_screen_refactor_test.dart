import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/presentation/user_profile_screen.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/customers/presentation/customer_directory_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/manage_organization_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/shift_schedule_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_profile_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';
import 'package:rentcore_mobile/features/printer/presentation/printer_settings_screen.dart';
import 'package:rentcore_mobile/features/transfers/presentation/transfers_screen.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_screen.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _MockAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _MockBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _MockBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSettingsWidget({String role = 'owner'}) {
    return ProviderScope(
      overrides: [
        authProvider.overrideWith(
          () => _MockAuthNotifier(
            AuthState(
              user: {
                'id': 'usr-1',
                'name': 'Hadi Pratama',
                'email': 'hadi@rentcore.id',
                'role': role,
              },
              isAuthenticated: true,
            ),
          ),
        ),
        businessProvider.overrideWith(
          () => _MockBusinessNotifier(
            BusinessState(
              activeBusinessId: 1,
              activeBusinessName: 'RentCore Pusat',
              businesses: [
                {'id': 1, 'name': 'RentCore Pusat', 'role': role},
              ],
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: StoreSettingsScreen()),
    );
  }

  group('StoreSettingsScreen Refactor Layout & Typography Tests', () {
    testWidgets('renders all 4 groups with polished subtitles and chevrons', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      // 1. Group 1: AKUN & TOKO
      expect(find.text('AKUN & TOKO'), findsOneWidget);
      expect(find.text('Profil Pengguna'), findsOneWidget);
      expect(find.text('Keamanan & data pribadi'), findsOneWidget);
      expect(find.text('Profil Usaha & Cabang'), findsOneWidget);
      expect(find.text('RentCore Pusat'), findsWidgets);

      // 2. Group 2: OPERASIONAL KASIR
      expect(find.text('OPERASIONAL KASIR'), findsOneWidget);
      expect(find.text('Metode Pembayaran'), findsOneWidget);
      expect(find.text('QRIS, Tunai, Bank & E-Wallet'), findsOneWidget);
      expect(find.text('Jam Operasional Shift'), findsOneWidget);
      expect(find.text('Atur jam buka, tutup & toleransi cabang'), findsOneWidget);
      expect(find.text('Shift Kasir & Jam Operasional'), findsNothing);
      expect(find.text('Kasir & Tutup Buku Shift'), findsNothing);
      expect(find.text('Voucher & Promo'), findsOneWidget);
      expect(find.text('Manajemen diskon & voucher sewa'), findsOneWidget);
      expect(find.text('Printer Thermal'), findsOneWidget);
      expect(find.text('Koneksi Bluetooth ESC/POS'), findsOneWidget);

      // 3. Group 3: INVENTARIS & PELANGGAN
      expect(find.text('INVENTARIS & PELANGGAN'), findsOneWidget);
      expect(find.text('Direktori Pelanggan & Blacklist'), findsOneWidget);
      expect(find.text('Data pelanggan & verifikasi KTP'), findsOneWidget);
      expect(find.text('Mutasi Unit'), findsOneWidget);
      expect(find.text('Transfer unit antar-cabang'), findsOneWidget);
      expect(find.text('Kelola Tim & Staf Cabang'), findsOneWidget);
      expect(find.text('Anggota tim & hak akses'), findsOneWidget);

      // 4. Group 4: SESI AKUN
      expect(find.text('SESI AKUN'), findsOneWidget);
      expect(find.text('Keluar Akun'), findsOneWidget);
      expect(find.text('Akhiri sesi pada perangkat ini'), findsOneWidget);

      // 5. Verify chevron icons are used
      expect(find.byIcon(Icons.chevron_right), findsWidgets);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsNothing);

      // 6. Verify ListView has bottom padding 100 for safe area
      final listViewFinder = find.byType(ListView);
      expect(listViewFinder, findsOneWidget);
      final listView = tester.widget<ListView>(listViewFinder);
      expect(
        listView.padding,
        const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
      );
    });

    testWidgets(
      'renders properly without RenderFlex overflow on small 320px screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('AKUN & TOKO'), findsOneWidget);
        expect(find.text('OPERASIONAL KASIR'), findsOneWidget);
      },
    );

    testWidgets(
      'does not render redundant Cashier & Shift or Revenue Report links in Settings',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        expect(find.text('Kasir & Tutup Buku Shift'), findsNothing);
        expect(find.text('Shift Kasir & Jam Operasional'), findsNothing);
        expect(find.text('Laporan Pendapatan'), findsNothing);
        expect(find.text('Jam Operasional Shift'), findsOneWidget);
      },
    );

    testWidgets('tapping Keluar Akun opens confirmation dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

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

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.text('Batal'), findsNothing);
    });
  });

  group('StoreSettingsScreen Navigation Targets Verification Tests', () {
    testWidgets('navigates to UserProfileScreen when tapping Profil Pengguna', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profil Pengguna'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(UserProfileScreen), findsOneWidget);
    });

    testWidgets(
      'navigates to StoreProfileScreen when tapping Profil Usaha & Cabang',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Profil Usaha & Cabang'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(StoreProfileScreen), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to PaymentMethodSettingsScreen when tapping Metode Pembayaran',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Metode Pembayaran'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(PaymentMethodSettingsScreen), findsOneWidget);
      },
    );

    testWidgets('navigates to VoucherScreen when tapping Voucher & Promo', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voucher & Promo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(VoucherScreen), findsOneWidget);
    });

    testWidgets(
      'navigates to PrinterSettingsScreen when tapping Printer Thermal',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Printer Thermal'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(PrinterSettingsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'navigates to CustomerDirectoryScreen when tapping Direktori Pelanggan & Blacklist',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Direktori Pelanggan & Blacklist'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(CustomerDirectoryScreen), findsOneWidget);
      },
    );

    testWidgets('navigates to TransfersScreen when tapping Mutasi Unit', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mutasi Unit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(TransfersScreen), findsOneWidget);
    });

    testWidgets(
      'navigates to ManageOrganizationScreen when tapping Kelola Tim & Staf Cabang',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kelola Tim & Staf Cabang'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.byType(ManageOrganizationScreen), findsOneWidget);
      },
    );

    testWidgets('navigates directly to ShiftScheduleScreen from Jam Operasional Shift', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Jam Operasional Shift'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(ShiftScheduleScreen), findsOneWidget);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sewakasir/features/auth/presentation/user_profile_screen.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/customers/presentation/customer_directory_screen.dart';
import 'package:sewakasir/features/organization/presentation/manage_organization_screen.dart';
import 'package:sewakasir/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:sewakasir/features/organization/presentation/shift_schedule_screen.dart';
import 'package:sewakasir/features/organization/presentation/store_profile_screen.dart';
import 'package:sewakasir/features/organization/presentation/store_settings_screen.dart';
import 'package:sewakasir/features/printer/presentation/printer_settings_screen.dart';
import 'package:sewakasir/features/transfers/presentation/transfers_screen.dart';
import 'package:sewakasir/features/vouchers/presentation/voucher_screen.dart';
import 'package:sewakasir/shared/widgets/business_selector_sheet.dart';

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

  @override
  Future<void> refreshSilently() async {}
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
              activeBranchId: 10,
              activeBranchName: 'Cabang Utama',
              businesses: [
                {
                  'id': 1,
                  'name': 'RentCore Pusat',
                  'role': role,
                  'branches': [
                    {'id': 10, 'name': 'Cabang Utama', 'is_central': true},
                  ],
                },
              ],
            ),
          ),
        ),
      ],
      child: const MaterialApp(home: StoreSettingsScreen()),
    );
  }

  group('StoreSettingsScreen Airy Minimalist Layout & Typography Tests', () {
    testWidgets('renders pure white borderless list, bare icons, compact header, and clean titles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      // White canvas & minimalist header
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

      final headerText = tester.widget<Text>(find.text('Pengaturan'));
      expect(headerText.style?.fontSize, 22);
      expect(headerText.style?.fontWeight, FontWeight.w700);
      expect(headerText.style?.color, const Color(0xFF0F172A));

      // Top account & active store header
      expect(find.byKey(const Key('settings_account_header')), findsOneWidget);
      expect(find.text('Hadi Pratama'), findsOneWidget);
      expect(find.text('hadi@rentcore.id • Owner'), findsOneWidget);
      expect(find.text('RentCore Pusat • Cabang Utama'), findsOneWidget);

      // Section headers & untrimmed single-line titles
      expect(find.text('AKUN & TOKO'), findsOneWidget);
      expect(find.text('Profil Pengguna'), findsOneWidget);
      expect(find.text('Profil Usaha & Cabang'), findsOneWidget);

      expect(find.text('OPERASIONAL KASIR'), findsOneWidget);
      expect(find.text('Metode Pembayaran'), findsOneWidget);
      expect(find.text('QRIS, Tunai, Bank & E-Wallet'), findsOneWidget);
      expect(find.text('Jam Operasional Shift'), findsOneWidget);
      expect(find.text('Kebijakan Booking & No-Show'), findsOneWidget);
      expect(find.text('Aturan Denda Keterlambatan'), findsOneWidget);
      expect(find.text('Voucher & Promo'), findsOneWidget);
      expect(find.text('Printer Thermal'), findsOneWidget);

      expect(find.text('INVENTARIS & PELANGGAN'), findsOneWidget);
      expect(find.text('Direktori Pelanggan & Blacklist'), findsOneWidget);
      expect(find.text('Mutasi Unit'), findsOneWidget);
      expect(find.text('Kelola Tim & Staf'), findsOneWidget);

      expect(find.text('PRIVASI & LEGAL'), findsOneWidget);
      expect(find.text('Kebijakan Privasi'), findsOneWidget);
      expect(find.text('Hapus Akun'), findsOneWidget);

      // Inline policy cards were moved out of main scroll body into progressive sub-sheets
      expect(find.byKey(const Key('late_pickup_policy_card')), findsNothing);
      expect(find.byKey(const Key('late_fee_policy_card')), findsNothing);

      // Clean footer actions
      expect(find.text('Ganti Usaha / Cabang'), findsOneWidget);
      expect(find.text('Keluar Akun'), findsOneWidget);
      expect(find.text('SewaKasir • Versi 1.0.0+1'), findsOneWidget);

      // Chevrons & ListView clearance
      expect(find.byIcon(Icons.chevron_right_rounded), findsWidgets);
      final listView = tester.widget<ListView>(find.byType(ListView));
      expect(listView.padding, const EdgeInsets.only(top: 4, bottom: 100));
    });

    testWidgets('staff role renders muted caption text instead of yellow pills and single-line Status Kepegawaian', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget(role: 'staff'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('hadi@rentcore.id • Staff'), findsOneWidget);
      expect(find.text('Status Kepegawaian'), findsOneWidget);
      expect(find.text('Kebijakan Booking & No-Show'), findsOneWidget);
      expect(find.text('Lihat saja'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Kelola Tim & Staf'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Kelola Tim & Staf'), findsOneWidget);
      expect(find.text('Owner / Admin'), findsOneWidget);
      // Old loud pills removed
      expect(find.text('Lihat Saja'), findsNothing);
      expect(find.text('Kepegawaian'), findsNothing);
    });

    testWidgets(
      'renders properly without RenderFlex overflow on small 320px screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget(role: 'staff'));
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

    testWidgets('tapping footer Ganti Usaha / Cabang opens BusinessSelectorSheet', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('footer_switch_business_button')));
      await tester.pumpAndSettle();

      expect(find.byType(BusinessSelectorSheet), findsOneWidget);
    });

    testWidgets('tapping Keluar Akun opens confirmation dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildSettingsWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('footer_logout_button')));
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

  group('StoreSettingsScreen Navigation Targets & Sub-Sheets Tests', () {
    testWidgets('navigates to UserProfileScreen from account header and Profil Pengguna', (
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
      'navigates to ManageOrganizationScreen when tapping Kelola Tim & Staf',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildSettingsWidget());
        await tester.pumpAndSettle();

        await tester.tap(find.text('Kelola Tim & Staf'));
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

  group('Airy Minimalist Settings Sub-Screen Design Tokens', () {
    testWidgets(
      'UserProfileScreen uses pure #FFFFFF canvas and Obsidian #0F172A primary CTA for password creation',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  AuthState(
                    user: {
                      'id': 'usr-g1',
                      'name': 'Dina',
                      'email': 'dina@rentcore.id',
                      'role': 'owner',
                      'has_password': false,
                      'auth_provider': 'google',
                    },
                    isAuthenticated: true,
                  ),
                ),
              ),
              businessProvider.overrideWith(
                () => _MockBusinessNotifier(
                  const BusinessState(activeBusinessId: 1),
                ),
              ),
            ],
            child: const MaterialApp(home: UserProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));

        final createPwdBtn = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Buat Kata Sandi Sekarang'),
        );
        final bg = createPwdBtn.style?.backgroundColor?.resolve({});
        expect(bg, const Color(0xFF0F172A));
      },
    );

    testWidgets(
      'StoreProfileScreen renders #FFFFFF canvas, uppercase header, and sticky Simpan Profil Toko CTA',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authProvider.overrideWith(
                () => _MockAuthNotifier(
                  AuthState(
                    user: {'id': 'usr-1', 'name': 'Hadi', 'role': 'owner'},
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
                      {
                        'id': 1,
                        'name': 'RentCore Pusat',
                        'role': 'owner',
                      },
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: StoreProfileScreen()),
          ),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
        expect(scaffold.backgroundColor, const Color(0xFFFFFFFF));
        expect(find.text('IDENTITAS TOKO & HEADER STRUK'), findsOneWidget);
        expect(find.text('Simpan Profil Toko'), findsOneWidget);
      },
    );
  });
}

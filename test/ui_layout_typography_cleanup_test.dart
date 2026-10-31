import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/presentation/pos_transaction_detail_sheet.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/data/dashboard_repository.dart';
import 'package:rentcore_mobile/features/home/presentation/home_screen.dart';
import 'package:rentcore_mobile/features/home/providers/dashboard_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';
import 'package:rentcore_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_form_dialog.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_screen.dart';
import 'package:rentcore_mobile/features/vouchers/providers/voucher_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVoucherRepo extends VoucherRepository {
  final List<Map<String, dynamic>> mockVouchers;
  _MockVoucherRepo(this.mockVouchers);

  @override
  Future<List<Map<String, dynamic>>> fetchVouchers({String? status, String? search, dynamic branchId}) async {
    return mockVouchers;
  }
}

class _MockDashboardRepo extends DashboardRepository {
  final List<dynamic> alerts;
  _MockDashboardRepo(this.alerts);

  @override
  Future<Map<String, dynamic>> fetchKpi({int? branchId}) async {
    return {
      'branch_id': branchId,
      'is_consolidated': true,
      'kpi': {
        'units_total': 10,
        'units_ready': 9,
        'units_rented': 1,
        'units_maintenance': 0,
        'units_in_transit': 0,
        'utilization_rate': 10.0,
        'active_rentals': 1,
        'due_today': 1,
        'overdue': 1,
        'today_rentals_created': 1,
        'today_revenue': 50000.0,
        'today_transactions_count': 1,
      },
      'overdue_alerts': alerts,
      'imminent_returns': [],
    };
  }
}

class _FixedBusinessNotifier extends BusinessNotifier {
  @override
  BusinessState build() {
    return const BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'RentCore Store',
      activeBranchId: 1,
      activeBranchName: 'Cabang Utama',
      businesses: [
        {
          'id': 1,
          'name': 'RentCore Store',
          'role': 'owner',
          'branches': [
            {'id': 1, 'name': 'Cabang Utama', 'code': 'CBU'},
          ],
        }
      ],
    );
  }
}

class _FixedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() {
    return const AuthState(
      isAuthenticated: true,
      user: {
        'id': 1,
        'name': 'Owner Test',
        'role': 'owner',
        'is_platform_admin': false,
      },
    );
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
    SharedPreferences.setMockInitialValues({});
  });

  group('UI Layout, Typography & Clutter Cleanup Tests', () {
    testWidgets('1. VoucherFormDialog eliminates prefix icons and renders clean labels & barcode options', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(_MockVoucherRepo([])),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const Scaffold(
              body: VoucherFormDialog(
                branches: [
                  {'id': 1, 'name': 'Cabang Utama', 'code': 'CBU'}
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check clean header text without decorative icon
      expect(find.text('Buat Voucher Promo Baru'), findsOneWidget);
      expect(find.byIcon(Icons.confirmation_number_outlined), findsNothing);

      // Check clean labels
      expect(find.text('Kode Voucher *'), findsOneWidget);
      expect(find.text('Nama Voucher *'), findsOneWidget);
      expect(find.text('Diskon (%) *'), findsOneWidget);
      expect(find.text('Minimal Transaksi *'), findsOneWidget);
      expect(find.text('Kuota'), findsOneWidget);
      expect(find.text('Format Barcode *'), findsOneWidget);

      // Check eliminated prefix icons
      expect(find.byIcon(Icons.tag_rounded), findsNothing);
      expect(find.byIcon(Icons.badge_outlined), findsNothing);
      expect(find.byIcon(Icons.notes_rounded), findsNothing);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
      expect(find.byIcon(Icons.people_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.qr_code_2_rounded), findsNothing);

      // Check simplified barcode dropdown options
      expect(find.text('QR Code'), findsOneWidget);
    });

    testWidgets('2. VoucherScreen on narrow 320px screen renders full title and no RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320, 568); // Narrow mobile screen (iPhone SE 1st gen)
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final vouchers = [
        {
          'id': 101,
          'code': 'RC-VCR-EXTRA-LONG-8921',
          'name': 'Promo Super Hemat Weekend 20%',
          'description': 'Diskon spesial untuk unit smartphone.',
          'discount_percentage': 20.0,
          'min_transaction_amount': 250000.0,
          'max_discount_cap': 50000.0,
          'barcode_type': 'qr_code',
          'start_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
          'end_at': DateTime.now().add(const Duration(days: 20)).toIso8601String(),
          'usage_limit_total': 100,
          'usage_limit_per_customer': 1,
          'usage_count': 5,
          'is_active': true,
          'affiliate_id': null,
          'affiliate': null,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(_MockVoucherRepo(vouchers)),
            businessProvider.overrideWith(() => _FixedBusinessNotifier()),
            authProvider.overrideWith(() => _FixedAuthNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const VoucherScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify AppBar title is full text
      expect(find.text('Voucher Promo'), findsOneWidget);
      // Verify redundant header button is removed
      expect(find.byKey(const Key('create_voucher_header_button')), findsNothing);

      // Verify card content without overflow
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.text('Semua Cabang'), findsOneWidget);
      expect(find.text('RC-VCR-EXTRA-LONG-8921'), findsOneWidget);
      expect(find.text('Cetak Slip'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsNothing);
    });

    testWidgets('3. PosTransactionDetailSheet renders simplified titles, QRIS badge, formatted date, and Sisa Tagihan', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final bookingData = {
        'id': 201,
        'booking_code': 'RC-261031-0001',
        'status': 'rented',
        'payment_status': 'paid',
        'total_bill': '150000.00',
        'subtotal_amount': '150000.00',
        'discount_amount': '0.00',
        'start_at': '2026-10-31T08:00:00.000000Z',
        'end_at': '2026-11-01T08:00:00.000000Z',
        'customer': {
          'name': 'Fauzi Ramadhan',
          'phone': '08123456789',
        },
        'creator': {
          'name': 'Budi Kasir',
        },
        'items': [
          {
            'status': 'active',
            'asset': {
              'serial_number': 'SN-IP15-001',
              'imei_1': '351234567890123',
              'model': {'name': 'iPhone 15 128GB Black'},
            },
          },
        ],
        'payments': [
          {
            'id': 1,
            'type': 'settlement',
            'amount': '150000.00',
            'payment_method': 'QRIS Dinamis / Statis',
            'transacted_at': '2026-10-31T07:58:49.000000Z',
            'processor': {'name': 'Budi Kasir'},
          },
        ],
      };

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingDetailProvider(201).overrideWith((ref) => Future.value(bookingData)),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: PosTransactionDetailSheet(booking: bookingData),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header without POS monitor icon
      expect(find.text('Rincian Transaksi'), findsOneWidget);
      expect(find.byIcon(Icons.inventory_2_outlined), findsNothing);

      // Verify Customer & Staff rendered without avatar prefix icons
      expect(find.text('Fauzi Ramadhan'), findsOneWidget);
      expect(find.text('Petugas/Kasir: Budi Kasir'), findsOneWidget);
      expect(find.byIcon(Icons.person_outline_rounded), findsNothing);
      expect(find.byIcon(Icons.badge_outlined), findsNothing);

      // Verify Sisa Tagihan
      expect(find.text('Sisa Tagihan'), findsOneWidget);

      // Verify Riwayat Pembayaran & Simplified QRIS badge
      expect(find.text('Riwayat Pembayaran'), findsOneWidget);
      expect(find.textContaining('QRIS • Sewa Kontrak'), findsOneWidget);

      // Verify Formatted Date: 31 Okt 2026, 07:58 (instead of raw ISO string)
      expect(find.textContaining('31 Okt 2026, 07:58'), findsOneWidget);
    });

    testWidgets('4. PaymentMethodSettingsScreen eliminates icons preceding headers and updates copywriting', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessProvider.overrideWith(() => _FixedBusinessNotifier()),
            authProvider.overrideWith(() => _FixedAuthNotifier()),
            paymentSettingsProvider(null).overrideWith((ref) => Future.value({
                  'config': {
                    'ewallet_enabled': true,
                    'ewallet_providers': {
                      'shopeepay': true,
                      'dana': true,
                      'linkaja': true,
                      'ovo': true,
                    },
                    'qris_statis_enabled': true,
                    'cash_enabled': true,
                    'bank_transfer_enabled': true,
                  }
                })),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const PaymentMethodSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify QRIS Statis title exists without preceding QR icon
      expect(find.text('QRIS Statis'), findsOneWidget);

      // Verify Dompet Digital (E-Wallet) exists without preceding wallet icon
      expect(find.text('Dompet Digital (E-Wallet)'), findsOneWidget);
      expect(find.byIcon(Icons.account_balance_wallet_rounded), findsNothing);

      // Verify simplified e-wallet master toggle subtitle
      expect(find.text('Aktifkan semua e-wallet'), findsOneWidget);
      expect(find.text('Master toggle untuk seluruh penyedia E-Wallet'), findsNothing);

      // Verify Tunai di Meja Kasir (CASH) does NOT show descriptive subtext
      expect(find.text('Tunai di Meja Kasir (CASH)'), findsOneWidget);
      expect(find.text('Penerimaan uang kertas dan koin fisik di laci kasir'), findsNothing);
    });

    testWidgets('5. Overdue Alert Banner renders 1 Unit Terlambat • Lihat Semua without 17px overflow on 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 568); // Narrow 320px screen
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final alerts = [
        {
          'booking_id': 101,
          'customer_name': 'Alexander Maximillian',
          'unit_name': 'iPhone 15 Pro Max',
          'late_duration_text': '2 Jam 30 Menit',
          'running_penalty': 50000.0,
        },
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(_MockDashboardRepo(alerts)),
            businessProvider.overrideWith(() => _FixedBusinessNotifier()),
            authProvider.overrideWith(() => _FixedAuthNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: HomeScreen(
              onNavigateTab: (_) {},
              onOpenDirectRental: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify formatted overdue alert line
      expect(find.text('1 Unit Terlambat'), findsOneWidget);
      expect(find.textContaining('Lihat Semua'), findsOneWidget);
      expect(find.text('PERINGATAN KETERLAMBATAN (1 UNIT)'), findsNothing);
    });
  });
}

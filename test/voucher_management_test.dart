import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/theme/app_theme.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/organization/providers/organization_provider.dart';
import 'package:rentcore_mobile/features/vouchers/data/voucher_repository.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_detail_dialog.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_form_dialog.dart';
import 'package:rentcore_mobile/features/vouchers/presentation/voucher_screen.dart';
import 'package:rentcore_mobile/features/vouchers/providers/voucher_provider.dart';

class MockVoucherRepository extends VoucherRepository {
  List<Map<String, dynamic>> mockVouchers = [];
  Map<String, dynamic>? lastCreatedPayload;
  Map<String, dynamic>? lastUpdatedPayload;
  int? lastToggledId;
  int? lastDeletedId;

  @override
  Future<List<Map<String, dynamic>>> fetchVouchers({
    String? status,
    String? search,
    dynamic branchId,
  }) async {
    var result = List<Map<String, dynamic>>.from(mockVouchers);
    if (status != null && status != 'all') {
      if (status == 'active') {
        result = result.where((v) => v['is_active'] == true).toList();
      } else if (status == 'inactive') {
        result = result.where((v) => v['is_active'] == false).toList();
      }
    }
    if (search != null && search.isNotEmpty) {
      result = result
          .where((v) =>
              (v['code'] ?? '').toString().toLowerCase().contains(search.toLowerCase()) ||
              (v['name'] ?? '').toString().toLowerCase().contains(search.toLowerCase()))
          .toList();
    }
    if (branchId != null) {
      result = result.where((v) => v['affiliate_id']?.toString() == branchId.toString()).toList();
    }
    return result;
  }

  @override
  Future<Map<String, dynamic>> createVoucher(Map<String, dynamic> payload) async {
    lastCreatedPayload = payload;
    final newV = Map<String, dynamic>.from(payload);
    newV['id'] = 99;
    newV['usage_count'] = 0;
    mockVouchers.add(newV);
    return newV;
  }

  @override
  Future<Map<String, dynamic>> updateVoucher(int id, Map<String, dynamic> payload) async {
    lastUpdatedPayload = payload;
    final index = mockVouchers.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      mockVouchers[index] = {...mockVouchers[index], ...payload};
      return mockVouchers[index];
    }
    return payload;
  }

  @override
  Future<Map<String, dynamic>> toggleVoucherStatus(int id) async {
    lastToggledId = id;
    final index = mockVouchers.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      mockVouchers[index]['is_active'] = !(mockVouchers[index]['is_active'] == true);
      return mockVouchers[index];
    }
    return {'is_active': false};
  }

  @override
  Future<void> deleteVoucher(int id) async {
    lastDeletedId = id;
    mockVouchers.removeWhere((v) => v['id'] == id);
  }

  @override
  Future<Map<String, dynamic>> validateVoucher(
    String code,
    double subtotal, {
    dynamic branchId,
    int? customerId,
  }) async {
    final v = mockVouchers.where((item) => item['code'] == code).firstOrNull;
    if (v == null) {
      throw Exception('Kode voucher tidak ditemukan.');
    }
    final discount = subtotal * ((v['discount_percentage'] as num) / 100);
    return {
      'valid': true,
      'code': code,
      'discount_percentage': v['discount_percentage'],
      'calculated_discount': discount,
      'final_payable': subtotal - discount,
    };
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  late MockVoucherRepository mockRepo;

  setUp(() {
    mockRepo = MockVoucherRepository();
    mockRepo.mockVouchers = [
      {
        'id': 1,
        'code': 'RC-VCR-15',
        'name': 'Promo Pelanggan Baru 15%',
        'description': 'Diskon khusus counter rental.',
        'discount_percentage': 15.0,
        'min_transaction_amount': 300000.0,
        'max_discount_cap': 100000.0,
        'barcode_type': 'qr_code',
        'start_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'end_at': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'usage_limit_total': 100,
        'usage_limit_per_customer': 1,
        'usage_count': 12,
        'is_active': true,
        'affiliate_id': null,
        'affiliate': null,
      },
      {
        'id': 2,
        'code': 'RC-GNT-20',
        'name': 'Promo Genteng Central 20%',
        'description': 'Eksklusif cabang Genteng.',
        'discount_percentage': 20.0,
        'min_transaction_amount': 500000.0,
        'barcode_type': 'qr_code',
        'start_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'end_at': DateTime.now().add(const Duration(days: 15)).toIso8601String(),
        'usage_limit_total': 50,
        'usage_limit_per_customer': 2,
        'usage_count': 0,
        'is_active': false,
        'affiliate_id': 10,
        'affiliate': {'id': 10, 'name': 'Genteng Central Hub', 'code': 'GNT'},
      },
    ];
  });

  group('Voucher State & Provider Tests', () {
    test('VoucherState copyWith maintains state integrity', () {
      const state = VoucherState(
        isLoading: false,
        statusFilter: 'all',
        searchQuery: '',
      );

      final updated = state.copyWith(
        isLoading: true,
        statusFilter: 'active',
        searchQuery: 'PROMO',
      );

      expect(updated.isLoading, isTrue);
      expect(updated.statusFilter, 'active');
      expect(updated.searchQuery, 'PROMO');
    });

    test('VoucherNotifier loads vouchers and supports status filters', () async {
      final container = ProviderContainer(
        overrides: [
          voucherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voucherProvider.notifier);
      await notifier.loadVouchers();

      expect(container.read(voucherProvider).vouchers.length, 2);

      notifier.setStatusFilter('active');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(voucherProvider).vouchers.length, 1);
      expect(container.read(voucherProvider).vouchers.first['code'], 'RC-VCR-15');

      notifier.setStatusFilter('inactive');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(container.read(voucherProvider).vouchers.length, 1);
      expect(container.read(voucherProvider).vouchers.first['code'], 'RC-GNT-20');
    });

    test('VoucherNotifier creates, toggles status, and deletes voucher', () async {
      final container = ProviderContainer(
        overrides: [
          voucherRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(voucherProvider.notifier);
      await notifier.loadVouchers();

      // Create
      final success = await notifier.createVoucher({
        'code': 'NEW-PROMO',
        'name': 'New Promo 25%',
        'discount_percentage': 25.0,
        'min_transaction_amount': 200000.0,
        'start_at': DateTime.now().toIso8601String(),
        'end_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
      });
      expect(success, isTrue);
      expect(mockRepo.lastCreatedPayload?['code'], 'NEW-PROMO');

      // Toggle
      await notifier.toggleStatus(1);
      expect(mockRepo.lastToggledId, 1);

      // Delete
      await notifier.deleteVoucher(2);
      expect(mockRepo.lastDeletedId, 2);
    });
  });

  group('VoucherScreen UI & Owner Governance Tests', () {
    testWidgets('Owner sees + Buat Voucher FAB, filter chips, and voucher cards', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(mockRepo),
            authProvider.overrideWith(() => MockAuthNotifier(isOwner: true)),
            businessProvider.overrideWith(() => MockBusinessNotifier(isOwner: true)),
            organizationProvider.overrideWith(() => MockOrganizationNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const VoucherScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title & filter chips
      expect(find.text('Voucher & Barcode 2D'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Semua'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Aktif'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Nonaktif'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Kedaluwarsa'), findsOneWidget);

      // Verify Owner Header Button & FAB are present
      expect(find.byKey(const Key('create_voucher_header_button')), findsOneWidget);
      expect(find.byKey(const Key('create_voucher_fab')), findsOneWidget);

      // Verify Voucher Card content
      expect(find.text('15% OFF'), findsOneWidget);
      expect(find.text('Promo Pelanggan Baru 15%'), findsOneWidget);
      expect(find.text('Semua Cabang'), findsOneWidget);
      expect(find.text('RC-VCR-15'), findsOneWidget);
      expect(find.text('Cetak Slip'), findsNWidgets(2));
    });

    testWidgets('Staff sees read-only screen without Buat Voucher FAB or edit controls', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(mockRepo),
            authProvider.overrideWith(() => MockAuthNotifier(isOwner: false)),
            businessProvider.overrideWith(() => MockBusinessNotifier(isOwner: false)),
            organizationProvider.overrideWith(() => MockOrganizationNotifier()),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const VoucherScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title
      expect(find.text('Voucher & Barcode 2D'), findsOneWidget);

      // Staff must NOT see the "Buat Voucher" FAB
      expect(find.text('Buat Voucher'), findsNothing);

      // Staff must NOT see status filter chips
      expect(find.widgetWithText(ChoiceChip, 'Semua'), findsNothing);
      expect(find.widgetWithText(ChoiceChip, 'Nonaktif'), findsNothing);

      // Staff can see active voucher cards and "Cetak Slip"
      expect(find.text('Promo Pelanggan Baru 15%'), findsOneWidget);
      expect(find.text('Cetak Slip'), findsNWidgets(2));
    });
  });

  group('VoucherFormDialog & VoucherDetailDialog Tests', () {
    testWidgets('VoucherFormDialog locks code and percentage for used vouchers', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final usedVoucher = mockRepo.mockVouchers.first; // usage_count = 12

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: VoucherFormDialog(
                voucher: usedVoucher,
                branches: const [
                  {'id': 10, 'name': 'Genteng Central Hub', 'code': 'GNT'},
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Voucher Promo'), findsOneWidget);
      expect(find.text('Terkunci karena voucher telah digunakan'), findsOneWidget);
      expect(find.text('Terkunci (sudah dipakai)'), findsOneWidget);
      expect(find.text('Simpan Perubahan'), findsOneWidget);
    });

    testWidgets('VoucherDetailDialog renders details and actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final voucher = mockRepo.mockVouchers.first;
      var printTriggered = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            voucherRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: VoucherDetailDialog(
                voucher: voucher,
                isOwner: true,
                branches: const [],
                onPrintThermal: () => printTriggered = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('RC-VCR-15'), findsOneWidget);
      expect(find.text('Promo Pelanggan Baru 15%'), findsOneWidget);
      expect(find.text('15% OFF'), findsOneWidget);
      expect(find.text('Cetak Slip Fisik ke Printer Thermal'), findsOneWidget);
      expect(find.text('Nonaktifkan'), findsOneWidget);
      expect(find.text('Edit'), findsOneWidget);

      await tester.tap(find.text('Cetak Slip Fisik ke Printer Thermal'));
      await tester.pumpAndSettle();
      expect(printTriggered, isTrue);
    });
  });
}

class MockAuthNotifier extends AuthNotifier {
  final bool isOwner;
  MockAuthNotifier({required this.isOwner});

  @override
  AuthState build() {
    return AuthState(
      isAuthenticated: true,
      user: {
        'id': 'usr-1',
        'name': isOwner ? 'Pak Owner' : 'Budi Kasir',
        'role': isOwner ? 'super_admin' : 'staff',
      },
    );
  }
}

class MockBusinessNotifier extends BusinessNotifier {
  final bool isOwner;
  MockBusinessNotifier({required this.isOwner});

  @override
  BusinessState build() {
    return BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'SkyRental Store Pusat',
      businesses: [
        {
          'id': 1,
          'name': 'SkyRental Store Pusat',
          'role': isOwner ? 'owner' : 'staff',
          'branches': [
            {'id': 10, 'name': 'Genteng Central Hub', 'code': 'GNT'},
            {'id': 20, 'name': 'Surabaya Barat', 'code': 'SBY'},
          ],
        }
      ],
    );
  }
}

class MockOrganizationNotifier extends OrganizationNotifier {
  @override
  OrganizationState build() {
    return const OrganizationState(
      businessId: 1,
      businessName: 'SkyRental Store Pusat',
      userRole: 'owner',
      branches: [
        {'id': 10, 'name': 'Genteng Central Hub', 'code': 'GNT'},
        {'id': 20, 'name': 'Surabaya Barat', 'code': 'SBY'},
      ],
    );
  }
}

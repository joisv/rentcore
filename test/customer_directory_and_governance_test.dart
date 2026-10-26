import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/core/models/paginated_result.dart';
import 'package:rentcore_mobile/features/customers/data/customer_repository.dart';
import 'package:rentcore_mobile/features/customers/presentation/customer_directory_screen.dart';
import 'package:rentcore_mobile/features/customers/presentation/widgets/add_customer_sheet.dart';
import 'package:rentcore_mobile/features/customers/presentation/widgets/customer_detail_sheet.dart';
import 'package:rentcore_mobile/features/customers/providers/customer_provider.dart';

class MockCustomerRepository extends CustomerRepository {
  List<Map<String, dynamic>> dummyCustomers = [
    {
      'id': 1,
      'name': 'Budi Santoso',
      'phone': '081234567890',
      'email': 'budi@test.com',
      'address': 'Jl. Pemuda No. 10',
      'is_blacklisted': false,
      'blacklist_reason': null,
      'bookings_count': 5,
      'identities': [
        {
          'id': 1,
          'identity_type': 'KTP',
          'identity_number': '5271010101900001',
          'is_verified': true,
        }
      ],
    },
    {
      'id': 2,
      'name': 'Andi Bermasalah',
      'phone': '081999888777',
      'email': 'andi@risk.com',
      'address': 'Jl. Rawan No. 5',
      'is_blacklisted': true,
      'blacklist_reason': 'Bawa kabur unit dan nomor tidak aktif',
      'bookings_count': 1,
      'identities': [
        {
          'id': 2,
          'identity_type': 'SIM',
          'identity_number': 'SIM-99887766',
          'is_verified': false,
        }
      ],
    },
  ];

  @override
  Future<PaginatedResult<Map<String, dynamic>>> fetchCustomersPaginated({
    int page = 1,
    String? search,
    bool? isBlacklisted,
  }) async {
    var filtered = List<Map<String, dynamic>>.from(dummyCustomers);
    if (search != null && search.isNotEmpty) {
      filtered = filtered.where((c) =>
        c['name'].toString().toLowerCase().contains(search.toLowerCase()) ||
        c['phone'].toString().contains(search)
      ).toList();
    }
    if (isBlacklisted != null) {
      filtered = filtered.where((c) => c['is_blacklisted'] == isBlacklisted).toList();
    }
    return PaginatedResult(
      items: filtered,
      currentPage: 1,
      lastPage: 1,
      total: filtered.length,
      hasMore: false,
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomer({
    required String name,
    required String phone,
    String? email,
    String? address,
    String? identityNumber,
    String? identityType,
    String? identityPhotoBase64,
  }) async {
    final newCust = {
      'id': dummyCustomers.length + 1,
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'is_blacklisted': false,
      'blacklist_reason': null,
      'bookings_count': 0,
      'identities': identityNumber != null ? [
        {
          'id': 99,
          'identity_type': identityType ?? 'KTP',
          'identity_number': identityNumber,
          'is_verified': true,
        }
      ] : [],
    };
    dummyCustomers.add(newCust);
    return newCust;
  }

  @override
  Future<Map<String, dynamic>> toggleBlacklist({
    required int customerId,
    required bool isBlacklisted,
    String? reason,
    String? managerPin,
  }) async {
    final idx = dummyCustomers.indexWhere((c) => c['id'] == customerId);
    if (idx != -1) {
      dummyCustomers[idx]['is_blacklisted'] = isBlacklisted;
      dummyCustomers[idx]['blacklist_reason'] = isBlacklisted ? reason : null;
      return dummyCustomers[idx];
    }
    throw Exception('Pelanggan tidak ditemukan.');
  }
}

void main() {
  group('Customer Directory & Governance Feature Tests', () {
    late MockCustomerRepository mockRepo;

    setUp(() {
      mockRepo = MockCustomerRepository();
    });

    testWidgets('CustomerDirectoryScreen renders directory, search bar, and filter chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CustomerDirectoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Direktori Pelanggan'), findsOneWidget);
      expect(find.text('Semua Pelanggan'), findsOneWidget);
      expect(find.text('Aktif (Aman)'), findsOneWidget);
      expect(find.text('Daftar Hitam (Blacklist)'), findsOneWidget);

      // Verifies customer cards render
      expect(find.text('Budi Santoso'), findsOneWidget);
      expect(find.text('081234567890'), findsOneWidget);
      expect(find.text('5 Sewa'), findsOneWidget);
      expect(find.text('KTP Terverifikasi'), findsOneWidget);

      expect(find.text('Andi Bermasalah'), findsOneWidget);
      expect(find.text('BLACKLIST'), findsWidgets);
    });

    testWidgets('Filter chip filters customers to blacklisted only', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: CustomerDirectoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Blacklist filter
      await tester.tap(find.text('Daftar Hitam (Blacklist)'));
      await tester.pumpAndSettle();

      expect(find.text('Andi Bermasalah'), findsOneWidget);
      expect(find.text('Budi Santoso'), findsNothing);
    });

    testWidgets('CustomerDetailSheet renders details, verified identity, and blacklist alert', (tester) async {
      final blacklistedCustomer = mockRepo.dummyCustomers[1];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: CustomerDetailSheet(customer: blacklistedCustomer),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Andi Bermasalah'), findsOneWidget);
      expect(find.text('081999888777'), findsOneWidget);
      expect(find.text('Pelanggan Dalam Daftar Hitam'), findsOneWidget);
      expect(find.textContaining('Bawa kabur unit'), findsOneWidget);
      expect(find.text('SIM • SIM-99887766'), findsOneWidget);
      expect(find.text('Cabut Blacklist'), findsOneWidget);
    });

    testWidgets('AddCustomerSheet renders form and registers new customer', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            customerRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AddCustomerSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tambah Pelanggan Baru'), findsOneWidget);
      expect(find.text('Nama Lengkap *'), findsOneWidget);
      expect(find.text('Nomor WhatsApp / HP *'), findsOneWidget);

      // Fill in customer form
      await tester.enterText(find.widgetWithText(TextFormField, 'Nama Lengkap *'), 'Citra Lestari');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nomor WhatsApp / HP *'), '081344556677');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nomor Identitas (NIK)'), '5271019998880002');
      await tester.pumpAndSettle();

      // Submit
      await tester.tap(find.text('Simpan Pelanggan'));
      await tester.pumpAndSettle();

      expect(mockRepo.dummyCustomers.any((c) => c['name'] == 'Citra Lestari'), isTrue);
    });
  });
}

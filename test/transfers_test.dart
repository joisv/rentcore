import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/features/auth/providers/auth_provider.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/bookings/data/booking_repository.dart';
import 'package:sewakasir/features/bookings/providers/booking_provider.dart';
import 'package:sewakasir/features/transfers/data/transfer_repository.dart';
import 'package:sewakasir/features/transfers/presentation/transfers_screen.dart';
import 'package:sewakasir/features/transfers/providers/transfer_provider.dart';

class _MockAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  _MockAuthNotifier(this.initialState);

  @override
  AuthState build() => initialState;
}

class _MockBusinessNotifier extends BusinessNotifier {
  final BusinessState initialState;
  _MockBusinessNotifier(this.initialState);

  @override
  BusinessState build() => initialState;
}

class _FakeBookingRepository extends BookingRepository {
  final List<Map<String, dynamic>> readyAssets;
  _FakeBookingRepository({this.readyAssets = const []});

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    return readyAssets;
  }
}

class _FakeTransferRepository extends TransferRepository {
  final List<Map<String, dynamic>> destinations;
  final Map<int, List<Map<String, dynamic>>> recipientsByBranch;
  Map<String, dynamic>? lastCreatedTransfer;

  _FakeTransferRepository({
    this.destinations = const [],
    this.recipientsByBranch = const {},
  });

  @override
  Future<List<Map<String, dynamic>>> fetchTransfers({
    String? direction,
    String? status,
  }) async {
    return const [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchDestinationAffiliates() async {
    return destinations;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchRecipients(int branchId) async {
    return recipientsByBranch[branchId] ?? const [];
  }

  @override
  Future<Map<String, dynamic>> createTransfer({
    required int assetId,
    required int toAffiliateId,
    required String recipientId,
    String? notes,
  }) async {
    lastCreatedTransfer = {
      'asset_id': assetId,
      'to_affiliate_id': toAffiliateId,
      'recipient_id': recipientId,
      'notes': notes,
    };
    return {'id': 999, 'transfer_code': 'TRF-261122-0001'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  group('TransfersScreen Widget & Role Authorization Tests', () {
    final mockPendingTransfer = {
      'id': 101,
      'transfer_code': 'TRF-261013-0001',
      'status': 'pending',
      'asset_id': 1,
      'from_affiliate_id': 1,
      'to_affiliate_id': 2,
      'sent_by': 'user-staff-1',
      'recipient_id': 'user-staff-2',
      'notes': 'Stok cadangan weekend',
      'asset': {
        'id': 1,
        'asset_code': 'AST-IP15P-001',
        'serial_number': 'SN-IP15P-001',
        'status': 'reserved',
        'model': {'name': 'iPhone 15 Pro 256GB'},
      },
      'from_affiliate': {'id': 1, 'name': 'Cabang Pusat'},
      'to_affiliate': {'id': 2, 'name': 'Cabang Surabaya'},
      'sender': {'id': 'user-staff-1', 'name': 'Staf Pusat'},
      'recipient': {'id': 'user-staff-2', 'name': 'Staf Surabaya'},
    };

    final mockInTransitTransfer = {
      'id': 102,
      'transfer_code': 'TRF-261013-0002',
      'status': 'in_transit',
      'asset_id': 2,
      'from_affiliate_id': 1,
      'to_affiliate_id': 2,
      'sent_by': 'user-owner',
      'recipient_id': 'user-staff-2',
      'approved_by': 'user-owner',
      'notes': 'Pengiriman unit ready',
      'asset': {
        'id': 2,
        'asset_code': 'AST-IP15PM-002',
        'serial_number': 'SN-IP15PM-002',
        'status': 'in_transit',
        'model': {'name': 'iPhone 15 Pro Max 256GB'},
      },
      'from_affiliate': {'id': 1, 'name': 'Cabang Pusat'},
      'to_affiliate': {'id': 2, 'name': 'Cabang Surabaya'},
      'sender': {'id': 'user-owner', 'name': 'Owner Mega Jaya'},
      'recipient': {'id': 'user-staff-2', 'name': 'Staf Surabaya'},
      'approver': {'id': 'user-owner', 'name': 'Owner Mega Jaya'},
    };

    testWidgets('Owner sees Setujui and Tolak buttons on pending transfer', (tester) async {
      const ownerAuthState = AuthState(
        isAuthenticated: true,
        user: {
          'id': 'user-owner',
          'name': 'Owner Mega Jaya',
          'email': 'owner@megajaya.id',
          'role': 'owner',
        },
      );
      const ownerBizState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Mega Jaya Rental',
        businesses: [
          {'id': 1, 'name': 'Mega Jaya Rental', 'role': 'owner'}
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(ownerAuthState)),
          transfersListProvider.overrideWith((ref) async => [mockPendingTransfer]),
          businessProvider.overrideWith(() => _MockBusinessNotifier(ownerBizState)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransfersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRF-261013-0001'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('transfer_card_status_101')),
          matching: find.text('Menunggu'),
        ),
        findsOneWidget,
      );
      expect(find.text('iPhone 15 Pro 256GB'), findsOneWidget);
      expect(find.text('Cabang Pusat'), findsOneWidget);
      expect(find.text('Cabang Surabaya'), findsOneWidget);

      // Owner should see approve & reject buttons
      expect(find.text('Setujui'), findsOneWidget);
      expect(find.text('Tolak'), findsOneWidget);
    });

    testWidgets('Staff does NOT see approve/reject buttons on pending transfer', (tester) async {
      const staffAuthState = AuthState(
        isAuthenticated: true,
        user: {
          'id': 'user-staff-1',
          'name': 'Staf Pusat',
          'email': 'staff1@megajaya.id',
          'role': 'staff',
        },
      );
      const staffBizState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Mega Jaya Rental',
        businesses: [
          {'id': 1, 'name': 'Mega Jaya Rental', 'role': 'staff'}
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(staffAuthState)),
          transfersListProvider.overrideWith((ref) async => [mockPendingTransfer]),
          businessProvider.overrideWith(() => _MockBusinessNotifier(staffBizState)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransfersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRF-261013-0001'), findsOneWidget);
      // Staff should NOT see Setujui or Tolak buttons
      expect(find.text('Setujui'), findsNothing);
      expect(find.text('Tolak'), findsNothing);
      expect(find.text('Menunggu persetujuan dari Business Owner.'), findsOneWidget);
    });

    testWidgets('Only assigned recipient sees Terima Unit button on in-transit transfer', (tester) async {
      const recipientAuthState = AuthState(
        isAuthenticated: true,
        user: {
          'id': 'user-staff-2',
          'name': 'Staf Surabaya',
          'email': 'staff2@megajaya.id',
          'role': 'staff',
        },
      );
      const recipientBizState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Mega Jaya Rental',
        businesses: [
          {'id': 1, 'name': 'Mega Jaya Rental', 'role': 'staff'}
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(recipientAuthState)),
          transfersListProvider.overrideWith((ref) async => [mockInTransitTransfer]),
          businessProvider.overrideWith(() => _MockBusinessNotifier(recipientBizState)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransfersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRF-261013-0002'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('transfer_card_status_102')),
          matching: find.text('Dikirim'),
        ),
        findsOneWidget,
      );
      // Assigned recipient MUST see "Terima Unit"
      expect(find.text('Terima Unit'), findsOneWidget);
      expect(find.text('Anda'), findsOneWidget);
    });

    testWidgets('Other user at destination branch does NOT see Terima Unit button', (tester) async {
      const otherAuthState = AuthState(
        isAuthenticated: true,
        user: {
          'id': 'user-staff-other',
          'name': 'Staf Lain Surabaya',
          'email': 'other@megajaya.id',
          'role': 'staff',
        },
      );
      const otherBizState = BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Mega Jaya Rental',
        businesses: [
          {'id': 1, 'name': 'Mega Jaya Rental', 'role': 'staff'}
        ],
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(otherAuthState)),
          transfersListProvider.overrideWith((ref) async => [mockInTransitTransfer]),
          businessProvider.overrideWith(() => _MockBusinessNotifier(otherBizState)),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: TransfersScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('TRF-261013-0002'), findsOneWidget);
      // Unassigned staff MUST NOT see "Terima Unit"
      expect(find.text('Terima Unit'), findsNothing);
      expect(find.textContaining('Menunggu penerimaan oleh Staf Surabaya'), findsOneWidget);
    });
  });

  group('TransfersScreen Redesign & Bottom Sheet Tests', () {
    const ownerAuthState = AuthState(
      isAuthenticated: true,
      user: {
        'id': 'user-owner',
        'name': 'Owner Mega Jaya',
        'email': 'owner@megajaya.id',
        'role': 'owner',
      },
    );

    const ownerBizState = BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'Mega Jaya Rental',
      activeBranchId: 1,
      businesses: [
        {'id': 1, 'name': 'Mega Jaya Rental', 'role': 'owner'},
      ],
    );

    final mockReceivedTransfer = {
      'id': 103,
      'transfer_code': 'TRF-261121-0001',
      'status': 'received',
      'asset_id': 3,
      'from_affiliate_id': 1,
      'to_affiliate_id': 2,
      'sent_by': 'user-staff-1',
      'recipient_id': 'user-owner',
      'asset': {
        'id': 3,
        'asset_code': 'AST-IP16P-003',
        'serial_number': 'SN-IP16P-003',
        'status': 'ready',
        'model': {'name': 'iPhone 16 Pro 256GB'},
      },
      'from_affiliate': {'id': 1, 'name': 'Cabang Pusat'},
      'to_affiliate': {'id': 2, 'name': 'Cabang Bandung'},
      'sender': {'id': 'user-staff-1', 'name': 'Budi'},
      'approver': {'id': 'user-owner', 'name': 'Owner Mega Jaya'},
      'recipient': {'id': 'user-owner', 'name': 'Owner Mega Jaya'},
      'receiver': {'id': 'user-owner', 'name': 'Owner Mega Jaya'},
    };

    testWidgets('renders segmented direction switcher without truncation and updates provider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(ownerAuthState)),
          businessProvider.overrideWith(() => _MockBusinessNotifier(ownerBizState)),
          transfersListProvider.overrideWith((ref) async => const []),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TransfersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mutasi Unit Antar Cabang'), findsOneWidget);
      expect(find.byKey(const Key('transfer_direction_all')), findsOneWidget);
      expect(find.byKey(const Key('transfer_direction_inbound')), findsOneWidget);
      expect(find.byKey(const Key('transfer_direction_outbound')), findsOneWidget);
      expect(find.text('Masuk'), findsOneWidget);
      expect(find.text('Keluar'), findsOneWidget);
      expect(find.textContaining('Inbound'), findsNothing);
      expect(find.textContaining('Outbound'), findsNothing);

      expect(container.read(selectedTransferDirectionProvider), 'all');

      await tester.tap(find.byKey(const Key('transfer_direction_inbound')));
      await tester.pumpAndSettle();
      expect(container.read(selectedTransferDirectionProvider), 'inbound');

      await tester.tap(find.byKey(const Key('transfer_direction_outbound')));
      await tester.pumpAndSettle();
      expect(container.read(selectedTransferDirectionProvider), 'outbound');
    });

    testWidgets('status filter pills maintain legible active contrast and update provider', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(ownerAuthState)),
          businessProvider.overrideWith(() => _MockBusinessNotifier(ownerBizState)),
          transfersListProvider.overrideWith((ref) async => const []),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TransfersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      // Active 'Semua' status pill uses #0F172A fill and #FFFFFF text
      final allStatusText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transfer_status_all')),
          matching: find.text('Semua'),
        ),
      );
      expect(allStatusText.style?.color, Colors.white);

      final allStatusBox = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byKey(const Key('transfer_status_all')),
          matching: find.byType(AnimatedContainer),
        ),
      );
      final allDecoration = allStatusBox.decoration as BoxDecoration;
      expect(allDecoration.color, const Color(0xFF0F172A));

      // Inactive 'Menunggu' pill uses #FFFFFF fill and #64748B text
      final pendingText = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transfer_status_pending')),
          matching: find.text('Menunggu'),
        ),
      );
      expect(pendingText.style?.color, const Color(0xFF64748B));

      await tester.tap(find.byKey(const Key('transfer_status_received')));
      await tester.pumpAndSettle();

      expect(container.read(selectedTransferStatusProvider), 'received');

      final receivedTextAfter = tester.widget<Text>(
        find.descendant(
          of: find.byKey(const Key('transfer_status_received')),
          matching: find.text('Diterima'),
        ),
      );
      expect(receivedTextAfter.style?.color, Colors.white);
    });

    testWidgets('renders clean transfer card with route, neutral receiver row, soft Anda badge, and audit trail', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(ownerAuthState)),
          businessProvider.overrideWith(() => _MockBusinessNotifier(ownerBizState)),
          transfersListProvider.overrideWith((ref) async => [mockReceivedTransfer]),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TransfersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRF-261121-0001'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const Key('transfer_card_status_103')),
          matching: find.text('Diterima'),
        ),
        findsOneWidget,
      );
      expect(find.text('iPhone 16 Pro 256GB'), findsOneWidget);
      expect(find.text('Kode: AST-IP16P-003 • SN: SN-IP16P-003'), findsOneWidget);
      expect(find.text('Cabang Asal'), findsOneWidget);
      expect(find.text('Cabang Tujuan'), findsOneWidget);
      expect(find.text('Cabang Pusat'), findsOneWidget);
      expect(find.text('Cabang Bandung'), findsOneWidget);
      expect(find.text('Penerima: Owner Mega Jaya'), findsOneWidget);
      expect(find.text('Anda'), findsOneWidget);
      expect(
        find.text('Diajukan: Budi • Disetujui: Owner Mega Jaya • Diterima: Owner Mega Jaya'),
        findsOneWidget,
      );
    });

    testWidgets('bottom sheet validates required fields and submits transfer cleanly', (tester) async {
      final fakeBookingRepo = _FakeBookingRepository(
        readyAssets: [
          {
            'id': 11,
            'asset_code': 'AST-MAC-011',
            'model': {'name': 'MacBook Pro M3'},
          },
        ],
      );
      final fakeTransferRepo = _FakeTransferRepository(
        destinations: [
          {'id': 2, 'name': 'Cabang Surabaya', 'code': 'SUB'},
        ],
        recipientsByBranch: {
          2: [
            {'id': 'user-staff-2', 'name': 'Siti', 'role': 'staff'},
          ],
        },
      );

      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWith(() => _MockAuthNotifier(ownerAuthState)),
          businessProvider.overrideWith(() => _MockBusinessNotifier(ownerBizState)),
          bookingRepositoryProvider.overrideWithValue(fakeBookingRepo),
          transferRepositoryProvider.overrideWithValue(fakeTransferRepo),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: TransfersScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('transfer_kirim_unit_button')));
      await tester.pumpAndSettle();

      expect(find.text('Kirim Unit Antar Cabang'), findsOneWidget);
      expect(find.text('Pindahkan unit siap sewa ke cabang tujuan'), findsOneWidget);

      // Submit button is initially disabled until required dropdowns are selected
      final initialSubmitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('transfer_submit_button')),
      );
      expect(initialSubmitBtn.onPressed, isNull);

      // Select ready asset
      await tester.tap(find.byKey(const Key('transfer_asset_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('MacBook Pro M3 (AST-MAC-011)').last);
      await tester.pumpAndSettle();

      // Still disabled before destination branch
      expect(
        tester.widget<ElevatedButton>(find.byKey(const Key('transfer_submit_button'))).onPressed,
        isNull,
      );

      // Select destination branch (auto-selects single recipient Siti)
      await tester.tap(find.byKey(const Key('transfer_destination_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cabang Surabaya (SUB)').last);
      await tester.pumpAndSettle();

      // Enter optional notes
      await tester.enterText(
        find.byKey(const Key('transfer_notes_field')),
        'Kebutuhan weekend',
      );
      await tester.pump();

      // Submit button should now be enabled
      final enabledSubmitBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('transfer_submit_button')),
      );
      expect(enabledSubmitBtn.onPressed, isNotNull);

      await tester.tap(find.byKey(const Key('transfer_submit_button')));
      await tester.pumpAndSettle();

      expect(fakeTransferRepo.lastCreatedTransfer, {
        'asset_id': 11,
        'to_affiliate_id': 2,
        'recipient_id': 'user-staff-2',
        'notes': 'Kebutuhan weekend',
      });
      expect(find.text('Pengajuan mutasi unit berhasil dikirim!'), findsOneWidget);
    });
  });
}

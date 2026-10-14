import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/transfers/presentation/transfers_screen.dart';
import 'package:rentcore_mobile/features/transfers/providers/transfer_provider.dart';

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
      expect(find.text('Menunggu Persetujuan'), findsOneWidget);
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
      expect(find.text('Dalam Pengiriman'), findsWidgets);
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
}

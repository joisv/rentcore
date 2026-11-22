import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/bookings/data/booking_repository.dart';
import 'package:rentcore_mobile/features/bookings/presentation/direct_rental_screen.dart';
import 'package:rentcore_mobile/features/bookings/providers/booking_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/inventory/providers/asset_provider.dart';

class _BranchAwareAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _BranchAwareAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _BranchAwareBusinessNotifier extends BusinessNotifier {
  final BusinessState _initialState;
  _BranchAwareBusinessNotifier(this._initialState);

  @override
  BusinessState build() => _initialState;

  void switchBranch(int? branchId, String? branchName) {
    state = state.copyWith(
      activeBranchId: branchId,
      activeBranchName: branchName,
      clearBranch: branchId == null,
    );
  }
}

class _ShiftSpyCashierRepo extends CashierRepository {
  final List<int?> shiftBranchCalls = [];

  @override
  Future<Map<String, dynamic>> fetchCurrentShift({int? branchId}) async {
    shiftBranchCalls.add(branchId);
    return {
      'has_active_shift': true,
      'shift_enforcement_enabled': true,
      'shift': {'id': branchId ?? 1, 'status': 'open', 'opening_cash_float': 100000.0},
    };
  }
}

class _BranchScopedBookingRepo extends BookingRepository {
  final List<int?> readyAssetBranchCalls = [];
  final List<int?> availabilityBranchCalls = [];
  Map<String, dynamic>? submittedPayload;

  @override
  Future<List<Map<String, dynamic>>> fetchReadyAssets({int? branchId}) async {
    readyAssetBranchCalls.add(branchId);
    if (branchId == 1) {
      return [
        {
          'id': 101,
          'affiliate_id': 1,
          'asset_code': 'PST-IP16-01',
          'serial_number': 'SN-PST-1601',
          'status': 'ready',
          'model_id': 50,
          'model': {
            'id': 50,
            'name': 'iPhone 16 Pro Max Pusat',
            'brand': 'Apple',
            'category_id': 1,
            'category': {'id': 1, 'name': 'Smartphones'},
            'pricing_tiers': [
              {
                'id': 501,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 450000,
              },
            ],
          },
        },
      ];
    }
    if (branchId == 2) {
      return [
        {
          'id': 201,
          'affiliate_id': 2,
          'asset_code': 'CB1-IP15-01',
          'serial_number': 'SN-CB1-1501',
          'status': 'ready',
          'model_id': 60,
          'model': {
            'id': 60,
            'name': 'iPhone 15 cabang 1',
            'brand': 'Apple',
            'category_id': 1,
            'category': {'id': 1, 'name': 'Smartphones'},
            'pricing_tiers': [
              {
                'id': 601,
                'duration_unit': 'day',
                'duration_value': 1,
                'duration_hours': 24,
                'price': 300000,
              },
            ],
          },
        },
      ];
    }
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> fetchModelAvailability({
    required DateTime startAt,
    required DateTime endAt,
    int? branchId,
    int? categoryId,
    String? search,
  }) async {
    availabilityBranchCalls.add(branchId);
    if (branchId == 1) {
      return [
        {
          'id': 50,
          'name': 'iPhone 16 Pro Max Pusat',
          'brand': 'Apple',
          'category_id': 1,
          'total_units': 1,
          'booked_units': 0,
          'available_slots': 1,
          'available_asset_ids': [101],
          'category': {'id': 1, 'name': 'Smartphones'},
          'pricing_tiers': [
            {
              'id': 501,
              'duration_unit': 'day',
              'duration_value': 1,
              'duration_hours': 24,
              'price': 450000,
            },
          ],
        },
      ];
    }
    if (branchId == 2) {
      return [
        {
          'id': 60,
          'name': 'iPhone 15 cabang 1',
          'brand': 'Apple',
          'category_id': 1,
          'total_units': 1,
          'booked_units': 0,
          'available_slots': 1,
          'available_asset_ids': [201],
          'category': {'id': 1, 'name': 'Smartphones'},
          'pricing_tiers': [
            {
              'id': 601,
              'duration_unit': 'day',
              'duration_value': 1,
              'duration_hours': 24,
              'price': 300000,
            },
          ],
        },
      ];
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> createRental(
    Map<String, dynamic> payload, {
    String? idempotencyKey,
  }) async {
    submittedPayload = Map<String, dynamic>.from(payload);
    return {'id': 99, 'booking_code': 'RC-CB1-099', 'status': 'booked'};
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });

  BusinessState makeBusinessState({
    required int? activeBranchId,
    required String? activeBranchName,
    bool includeBranches = true,
  }) {
    return BusinessState(
      activeBusinessId: 1,
      activeBusinessName: 'Gwenn Rental',
      activeBranchId: activeBranchId,
      activeBranchName: activeBranchName,
      businesses: [
        {
          'id': 1,
          'name': 'Gwenn Rental',
          'role': 'owner',
          'branches': includeBranches
              ? [
                  {'id': 1, 'name': 'Gwenn Rental Pusat', 'is_central': true, 'allow_floating_unit_booking': true},
                  {'id': 2, 'name': 'cabang 1', 'is_central': false, 'allow_floating_unit_booking': true},
                ]
              : [],
        },
      ],
    );
  }

  testWidgets(
    'Switching from Gwenn Rental Pusat to cabang 1 resets stale selections, updates header & shift, queries cabang 1 stock, and submits explicit branch_id',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _BranchScopedBookingRepo();
      final cashierRepo = _ShiftSpyCashierRepo();
      final bizNotifier = _BranchAwareBusinessNotifier(
        makeBusinessState(activeBranchId: 1, activeBranchName: 'Gwenn Rental Pusat'),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            businessProvider.overrideWith(() => bizNotifier),
            authProvider.overrideWith(
              () => _BranchAwareAuthNotifier(
                const AuthState(isAuthenticated: true, user: {'id': 1, 'name': 'Owner'}),
              ),
            ),
            categoriesProvider.overrideWith((ref) async => [
              {'id': 1, 'name': 'Smartphones', 'is_addon': false},
            ]),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(
              key: ValueKey('empty_branches_screen'),
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initially Gwenn Rental Pusat
      expect(find.text('Sewa / Booking Baru'), findsOneWidget);
      expect(find.text('Cabang: Gwenn Rental Pusat'), findsOneWidget);
      expect(find.textContaining('PST-IP16-01'), findsOneWidget);
      expect(cashierRepo.shiftBranchCalls, contains(1));

      // Select Pusat unit and pick future schedule
      await tester.tap(find.textContaining('PST-IP16-01').last);
      await tester.pumpAndSettle();

      final scheduleTrigger = find.byKey(const Key('inline_schedule_action'));
      await tester.ensureVisible(scheduleTrigger);
      await tester.tap(scheduleTrigger);
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(repo.availabilityBranchCalls, [1]);
      expect(find.byKey(const Key('floating_model_card_50')), findsOneWidget);

      // Switch branch to cabang 1 (id: 2)
      bizNotifier.switchBranch(2, 'cabang 1');
      await tester.pumpAndSettle();

      // Header subtitle, shift query, and floating models update to cabang 1 while clearing Pusat model
      expect(find.text('Cabang: Cabang 1'), findsOneWidget);
      expect(repo.availabilityBranchCalls.last, 2);
      expect(cashierRepo.shiftBranchCalls, contains(2));
      expect(find.byKey(const Key('floating_model_card_60')), findsOneWidget);
      expect(find.byKey(const Key('floating_model_card_50')), findsNothing);
      expect(find.text('iPhone 16 Pro Max Pusat'), findsNothing);

      // Next should be disabled until cabang 1 model is selected
      final nextBtnBeforeSelect = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Lanjut'),
      );
      expect(nextBtnBeforeSelect.onPressed, isNull);

      // Select cabang 1 model -> Step 2 (Penyewa) -> Step 3 -> Bayar Nanti submits explicit branch_id: 2
      await tester.tap(find.byKey(const Key('floating_model_card_60')));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('step2_name_field')),
        'Budi Cabang 1',
      );
      await tester.enterText(
        find.byKey(const Key('step2_phone_field')),
        '081234567890',
      );
      await tester.enterText(
        find.byKey(const Key('step2_address_field')),
        'Jl. Cabang Satu No. 1',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Lanjut'));
      await tester.pumpAndSettle();

      // Switch to Pay Later ('Bayar Saat Ambil') in Step 3 and submit directly to inspect payload
      await tester.tap(find.text('Bayar Saat Ambil'));
      await tester.pumpAndSettle();
      final submitBtn = find.widgetWithText(ElevatedButton, 'Simpan Booking');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(repo.submittedPayload, isNotNull);
      expect(repo.submittedPayload!['branch_id'], 2);
      expect(repo.submittedPayload!['affiliate_id'], 2);
      expect(repo.submittedPayload!['asset_model_id'], 60);
    },
  );

  testWidgets(
    'Consolidated mode (activeBranchId == null) falls back to user assigned branch and allows switching target branch inside form',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final repo = _BranchScopedBookingRepo();
      final cashierRepo = _ShiftSpyCashierRepo();
      final bizNotifier = _BranchAwareBusinessNotifier(
        makeBusinessState(activeBranchId: null, activeBranchName: null),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            businessProvider.overrideWith(() => bizNotifier),
            authProvider.overrideWith(
              () => _BranchAwareAuthNotifier(
                const AuthState(
                  isAuthenticated: true,
                  user: {'id': 2, 'name': 'Staff cabang 1', 'affiliate_id': 2},
                ),
              ),
            ),
            categoriesProvider.overrideWith((ref) async => [
              {'id': 1, 'name': 'Smartphones', 'is_addon': false},
            ]),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(
              key: ValueKey('empty_branches_screen'),
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Falls back to user's assigned branch (id: 2 -> cabang 1)
      expect(find.text('Cabang: Cabang 1'), findsOneWidget);
      expect(find.byKey(const Key('consolidated_branch_fallback_banner')), findsOneWidget);
      expect(repo.readyAssetBranchCalls, contains(2));
      expect(find.textContaining('CB1-IP15-01'), findsOneWidget);
      expect(find.textContaining('PST-IP16-01'), findsNothing);

      // Switch target branch inside form via header "Ganti" button to Gwenn Rental Pusat (1)
      await tester.tap(find.byKey(const Key('booking_switch_branch_button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('booking_branch_option_1')));
      await tester.pumpAndSettle();

      expect(find.text('Cabang: Gwenn Rental Pusat'), findsOneWidget);
      expect(repo.readyAssetBranchCalls.last, 1);
      expect(find.textContaining('PST-IP16-01'), findsOneWidget);
      expect(find.textContaining('CB1-IP15-01'), findsNothing);

      // If no branches exist at all, warning banner appears and Lanjut stays disabled
      final emptyBizNotifier = _BranchAwareBusinessNotifier(
        makeBusinessState(activeBranchId: null, activeBranchName: null, includeBranches: false),
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey('empty_branches_scope'),
          overrides: [
            bookingRepositoryProvider.overrideWithValue(repo),
            cashierRepositoryProvider.overrideWithValue(cashierRepo),
            businessProvider.overrideWith(() => emptyBizNotifier),
            authProvider.overrideWith(
              () => _BranchAwareAuthNotifier(const AuthState(isAuthenticated: true, user: {'id': 1})),
            ),
            categoriesProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: DirectRentalScreen(
              key: ValueKey('no_branches_widget'),
              showAppBar: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('consolidated_branch_booking_warning')), findsOneWidget);
      final nextBtn = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Lanjut'),
      );
      expect(nextBtn.onPressed, isNull);
    },
  );
}

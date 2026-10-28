import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/shift_schedule_screen.dart';
import 'package:rentcore_mobile/features/organization/presentation/store_settings_screen.dart';

class _StaticAuthNotifier extends AuthNotifier {
  final AuthState _initial;
  _StaticAuthNotifier(this._initial);

  @override
  AuthState build() => _initial;
}

class _StaticBusinessNotifier extends BusinessNotifier {
  final BusinessState _initial;
  _StaticBusinessNotifier(this._initial);

  @override
  BusinessState build() => _initial;
}

void main() {
  testWidgets('ShiftScheduleScreen renders schedule configuration and read-only notice for staff', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockSchedule = {
      'shift_enforcement_enabled': true,
      'shift_opening_time': '08:00',
      'shift_closing_time': '22:00',
      'shift_grace_period_minutes': 30,
      'is_overnight': false,
      'timezone': 'Asia/Jakarta',
      'operational_state': 'active',
      'status_message': 'Shift kasir sedang aktif.',
      'has_active_shift': true,
      'active_shift_id': 2,
    };

    final staffUser = {
      'id': '01a13506-5862-72ea-99f4-6c5486ffad59',
      'name': 'Jois Vanka',
      'role': 'staff',
      'is_platform_admin': false,
    };

    final sampleBusiness = {
      'id': 3,
      'name': 'Gwenn Repair & Rental',
      'role': 'staff',
      'branches': [
        {'id': 5, 'name': 'Cabang Satelit', 'is_central': false},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _StaticAuthNotifier(
            AuthState(user: staffUser, isAuthenticated: true),
          )),
          businessProvider.overrideWith(() => _StaticBusinessNotifier(
            BusinessState(
              activeBusinessId: 3,
              activeBusinessName: 'Gwenn Repair & Rental',
              activeBranchId: 5,
              businesses: [sampleBusiness],
            ),
          )),
          shiftScheduleProvider(5).overrideWith((ref) => Future.value(mockSchedule)),
          shiftScheduleProvider(null).overrideWith((ref) => Future.value(mockSchedule)),
        ],
        child: const MaterialApp(
          home: ShiftScheduleScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Screen Title
    expect(find.text('Jadwal Operasional Shift'), findsOneWidget);

    // Verify Staff Read-only notice
    expect(find.textContaining('Mode Hanya Baca'), findsOneWidget);

    // Verify Status Card elements
    expect(find.text('STATUS OPERASIONAL HARI INI'), findsOneWidget);
    expect(find.text('SHIFT SEDANG AKTIF'), findsOneWidget);
    expect(find.text('Shift kasir sedang aktif.'), findsOneWidget);

    // Verify Main schedule card
    expect(find.text('PENGATURAN UTAMA JADWAL SHIFT'), findsOneWidget);
    expect(find.text('08:00'), findsWidgets);
    expect(find.text('22:00'), findsWidgets);

    // Save button should NOT be rendered for staff
    expect(find.text('Simpan Jadwal Operasional'), findsNothing);
  });

  testWidgets('ShiftScheduleScreen allows Owner to view save button', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final mockSchedule = {
      'shift_enforcement_enabled': true,
      'shift_opening_time': '08:00',
      'shift_closing_time': '22:00',
      'shift_grace_period_minutes': 30,
      'is_overnight': false,
      'timezone': 'Asia/Jakarta',
      'operational_state': 'opening_required',
      'status_message': 'Wajib buka shift.',
      'has_active_shift': false,
    };

    final ownerUser = {
      'id': 'owner-123',
      'name': 'Owner Gwenn',
      'role': 'owner',
      'is_platform_admin': false,
    };

    final ownerBusiness = {
      'id': 3,
      'name': 'Gwenn Repair & Rental',
      'role': 'owner',
      'branches': [
        {'id': 5, 'name': 'Cabang Satelit', 'is_central': false},
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(() => _StaticAuthNotifier(
            AuthState(user: ownerUser, isAuthenticated: true),
          )),
          businessProvider.overrideWith(() => _StaticBusinessNotifier(
            BusinessState(
              activeBusinessId: 3,
              activeBusinessName: 'Gwenn Repair & Rental',
              activeBranchId: 5,
              businesses: [ownerBusiness],
            ),
          )),
          shiftScheduleProvider(5).overrideWith((ref) => Future.value(mockSchedule)),
          shiftScheduleProvider(null).overrideWith((ref) => Future.value(mockSchedule)),
        ],
        child: const MaterialApp(
          home: ShiftScheduleScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Staff read-only notice should NOT appear
    expect(find.textContaining('Mode Hanya Baca'), findsNothing);

    // Save button should be rendered
    expect(find.text('Simpan Jadwal Operasional'), findsOneWidget);
  });

  testWidgets('StoreSettingsScreen contains Shift Schedule tile', (tester) async {
    tester.view.physicalSize = const Size(1000, 2000);
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
    expect(find.text('Jadwal & Jam Operasional Shift'), findsOneWidget);
  });
}

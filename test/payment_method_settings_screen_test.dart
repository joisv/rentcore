import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/data/cashier_repository.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';
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

class FakeCashierRepository extends CashierRepository {
  Map<String, dynamic> settingsData = {
    'business_id': 1,
    'branch_id': null,
    'is_branch_override': false,
    'is_owner_or_admin': true,
    'config': {
      'ewallet_enabled': true,
      'ewallet_providers': {
        'shopeepay': true,
        'dana': true,
        'linkaja': true,
        'ovo': true,
      },
      'qris_statis_enabled': true,
      'qris_image_path': null,
      'qris_image_url': null,
      'cash_enabled': true,
      'bank_transfer_enabled': true,
    },
  };

  Future<Map<String, dynamic>> Function(dynamic payload)?
  updatePaymentSettingsHandler;

  @override
  Future<Map<String, dynamic>> fetchPaymentSettings({int? branchId}) async {
    return settingsData;
  }

  @override
  Future<Map<String, dynamic>> updatePaymentSettings(dynamic payload) async {
    if (updatePaymentSettingsHandler != null) {
      return updatePaymentSettingsHandler!(payload);
    }
    return settingsData;
  }
}

void main() {
  group('PaymentMethodSettingsScreen UI Tests', () {
    testWidgets('Owner sees all toggles, QRIS upload card, and save button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeCashierRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            paymentSettingsProvider(null)
                .overrideWith((ref) => Future.value(fakeRepo.settingsData)),
            authProvider.overrideWith(
              () => _StaticAuthNotifier(
                AuthState(
                  user: {
                    'id': 'user-1',
                    'name': 'Owner Hadi',
                    'email': 'owner@rentcore.id',
                    'role': 'owner',
                  },
                  isAuthenticated: true,
                ),
              ),
            ),
            businessProvider.overrideWith(
              () => _StaticBusinessNotifier(
                BusinessState(
                  activeBusinessId: 1,
                  activeBusinessName: 'RentCore Pusat',
                  businesses: [
                    {'id': 1, 'name': 'RentCore Pusat', 'role': 'owner'},
                  ],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: PaymentMethodSettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Screen Title
      expect(find.text('Metode Pembayaran'), findsOneWidget);

      // Verify QRIS Section
      expect(find.text('QRIS Statis'), findsOneWidget);
      expect(find.byKey(const Key('qris_statis_toggle')), findsOneWidget);
      expect(find.text('Belum ada gambar barcode QRIS'), findsOneWidget);

      // Verify E-Wallet Section & Providers
      expect(find.text('Dompet Digital (E-Wallet)'), findsOneWidget);
      expect(find.byKey(const Key('ewallet_master_toggle')), findsOneWidget);
      expect(find.text('ShopeePay'), findsOneWidget);
      expect(find.text('DANA'), findsOneWidget);
      expect(find.text('LinkAja'), findsOneWidget);
      expect(find.text('OVO'), findsOneWidget);

      // Verify Save Button is present for Owner
      expect(
        find.byKey(const Key('save_payment_settings_button')),
        findsOneWidget,
      );
    });

    testWidgets('Staff sees read-only banner without save button', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      final fakeRepo = FakeCashierRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cashierRepositoryProvider.overrideWithValue(fakeRepo),
            paymentSettingsProvider(null)
                .overrideWith((ref) => Future.value(fakeRepo.settingsData)),
            authProvider.overrideWith(
              () => _StaticAuthNotifier(
                AuthState(
                  user: {
                    'id': 'user-2',
                    'name': 'Kasir Budi',
                    'email': 'budi@rentcore.id',
                    'role': 'staff',
                  },
                  isAuthenticated: true,
                ),
              ),
            ),
            businessProvider.overrideWith(
              () => _StaticBusinessNotifier(
                BusinessState(
                  activeBusinessId: 1,
                  activeBusinessName: 'RentCore Pusat',
                  businesses: [
                    {'id': 1, 'name': 'RentCore Pusat', 'role': 'staff'},
                  ],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: PaymentMethodSettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify read-only notice
      expect(
        find.textContaining(
          'Pengaturan metode pembayaran hanya dapat diubah oleh Owner atau Admin',
        ),
        findsOneWidget,
      );

      // Verify Save Button is hidden for Staff
      expect(
        find.byKey(const Key('save_payment_settings_button')),
        findsNothing,
      );
    });

    testWidgets('StoreSettingsScreen contains Metode Pembayaran tile', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith(
              () => _StaticAuthNotifier(
                AuthState(
                  user: {
                    'id': 'user-1',
                    'name': 'Owner Hadi',
                    'email': 'owner@rentcore.id',
                    'role': 'owner',
                  },
                  isAuthenticated: true,
                ),
              ),
            ),
            businessProvider.overrideWith(
              () => _StaticBusinessNotifier(
                BusinessState(
                  activeBusinessId: 1,
                  activeBusinessName: 'RentCore Pusat',
                  businesses: [
                    {'id': 1, 'name': 'RentCore Pusat', 'role': 'owner'},
                  ],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: StoreSettingsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Metode Pembayaran'), findsOneWidget);
      expect(find.text('QRIS, Tunai, Bank & E-Wallet'), findsOneWidget);
    });

    testWidgets(
      'Toggling payment method and saving updates state without race condition',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);

        final fakeRepo = FakeCashierRepository();
        bool updateCalled = false;

        fakeRepo.updatePaymentSettingsHandler = (payload) async {
          updateCalled = true;
          // Server updates and returns fresh config
          fakeRepo.settingsData = {
            'business_id': 1,
            'branch_id': null,
            'is_branch_override': false,
            'is_owner_or_admin': true,
            'config': {
              'ewallet_enabled': false,
              'ewallet_providers': {
                'shopeepay': false,
                'dana': false,
                'linkaja': false,
                'ovo': false,
              },
              'qris_statis_enabled': false,
              'is_dynamic_qris_enabled': false,
              'cash_enabled': true,
              'bank_transfer_enabled': true,
            },
          };
          return fakeRepo.settingsData;
        };

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cashierRepositoryProvider.overrideWithValue(fakeRepo),
              paymentSettingsProvider(null)
                  .overrideWith((ref) => Future.value(fakeRepo.settingsData)),
              authProvider.overrideWith(
                () => _StaticAuthNotifier(
                  AuthState(
                    user: {
                      'id': 'user-1',
                      'name': 'Owner Hadi',
                      'email': 'owner@rentcore.id',
                      'role': 'owner',
                    },
                    isAuthenticated: true,
                  ),
                ),
              ),
              businessProvider.overrideWith(
                () => _StaticBusinessNotifier(
                  BusinessState(
                    activeBusinessId: 1,
                    activeBusinessName: 'RentCore Pusat',
                    businesses: [
                      {'id': 1, 'name': 'RentCore Pusat', 'role': 'owner'},
                    ],
                  ),
                ),
              ),
            ],
            child: const MaterialApp(home: PaymentMethodSettingsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Tap E-Wallet Master Toggle to disable it
        final ewalletSwitch = find.byKey(const Key('ewallet_master_toggle'));
        expect(ewalletSwitch, findsOneWidget);
        await tester.tap(ewalletSwitch);
        await tester.pumpAndSettle();

        // Tap QRIS Toggle to disable it
        final qrisSwitch = find.byKey(const Key('qris_statis_toggle'));
        expect(qrisSwitch, findsOneWidget);
        await tester.tap(qrisSwitch);
        await tester.pumpAndSettle();

        // Tap Save Button
        final saveButton = find.byKey(
          const Key('save_payment_settings_button'),
        );
        await tester.tap(saveButton);
        await tester.pumpAndSettle();

        expect(updateCalled, isTrue);
        expect(
          find.text('Konfigurasi metode pembayaran berhasil disimpan.'),
          findsOneWidget,
        );

        // Verify the UI toggles reflect the updated state directly
        final Switch ewalletWidget = tester.widget(ewalletSwitch);
        expect(ewalletWidget.value, isFalse);

        final Switch qrisWidget = tester.widget(qrisSwitch);
        expect(qrisWidget.value, isFalse);
      },
    );
  });
}

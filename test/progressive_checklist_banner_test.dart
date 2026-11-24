import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/cashier/providers/cashier_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/widgets/progressive_checklist_banner.dart';
import 'package:rentcore_mobile/features/organization/presentation/payment_method_settings_screen.dart';

class _FakeChecklistAuthRepository extends AuthRepository {
  final Map<int, bool> dismissedMap = {};

  @override
  Future<bool> isChecklistDismissed(int? businessId) async {
    if (businessId == null) return false;
    return dismissedMap[businessId] ?? false;
  }

  @override
  Future<void> setChecklistDismissed(int businessId, bool dismissed) async {
    dismissedMap[businessId] = dismissed;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
      'ProgressiveChecklistBanner renders 3 Airy steps for Owner, tracks progress, and dismisses cleanly',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();

    final testBiz = {
      'id': 101,
      'name': 'Skyrental Jember',
      'role': 'owner',
      'payment_methods_config': {
        'is_dynamic_qris_enabled': true, // step 3 done
      },
      'branches': [
        {'id': 201, 'name': 'Pusat', 'code': 'PST', 'is_central': true}
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
          paymentSettingsProvider.overrideWith(
            (ref, _) => Future.value(<String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalModelCount: 1, // step 1 done
              totalAssetCount: 0, // step 2 pending
            ),
          ),
        ),
      ),
    );

    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container
        .read(businessProvider.notifier)
        .loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner_setup_checklist_card')), findsOneWidget);
    expect(find.text('Panduan Persiapan Toko'), findsOneWidget);
    // 2 of 3 completed: Create Model (yes), Register Unit (no), Payment/QRIS (yes)
    expect(find.text('2 dari 3 langkah selesai'), findsOneWidget);

    expect(find.text('Buat Model & Tarif Pertama'), findsOneWidget);
    expect(find.text('Daftarkan Unit Fisik Pertama'), findsOneWidget);
    expect(find.text('Atur Metode Pembayaran / QRIS'), findsOneWidget);

    // Dismiss banner
    await tester.tap(find.byKey(const Key('checklist_dismiss_button')));
    await tester.pumpAndSettle();

    expect(find.text('Panduan Persiapan Toko'), findsNothing);
    expect(fakeRepo.dismissedMap[101], isTrue);
  });

  testWidgets(
      'ProgressiveChecklistBanner auto-hides when all 3 steps complete and hides for staff role',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();

    final completedOwnerBiz = {
      'id': 102,
      'name': 'Branch QRIS Rental',
      'role': 'owner',
      'payment_methods_config': null,
      'branches': [
        {
          'id': 202,
          'name': 'Cabang Utama',
          'code': 'UTM',
          'is_central': true,
          'qris_raw_payload': '0002010102116304ABCD',
        }
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
          paymentSettingsProvider.overrideWith(
            (ref, _) => Future.value(<String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalModelCount: 2,
              totalAssetCount: 2,
            ),
          ),
        ),
      ),
    );

    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container
        .read(businessProvider.notifier)
        .loadInitialContext(preloadedBusinesses: [completedOwnerBiz]);
    await tester.pumpAndSettle();

    // 3/3 completed -> auto-hides
    expect(find.byKey(const Key('owner_setup_checklist_card')), findsNothing);

    // Switch to invited staff business -> hidden even at 0/3
    final staffBiz = {
      'id': 103,
      'name': 'Staff Toko',
      'role': 'staff',
      'payment_methods_config': null,
      'branches': [
        {'id': 203, 'name': 'Cabang Utama', 'code': 'UTM', 'is_central': true}
      ],
    };
    await container
        .read(businessProvider.notifier)
        .loadInitialContext(preloadedBusinesses: [staffBiz]);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('owner_setup_checklist_card')), findsNothing);
  });

  testWidgets(
      'Tapping "Atur Metode Pembayaran / QRIS" opens PaymentMethodSettingsScreen',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();
    final testBiz = {
      'id': 104,
      'name': 'Payment Setup Biz',
      'role': 'owner',
      'branches': [
        {'id': 204, 'name': 'Pusat', 'code': 'PST', 'is_central': true}
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
          paymentSettingsProvider.overrideWith(
            (ref, _) => Future.value(<String, dynamic>{}),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalModelCount: 0,
              totalAssetCount: 0,
            ),
          ),
        ),
      ),
    );

    final container =
        ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container
        .read(businessProvider.notifier)
        .loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Atur Metode Pembayaran / QRIS'));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentMethodSettingsScreen), findsOneWidget);
  });
}

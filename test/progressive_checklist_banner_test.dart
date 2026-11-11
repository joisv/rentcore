import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/features/auth/data/auth_repository.dart';
import 'package:rentcore_mobile/features/auth/providers/auth_provider.dart';
import 'package:rentcore_mobile/features/auth/providers/business_provider.dart';
import 'package:rentcore_mobile/features/home/presentation/widgets/progressive_checklist_banner.dart';
import 'package:rentcore_mobile/core/models/thermal_printer_models.dart';
import 'package:rentcore_mobile/features/printer/presentation/printer_settings_screen.dart';
import 'package:rentcore_mobile/features/printer/presentation/receipt_customization_screen.dart';
import 'package:rentcore_mobile/features/printer/providers/printer_provider.dart';

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

  testWidgets('ProgressiveChecklistBanner renders items and progress accurately',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();

    final testBiz = {
      'id': 101,
      'name': 'Skyrental Jember',
      'phone': '081234567890', // hasProfile true
      'address': 'Jl. Kalimantan No. 12',
      'payment_methods_config': {
        'is_dynamic_qris_enabled': true, // hasQris true
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
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalAssetCount: 5, // hasUnits true
            ),
          ),
        ),
      ),
    );

    // Provide active business to state
    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(businessProvider.notifier).loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    expect(find.text('Panduan Persiapan Toko'), findsOneWidget);
    // 3 of 4 completed: Profile (yes), Units (yes, count 5), QRIS (yes), Printer (pending)
    expect(find.text('3 dari 4 Selesai'), findsOneWidget);

    expect(find.text('Lengkapi Profil Usaha'), findsOneWidget);
    expect(find.text('Daftarkan Unit Pertama'), findsOneWidget);
    expect(find.text('Atur Metode Pembayaran QRIS'), findsOneWidget);
    expect(find.text('Hubungkan Printer Thermal'), findsOneWidget);

    // Dismiss banner
    await tester.tap(find.byTooltip('Sembunyikan Panduan'));
    await tester.pumpAndSettle();

    // Banner is dismissed and hidden
    expect(find.text('Panduan Persiapan Toko'), findsNothing);
  });

  testWidgets('ProgressiveChecklistBanner marks QRIS complete when branch override has qris_raw_payload',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();

    final testBiz = {
      'id': 102,
      'name': 'Branch QRIS Rental',
      'phone': '081234567890',
      'address': 'Jl. Tidar No. 5',
      // Business-level QRIS is not set
      'payment_methods_config': null,
      'branches': [
        {
          'id': 202,
          'name': 'Cabang Utama',
          'code': 'UTM',
          'is_central': true,
          // Branch-level QRIS is configured
          'qris_raw_payload': '00020101021126570014ID.LINKAJA.WWW011893600911002100650902081000650951440014ID.CO.QRIS.WWW0215ID10200210065090303UMI5204599953033605802ID5913RENTAL STORE6006JEMBER61056812162070703A016304ABCD',
        }
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalAssetCount: 2,
            ),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(businessProvider.notifier).loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    // 3 of 4: Profile (yes), Units (yes), QRIS (yes from branch qris_raw_payload)
    expect(find.text('3 dari 4 Selesai'), findsOneWidget);
  });

  testWidgets('Tapping "Hubungkan Printer Thermal" navigates to PrinterSettingsScreen instead of ReceiptCustomizationScreen',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();
    final testBiz = {
      'id': 103,
      'name': 'Printer Nav Test Biz',
      'branches': [
        {'id': 203, 'name': 'Pusat', 'code': 'PST', 'is_central': true}
      ],
    };

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(totalAssetCount: 0),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(businessProvider.notifier).loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    final printerTile = find.text('Hubungkan Printer Thermal');
    expect(printerTile, findsOneWidget);

    await tester.tap(printerTile);
    await tester.pumpAndSettle();

    // Verify PrinterSettingsScreen is opened, NOT ReceiptCustomizationScreen
    expect(find.byType(PrinterSettingsScreen), findsOneWidget);
    expect(find.byType(ReceiptCustomizationScreen), findsNothing);
  });

  testWidgets('ProgressiveChecklistBanner marks printer complete when thermal printer is paired or connected',
      (tester) async {
    final fakeRepo = _FakeChecklistAuthRepository();
    final testBiz = {
      'id': 104,
      'name': 'Paired Printer Biz',
      'phone': '081234567890', // hasProfile true
      'address': 'Jl. Mastrip 45',
      'payment_methods_config': {
        'is_dynamic_qris_enabled': true, // hasQris true
      },
      'branches': [
        {'id': 204, 'name': 'Pusat', 'code': 'PST', 'is_central': true}
      ],
    };

    const pairedPrinterState = PrinterState(
      connectedDevice: ThermalPrinterDevice(
        name: 'Zjiang PT-210',
        address: '66:22:33:44:55:66',
        isConnected: true,
      ),
      status: PrinterConnectionStatus.connected,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
          businessProvider.overrideWith(BusinessNotifier.new),
          printerProvider.overrideWith(() => _MockPrinterNotifier(pairedPrinterState)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: ProgressiveChecklistBanner(
              totalAssetCount: 3, // hasUnits true
            ),
          ),
        ),
      ),
    );

    final container = ProviderScope.containerOf(tester.element(find.byType(Scaffold)));
    await container.read(businessProvider.notifier).loadInitialContext(preloadedBusinesses: [testBiz]);
    await tester.pumpAndSettle();

    // All 4 of 4 completed: Profile, Units, QRIS, Printer
    expect(find.text('4 dari 4 Selesai'), findsOneWidget);
  });
}

class _MockPrinterNotifier extends PrinterNotifier {
  final PrinterState _initial;
  _MockPrinterNotifier(this._initial);

  @override
  PrinterState build() => _initial;
}

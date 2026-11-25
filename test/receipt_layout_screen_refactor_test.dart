import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sewakasir/core/models/thermal_printer_models.dart';
import 'package:sewakasir/features/auth/providers/business_provider.dart';
import 'package:sewakasir/features/printer/presentation/receipt_customization_screen.dart';
import 'package:sewakasir/features/printer/providers/printer_provider.dart';

class _FakeBusinessNotifierForReceiptTest extends BusinessNotifier {
  @override
  BusinessState build() => const BusinessState(
        activeBusinessId: 1,
        activeBusinessName: 'Rentcore Pusat Jember',
        activeBranchId: 1,
        activeBranchName: 'Cabang Utama',
        businesses: [
          {
            'id': 1,
            'name': 'Rentcore Pusat Jember',
            'role': 'owner',
            'branches': [
              {'id': 1, 'name': 'Cabang Utama', 'is_central': true},
            ],
          }
        ],
      );
}

class _CustomSettingsPrinterNotifier extends PrinterNotifier {
  final ReceiptCustomizationSettings? initialSettings;
  _CustomSettingsPrinterNotifier({this.initialSettings});

  @override
  PrinterState build() {
    final base = super.build();
    if (initialSettings != null) {
      return base.copyWith(settings: initialSettings!);
    }
    return base;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget buildScreen({ReceiptCustomizationSettings? initialSettings}) {
    return ProviderScope(
      overrides: [
        businessProvider.overrideWith(() => _FakeBusinessNotifierForReceiptTest()),
        printerProvider.overrideWith(
          () => _CustomSettingsPrinterNotifier(initialSettings: initialSettings),
        ),
      ],
      child: const MaterialApp(
        home: ReceiptCustomizationScreen(),
      ),
    );
  }

  group('Receipt Layout Screen Refactor & Overflow Fix Tests', () {
    testWidgets(
      '1. Live Preview Header renders without RenderFlex overflow on compact 360px viewport',
      (tester) async {
        // Strict narrow mobile viewport (e.g. 360x640 dp)
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Must not throw any RenderFlex overflow exceptions
        expect(tester.takeException(), isNull);

        // Header text and paper width badge exist
        expect(find.text('PRATINJAU LANGSUNG'), findsOneWidget);
        expect(find.text('58mm Standar'), findsOneWidget);

        // Segmented Control labels normalized
        expect(find.text('Standar (58mm)'), findsOneWidget);
        expect(find.text('Kompak'), findsOneWidget);
        expect(find.text('Standard (Kertas Thermal)'), findsNothing);
        expect(find.text('Echo (Kompak)'), findsNothing);
      },
    );

    testWidgets(
      '2. Switching between Standar (58mm) and Kompak updates Live Preview with zero overflow warnings',
      (tester) async {
        tester.view.physicalSize = const Size(375, 812);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Switch to Kompak (Echo)
        final kompakTab = find.text('Kompak');
        await tester.tap(kompakTab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('MODE ECHO • KOMPAK (58MM)'), findsOneWidget);

        // Switch back to Standar (58mm)
        final standardTab = find.text('Standar (58mm)');
        await tester.tap(standardTab);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('TEAR BAR MANUAL (58MM)'), findsOneWidget);
      },
    );

    testWidgets(
      '3. Streamlined save action: text button in AppBar, duplicate bottom save button removed',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Top-right AppBar text button "Simpan" exists
        expect(find.byKey(const Key('receipt_layout_save_button')), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Simpan'), findsOneWidget);

        // Ambiguous checkmark icon button and bottom diskette button removed
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        expect(find.text('Simpan Pengaturan Desain'), findsNothing);
      },
    );

    testWidgets(
      '4. Reset button shows confirmation dialog before restoring default settings',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Tap Reset in AppBar
        final resetBtn = find.byKey(const Key('receipt_layout_reset_button'));
        expect(resetBtn, findsOneWidget);
        await tester.tap(resetBtn);
        await tester.pumpAndSettle();

        // Verify confirmation dialog
        expect(find.text('Reset Pengaturan Struk?'), findsOneWidget);
        expect(find.text('Semua perubahan desain struk akan dikembalikan ke pengaturan bawaan toko. Lanjutkan?'), findsOneWidget);
        expect(find.text('Batal'), findsOneWidget);
        expect(find.text('Reset ke Bawaan'), findsOneWidget);

        // Dismiss via Batal
        await tester.tap(find.text('Batal'));
        await tester.pumpAndSettle();
        expect(find.text('Reset Pengaturan Struk?'), findsNothing);
      },
    );

    testWidgets(
      '5. Toggles use subtle dividers and footer fields are styled TextFormField containers with character limits',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        // Verify subtle dividers exist
        final subtleDividers = find.byWidgetPredicate(
          (w) => w is Divider && w.color == Colors.grey.shade100,
        );
        expect(subtleDividers, findsWidgets);

        // Verify footer text fields exist as styled TextFormField with maxLength
        final klausulField = find.widgetWithText(TextFormField, 'Klausul Pengembalian');
        final pesanPenutupField = find.widgetWithText(TextFormField, 'Pesan Penutup / Ucapan Terima Kasih');

        expect(klausulField, findsOneWidget);
        expect(pesanPenutupField, findsOneWidget);

        // Verify character counter display (e.g. /150 and /120)
        expect(find.textContaining('/150'), findsOneWidget);
        expect(find.textContaining('/120'), findsOneWidget);
      },
    );

    testWidgets(
      '6. Parent ListView has bottom: 40 padding for gesture bar clearance',
      (tester) async {
        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildScreen());
        await tester.pumpAndSettle();

        final listViewFinder = find.byWidgetPredicate((w) {
          if (w is ListView && w.padding is EdgeInsets) {
            final padding = w.padding as EdgeInsets;
            return padding.bottom == 40.0;
          }
          return false;
        });
        expect(listViewFinder, findsOneWidget);
      },
    );

    testWidgets(
      '7. Live Preview updates reactively when 80mm paper width is selected with zero overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        // Initialized with 80mm paper width
        final custom80mmSettings = ReceiptCustomizationSettings.defaultSettings().copyWith(
          paperWidth: ReceiptPaperWidth.mm80,
        );

        await tester.pumpWidget(buildScreen(initialSettings: custom80mmSettings));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('PRATINJAU LANGSUNG'), findsOneWidget);
        expect(find.text('80mm POS'), findsOneWidget);
      },
    );
  });
}

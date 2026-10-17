import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rentcore_mobile/core/services/printer_bluetooth_driver.dart';
import 'package:rentcore_mobile/core/services/thermal_printer_service.dart';
import 'package:rentcore_mobile/features/printer/presentation/printer_settings_screen.dart';
import 'package:rentcore_mobile/features/printer/presentation/receipt_customization_screen.dart';
import 'package:rentcore_mobile/features/printer/providers/printer_provider.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ThermalPrinterService().setDriver(MockPrinterDriver());
    ThermalPrinterService().setConnectedDevice(null);
  });

  Widget buildTestableWidget(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('PrinterSettingsScreen UI Widget Tests', () {
    testWidgets('renders header, configuration chips, and quick action buttons', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrinterSettingsScreen()));
      await tester.pumpAndSettle();

      // Check AppBar Title
      expect(find.text('Pengaturan Printer Thermal'), findsOneWidget);

      // Check Hardware Options
      expect(find.text('KONFIGURASI PERANGKAT KERAS'), findsOneWidget);
      expect(find.text('58mm Portabel'), findsOneWidget);
      expect(find.text('80mm POS'), findsOneWidget);
      expect(find.text('Normal'), findsOneWidget);
      expect(find.text('Echo'), findsOneWidget);

      // Check Quick Action Buttons
      expect(find.text('Test Print'), findsOneWidget);
      expect(find.text('Desain Struk'), findsOneWidget);
    });

    testWidgets('toggling paper width and print mode updates settings', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrinterSettingsScreen()));
      await tester.pumpAndSettle();

      // Tap 80mm
      await tester.tap(find.text('80mm POS'));
      await tester.pumpAndSettle();

      // Tap Echo
      await tester.tap(find.text('Echo'));
      await tester.pumpAndSettle();

      // Should display Echo mode banner
      expect(find.textContaining('Mode Echo Aktif'), findsOneWidget);
    });

    testWidgets('tapping Desain Struk opens ReceiptCustomizationScreen', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrinterSettingsScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Desain Struk'));
      await tester.pumpAndSettle();

      expect(find.byType(ReceiptCustomizationScreen), findsOneWidget);
      expect(find.text('Desain & Layout Struk'), findsOneWidget);
      expect(find.text('PRATINJAU LANGSUNG (LIVE PREVIEW)'), findsOneWidget);
    });

    testWidgets('tapping Test Print in Normal mode without connected printer shows error feedback', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrinterSettingsScreen()));
      await tester.pumpAndSettle();

      // Tap Test Print in Normal mode without connected printer
      await tester.tap(find.text('Test Print'));
      await tester.pumpAndSettle();

      // Should show error feedback (both card banner and SnackBar)
      expect(find.textContaining('Belum ada printer yang dipilih'), findsAtLeastNWidgets(1));
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('tapping Test Print in Echo mode without connected printer shows error feedback', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const PrinterSettingsScreen()));
      await tester.pumpAndSettle();

      // Switch to Echo mode
      await tester.tap(find.text('Echo'));
      await tester.pumpAndSettle();

      // Tap Test Print in Echo mode without connected printer
      await tester.tap(find.text('Test Print'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should show error feedback (both card banner and SnackBar)
      expect(find.textContaining('Belum ada printer yang dipilih'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping Test Print in Echo mode with connected printer executes successfully', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const device = ThermalPrinterDevice(
        name: 'Echo Test Thermal Printer',
        address: '11:22:33:44:55:66',
        isConnected: true,
      );

      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(() => ThermalPrinterService().setConnectedDevice(null));

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: PrinterSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Connect device via notifier
      await container.read(printerProvider.notifier).connectDevice(device);
      await tester.pumpAndSettle();

      // Switch to Echo mode
      await tester.tap(find.text('Echo'));
      await tester.pumpAndSettle();

      // Tap Test Print in Echo mode
      await tester.tap(find.text('Test Print'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      // Should show Echo success SnackBar
      expect(find.textContaining('Test print [ECHO] berhasil dikirim!'), findsOneWidget);
    });
  });

  group('ReceiptCustomizationScreen UI Widget Tests', () {
    testWidgets('renders preview and allows editing fields and toggling options', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ReceiptCustomizationScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Desain & Layout Struk'), findsOneWidget);
      expect(find.text('PRATINJAU LANGSUNG (LIVE PREVIEW)'), findsOneWidget);
      expect(find.text('STRUK SEWA PERANGKAT'), findsOneWidget);

      // Verify toggles
      expect(find.text('Tampilkan Nama Kasir'), findsOneWidget);
      expect(find.text('Tampilkan Nomor Telepon Pelanggan'), findsOneWidget);
      expect(find.text('Sensor Nomor HP (Privasi Masking)'), findsOneWidget);

      // Test editing custom store name
      final shopNameField = find.widgetWithText(TextField, 'Nama Usaha / Toko');
      expect(shopNameField, findsOneWidget);
      await tester.enterText(shopNameField, 'TOKO GADGET SUPER');
      await tester.pumpAndSettle();

      // Verify preview paper contains updated text
      expect(find.text('TOKO GADGET SUPER'), findsAtLeastNWidgets(1));

      // Test Reset button
      final resetButton = find.text('Reset');
      expect(resetButton, findsOneWidget);
      await tester.tap(resetButton);
      await tester.pumpAndSettle();

      // Save button exists
      expect(find.text('Simpan Pengaturan Desain'), findsOneWidget);
    });

    testWidgets('switching between Standard and Echo preview tabs updates layout and allows per-mode printing', (tester) async {
      await tester.pumpWidget(buildTestableWidget(const ReceiptCustomizationScreen()));
      await tester.pumpAndSettle();

      // Check preview tab buttons exist
      expect(find.text('Standard (Kertas Thermal)'), findsOneWidget);
      expect(find.text('Echo (Kompak)'), findsOneWidget);

      // Initially in Standard mode: tear bar indicator and Print Standard button are visible
      expect(find.text('TEAR BAR MANUAL (58MM)'), findsOneWidget);
      final printStandardBtn = find.text('Print Standard');
      expect(printStandardBtn, findsOneWidget);

      // Tap Print Standard without connected device (handles error gracefully)
      await tester.ensureVisible(printStandardBtn);
      await tester.pumpAndSettle();
      await tester.tap(printStandardBtn);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.textContaining('Belum ada printer yang dipilih'), findsOneWidget);

      // Switch to Echo mode preview
      final echoTab = find.text('Echo (Kompak)');
      await tester.ensureVisible(echoTab);
      await tester.pumpAndSettle();
      await tester.tap(echoTab);
      await tester.pumpAndSettle();

      // Echo clean thermal paper elements should now be visible
      expect(find.text('MODE ECHO • KOMPAK (58MM)'), findsOneWidget);
      final printEchoBtn = find.text('Print Echo');
      expect(printEchoBtn, findsOneWidget);

      // Tap Print Echo without connected device (handles error gracefully)
      await tester.ensureVisible(printEchoBtn);
      await tester.pumpAndSettle();
      await tester.tap(printEchoBtn);
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Verify SnackBar feedback
      expect(find.textContaining('Belum ada printer yang dipilih'), findsOneWidget);

      // Switch back to Standard mode preview
      final standardTab = find.text('Standard (Kertas Thermal)');
      await tester.ensureVisible(standardTab);
      await tester.pumpAndSettle();
      await tester.tap(standardTab);
      await tester.pumpAndSettle();

      // Standard mode tear bar and Print Standard should be visible again
      expect(find.text('TEAR BAR MANUAL (58MM)'), findsOneWidget);
      expect(find.text('Print Standard'), findsOneWidget);
    });
  });
}

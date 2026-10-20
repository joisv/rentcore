import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/thermal_printer_service.dart';

const String _kPrinterSettingsKey = 'rentcore_printer_settings_v1';
const String _kPrinterSavedDeviceKey = 'rentcore_printer_saved_device_v1';

class PrinterState {
  final ThermalPrinterDevice? connectedDevice;
  final List<ThermalPrinterDevice> discoveredDevices;
  final PrinterConnectionStatus status;
  final ReceiptCustomizationSettings settings;
  final bool isScanning;
  final bool isConnecting;
  final bool isPrinting;
  final String? lastEchoLog;
  final String? errorMessage;

  const PrinterState({
    this.connectedDevice,
    this.discoveredDevices = const [],
    this.status = PrinterConnectionStatus.disconnected,
    this.settings = const ReceiptCustomizationSettings(),
    this.isScanning = false,
    this.isConnecting = false,
    this.isPrinting = false,
    this.lastEchoLog,
    this.errorMessage,
  });

  PrinterState copyWith({
    ThermalPrinterDevice? connectedDevice,
    bool clearConnectedDevice = false,
    List<ThermalPrinterDevice>? discoveredDevices,
    PrinterConnectionStatus? status,
    ReceiptCustomizationSettings? settings,
    bool? isScanning,
    bool? isConnecting,
    bool? isPrinting,
    String? lastEchoLog,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PrinterState(
      connectedDevice: clearConnectedDevice ? null : (connectedDevice ?? this.connectedDevice),
      discoveredDevices: discoveredDevices ?? this.discoveredDevices,
      status: status ?? this.status,
      settings: settings ?? this.settings,
      isScanning: isScanning ?? this.isScanning,
      isConnecting: isConnecting ?? this.isConnecting,
      isPrinting: isPrinting ?? this.isPrinting,
      lastEchoLog: lastEchoLog ?? this.lastEchoLog,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final printerProvider = NotifierProvider<PrinterNotifier, PrinterState>(() {
  return PrinterNotifier();
});

class PrinterNotifier extends Notifier<PrinterState> {
  late final ThermalPrinterService _service;

  @override
  PrinterState build() {
    _service = ThermalPrinterService();
    Future.microtask(() => _init());
    return const PrinterState();
  }

  Future<void> _init() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Load saved customization settings
      final settingsJson = prefs.getString(_kPrinterSettingsKey);
      ReceiptCustomizationSettings settings = const ReceiptCustomizationSettings();
      if (settingsJson != null) {
        try {
          final decoded = json.decode(settingsJson) as Map<String, dynamic>;
          settings = ReceiptCustomizationSettings.fromJson(decoded);
        } catch (e) {
          debugPrint('[PrinterNotifier] Error parsing saved settings: $e');
        }
      }

      // 2. Load saved device
      final deviceJson = prefs.getString(_kPrinterSavedDeviceKey);
      ThermalPrinterDevice? device;
      if (deviceJson != null) {
        try {
          final decoded = json.decode(deviceJson) as Map<String, dynamic>;
          device = ThermalPrinterDevice.fromJson(decoded);
        } catch (e) {
          debugPrint('[PrinterNotifier] Error parsing saved device: $e');
        }
      }

      // Fallback: if no saved device, check ThermalPrinterService current device
      device ??= _service.connectedDevice;

      // Verify active hardware connection status
      bool isActuallyConnected = false;
      if (device != null) {
        try {
          isActuallyConnected = await _service.driver.isConnected();
        } catch (_) {
          isActuallyConnected = false;
        }
        device = device.copyWith(isConnected: isActuallyConnected);
      }
      _service.setConnectedDevice(device);

      state = state.copyWith(
        settings: settings,
        connectedDevice: device,
        status: isActuallyConnected
            ? PrinterConnectionStatus.connected
            : PrinterConnectionStatus.disconnected,
      );
    } catch (e) {
      debugPrint('[PrinterNotifier] _init error: $e');
    }
  }

  Future<void> scanDevices() async {
    if (state.isScanning) return;

    state = state.copyWith(
      isScanning: true,
      status: PrinterConnectionStatus.scanning,
      clearError: true,
    );

    try {
      final hasPerm = await _service.driver.checkAndRequestPermissions();
      if (!hasPerm) {
        state = state.copyWith(
          isScanning: false,
          status: PrinterConnectionStatus.error,
          errorMessage: 'Izin Bluetooth belum diberikan. Mohon izinkan Bluetooth di Pengaturan.',
        );
        return;
      }

      final isBtOn = await _service.driver.isBluetoothAvailable();
      if (!isBtOn) {
        state = state.copyWith(
          isScanning: false,
          status: PrinterConnectionStatus.error,
          errorMessage: 'Bluetooth nonaktif. Silakan nyalakan Bluetooth Anda terlebih dahulu.',
        );
        return;
      }

      final devices = await _service.driver.startDiscovery();

      // Deduplicate devices by address
      final uniqueMap = <String, ThermalPrinterDevice>{};
      for (final d in devices) {
        if (d.address.isNotEmpty) {
          uniqueMap[d.address] = d;
        }
      }

      state = state.copyWith(
        isScanning: false,
        discoveredDevices: uniqueMap.values.toList(),
        status: (state.connectedDevice != null && state.connectedDevice!.isConnected)
            ? PrinterConnectionStatus.connected
            : PrinterConnectionStatus.disconnected,
      );
    } catch (e) {
      state = state.copyWith(
        isScanning: false,
        status: PrinterConnectionStatus.error,
        errorMessage: 'Gagal mencari printer Bluetooth: $e',
      );
    }
  }

  Future<bool> connectDevice(ThermalPrinterDevice device) async {
    if (state.isConnecting) return false;

    state = state.copyWith(
      isConnecting: true,
      status: PrinterConnectionStatus.connecting,
      clearError: true,
    );

    try {
      final isBtOn = await _service.driver.isBluetoothAvailable();
      if (!isBtOn) {
        state = state.copyWith(
          isConnecting: false,
          status: PrinterConnectionStatus.error,
          errorMessage: 'Bluetooth nonaktif. Silakan nyalakan Bluetooth Anda terlebih dahulu.',
        );
        return false;
      }

      final success = await _service.driver.connect(device.address);
      if (success) {
        final connected = device.copyWith(isConnected: true);
        _service.setConnectedDevice(connected);

        // Persist saved device
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_kPrinterSavedDeviceKey, json.encode(connected.toJson()));

        state = state.copyWith(
          isConnecting: false,
          connectedDevice: connected,
          status: PrinterConnectionStatus.connected,
        );
        return true;
      } else {
        state = state.copyWith(
          isConnecting: false,
          status: PrinterConnectionStatus.error,
          errorMessage: 'Gagal terhubung ke ${device.name}. Pastikan printer menyala dan dalam jarak dekat.',
        );
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        status: PrinterConnectionStatus.error,
        errorMessage: 'Terjadi kesalahan saat menghubungkan: $e',
      );
      return false;
    }
  }

  Future<void> disconnect() async {
    try {
      await _service.driver.disconnect();
      _service.setConnectedDevice(null);

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPrinterSavedDeviceKey);

      state = state.copyWith(
        clearConnectedDevice: true,
        status: PrinterConnectionStatus.disconnected,
      );
    } catch (e) {
      debugPrint('[PrinterNotifier] Disconnect error: $e');
    }
  }

  Future<void> saveSettings(ReceiptCustomizationSettings newSettings) async {
    state = state.copyWith(settings: newSettings);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kPrinterSettingsKey, json.encode(newSettings.toJson()));
    } catch (e) {
      debugPrint('[PrinterNotifier] Save settings error: $e');
    }
  }

  Future<void> setPaperWidth(ReceiptPaperWidth width) async {
    final updated = state.settings.copyWith(paperWidth: width);
    await saveSettings(updated);
  }

  Future<void> setPrintMode(PrintMode mode) async {
    final updated = state.settings.copyWith(printMode: mode);
    await saveSettings(updated);
  }

  Future<bool> printTestReceipt() async {
    if (state.isPrinting) return false;
    state = state.copyWith(isPrinting: true, clearError: true);
    try {
      if (state.connectedDevice == null) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: 'Belum ada printer yang dipilih. Silakan hubungkan printer dari daftar.',
        );
        return false;
      }

      final isBtOn = await _service.driver.isBluetoothAvailable();
      if (!isBtOn) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: 'Bluetooth nonaktif. Silakan nyalakan Bluetooth Anda terlebih dahulu.',
        );
        return false;
      }

      Uint8List bytes;
      if (state.settings.printMode == PrintMode.echo) {
        final sampleData = _service.getSampleBookingReceipt(state.settings);
        final doc = _service.buildReceiptDocument(sampleData, state.settings, PrintMode.echo);
        bytes = _service.buildSlipBytesFromDocument(doc, state.settings);
      } else {
        bytes = _service.buildTestSlipBytes(state.settings);
      }

      final success = await _service.sendPrintJob(bytes, state.settings.printMode);

      if (!success) {
        final err = _service.lastError ?? 'Gagal mengirim test print. Periksa koneksi printer.';
        state = state.copyWith(
          isPrinting: false,
          errorMessage: err,
        );
        return false;
      }

      state = state.copyWith(
        isPrinting: false,
        status: PrinterConnectionStatus.connected,
        connectedDevice: state.connectedDevice?.copyWith(isConnected: true),
        lastEchoLog: state.settings.printMode == PrintMode.echo
            ? '[ECHO CETAK BERHASIL]\n'
                'Waktu: ${DateTime.now().toString().substring(0, 19)}\n'
                'Ukuran: ${state.settings.paperWidth.label}\n'
                'Status: Sukses Dicetak (Format Kompak)'
            : null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        errorMessage: 'Gagal mengirim test print: $e',
      );
      return false;
    }
  }

  Future<bool> printReceipt(ReceiptDataModel data) async {
    if (state.isPrinting) return false;
    state = state.copyWith(isPrinting: true, clearError: true);
    try {
      if (state.connectedDevice == null) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: 'Belum ada printer yang dipilih atau terhubung.',
        );
        return false;
      }

      final isBtOn = await _service.driver.isBluetoothAvailable();
      if (!isBtOn) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: 'Bluetooth nonaktif. Silakan nyalakan Bluetooth Anda.',
        );
        return false;
      }

      Uint8List bytes;
      if (state.settings.printMode == PrintMode.echo) {
        final doc = _service.buildReceiptDocument(data, state.settings, PrintMode.echo);
        bytes = _service.buildSlipBytesFromDocument(doc, state.settings);
      } else {
        switch (data.type) {
          case ReceiptType.rentalBooking:
            bytes = _service.buildRentalBookingSlipBytes(data, state.settings);
            break;
          case ReceiptType.posPayment:
            bytes = _service.buildPosPaymentSlipBytes(data, state.settings);
            break;
          case ReceiptType.rentalReturn:
            bytes = _service.buildRentalReturnSlipBytes(data, state.settings);
            break;
          case ReceiptType.rentalExchange:
            final doc = _service.buildReceiptDocument(data, state.settings);
            bytes = _service.buildSlipBytesFromDocument(doc, state.settings);
            break;
          case ReceiptType.closingShift:
            bytes = _service.buildClosingShiftSlipBytes(
              branchName: data.branchName,
              cashierName: data.cashierName ?? 'Kasir',
              date: data.transactedAt ?? DateTime.now().toString().substring(0, 16),
              totalTransactions: data.shiftTotalTransactions ?? 1,
              totalRevenue: data.totalAmount,
              paymentBreakdown: data.shiftBreakdown ?? {'Tunai': data.totalAmount},
            );
            break;
          case ReceiptType.voucherSlip:
            bytes = _service.buildVoucherSlipBytes(
              shopName: data.shopName ?? 'RENTCORE GADGETS',
              branchName: data.branchName,
              voucherCode: data.bookingCode ?? 'PROMO',
              discountPercentage: data.discount ?? 10.0,
              minTransaction: data.subtotal ?? 100000.0,
              validUntil: data.rentalEndDate ?? '-',
            );
            break;
          case ReceiptType.testPrint:
            bytes = _service.buildTestSlipBytes(state.settings);
            break;
        }
      }

      final success = await _service.sendPrintJob(bytes, state.settings.printMode);

      if (!success) {
        final err = _service.lastError ?? 'Gagal mencetak struk transaksi. Periksa koneksi printer.';
        state = state.copyWith(
          isPrinting: false,
          errorMessage: err,
        );
        return false;
      }

      state = state.copyWith(
        isPrinting: false,
        status: PrinterConnectionStatus.connected,
        connectedDevice: state.connectedDevice?.copyWith(isConnected: true),
        lastEchoLog: state.settings.printMode == PrintMode.echo
            ? '[ECHO STRUK]\n'
                'Judul: ${data.title}\n'
                'Ref: ${data.bookingCode ?? data.receiptNumber ?? "-"}\n'
                'Total: Rp ${data.totalAmount.toInt()}\n'
                'Status: Sukses Dicetak (Format Kompak)'
            : null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        errorMessage: 'Gagal mencetak struk: $e',
      );
      return false;
    }
  }
}

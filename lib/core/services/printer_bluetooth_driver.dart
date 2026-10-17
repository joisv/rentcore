import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import '../models/thermal_printer_models.dart';

abstract class PrinterBluetoothDriver {
  Future<bool> checkAndRequestPermissions();
  Future<bool> isBluetoothAvailable();
  Future<List<ThermalPrinterDevice>> getBondedDevices();
  Future<List<ThermalPrinterDevice>> startDiscovery({Duration timeout = const Duration(seconds: 4)});
  Future<bool> connect(String address);
  Future<bool> disconnect();
  Future<bool> writeBytes(Uint8List bytes);
  Future<bool> isConnected();
}

/// Mock driver for headless unit tests, desktop runs, and hardware-less simulation.
class MockPrinterDriver implements PrinterBluetoothDriver {
  final bool simulateDelays;
  MockPrinterDriver({this.simulateDelays = false});

  bool _connected = false;
  String? _connectedAddress;

  final List<ThermalPrinterDevice> _mockBonded = [
    const ThermalPrinterDevice(
      name: 'RPP-02N Bluetooth Printer (58mm)',
      address: '00:11:22:33:44:55',
      isBonded: true,
      deviceType: 'classic',
    ),
    const ThermalPrinterDevice(
      name: 'PT-210 Mobile Printer (80mm)',
      address: '66:77:88:99:AA:BB',
      isBonded: true,
      deviceType: 'classic',
    ),
  ];

  final List<ThermalPrinterDevice> _mockNearby = [
    const ThermalPrinterDevice(
      name: 'Panda PRJ-58D Bluetooth',
      address: '11:22:33:44:55:66',
      rssi: -58,
      deviceType: 'classic',
    ),
    const ThermalPrinterDevice(
      name: 'ZJ-5805 Mini POS',
      address: '22:33:44:55:66:77',
      rssi: -72,
      deviceType: 'ble',
    ),
  ];

  @override
  Future<bool> checkAndRequestPermissions() async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 100));
    return true;
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    return true;
  }

  @override
  Future<List<ThermalPrinterDevice>> getBondedDevices() async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 150));
    return _mockBonded;
  }

  @override
  Future<List<ThermalPrinterDevice>> startDiscovery({Duration timeout = const Duration(seconds: 2)}) async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 400));
    return [..._mockBonded, ..._mockNearby];
  }

  @override
  Future<bool> connect(String address) async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 300));
    _connected = true;
    _connectedAddress = address;
    return true;
  }

  @override
  Future<bool> disconnect() async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 150));
    _connected = false;
    _connectedAddress = null;
    return true;
  }

  @override
  Future<bool> writeBytes(Uint8List bytes) async {
    if (simulateDelays) await Future.delayed(const Duration(milliseconds: 250));
    return _connected;
  }

  @override
  Future<bool> isConnected() async {
    return _connected;
  }
}

/// Concrete driver communicating with physical Bluetooth thermal printers via print_bluetooth_thermal.
class PlatformBluetoothDriver implements PrinterBluetoothDriver {
  static final MockPrinterDriver _fallbackMock = MockPrinterDriver();

  @override
  Future<bool> checkAndRequestPermissions() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.checkAndRequestPermissions();
      }
      return await PrintBluetoothThermal.isPermissionBluetoothGranted;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Permission check error: $e');
      return false;
    }
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.isBluetoothAvailable();
      }
      return await PrintBluetoothThermal.bluetoothEnabled;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Bluetooth check error: $e');
      return false;
    }
  }

  @override
  Future<List<ThermalPrinterDevice>> getBondedDevices() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.getBondedDevices();
      }
      final pairedList = await PrintBluetoothThermal.pairedBluetooths;
      return pairedList.map((d) {
        return ThermalPrinterDevice(
          name: d.name.isNotEmpty ? d.name : 'Unknown Device',
          address: d.macAdress,
          isBonded: true,
          deviceType: 'classic',
        );
      }).toList();
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Bonded devices error: $e');
      return [];
    }
  }

  @override
  Future<List<ThermalPrinterDevice>> startDiscovery({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.startDiscovery(timeout: timeout);
      }
      // PrintBluetoothThermal scan
      // Note: On Android, paired devices are retrieved first, then discovery is initiated.
      final paired = await getBondedDevices();
      return paired;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Discovery error: $e');
      return [];
    }
  }

  @override
  Future<bool> connect(String address) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.connect(address);
      }
      final bool result = await PrintBluetoothThermal.connect(macPrinterAddress: address);
      return result;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Connection error: $e');
      return false;
    }
  }

  @override
  Future<bool> disconnect() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.disconnect();
      }
      return await PrintBluetoothThermal.disconnect;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Disconnection error: $e');
      return false;
    }
  }

  /// print_bluetooth_thermal's Android side does `call.arguments as? List<Int>`.
  /// A [Uint8List] is encoded by the platform channel as `byte[]`, which fails
  /// that cast and makes the plugin silently return `false` without writing.
  /// A plain `List<int>` is encoded as `ArrayList<Integer>` and works.
  @visibleForTesting
  static List<int> toPluginPayload(Uint8List bytes) => List<int>.of(bytes, growable: false);

  @override
  Future<bool> writeBytes(Uint8List bytes) async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.writeBytes(bytes);
      }
      final bool result = await PrintBluetoothThermal.writeBytes(toPluginPayload(bytes));
      debugPrint('[PlatformBluetoothDriver] writeBytes(${bytes.length} bytes) -> $result');
      return result;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] Write error: $e');
      return false;
    }
  }

  @override
  Future<bool> isConnected() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return _fallbackMock.isConnected();
      }
      return await PrintBluetoothThermal.connectionStatus;
    } catch (e) {
      debugPrint('[PlatformBluetoothDriver] ConnectionStatus error: $e');
      return false;
    }
  }
}

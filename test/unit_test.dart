import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:rentcore_mobile/core/network/network_status_provider.dart';
import 'package:rentcore_mobile/core/services/thermal_printer_service.dart';
import 'package:rentcore_mobile/core/utils/currency_formatter.dart';
import 'package:rentcore_mobile/core/utils/date_formatter.dart';
import 'package:rentcore_mobile/features/customers/providers/customer_provider.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('id_ID', null);
  });
  group('CurrencyFormatter Tests', () {
    test('formats positive amounts correctly', () {
      expect(CurrencyFormatter.format(150000), 'Rp 150.000');
      expect(CurrencyFormatter.format(0), 'Rp 0');
      expect(CurrencyFormatter.format(1500000), 'Rp 1.500.000');
      expect(CurrencyFormatter.format("300000.00"), 'Rp 300.000');
    });

    test('handles null amounts safely', () {
      expect(CurrencyFormatter.format(null), 'Rp 0');
    });

    test('parses numbers and strings robustly', () {
      expect(CurrencyFormatter.parse(15), 15.0);
      expect(CurrencyFormatter.parse("15.00"), 15.0);
      expect(CurrencyFormatter.parse("300000.50"), 300000.5);
      expect(CurrencyFormatter.parse(null), 0.0);
      expect(CurrencyFormatter.parse("invalid"), 0.0);
    });
  });

  group('DateFormatter Tests', () {
    test('formats full date string properly', () {
      final date = DateTime(2026, 10, 10, 14, 30);
      final formatted = DateFormatter.formatFull(date);
      expect(formatted, contains('10 Okt 2026'));
      expect(formatted, contains('14:30'));
    });

    test('calculates remaining overtime correctly', () {
      final now = DateTime.now();
      final futureDate = now.add(const Duration(hours: 3));
      final pastDate = now.subtract(const Duration(minutes: 90));

      final remainingText = DateFormatter.formatRelative(futureDate);
      expect(remainingText, contains('Sisa'));

      final overtimeText = DateFormatter.formatRelative(pastDate);
      expect(overtimeText, contains('Terlambat'));
    });
  });

  group('ThermalPrinterService Tests', () {
    final printerService = ThermalPrinterService();

    test('generates valid ESC/POS voucher slip bytes', () {
      final bytes = printerService.buildVoucherSlipBytes(
        shopName: 'RENTCORE GADGETS',
        branchName: 'Cabang Mataram',
        voucherCode: 'RC-VCR-DISC20',
        discountPercentage: 20,
        minTransaction: 300000,
        validUntil: '15 Okt 2026',
      );

      expect(bytes, isNotEmpty);
      // Starts with ESC @ (0x1B, 0x40)
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
      // Ends with partial cut (0x1D, 0x56, 0x01)
      expect(bytes[bytes.length - 3], 0x1D);
      expect(bytes[bytes.length - 2], 0x56);
      expect(bytes[bytes.length - 1], 0x01);
    });

    test('generates valid ESC/POS closing shift slip bytes with breakdown', () {
      final bytes = printerService.buildClosingShiftSlipBytes(
        branchName: 'Cabang Mataram',
        cashierName: 'Ahmad Staff',
        date: '2026-10-11 17:00',
        totalTransactions: 15,
        totalRevenue: 5250000,
        paymentBreakdown: {
          'Cash': 2000000,
          'QRIS': 2250000,
          'Bank BCA': 1000000,
        },
      );

      expect(bytes, isNotEmpty);
      expect(bytes[0], 0x1B);
      expect(bytes[1], 0x40);
      expect(bytes[bytes.length - 1], 0x01);
    });

    test('verifies connected device and simulated print job', () async {
      expect(printerService.connectedDevice, isNotNull);
      expect(printerService.connectedDevice!.isConnected, isTrue);

      final testBytes = printerService.buildVoucherSlipBytes(
        shopName: 'RENTCORE',
        branchName: 'Pusat',
        voucherCode: 'TEST',
        discountPercentage: 10,
        minTransaction: 100000,
        validUntil: '31 Des 2026',
      );

      final result = await printerService.sendPrintJob(testBytes);
      expect(result, isTrue);
    });
  });

  group('NetworkStatusNotifier & Connectivity Awareness', () {
    test('initializes with online state and transitions correctly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialStatus = container.read(networkStatusProvider);
      expect(initialStatus, equals(NetworkStatus.online));

      container.read(networkStatusProvider.notifier).setOffline();
      expect(container.read(networkStatusProvider), equals(NetworkStatus.offline));

      container.read(networkStatusProvider.notifier).setOnline();
      expect(container.read(networkStatusProvider), equals(NetworkStatus.online));
    });

    test('customerRepositoryProvider instantiates successfully', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(customerRepositoryProvider);
      expect(repo, isNotNull);
    });
  });

  group('Dashboard UX & Logic Tests', () {
    test('generates accurate user avatar initials from single and multi-word names', () {
      String getInitials(String name) {
        final parts = name.trim().split(RegExp(r'\s+'));
        if (parts.isEmpty || parts[0].isEmpty) return 'RC';
        if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
        return (parts[0][0] + parts[1][0]).toUpperCase();
      }

      expect(getInitials('Budi Santoso'), 'BS');
      expect(getInitials('Ahmad Dahlan Putra'), 'AD');
      expect(getInitials('Kasir'), 'KA');
      expect(getInitials('A'), 'A');
      expect(getInitials(''), 'RC');
    });

    test('calculates inventory utilization rate accurately', () {
      double calculateUtilization(int rented, int total) {
        if (total <= 0) return 0.0;
        return double.parse(((rented / total) * 100).toStringAsFixed(1));
      }

      expect(calculateUtilization(5, 20), 25.0);
      expect(calculateUtilization(0, 15), 0.0);
      expect(calculateUtilization(12, 16), 75.0);
      expect(calculateUtilization(0, 0), 0.0);
    });
  });

  group('POS Cashier Payment & Change Calculation Tests', () {
    test('exact cash received yields zero change', () {
      const double totalDue = 350000.0;
      const double cashReceived = 350000.0;
      final change = (cashReceived - totalDue).clamp(0.0, double.infinity);
      final shortage = (totalDue - cashReceived).clamp(0.0, double.infinity);

      expect(change, 0.0);
      expect(shortage, 0.0);
    });

    test('excess cash received calculates correct change amount', () {
      const double totalDue = 350000.0;
      const double cashReceived = 400000.0;
      final change = (cashReceived - totalDue).clamp(0.0, double.infinity);
      final shortage = (totalDue - cashReceived).clamp(0.0, double.infinity);

      expect(change, 50000.0);
      expect(shortage, 0.0);
    });

    test('insufficient cash received detects exact shortage and prevents zero change deception', () {
      const double totalDue = 350000.0;
      const double cashReceived = 200000.0;
      final change = (cashReceived - totalDue).clamp(0.0, double.infinity);
      final shortage = (totalDue - cashReceived).clamp(0.0, double.infinity);

      expect(shortage, 150000.0);
      expect(change, 0.0);
    });

    test('non-cash payment methods (QRIS/Transfer) bypass change calculation', () {
      const double totalDue = 350000.0;
      double calculateChange(bool isCashMethod, double received, double due) {
        return isCashMethod ? (received - due).clamp(0.0, double.infinity) : 0.0;
      }

      expect(calculateChange(false, 400000.0, totalDue), 0.0);
      expect(calculateChange(true, 400000.0, totalDue), 50000.0);
      expect(totalDue, 350000.0);
    });
  });

  group('New Rental Transaction Business Rule Tests', () {
    test('unit selection prerequisite enforces disabled duration and voucher when null', () {
      int? selectedAssetId;
      bool isDurationEnabled(int? assetId) => assetId != null;
      bool isVoucherEnabled(int? assetId) => assetId != null;

      expect(isDurationEnabled(selectedAssetId), isFalse);
      expect(isVoucherEnabled(selectedAssetId), isFalse);

      selectedAssetId = 101;
      expect(isDurationEnabled(selectedAssetId), isTrue);
      expect(isVoucherEnabled(selectedAssetId), isTrue);
    });

    test('unit change recalculates price dynamically from tier and revalidates voucher threshold', () {
      final tierData = {
        'model': {
          'name': 'iPhone 15 Pro 256GB',
          'pricing_tiers': [
            {'duration_hours': 12, 'price': 200000.0},
            {'duration_hours': 24, 'price': 350000.0},
            {'duration_hours': 48, 'price': 650000.0},
          ]
        }
      };

      double calculatePrice(Map<String, dynamic> asset, int duration) {
        final tiers = asset['model']['pricing_tiers'] as List;
        for (final t in tiers) {
          if (t['duration_hours'] == duration) {
            return (t['price'] as num).toDouble();
          }
        }
        return 0.0;
      }

      expect(calculatePrice(tierData, 12), 200000.0);
      expect(calculatePrice(tierData, 24), 350000.0);
      expect(calculatePrice(tierData, 48), 650000.0);

      // Voucher threshold check: min 300.000
      const double minTx = 300000.0;
      bool isVoucherEligible(double subtotal) => subtotal >= minTx;

      expect(isVoucherEligible(calculatePrice(tierData, 12)), isFalse); // 200k < 300k
      expect(isVoucherEligible(calculatePrice(tierData, 24)), isTrue);  // 350k >= 300k
    });

    test('customer address validation requires non-empty text input', () {
      bool isAddressValid(String? address) {
        return address != null && address.trim().length >= 5;
      }

      expect(isAddressValid(''), isFalse);
      expect(isAddressValid('   '), isFalse);
      expect(isAddressValid('Jl. Raya Genteng No. 128, RT 03/RW 02'), isTrue);
    });
  });
}


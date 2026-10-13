import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookings/presentation/direct_rental_screen.dart';
import '../providers/cashier_provider.dart';

class CashierScreen extends ConsumerStatefulWidget {
  const CashierScreen({super.key});

  @override
  ConsumerState<CashierScreen> createState() => _CashierScreenState();
}

class _CashierScreenState extends ConsumerState<CashierScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kasir POS & Laporan Closing'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Pengaturan Server',
            onPressed: () => _showServerSettings(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan Data',
            onPressed: () {
              ref.invalidate(closingSummaryProvider);
              ref.invalidate(cashierBookingsProvider(_searchQuery));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.obsidian,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.obsidian,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(
              icon: Icon(Icons.point_of_sale_rounded, size: 20),
              text: 'Meja Kasir POS',
            ),
            Tab(
              icon: Icon(Icons.assessment_outlined, size: 20),
              text: 'Rekap Shift & Closing',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPosTerminalTab(),
          _buildClosingShiftTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: MEJA KASIR POS (TRANSACTION SETTLEMENT)
  // =========================================================================
  Widget _buildPosTerminalTab() {
    final bookingsAsync = ref.watch(cashierBookingsProvider(_searchQuery));

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(cashierBookingsProvider(_searchQuery));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quick Button: New Direct Rental Transaction
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.obsidian,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaksi Sewa Baru',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        Text(
                          'Buat sewa langsung di meja kasir untuk pelanggan baru',
                          style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DirectRentalScreen()),
                      );
                    },
                    child: const Text('Buka'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Search Filter
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Cari kode booking / no. telepon / nama...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                _onSearch();
                              },
                            )
                          : null,
                    ),
                    onSubmitted: (_) => _onSearch(),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(60, 52),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _onSearch,
                  child: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DAFTAR TRANSAKSI SEWA',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.textMuted,
                  ),
                ),
                Text(
                  _searchQuery.isNotEmpty ? 'Pencarian: "$_searchQuery"' : 'Terbaru',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Bookings List
            bookingsAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text('Gagal memuat transaksi: $e', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Coba Lagi'),
                      onPressed: () => ref.refresh(cashierBookingsProvider(_searchQuery)),
                    ),
                  ],
                ),
              ),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          const Icon(Icons.receipt_long_outlined, size: 36, color: AppColors.textMuted),
                          const SizedBox(height: 10),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Tidak ditemukan transaksi dengan kata kunci "$_searchQuery"'
                                : 'Belum ada transaksi sewa yang tercatat.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: bookings.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final b = bookings[index];
                    return _buildBookingPosCard(b);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingPosCard(Map<String, dynamic> b) {
    final customer = b['customer'] as Map? ?? {};
    final items = (b['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? (items[0] as Map) : null;
    final modelName = firstItem?['asset']?['model']?['name'] ?? 'Perangkat Apple';
    final assetCode = firstItem?['asset']?['asset_code'] ?? '';
    final totalBill = CurrencyFormatter.parse(b['total_bill']);
    final paymentStatus = (b['payment_status'] ?? 'paid').toString().toLowerCase();
    final isPaid = paymentStatus == 'paid';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPaid ? AppColors.border : AppColors.danger.withValues(alpha: 0.4),
          width: isPaid ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                b['booking_code'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isPaid ? AppColors.successLight : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? 'LUNAS' : (paymentStatus == 'partial' ? 'SEBAGIAN' : 'BELUM LUNAS'),
                  style: TextStyle(
                    color: isPaid ? AppColors.success : AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                customer['name'] ?? 'Pelanggan',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
              Text(
                ' • ${customer['phone'] ?? ''}',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.smartphone_rounded, size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '$modelName ($assetCode) • ${b['duration_hours']} Jam',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Total Tagihan', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  Text(
                    CurrencyFormatter.format(totalBill),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.obsidian),
                  ),
                ],
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isPaid ? AppColors.surfaceMuted : AppColors.obsidian,
                  foregroundColor: isPaid ? AppColors.textPrimary : Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(
                  isPaid ? Icons.receipt_outlined : Icons.payments_rounded,
                  size: 16,
                ),
                label: Text(
                  isPaid ? 'Rincian & Struk' : 'Bayar di Kasir',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _openPosPaymentModal(context, b),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Opens the POS Payment Modal / Sheet for a transaction.
  void _openPosPaymentModal(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PosPaymentModalSheet(
        booking: booking,
        onPaymentSuccess: () {
          ref.invalidate(cashierBookingsProvider(_searchQuery));
          ref.invalidate(closingSummaryProvider);
        },
      ),
    );
  }

  // =========================================================================
  // TAB 2: REKAP SHIFT & CLOSING KASIR
  // =========================================================================
  Widget _buildClosingShiftTab() {
    final closingAsync = ref.watch(closingSummaryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(closingSummaryProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Revenue Card
            closingAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (e, _) => Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'Gagal memuat rekap kasir:\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Coba Lagi'),
                      onPressed: () => ref.refresh(closingSummaryProvider),
                    ),
                  ],
                ),
              ),
              data: (data) {
                final totalRev = CurrencyFormatter.parse(data['total_revenue']);
                final totalTx = int.tryParse(data['total_transactions']?.toString() ?? '0') ?? 0;
                final Map<String, dynamic> breakdown = data['breakdown_by_method'] is Map
                    ? Map<String, dynamic>.from(data['breakdown_by_method'] as Map)
                    : {};

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'TOTAL OMSET HARI INI',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              Icon(Icons.payments_rounded, color: Colors.white70, size: 20),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            CurrencyFormatter.format(totalRev),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$totalTx transaksi berhasil diselesaikan di shift ini',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Method Breakdown
                    Text(
                      'RINCIAN METODE PEMBAYARAN',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (breakdown.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Center(
                          child: Text(
                            'Belum ada transaksi pembayaran hari ini.',
                            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                          ),
                        ),
                      )
                    else
                      ...breakdown.entries.map((entry) {
                        final val = entry.value is Map ? (entry.value as Map) : {};
                        final total = CurrencyFormatter.parse(val['total']);
                        final count = val['count'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.account_balance_wallet_outlined, size: 20, color: AppColors.textSecondary),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      Text('$count Transaksi', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                    ],
                                  ),
                                ],
                              ),
                              Text(
                                CurrencyFormatter.format(total),
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                        );
                      }),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      icon: const Icon(Icons.print_rounded, size: 20),
                      label: const Text('Cetak Struk Closing Shift (ESC/POS)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      onPressed: () => _printClosingReceipt(context, ref, data),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Printer & Hardware Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PERANGKAT PRINTER BLUETOOTH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.print_rounded, size: 24, color: AppColors.success),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ThermalPrinterService().connectedDevice?.name ?? 'Printer Thermal 58mm',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const Text('Status: Siap Mencetak (Terhubung)', style: TextStyle(fontSize: 12, color: AppColors.success)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_outlined, size: 18),
                    label: const Text('Test Print Struk Kasir'),
                    onPressed: () {
                      closingAsync.whenData((data) {
                        _printClosingReceipt(context, ref, data);
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // User Info & Logout
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.dangerLight,
                foregroundColor: AppColors.danger,
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Keluar dari Akun Kasir'),
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showServerSettings(BuildContext context) {
    final urlCtrl = TextEditingController(text: ApiClient().currentBaseUrl);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Pengaturan Server API'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: urlCtrl,
                decoration: const InputDecoration(labelText: 'Base URL API'),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('LAN Wi-Fi (192.168.1.93)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = ApiConstants.lanPcBaseUrl,
                  ),
                  ActionChip(
                    label: const Text('USB Reverse (127.0.0.1)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = ApiConstants.usbReverseBaseUrl,
                  ),
                  ActionChip(
                    label: const Text('Emulator (10.0.2.2)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = ApiConstants.emulatorBaseUrl,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                final newUrl = urlCtrl.text.trim();
                await ApiClient().updateBaseUrl(newUrl);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Base URL diubah ke: $newUrl')),
                  );
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  void _printClosingReceipt(BuildContext context, WidgetRef ref, Map<String, dynamic> data) {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final branchName = user?['affiliate']?['name'] ?? 'Cabang Operasional RentCore';
    final cashierName = user?['name'] ?? 'Kasir Bertugas';
    final totalRev = CurrencyFormatter.parse(data['total_revenue']);
    final totalTx = int.tryParse(data['total_transactions']?.toString() ?? '0') ?? 0;

    final breakdownMap = <String, double>{};
    if (data['breakdown_by_method'] is Map) {
      final breakdown = data['breakdown_by_method'] as Map;
      breakdown.forEach((k, v) {
        if (v is Map) {
          final amt = CurrencyFormatter.parse(v['total_amount'] ?? v['total']);
          breakdownMap[k.toString()] = amt;
        }
      });
    }

    final dateStr = DateTime.now().toLocal().toString().substring(0, 16);
    final printerService = ThermalPrinterService();
    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: branchName,
      cashierName: cashierName,
      date: dateStr,
      totalTransactions: totalTx,
      totalRevenue: totalRev,
      paymentBreakdown: breakdownMap,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Preview Closing Kasir',
        branchName: branchName,
        escposBytes: escposBytes,
        content: Column(
          children: [
            const Text('LAPORAN CLOSING SHIFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('Kasir: $cashierName', style: const TextStyle(fontSize: 11)),
            Text('Waktu: $dateStr', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Transaksi:', style: TextStyle(fontSize: 11)),
                Text('$totalTx', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Omset:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text(CurrencyFormatter.format(totalRev), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// POS PAYMENT MODAL SHEET (PRACTICAL POINT OF SALE INTERFACE)
// =========================================================================
class _PosPaymentModalSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onPaymentSuccess;

  const _PosPaymentModalSheet({
    required this.booking,
    required this.onPaymentSuccess,
  });

  @override
  ConsumerState<_PosPaymentModalSheet> createState() => _PosPaymentModalSheetState();
}

class _PosPaymentModalSheetState extends ConsumerState<_PosPaymentModalSheet> {
  final _cashReceivedController = TextEditingController();
  int _selectedMethodId = 1;
  String _selectedMethodCode = 'CASH';
  bool _nonCashConfirmed = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.booking;
    final customer = b['customer'] as Map? ?? {};
    final items = (b['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? (items[0] as Map) : null;
    final modelName = firstItem?['asset']?['model']?['name'] ?? 'Perangkat Apple';
    final assetCode = firstItem?['asset']?['asset_code'] ?? '';

    final subtotal = CurrencyFormatter.parse(b['subtotal_amount']);
    final discount = CurrencyFormatter.parse(b['discount_amount']);
    final totalBill = CurrencyFormatter.parse(b['total_bill']);

    final payments = (b['payments'] as List?) ?? [];
    double alreadyPaid = 0.0;
    for (final p in payments) {
      if (p['type'] == 'settlement' || p['type'] == 'dp' || p['type'] == 'extension') {
        alreadyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingDue = (totalBill - alreadyPaid).clamp(0.0, double.infinity);
    final isSettled = remainingDue <= 0 && (b['payment_status'] == 'paid');

    final cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
    final cashShortage = (remainingDue - cashReceived).clamp(0.0, double.infinity);
    final cashChange = (cashReceived - remainingDue).clamp(0.0, double.infinity);

    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modal Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'TERMINAL KASIR POS',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                    ),
                    Text(
                      b['booking_code'] ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Transaction Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(customer['name'] ?? 'Pelanggan', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      Text(customer['phone'] ?? '', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                  if (customer['address'] != null && customer['address'].toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Alamat: ${customer['address']}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('$modelName ($assetCode) • ${b['duration_hours']} Jam', style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                  const Divider(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Subtotal Sewa', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(subtotal), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (discount > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Diskon Voucher', style: TextStyle(fontSize: 11, color: AppColors.success)),
                        Text('- ${CurrencyFormatter.format(discount)}', style: const TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Tagihan Kontrak', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(CurrencyFormatter.format(totalBill), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  if (alreadyPaid > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Telah Dibayar Sebelumnya', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(CurrencyFormatter.format(alreadyPaid), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SISA TAGIHAN (AMOUNT DUE)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.danger),
                      ),
                      Text(
                        CurrencyFormatter.format(remainingDue),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: remainingDue > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // If already settled
            if (isSettled) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.success),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: AppColors.success, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Transaksi sewa ini sudah LUNAS sepenuhnya di meja kasir.',
                        style: TextStyle(color: AppColors.success, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                icon: const Icon(Icons.print_rounded),
                label: const Text('Cetak Ulang Struk Transaksi'),
                onPressed: () {
                  final latestTx = payments.isNotEmpty ? payments.last : null;
                  final receiptId = latestTx?['receipt_number'] ?? latestTx?['id'] ?? b['id'];
                  _fetchAndShowReceipt(receiptId);
                },
              ),
            ] else ...[
              // PAYMENT METHOD SELECTOR
              const Text(
                'PILIH METODE PEMBAYARAN',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
              ),
              const SizedBox(height: 8),
              paymentMethodsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal: $e'),
                data: (methods) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: methods.map((m) {
                    final isSel = _selectedMethodId == m['id'];
                    return ChoiceChip(
                      label: Text(m['name'] ?? m['code'] ?? 'Metode'),
                      selected: isSel,
                      onSelected: (_) {
                        setState(() {
                          _selectedMethodId = m['id'];
                          _selectedMethodCode = (m['code'] ?? 'CASH').toString().toUpperCase();
                          if (_selectedMethodCode == 'CASH') {
                            _cashReceivedController.text = remainingDue.toInt().toString();
                          }
                        });
                      },
                      selectedColor: AppColors.obsidian,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 14),

              // CASH PAYMENT: INPUT & REAL-TIME CHANGE CALCULATION
              if (_selectedMethodCode == 'CASH') ...[
                TextField(
                  controller: _cashReceivedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Jumlah Uang Diterima (Rp)',
                    hintText: 'Nominal tunai pelanggan',
                    prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      tooltip: 'Uang Pas',
                      onPressed: () {
                        _cashReceivedController.text = remainingDue.toInt().toString();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Cash Denomination Shortcuts
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('Uang Pas', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        _cashReceivedController.text = remainingDue.toInt().toString();
                      },
                    ),
                    ActionChip(
                      label: const Text('Rp 50.000', style: TextStyle(fontSize: 11)),
                      onPressed: () => _cashReceivedController.text = '50000',
                    ),
                    ActionChip(
                      label: const Text('Rp 100.000', style: TextStyle(fontSize: 11)),
                      onPressed: () => _cashReceivedController.text = '100000',
                    ),
                    ActionChip(
                      label: const Text('Rp 200.000', style: TextStyle(fontSize: 11)),
                      onPressed: () => _cashReceivedController.text = '200000',
                    ),
                    ActionChip(
                      label: const Text('Rp 350.000', style: TextStyle(fontSize: 11)),
                      onPressed: () => _cashReceivedController.text = '350000',
                    ),
                    ActionChip(
                      label: const Text('Rp 500.000', style: TextStyle(fontSize: 11)),
                      onPressed: () => _cashReceivedController.text = '500000',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Change / Shortage Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cashShortage > 0 ? AppColors.dangerLight : AppColors.successLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            cashShortage > 0 ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                            color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cashShortage > 0 ? 'Kekurangan Uang:' : 'Kembalian Pelanggan:',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        CurrencyFormatter.format(cashShortage > 0 ? cashShortage : cashChange),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Non-Cash Confirmation
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _nonCashConfirmed,
                        activeColor: AppColors.obsidian,
                        onChanged: (val) {
                          setState(() => _nonCashConfirmed = val ?? false);
                        },
                      ),
                      const Expanded(
                        child: Text(
                          'Konfirmasi pembayaran non-tunai (QRIS / Transfer) telah diverifikasi dan masuk.',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // PROCESS PAYMENT BUTTON
              ElevatedButton(
                onPressed: (_isProcessing ||
                        (_selectedMethodCode == 'CASH' && cashShortage > 0) ||
                        (_selectedMethodCode != 'CASH' && !_nonCashConfirmed))
                    ? null
                    : () => _executePayment(remainingDue),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedMethodCode == 'CASH' && cashShortage > 0
                            ? 'Uang Tunai Kurang (${CurrencyFormatter.format(cashShortage)})'
                            : 'Konfirmasi Bayar (${CurrencyFormatter.format(remainingDue)}) 🖨️',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _executePayment(double amountDue) async {
    setState(() => _isProcessing = true);

    try {
      final double cashReceived = _selectedMethodCode == 'CASH'
          ? CurrencyFormatter.parse(_cashReceivedController.text)
          : amountDue;

      final repo = ref.read(cashierRepositoryProvider);
      final result = await repo.processPayment(
        bookingId: widget.booking['id'],
        paymentMethodId: _selectedMethodId,
        cashReceived: cashReceived,
        amount: amountDue,
        notes: 'Pelunasan di meja kasir POS',
      );

      widget.onPaymentSuccess();

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet

      final change = CurrencyFormatter.parse(result['cash_change']);
      final receiptNum = result['receipt_number'] ?? '-';

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success),
              SizedBox(width: 8),
              Text('Pembayaran Berhasil!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tagihan ${widget.booking['booking_code']} telah lunas.'),
              const SizedBox(height: 8),
              Text('No. Struk: $receiptNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Metode: $_selectedMethodCode', style: const TextStyle(fontSize: 12)),
              if (_selectedMethodCode == 'CASH') ...[
                const SizedBox(height: 4),
                Text('Uang Diterima: ${CurrencyFormatter.format(cashReceived)}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Text('Kembalian: ${CurrencyFormatter.format(change)}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.print_rounded, size: 18),
              label: const Text('Cetak Struk'),
              onPressed: () {
                Navigator.pop(ctx);
                _fetchAndShowReceipt(receiptNum);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses pembayaran: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _fetchAndShowReceipt(dynamic receiptId) async {
    try {
      final repo = ref.read(cashierRepositoryProvider);
      final receiptData = await repo.fetchReceipt(receiptId);

      if (!mounted) return;
      final branchName = receiptData['outlet_name'] ?? 'RentCore';
      final cashierName = receiptData['cashier_name'] ?? 'Kasir';
      final receiptNum = receiptData['receipt_number'] ?? '-';
      final customerName = receiptData['customer_name'] ?? '-';
      final totalAmt = CurrencyFormatter.parse(receiptData['total_amount']);
      final cashRec = CurrencyFormatter.parse(receiptData['cash_received']);
      final cashChg = CurrencyFormatter.parse(receiptData['cash_change']);
      final method = receiptData['payment_method'] ?? 'Tunai';

      final printerService = ThermalPrinterService();
      final escposBytes = printerService.buildClosingShiftSlipBytes(
        branchName: branchName,
        cashierName: cashierName,
        date: receiptData['transacted_at']?.toString() ?? '',
        totalTransactions: 1,
        totalRevenue: totalAmt,
        paymentBreakdown: {method: totalAmt},
      );

      showDialog(
        context: context,
        builder: (ctx) => ThermalReceiptPreviewDialog(
          title: 'Struk Transaksi POS',
          branchName: branchName,
          escposBytes: escposBytes,
          content: Column(
            children: [
              Text('STRUK SEWA KASIR', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('No: $receiptNum', style: const TextStyle(fontSize: 11)),
              Text('Pelanggan: $customerName', style: const TextStyle(fontSize: 11)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bayar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(CurrencyFormatter.format(totalAmt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
              if (cashRec > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tunai Diterima:', style: TextStyle(fontSize: 11)),
                    Text(CurrencyFormatter.format(cashRec), style: const TextStyle(fontSize: 11)),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kembalian:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                    Text(CurrencyFormatter.format(cashChg), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memuat struk: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}

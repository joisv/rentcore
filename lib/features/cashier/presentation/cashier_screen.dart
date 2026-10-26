import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/network/api_client.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/cash_suggestion_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../bookings/presentation/direct_rental_screen.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../printer/providers/printer_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../providers/cashier_provider.dart';
import 'financial_activity_ledger_screen.dart';
import 'pos_transaction_detail_sheet.dart';
import 'widgets/add_branch_expense_modal.dart';
import 'widgets/cash_drawer_shift_modal.dart';

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
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.obsidian,
          unselectedLabelColor: AppColors.textMuted,
          indicatorColor: AppColors.obsidian,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Meja Kasir POS'),
            Tab(text: 'Rekap Shift & Closing'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBranchSelectorHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPosTerminalTab(),
                _buildClosingShiftTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBranchSelectorHeader() {
    final bizState = ref.watch(businessProvider);
    final authState = ref.watch(authProvider);
    final posBranchFilter = ref.watch(posFilterBranchIdProvider);

    final activeBiz = bizState.businesses.where((b) => b['id'] == bizState.activeBusinessId).firstOrNull;
    final role = (activeBiz?['membership']?['role'] ?? authState.user?['role'] ?? 'staff').toString().toLowerCase();
    final isOwnerOrAdmin = role == 'owner' || role == 'admin' || role == 'super_admin';

    final rawBranches = (activeBiz?['branches'] as List?) ?? [];
    final List<Map<String, dynamic>> branches = rawBranches
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    final isCentralUser = isOwnerOrAdmin || (branches.any((b) => b['id'] == bizState.activeBranchId && b['is_central'] == true));

    final bool isConsolidated = posBranchFilter == -1 || (posBranchFilter == null && bizState.activeBranchId == null);
    final String branchLabel;
    if (isConsolidated) {
      branchLabel = 'Semua Cabang (Konsolidasi)';
    } else {
      final effectiveId = posBranchFilter ?? bizState.activeBranchId;
      final match = branches.where((b) => b['id'] == effectiveId).firstOrNull;
      branchLabel = match?['name'] ?? bizState.activeBranchName ?? 'Cabang Aktif';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConsolidated ? AppColors.warning.withValues(alpha: 0.6) : AppColors.border,
          width: isConsolidated ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConsolidated ? Icons.hub_rounded : Icons.storefront_rounded,
            size: 20,
            color: isConsolidated ? AppColors.warning : AppColors.obsidian,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CAKUPAN POS & REKAP KASIR',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isConsolidated ? AppColors.warning : AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  branchLabel,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCentralUser && branches.isNotEmpty) ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text('Ganti', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              onPressed: () => _showBranchFilterModal(context, branches, isConsolidated, posBranchFilter),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text('Terkunci', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ),
          ],
        ],
      ),
    );
  }

  void _showBranchFilterModal(
    BuildContext context,
    List<Map<String, dynamic>> branches,
    bool isConsolidated,
    int? currentFilterId,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Pilih Cakupan Cabang POS',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Text(
                    'Tentukan cabang yang ingin dipantau atau pilih konsolidasi semua cabang',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.hub_rounded, color: AppColors.warning),
                  title: const Text('Semua Cabang (Konsolidasi)', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Gabungkan total transaksi & omset seluruh cabang', style: TextStyle(fontSize: 11)),
                  trailing: isConsolidated ? const Icon(Icons.check_circle_rounded, color: AppColors.warning) : null,
                  onTap: () {
                    ref.read(posFilterBranchIdProvider.notifier).setBranchId(-1);
                    ref.invalidate(closingSummaryProvider);
                    ref.invalidate(cashierBookingsProvider(_searchQuery));
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                ...branches.map((b) {
                  final bId = b['id'] as int;
                  final bName = b['name'] as String;
                  final isCent = b['is_central'] == true;
                  final isSelected = !isConsolidated && (currentFilterId == bId || (currentFilterId == null && ref.read(businessProvider).activeBranchId == bId));

                  return ListTile(
                    leading: Icon(
                      isCent ? Icons.account_balance_rounded : Icons.storefront_rounded,
                      color: isCent ? AppColors.warning : AppColors.info,
                    ),
                    title: Text(bName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    subtitle: Text(isCent ? 'Kantor Pusat (Main Store)' : 'Outlet Cabang', style: const TextStyle(fontSize: 11)),
                    trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: AppColors.success) : null,
                    onTap: () {
                      ref.read(posFilterBranchIdProvider.notifier).setBranchId(bId);
                      ref.invalidate(closingSummaryProvider);
                      ref.invalidate(cashierBookingsProvider(_searchQuery));
                      Navigator.pop(ctx);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openTransactionDetailSheet(BuildContext context, Map<String, dynamic> booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosTransactionDetailSheet(
        booking: booking,
        onPaymentRequested: (activeBooking) => _openPosPaymentModal(context, activeBooking),
      ),
    );
  }

  void _openAddExpenseModal(BuildContext context, int? branchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddBranchExpenseModal(
        branchId: branchId,
        onExpenseCreated: () {
          ref.invalidate(closingSummaryProvider);
          ref.invalidate(cashierExpensesProvider);
        },
      ),
    );
  }

  void _openShiftModal(BuildContext context, Map<String, dynamic>? activeShift, double expectedCash, int? branchId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CashDrawerShiftModal(
        activeShift: activeShift,
        expectedDrawerCash: expectedCash,
        branchId: branchId,
        onShiftUpdated: () {
          ref.invalidate(closingSummaryProvider);
          ref.invalidate(currentShiftProvider);
        },
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
    final affiliate = b['affiliate'] as Map? ?? {};
    final items = (b['items'] as List?) ?? [];
    final firstItem = items.isNotEmpty ? (items[0] as Map) : null;
    final modelName = firstItem?['asset']?['model']?['name'] ?? 'Perangkat Apple';
    final assetCode = firstItem?['asset']?['asset_code'] ?? '';
    final totalBill = CurrencyFormatter.parse(b['total_bill']);
    final returnInspection = b['return_inspection'] as Map? ?? b['returnInspection'] as Map? ?? {};
    final penaltyDue = CurrencyFormatter.parse(returnInspection['total_penalty']);
    final effectiveTotal = totalBill + penaltyDue;
    final paymentStatus = (b['payment_status'] ?? 'paid').toString().toLowerCase();
    final isPaid = paymentStatus == 'paid';

    final isCentral = affiliate['is_central'] == true;
    final branchName = affiliate['name'] ?? (isCentral ? 'Pusat' : 'Cabang');

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _openTransactionDetailSheet(context, b),
      child: Container(
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
                Row(
                  children: [
                    Text(
                      b['booking_code'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCentral ? AppColors.warningLight : AppColors.infoLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCentral ? 'Pusat' : branchName,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isCentral ? AppColors.warning : AppColors.info,
                        ),
                      ),
                    ),
                  ],
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
                    Row(
                      children: [
                        const Text('Total Tagihan', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                        if (penaltyDue > 0) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.deepOrange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              '+ Denda',
                              style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      CurrencyFormatter.format(effectiveTotal),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.obsidian),
                    ),
                  ],
                ),
                Row(
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.info_outline_rounded, size: 14),
                      label: const Text('Rincian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                      onPressed: () => _openTransactionDetailSheet(context, b),
                    ),
                    if (!isPaid) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidian,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        icon: const Icon(Icons.payments_rounded, size: 14),
                        label: const Text('Bayar', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => _openPosPaymentModal(context, b),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Opens the POS Payment Modal / Sheet for a transaction.
  void _openPosPaymentModal(BuildContext context, Map<String, dynamic> booking) {
    final returnInspection = booking['return_inspection'] as Map? ?? booking['returnInspection'] as Map? ?? {};
    final totalPenaltyDue = CurrencyFormatter.parse(returnInspection['total_penalty']);
    final payments = (booking['payments'] as List?) ?? [];
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      if (p['type']?.toString().toLowerCase() == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingPenalty = (totalPenaltyDue - penaltyPaid).clamp(0.0, double.infinity);

    final totalBill = CurrencyFormatter.parse(booking['total_bill']);
    double rentalPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pt = p['type']?.toString().toLowerCase();
      if (pt == 'settlement' || pt == 'dp' || pt == 'extension' || pt == 'rental' || pt == 'exchange') {
        rentalPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingRental = (totalBill - rentalPaid).clamp(0.0, double.infinity);

    final isPenaltyTarget = remainingRental <= 0 && remainingPenalty > 0;
    final paymentContext = isPenaltyTarget
        ? PaymentContext.penalty(
            booking: booking,
            penaltyDue: remainingPenalty,
          )
        : PaymentContext.settlement(
            booking: booking,
            remainingDue: remainingRental > 0 ? remainingRental : (remainingPenalty > 0 ? remainingPenalty : totalBill),
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentPage(
        paymentContext: paymentContext,
        isModal: true,
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
            // Date Range Filter Chips
            _buildDateFilterChips(),
            const SizedBox(height: 14),

            // Revenue Card & Consolidated Reports
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
                final dateLabel = data['date'] ?? 'HARI INI';
                final isConsolidated = data['is_consolidated'] == true;

                final cashTotal = _calcCashTotal(breakdown);
                final nonCashTotal = _calcNonCashTotal(breakdown);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main Revenue Card
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
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'TOTAL OMSET ($dateLabel)',
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  if (isConsolidated) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'KONSOLIDASI',
                                        style: TextStyle(color: Colors.black, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const Icon(Icons.payments_rounded, color: Colors.white70, size: 20),
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
                            '$totalTx transaksi berhasil diselesaikan',
                            style: const TextStyle(color: Colors.white60, fontSize: 13),
                          ),
                          const SizedBox(height: 14),
                          const Divider(color: Colors.white24, height: 1),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.money_rounded, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Tunai (Cash)', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                        Text(
                                          CurrencyFormatter.format(cashTotal),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 28, color: Colors.white24),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Row(
                                  children: [
                                    const Icon(Icons.credit_card_rounded, size: 16, color: Colors.white70),
                                    const SizedBox(width: 6),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Non-Tunai', style: TextStyle(color: Colors.white60, fontSize: 10)),
                                        Text(
                                          CurrencyFormatter.format(nonCashTotal),
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Action: Catat Beban, Buka/Tutup Shift, dan Buku Kas
                    Builder(builder: (_) {
                      final recon = data['cash_reconciliation'] is Map ? (data['cash_reconciliation'] as Map) : {};
                      final activeShift = recon['active_shift'] is Map ? Map<String, dynamic>.from(recon['active_shift'] as Map) : null;
                      final hasActiveShift = activeShift != null && activeShift['status'] == 'open';
                      final totalExp = CurrencyFormatter.parse(data['total_expenses']);
                      final cashExp = CurrencyFormatter.parse(data['cash_drawer_expenses']);
                      final expectedCash = recon.containsKey('expected_cash_in_drawer')
                          ? CurrencyFormatter.parse(recon['expected_cash_in_drawer'])
                          : (cashTotal - cashExp > 0 ? cashTotal - cashExp : 0.0);

                      final bizState = ref.read(businessProvider);
                      final posBranchFilter = ref.read(posFilterBranchIdProvider);
                      final int? effBranch = posBranchFilter != -1 ? (posBranchFilter ?? bizState.activeBranchId) : bizState.activeBranchId;

                      return Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    side: const BorderSide(color: AppColors.border),
                                  ),
                                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                                  label: const Text(
                                    '+ Catat Beban',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () => _openAddExpenseModal(context, effBranch),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: hasActiveShift ? AppColors.obsidian : AppColors.info,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  icon: Icon(
                                    hasActiveShift ? Icons.lock_clock_rounded : Icons.lock_open_rounded,
                                    size: 18,
                                  ),
                                  label: Text(
                                    hasActiveShift ? 'Tutup Shift' : 'Buka Shift',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  onPressed: () => _openShiftModal(context, activeShift, expectedCash, effBranch),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FinancialActivityLedgerScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.menu_book_rounded, size: 16, color: AppColors.obsidian),
                                      SizedBox(width: 8),
                                      Text(
                                        'Buku Kas Lengkap (Audit Ledger Finansial)',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.obsidian),
                                      ),
                                    ],
                                  ),
                                  Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 16),

                    // Cash Drawer & Operational Expense Card
                    if (data['cash_reconciliation'] is Map || (data['total_expenses'] != null && CurrencyFormatter.parse(data['total_expenses']) > 0)) ...[
                      Builder(builder: (_) {
                        final recon = data['cash_reconciliation'] is Map ? (data['cash_reconciliation'] as Map) : {};
                        final totalExp = CurrencyFormatter.parse(data['total_expenses']);
                        final cashExp = CurrencyFormatter.parse(data['cash_drawer_expenses']);
                        final expectedCash = recon.containsKey('expected_cash_in_drawer')
                            ? CurrencyFormatter.parse(recon['expected_cash_in_drawer'])
                            : (cashTotal - cashExp > 0 ? cashTotal - cashExp : 0.0);
                        final openingFloat = CurrencyFormatter.parse(recon['opening_cash_float']);

                        return Container(
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
                                  const Row(
                                    children: [
                                      Icon(Icons.point_of_sale_rounded, size: 18, color: AppColors.obsidian),
                                      SizedBox(width: 8),
                                      Text(
                                        'REKONSILIASI KAS LACI & BEBAN',
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                  if (recon['active_shift'] is Map)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppColors.successLight,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Shift #${(recon['active_shift'] as Map)['shift_number'] ?? (recon['active_shift'] as Map)['id']} Aktif',
                                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (openingFloat > 0) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Modal Awal Kas Laci', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text(CurrencyFormatter.format(openingFloat), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                              ],
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Kas Masuk Bersih (Net Cash)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                  Text(CurrencyFormatter.format(cashTotal), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.success)),
                                ],
                              ),
                              if (totalExp > 0) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Beban Pengeluaran Cabang ${cashExp > 0 ? '(Kas Laci)' : ''}', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                                    Text('-${CurrencyFormatter.format(cashExp > 0 ? cashExp : totalExp)}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.danger)),
                                  ],
                                ),
                              ],
                              const Divider(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('FISIK KAS HARUS ADA DI LACI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                                  Text(
                                    CurrencyFormatter.format(expectedCash),
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Income Type Breakdown (Rental, Extension, Penalty)
                    if (data['breakdown_by_type'] is Map) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'SUMBER PENDAPATAN (INCOME TYPE)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Builder(builder: (_) {
                        final typeMap = data['breakdown_by_type'] as Map;
                        final types = [
                          'rental',
                          'extension',
                          'penalty',
                          if (typeMap.containsKey('refund') && ((typeMap['refund'] is Map && (typeMap['refund']['count'] ?? 0) > 0) || CurrencyFormatter.parse((typeMap['refund'] is Map ? typeMap['refund']['total'] : null)) > 0))
                            'refund',
                        ];
                        return Column(
                          children: types.map((key) {
                            final info = typeMap[key] is Map ? (typeMap[key] as Map) : {};
                            final label = info['label'] ?? (key == 'penalty' ? 'Denda Keterlambatan' : (key == 'extension' ? 'Perpanjangan Sewa' : (key == 'refund' ? 'Pengembalian Deposit (Refund)' : 'Sewa Kontrak Pokok')));
                            final total = CurrencyFormatter.parse(info['total']);
                            final count = info['count'] ?? 0;
                            final isPenalty = key == 'penalty';
                            final isExtension = key == 'extension';
                            final isRefund = key == 'refund';

                            final icon = isPenalty
                                ? Icons.warning_amber_rounded
                                : (isExtension ? Icons.update_rounded : Icons.vpn_key_outlined);
                            final iconColor = isPenalty
                                ? Colors.deepOrange
                                : (isExtension ? AppColors.info : AppColors.obsidian);
                            final iconBg = isPenalty
                                ? Colors.deepOrange.withValues(alpha: 0.1)
                                : (isExtension ? AppColors.infoLight : AppColors.surfaceMuted);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isPenalty && total > 0 ? Colors.deepOrange.withValues(alpha: 0.35) : AppColors.border,
                                  width: isPenalty && total > 0 ? 1.5 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: iconBg,
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(icon, size: 20, color: iconColor),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isPenalty && total > 0 ? Colors.deepOrange.shade800 : AppColors.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '$count Transaksi',
                                            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  Text(
                                    CurrencyFormatter.format(total),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: isPenalty && total > 0 ? Colors.deepOrange : AppColors.obsidian,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

                    // Branch Breakdown Section
                    if (data['breakdown_by_branch'] is List && (data['breakdown_by_branch'] as List).isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'KONTRIBUSI REVENUE PER CABANG',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            '${(data['breakdown_by_branch'] as List).length} Cabang Terdata',
                            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...(data['breakdown_by_branch'] as List).map((bItem) {
                        final b = bItem is Map ? bItem : {};
                        final bName = b['branch_name'] ?? 'Cabang';
                        final isCent = b['is_central'] == true;
                        final bRev = CurrencyFormatter.parse(b['total_revenue']);
                        final bCash = CurrencyFormatter.parse(b['cash_revenue']);
                        final bNonCash = CurrencyFormatter.parse(b['non_cash_revenue']);
                        final bTxCount = b['transaction_count'] ?? 0;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
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
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: isCent ? AppColors.warningLight : AppColors.infoLight,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isCent ? 'PUSAT' : 'CABANG',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: isCent ? AppColors.warning : AppColors.info,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        bName,
                                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    CurrencyFormatter.format(bRev),
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.obsidian),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('$bTxCount Transaksi', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                  Text(
                                    'Tunai: ${CurrencyFormatter.format(bCash)} • Non-Tunai: ${CurrencyFormatter.format(bNonCash)}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                      const SizedBox(height: 16),
                    ],

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
                            'Belum ada transaksi pembayaran di periode ini.',
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

                    // Recent Completed Transactions (Inspection)
                    if (data['recent_transactions'] is List && (data['recent_transactions'] as List).isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'TRANSAKSI TERBARU (AUDIT RINCIAN)',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                              color: AppColors.textMuted,
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Icons.menu_book_rounded, size: 14),
                            label: const Text('Buku Kas Lengkap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const FinancialActivityLedgerScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ...(data['recent_transactions'] as List).map((txItem) {
                        final tx = txItem is Map ? txItem : {};
                        final txCode = tx['receipt_number'] ?? tx['transaction_code'] ?? 'TX';
                        final custName = tx['customer_name'] ?? 'Pelanggan';
                        final brName = tx['branch_name'] ?? 'Cabang';
                        final isCent = tx['is_central'] == true;
                        final txAmt = CurrencyFormatter.parse(tx['amount']);
                        final pMethod = tx['payment_method'] ?? 'Tunai';
                        final cashier = tx['cashier_name'] ?? 'Kasir';
                        final itemsSummary = tx['items_summary'] ?? 'Perangkat Apple';
                        final txType = tx['type']?.toString().toLowerCase();
                        final txTypeLabel = tx['type_label'] ?? (txType == 'penalty' ? 'Denda Keterlambatan' : null);

                        return InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _openTransactionDetailSheet(context, Map<String, dynamic>.from(tx)),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isCent ? AppColors.warningLight : AppColors.infoLight,
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCent ? 'Pusat' : brName,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isCent ? AppColors.warning : AppColors.info,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            txCode,
                                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                                          ),
                                          if (txType == 'penalty') ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.deepOrange.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Denda',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.deepOrange,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$custName • $itemsSummary',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Kasir: $cashier • $pMethod${txTypeLabel != null ? ' • $txTypeLabel' : ''}',
                                        style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      CurrencyFormatter.format(txAmt),
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.obsidian),
                                    ),
                                    const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textMuted),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

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

  double _calcCashTotal(Map<String, dynamic> breakdown) {
    double total = 0.0;
    breakdown.forEach((k, v) {
      final kStr = k.toString().toLowerCase();
      if (kStr.contains('tunai') || kStr == 'cash') {
        if (v is Map) {
          total += CurrencyFormatter.parse(v['total'] ?? v['total_amount']);
        }
      }
    });
    return total;
  }

  double _calcNonCashTotal(Map<String, dynamic> breakdown) {
    double total = 0.0;
    breakdown.forEach((k, v) {
      final kStr = k.toString().toLowerCase();
      if (!kStr.contains('tunai') && kStr != 'cash') {
        if (v is Map) {
          total += CurrencyFormatter.parse(v['total'] ?? v['total_amount']);
        }
      }
    });
    return total;
  }

  Widget _buildDateFilterChips() {
    final dateState = ref.watch(posDateRangeProvider);
    final activeLabel = dateState.label;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildDateFilterChip('Hari Ini', activeLabel == 'Hari Ini', () {
            final nowStr = DateTime.now().toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
              label: 'Hari Ini',
              startDate: nowStr,
              endDate: nowStr,
            );
          }),
          const SizedBox(width: 8),
          _buildDateFilterChip('Kemarin', activeLabel == 'Kemarin', () {
            final now = DateTime.now();
            final yesterday = DateTime(now.year, now.month, now.day - 1);
            final yStr = yesterday.toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
              label: 'Kemarin',
              startDate: yStr,
              endDate: yStr,
            );
          }),
          const SizedBox(width: 8),
          _buildDateFilterChip('Bulan Ini', activeLabel == 'Bulan Ini', () {
            final now = DateTime.now();
            final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
            final todayStr = now.toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
              label: 'Bulan Ini',
              startDate: startOfMonth,
              endDate: todayStr,
            );
          }),
          const SizedBox(width: 8),
          ActionChip(
            avatar: const Icon(Icons.date_range_rounded, size: 16),
            label: Text(
              activeLabel != 'Hari Ini' && activeLabel != 'Kemarin' && activeLabel != 'Bulan Ini'
                  ? activeLabel
                  : 'Rentang Kustom',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: (activeLabel != 'Hari Ini' && activeLabel != 'Kemarin' && activeLabel != 'Bulan Ini')
                    ? Colors.white
                    : AppColors.textPrimary,
              ),
            ),
            backgroundColor: (activeLabel != 'Hari Ini' && activeLabel != 'Kemarin' && activeLabel != 'Bulan Ini')
                ? AppColors.obsidian
                : AppColors.surface,
            onPressed: () async {
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2024),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (picked != null) {
                final startStr = picked.start.toIso8601String().substring(0, 10);
                final endStr = picked.end.toIso8601String().substring(0, 10);
                ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: '$startStr s/d $endStr',
                  startDate: startStr,
                  endDate: endStr,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surface,
      onSelected: (_) => onTap(),
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
                    label: const Text('Current PC (192.168.1.101)', style: TextStyle(fontSize: 11)),
                    onPressed: () => urlCtrl.text = ApiConstants.currentLanPcBaseUrl,
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
  String _paymentTarget = 'settlement'; // 'settlement' or 'penalty'
  bool _initializedTarget = false;

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

    final returnInspection = b['return_inspection'] as Map? ?? b['returnInspection'] as Map? ?? {};
    final totalPenaltyDue = CurrencyFormatter.parse(returnInspection['total_penalty']);

    final payments = (b['payments'] as List?) ?? [];
    double rentalPaid = 0.0;
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pType = p['type']?.toString().toLowerCase();
      if (pType == 'settlement' || pType == 'dp' || pType == 'extension' || pType == 'rental' || pType == 'exchange') {
        rentalPaid += CurrencyFormatter.parse(p['amount']);
      } else if (pType == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingRentalDue = (totalBill - rentalPaid).clamp(0.0, double.infinity);
    final remainingPenaltyDue = (totalPenaltyDue - penaltyPaid).clamp(0.0, double.infinity);
    final totalRemainingDue = remainingRentalDue + remainingPenaltyDue;
    final isSettled = totalRemainingDue <= 0 && (b['payment_status'] == 'paid');

    if (!_initializedTarget) {
      _initializedTarget = true;
      if (remainingRentalDue <= 0 && remainingPenaltyDue > 0) {
        _paymentTarget = 'penalty';
      } else {
        _paymentTarget = 'settlement';
      }
    }

    final currentTargetDue = _paymentTarget == 'penalty' ? remainingPenaltyDue : remainingRentalDue;
    final cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
    final cashShortage = CashPaymentSuggestionHelper.calculateShortage(amountDue: currentTargetDue, cashReceived: cashReceived);
    final cashChange = CashPaymentSuggestionHelper.calculateChange(amountDue: currentTargetDue, cashReceived: cashReceived);

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

            // Target Selector (If both rental and penalty have pending balance)
            if (remainingRentalDue > 0 && remainingPenaltyDue > 0) ...[
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'settlement',
                    label: Text('Sewa (${CurrencyFormatter.format(remainingRentalDue)})', style: const TextStyle(fontSize: 11)),
                  ),
                  ButtonSegment(
                    value: 'penalty',
                    label: Text('Denda (${CurrencyFormatter.format(remainingPenaltyDue)})', style: const TextStyle(fontSize: 11)),
                  ),
                ],
                selected: {_paymentTarget},
                onSelectionChanged: (set) {
                  setState(() {
                    _paymentTarget = set.first;
                    if (_selectedMethodCode == 'CASH') {
                      final due = _paymentTarget == 'penalty' ? remainingPenaltyDue : remainingRentalDue;
                      _cashReceivedController.text = due.toInt().toString();
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
            ] else if (_paymentTarget == 'penalty' && remainingPenaltyDue > 0) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepOrange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.deepOrange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Pembayaran Pelunasan Denda Keterlambatan Unit',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

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
                  if (totalPenaltyDue > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Denda Keterlambatan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        Text(CurrencyFormatter.format(totalPenaltyDue), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                  ],
                  if (rentalPaid > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sewa Terbayar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(CurrencyFormatter.format(rentalPaid), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                  if (penaltyPaid > 0) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Denda Terbayar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                        Text(CurrencyFormatter.format(penaltyPaid), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _paymentTarget == 'penalty' ? 'SISA DENDA HARUS DIBAYAR' : 'SISA TAGIHAN SEWA',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.danger),
                      ),
                      Text(
                        CurrencyFormatter.format(currentTargetDue),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: currentTargetDue > 0 ? AppColors.danger : AppColors.success,
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
                      showCheckmark: false,
                      onSelected: (_) {
                        setState(() {
                          _selectedMethodId = m['id'];
                          _selectedMethodCode = (m['code'] ?? 'CASH').toString().toUpperCase();
                          if (_selectedMethodCode == 'CASH') {
                            _cashReceivedController.text = currentTargetDue.toInt().toString();
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
                    prefixIcon: const SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          'Rp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.check_circle_outline_rounded),
                      tooltip: 'Uang Pas',
                      onPressed: () {
                        _cashReceivedController.text = currentTargetDue.toInt().toString();
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),

                // Cash Denomination Dynamic Suggestions
                Builder(
                  builder: (context) {
                    final cashSuggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(currentTargetDue);
                    if (cashSuggestions.isEmpty) return const SizedBox.shrink();

                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: cashSuggestions.map((amt) {
                        final isExact = amt == currentTargetDue.toInt();
                        return ActionChip(
                          label: Text(
                            CurrencyFormatter.format(amt),
                            style: const TextStyle(fontSize: 11),
                          ),
                          tooltip: isExact ? 'Uang Pas' : null,
                          onPressed: () {
                            _cashReceivedController.text = amt.toString();
                          },
                        );
                      }).toList(),
                    );
                  },
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
                    : () => _executePayment(currentTargetDue),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _paymentTarget == 'penalty' ? Colors.deepOrange.shade800 : AppColors.obsidian,
                  foregroundColor: Colors.white,
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
                            : 'Konfirmasi Bayar ${_paymentTarget == 'penalty' ? 'Denda' : 'Sewa'} (${CurrencyFormatter.format(currentTargetDue)})',
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
        paymentType: _paymentTarget,
        notes: _paymentTarget == 'penalty' ? 'Pelunasan denda via Kasir POS' : 'Pelunasan di meja kasir POS',
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
              Text(_paymentTarget == 'penalty'
                  ? 'Denda keterlambatan ${widget.booking['booking_code']} telah lunas tercatat sebagai omset pendapatan.'
                  : 'Tagihan ${widget.booking['booking_code']} telah lunas.'),
              const SizedBox(height: 8),
              Text('No. Struk: $receiptNum', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Tipe: ${_paymentTarget == 'penalty' ? 'Denda Keterlambatan' : 'Sewa Kontrak'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
        SnackBar(
          content: Text('Gagal memproses pembayaran: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
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
      final printerSettings = ref.read(printerProvider).settings;
      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: branchName,
        receiptNumber: receiptNum,
        customerName: customerName,
        cashierName: cashierName,
        totalAmount: totalAmt,
        paymentMethod: method,
        cashReceived: cashRec,
        cashChange: cashChg,
        transactedAt: receiptData['transacted_at']?.toString() ?? '',
      );
      final escposBytes = printerService.buildPosPaymentSlipBytes(model, printerSettings);

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

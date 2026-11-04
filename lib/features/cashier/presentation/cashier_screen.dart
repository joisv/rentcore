import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
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

class _CashierScreenState extends ConsumerState<CashierScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Shift Aktif'),
            Tab(text: 'Riwayat Shift'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildBranchSelectorHeader(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildActiveShiftTab(), _buildShiftHistoryTab()],
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

    final activeBiz = bizState.businesses
        .where((b) => b['id'] == bizState.activeBusinessId)
        .firstOrNull;
    final role =
        (activeBiz?['membership']?['role'] ??
                authState.user?['role'] ??
                'staff')
            .toString()
            .toLowerCase();
    final isOwnerOrAdmin =
        role == 'owner' || role == 'admin' || role == 'super_admin';

    final rawBranches = (activeBiz?['branches'] as List?) ?? [];
    final List<Map<String, dynamic>> branches = rawBranches
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    final isCentralUser =
        isOwnerOrAdmin ||
        (branches.any(
          (b) => b['id'] == bizState.activeBranchId && b['is_central'] == true,
        ));

    final bool isConsolidated =
        posBranchFilter == -1 ||
        (posBranchFilter == null && bizState.activeBranchId == null);
    final String branchLabel;
    if (isConsolidated) {
      branchLabel = 'Semua Cabang (Konsolidasi)';
    } else {
      final effectiveId = posBranchFilter ?? bizState.activeBranchId;
      final match = branches.where((b) => b['id'] == effectiveId).firstOrNull;
      branchLabel =
          match?['name'] ?? bizState.activeBranchName ?? 'Cabang Aktif';
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isConsolidated
              ? AppColors.warning.withValues(alpha: 0.6)
              : AppColors.border,
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
                  'Cakupan Kasir',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isConsolidated
                        ? AppColors.warning
                        : AppColors.textMuted,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  branchLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCentralUser && branches.isNotEmpty) ...[
            TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.swap_horiz_rounded, size: 16),
              label: const Text(
                'Ganti',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => _showBranchFilterModal(
                context,
                branches,
                isConsolidated,
                posBranchFilter,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Terkunci',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.hub_rounded,
                    color: AppColors.warning,
                  ),
                  title: const Text(
                    'Semua Cabang (Konsolidasi)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: const Text(
                    'Gabungkan total transaksi & omset seluruh cabang',
                    style: TextStyle(fontSize: 11),
                  ),
                  trailing: isConsolidated
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.warning,
                        )
                      : null,
                  onTap: () {
                    ref
                        .read(posFilterBranchIdProvider.notifier)
                        .setBranchId(-1);
                    ref.invalidate(closingSummaryProvider);
                    ref.invalidate(shiftHistoryProvider);
                    Navigator.pop(ctx);
                  },
                ),
                const Divider(indent: 20, endIndent: 20),
                ...branches.map((b) {
                  final bId = b['id'] as int;
                  final bName = b['name'] as String;
                  final isCent = b['is_central'] == true;
                  final isSelected =
                      !isConsolidated &&
                      (currentFilterId == bId ||
                          (currentFilterId == null &&
                              ref.read(businessProvider).activeBranchId ==
                                  bId));

                  return ListTile(
                    leading: Icon(
                      isCent
                          ? Icons.account_balance_rounded
                          : Icons.storefront_rounded,
                      color: isCent ? AppColors.warning : AppColors.info,
                    ),
                    title: Text(
                      bName,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      isCent ? 'Kantor Pusat (Main Store)' : 'Outlet Cabang',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                          )
                        : null,
                    onTap: () {
                      ref
                          .read(posFilterBranchIdProvider.notifier)
                          .setBranchId(bId);
                      ref.invalidate(closingSummaryProvider);
                      ref.invalidate(shiftHistoryProvider);
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

  void _openTransactionDetailSheet(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosTransactionDetailSheet(booking: booking),
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
          ref.invalidate(shiftHistoryProvider);
        },
      ),
    );
  }

  void _openShiftModal(
    BuildContext context,
    Map<String, dynamic>? activeShift,
    double expectedCash,
    int? branchId,
  ) {
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
          ref.invalidate(shiftHistoryProvider);
        },
      ),
    );
  }

  // =========================================================================
  // TAB 1: SHIFT AKTIF (ACTIVE SHIFT REGISTER & REKAP KASIR)
  // =========================================================================
  Widget _buildActiveShiftTab() {
    final closingAsync = ref.watch(closingSummaryProvider);
    final currentShiftAsync = ref.watch(currentShiftProvider);
    final authState = ref.watch(authProvider);
    final bizState = ref.watch(businessProvider);
    final posBranchFilter = ref.watch(posFilterBranchIdProvider);
    final int? effBranch = posBranchFilter != -1
        ? (posBranchFilter ?? bizState.activeBranchId)
        : bizState.activeBranchId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(closingSummaryProvider);
          ref.invalidate(currentShiftProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date Range Filter Chips (Pill-style, compact height)
              _buildDateFilterChips(),
              const SizedBox(height: 14),

              closingAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
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
                      Text(
                        'Gagal memuat rekap kasir:\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
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
                  final totalRev = CurrencyFormatter.parse(
                    data['total_revenue'],
                  );
                  final totalTx =
                      int.tryParse(
                        data['total_transactions']?.toString() ?? '0',
                      ) ??
                      0;
                  final Map<String, dynamic> breakdown =
                      data['breakdown_by_method'] is Map
                      ? Map<String, dynamic>.from(
                          data['breakdown_by_method'] as Map,
                        )
                      : {};
                  final dateLabel = data['date'] ?? 'Hari Ini';
                  final isConsolidated = data['is_consolidated'] == true;

                  final cashTotal = _calcCashTotal(breakdown);
                  final nonCashTotal = _calcNonCashTotal(breakdown);

                  final recon = data['cash_reconciliation'] is Map
                      ? (data['cash_reconciliation'] as Map)
                      : {};
                  final activeShift = recon['active_shift'] is Map
                      ? Map<String, dynamic>.from(recon['active_shift'] as Map)
                      : null;
                  final shiftPayload = currentShiftAsync.asData?.value;
                  final currentShiftData =
                      shiftPayload?['data']?['shift'] is Map
                      ? Map<String, dynamic>.from(
                          shiftPayload!['data']['shift'] as Map,
                        )
                      : null;
                  final effectiveShift = currentShiftData ?? activeShift;
                  final hasActiveShift =
                      effectiveShift != null &&
                      effectiveShift['status'] == 'open';

                  final totalExp = CurrencyFormatter.parse(
                    data['total_expenses'],
                  );
                  final cashExp = CurrencyFormatter.parse(
                    data['cash_drawer_expenses'],
                  );

                  final openingFloat = CurrencyFormatter.parse(
                    effectiveShift?['opening_cash_float'] ??
                        recon['opening_cash_float'],
                  );

                  final double expectedCash;
                  if (effectiveShift != null &&
                      effectiveShift['expected_cash_now'] != null) {
                    expectedCash = CurrencyFormatter.parse(
                      effectiveShift['expected_cash_now'],
                    );
                  } else if (recon.containsKey('expected_cash_in_drawer')) {
                    expectedCash = CurrencyFormatter.parse(
                      recon['expected_cash_in_drawer'],
                    );
                  } else {
                    expectedCash =
                        (cashTotal - cashExp > 0 ? cashTotal - cashExp : 0.0) +
                        openingFloat;
                  }

                  final cashierName =
                      effectiveShift?['cashier_name'] ??
                      effectiveShift?['cashier']?['name'] ??
                      authState.user?['name'] ??
                      'Kasir Bertugas';
                  final branchName =
                      effectiveShift?['branch_name'] ??
                      effectiveShift?['affiliate']?['name'] ??
                      bizState.activeBranchName ??
                      'Cabang Utama';
                  final openedAt =
                      effectiveShift?['opened_at'] ??
                      effectiveShift?['created_at'];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. ACTIVE SESSION INFO CARD
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
                              children: [
                                const Icon(
                                  Icons.badge_outlined,
                                  size: 18,
                                  color: AppColors.obsidian,
                                ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Sesi Kasir Berjalan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      color: AppColors.obsidian,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: hasActiveShift
                                    ? AppColors.successLight
                                    : AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: hasActiveShift
                                          ? AppColors.success
                                          : AppColors.textMuted,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      hasActiveShift
                                          ? 'Shift #${effectiveShift['shift_number'] ?? effectiveShift['id']} Aktif'
                                          : 'Shift Ditutup',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: hasActiveShift
                                            ? AppColors.success
                                            : AppColors.textMuted,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 18),
                            if (hasActiveShift) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Kasir Bertugas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      cashierName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.obsidian,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Cabang Operasional',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      branchName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.obsidian,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              if (openedAt != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Waktu Buka Shift',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        DateFormatter.formatFull(
                                          DateTime.tryParse(
                                            openedAt.toString(),
                                          ),
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.obsidian,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Modal Kas Awal',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(openingFloat),
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              const Text(
                                'Laci kasir belum memiliki sesi shift aktif. Buka shift kasir untuk memasukkan modal awal kas laci.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.obsidian,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.meeting_room_rounded,
                                    size: 16,
                                  ),
                                  label: const Text(
                                    'Buka Shift Sekarang',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  onPressed: () => _openShiftModal(
                                    context,
                                    effectiveShift,
                                    expectedCash,
                                    effBranch,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 2. REAL-TIME CASH SUMMARY CARD
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
                            const Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Rekonsiliasi Kas Laci & Beban',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Kas Masuk Tunai
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Kas Masuk Tunai',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        'Kas Masuk Bersih (Sistem)',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  CurrencyFormatter.format(cashTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            // Total Non-Tunai
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Total Non-Tunai (QRIS / Bank / EDC)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  CurrencyFormatter.format(nonCashTotal),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),

                            if (openingFloat > 0) ...[
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Modal Awal Kas Laci',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    CurrencyFormatter.format(openingFloat),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                            ],

                            // Pengeluaran Kasir
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    totalExp > 0
                                        ? 'Beban Pengeluaran Cabang ${cashExp > 0 ? '(Kas Laci)' : ''}'
                                        : 'Beban Kas Keluar (Laci)',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  totalExp > 0
                                      ? '-${CurrencyFormatter.format(cashExp > 0 ? cashExp : totalExp)}'
                                      : 'Rp 0',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: (cashExp > 0 || totalExp > 0)
                                        ? AppColors.danger
                                        : AppColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 18),

                            // Ekspektasi Uang Fisik di Laci
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ekspektasi Uang Fisik di Laci',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.obsidian,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Total Fisik Kas Wajib di Laci',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      CurrencyFormatter.format(expectedCash),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 3. QUICK ACTION BAR
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: const BorderSide(color: AppColors.border),
                                foregroundColor: AppColors.obsidian,
                              ),
                              icon: const Icon(
                                Icons.add_shopping_cart_rounded,
                                size: 16,
                              ),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '+ Catat Beban Pengeluaran',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              onPressed: () =>
                                  _openAddExpenseModal(context, effBranch),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: hasActiveShift
                                    ? AppColors.obsidian
                                    : AppColors.info,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              icon: Icon(
                                hasActiveShift
                                    ? Icons.lock_clock_rounded
                                    : Icons.lock_open_rounded,
                                size: 16,
                              ),
                              label: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  hasActiveShift
                                      ? 'Tutup Shift & Closing'
                                      : 'Buka Shift Kasir',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              onPressed: () => _openShiftModal(
                                context,
                                effectiveShift,
                                expectedCash,
                                effBranch,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 4. MAIN REVENUE CARD
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(20),
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
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          'Total Omset ($dateLabel)',
                                          style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.8,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isConsolidated) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.warning,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'Konsolidasi',
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.payments_rounded,
                                  color: Colors.white70,
                                  size: 20,
                                ),
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
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 14),
                            const Divider(color: Colors.white24, height: 1),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.money_rounded,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Tunai (Cash)',
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              CurrencyFormatter.format(
                                                cashTotal,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 28,
                                  color: Colors.white24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.credit_card_rounded,
                                        size: 16,
                                        color: Colors.white70,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Non-Tunai',
                                              style: TextStyle(
                                                color: Colors.white60,
                                                fontSize: 10,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              CurrencyFormatter.format(
                                                nonCashTotal,
                                              ),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 5. INCOME TYPE BREAKDOWN
                      if (data['breakdown_by_type'] is Map) ...[
                        Text(
                          'Sumber Pendapatan',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                                color: AppColors.textMuted,
                              ),
                        ),
                        const SizedBox(height: 10),
                        Builder(
                          builder: (_) {
                            final typeMap = data['breakdown_by_type'] as Map;
                            final types = [
                              'rental',
                              'extension',
                              'penalty',
                              if (typeMap.containsKey('refund') &&
                                  ((typeMap['refund'] is Map &&
                                          (typeMap['refund']['count'] ?? 0) >
                                              0) ||
                                      CurrencyFormatter.parse(
                                            (typeMap['refund'] is Map
                                                ? typeMap['refund']['total']
                                                : null),
                                          ) >
                                          0))
                                'refund',
                            ];
                            return Container(
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Column(
                                children: [
                                  for (int i = 0; i < types.length; i++) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: AppColors.surfaceMuted,
                                      ),
                                    Builder(
                                      builder: (_) {
                                        final key = types[i];
                                        final info = typeMap[key] is Map
                                            ? (typeMap[key] as Map)
                                            : {};
                                        final label =
                                            info['label'] ??
                                            (key == 'penalty'
                                                ? 'Denda Keterlambatan'
                                                : (key == 'extension'
                                                      ? 'Perpanjangan Sewa'
                                                      : (key == 'refund'
                                                            ? 'Pengembalian Deposit (Refund)'
                                                            : 'Sewa Kontrak Pokok')));
                                        final total = CurrencyFormatter.parse(
                                          info['total'],
                                        );
                                        final count = info['count'] ?? 0;
                                        final isPenalty = key == 'penalty';
                                        final isExtension = key == 'extension';

                                        final icon = isPenalty
                                            ? Icons.warning_amber_rounded
                                            : (isExtension
                                                  ? Icons.update_rounded
                                                  : Icons.vpn_key_outlined);
                                        final iconColor = isPenalty
                                            ? Colors.deepOrange
                                            : (isExtension
                                                  ? AppColors.info
                                                  : AppColors.obsidian);
                                        final iconBg = isPenalty
                                            ? Colors.deepOrange.withValues(
                                                alpha: 0.1,
                                              )
                                            : (isExtension
                                                  ? AppColors.infoLight
                                                  : AppColors.surfaceMuted);

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: iconBg,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  icon,
                                                  size: 18,
                                                  color: iconColor,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      label,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                        color:
                                                            isPenalty &&
                                                                total > 0
                                                            ? Colors
                                                                  .deepOrange
                                                                  .shade800
                                                            : AppColors
                                                                  .textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '$count Transaksi',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                CurrencyFormatter.format(total),
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: isPenalty && total > 0
                                                      ? Colors.deepOrange
                                                      : AppColors.obsidian,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 6. BRANCH CONTRIBUTION BREAKDOWN
                      if (data['breakdown_by_branch'] is List &&
                          (data['breakdown_by_branch'] as List).isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Kontribusi Omset per Cabang',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(data['breakdown_by_branch'] as List).length} Cabang Terdata',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...(data['breakdown_by_branch'] as List).map((bItem) {
                          final b = bItem is Map ? bItem : {};
                          final bName = b['branch_name'] ?? 'Cabang';
                          final isCent = b['is_central'] == true;
                          final bRev = CurrencyFormatter.parse(
                            b['total_revenue'],
                          );
                          final bCash = CurrencyFormatter.parse(
                            b['cash_revenue'],
                          );
                          final bNonCash = CurrencyFormatter.parse(
                            b['non_cash_revenue'],
                          );
                          final bTxCount = b['transaction_count'] ?? 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isCent
                                                  ? AppColors.warningLight
                                                  : AppColors.infoLight,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              isCent ? 'Pusat' : 'Cabang',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isCent
                                                    ? AppColors.warning
                                                    : AppColors.info,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              bName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      CurrencyFormatter.format(bRev),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                        color: AppColors.obsidian,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '$bTxCount Transaksi',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        'Tunai: ${CurrencyFormatter.format(bCash)} • Non-Tunai: ${CurrencyFormatter.format(bNonCash)}',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      // 7. PAYMENT METHOD BREAKDOWN
                      Text(
                        'Rincian Metode Pembayaran',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: breakdown.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(18),
                                child: Center(
                                  child: Text(
                                    'Belum ada transaksi pembayaran di periode ini.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                children: [
                                  for (
                                    int i = 0;
                                    i < breakdown.entries.length;
                                    i++
                                  ) ...[
                                    if (i > 0)
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: AppColors.surfaceMuted,
                                      ),
                                    Builder(
                                      builder: (_) {
                                        final entry = breakdown.entries
                                            .elementAt(i);
                                        final val = entry.value is Map
                                            ? (entry.value as Map)
                                            : {};
                                        final total = CurrencyFormatter.parse(
                                          val['total'],
                                        );
                                        final count = val['count'] ?? 0;
                                        final kStr = entry.key
                                            .toString()
                                            .toLowerCase();

                                        final IconData methodIcon;
                                        if (kStr.contains('tunai') ||
                                            kStr == 'cash') {
                                          methodIcon = Icons.money_rounded;
                                        } else if (kStr.contains('qris')) {
                                          methodIcon =
                                              Icons.qr_code_scanner_rounded;
                                        } else if (kStr.contains('transfer') ||
                                            kStr.contains('bank')) {
                                          methodIcon =
                                              Icons.account_balance_rounded;
                                        } else if (kStr.contains('edc') ||
                                            kStr.contains('card') ||
                                            kStr.contains('kartu')) {
                                          methodIcon =
                                              Icons.credit_card_rounded;
                                        } else {
                                          methodIcon = Icons
                                              .account_balance_wallet_outlined;
                                        }

                                        return Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  7,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.surfaceMuted,
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Icon(
                                                  methodIcon,
                                                  size: 18,
                                                  color: AppColors.obsidian,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      entry.key,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        fontSize: 12,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '$count Transaksi',
                                                      style: const TextStyle(
                                                        fontSize: 11,
                                                        color:
                                                            AppColors.textMuted,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                CurrencyFormatter.format(total),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 16),

                      // 8. RECENT COMPLETED TRANSACTIONS
                      if (data['recent_transactions'] is List &&
                          (data['recent_transactions'] as List).isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Text(
                                'Transaksi Terbaru (Audit Rincian)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: AppColors.textMuted,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                              ),
                              icon: const Icon(
                                Icons.menu_book_rounded,
                                size: 14,
                              ),
                              label: const Text(
                                'Buku Kas Lengkap',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const FinancialActivityLedgerScreen(),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...(data['recent_transactions'] as List).map((txItem) {
                          final tx = txItem is Map ? txItem : {};
                          final txCode =
                              tx['receipt_number'] ??
                              tx['transaction_code'] ??
                              'TX';
                          final custName = tx['customer_name'] ?? 'Pelanggan';
                          final brName = tx['branch_name'] ?? 'Cabang';
                          final isCent = tx['is_central'] == true;
                          final txAmt = CurrencyFormatter.parse(tx['amount']);
                          final pMethod = tx['payment_method'] ?? 'Tunai';
                          final cashier = tx['cashier_name'] ?? 'Kasir';
                          final itemsSummary =
                              tx['items_summary'] ?? 'Perangkat Apple';
                          final txType = tx['type']?.toString().toLowerCase();
                          final txTypeLabel =
                              tx['type_label'] ??
                              (txType == 'penalty'
                                  ? 'Denda Keterlambatan'
                                  : null);

                          return InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => _openTransactionDetailSheet(
                              context,
                              Map<String, dynamic>.from(tx),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isCent
                                                    ? AppColors.warningLight
                                                    : AppColors.infoLight,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isCent ? 'Pusat' : brName,
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isCent
                                                      ? AppColors.warning
                                                      : AppColors.info,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Flexible(
                                              child: Text(
                                                txCode,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (txType == 'penalty') ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.deepOrange
                                                      .withValues(alpha: 0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Kasir: $cashier • $pMethod${txTypeLabel != null ? ' • $txTypeLabel' : ''}',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: AppColors.textMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        CurrencyFormatter.format(txAmt),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: AppColors.obsidian,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        size: 18,
                                        color: AppColors.textMuted,
                                      ),
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

              // LOGOUT BUTTON
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.dangerLight),
                  backgroundColor: AppColors.dangerLight.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: const Text(
                  'Keluar dari Akun Kasir',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                onPressed: () {
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _buildStickyClosingBottomBar(closingAsync),
    );
  }

  Widget? _buildStickyClosingBottomBar(
    AsyncValue<Map<String, dynamic>> closingAsync,
  ) {
    return closingAsync.maybeWhen(
      data: (data) {
        final recon = data['cash_reconciliation'] is Map
            ? (data['cash_reconciliation'] as Map)
            : {};
        final activeShift = recon['active_shift'] is Map
            ? Map<String, dynamic>.from(recon['active_shift'] as Map)
            : null;
        final currentShiftAsync = ref.watch(currentShiftProvider);
        final shiftPayload = currentShiftAsync.asData?.value;
        final currentShiftData = shiftPayload?['data']?['shift'] is Map
            ? Map<String, dynamic>.from(shiftPayload!['data']['shift'] as Map)
            : null;
        final effectiveShift = currentShiftData ?? activeShift;
        final hasActiveShift =
            effectiveShift != null && effectiveShift['status'] == 'open';

        final Map<String, dynamic> breakdown =
            data['breakdown_by_method'] is Map
            ? Map<String, dynamic>.from(data['breakdown_by_method'] as Map)
            : {};
        final cashTotal = _calcCashTotal(breakdown);
        final cashExp = CurrencyFormatter.parse(data['cash_drawer_expenses']);
        final openingFloat = CurrencyFormatter.parse(
          effectiveShift?['opening_cash_float'] ?? recon['opening_cash_float'],
        );

        final double expectedCash;
        if (effectiveShift != null &&
            effectiveShift['expected_cash_now'] != null) {
          expectedCash = CurrencyFormatter.parse(
            effectiveShift['expected_cash_now'],
          );
        } else if (recon.containsKey('expected_cash_in_drawer')) {
          expectedCash = CurrencyFormatter.parse(
            recon['expected_cash_in_drawer'],
          );
        } else {
          expectedCash =
              (cashTotal - cashExp > 0 ? cashTotal - cashExp : 0.0) +
              openingFloat;
        }

        final bizState = ref.read(businessProvider);
        final posBranchFilter = ref.read(posFilterBranchIdProvider);
        final int? effBranch = posBranchFilter != -1
            ? (posBranchFilter ?? bizState.activeBranchId)
            : bizState.activeBranchId;

        return Container(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + MediaQuery.paddingOf(context).bottom,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                offset: const Offset(0, -3),
                blurRadius: 12,
              ),
            ],
            border: const Border(
              top: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    foregroundColor: AppColors.obsidian,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'Cetak Struk Closing',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _printClosingReceipt(context, ref, data),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveShift
                        ? AppColors.obsidian
                        : AppColors.info,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: Icon(
                    hasActiveShift
                        ? Icons.lock_clock_rounded
                        : Icons.lock_open_rounded,
                    size: 18,
                  ),
                  label: Text(
                    hasActiveShift ? 'Tutup Shift' : 'Buka Shift',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _openShiftModal(
                    context,
                    effectiveShift,
                    expectedCash,
                    effBranch,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => null,
    );
  }

  // =========================================================================
  // TAB 2: RIWAYAT SHIFT (SHIFT HISTORY & AUDIT LOGS)
  // =========================================================================
  Widget _buildShiftHistoryTab() {
    final shiftHistoryAsync = ref.watch(shiftHistoryProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(shiftHistoryProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Filter Chips (Default: 7 Hari Terakhir)
            _buildShiftHistoryDateFilterChips(),
            const SizedBox(height: 14),

            shiftHistoryAsync.when(
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
                    Text(
                      'Gagal memuat riwayat shift:\n$e',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Coba Lagi'),
                      onPressed: () => ref.refresh(shiftHistoryProvider),
                    ),
                  ],
                ),
              ),
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.history_rounded,
                            size: 36,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Belum ada riwayat shift yang ditutup untuk rentang waktu ini.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: shifts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final shift = shifts[index];
                    return _buildShiftHistoryCard(shift);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftHistoryCard(Map<String, dynamic> shift) {
    final shiftNum = shift['shift_number'] ?? 'SHF-${shift['id'] ?? ''}';
    final cashier =
        shift['cashier_name'] ?? shift['cashier']?['name'] ?? 'Kasir';
    final openedAtStr = shift['opened_at'] ?? shift['created_at'];
    final closedAtStr = shift['closed_at'] ?? shift['updated_at'];
    final openedAt = openedAtStr != null
        ? DateTime.tryParse(openedAtStr.toString())
        : null;
    final closedAt = closedAtStr != null
        ? DateTime.tryParse(closedAtStr.toString())
        : null;

    final durationStr = (openedAt != null && closedAt != null)
        ? '${DateFormatter.formatTime(openedAt)} - ${DateFormatter.formatTime(closedAt)}'
        : (openedAt != null ? DateFormatter.formatFull(openedAt) : '-');

    final dateStr = openedAt != null
        ? DateFormatter.formatShort(openedAt)
        : 'Shift';

    final openingFloat = CurrencyFormatter.parse(shift['opening_cash_float']);
    final totalSales = CurrencyFormatter.parse(
      shift['total_sales'] ?? shift['cash_inflow'] ?? shift['total_revenue'],
    );
    final actual = CurrencyFormatter.parse(shift['actual_cash_counted']);
    final expected = CurrencyFormatter.parse(
      shift['expected_cash_total'] ?? shift['expected_cash'],
    );
    final diff = CurrencyFormatter.parse(
      shift['cash_difference'] ?? (actual - expected),
    );

    final isSesuai = diff.abs() < 1;
    final isKurang = diff < -1;

    final String statusLabel;
    final Color statusColor;
    final Color statusBg;
    if (isSesuai) {
      statusLabel = 'SESUAI';
      statusColor = AppColors.success;
      statusBg = AppColors.successLight;
    } else if (isKurang) {
      statusLabel = 'KURANG: ${CurrencyFormatter.format(diff.abs())}';
      statusColor = AppColors.danger;
      statusBg = AppColors.dangerLight;
    } else {
      statusLabel = 'LEBIH: ${CurrencyFormatter.format(diff)}';
      statusColor = Colors.deepOrange;
      statusBg = Colors.deepOrange.withValues(alpha: 0.12);
    }

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
          // Header: Shift Name / Date, Cashier Name, and Duration
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift #$shiftNum • $dateStr',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: AppColors.obsidian,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Kasir: $cashier • $durationStr',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Status Pill (no decorative icons)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Financial Breakdown: Modal Awal • Total Penjualan • Total Fisik Kas Terhitung • Selisih
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modal Awal',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(openingFloat),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Penjualan',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(totalSales),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Kas Terhitung',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(actual),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selisih',
                      style: TextStyle(
                        fontSize: 10,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(diff),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: isSesuai
                              ? AppColors.success
                              : (isKurang
                                    ? AppColors.danger
                                    : Colors.deepOrange),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Actions Row: "Lihat Rekap Lengkap" and "Cetak Ulang Struk (ESC/POS)"
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    foregroundColor: AppColors.obsidian,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () => _showShiftDetailModal(context, shift),
                  child: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Lihat Rekap Lengkap',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    minimumSize: Size.zero,
                    foregroundColor: AppColors.obsidian,
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Cetak Ulang Struk',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onPressed: () => _reprintShiftClosingReceipt(context, shift),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showShiftDetailModal(BuildContext context, Map<String, dynamic> shift) {
    final shiftNum = shift['shift_number'] ?? 'SHF-${shift['id'] ?? ''}';
    final cashier =
        shift['cashier_name'] ?? shift['cashier']?['name'] ?? 'Kasir';
    final branch =
        shift['branch_name'] ?? shift['affiliate']?['name'] ?? 'Cabang';
    final openedAtStr = shift['opened_at'] ?? shift['created_at'];
    final closedAtStr = shift['closed_at'] ?? shift['updated_at'];
    final openedAt = openedAtStr != null
        ? DateTime.tryParse(openedAtStr.toString())
        : null;
    final closedAt = closedAtStr != null
        ? DateTime.tryParse(closedAtStr.toString())
        : null;

    final openingFloat = CurrencyFormatter.parse(shift['opening_cash_float']);
    final totalSales = CurrencyFormatter.parse(
      shift['total_sales'] ?? shift['cash_inflow'] ?? shift['total_revenue'],
    );
    final expenses = CurrencyFormatter.parse(
      shift['cash_expenses'] ?? shift['cash_drawer_expenses'],
    );
    final actual = CurrencyFormatter.parse(shift['actual_cash_counted']);
    final expected = CurrencyFormatter.parse(
      shift['expected_cash_total'] ?? shift['expected_cash'],
    );
    final diff = CurrencyFormatter.parse(
      shift['cash_difference'] ?? (actual - expected),
    );
    final reason = shift['difference_reason']?.toString();
    final notes = shift['closing_notes']?.toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AUDIT REKAP SHIFT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        'Shift #$shiftNum',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    _buildDetailRow('Kasir', cashier),
                    const SizedBox(height: 8),
                    _buildDetailRow('Cabang', branch),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Waktu Buka',
                      openedAt != null
                          ? DateFormatter.formatFull(openedAt)
                          : '-',
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Waktu Tutup',
                      closedAt != null
                          ? DateFormatter.formatFull(closedAt)
                          : '-',
                    ),
                    const Divider(height: 20),
                    _buildDetailRow(
                      'Modal Awal Kas Laci',
                      CurrencyFormatter.format(openingFloat),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Kas Masuk Penjualan',
                      CurrencyFormatter.format(totalSales),
                      valueColor: AppColors.success,
                    ),
                    if (expenses > 0) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow(
                        'Pengeluaran Kas Laci',
                        '-${CurrencyFormatter.format(expenses)}',
                        valueColor: AppColors.danger,
                      ),
                    ],
                    const Divider(height: 20),
                    _buildDetailRow(
                      'Fisik Kas Wajib Ada',
                      CurrencyFormatter.format(expected),
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Fisik Kas Hasil Hitung',
                      CurrencyFormatter.format(actual),
                      isBold: true,
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Selisih Kas (Variance)',
                      CurrencyFormatter.format(diff),
                      isBold: true,
                      valueColor: diff == 0
                          ? AppColors.success
                          : (diff < 0 ? AppColors.danger : Colors.deepOrange),
                    ),
                  ],
                ),
              ),

              if (reason != null && reason.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Alasan Selisih Kas:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.danger,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reason,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (notes != null && notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Catatan Closing:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notes,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(
                  'Cetak Ulang Struk Closing',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _reprintShiftClosingReceipt(context, shift);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isBold ? AppColors.obsidian : AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 12 : 11,
            color: valueColor ?? AppColors.obsidian,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _reprintShiftClosingReceipt(
    BuildContext context,
    Map<String, dynamic> shift,
  ) {
    final shiftNum = shift['shift_number'] ?? 'SHF-${shift['id'] ?? ''}';
    final cashierName =
        shift['cashier_name'] ?? shift['cashier']?['name'] ?? 'Kasir Bertugas';
    final branchName =
        shift['branch_name'] ??
        shift['affiliate']?['name'] ??
        'Cabang Operasional RentCore';
    final openedAtStr = shift['opened_at'] ?? shift['created_at'];
    final closedAtStr = shift['closed_at'] ?? shift['updated_at'];
    final openedAt = openedAtStr != null
        ? DateTime.tryParse(openedAtStr.toString())
        : null;
    final closedAt = closedAtStr != null
        ? DateTime.tryParse(closedAtStr.toString())
        : null;

    final dateStr = (openedAt != null && closedAt != null)
        ? '${DateFormatter.formatShort(openedAt)} (${DateFormatter.formatTime(openedAt)} - ${DateFormatter.formatTime(closedAt)})'
        : (openedAt != null
              ? DateFormatter.formatFull(openedAt)
              : DateTime.now().toString().substring(0, 16));

    final actual = CurrencyFormatter.parse(shift['actual_cash_counted']);
    final expected = CurrencyFormatter.parse(
      shift['expected_cash_total'] ?? shift['expected_cash'],
    );
    final diff = CurrencyFormatter.parse(
      shift['cash_difference'] ?? (actual - expected),
    );
    final openingFloat = CurrencyFormatter.parse(shift['opening_cash_float']);
    final netCash = CurrencyFormatter.parse(
      shift['cash_inflow'] ?? shift['net_cash_revenue'] ?? shift['total_sales'],
    );
    final cashExpenses = CurrencyFormatter.parse(
      shift['cash_expenses'] ?? shift['cash_drawer_expenses'],
    );
    final totalTx =
        int.tryParse(shift['total_transactions']?.toString() ?? '0') ?? 1;

    final breakdownMap = <String, double>{
      'Modal Awal': openingFloat,
      'Kas Masuk': netCash,
      if (cashExpenses > 0) 'Beban Laci': -cashExpenses,
      'Fisik Kas Dihitung': actual,
    };

    final printerService = ThermalPrinterService();
    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: branchName,
      cashierName: cashierName,
      date: dateStr,
      totalTransactions: totalTx,
      totalRevenue: actual,
      paymentBreakdown: breakdownMap,
      openingCashFloat: openingFloat > 0 ? openingFloat : null,
      netCashRevenue: netCash,
      cashDrawerExpenses: cashExpenses > 0 ? cashExpenses : null,
      expectedCashInDrawer: expected,
      shiftNumber: shiftNum.toString(),
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Preview Cetak Struk Closing',
        branchName: branchName,
        escposBytes: escposBytes,
        content: Column(
          children: [
            const Text(
              'LAPORAN CLOSING SHIFT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text(
              'Shift: #$shiftNum',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.info,
              ),
            ),
            Text('Kasir: $cashierName', style: const TextStyle(fontSize: 11)),
            Text(
              'Waktu: $dateStr',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Fisik Dihitung:',
                    style: TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(actual),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Ekspektasi Sistem:',
                    style: TextStyle(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(expected),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Selisih Kas:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(diff),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: diff == 0
                          ? AppColors.success
                          : (diff < 0 ? AppColors.danger : Colors.deepOrange),
                    ),
                  ),
                ),
              ],
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

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCompactFilterChip('Hari Ini', activeLabel == 'Hari Ini', () {
            final nowStr = DateTime.now().toIso8601String().substring(0, 10);
            ref
                .read(posDateRangeProvider.notifier)
                .setDateRange(
                  label: 'Hari Ini',
                  startDate: nowStr,
                  endDate: nowStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Kemarin', activeLabel == 'Kemarin', () {
            final now = DateTime.now();
            final yesterday = DateTime(now.year, now.month, now.day - 1);
            final yStr = yesterday.toIso8601String().substring(0, 10);
            ref
                .read(posDateRangeProvider.notifier)
                .setDateRange(label: 'Kemarin', startDate: yStr, endDate: yStr);
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Bulan Ini', activeLabel == 'Bulan Ini', () {
            final now = DateTime.now();
            final startOfMonth = DateTime(
              now.year,
              now.month,
              1,
            ).toIso8601String().substring(0, 10);
            final todayStr = now.toIso8601String().substring(0, 10);
            ref
                .read(posDateRangeProvider.notifier)
                .setDateRange(
                  label: 'Bulan Ini',
                  startDate: startOfMonth,
                  endDate: todayStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCustomDateFilterChip(activeLabel),
        ],
      ),
    );
  }

  Widget _buildShiftHistoryDateFilterChips() {
    final dateState = ref.watch(shiftHistoryDateRangeProvider);
    final activeLabel = dateState.label;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCompactFilterChip(
            '7 Hari Terakhir',
            activeLabel == '7 Hari Terakhir',
            () {
              final now = DateTime.now();
              final start = now
                  .subtract(const Duration(days: 6))
                  .toIso8601String()
                  .substring(0, 10);
              final end = now.toIso8601String().substring(0, 10);
              ref
                  .read(shiftHistoryDateRangeProvider.notifier)
                  .setDateRange(
                    label: '7 Hari Terakhir',
                    startDate: start,
                    endDate: end,
                  );
            },
          ),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Hari Ini', activeLabel == 'Hari Ini', () {
            final nowStr = DateTime.now().toIso8601String().substring(0, 10);
            ref
                .read(shiftHistoryDateRangeProvider.notifier)
                .setDateRange(
                  label: 'Hari Ini',
                  startDate: nowStr,
                  endDate: nowStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Kemarin', activeLabel == 'Kemarin', () {
            final now = DateTime.now();
            final yesterday = DateTime(now.year, now.month, now.day - 1);
            final yStr = yesterday.toIso8601String().substring(0, 10);
            ref
                .read(shiftHistoryDateRangeProvider.notifier)
                .setDateRange(label: 'Kemarin', startDate: yStr, endDate: yStr);
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Bulan Ini', activeLabel == 'Bulan Ini', () {
            final now = DateTime.now();
            final startOfMonth = DateTime(
              now.year,
              now.month,
              1,
            ).toIso8601String().substring(0, 10);
            final todayStr = now.toIso8601String().substring(0, 10);
            ref
                .read(shiftHistoryDateRangeProvider.notifier)
                .setDateRange(
                  label: 'Bulan Ini',
                  startDate: startOfMonth,
                  endDate: todayStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCustomShiftHistoryDateFilterChip(activeLabel),
        ],
      ),
    );
  }

  Widget _buildCompactFilterChip(
    String label,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected ? Colors.white : AppColors.textPrimary,
        ),
      ),
      selected: isSelected,
      showCheckmark: false,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isSelected ? AppColors.obsidian : AppColors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onSelected: (_) => onTap(),
    );
  }

  Widget _buildCustomDateFilterChip(String activeLabel) {
    final isCustom =
        activeLabel != 'Hari Ini' &&
        activeLabel != 'Kemarin' &&
        activeLabel != 'Bulan Ini';
    return ActionChip(
      avatar: Icon(
        Icons.date_range_rounded,
        size: 14,
        color: isCustom ? Colors.white : AppColors.textMuted,
      ),
      label: Text(
        isCustom ? activeLabel : 'Rentang Kustom',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500,
          color: isCustom ? Colors.white : AppColors.textPrimary,
        ),
      ),
      backgroundColor: isCustom ? AppColors.obsidian : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCustom ? AppColors.obsidian : AppColors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) {
          final startStr = picked.start.toIso8601String().substring(0, 10);
          final endStr = picked.end.toIso8601String().substring(0, 10);
          ref
              .read(posDateRangeProvider.notifier)
              .setDateRange(
                label: '$startStr s/d $endStr',
                startDate: startStr,
                endDate: endStr,
              );
        }
      },
    );
  }

  Widget _buildCustomShiftHistoryDateFilterChip(String activeLabel) {
    final isCustom =
        activeLabel != '7 Hari Terakhir' &&
        activeLabel != 'Hari Ini' &&
        activeLabel != 'Kemarin' &&
        activeLabel != 'Bulan Ini';
    return ActionChip(
      avatar: Icon(
        Icons.date_range_rounded,
        size: 14,
        color: isCustom ? Colors.white : AppColors.textMuted,
      ),
      label: Text(
        isCustom ? activeLabel : 'Rentang Kustom',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500,
          color: isCustom ? Colors.white : AppColors.textPrimary,
        ),
      ),
      backgroundColor: isCustom ? AppColors.obsidian : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isCustom ? AppColors.obsidian : AppColors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () async {
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now().add(const Duration(days: 30)),
        );
        if (picked != null) {
          final startStr = picked.start.toIso8601String().substring(0, 10);
          final endStr = picked.end.toIso8601String().substring(0, 10);
          ref
              .read(shiftHistoryDateRangeProvider.notifier)
              .setDateRange(
                label: '$startStr s/d $endStr',
                startDate: startStr,
                endDate: endStr,
              );
        }
      },
    );
  }

  void _printClosingReceipt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
  ) {
    final authState = ref.read(authProvider);
    final user = authState.user;
    final branchName =
        user?['affiliate']?['name'] ?? 'Cabang Operasional RentCore';
    final cashierName = user?['name'] ?? 'Kasir Bertugas';
    final totalRev = CurrencyFormatter.parse(data['total_revenue']);
    final totalTx =
        int.tryParse(data['total_transactions']?.toString() ?? '0') ?? 0;

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
    final recon = data['cash_reconciliation'] is Map
        ? (data['cash_reconciliation'] as Map)
        : {};
    final activeShift = recon['active_shift'] is Map
        ? (recon['active_shift'] as Map)
        : null;
    final shiftNum = activeShift?['shift_number']?.toString();
    final openingFloat = CurrencyFormatter.parse(recon['opening_cash_float']);
    final netCash = CurrencyFormatter.parse(recon['net_cash_revenue']);
    final cashExpenses = CurrencyFormatter.parse(recon['cash_drawer_expenses']);
    final expectedDrawerCash = recon.containsKey('expected_cash_in_drawer')
        ? CurrencyFormatter.parse(recon['expected_cash_in_drawer'])
        : null;

    final printerService = ThermalPrinterService();
    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: branchName,
      cashierName: cashierName,
      date: dateStr,
      totalTransactions: totalTx,
      totalRevenue: totalRev,
      paymentBreakdown: breakdownMap,
      openingCashFloat: openingFloat > 0 ? openingFloat : null,
      netCashRevenue: netCash,
      cashDrawerExpenses: cashExpenses > 0 ? cashExpenses : null,
      expectedCashInDrawer: expectedDrawerCash,
      shiftNumber: shiftNum,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Preview Closing Kasir',
        branchName: branchName,
        escposBytes: escposBytes,
        content: Column(
          children: [
            const Text(
              'LAPORAN CLOSING SHIFT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            if (shiftNum != null)
              Text(
                'Shift: #$shiftNum',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.info,
                ),
              ),
            Text('Kasir: $cashierName', style: const TextStyle(fontSize: 11)),
            Text(
              'Waktu: $dateStr',
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Transaksi:', style: TextStyle(fontSize: 11)),
                Text(
                  '$totalTx',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Omset:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  CurrencyFormatter.format(totalRev),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            if (expectedDrawerCash != null) ...[
              const Divider(height: 16),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'REKONSILIASI KAS LACI',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              if (openingFloat > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Modal Awal Laci:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(openingFloat),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Kas Masuk Bersih:',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(netCash),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (cashExpenses > 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Beban Kas Laci:',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      '-${CurrencyFormatter.format(cashExpenses)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'FISIK KAS LACI:',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    CurrencyFormatter.format(expectedDrawerCash),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.obsidian,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

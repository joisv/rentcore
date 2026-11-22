import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/dock_aware_scaffold.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/cashier_provider.dart';
import 'widgets/add_branch_expense_modal.dart';
import 'widgets/cash_drawer_shift_modal.dart';
import 'widgets/report_shared_widgets.dart';

class CashierScreen extends StatelessWidget {
  const CashierScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Kasir & Shift',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: const CashierShiftView(),
    );
  }
}

/// Alias for CashierScreen focusing on shift drawer duties
typedef ShiftScreen = CashierScreen;

/// Embeddable Cashier & Shift view used both in [CashierScreen]
/// and inside Tab 2 ('Kasir & Shift') of [FinancialHubScreen].
class CashierShiftView extends ConsumerStatefulWidget {
  final bool embedded;

  const CashierShiftView({super.key, this.embedded = false});

  @override
  ConsumerState<CashierShiftView> createState() => _CashierShiftViewState();
}

class _CashierShiftViewState extends ConsumerState<CashierShiftView>
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
    return ColoredBox(
      color: Colors.white,
      child: Column(
        children: [
          _buildBranchSelectorHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: const Color(0xFF0F172A),
                unselectedLabelColor: const Color(0xFF64748B),
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                ),
                tabs: const [
                  Tab(text: 'Shift Aktif'),
                  Tab(text: 'Riwayat Shift'),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
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
      final rawName =
          (match?['name'] ??
                  (bizState.resolvedBranchName.isNotEmpty
                      ? bizState.resolvedBranchName
                      : 'Cabang Terpilih'))
              .toString();
      branchLabel = formatReportBranchName(rawName);
    }

    final switchable = isCentralUser && branches.length > 1;
    return ReportBranchScopeBar(
      branchLabel: branchLabel,
      isConsolidated: isConsolidated,
      switchable: switchable,
      onTapSwitch: switchable
          ? () => _showBranchFilterModal(
              context,
              branches,
              isConsolidated,
              posBranchFilter,
            )
          : null,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
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
                  final bName = formatReportBranchName((b['name'] ?? 'Cabang').toString());
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
                      isCent ? 'Kantor Pusat' : 'Cabang',
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

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(closingSummaryProvider);
        ref.invalidate(currentShiftProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          0,
          16,
          0,
          104 + MediaQuery.paddingOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            closingAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ActiveShiftSkeleton(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
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
              ),
              data: (data) {
                final Map<String, dynamic> breakdown =
                    data['breakdown_by_method'] is Map
                    ? Map<String, dynamic>.from(
                        data['breakdown_by_method'] as Map,
                      )
                    : {};

                final cashTotal = _calcCashTotal(breakdown);
                final nonCashTotal = _calcNonCashTotal(breakdown);

                final recon = data['cash_reconciliation'] is Map
                    ? (data['cash_reconciliation'] as Map)
                    : {};
                final activeShift = recon['active_shift'] is Map
                    ? Map<String, dynamic>.from(recon['active_shift'] as Map)
                    : null;
                final shiftPayload = currentShiftAsync.asData?.value;
                final dynamic rawShift =
                    shiftPayload?['shift'] ?? shiftPayload?['data']?['shift'];
                final currentShiftData = rawShift is Map
                    ? Map<String, dynamic>.from(rawShift)
                    : null;
                final effectiveShift = currentShiftData ?? activeShift;
                final hasActiveShift =
                    effectiveShift != null &&
                    effectiveShift['status'] == 'open';

                final cashExp = CurrencyFormatter.parse(
                  data['cash_drawer_expenses'],
                );

                final openingFloat = CurrencyFormatter.parse(
                  effectiveShift?['opening_cash_float'] ??
                      recon['opening_cash_float'],
                );

                final isBlindClose =
                    hasActiveShift &&
                    (effectiveShift['is_blind_close'] == true ||
                        recon['is_blind_close'] == true ||
                        data['is_blind_close'] == true ||
                        (effectiveShift['expected_cash_now'] == null &&
                            !recon.containsKey('expected_cash_in_drawer')));

                final double expectedCash;
                if (isBlindClose) {
                  expectedCash = 0.0;
                } else if (effectiveShift != null &&
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
                final rawBranchName =
                    (effectiveShift?['branch_name'] ??
                            effectiveShift?['affiliate']?['name'] ??
                            (bizState.resolvedBranchName.isNotEmpty
                                ? bizState.resolvedBranchName
                                : 'Cabang'))
                        .toString();
                final branchName = formatReportBranchName(rawBranchName);
                final openedAt =
                    effectiveShift?['opened_at'] ??
                    effectiveShift?['created_at'];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. ACTIVE SESSION INFO (Flat Hairline Section)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.badge_outlined,
                            size: 20,
                            color: Color(0xFF0F172A),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Sesi Kasir Berjalan',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: hasActiveShift
                                ? const Color(0xFFECFDF5)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: hasActiveShift
                                  ? const Color(0xFFA7F3D0)
                                  : const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: hasActiveShift
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 7),
                              Flexible(
                                child: Text(
                                  hasActiveShift
                                      ? 'Shift #${effectiveShift['shift_number'] ?? effectiveShift['id']} • Aktif'
                                      : 'Shift Ditutup',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                    color: hasActiveShift
                                        ? const Color(0xFF047857)
                                        : const Color(0xFF64748B),
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (hasActiveShift) ...[
                      _buildKeyValueRow('Kasir Bertugas', cashierName),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFFF1F5F9),
                      ),
                      _buildKeyValueRow('Cabang Operasional', branchName),
                      if (openedAt != null) ...[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                          color: Color(0xFFF1F5F9),
                        ),
                        _buildKeyValueRow(
                          'Waktu Buka Shift',
                          DateFormatter.formatFull(
                            DateTime.tryParse(openedAt.toString()),
                          ),
                        ),
                      ],
                      if (!isBlindClose) ...[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                          color: Color(0xFFF1F5F9),
                        ),
                        _buildKeyValueRow(
                          'Modal Kas Awal',
                          CurrencyFormatter.format(openingFloat),
                          isTabularAmount: true,
                        ),
                      ],
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Laci kasir belum memiliki sesi shift aktif. Buka shift kasir untuk memasukkan modal awal kas laci.',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 46,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.meeting_room_outlined,
                                  size: 18,
                                ),
                                label: const Text(
                                  'Buka Shift Sekarang',
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
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
                      ),
                    ],
                    const SizedBox(height: 8),
                    const Divider(
                      height: 1,
                      thickness: 1,
                      color: Color(0xFFF1F5F9),
                    ),

                    // 2. REAL-TIME CASH SUMMARY
                    const ReportSectionHeader(
                      title: 'Rekonsiliasi Kas Laci & Beban',
                    ),

                    if (isBlindClose) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.visibility_off_outlined,
                                size: 20,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Total Kas Laci (Blind Close)',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Shift #${effectiveShift['shift_number'] ?? effectiveShift['id']}${openedAt != null ? ' • Dibuka ${DateFormatter.formatFull(DateTime.tryParse(openedAt.toString()))}' : ''}',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Nominal kas laci disembunyikan hingga shift ditutup (Mode Blind Close).',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                        height: 1.35,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _buildKeyValueRow(
                        'Total Non-Tunai (QRIS / Bank / EDC)',
                        CurrencyFormatter.format(nonCashTotal),
                        isTabularAmount: true,
                      ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kas Masuk Tunai',
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Kas Masuk Bersih (Sistem)',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF64748B),
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
                                fontWeight: FontWeight.w600,
                                fontSize: 14.5,
                                color: Color(0xFF059669),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFFF1F5F9),
                      ),
                      _buildKeyValueRow(
                        'Total Non-Tunai (QRIS / Bank / EDC)',
                        CurrencyFormatter.format(nonCashTotal),
                        isTabularAmount: true,
                      ),
                      if (openingFloat > 0) ...[
                        const Divider(
                          height: 1,
                          thickness: 1,
                          indent: 20,
                          endIndent: 20,
                          color: Color(0xFFF1F5F9),
                        ),
                        _buildKeyValueRow(
                          'Modal Awal Kas Laci',
                          CurrencyFormatter.format(openingFloat),
                          isTabularAmount: true,
                        ),
                      ],
                      const Divider(
                        height: 1,
                        thickness: 1,
                        indent: 20,
                        endIndent: 20,
                        color: Color(0xFFF1F5F9),
                      ),
                      _buildKeyValueRow(
                        cashExp > 0
                            ? 'Beban Pengeluaran Cabang (Kas Laci)'
                            : 'Beban Kas Keluar (Laci)',
                        cashExp > 0
                            ? '-${CurrencyFormatter.format(cashExp)}'
                            : 'Rp 0',
                        valueColor: cashExp > 0
                            ? const Color(0xFFDC2626)
                            : const Color(0xFF64748B),
                        isTabularAmount: true,
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE2E8F0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Total Kas Wajib di Laci',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2),
                                    Text(
                                      'Total Fisik Kas Wajib di Laci',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: Color(0xFF64748B),
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
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0F172A),
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // 3. EXPENSE QUICK ACTION BUTTON
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: SizedBox(
                        height: 44,
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0F172A),
                            side: const BorderSide(
                              color: Color(0xFFE2E8F0),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.add_shopping_cart_outlined,
                            size: 18,
                          ),
                          label: const Text(
                            '+ Catat Beban Pengeluaran',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          onPressed: () =>
                              _openAddExpenseModal(context, effBranch),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 4. PAYMENT METHOD BREAKDOWN
                    ReportPaymentMethodList(
                      breakdown: breakdown,
                      isBlindClose: isBlindClose,
                    ),

                    // 5. RECENT COMPLETED TRANSACTIONS
                    if (data['recent_transactions'] is List &&
                        (data['recent_transactions'] as List).isNotEmpty)
                      ReportRecentTransactionsList(
                        transactions: data['recent_transactions'] as List,
                        isConsolidated: posBranchFilter == -1,
                      ),

                    const SizedBox(height: 16),
                    _buildShiftClosingActionButtons(
                      context: context,
                      data: data,
                      effectiveShift: effectiveShift,
                      hasActiveShift: hasActiveShift,
                      expectedCash: expectedCash,
                      branchId: effBranch,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyValueRow(
    String label,
    String value, {
    Color? valueColor,
    bool isTabularAmount = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: isTabularAmount ? 14 : 13,
                fontWeight: FontWeight.w600,
                color: valueColor ?? const Color(0xFF0F172A),
                fontFeatures: isTabularAmount
                    ? const [FontFeature.tabularFigures()]
                    : null,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftClosingActionButtons({
    required BuildContext context,
    required Map<String, dynamic> data,
    required Map<String, dynamic>? effectiveShift,
    required bool hasActiveShift,
    required double expectedCash,
    required int? branchId,
  }) {
    return Column(
      children: [
        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 46),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      foregroundColor: const Color(0xFF0F172A),
                      backgroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.print_outlined, size: 18),
                    label: const Text(
                      'Cetak Struk',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _printClosingReceipt(context, ref, data),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasActiveShift
                          ? const Color(0xFF0F172A)
                          : AppColors.info,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 46),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(
                      hasActiveShift
                          ? Icons.lock_clock_outlined
                          : Icons.lock_open_outlined,
                      size: 18,
                    ),
                    label: Text(
                      hasActiveShift ? 'Tutup Shift' : 'Buka Shift',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onPressed: () => _openShiftModal(
                      context,
                      effectiveShift,
                      expectedCash,
                      branchId,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
        padding: EdgeInsets.fromLTRB(
          0,
          14,
          0,
          widget.embedded ? kDockHeight + 24 : 100,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Filter Chips (Default: 7 Hari Terakhir)
            _buildShiftHistoryDateFilterChips(),
            const SizedBox(height: 16),

            shiftHistoryAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: ShiftHistoryTabSkeleton(count: 4),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(12),
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
              ),
              data: (shifts) {
                if (shifts.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 36,
                              color: Color(0xFF94A3B8),
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Belum ada riwayat shift yang ditutup untuk rentang waktu ini.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
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

    final String openedDateTimeStr;
    if (openedAt != null && closedAt != null) {
      openedDateTimeStr =
          '${DateFormatter.formatShort(openedAt)}, ${DateFormatter.formatTime(openedAt)} - ${DateFormatter.formatTime(closedAt)}';
    } else if (openedAt != null) {
      openedDateTimeStr =
          '${DateFormatter.formatShort(openedAt)}, ${DateFormatter.formatTime(openedAt)}';
    } else {
      openedDateTimeStr = '-';
    }

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
    final Color statusBorder;
    if (isSesuai) {
      statusLabel = 'Sesuai';
      statusColor = const Color(0xFF047857);
      statusBg = const Color(0xFFECFDF5);
      statusBorder = const Color(0xFFA7F3D0);
    } else if (isKurang) {
      statusLabel = 'Kurang: ${CurrencyFormatter.format(diff.abs())}';
      statusColor = const Color(0xFFB91C1C);
      statusBg = const Color(0xFFFEF2F2);
      statusBorder = const Color(0xFFFECACA);
    } else {
      statusLabel = 'Lebih: ${CurrencyFormatter.format(diff)}';
      statusColor = const Color(0xFFC2410C);
      statusBg = const Color(0xFFFFF7ED);
      statusBorder = const Color(0xFFFED7AA);
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Shift ID + Cashier & Date on clean stacked lines, Status pill on right
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Shift #$shiftNum',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Kasir: $cashier • $openedDateTimeStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: statusBorder, width: 1),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Financial Breakdown: Modal Awal • Penjualan • Kas Terhitung • Selisih
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Modal Awal',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(openingFloat),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(totalSales),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(actual),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: Color(0xFF0F172A),
                          fontFeatures: [FontFeature.tabularFigures()],
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
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        CurrencyFormatter.format(diff),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: isSesuai
                              ? const Color(0xFF059669)
                              : (isKurang
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFC2410C)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 10),

          // Actions Row: 40dp balanced buttons
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _showShiftDetailModal(context, shift),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Lihat Rekap Lengkap',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      minimumSize: const Size(0, 40),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F172A),
                      side: const BorderSide(
                        color: Color(0xFFE2E8F0),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.print_outlined, size: 15),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Cetak Ulang Struk',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    onPressed: () =>
                        _reprintShiftClosingReceipt(context, shift),
                  ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
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
                  borderRadius: BorderRadius.circular(10),
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
                    borderRadius: BorderRadius.circular(8),
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
    final bizState = ref.read(businessProvider);
    final shopName = bizState.resolvedStoreName;
    final rawBranch = (shift['branch_name']?.toString() ??
            shift['affiliate']?['name']?.toString() ??
            bizState.resolvedBranchName)
        .trim();
    final branchName = rawBranch.isNotEmpty ? rawBranch : 'Cabang Utama';
    final branchAddress = (shift['affiliate']?['address']?.toString() ??
            bizState.resolvedBranchAddress)
        .trim();
    final branchPhone = (shift['affiliate']?['phone']?.toString() ??
            bizState.resolvedBranchPhone)
        .trim();
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
    final printerSettings = ref.read(printerProvider).settings;
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
      shopName: shopName.isNotEmpty ? shopName : null,
      branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
      branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
      settings: printerSettings,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Preview Cetak Struk Closing',
        shopName: shopName.isNotEmpty ? shopName : null,
        branchName: branchName,
        branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
        branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
        isReprint: true,
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

  Widget _buildShiftHistoryDateFilterChips() {
    final dateState = ref.watch(shiftHistoryDateRangeProvider);
    final activeLabel = dateState.label;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          _buildCompactFilterChip('Kemarin', activeLabel == 'Kemarin', () {
            final now = DateTime.now();
            final yesterday = DateTime(now.year, now.month, now.day - 1);
            final yStr = yesterday.toIso8601String().substring(0, 10);
            ref
                .read(shiftHistoryDateRangeProvider.notifier)
                .setDateRange(label: 'Kemarin', startDate: yStr, endDate: yStr);
          }),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
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
    return ReportFilterPill(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildCustomShiftHistoryDateFilterChip(String activeLabel) {
    final isCustom =
        activeLabel != '7 Hari Terakhir' &&
        activeLabel != 'Hari Ini' &&
        activeLabel != 'Kemarin' &&
        activeLabel != 'Bulan Ini';
    return ReportFilterPill(
      label: isCustom ? activeLabel : 'Rentang Kustom',
      isSelected: isCustom,
      leadingIcon: Icons.date_range_outlined,
      onTap: () async {
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
    final bizState = ref.read(businessProvider);
    final user = authState.user;
    final shopName = bizState.resolvedStoreName;
    final rawBranch = (user?['affiliate']?['name']?.toString() ??
            bizState.resolvedBranchName)
        .trim();
    final branchName = rawBranch.isNotEmpty ? rawBranch : 'Cabang Utama';
    final branchAddress = (user?['affiliate']?['address']?.toString() ??
            bizState.resolvedBranchAddress)
        .trim();
    final branchPhone = (user?['affiliate']?['phone']?.toString() ??
            bizState.resolvedBranchPhone)
        .trim();
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
    final printerSettings = ref.read(printerProvider).settings;
    final paperWidth = printerSettings.paperWidth;
    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: branchName,
      cashierName: cashierName,
      date: dateStr,
      totalTransactions: totalTx,
      totalRevenue: totalRev,
      paymentBreakdown: breakdownMap,
      paperWidth: paperWidth,
      openingCashFloat: openingFloat > 0 ? openingFloat : null,
      netCashRevenue: netCash,
      cashDrawerExpenses: cashExpenses > 0 ? cashExpenses : null,
      expectedCashInDrawer: expectedDrawerCash,
      shiftNumber: shiftNum,
      shopName: shopName.isNotEmpty ? shopName : null,
      branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
      branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
      settings: printerSettings,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Preview Closing Kasir',
        shopName: shopName.isNotEmpty ? shopName : null,
        branchName: branchName,
        branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
        branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
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

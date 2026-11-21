import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/cashier_provider.dart';
import 'financial_activity_ledger_screen.dart';
import 'pos_transaction_detail_sheet.dart';
import '../../../shared/widgets/dock_aware_scaffold.dart';

/// Dedicated Revenue Report Screen (`RevenueReportScreen`) & embeddable `RevenueReportView`
///
/// Provides owner and multi-branch revenue analytics:
/// - Top Date Filter Bar (Hari Ini, Minggu Ini, Bulan Ini, Bulan Lalu, Kustom)
/// - Hero Revenue Card (Total Omzet, Tunai vs Non-Tunai)
/// - Sumber Pendapatan (Sewa Kontrak Pokok, Perpanjangan Sewa, Denda Keterlambatan)
/// - Kontribusi Omset per Cabang (only shown when multi-branch & viewing "Semua Cabang")
/// - Rincian Metode Pembayaran
/// - Audit Rincian Transaksi (clean customer & category subtitles, no repetitive branch pills when filtered)
class RevenueReportScreen extends StatelessWidget {
  const RevenueReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Laporan Pendapatan'),
      ),
      body: const RevenueReportView(),
    );
  }
}

/// Embeddable Revenue Report body used in [RevenueReportScreen] and [FinancialHubScreen].
class RevenueReportView extends ConsumerStatefulWidget {
  final bool embedded;

  const RevenueReportView({super.key, this.embedded = false});

  @override
  ConsumerState<RevenueReportView> createState() => _RevenueReportViewState();
}

class _RevenueReportViewState extends ConsumerState<RevenueReportView> {
  @override
  Widget build(BuildContext context) {
    final closingAsync = ref.watch(closingSummaryProvider);
    final bizState = ref.watch(businessProvider);
    final authState = ref.watch(authProvider);
    final posBranchFilter = ref.watch(posFilterBranchIdProvider);

    final activeBiz = bizState.businesses
        .where((b) => b['id'] == bizState.activeBusinessId)
        .firstOrNull;
    final role = (activeBiz?['membership']?['role'] ?? authState.user?['role'] ?? 'staff')
        .toString()
        .toLowerCase();
    final isOwnerOrAdmin = role == 'owner' || role == 'admin' || role == 'super_admin';

    final rawBranches = (activeBiz?['branches'] as List?) ?? [];
    final List<Map<String, dynamic>> branches = rawBranches
        .whereType<Map>()
        .map((b) => Map<String, dynamic>.from(b))
        .toList();

    final isCentralUser = isOwnerOrAdmin ||
        branches.any((b) => b['id'] == bizState.activeBranchId && b['is_central'] == true);

    final bool isConsolidated = posBranchFilter == -1 ||
        (posBranchFilter == null && bizState.activeBranchId == null);

    return Column(
      children: [
        // Branch Selector Header (if central / multi-branch user)
        _buildBranchSelectorHeader(
          branches: branches,
          isCentralUser: isCentralUser,
          isConsolidated: isConsolidated,
          bizState: bizState,
          posBranchFilter: posBranchFilter,
        ),

        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(closingSummaryProvider);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                20,
                14,
                20,
                widget.embedded ? kDockHeight + 24 : 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. TOP HORIZONTAL FILTER BAR (Concise labels, never truncates)
                  _buildTopFilterBar(),
                  const SizedBox(height: 16),

                  // 2. MAIN CONTENT
                  closingAsync.when(
                    loading: () => const CatalogTabSkeleton(count: 4),
                    error: (e, _) => Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            'Gagal memuat laporan pendapatan:\n$e',
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
                    data: (data) => _buildRevenueContent(
                      data: data,
                      branches: branches,
                      isConsolidated: isConsolidated,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================================
  // 1. BRANCH SELECTOR HEADER
  // =========================================================================
  Widget _buildBranchSelectorHeader({
    required List<Map<String, dynamic>> branches,
    required bool isCentralUser,
    required bool isConsolidated,
    required BusinessState bizState,
    required int? posBranchFilter,
  }) {
    final String branchLabel;
    if (isConsolidated) {
      branchLabel = 'Semua Cabang (Konsolidasi)';
    } else {
      final effectiveId = posBranchFilter ?? bizState.activeBranchId;
      final match = branches.where((b) => b['id'] == effectiveId).firstOrNull;
      branchLabel = match?['name'] ??
          (bizState.resolvedBranchName.isNotEmpty
              ? bizState.resolvedBranchName
              : 'Cabang Terpilih');
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
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
                  'Cakupan Kasir',
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: AppColors.obsidian,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (isCentralUser && branches.length > 1) ...[
            const SizedBox(width: 8),
            InkWell(
              onTap: () => _showBranchFilterModal(context, branches, isConsolidated),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isConsolidated ? AppColors.warning : AppColors.obsidian,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Ganti',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isConsolidated ? Colors.black : Colors.white,
                  ),
                ),
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
    bool isCurrentlyConsolidated,
  ) {
    final activeBranchId = ref.read(businessProvider).activeBranchId;
    final currentPosFilter = ref.read(posFilterBranchIdProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Pilih Cakupan Cabang',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.obsidian,
                ),
              ),
              const SizedBox(height: 12),
              // Opsi 1: Semua Cabang (Konsolidasi)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hub_rounded, color: AppColors.warning, size: 20),
                ),
                title: const Text(
                  'Semua Cabang (Konsolidasi)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Gabungkan total pendapatan dari seluruh cabang',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
                trailing: isCurrentlyConsolidated
                    ? const Icon(Icons.check_circle_rounded, color: AppColors.warning)
                    : null,
                onTap: () {
                  ref.read(posFilterBranchIdProvider.notifier).setBranchId(-1);
                  Navigator.pop(ctx);
                },
              ),
              const Divider(height: 1),
              // Opsi 2: Per Cabang
              ...branches.map((b) {
                final bId = b['id'] as int?;
                final bName = b['name'] ?? 'Cabang';
                final isCent = b['is_central'] == true;
                final bool isSelected = !isCurrentlyConsolidated &&
                    ((currentPosFilter != null && currentPosFilter == bId) ||
                        (currentPosFilter == null && activeBranchId == bId));

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCent ? AppColors.warningLight : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.storefront_rounded,
                      color: isCent ? AppColors.warning : AppColors.obsidian,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    bName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    isCent ? 'Cabang Utama (Pusat)' : 'Sub-Cabang',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.obsidian)
                      : null,
                  onTap: () {
                    ref.read(posFilterBranchIdProvider.notifier).setBranchId(bId);
                    Navigator.pop(ctx);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  // =========================================================================
  // 2. TOP FILTER BAR (Concise labels, never truncates on mobile screens)
  // =========================================================================
  Widget _buildTopFilterBar() {
    final dateState = ref.watch(posDateRangeProvider);
    final activeLabel = dateState.label;

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCompactFilterChip('Hari Ini', activeLabel == 'Hari Ini', () {
            final nowStr = DateTime.now().toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: 'Hari Ini',
                  startDate: nowStr,
                  endDate: nowStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Minggu Ini', activeLabel == 'Minggu Ini', () {
            final now = DateTime.now();
            final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
            final sStr = startOfWeek.toIso8601String().substring(0, 10);
            final eStr = now.toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: 'Minggu Ini',
                  startDate: sStr,
                  endDate: eStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Bulan Ini', activeLabel == 'Bulan Ini', () {
            final now = DateTime.now();
            final startOfMonth = DateTime(now.year, now.month, 1).toIso8601String().substring(0, 10);
            final todayStr = now.toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: 'Bulan Ini',
                  startDate: startOfMonth,
                  endDate: todayStr,
                );
          }),
          const SizedBox(width: 6),
          _buildCompactFilterChip('Bulan Lalu', activeLabel == 'Bulan Lalu', () {
            final now = DateTime.now();
            final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
            final lastOfLastMonth = DateTime(now.year, now.month, 0);
            ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: 'Bulan Lalu',
                  startDate: firstOfLastMonth.toIso8601String().substring(0, 10),
                  endDate: lastOfLastMonth.toIso8601String().substring(0, 10),
                );
          }),
          const SizedBox(width: 6),
          _buildCustomDateFilterChip(activeLabel),
        ],
      ),
    );
  }

  Widget _buildCompactFilterChip(String label, bool isSelected, VoidCallback onTap) {
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
        borderRadius: BorderRadius.circular(8),
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
    final isCustom = activeLabel != 'Hari Ini' &&
        activeLabel != 'Minggu Ini' &&
        activeLabel != 'Bulan Ini' &&
        activeLabel != 'Bulan Lalu';

    return ActionChip(
      avatar: Icon(
        Icons.date_range_rounded,
        size: 14,
        color: isCustom ? Colors.white : AppColors.textMuted,
      ),
      label: Text(
        isCustom ? activeLabel : 'Kustom',
        style: TextStyle(
          fontSize: 12,
          fontWeight: isCustom ? FontWeight.w700 : FontWeight.w500,
          color: isCustom ? Colors.white : AppColors.textPrimary,
        ),
      ),
      backgroundColor: isCustom ? AppColors.obsidian : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isCustom ? AppColors.obsidian : AppColors.border,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      onPressed: () async {
        final now = DateTime.now();
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(now.year - 2),
          lastDate: now,
          initialDateRange: DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: const ColorScheme.light(
                  primary: AppColors.obsidian,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: AppColors.obsidian,
                ),
              ),
              child: child!,
            );
          },
        );

        if (picked != null) {
          final sStr = picked.start.toIso8601String().substring(0, 10);
          final eStr = picked.end.toIso8601String().substring(0, 10);
          final customLabel =
              '${DateFormatter.formatShort(picked.start)} - ${DateFormatter.formatShort(picked.end)}';
          ref.read(posDateRangeProvider.notifier).setDateRange(
                label: customLabel,
                startDate: sStr,
                endDate: eStr,
              );
        }
      },
    );
  }

  // =========================================================================
  // 3. REVENUE CONTENT BODY
  // =========================================================================
  Widget _buildRevenueContent({
    required Map<String, dynamic> data,
    required List<Map<String, dynamic>> branches,
    required bool isConsolidated,
  }) {
    final totalRev = CurrencyFormatter.parse(data['total_revenue']);
    final totalTx = int.tryParse(data['total_transactions']?.toString() ?? '0') ?? 0;
    final Map<String, dynamic> breakdown = data['breakdown_by_method'] is Map
        ? Map<String, dynamic>.from(data['breakdown_by_method'] as Map)
        : {};
    final dateLabel = data['date'] ?? 'Hari Ini';

    final cashTotal = _calcCashTotal(breakdown);
    final nonCashTotal = _calcNonCashTotal(breakdown);

    final bool hasMultipleBranches = branches.length > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. HERO REVENUE CARD (Black Card)
        _buildHeroRevenueCard(
          totalRev: totalRev,
          totalTx: totalTx,
          cashTotal: cashTotal,
          nonCashTotal: nonCashTotal,
          dateLabel: dateLabel,
          isConsolidated: isConsolidated,
        ),
        const SizedBox(height: 16),

        // 2. SUMBER PENDAPATAN CARD (Clean Indonesian labels without English debug text)
        if (data['breakdown_by_type'] is Map) ...[
          _buildIncomeTypeBreakdown(data['breakdown_by_type'] as Map),
          const SizedBox(height: 16),
        ],

        // 3. KONTRIBUSI OMSET PER CABANG (Only rendered when > 1 branch & viewing "Semua Cabang")
        if (hasMultipleBranches &&
            isConsolidated &&
            data['breakdown_by_branch'] is List &&
            (data['breakdown_by_branch'] as List).isNotEmpty) ...[
          _buildBranchContributionBreakdown(data['breakdown_by_branch'] as List),
          const SizedBox(height: 16),
        ],

        // 4. RINCIAN METODE PEMBAYARAN
        _buildPaymentMethodBreakdown(breakdown),
        const SizedBox(height: 16),

        // 5. AUDIT RINCIAN TRANSAKSI (Clean rows, no repetitive branch pills when filtered)
        if (data['recent_transactions'] is List &&
            (data['recent_transactions'] as List).isNotEmpty) ...[
          _buildRecentTransactionsAudit(
            transactions: data['recent_transactions'] as List,
            isConsolidated: isConsolidated,
          ),
        ],
      ],
    );
  }

  // --- Hero Revenue Card ---
  Widget _buildHeroRevenueCard({
    required double totalRev,
    required int totalTx,
    required double cashTotal,
    required double nonCashTotal,
    required String dateLabel,
    required bool isConsolidated,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.obsidian,
        borderRadius: BorderRadius.circular(10),
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
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(4),
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tunai (Cash)',
                            style: TextStyle(color: Colors.white60, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            CurrencyFormatter.format(cashTotal),
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
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.credit_card_rounded, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Non-Tunai',
                            style: TextStyle(color: Colors.white60, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            CurrencyFormatter.format(nonCashTotal),
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
    );
  }

  // --- Sumber Pendapatan Card (Clean Indonesian Labels) ---
  Widget _buildIncomeTypeBreakdown(Map typeMap) {
    final types = [
      'rental',
      'extension',
      'penalty',
      if (typeMap.containsKey('refund') &&
          ((typeMap['refund'] is Map && (typeMap['refund']['count'] ?? 0) > 0) ||
              CurrencyFormatter.parse(
                      typeMap['refund'] is Map ? typeMap['refund']['total'] : null) >
                  0))
        'refund',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Sumber Pendapatan',
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
            borderRadius: BorderRadius.circular(10),
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
                    final info = typeMap[key] is Map ? (typeMap[key] as Map) : {};
                    // Clean Indonesian labels: strictly strip any english debug text like (Late Penalty)
                    final String cleanLabel;
                    if (key == 'penalty') {
                      cleanLabel = 'Denda Keterlambatan';
                    } else if (key == 'extension') {
                      cleanLabel = 'Perpanjangan Sewa';
                    } else if (key == 'refund') {
                      cleanLabel = 'Pengembalian Deposit (Refund)';
                    } else {
                      cleanLabel = 'Sewa Kontrak Pokok';
                    }

                    final total = CurrencyFormatter.parse(info['total']);
                    final count = info['count'] ?? 0;
                    final isPenalty = key == 'penalty';
                    final isExtension = key == 'extension';

                    final icon = isPenalty
                        ? Icons.warning_amber_rounded
                        : (isExtension ? Icons.update_rounded : Icons.vpn_key_outlined);
                    final iconColor = isPenalty
                        ? Colors.deepOrange
                        : (isExtension ? AppColors.info : AppColors.obsidian);
                    final iconBg = isPenalty
                        ? Colors.deepOrange.withValues(alpha: 0.1)
                        : (isExtension ? AppColors.infoLight : AppColors.surfaceMuted);

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: iconBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, size: 18, color: iconColor),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cleanLabel,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: isPenalty && total > 0
                                        ? Colors.deepOrange.shade800
                                        : AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$count Transaksi',
                                  style: const TextStyle(
                                    fontSize: 11,
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
        ),
      ],
    );
  }

  // --- Branch Contribution Breakdown ---
  Widget _buildBranchContributionBreakdown(List branchDataList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              '${branchDataList.length} Cabang Terdata',
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ...branchDataList.map((bItem) {
          final b = bItem is Map ? bItem : {};
          final bName = b['branch_name'] ?? 'Cabang';
          final isCent = b['is_central'] == true;
          final bRev = CurrencyFormatter.parse(b['total_revenue']);
          final bCash = CurrencyFormatter.parse(b['cash_revenue']);
          final bNonCash = CurrencyFormatter.parse(b['non_cash_revenue']);
          final bTxCount = b['transaction_count'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
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
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isCent ? AppColors.warningLight : AppColors.infoLight,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isCent ? 'Pusat' : 'Cabang',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isCent ? AppColors.warning : AppColors.info,
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$bTxCount Transaksi',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Tunai: ${CurrencyFormatter.format(bCash)} • Non-Tunai: ${CurrencyFormatter.format(bNonCash)}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
      ],
    );
  }

  // --- Payment Method Breakdown ---
  Widget _buildPaymentMethodBreakdown(Map<String, dynamic> breakdown) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: breakdown.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Center(
                    child: Text(
                      'Belum ada transaksi pembayaran di periode ini.',
                      style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < breakdown.entries.length; i++) ...[
                      if (i > 0)
                        const Divider(
                          height: 1,
                          thickness: 1,
                          color: AppColors.surfaceMuted,
                        ),
                      Builder(
                        builder: (_) {
                          final entry = breakdown.entries.elementAt(i);
                          final val = entry.value is Map ? (entry.value as Map) : {};
                          final total = CurrencyFormatter.parse(val['total']);
                          final count = val['count'] ?? 0;
                          final kStr = entry.key.toString().toLowerCase();

                          final IconData methodIcon;
                          if (kStr.contains('tunai') || kStr == 'cash') {
                            methodIcon = Icons.money_rounded;
                          } else if (kStr.contains('qris')) {
                            methodIcon = Icons.qr_code_scanner_rounded;
                          } else if (kStr.contains('transfer') || kStr.contains('bank')) {
                            methodIcon = Icons.account_balance_rounded;
                          } else if (kStr.contains('edc') ||
                              kStr.contains('card') ||
                              kStr.contains('kartu')) {
                            methodIcon = Icons.credit_card_rounded;
                          } else {
                            methodIcon = Icons.account_balance_wallet_outlined;
                          }

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceMuted,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(methodIcon, size: 18, color: AppColors.obsidian),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.key,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '$count Transaksi',
                                        style: const TextStyle(
                                          fontSize: 11,
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
      ],
    );
  }

  // --- Audit Rincian Transaksi (Clean Subtitles & No Redundant Branch Pill) ---
  Widget _buildRecentTransactionsAudit({
    required List transactions,
    required bool isConsolidated,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
              icon: const Icon(Icons.menu_book_rounded, size: 14),
              label: const Text(
                'Buku Kas Lengkap',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
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
        ...transactions.map((txItem) {
          final tx = txItem is Map ? txItem : {};
          final txCode = tx['receipt_number'] ?? tx['transaction_code'] ?? 'TX';
          final custName = tx['customer_name'] ?? 'Pelanggan';
          final brName = tx['branch_name'] ?? 'Cabang';
          final isCent = tx['is_central'] == true;
          final txAmt = CurrencyFormatter.parse(tx['amount']);
          final pMethod = tx['payment_method'] ?? 'Tunai';
          final itemsSummary = tx['items_summary'] ?? 'Perangkat Apple';
          final txType = tx['type']?.toString().toLowerCase();

          final String categoryLabel;
          if (txType == 'penalty') {
            categoryLabel = 'Denda';
          } else if (txType == 'extension') {
            categoryLabel = 'Perpanjangan';
          } else {
            categoryLabel = 'Sewa';
          }

          return InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => PosTransactionDetailSheet(
                  booking: Map<String, dynamic>.from(tx),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
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
                            // Only render branch pill tag when viewing "Semua Cabang"
                            if (isConsolidated) ...[
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
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
                        // Line 1: Customer Name • Unit Model
                        Text(
                          '$custName • $itemsSummary',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        // Line 2: Payment Method • Category (Sewa/Denda)
                        Text(
                          '$pMethod • $categoryLabel',
                          style: const TextStyle(
                            fontSize: 11,
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
}

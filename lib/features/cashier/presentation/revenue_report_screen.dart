import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/dock_aware_scaffold.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/cashier_provider.dart';
import 'widgets/report_shared_widgets.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Laporan Pendapatan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF0F172A),
          ),
        ),
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

    return ColoredBox(
      color: Colors.white,
      child: Column(
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
                  0,
                  4,
                  0,
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
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: CatalogTabSkeleton(count: 4),
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
      ),
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
      final rawName = (match?['name'] ??
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
          ? () => _showBranchFilterModal(context, branches, isConsolidated)
          : null,
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
                final bName = formatReportBranchName((b['name'] ?? 'Cabang').toString());
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
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildCompactFilterChip('Hari Ini', activeLabel == 'Hari Ini', () {
            final nowStr = DateTime.now().toIso8601String().substring(0, 10);
            ref.read(posDateRangeProvider.notifier).setDateRange(
                  label: 'Hari Ini',
                  startDate: nowStr,
                  endDate: nowStr,
                );
          }),
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
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
          const SizedBox(width: 8),
          _buildCustomDateFilterChip(activeLabel),
        ],
      ),
    );
  }

  Widget _buildCompactFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return ReportFilterPill(
      label: label,
      isSelected: isSelected,
      onTap: onTap,
    );
  }

  Widget _buildCustomDateFilterChip(String activeLabel) {
    final isCustom = activeLabel != 'Hari Ini' &&
        activeLabel != 'Minggu Ini' &&
        activeLabel != 'Bulan Ini' &&
        activeLabel != 'Bulan Lalu';

    return ReportFilterPill(
      label: isCustom ? activeLabel : 'Kustom',
      isSelected: isCustom,
      leadingIcon: Icons.date_range_outlined,
      onTap: () async {
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
                  primary: Color(0xFF0F172A),
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Color(0xFF0F172A),
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
        // 1. HERO REVENUE CARD (Obsidian Card)
        _buildHeroRevenueCard(
          totalRev: totalRev,
          totalTx: totalTx,
          cashTotal: cashTotal,
          nonCashTotal: nonCashTotal,
          dateLabel: dateLabel,
          isConsolidated: isConsolidated,
        ),
        const SizedBox(height: 8),

        // 2. SUMBER PENDAPATAN (Flat hairline list)
        if (data['breakdown_by_type'] is Map)
          _buildIncomeTypeBreakdown(data['breakdown_by_type'] as Map),

        // 3. KONTRIBUSI OMSET PER CABANG (Only rendered when > 1 branch & viewing "Semua Cabang")
        if (hasMultipleBranches &&
            isConsolidated &&
            data['breakdown_by_branch'] is List &&
            (data['breakdown_by_branch'] as List).isNotEmpty)
          _buildBranchContributionBreakdown(data['breakdown_by_branch'] as List),

        // 4. RINCIAN METODE PEMBAYARAN (Flat hairline list)
        ReportPaymentMethodList(breakdown: breakdown),

        // 5. TRANSAKSI TERBARU (Flat hairline list)
        if (data['recent_transactions'] is List &&
            (data['recent_transactions'] as List).isNotEmpty)
          ReportRecentTransactionsList(
            transactions: data['recent_transactions'] as List,
            isConsolidated: isConsolidated,
          ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(16),
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
                            color: Color(0xFF94A3B8),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
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
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: const Text(
                            'Konsolidasi',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF94A3B8),
                  size: 19,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              CurrencyFormatter.format(totalRev),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$totalTx transaksi berhasil diselesaikan',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
              ),
            ),
            const SizedBox(height: 14),
            const Divider(color: Colors.white12, height: 1, thickness: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.payments_outlined,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tunai (Cash)',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(cashTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                fontFeatures: [FontFeature.tabularFigures()],
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
                Container(width: 1, height: 28, color: Colors.white12),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      const Icon(
                        Icons.credit_card_outlined,
                        size: 16,
                        color: Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Non-Tunai',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              CurrencyFormatter.format(nonCashTotal),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5,
                                fontFeatures: [FontFeature.tabularFigures()],
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
    );
  }

  // --- Sumber Pendapatan (Flat Hairline Breakdown) ---
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
        const ReportSectionHeader(title: 'Sumber Pendapatan'),
        for (int i = 0; i < types.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              indent: 20,
              endIndent: 20,
              color: Color(0xFFF1F5F9),
            ),
          Builder(
            builder: (_) {
              final key = types[i];
              final info = typeMap[key] is Map ? (typeMap[key] as Map) : {};
              // Clean Indonesian labels: strictly strip any english debug text like (Late Penalty)
              final String cleanLabel;
              final IconData icon;
              if (key == 'penalty') {
                cleanLabel = 'Denda Keterlambatan';
                icon = Icons.warning_amber_rounded;
              } else if (key == 'extension') {
                cleanLabel = 'Perpanjangan Sewa';
                icon = Icons.update_rounded;
              } else if (key == 'refund') {
                cleanLabel = 'Pengembalian Deposit (Refund)';
                icon = Icons.currency_exchange_rounded;
              } else {
                cleanLabel = 'Sewa Kontrak Pokok';
                icon = Icons.vpn_key_outlined;
              }

              final total = CurrencyFormatter.parse(info['total']);
              final count = info['count'] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: const Color(0xFF0F172A),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanLabel,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$count Transaksi',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      CurrencyFormatter.format(total),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        color: Color(0xFF0F172A),
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ],
    );
  }

  // --- Branch Contribution Breakdown (Flat Hairline Rows) ---
  Widget _buildBranchContributionBreakdown(List branchDataList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Kontribusi Omset per Cabang',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${branchDataList.length} Cabang Terdata',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < branchDataList.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              indent: 20,
              endIndent: 20,
              color: Color(0xFFF1F5F9),
            ),
          Builder(
            builder: (_) {
              final bItem = branchDataList[i];
              final b = bItem is Map ? bItem : {};
              final bName = formatReportBranchName(
                (b['branch_name'] ?? 'Cabang').toString(),
              );
              final isCent = b['is_central'] == true;
              final bRev = CurrencyFormatter.parse(b['total_revenue']);
              final bCash = CurrencyFormatter.parse(b['cash_revenue']);
              final bNonCash = CurrencyFormatter.parse(b['non_cash_revenue']);
              final bTxCount = b['transaction_count'] ?? 0;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  isCent ? 'Pusat' : 'Cabang',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF475569),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  bName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5,
                                    color: Color(0xFF0F172A),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          CurrencyFormatter.format(bRev),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                            color: Color(0xFF0F172A),
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$bTxCount Transaksi',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Tunai: ${CurrencyFormatter.format(bCash)} • Non-Tunai: ${CurrencyFormatter.format(bNonCash)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF64748B),
                              fontFeatures: [FontFeature.tabularFigures()],
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
            },
          ),
        ],
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

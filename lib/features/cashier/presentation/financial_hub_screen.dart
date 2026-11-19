import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import 'cashier_screen.dart';
import 'revenue_report_screen.dart';

/// Tab 2 ("Laporan") Hub Screen consolidating Financial Reports & Cashier Shifts.
///
/// Features a clean top 2-tab switcher (`Pendapatan` | `Kasir & Shift`) so owners
/// and cashiers can access revenue analytics and shift drawer reconciliation in 1 tap.
class FinancialHubScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;

  const FinancialHubScreen({
    super.key,
    this.initialTabIndex = 0,
  });

  @override
  ConsumerState<FinancialHubScreen> createState() => _FinancialHubScreenState();
}

class _FinancialHubScreenState extends ConsumerState<FinancialHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 1),
    );
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
        backgroundColor: AppColors.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: const Text('Laporan', style: AppTextStyles.pageHeader),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                bottom: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppTextStyles.pageHeaderHorizontalPadding,
              0,
              AppTextStyles.pageHeaderHorizontalPadding,
              12,
            ),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.obsidian,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(height: 38, text: 'Pendapatan'),
                  Tab(height: 38, text: 'Kasir & Shift'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          RevenueReportView(embedded: true),
          CashierShiftView(embedded: true),
        ],
      ),
    );
  }
}

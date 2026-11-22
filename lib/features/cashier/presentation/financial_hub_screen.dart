import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 20,
        title: const Text(
          'Laporan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(57),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Container(
              height: 42,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
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
                  fontSize: 13,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Pendapatan'),
                  Tab(text: 'Kasir & Shift'),
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

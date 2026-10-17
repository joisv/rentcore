import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookings/presentation/return_wizard_screen.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../transfers/presentation/transfers_screen.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../auth/providers/business_provider.dart';
import '../../organization/presentation/manage_organization_screen.dart';
import '../../printer/presentation/printer_settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  final ValueChanged<int> onNavigateTab;
  final VoidCallback onOpenDirectRental;

  const HomeScreen({
    super.key,
    required this.onNavigateTab,
    required this.onOpenDirectRental,
  });

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Selamat Pagi';
    if (hour >= 12 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return 'RC';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Konfirmasi Keluar'),
        content: const Text('Apakah Anda yakin ingin keluar dari sesi aplikasi RentCore?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Ya, Keluar'),
          ),
        ],
      ),
    );
  }

  void _processOverdueReturn(BuildContext context, WidgetRef ref, int bookingId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.obsidian),
      ),
    );

    try {
      final booking = await ref.read(bookingRepositoryProvider).fetchBookingDetail(bookingId);
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading spinner
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReturnWizardScreen(booking: booking),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading spinner
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail sewa: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final kpiAsync = ref.watch(dashboardKpiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.obsidian,
          onRefresh: () => ref.refresh(dashboardKpiProvider.future),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Personalized Header
                _buildHeader(context, ref, user),
                const SizedBox(height: 20),

                // If user has NO active business: show dedicated onboarding banner
                if (ref.watch(businessProvider).activeBusinessId == null ||
                    ref.watch(businessProvider).businesses.isEmpty) ...[
                  _buildOnboardingBanner(context),
                  const SizedBox(height: 22),
                ],

                // 2. Quick Action Bar
                _buildQuickActionBar(context, ref, user),
                const SizedBox(height: 22),

                // 3. Dynamic KPI & Operations Content
                kpiAsync.when(
                  loading: () => _buildSkeletonLoading(),
                  error: (error, _) => _buildErrorCard(context, ref, error),
                  data: (data) => _buildDashboardContent(context, ref, data, user),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- Onboarding Banner for users with 0 businesses ---
  Widget _buildOnboardingBanner(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mulai Bisnis Rental Anda',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.textPrimary),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Kelola rental gadget & unit iPhone secara mandiri',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Akun Anda belum memiliki bisnis rental terdaftar. Buat bisnis dan cabang utama Anda untuk mulai mengelola katalog produk, tarif rental, dan inventaris perangkat.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_business_rounded, size: 18),
              label: const Text('Daftarkan Bisnis Rental Baru', style: TextStyle(fontWeight: FontWeight.w700)),
              onPressed: () => BusinessSelectorSheet.show(context),
            ),
          ),
        ],
      ),
    );
  }

  // --- Header Component ---
  Widget _buildHeader(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    final userName = user?['name']?.toString() ?? 'Petugas Counter';
    final role = user?['role']?.toString() ?? 'staff';
    final isSuperAdmin = role == 'super_admin';
    final affiliate = user?['affiliate'] as Map<String, dynamic>?;
    final fallbackBranchName = affiliate?['name']?.toString() ?? (isSuperAdmin ? 'Pusat Jaringan' : 'Pusat Operasional');

    final businessState = ref.watch(businessProvider);
    final hasBusiness = businessState.activeBusinessId != null && businessState.businesses.isNotEmpty;
    final activeBizName = hasBusiness
        ? (businessState.activeBusinessName ?? 'Bisnis Rental')
        : 'Belum Ada Bisnis';
    final activeBranchName = hasBusiness
        ? (businessState.activeBranchName ?? fallbackBranchName)
        : 'Ketuk untuk buat';

    final greeting = _getTimeGreeting();
    final initials = _getInitials(userName);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Initials Avatar (Tappable to open Business Selector)
          InkWell(
            onTap: () => BusinessSelectorSheet.show(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // User & Role Context
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: InkWell(
                        onTap: () => BusinessSelectorSheet.show(context),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  '$activeBizName • $activeBranchName',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: AppColors.textSecondary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isSuperAdmin ? AppColors.infoLight : AppColors.successLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isSuperAdmin ? 'SUPER ADMIN' : 'STAFF KASIR',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: isSuperAdmin ? AppColors.info : AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '$greeting, $userName 👋',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => BusinessSelectorSheet.show(context),
            tooltip: 'Pilih Usaha / Profil',
            icon: const Icon(Icons.storefront_rounded, color: AppColors.textSecondary, size: 20),
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
            tooltip: 'Pengaturan Printer Thermal',
            icon: const Icon(Icons.print_rounded, color: AppColors.textSecondary, size: 20),
          ),
          IconButton(
            onPressed: () => _confirmLogout(context, ref),
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, color: AppColors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }

  // --- Quick Actions Bar ---
  Widget _buildQuickActionBar(BuildContext context, WidgetRef ref, Map<String, dynamic>? user) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickAction(
            icon: Icons.add_circle_outline_rounded,
            label: 'Sewa Baru',
            isPrimary: true,
            onTap: onOpenDirectRental,
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.assignment_return_outlined,
            label: 'Pengembalian',
            onTap: () => onNavigateTab(1),
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.inventory_2_outlined,
            label: 'Inventaris',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InventoryScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.swap_horiz_rounded,
            label: 'Transfer Unit',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransfersScreen()),
              );
            },
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.confirmation_number_outlined,
            label: 'Voucher',
            onTap: () => onNavigateTab(2),
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.point_of_sale_outlined,
            label: 'Kasir',
            onTap: () => onNavigateTab(3),
          ),
          const SizedBox(width: 10),
          _buildQuickAction(
            icon: Icons.print_outlined,
            label: 'Printer',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
              );
            },
          ),
          if (ref.watch(businessProvider).activeBusinessId != null) ...[
            const SizedBox(width: 10),
            _buildQuickAction(
              icon: Icons.people_outline_rounded,
              label: 'Kelola Tim',
              onTap: () {
                final bState = ref.read(businessProvider);
                if (bState.activeBusinessId != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ManageOrganizationScreen(
                        businessId: bState.activeBusinessId!,
                        businessName: bState.activeBusinessName ?? 'Bisnis Rental',
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.obsidian : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? AppColors.obsidian : AppColors.border,
          ),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: AppColors.obsidian.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isPrimary ? Colors.white : AppColors.obsidian,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isPrimary ? Colors.white : AppColors.obsidian,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Dashboard Data Content ---
  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
    Map<String, dynamic>? user,
  ) {
    final kpi = data['kpi'] ?? {};
    final overdueAlerts = (data['overdue_alerts'] as List?) ?? [];
    final imminentReturns = (data['imminent_returns'] as List?) ?? [];

    final unitsTotal = (kpi['units_total'] ?? 0) as int;
    final unitsReady = (kpi['units_ready'] ?? 0) as int;
    final unitsRented = (kpi['units_rented'] ?? 0) as int;
    final unitsMaintenance = (kpi['units_maintenance'] ?? 0) as int;
    final utilizationRate = (kpi['utilization_rate'] ?? 0).toDouble();

    final todayRevenue = (kpi['today_revenue'] ?? 0.0);
    final todayTransactions = (kpi['today_transactions_count'] ?? 0);
    final todayRentalsCreated = (kpi['today_rentals_created'] ?? 0);
    final dueToday = (kpi['due_today'] ?? 0);
    final overdueCount = (kpi['overdue'] ?? 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Attention Required: Overdue Alerts or All-Clear Status
        if (overdueAlerts.isNotEmpty)
          _buildOverdueAlertCard(context, ref, overdueAlerts)
        else
          _buildAllClearStatusCard(),
        const SizedBox(height: 20),

        // 2. Inventory Overview & Fleet Utilization Meter
        _buildInventoryOverview(
          context,
          unitsTotal: unitsTotal,
          unitsReady: unitsReady,
          unitsRented: unitsRented,
          unitsMaintenance: unitsMaintenance,
          utilizationRate: utilizationRate,
        ),
        const SizedBox(height: 20),

        // 3. Operational & Financial Daily Summary
        _buildDailySummary(
          context,
          todayRentalsCreated: todayRentalsCreated,
          dueToday: dueToday,
          overdueCount: overdueCount,
          todayRevenue: todayRevenue,
          todayTransactions: todayTransactions,
        ),
        const SizedBox(height: 20),

        // 4. Imminent Returns (Next 4 Hours)
        if (imminentReturns.isNotEmpty) ...[
          _buildImminentReturnsSection(context, imminentReturns),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  // --- Overdue Alert Card with 1-Tap Return Action ---
  Widget _buildOverdueAlertCard(BuildContext context, WidgetRef ref, List<dynamic> alerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'PERINGATAN KETERLAMBATAN (${alerts.length} UNIT)',
                    style: const TextStyle(
                      color: AppColors.danger,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => onNavigateTab(1), // Go to Bookings
                child: const Text(
                  'Lihat Semua',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...alerts.take(3).map((alert) {
            final bookingId = alert['booking_id'] as int? ?? 0;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${alert['customer_name']} • ${alert['unit_name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Telat ${alert['late_duration_text']} • Denda: ${CurrencyFormatter.format(alert['running_penalty'])}',
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _processOverdueReturn(context, ref, bookingId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text(
                      'Kembalikan',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- All-Clear Status Banner ---
  Widget _buildAllClearStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Operasional Lancar: Semua unit tepat waktu & tidak ada antrean terlambat.',
              style: TextStyle(
                color: AppColors.success,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Inventory Overview with Utilization Bar ---
  Widget _buildInventoryOverview(
    BuildContext context, {
    required int unitsTotal,
    required int unitsReady,
    required int unitsRented,
    required int unitsMaintenance,
    required double utilizationRate,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with Utilization Rate Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'STATUS INVENTARIS CABANG',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.obsidian,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Utilisasi ${utilizationRate.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Progress Bar (Fleet Health Meter)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 8,
              child: unitsTotal > 0
                  ? Row(
                      children: [
                        if (unitsReady > 0)
                          Expanded(
                            flex: unitsReady,
                            child: Container(color: AppColors.success),
                          ),
                        if (unitsRented > 0)
                          Expanded(
                            flex: unitsRented,
                            child: Container(color: AppColors.info),
                          ),
                        if (unitsMaintenance > 0)
                          Expanded(
                            flex: unitsMaintenance,
                            child: Container(color: AppColors.warning),
                          ),
                      ],
                    )
                  : Container(color: AppColors.border),
            ),
          ),
          const SizedBox(height: 14),

          // 4 Status Tiles
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  label: 'Unit Siap',
                  count: unitsReady.toString().padLeft(2, '0'),
                  color: AppColors.success,
                  icon: Icons.check_circle_outline_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(initialStatusFilter: 'ready'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  label: 'Sedang Sewa',
                  count: unitsRented.toString().padLeft(2, '0'),
                  color: AppColors.info,
                  icon: Icons.schedule_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(initialStatusFilter: 'rented'),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  label: 'Perbaikan',
                  count: unitsMaintenance.toString().padLeft(2, '0'),
                  color: AppColors.warning,
                  icon: Icons.build_circle_outlined,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(initialStatusFilter: 'maintenance'),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  label: 'Total Armada',
                  count: unitsTotal.toString().padLeft(2, '0'),
                  color: AppColors.obsidian,
                  icon: Icons.devices_other_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InventoryScreen(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Daily Operational & Cashier Summary ---
  Widget _buildDailySummary(
    BuildContext context, {
    required dynamic todayRentalsCreated,
    required dynamic dueToday,
    required dynamic overdueCount,
    required dynamic todayRevenue,
    required dynamic todayTransactions,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RINGKASAN OPERASIONAL & KASIR HARI INI',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 14),

          // Operational metrics chips
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sewa Baru',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$todayRentalsCreated Transaksi',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Jatuh Tempo',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$dueToday Unit',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.warning),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Financial Cashier Summary Banner
          InkWell(
            onTap: () => onNavigateTab(3), // Open Cashier Tab
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.obsidian,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Omzet Masuk Hari Ini',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          CurrencyFormatter.format(todayRevenue),
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        '$todayTransactions Trx',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Imminent Returns Section ---
  Widget _buildImminentReturnsSection(BuildContext context, List<dynamic> imminentReturns) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'JATUH TEMPO BERIKUTNYA (4 JAM KEDEPAN)',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 10),
        ...imminentReturns.map((item) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.smartphone_rounded, size: 22, color: AppColors.obsidian),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['unit_name'] ?? 'Perangkat',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item['customer_name']} • Slot: ${item['collateral_storage_slot'] ?? '-'}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item['expected_return_at'] ?? '',
                    style: const TextStyle(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // --- KPI Card Widget ---
  Widget _buildKpiCard({
    required String label,
    required String count,
    required Color color,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  count,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: color,
                    letterSpacing: -0.5,
                  ),
                ),
                Icon(icon, size: 18, color: color),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Skeleton Loading Placeholder ---
  Widget _buildSkeletonLoading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
        ),
      ],
    );
  }

  // --- Error State Widget with Retry Action ---
  Widget _buildErrorCard(BuildContext context, WidgetRef ref, Object error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.danger, size: 36),
          const SizedBox(height: 10),
          const Text(
            'Gagal Memuat Data Dashboard',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            '$error',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(dashboardKpiProvider.future),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Coba Lagi'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
}

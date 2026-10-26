import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookings/presentation/return_wizard_screen.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../cashier/presentation/cashier_screen.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../auth/presentation/user_profile_screen.dart';
import '../providers/dashboard_provider.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../../shared/widgets/dock_aware_scaffold.dart';
import '../../auth/providers/business_provider.dart';
import '../../notifications/presentation/notification_center_screen.dart';
import '../../notifications/providers/notification_provider.dart';

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
    final businessState = ref.watch(businessProvider);
    final kpiAsync = ref.watch(dashboardKpiProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: onOpenDirectRental,
        backgroundColor: AppColors.obsidian,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text('Sewa Baru', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      ),
      floatingActionButtonLocation: const DockFloatingActionButtonLocation(extraOffset: 4),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.obsidian,
          onRefresh: () async {
            await ref.read(businessProvider.notifier).refresh();
            ref.read(notificationProvider.notifier).fetchUnreadCountOnly();
            ref.invalidate(dashboardKpiProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Personalized Header
                _buildHeader(context, ref, user, businessState),
                const SizedBox(height: 12),

                // 2. Business Sync / Connection Error Diagnostic Card
                if (businessState.error != null) ...[
                  _buildBusinessErrorCard(context, ref, businessState.error!),
                  const SizedBox(height: 14),
                ],

                // 3. Persistent Active Context Bar (Branch / Consolidated Indicator)
                if (businessState.activeBusinessId != null) ...[
                  _buildActiveContextBanner(context, ref, businessState),
                  const SizedBox(height: 16),
                ],

                // 4. If user has NO active business and no error: show dedicated onboarding banner
                if (businessState.error == null &&
                    !businessState.isLoading &&
                    (businessState.activeBusinessId == null || businessState.businesses.isEmpty)) ...[
                  _buildOnboardingBanner(context),
                  const SizedBox(height: 22),
                ],

                // 5. Dynamic KPI & Operations Content
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
  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic>? user,
    BusinessState businessState,
  ) {
    final userName = user?['name']?.toString() ?? 'Petugas Counter';
    final isSuperAdmin = user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final activeRole = businessState.currentBusiness?['role']?.toString() ?? user?['role']?.toString() ?? 'staff';

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
          // User Avatar (Tappable to open User Profile Screen)
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
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
                    _buildRoleBadge(activeRole, isSuperAdmin),
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
            tooltip: 'Ganti Cabang',
            icon: const Icon(Icons.storefront_rounded, color: AppColors.textSecondary, size: 20),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
                  );
                },
                tooltip: 'Pusat Pemberitahuan',
                icon: const Icon(Icons.notifications_outlined, color: AppColors.textSecondary, size: 22),
              ),
              Builder(
                builder: (context) {
                  final unreadCount = ref.watch(notificationProvider.select((s) => s.unreadCount));
                  if (unreadCount <= 0) return const SizedBox.shrink();
                  return Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          height: 1.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Role Badge Helper ---
  Widget _buildRoleBadge(String role, bool isSuperAdmin) {
    Color bg;
    Color fg;
    String label;

    if (isSuperAdmin) {
      bg = AppColors.infoLight;
      fg = AppColors.info;
      label = 'SUPER ADMIN';
    } else {
      switch (role.toLowerCase()) {
        case 'owner':
          bg = const Color(0xFFFEF3C7);
          fg = const Color(0xFFD97706);
          label = 'PEMILIK (OWNER)';
          break;
        case 'admin':
          bg = const Color(0xFFEEF2FF);
          fg = const Color(0xFF4F46E5);
          label = 'ADMIN USAHA';
          break;
        case 'staff':
        case 'cashier':
        default:
          bg = AppColors.successLight;
          fg = AppColors.success;
          label = 'STAFF KASIR';
          break;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  // --- Persistent Active Context Banner ---
  Widget _buildActiveContextBanner(
    BuildContext context,
    WidgetRef ref,
    BusinessState businessState,
  ) {
    if (businessState.isConsolidated) {
      // Consolidated Mode (All Branches)
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.corporate_fare_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'KONSOLIDASI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          businessState.activeBusinessName ?? 'Semua Cabang',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Color(0xFF92400E),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Mode Konsolidasi: Melihat gabungan seluruh cabang. Beralih ke cabang tertentu untuk transaksi POS & kasir.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFFB45309),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Specific Branch Mode
    final isCentral = businessState.isCentralBranch;
    final branchCity = businessState.currentBranch?['city'] ?? '';
    final branchCode = businessState.currentBranch?['code'] ?? '';
    final metaParts = [
      if (branchCode.toString().isNotEmpty) branchCode.toString(),
      if (branchCity.toString().isNotEmpty) branchCity.toString(),
      businessState.activeBusinessName ?? '',
    ].where((s) => s.isNotEmpty).join(' • ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isCentral ? AppColors.obsidian : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isCentral ? Icons.hub_rounded : Icons.storefront_rounded,
              color: isCentral ? Colors.white : AppColors.obsidian,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isCentral ? AppColors.obsidian : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        isCentral ? 'CABANG UTAMA' : 'SUB-CABANG',
                        style: TextStyle(
                          color: isCentral ? Colors.white : AppColors.textSecondary,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        businessState.activeBranchName ?? 'Cabang Terpilih',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  metaParts.isNotEmpty ? metaParts : (businessState.activeBusinessName ?? ''),
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
        ],
      ),
    );
  }

  // --- Business Error Card ---
  Widget _buildBusinessErrorCard(BuildContext context, WidgetRef ref, String error) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sync_problem_rounded, color: AppColors.danger, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gagal Menyinkronkan Konteks Bisnis',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.danger),
                ),
                const SizedBox(height: 2),
                Text(
                  error,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              ref.read(businessProvider.notifier).refresh();
              ref.invalidate(dashboardKpiProvider);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Coba Lagi', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  int _parseInt(dynamic value, [int fallback = 0]) {
    if (value == null) return fallback;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? double.tryParse(value)?.toInt() ?? fallback;
    return fallback;
  }

  double _parseDouble(dynamic value, [double fallback = 0.0]) {
    if (value == null) return fallback;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  // --- Main Dashboard Data Content ---
  Widget _buildDashboardContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> data,
    Map<String, dynamic>? user,
  ) {
    final kpi = data['kpi'] is Map ? data['kpi'] as Map : (data['stats'] is Map ? data['stats'] as Map : const {});
    final overdueAlerts = (data['overdue_alerts'] as List?) ?? [];
    final imminentReturns = (data['imminent_returns'] as List?) ?? [];

    final unitsTotal = _parseInt(kpi['units_total'] ?? kpi['total_units']);
    final unitsReady = _parseInt(kpi['units_ready'] ?? kpi['ready_units']);
    final unitsRented = _parseInt(kpi['units_rented'] ?? kpi['rented_units']);
    final unitsMaintenance = _parseInt(kpi['units_maintenance'] ?? kpi['maintenance_units']);
    final utilizationRate = _parseDouble(kpi['utilization_rate']);

    final todayRevenue = CurrencyFormatter.parse(kpi['today_revenue']);
    final todayTransactions = _parseInt(kpi['today_transactions_count']);
    final todayRentalsCreated = _parseInt(kpi['today_rentals_created']);
    final dueToday = _parseInt(kpi['due_today']);
    final overdueCount = _parseInt(kpi['overdue'] ?? kpi['overdue_count']);

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
            final bookingId = _parseInt(alert['booking_id']);
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
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CashierScreen()),
              );
            },
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
            onPressed: () => ref.invalidate(dashboardKpiProvider),
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

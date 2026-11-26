import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/legal_links.dart';
import '../../../shared/widgets/business_selector_sheet.dart';
import '../../auth/presentation/user_profile_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../customers/presentation/customer_directory_screen.dart';
import '../../onboarding/presentation/feature_walkthrough_screen.dart';
import '../../printer/providers/printer_provider.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../transfers/presentation/transfers_screen.dart';
import '../../vouchers/presentation/voucher_screen.dart';
import 'booking_rules_settings_screen.dart';
import 'collateral_settings_screen.dart';
import 'manage_organization_screen.dart';
import 'payment_method_settings_screen.dart';
import 'shift_schedule_screen.dart';
import 'store_profile_screen.dart';
import 'widgets/staff_resignation_sheet.dart';

typedef SettingsScreen = StoreSettingsScreen;

class StoreSettingsScreen extends ConsumerWidget {
  const StoreSettingsScreen({super.key});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFDC2626), size: 22),
            SizedBox(width: 8),
            Text(
              'Keluar Akun',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF475569)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748B),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final authNotifier = ref.read(authProvider.notifier);
              Navigator.pop(ctx);
              await authNotifier.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingPolicySheet(
    BuildContext context, {
    required int businessId,
    required Map<String, dynamic>? business,
    required bool isOwnerOrAdmin,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _BookingPolicyBottomSheet(
        businessId: businessId,
        business: business,
        isOwnerOrAdmin: isOwnerOrAdmin,
      ),
    );
  }

  void _showLateFeePolicySheet(
    BuildContext context, {
    required int businessId,
    required Map<String, dynamic>? business,
    required bool isOwnerOrAdmin,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _LateFeePolicyBottomSheet(
        businessId: businessId,
        business: business,
        isOwnerOrAdmin: isOwnerOrAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);
    final printerState = ref.watch(printerProvider);

    final isSuperAdmin =
        user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final currentBiz = bState.currentBusiness;
    final userRole =
        currentBiz?['role']?.toString().toLowerCase() ??
        user?['role']?.toString().toLowerCase() ??
        '';
    final isOwnerOrAdmin =
        userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final userName = user?['name']?.toString() ?? 'Pengguna';
    final userEmail = user?['email']?.toString() ?? '-';
    final roleDisplay = _formatRoleLabel(userRole);
    final resolvedStore = bState.resolvedStoreName;
    final resolvedBranch = bState.resolvedBranchName;
    final branchList = bState.currentBusiness?['branches'];
    final hasMultiBranches = branchList is List && branchList.length > 1;
    final activeBranchLabel = bState.isConsolidated && hasMultiBranches
        ? 'Semua Cabang'
        : resolvedBranch;
    final storeName = resolvedStore.isEmpty
        ? 'Belum ada usaha terpilih'
        : (activeBranchLabel.isNotEmpty
            ? '$resolvedStore • $activeBranchLabel'
            : resolvedStore);
    final activeBusinessDisplayName =
        resolvedStore.isNotEmpty ? resolvedStore : 'Usaha Rental';

    final connectedPrinterName = printerState.connectedDevice?.name.trim() ?? '';
    final printerSubtitle =
        printerState.isPairedOrConnected && connectedPrinterName.isNotEmpty
            ? 'Terhubung: $connectedPrinterName'
            : 'Koneksi Bluetooth ESC/POS';

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        title: const Text(
          'Pengaturan',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 4, bottom: 100),
        children: [
          // Compact Top Account & Active Store Header
          InkWell(
            key: const Key('settings_account_header'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roleDisplay.isNotEmpty
                              ? '$userEmail • $roleDisplay'
                              : userEmail,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: Color(0xFF64748B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.storefront_outlined,
                              size: 13.5,
                              color: Color(0xFF475569),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                storeName,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF334155),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
          _buildSectionDivider(),

          // GROUP 1: AKUN & TOKO
          _buildGroupHeader('AKUN & TOKO'),
          _buildMenuRow(
            icon: Icons.person_outline_rounded,
            title: 'Profil Pengguna',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.storefront_outlined,
            title: 'Profil Usaha & Cabang',
            subtitle: activeBranchLabel.isNotEmpty ? activeBranchLabel : null,
            rightCaption: isOwnerOrAdmin ? null : 'Lihat saja',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
              );
            },
          ),
          if (userRole != 'owner' && bState.activeBusinessId != null) ...[
            _buildRowDivider(),
            _buildMenuRow(
              icon: Icons.badge_outlined,
              title: 'Status Kepegawaian',
              onTap: () {
                StaffResignationSheet.show(
                  context,
                  businessId: bState.activeBusinessId!,
                  businessName: activeBusinessDisplayName,
                );
              },
            ),
          ],
          _buildSectionDivider(),

          // GROUP 2: OPERASIONAL KASIR
          _buildGroupHeader('OPERASIONAL KASIR'),
          _buildMenuRow(
            icon: Icons.payments_outlined,
            title: 'Metode Pembayaran',
            subtitle: 'QRIS, Tunai, Bank & E-Wallet',
            rightCaption: isOwnerOrAdmin ? null : 'Lihat saja',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentMethodSettingsScreen(),
                ),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.schedule_rounded,
            title: 'Jam Operasional Shift',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ShiftScheduleScreen()),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            key: const Key('menu_booking_policy'),
            icon: Icons.event_busy_outlined,
            title: 'Kebijakan Booking & No-Show',
            rightCaption: isOwnerOrAdmin ? null : 'Lihat saja',
            onTap: () {
              final bizId = bState.activeBusinessId;
              if (bizId != null) {
                _showBookingPolicySheet(
                  context,
                  businessId: bizId,
                  business: currentBiz,
                  isOwnerOrAdmin: isOwnerOrAdmin,
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingRulesSettingsScreen(),
                  ),
                );
              }
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            key: const Key('menu_late_fee_policy'),
            icon: Icons.calculate_outlined,
            title: 'Aturan Denda Keterlambatan',
            rightCaption: isOwnerOrAdmin ? null : 'Lihat saja',
            onTap: () {
              final bizId = bState.activeBusinessId;
              if (bizId != null) {
                _showLateFeePolicySheet(
                  context,
                  businessId: bizId,
                  business: currentBiz,
                  isOwnerOrAdmin: isOwnerOrAdmin,
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pilih bisnis rental terlebih dahulu.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            key: const Key('menu_collateral_settings'),
            icon: Icons.verified_user_outlined,
            title: 'Jaminan & Deposit',
            subtitle: bState.isCollateralEnabled
                ? 'Aktif • ${bState.activeCollateralTypes.length} tipe'
                : 'Nonaktif',
            rightCaption: isOwnerOrAdmin ? null : 'Lihat saja',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CollateralSettingsScreen(
                    isReadOnly: !isOwnerOrAdmin,
                  ),
                ),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.confirmation_number_outlined,
            title: 'Voucher & Promo',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const VoucherScreen()),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.print_outlined,
            title: 'Printer Thermal',
            subtitle: printerSubtitle,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
            },
          ),
          _buildSectionDivider(),

          // GROUP 3: INVENTARIS & PELANGGAN
          _buildGroupHeader('INVENTARIS & PELANGGAN'),
          _buildMenuRow(
            icon: Icons.people_alt_outlined,
            title: 'Direktori Pelanggan & Blacklist',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const CustomerDirectoryScreen(),
                ),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.swap_horiz_rounded,
            title: 'Mutasi Unit',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TransfersScreen()),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.group_outlined,
            title: 'Kelola Tim & Staf',
            rightCaption: isOwnerOrAdmin ? null : 'Owner / Admin',
            onTap: () {
              if (!isOwnerOrAdmin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Kelola Tim hanya dapat diakses oleh Owner atau Admin.',
                    ),
                    backgroundColor: AppColors.warning,
                  ),
                );
                return;
              }
              final bizId = bState.activeBusinessId;
              if (bizId != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ManageOrganizationScreen(
                      businessId: bizId,
                      businessName: activeBusinessDisplayName,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pilih bisnis rental terlebih dahulu.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
          ),
          _buildSectionDivider(),

          // GROUP 4: PRIVASI & LEGAL
          _buildGroupHeader('PRIVASI & LEGAL'),
          _buildMenuRow(
            key: const Key('menu_app_guide'),
            icon: Icons.help_outline_rounded,
            title: 'Panduan Aplikasi',
            subtitle: 'Lihat ulang alur operasional SewaKasir',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FeatureWalkthroughScreen(
                    replayMode: true,
                  ),
                ),
              );
            },
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.privacy_tip_outlined,
            title: 'Kebijakan Privasi',
            onTap: () => LegalLinks.openExternal(
              context,
              LegalLinks.privacyPolicyUri,
            ),
          ),
          _buildRowDivider(),
          _buildMenuRow(
            icon: Icons.delete_outline_rounded,
            title: 'Hapus Akun',
            iconColor: const Color(0xFFDC2626),
            titleColor: const Color(0xFFDC2626),
            onTap: () => LegalLinks.openExternal(
              context,
              LegalLinks.accountDeletionUri,
            ),
          ),
          _buildSectionDivider(),

          // Clean Minimalist Footer Actions
          const SizedBox(height: 8),
          InkWell(
            key: const Key('footer_switch_business_button'),
            onTap: () => BusinessSelectorSheet.show(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Text(
                'Ganti Usaha / Cabang',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
          const Divider(
            height: 1,
            thickness: 1,
            indent: 20,
            endIndent: 20,
            color: Color(0xFFF1F5F9),
          ),
          InkWell(
            key: const Key('footer_logout_button'),
            onTap: () => _confirmLogout(context, ref),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Text(
                'Keluar Akun',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ),
          _buildSectionDivider(),
          const SizedBox(height: 20),

          const Center(
            child: Text(
              'SewaKasir • Versi 1.0.0+1',
              style: TextStyle(
                fontSize: 11.5,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF64748B),
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    String? rightCaption,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    bool showChevron = true,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            SizedBox(
              width: 28,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Icon(
                  icon,
                  color: iconColor ?? const Color(0xFF0F172A),
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? const Color(0xFF0F172A),
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (rightCaption != null && rightCaption.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                rightCaption,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
            if (showChevron) ...[
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF94A3B8),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRowDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 62,
      endIndent: 20,
      color: Color(0xFFF1F5F9),
    );
  }

  Widget _buildSectionDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      color: Color(0xFFF1F5F9),
    );
  }

  String _formatRoleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'admin':
      case 'affiliate_admin':
        return 'Admin';
      case 'cashier':
        return 'Kasir';
      case 'staff':
        return 'Staff';
      case 'super_admin':
        return 'Super Admin';
      default:
        if (role.isEmpty) return '';
        return role[0].toUpperCase() + role.substring(1);
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

class _BookingPolicyBottomSheet extends ConsumerStatefulWidget {
  final int businessId;
  final Map<String, dynamic>? business;
  final bool isOwnerOrAdmin;

  const _BookingPolicyBottomSheet({
    required this.businessId,
    required this.business,
    required this.isOwnerOrAdmin,
  });

  @override
  ConsumerState<_BookingPolicyBottomSheet> createState() =>
      _BookingPolicyBottomSheetState();
}

class _BookingPolicyBottomSheetState
    extends ConsumerState<_BookingPolicyBottomSheet> {
  static const List<int> _graceOptions = [15, 30, 60, 120];

  late int _gracePeriodMinutes;
  late bool _autoExpireUnpaid;
  late String _endTimeMode;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _syncFromBusiness(widget.business);
  }

  void _syncFromBusiness(Map<String, dynamic>? biz) {
    final rawGrace = (biz?['booking_grace_period_minutes'] as num?)?.toInt();
    _gracePeriodMinutes =
        (rawGrace != null && _graceOptions.contains(rawGrace)) ? rawGrace : 60;
    _autoExpireUnpaid = biz?['auto_expire_unpaid_booking'] != false;
    final rawMode = biz?['late_pickup_end_time_mode']?.toString();
    _endTimeMode = rawMode == 'shift_if_available'
        ? 'shift_if_available'
        : 'keep_original_end';
  }

  Future<void> _savePolicy() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await ref.read(authRepositoryProvider).updateBusiness(widget.businessId, {
        'booking_grace_period_minutes': _gracePeriodMinutes,
        'auto_expire_unpaid_booking': _autoExpireUnpaid,
        'late_pickup_end_time_mode': _endTimeMode,
      });
      await ref.read(businessProvider.notifier).refresh();
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kebijakan booking & no-show berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan kebijakan: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.isOwnerOrAdmin;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          key: const Key('booking_policy_bottom_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Kebijakan Booking & No-Show',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Toleransi tunggu, auto-expire & jadwal kembali',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            if (!canEdit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hanya Owner atau Admin yang dapat mengubah kebijakan ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Toleransi Pengambilan (Grace Period)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _graceOptions.map((mins) {
                final selected = _gracePeriodMinutes == mins;
                return ChoiceChip(
                  key: Key('policy_grace_$mins'),
                  label: Text('${mins}m'),
                  selected: selected,
                  showCheckmark: false,
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : const Color(0xFF0F172A),
                  ),
                  onSelected: canEdit
                      ? (_) => setState(() => _gracePeriodMinutes = mins)
                      : null,
                );
              }).toList(),
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Auto-Batalkan Booking Belum Bayar',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Otomatis tandai No-Show dan lepas unit jika belum bayar/DP melewati grace period.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  key: const Key('policy_toggle_auto_expire_unpaid'),
                  value: _autoExpireUnpaid,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF0F172A),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  onChanged: canEdit
                      ? (val) => setState(() => _autoExpireUnpaid = val)
                      : null,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            const Text(
              'Jadwal Kembali Saat Ambil Terlambat',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  key: const Key('policy_end_mode_keep'),
                  label: const Text('Sesuai Jadwal Awal'),
                  selected: _endTimeMode == 'keep_original_end',
                  showCheckmark: false,
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: _endTimeMode == 'keep_original_end'
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _endTimeMode == 'keep_original_end'
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                  onSelected: canEdit
                      ? (_) =>
                          setState(() => _endTimeMode = 'keep_original_end')
                      : null,
                ),
                ChoiceChip(
                  key: const Key('policy_end_mode_shift'),
                  label: const Text('Geser Jika Tersedia'),
                  selected: _endTimeMode == 'shift_if_available',
                  showCheckmark: false,
                  selectedColor: const Color(0xFF0F172A),
                  backgroundColor: const Color(0xFFF8FAFC),
                  side: BorderSide(
                    color: _endTimeMode == 'shift_if_available'
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _endTimeMode == 'shift_if_available'
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                  onSelected: canEdit
                      ? (_) =>
                          setState(() => _endTimeMode = 'shift_if_available')
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 16),
            InkWell(
              key: const Key('open_branch_booking_rules_link'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const BookingRulesSettingsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Aturan Floating Unit & Cabang',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            if (canEdit) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('policy_save_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _savePolicy,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Kebijakan',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LateFeePolicyBottomSheet extends ConsumerStatefulWidget {
  final int businessId;
  final Map<String, dynamic>? business;
  final bool isOwnerOrAdmin;

  const _LateFeePolicyBottomSheet({
    required this.businessId,
    required this.business,
    required this.isOwnerOrAdmin,
  });

  @override
  ConsumerState<_LateFeePolicyBottomSheet> createState() =>
      _LateFeePolicyBottomSheetState();
}

class _LateFeePolicyBottomSheetState
    extends ConsumerState<_LateFeePolicyBottomSheet> {
  static const List<int> _graceOptions = [0, 10, 15, 30];

  late int _returnGraceMinutes;
  late String _graceMode;
  late String _roundingMode;
  late bool _capAtDailyRate;
  late String _defaultRateType;
  late bool _allowCashierWaiver;
  late final TextEditingController _defaultRateController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _defaultRateController = TextEditingController();
    _syncFromBusiness(widget.business);
  }

  @override
  void dispose() {
    _defaultRateController.dispose();
    super.dispose();
  }

  void _syncFromBusiness(Map<String, dynamic>? biz) {
    final rawGrace = (biz?['late_fee_grace_minutes'] as num?)?.toInt() ??
        (biz?['return_grace_period_minutes'] as num?)?.toInt();
    _returnGraceMinutes =
        (rawGrace != null && _graceOptions.contains(rawGrace)) ? rawGrace : 15;

    final rawGraceMode = biz?['late_fee_grace_mode']?.toString();
    _graceMode = rawGraceMode == 'deductive' ? 'deductive' : 'forfeit';

    final rawMode = (biz?['late_fee_rounding'] ?? biz?['late_fee_rounding_mode'])
        ?.toString();
    if (rawMode == 'half_hourly_ceil' || rawMode == 'exact_minute') {
      _roundingMode = rawMode!;
    } else {
      _roundingMode = 'hourly_ceil';
    }

    _capAtDailyRate = (biz?['late_fee_cap_daily'] ??
            biz?['cap_late_fee_at_daily_rate']) !=
        false;

    final rawType = biz?['late_fee_default_type']?.toString();
    _defaultRateType = rawType == 'percent_daily' ? 'percent_daily' : 'fixed';

    _allowCashierWaiver = biz?['allow_cashier_late_fee_waiver'] != false;

    final rawDefaultRate = double.tryParse(
      (biz?['late_fee_default_rate'] ?? biz?['default_hourly_late_fee'])
              ?.toString() ??
          '',
    );
    _defaultRateController.text =
        (rawDefaultRate != null && rawDefaultRate > 0)
            ? (rawDefaultRate % 1 == 0
                ? rawDefaultRate.toInt().toString()
                : rawDefaultRate.toString())
            : '';
  }

  Future<void> _savePolicy() async {
    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final rawRate = _defaultRateController.text.trim();
      final double parsedRate = rawRate.isNotEmpty
          ? (_defaultRateType == 'percent_daily'
              ? (double.tryParse(rawRate.replaceAll(',', '.')) ?? 0.0)
              : CurrencyFormatter.parse(rawRate))
          : 0.0;

      final payload = <String, dynamic>{
        'return_grace_period_minutes': _returnGraceMinutes,
        'late_fee_grace_minutes': _returnGraceMinutes,
        'late_fee_grace_mode': _graceMode,
        'late_fee_rounding_mode': _roundingMode,
        'late_fee_rounding': _roundingMode,
        'cap_late_fee_at_daily_rate': _capAtDailyRate,
        'late_fee_cap_daily': _capAtDailyRate,
        'default_hourly_late_fee': parsedRate,
        'late_fee_default_rate': parsedRate,
        'late_fee_default_type': _defaultRateType,
        'allow_cashier_late_fee_waiver': _allowCashierWaiver,
      };
      final updatedBiz = await ref
          .read(authRepositoryProvider)
          .updateBusiness(widget.businessId, payload);
      await ref.read(businessProvider.notifier).updateActiveBusinessProfile(
        widget.businessId,
        {...payload, ...updatedBiz},
      );
      await ref.read(businessProvider.notifier).refresh();
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aturan denda keterlambatan berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan aturan denda: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildOptionChip({
    required Key key,
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onSelected,
  }) {
    return ChoiceChip(
      key: key,
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: const Color(0xFFF8FAFC),
      side: BorderSide(
        color: selected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
      ),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : const Color(0xFF0F172A),
      ),
      onSelected: enabled ? (_) => onSelected() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = widget.isOwnerOrAdmin;
    final isPercentDefault = _defaultRateType == 'percent_daily';
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 24,
        ),
        child: Column(
          key: const Key('late_fee_policy_bottom_sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aturan Denda Keterlambatan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Toleransi, pembulatan, batas harian & izin kasir',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFFF1F5F9),
                    foregroundColor: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
            if (!canEdit) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.lock_outline_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hanya Owner atau Admin yang dapat mengubah aturan denda ini.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),
            const Text(
              'Toleransi Keterlambatan',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _graceOptions.map((mins) {
                return _buildOptionChip(
                  key: Key('late_fee_grace_$mins'),
                  label: '$mins menit',
                  selected: _returnGraceMinutes == mins,
                  enabled: canEdit,
                  onSelected: () => setState(() => _returnGraceMinutes = mins),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            const Text(
              'Perilaku Toleransi',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _graceMode == 'forfeit'
                  ? 'Jika melewati toleransi, seluruh durasi keterlambatan dihitung penuh.'
                  : 'Durasi keterlambatan dikurangi menit toleransi terlebih dahulu.',
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOptionChip(
                  key: const Key('late_fee_grace_mode_forfeit'),
                  label: 'Hangus Jika Lewat',
                  selected: _graceMode == 'forfeit',
                  enabled: canEdit,
                  onSelected: () => setState(() => _graceMode = 'forfeit'),
                ),
                _buildOptionChip(
                  key: const Key('late_fee_grace_mode_deductive'),
                  label: 'Potong Durasi Telat',
                  selected: _graceMode == 'deductive',
                  enabled: canEdit,
                  onSelected: () => setState(() => _graceMode = 'deductive'),
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            const Text(
              'Pembulatan Waktu Denda',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOptionChip(
                  key: const Key('late_fee_rounding_hourly'),
                  label: 'Per Jam',
                  selected: _roundingMode == 'hourly_ceil',
                  enabled: canEdit,
                  onSelected: () => setState(() => _roundingMode = 'hourly_ceil'),
                ),
                _buildOptionChip(
                  key: const Key('late_fee_rounding_half'),
                  label: 'Per 30 Menit',
                  selected: _roundingMode == 'half_hourly_ceil',
                  enabled: canEdit,
                  onSelected: () =>
                      setState(() => _roundingMode = 'half_hourly_ceil'),
                ),
                _buildOptionChip(
                  key: const Key('late_fee_rounding_exact'),
                  label: 'Prorata Menit',
                  selected: _roundingMode == 'exact_minute',
                  enabled: canEdit,
                  onSelected: () => setState(() => _roundingMode = 'exact_minute'),
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batas Maksimal Tarif 1 Hari',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Batasi total denda per siklus 24 jam agar tidak melebihi tarif sewa harian model.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  key: const Key('late_fee_toggle_daily_cap'),
                  value: _capAtDailyRate,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF0F172A),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  onChanged: canEdit
                      ? (val) => setState(() => _capAtDailyRate = val)
                      : null,
                ),
              ],
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            const Text(
              'Tarif Denda Default Toko',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildOptionChip(
                  key: const Key('late_fee_default_type_fixed'),
                  label: 'Nominal Tetap / Jam',
                  selected: !isPercentDefault,
                  enabled: canEdit,
                  onSelected: () => setState(() => _defaultRateType = 'fixed'),
                ),
                _buildOptionChip(
                  key: const Key('late_fee_default_type_percent'),
                  label: '% Tarif Harian',
                  selected: isPercentDefault,
                  enabled: canEdit,
                  onSelected: () =>
                      setState(() => _defaultRateType = 'percent_daily'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('late_fee_default_rate_input'),
              controller: _defaultRateController,
              enabled: canEdit,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                prefixText: isPercentDefault ? null : 'Rp ',
                suffixText: isPercentDefault ? '% / jam' : null,
                hintText: isPercentDefault
                    ? 'Contoh: 10 (10% tarif harian per jam)'
                    : '0 (jika model tidak mengatur tarif)',
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF0F172A),
                    width: 1.5,
                  ),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              key: const Key('late_fee_hierarchy_note'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Tarif default toko berlaku untuk semua model, kecuali model tersebut memiliki tarif denda khusus di katalog.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 28, color: Color(0xFFF1F5F9)),
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Izinkan Kasir Bebaskan Denda',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Jika nonaktif, hanya Owner yang dapat menyesuaikan atau membebaskan denda saat pengembalian.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Switch.adaptive(
                  key: const Key('late_fee_toggle_allow_waiver'),
                  value: _allowCashierWaiver,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFF0F172A),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFE2E8F0),
                  trackOutlineColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  onChanged: canEdit
                      ? (val) => setState(() => _allowCashierWaiver = val)
                      : null,
                ),
              ],
            ),
            if (canEdit) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  key: const Key('late_fee_save_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isSaving ? null : _savePolicy,
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Simpan Aturan Denda',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

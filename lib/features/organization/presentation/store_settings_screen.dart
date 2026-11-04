import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/presentation/user_profile_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/presentation/cashier_screen.dart';
import '../../customers/presentation/customer_directory_screen.dart';
import '../../printer/presentation/printer_settings_screen.dart';
import '../../transfers/presentation/transfers_screen.dart';
import '../../vouchers/presentation/voucher_screen.dart';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text(
              'Keluar Akun',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  void _openShiftMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Shift Kasir & Jam Operasional',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.point_of_sale_outlined,
                    color: AppColors.obsidian,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Kasir & Tutup Buku Shift',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Pembayaran, kas & laci kasir',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashierScreen()),
                  );
                },
              ),
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 20,
                color: AppColors.border,
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: AppColors.obsidian,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Jadwal & Jam Operasional Shift',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Atur jam buka, tutup & toleransi cabang',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ShiftScheduleScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);

    final isSuperAdmin =
        user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final currentBiz = bState.currentBusiness;
    final userRole =
        currentBiz?['role']?.toString().toLowerCase() ??
        user?['role']?.toString().toLowerCase() ??
        '';
    final isOwnerOrAdmin =
        userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final userName = user?['name']?.toString() ?? 'Pengguna RentCore';
    final userEmail = user?['email']?.toString() ?? '-';
    final storeName = bState.activeBusinessName ?? 'Belum ada usaha terpilih';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(title: 'Pengaturan'),
      body: ListView(
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: 100,
        ),
        children: [
          // User Card Summary
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      color: AppColors.obsidian,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _getInitials(userName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
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
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          userEmail,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                userRole.toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // GROUP 1: AKUN & TOKO
          _buildGroupHeader('AKUN & TOKO'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.person_outline_rounded,
              title: 'Profil Pengguna',
              subtitle: 'Keamanan & data pribadi',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UserProfileScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.storefront_outlined,
              title: 'Profil Usaha & Cabang',
              subtitle: storeName,
              badge: isOwnerOrAdmin ? null : 'Lihat Saja',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StoreProfileScreen()),
                );
              },
            ),
            if (userRole != 'owner' && bState.activeBusinessId != null) ...[
              _buildDivider(),
              _buildListTile(
                icon: Icons.badge_outlined,
                title: 'Status Kepegawaian & Resign',
                subtitle: 'Penugasan cabang & resign',
                badge: 'Kepegawaian',
                badgeColor: const Color(0xFFFEF3C7),
                badgeTextColor: const Color(0xFFD97706),
                onTap: () {
                  StaffResignationSheet.show(
                    context,
                    businessId: bState.activeBusinessId!,
                    businessName: bState.activeBusinessName ?? 'Bisnis Rental',
                  );
                },
              ),
            ],
          ]),
          const SizedBox(height: 20),

          // GROUP 2: OPERASIONAL KASIR
          _buildGroupHeader('OPERASIONAL KASIR'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.payments_outlined,
              title: 'Metode Pembayaran',
              subtitle: 'QRIS, Tunai, Bank & E-Wallet',
              badge: isOwnerOrAdmin ? null : 'Lihat Saja',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PaymentMethodSettingsScreen(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.schedule_rounded,
              title: 'Shift Kasir & Jam Operasional',
              subtitle: 'Buku kas & jam operasional',
              onTap: () => _openShiftMenu(context),
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Voucher & Promo',
              subtitle: 'Manajemen diskon & voucher sewa',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoucherScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.print_outlined,
              title: 'Printer Thermal',
              subtitle: 'Koneksi Bluetooth ESC/POS',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PrinterSettingsScreen(),
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 20),

          // GROUP 3: INVENTARIS & PELANGGAN
          _buildGroupHeader('INVENTARIS & PELANGGAN'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.people_alt_outlined,
              title: 'Direktori Pelanggan & Blacklist',
              subtitle: 'Data pelanggan & verifikasi KTP',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerDirectoryScreen(),
                  ),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Mutasi Unit',
              subtitle: 'Transfer unit antar-cabang',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransfersScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.badge_outlined,
              title: 'Kelola Tim & Staf Cabang',
              subtitle: 'Anggota tim & hak akses',
              badge: isOwnerOrAdmin ? null : 'Owner / Admin',
              badgeColor: isOwnerOrAdmin ? null : const Color(0xFFFEF3C7),
              badgeTextColor: isOwnerOrAdmin ? null : const Color(0xFFD97706),
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
                        businessName:
                            bState.activeBusinessName ?? 'Bisnis Rental',
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
          ]),
          const SizedBox(height: 20),

          // GROUP 4: SESI AKUN
          _buildGroupHeader('SESI AKUN'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.logout_rounded,
              title: 'Keluar Akun',
              subtitle: 'Akhiri sesi pada perangkat ini',
              iconColor: AppColors.danger,
              titleColor: AppColors.danger,
              onTap: () => _confirmLogout(context, ref),
            ),
          ]),
          const SizedBox(height: 24),

          // App Version Footer
          const Center(
            child: Text(
              'RentCore Mobile Handheld • Versi 1.0.0+1',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
    bool showChevron = true,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.obsidian).withValues(
                  alpha: 0.08,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor ?? AppColors.obsidian,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: titleColor ?? AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor ?? AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeTextColor ?? AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right,
                size: 20,
                color: AppColors.textSecondary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(
      height: 1,
      indent: 56,
      endIndent: 16,
      color: AppColors.border,
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

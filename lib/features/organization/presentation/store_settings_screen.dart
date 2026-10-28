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
            Text('Keluar Akun', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari akun ini? Sesi Anda pada perangkat ini akan diakhiri.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);

    final isSuperAdmin = user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final currentBiz = bState.currentBusiness;
    final userRole = currentBiz?['role']?.toString().toLowerCase() ?? user?['role']?.toString().toLowerCase() ?? '';
    final isOwnerOrAdmin = userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final userName = user?['name']?.toString() ?? 'Pengguna RentCore';
    final userEmail = user?['email']?.toString() ?? '-';
    final storeName = bState.activeBusinessName ?? 'Belum ada usaha terpilih';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(
        title: 'Pengaturan',
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // GROUP 1: PROFIL & BISNIS
          _buildGroupHeader('PROFIL & IDENTITAS'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.person_outline_rounded,
              title: 'Profil Saya & Keamanan',
              subtitle: 'Ubah nama, telepon, dan kelola kata sandi',
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
              title: 'Profil Usaha & Slogan',
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
                subtitle: 'Penugasan cabang dan pengajuan pengunduran diri',
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
          const SizedBox(height: 18),

          // GROUP 2: OPERASIONAL & PERANGKAT
          _buildGroupHeader('OPERASIONAL & PERANGKAT'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.print_outlined,
              title: 'Printer Thermal & Kasir',
              subtitle: 'Sambungkan printer Bluetooth ESC/POS & format struk',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.confirmation_number_outlined,
              title: 'Voucher Promo & Diskon',
              subtitle: 'Manajemen voucher sewa & cetak slip kupon',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const VoucherScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Mutasi / Transfer Unit',
              subtitle: 'Kirim, setujui, dan terima mutasi unit antar-cabang',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TransfersScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.point_of_sale_outlined,
              title: 'Kasir & Tutup Buku Shift',
              subtitle: 'Pembayaran counter, pengeluaran kasir & shift drawer',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CashierScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.access_time_rounded,
              title: 'Jadwal & Jam Operasional Shift',
              subtitle: 'Atur jam operasional, toleransi tutup, dan override cabang',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ShiftScheduleScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.payments_outlined,
              title: 'Metode Pembayaran',
              subtitle: 'Atur E-Wallet, QRIS Statis, dan upload gambar barcode QR',
              badge: isOwnerOrAdmin ? null : 'Lihat Saja',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PaymentMethodSettingsScreen()),
                );
              },
            ),
            _buildDivider(),
            _buildListTile(
              icon: Icons.people_alt_outlined,
              title: 'Direktori Pelanggan & Blacklist',
              subtitle: 'Pencarian penyewa, verifikasi KTP, dan status risiko',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CustomerDirectoryScreen()),
                );
              },
            ),
          ]),
          const SizedBox(height: 18),

          // GROUP 3: ORGANISASI (OWNER/ADMIN)
          _buildGroupHeader('ORGANISASI'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.people_outline_rounded,
              title: 'Kelola Tim & Staf Cabang',
              subtitle: 'Anggota tim, peran pengguna, dan akses cabang',
              badge: isOwnerOrAdmin ? null : 'Owner / Admin',
              badgeColor: isOwnerOrAdmin ? null : const Color(0xFFFEF3C7),
              badgeTextColor: isOwnerOrAdmin ? null : const Color(0xFFD97706),
              onTap: () {
                if (!isOwnerOrAdmin) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Kelola Tim hanya dapat diakses oleh Owner atau Admin.'),
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
                        businessName: bState.activeBusinessName ?? 'Bisnis Rental',
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
          const SizedBox(height: 18),

          // GROUP 4: SESI
          _buildGroupHeader('SESI AKUN'),
          _buildSettingsCard([
            _buildListTile(
              icon: Icons.logout_rounded,
              title: 'Keluar Akun',
              subtitle: 'Akhiri sesi aktif pada perangkat ini',
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
    required String subtitle,
    required VoidCallback onTap,
    Color? iconColor,
    Color? titleColor,
    String? badge,
    Color? badgeColor,
    Color? badgeTextColor,
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
                color: (iconColor ?? AppColors.obsidian).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor ?? AppColors.obsidian, size: 20),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 56, endIndent: 16, color: AppColors.border);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }
}

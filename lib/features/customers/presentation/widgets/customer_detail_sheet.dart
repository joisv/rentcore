import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../bookings/presentation/direct_rental_screen.dart';
import '../../providers/customer_provider.dart';

class CustomerDetailSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> customer;

  const CustomerDetailSheet({super.key, required this.customer});

  static Future<void> show(BuildContext context, Map<String, dynamic> customer) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CustomerDetailSheet(customer: customer),
    );
  }

  @override
  ConsumerState<CustomerDetailSheet> createState() => _CustomerDetailSheetState();
}

class _CustomerDetailSheetState extends ConsumerState<CustomerDetailSheet> {
  late Map<String, dynamic> _customer;

  @override
  void initState() {
    super.initState();
    _customer = Map<String, dynamic>.from(widget.customer);
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Future<void> _handleBlacklistToggle(bool blacklist) async {
    final reasonController = TextEditingController();
    final pinController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          blacklist ? 'Tandai Sebagai Blacklist' : 'Cabut Status Blacklist',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: blacklist ? AppColors.danger : AppColors.obsidian,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              blacklist
                  ? 'Pelanggan yang masuk daftar hitam tidak akan dapat menyewa unit baru sebelum status dicabut oleh Owner/Admin.'
                  : 'Pelanggan akan dipulihkan ke status aktif dan dapat kembali melakukan transaksi sewa.',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            if (blacklist) ...[
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Alasan Blacklist *',
                  hintText: 'Misal: Terlambat > 7 hari tanpa kabar',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'PIN Manager (Jika Staf)',
                hintText: '6 digit PIN',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: blacklist ? AppColors.danger : AppColors.success,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (blacklist && reasonController.text.trim().length < 5) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Alasan blacklist wajib diisi minimal 5 karakter.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: Text(blacklist ? 'Ya, Blacklist' : 'Pulihkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await ref.read(customerProvider.notifier).toggleBlacklist(
        customerId: _customer['id'],
        isBlacklisted: blacklist,
        reason: blacklist ? reasonController.text.trim() : null,
        managerPin: pinController.text.trim().isEmpty ? null : pinController.text.trim(),
      );

      if (mounted) {
        if (success) {
          setState(() {
            _customer['is_blacklisted'] = blacklist;
            if (blacklist) {
              _customer['blacklist_reason'] = reasonController.text.trim();
            } else {
              _customer['blacklist_reason'] = null;
            }
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(blacklist ? 'Pelanggan berhasil ditandai blacklist.' : 'Status blacklist berhasil dicabut.'),
              backgroundColor: blacklist ? AppColors.danger : AppColors.success,
            ),
          );
        } else {
          final err = ref.read(customerProvider).error;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(err ?? 'Gagal memperbarui status pelanggan.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _customer['name']?.toString() ?? 'Pelanggan';
    final phone = _customer['phone']?.toString() ?? '-';
    final email = _customer['email']?.toString();
    final address = _customer['address']?.toString();
    final isBlacklisted = _customer['is_blacklisted'] == true;
    final blacklistReason = _customer['blacklist_reason']?.toString();
    final bookingsCount = _customer['bookings_count'] ?? 0;
    final identities = (_customer['identities'] as List?) ?? [];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Header Card
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isBlacklisted ? AppColors.dangerLight : AppColors.obsidian,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _getInitials(name),
                    style: TextStyle(
                      color: isBlacklisted ? AppColors.danger : Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
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
                              name,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isBlacklisted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'BLACKLIST',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        phone,
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                      if (email != null && email.isNotEmpty)
                        Text(
                          email,
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Blacklist Warning Banner (If Blacklisted)
            if (isBlacklisted) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Pelanggan Dalam Daftar Hitam',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.danger,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            blacklistReason != null && blacklistReason.isNotEmpty
                                ? 'Alasan: $blacklistReason'
                                : 'Tidak ada catatan alasan yang tersimpan.',
                            style: const TextStyle(fontSize: 11, color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Stats Row
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text('Total Sewa', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          '$bookingsCount Kali',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.obsidian),
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
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        const Text('Status Akun', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                        const SizedBox(height: 2),
                        Text(
                          isBlacklisted ? 'Blacklisted' : 'Aktif (Aman)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isBlacklisted ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Domisili Address
            if (address != null && address.isNotEmpty) ...[
              const Text('Alamat Domisili:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textMuted)),
              const SizedBox(height: 4),
              Text(address, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
            ],

            // Verified Identity Documents Section
            const Text(
              'DOKUMEN IDENTITAS TERDAFTAR',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            if (identities.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'Belum ada dokumen identitas (KTP/SIM/Paspor) terlampir.',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              )
            else
              ...identities.map((idDoc) {
                final idMap = idDoc is Map ? idDoc : {};
                final type = idMap['identity_type'] ?? 'KTP';
                final number = idMap['identity_number'] ?? '-';
                final isVerified = idMap['is_verified'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.badge_outlined, size: 18, color: AppColors.info),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$type • $number',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isVerified ? 'Terverifikasi' : 'Belum Diverifikasi',
                              style: TextStyle(
                                fontSize: 11,
                                color: isVerified ? AppColors.success : AppColors.textMuted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.verified_rounded, size: 18, color: AppColors.success),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: isBlacklisted ? AppColors.success : AppColors.danger),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: Icon(
                      isBlacklisted ? Icons.lock_open_rounded : Icons.block_rounded,
                      size: 16,
                      color: isBlacklisted ? AppColors.success : AppColors.danger,
                    ),
                    label: Text(
                      isBlacklisted ? 'Cabut Blacklist' : 'Blacklist Pelanggan',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isBlacklisted ? AppColors.success : AppColors.danger,
                      ),
                    ),
                    onPressed: () => _handleBlacklistToggle(!isBlacklisted),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBlacklisted ? AppColors.textMuted : AppColors.obsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 16),
                    label: const Text(
                      'Sewa Unit',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: isBlacklisted
                        ? null
                        : () {
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DirectRentalScreen()),
                            );
                          },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

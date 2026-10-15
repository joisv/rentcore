import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../providers/voucher_provider.dart';
import 'voucher_form_dialog.dart';

class VoucherDetailDialog extends ConsumerWidget {
  final Map<String, dynamic> voucher;
  final bool isOwner;
  final List<dynamic> branches;
  final VoidCallback onPrintThermal;

  const VoucherDetailDialog({
    super.key,
    required this.voucher,
    required this.isOwner,
    required this.branches,
    required this.onPrintThermal,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> voucher,
    required bool isOwner,
    required List<dynamic> branches,
    required VoidCallback onPrintThermal,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoucherDetailDialog(
        voucher: voucher,
        isOwner: isOwner,
        branches: branches,
        onPrintThermal: onPrintThermal,
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    final id = voucher['id'] is int ? voucher['id'] as int : int.parse(voucher['id'].toString());
    final usageCount = voucher['usage_count'] ?? 0;

    if (usageCount > 0) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.warning),
              SizedBox(width: 8),
              Text('Tidak Dapat Dihapus', style: TextStyle(fontSize: 16)),
            ],
          ),
          content: Text(
            'Voucher ini telah digunakan sebanyak $usageCount kali dalam riwayat sewa pelanggan.\n\nSesuai standar integritas data transaksi keuangan, voucher yang sudah pernah dipakai tidak boleh dihapus agar laporan pembukuan tetap akurat.\n\nSilakan pilih "Nonaktifkan Voucher" untuk menghentikan penggunaan voucher ini ke depannya.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(voucherProvider.notifier).toggleStatus(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voucher berhasil dinonaktifkan!')),
                  );
                }
              },
              child: const Text('Nonaktifkan Saja'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Voucher Promo?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus voucher "${voucher['code']}"?\n\nVoucher belum pernah digunakan dalam transaksi apapun dan akan dihapus secara permanen.',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(voucherProvider.notifier).deleteVoucher(id);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Voucher berhasil dihapus!')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            child: const Text('Hapus Permanen', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountPercent = CurrencyFormatter.parse(voucher['discount_percentage']);
    final minSpend = CurrencyFormatter.parse(voucher['min_transaction_amount']);
    final maxCap = voucher['max_discount_cap'] != null ? CurrencyFormatter.parse(voucher['max_discount_cap']) : null;
    final isActive = voucher['is_active'] == true;
    final endAt = voucher['end_at'] != null ? DateTime.tryParse(voucher['end_at'].toString()) : null;
    final startAt = voucher['start_at'] != null ? DateTime.tryParse(voucher['start_at'].toString()) : null;
    final isExpired = endAt != null && endAt.isBefore(DateTime.now());
    final branchName = voucher['affiliate']?['name'] ?? 'Semua Cabang (Bisnis-wide)';
    final usageCount = voucher['usage_count'] ?? 0;
    final usageLimitTotal = voucher['usage_limit_total'];
    final perCustLimit = voucher['usage_limit_per_customer'] ?? 1;
    final creatorName = voucher['creator']?['name'] ?? 'Owner Toko';
    final id = voucher['id'] is int ? voucher['id'] as int : int.parse(voucher['id'].toString());

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header Row: Code & Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.qr_code_2_rounded, size: 20, color: AppColors.obsidian),
                          const SizedBox(width: 8),
                          Text(
                            voucher['code'] ?? '',
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        voucher['name'] ?? 'Voucher Promo',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: !isActive
                        ? AppColors.surfaceMuted
                        : isExpired
                            ? AppColors.danger.withValues(alpha: 0.1)
                            : AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    !isActive
                        ? 'Nonaktif'
                        : isExpired
                            ? 'Kedaluwarsa'
                            : 'Aktif',
                    style: TextStyle(
                      color: !isActive
                          ? AppColors.textMuted
                          : isExpired
                              ? AppColors.danger
                              : AppColors.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 16),

            // Detail Grid
            _buildDetailRow('Diskon Promosi', '${discountPercent.toInt()}% OFF'),
            if (maxCap != null) _buildDetailRow('Plafon Maksimal', CurrencyFormatter.format(maxCap)),
            _buildDetailRow('Min. Transaksi Sewa', CurrencyFormatter.format(minSpend)),
            _buildDetailRow('Cakupan Cabang', branchName),
            _buildDetailRow(
              'Periode Promo',
              '${DateFormatter.formatShort(startAt)} — ${DateFormatter.formatShort(endAt)}',
            ),
            _buildDetailRow(
              'Kouta Penggunaan',
              usageLimitTotal != null ? '$usageCount / $usageLimitTotal terpakai' : '$usageCount kali digunakan',
            ),
            _buildDetailRow('Batas per Pelanggan', '$perCustLimit kali'),
            _buildDetailRow('Format Barcode', (voucher['barcode_type'] ?? 'qr_code').toString().toUpperCase()),
            _buildDetailRow('Diterbitkan Oleh', creatorName),

            if (voucher['description'] != null && voucher['description'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Keterangan / Catatan:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                voucher['description'].toString(),
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
              ),
            ],

            const SizedBox(height: 24),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 16),

            // Action Buttons
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.print_outlined, size: 18),
              label: const Text('Cetak Slip Fisik ke Printer Thermal'),
              onPressed: () {
                Navigator.pop(context);
                onPrintThermal();
              },
            ),

            if (isOwner) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: Icon(isActive ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded, size: 18),
                      label: Text(isActive ? 'Nonaktifkan' : 'Aktifkan'),
                      onPressed: () async {
                        await ref.read(voucherProvider.notifier).toggleStatus(id);
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Status voucher berhasil diubah menjadi ${!isActive ? "Aktif" : "Nonaktif"}!')),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      onPressed: () {
                        Navigator.pop(context);
                        VoucherFormDialog.show(
                          context,
                          voucher: voucher,
                          branches: branches,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.danger.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
                    tooltip: 'Hapus Voucher',
                    onPressed: () => _confirmDelete(context, ref),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/voucher_provider.dart';

class VoucherScreen extends ConsumerWidget {
  const VoucherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vouchersAsync = ref.watch(vouchersListProvider);
    final authState = ref.watch(authProvider);
    final isSuperAdmin = authState.user?['role'] == 'super_admin';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Voucher & Barcode 2D'),
        actions: [
          if (isSuperAdmin)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'Buat Voucher Baru (Super-Admin)',
              onPressed: () => _showCreateVoucherDialog(context, ref),
            ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(vouchersListProvider),
          ),
        ],
      ),
      body: vouchersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat voucher:\n$e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Coba Lagi'),
                  onPressed: () => ref.refresh(vouchersListProvider),
                ),
              ],
            ),
          ),
        ),
        data: (vouchers) {
          if (vouchers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.confirmation_number_outlined, size: 48, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Belum ada voucher aktif.'),
                  if (isSuperAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _showCreateVoucherDialog(context, ref),
                      child: const Text('+ Buat Voucher Pertama'),
                    ),
                  ],
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
            itemCount: vouchers.length,
            itemBuilder: (context, index) {
              final v = vouchers[index];
              final discountPercent = CurrencyFormatter.parse(v['discount_percentage']);
              final minSpend = CurrencyFormatter.parse(v['min_transaction_amount']);
              final endAt = v['end_at'] != null ? DateTime.tryParse(v['end_at'].toString()) : null;

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.obsidian,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${discountPercent.toInt()}% OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        Text(
                          'Berlaku s/d ${DateFormatter.formatShort(endAt)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      v['name'] ?? 'Voucher Promo',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      v['description'] ?? 'Gunakan saat sewa di meja kasir.',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          'Min. Belanja: ${CurrencyFormatter.format(minSpend)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppColors.borderSubtle),
                    const SizedBox(height: 12),

                    // Thermal Slip Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.obsidian),
                            const SizedBox(width: 6),
                            Text(
                              v['code'] ?? '',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(140, 38),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          icon: const Icon(Icons.print_outlined, size: 16),
                          label: const Text('Cetak Slip Fisik', style: TextStyle(fontSize: 12)),
                          onPressed: () => _showThermalSlipModal(context, v),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showThermalSlipModal(BuildContext context, Map<String, dynamic> voucher) {
    final code = voucher['code'] ?? '';
    final percent = CurrencyFormatter.parse(voucher['discount_percentage']);
    final minSpend = CurrencyFormatter.parse(voucher['min_transaction_amount']);
    final validUntil = voucher['end_at'] != null ? DateFormatter.formatShort(voucher['end_at']) : '-';
    final branchName = voucher['affiliate']?['name'] ?? 'Semua Cabang RentCore';

    final printerService = ThermalPrinterService();
    final escposBytes = printerService.buildVoucherSlipBytes(
      shopName: 'RENTCORE GADGETS',
      branchName: branchName,
      voucherCode: code,
      discountPercentage: percent,
      minTransaction: minSpend,
      validUntil: validUntil,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Cetak Slip Voucher Fisik',
        branchName: branchName,
        escposBytes: escposBytes,
        qrData: code,
        content: Column(
          children: [
            const Text(
              'VOUCHER DISKON SPESIAL',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              '*** ${percent.toInt()}% OFF ***',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Kode Voucher  : $code',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Text(
              'Min. Transaksi: ${CurrencyFormatter.format(minSpend)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            Text(
              'Berlaku s/d   : $validUntil',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateVoucherDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController(text: 'Voucher Pelanggan Baru 20%');
    final codeCtrl = TextEditingController(text: 'RC-VCR-BARU20');
    final percentCtrl = TextEditingController(text: '20');
    final minSpendCtrl = TextEditingController(text: '300000');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Buat Voucher Super-Admin'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Nama Voucher')),
                const SizedBox(height: 10),
                TextField(controller: codeCtrl, decoration: const InputDecoration(labelText: 'Kode Voucher')),
                const SizedBox(height: 10),
                TextField(controller: percentCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Diskon (%)')),
                const SizedBox(height: 10),
                TextField(controller: minSpendCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Min. Transaksi (Rp)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final repo = ref.read(voucherRepositoryProvider);
                  await repo.createVoucher({
                    'name': nameCtrl.text.trim(),
                    'code': codeCtrl.text.trim(),
                    'discount_percentage': double.parse(percentCtrl.text.trim()),
                    'min_transaction_amount': double.parse(minSpendCtrl.text.trim()),
                    'start_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
                    'end_at': DateTime.now().add(const Duration(days: 60)).toIso8601String(),
                  });
                  ref.invalidate(vouchersListProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voucher diskon Super-Admin berhasil dibuat!')),
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
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
}

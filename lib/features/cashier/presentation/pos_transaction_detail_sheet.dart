import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../providers/cashier_provider.dart';

class PosTransactionDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final VoidCallback? onPaymentRequested;

  const PosTransactionDetailSheet({
    super.key,
    required this.booking,
    this.onPaymentRequested,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingId = booking['booking_id'] ?? booking['id'];
    final detailAsync = ref.watch(bookingDetailProvider(bookingId));

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 20, color: AppColors.obsidian),
                    SizedBox(width: 8),
                    Text(
                      'Rincian Transaksi Rental POS',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Body
          Expanded(
            child: detailAsync.when(
              loading: () => _buildContent(context, ref, booking, isLoadingDeep: true),
              error: (_, _) => _buildContent(context, ref, booking),
              data: (deepData) => _buildContent(context, ref, deepData.isNotEmpty ? deepData : booking),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> b, {
    bool isLoadingDeep = false,
  }) {
    final customer = b['customer'] as Map? ?? {};
    final affiliate = b['affiliate'] as Map? ?? {};
    final creator = b['creator'] as Map? ?? {};
    final items = (b['items'] as List?) ?? [];
    final payments = (b['payments'] as List?) ?? [];
    final extensions = (b['extensions'] as List?) ?? [];
    final returnInspection = b['return_inspection'] as Map? ?? b['returnInspection'] as Map? ?? {};

    final bookingCode = b['booking_code'] ?? '-';
    final status = (b['status'] ?? 'rented').toString().toLowerCase();
    final paymentStatus = (b['payment_status'] ?? 'paid').toString().toLowerCase();
    final isPaid = paymentStatus == 'paid';

    final totalBill = CurrencyFormatter.parse(b['total_bill']);
    final subtotal = CurrencyFormatter.parse(b['subtotal_amount']);
    final discount = CurrencyFormatter.parse(b['discount_amount']);

    double totalPaid = 0.0;
    double penaltyPaid = 0.0;
    for (final p in payments) {
      final pType = p['type']?.toString().toLowerCase();
      if (pType == 'settlement' || pType == 'dp' || pType == 'extension' || pType == 'rental') {
        totalPaid += CurrencyFormatter.parse(p['amount']);
      } else if (pType == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    if (totalPaid == 0 && isPaid) {
      totalPaid = totalBill;
    }
    final remainingRentalDue = (totalBill - totalPaid).clamp(0.0, double.infinity);
    final totalPenaltyDue = CurrencyFormatter.parse(returnInspection['total_penalty']);
    final remainingPenaltyDue = (totalPenaltyDue - penaltyPaid).clamp(0.0, double.infinity);
    final remainingDue = remainingRentalDue + remainingPenaltyDue;

    final isCentral = affiliate['is_central'] == true;
    final branchName = affiliate['name'] ?? (isCentral ? 'Pusat (Main Store)' : 'Cabang');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isLoadingDeep) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],

          // 1. Transaction Badge & Branch Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          bookingCode,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 16, color: AppColors.textSecondary),
                          tooltip: 'Salin Kode Booking',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: bookingCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kode booking disalin ke clipboard')),
                            );
                          },
                        ),
                      ],
                    ),
                    _buildStatusChip(paymentStatus, status),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCentral ? AppColors.warningLight : AppColors.infoLight,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCentral ? 'PUSAT (MAIN STORE)' : 'CABANG SATELLITE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isCentral ? AppColors.warning : AppColors.info,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        branchName,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Customer & Staff Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PIHAK TERKAIT',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            customer['name'] ?? 'Pelanggan Walk-In',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          if (customer['phone'] != null)
                            Text(
                              customer['phone'],
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.badge_outlined, size: 18, color: AppColors.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Petugas/Kasir: ${creator['name'] ?? 'Staff RentCore'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Rented Assets & Identifiers
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNIT PERANGKAT DISEWA',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Text(
                    b['items_summary'] ?? 'Perangkat Apple iPhone',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  )
                else
                  ...items.map((item) {
                    final asset = item['asset'] as Map? ?? {};
                    final model = asset['model'] as Map? ?? {};
                    final modelName = model['name'] ?? 'Apple iPhone';
                    final storage = model['storage_capacity'] ?? '';
                    final color = model['color'] ?? '';
                    final sn = asset['serial_number'] ?? '-';
                    final imei = asset['imei_1'] ?? '-';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone_rounded, size: 20, color: AppColors.obsidian),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$modelName $storage $color'.trim(),
                                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('SN: $sn', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                              Text('IMEI: $imei', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Rental Timeline
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PERIODE & DURASI RENTAL',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                _buildTimelineRow('Mulai Rental', b['start_at']),
                const SizedBox(height: 6),
                _buildTimelineRow('Jadwal Kembali', b['end_at']),
                if (returnInspection['returned_at'] != null) ...[
                  const SizedBox(height: 6),
                  _buildTimelineRow('Waktu Pengembalian', returnInspection['returned_at']),
                ],
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Durasi:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      '${b['duration_hours'] ?? 24} Jam',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Financial Audit Breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RINCIAN TAGIHAN & PEMBAYARAN',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                ),
                const SizedBox(height: 10),
                _buildPriceRow('Harga Sewa Pokok', subtotal),
                if (discount > 0) ...[
                  const SizedBox(height: 4),
                  _buildPriceRow('Diskon / Voucher', -discount, isDiscount: true),
                ],
                if (extensions.isNotEmpty) ...[
                  ...extensions.map((ext) {
                    final addHours = ext['additional_hours'] ?? 0;
                    final addFee = CurrencyFormatter.parse(ext['additional_fee']);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPriceRow('Perpanjangan ($addHours Jam)', addFee),
                    );
                  }),
                ],
                if (returnInspection.isNotEmpty) ...[
                  if (CurrencyFormatter.parse(returnInspection['late_fee']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPriceRow('Denda Keterlambatan', CurrencyFormatter.parse(returnInspection['late_fee'])),
                    ),
                  if (CurrencyFormatter.parse(returnInspection['damage_fee']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPriceRow('Biaya Kerusakan/Denda', CurrencyFormatter.parse(returnInspection['damage_fee'])),
                    ),
                ],
                const Divider(height: 16),
                _buildPriceRow('TOTAL TAGIHAN', totalBill + totalPenaltyDue, isBold: true, fontSize: 14),
                const SizedBox(height: 6),
                _buildPriceRow('Total Terbayar', totalPaid + penaltyPaid, color: AppColors.success),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'SISA HARUS DIBAYAR',
                  remainingDue,
                  isBold: true,
                  color: remainingDue > 0 ? AppColors.danger : AppColors.success,
                  fontSize: 14,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 6. Payment Transaction History Logs
          if (payments.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'RIWAYAT TRANSAKSI PEMBAYARAN',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  ...payments.map((p) {
                    final pAmt = CurrencyFormatter.parse(p['amount']);
                    final pMethod = p['payment_method']?['name'] ?? p['payment_method'] ?? 'Tunai';
                    final pDate = p['transacted_at'] ?? p['created_at'] ?? '';
                    final pCashier = p['processor']?['name'] ?? p['processed_by']?['name'] ?? 'Kasir';
                    final pType = p['type']?.toString().toLowerCase();
                    final pTypeLabel = p['type_label'] ?? (pType == 'penalty' ? 'Denda Keterlambatan' : (pType == 'extension' ? 'Perpanjangan' : 'Sewa Kontrak'));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('$pMethod • $pTypeLabel', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                              Text('$pDate • Oleh: $pCashier', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                            ],
                          ),
                          Text(CurrencyFormatter.format(pAmt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // 7. Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text('Cetak Struk (ESC/POS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  onPressed: () => _printBookingReceipt(context, ref, b),
                ),
              ),
              if (remainingDue > 0) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.payments_rounded, size: 18),
                    label: const Text('Bayar di Kasir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    onPressed: () {
                      Navigator.pop(context);
                      onPaymentRequested?.call();
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String paymentStatus, String bookingStatus) {
    final isPaid = paymentStatus == 'paid';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPaid ? AppColors.successLight : AppColors.dangerLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'LUNAS' : (paymentStatus == 'partial' ? 'SEBAGIAN' : 'BELUM LUNAS'),
        style: TextStyle(
          color: isPaid ? AppColors.success : AppColors.danger,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String label, dynamic value) {
    final strVal = value != null ? value.toString().replaceAll('T', ' ').substring(0, 16) : '-';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        Text(strVal, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isDiscount = false,
    Color? color,
    double fontSize = 12,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? AppColors.textPrimary,
          ),
        ),
        Text(
          (isDiscount ? '- ' : '') + CurrencyFormatter.format(amount.abs()),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w700,
            color: isDiscount ? AppColors.danger : (color ?? AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  void _printBookingReceipt(BuildContext context, WidgetRef ref, Map<String, dynamic> b) async {
    try {
      final repo = ref.read(cashierRepositoryProvider);
      final payments = (b['payments'] as List?) ?? [];
      final latestTx = payments.isNotEmpty ? payments.last : null;
      final receiptId = latestTx?['receipt_number'] ?? latestTx?['id'] ?? b['id'];

      final receiptData = await repo.fetchReceipt(receiptId);
      if (!context.mounted) return;

      final branchName = receiptData['outlet_name'] ?? b['affiliate']?['name'] ?? 'RentCore';
      final cashierName = receiptData['cashier_name'] ?? 'Kasir';
      final receiptNum = receiptData['receipt_number'] ?? b['booking_code'] ?? '-';
      final totalAmt = CurrencyFormatter.parse(receiptData['total_amount'] ?? b['total_bill']);
      final method = receiptData['payment_method'] ?? 'Tunai';

      final printerService = ThermalPrinterService();
      final escposBytes = printerService.buildClosingShiftSlipBytes(
        branchName: branchName,
        cashierName: cashierName,
        date: receiptData['transacted_at']?.toString() ?? DateTime.now().toString().substring(0, 16),
        totalTransactions: 1,
        totalRevenue: totalAmt,
        paymentBreakdown: {method: totalAmt},
      );

      showDialog(
        context: context,
        builder: (ctx) => ThermalReceiptPreviewDialog(
          title: 'Struk Transaksi POS',
          branchName: branchName,
          escposBytes: escposBytes,
          content: Column(
            children: [
              const Text('STRUK SEWA KASIR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text('No: $receiptNum', style: const TextStyle(fontSize: 11)),
              Text('Pelanggan: ${b['customer']?['name'] ?? '-'}', style: const TextStyle(fontSize: 11)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bayar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(CurrencyFormatter.format(totalAmt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencetak struk: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}

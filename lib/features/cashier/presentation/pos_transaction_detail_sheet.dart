import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../bookings/presentation/exchange_history_sheet.dart';
import '../../bookings/presentation/exchange_wizard_screen.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/cashier_provider.dart';

class PosTransactionDetailSheet extends ConsumerWidget {
  final Map<String, dynamic> booking;
  final ValueChanged<Map<String, dynamic>>? onPaymentRequested;

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
    final exchanges = (b['exchanges'] as List?) ?? [];
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
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pType = p['type']?.toString().toLowerCase();
      if (pType == 'settlement' || pType == 'dp' || pType == 'extension' || pType == 'rental' || pType == 'exchange') {
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
                              if (b['status'] == 'rented' && item['status'] != 'exchanged')
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                                    side: const BorderSide(color: AppColors.info),
                                    foregroundColor: AppColors.info,
                                  ),
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                                  label: const Text('Tukar Unit', style: TextStyle(fontSize: 11)),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ExchangeWizardScreen(booking: b),
                                      ),
                                    );
                                    if (res != null) {
                                      ref.invalidate(bookingsListProvider);
                                    }
                                  },
                                )
                              else if (item['status'] == 'exchanged')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.warningLight,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DITUKAR',
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.warning),
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

          // 3b. Exchange History Summary & Direct Access
          if (exchanges.isNotEmpty) ...[
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
                      const Row(
                        children: [
                          Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.info),
                          SizedBox(width: 6),
                          Text(
                            'RIWAYAT PERTUKARAN UNIT',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          foregroundColor: AppColors.info,
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text('Detail Lengkap', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () => ExchangeHistorySheet.show(context, b),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...exchanges.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final exc = entry.value as Map;
                    final oldAsset = exc['old_asset'] as Map? ?? exc['oldAsset'] as Map? ?? {};
                    final newAsset = exc['new_asset'] as Map? ?? exc['newAsset'] as Map? ?? {};
                    final oldModel = oldAsset['model'] as Map? ?? {};
                    final newModel = newAsset['model'] as Map? ?? {};
                    final diff = CurrencyFormatter.parse(exc['price_differential']);
                    final waived = exc['fee_waived'] == true;
                    final timeElapsed = exc['time_elapsed_hours'];
                    final category = exc['reported_issue_category'] ?? 'other';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pertukaran #$idx  •  ${exc['exchange_reference'] ?? 'EXC-${exc['id']}'}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                              ),
                              if (timeElapsed != null)
                                Text(
                                  '+${timeElapsed}j dari awal sewa',
                                  style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.phonelink_erase_rounded, size: 14, color: AppColors.danger),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Lama: ${oldModel['name'] ?? 'Unit Lama'} (${oldAsset['asset_code'] ?? '-'})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.info),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Ganti: ${newModel['name'] ?? 'Unit Baru'} (${newAsset['asset_code'] ?? '-'})',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.obsidian),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Keluhan: "${exc['customer_complaint'] ?? category}"',
                            style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                          ),
                          const Divider(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                waived
                                    ? 'Selisih: Bebas Biaya (Waived)'
                                    : (diff > 0 ? 'Selisih: +${CurrencyFormatter.format(diff)}' : 'Selisih: Setara (Rp 0)'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: waived ? AppColors.warning : (diff > 0 ? AppColors.success : AppColors.info),
                                ),
                              ),
                              Text(
                                'Staff: ${exc['handler']?['name'] ?? 'Staff'}',
                                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                              ),
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
          ],

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
                if (exchanges.isNotEmpty) ...[
                  ...exchanges.map((exc) {
                    final oldAsset = (exc['old_asset'] as Map? ?? exc['oldAsset'] as Map? ?? {}).cast<String, dynamic>();
                    final newAsset = (exc['new_asset'] as Map? ?? exc['newAsset'] as Map? ?? {}).cast<String, dynamic>();
                    final oldModel = (oldAsset['model'] as Map?)?['name'] ?? 'Unit Lama';
                    final newModel = (newAsset['model'] as Map?)?['name'] ?? 'Unit Baru';
                    final diff = CurrencyFormatter.parse(exc['price_differential']);
                    final waived = exc['fee_waived'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: _buildPriceRow(
                        waived ? 'Tukar: $oldModel ➔ $newModel (Waived)' : 'Tukar: $oldModel ➔ $newModel',
                        waived ? 0.0 : diff,
                      ),
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
                    final pMethod = (p['payment_method'] is Map ? p['payment_method']['name'] : p['payment_method']) ?? 'Tunai';
                    final pDate = p['transacted_at'] ?? p['created_at'] ?? '';
                    final pCashier = (p['processor'] is Map ? p['processor']['name'] : (p['processed_by'] is Map ? p['processed_by']['name'] : p['processed_by'])) ?? 'Kasir';
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
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$pMethod • $pTypeLabel', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12), overflow: TextOverflow.ellipsis),
                                Text('$pDate • Oleh: $pCashier', style: const TextStyle(fontSize: 10, color: AppColors.textMuted), overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(CurrencyFormatter.format(pAmt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                              if (p['status'] != 'void') ...[
                                const SizedBox(width: 4),
                                IconButton(
                                  icon: const Icon(Icons.cancel_outlined, size: 16, color: AppColors.danger),
                                  tooltip: 'Batalkan Pembayaran (Void)',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showVoidDialog(context, ref, p, b['id'] ?? b['booking_id']),
                                ),
                              ],
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
                      onPaymentRequested?.call(b);
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
      final printerSettings = ref.read(printerProvider).settings;
      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: branchName,
        receiptNumber: receiptNum,
        bookingCode: b['booking_code']?.toString(),
        customerName: b['customer']?['name']?.toString() ?? '-',
        cashierName: cashierName,
        totalAmount: totalAmt,
        paymentMethod: method,
        transactedAt: receiptData['transacted_at']?.toString() ?? DateTime.now().toString().substring(0, 16),
      );
      final escposBytes = printerService.buildPosPaymentSlipBytes(model, printerSettings);

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

  void _showVoidDialog(BuildContext context, WidgetRef ref, Map p, dynamic bookingId) {
    showDialog(
      context: context,
      builder: (dialogCtx) => _VoidTransactionDialog(
        payment: p,
        bookingId: bookingId,
      ),
    );
  }
}

class _VoidTransactionDialog extends ConsumerStatefulWidget {
  final Map payment;
  final dynamic bookingId;

  const _VoidTransactionDialog({
    required this.payment,
    required this.bookingId,
  });

  @override
  ConsumerState<_VoidTransactionDialog> createState() => _VoidTransactionDialogState();
}

class _VoidTransactionDialogState extends ConsumerState<_VoidTransactionDialog> {
  final _reasonController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isSubmitting = false;
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  String? _pinError;
  Timer? _countdownTimer;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _reasonController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _startLockoutTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_lockoutUntil == null || DateTime.now().isAfter(_lockoutUntil!)) {
        t.cancel();
        setState(() {
          _lockoutUntil = null;
          _failedAttempts = 0;
          _pinError = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<void> _handleVoidSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final p = widget.payment;
    final pCode = p['transaction_code'] ?? p['receipt_number'] ?? 'TX-${p['id']}';

    try {
      final repo = ref.read(cashierRepositoryProvider);
      await repo.voidTransaction(
        transactionId: p['id'],
        reason: _reasonController.text.trim(),
        managerPin: _pinController.text.trim().isNotEmpty ? _pinController.text.trim() : null,
      );

      _countdownTimer?.cancel();
      if (!mounted) return;

      Navigator.pop(context);
      ref.invalidate(bookingDetailProvider(widget.bookingId));
      ref.invalidate(closingSummaryProvider);
      ref.invalidate(cashierExpensesProvider);
      ref.invalidate(currentShiftProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaksi $pCode berhasil dibatalkan (void).'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      final errStr = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      final isPinError = errStr.toLowerCase().contains('pin') ||
          errStr.toLowerCase().contains('otorisasi') ||
          errStr.toLowerCase().contains('unauthorized') ||
          errStr.contains('403');

      if (isPinError) {
        _failedAttempts++;
        if (_failedAttempts >= 3) {
          _lockoutUntil = DateTime.now().add(const Duration(seconds: 30));
          _pinError = 'Terlalu banyak percobaan PIN salah. Terkunci 30 detik.';
          _startLockoutTimer();
        } else {
          _pinError = 'PIN Manager salah ($_failedAttempts/3 percobaan).';
        }
      }

      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membatalkan transaksi: $errStr'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.payment;
    final pCode = p['transaction_code'] ?? p['receipt_number'] ?? 'TX-${p['id']}';
    final pAmt = CurrencyFormatter.parse(p['amount']);
    final isLockedOut = _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
    final remainingSeconds = isLockedOut ? _lockoutUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
          ),
          const SizedBox(width: 10),
          const Text('Batalkan Transaksi (Void)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(pCode, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        Text(CurrencyFormatter.format(pAmt), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Metode: ${(p['payment_method'] is Map ? p['payment_method']['name'] : p['payment_method']) ?? 'Tunai'} • Tipe: ${p['type_label'] ?? p['type'] ?? 'Bayar'}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('Alasan Pembatalan *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Salah input nominal, duplikasi, dsb.',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Alasan wajib diisi minimal 5 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text('PIN Manager Cabang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Text(
                'Diperlukan jika Anda bukan Owner/Admin bisnis.',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _pinController,
                obscureText: true,
                enabled: !isLockedOut,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: InputDecoration(
                  hintText: isLockedOut ? 'Terkunci sementara' : '6 digit PIN Manager',
                  hintStyle: const TextStyle(fontSize: 12),
                  counterText: '',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              if (isLockedOut) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_clock_rounded, color: AppColors.danger, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Akses PIN dikunci sementara: $remainingSeconds detik tersisa.',
                          style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_pinError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _pinError!,
                  style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () {
            _countdownTimer?.cancel();
            Navigator.pop(context);
          },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: (_isSubmitting || isLockedOut) ? null : _handleVoidSubmit,
          child: _isSubmitting
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(
                  isLockedOut ? 'Terkunci ($remainingSeconds s)' : 'Void Transaksi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

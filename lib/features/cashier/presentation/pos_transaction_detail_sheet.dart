import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/collateral_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/business_provider.dart';
import '../../bookings/presentation/exchange_history_sheet.dart';
import '../../bookings/presentation/exchange_wizard_screen.dart';
import '../../bookings/presentation/rental_queue_actions.dart';
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
        color: Color(0xFFFFFFFF),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Rincian Transaksi',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Body
          Expanded(
            child: detailAsync.when(
              loading: () => booking.isEmpty
                  ? const DetailViewSkeleton()
                  : _buildContent(context, ref, booking, isLoadingDeep: true),
              error: (_, _) => _buildContent(context, ref, booking),
              data: (deepData) => _buildContent(
                context,
                ref,
                deepData.isNotEmpty ? deepData : booking,
              ),
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
    final returnInspection =
        b['return_inspection'] as Map? ?? b['returnInspection'] as Map? ?? {};

    final bookingCode = b['booking_code'] ?? '-';
    final status = (b['status'] ?? 'rented').toString().toLowerCase();
    final paymentStatus = (b['payment_status'] ?? 'paid')
        .toString()
        .toLowerCase();
    final isPaid = paymentStatus == 'paid';

    final totalBill = CurrencyFormatter.parse(b['total_bill']);
    final subtotal = CurrencyFormatter.parse(b['subtotal_amount']);
    final discount = CurrencyFormatter.parse(b['discount_amount']);

    double totalPaid = 0.0;
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pType = p['type']?.toString().toLowerCase();
      if (pType == 'settlement' ||
          pType == 'dp' ||
          pType == 'extension' ||
          pType == 'rental' ||
          pType == 'exchange') {
        totalPaid += CurrencyFormatter.parse(p['amount']);
      } else if (pType == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    if (totalPaid == 0 && isPaid) {
      totalPaid = totalBill;
    }
    final remainingRentalDue = (totalBill - totalPaid).clamp(
      0.0,
      double.infinity,
    );
    final totalPenaltyDue = CurrencyFormatter.parse(
      returnInspection['total_penalty'] ??
          returnInspection['late_fee'] ??
          returnInspection['penalty_amount'] ??
          b['total_penalty'] ??
          b['penalty_amount'] ??
          b['late_fee'] ??
          0,
    );
    final remainingPenaltyDue = (totalPenaltyDue - penaltyPaid).clamp(
      0.0,
      double.infinity,
    );
    final remainingDue = remainingRentalDue + remainingPenaltyDue;

    final lateMinutes =
        int.tryParse(returnInspection['late_minutes']?.toString() ?? '0') ?? 0;
    final lateFee = CurrencyFormatter.parse(returnInspection['late_fee']);
    final billableHours = lateMinutes > 60
        ? ((lateMinutes - 60) / 60.0).ceil()
        : 0;
    final hourlyRate = billableHours > 0 && lateFee > 0
        ? (lateFee / billableHours)
        : 15000.0;
    final overdueDurationText = lateMinutes >= 60
        ? '${lateMinutes ~/ 60} Jam ${lateMinutes % 60} Menit ($lateMinutes Menit)'
        : '$lateMinutes Menit';
    final penaltyPaymentStatusText = lateFee > 0
        ? (remainingPenaltyDue <= 0
              ? 'Lunas (Terbayar)'
              : (penaltyPaid > 0
                    ? 'Sebagian (Sisa ${CurrencyFormatter.format(remainingPenaltyDue)})'
                    : 'Belum Dibayar'))
        : 'Bebas Denda';

    final isCentral = affiliate['is_central'] == true;
    final rawBranchName =
        (affiliate['name']?.toString() ?? (isCentral ? 'Pusat' : 'Cabang'))
            .trim();
    final formattedBranch = _formatTitleCase(rawBranchName);
    final branchLower = formattedBranch.toLowerCase();
    final branchMetaLabel =
        branchLower.startsWith('cabang') || branchLower.startsWith('pusat')
        ? formattedBranch
        : '${isCentral ? 'Pusat' : 'Cabang'} $formattedBranch';

    final isAwaitingHandover = status == 'booked' ||
        status == 'reserved' ||
        status == 'confirmed' ||
        status == 'waiting_handover' ||
        status == 'late_pickup';
    final startAt = DateFormatter.parseLocal(b['start_at']);
    final graceDeadline = DateFormatter.parseLocal(
          b['grace_extended_until'] ?? b['grace_expires_at'],
        ) ??
        startAt?.add(const Duration(minutes: 60));
    final nowLocal = DateTime.now();
    final isOverduePickup = isAwaitingHandover &&
        (status == 'late_pickup' ||
            b['is_late_pickup'] == true ||
            b['is_overdue_pickup'] == true ||
            (graceDeadline != null && graceDeadline.isBefore(nowLocal)));
    final latePickupMinutes = (isOverduePickup && graceDeadline != null)
        ? nowLocal.difference(graceDeadline).inMinutes.clamp(1, 99999)
        : 0;
    final latePickupLabel = latePickupMinutes >= 60
        ? 'Terlambat Ambil (+${latePickupMinutes ~/ 60}j ${latePickupMinutes % 60}m)'
        : (latePickupMinutes > 0
            ? 'Terlambat Ambil (+${latePickupMinutes}m)'
            : 'Terlambat Ambil');

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (isLoadingDeep) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],

                // 1. Open Transaction Code, Status Pills & Clean Branch Metadata
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        bookingCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 17,
                          fontFamily: 'monospace',
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(
                        Icons.copy_rounded,
                        size: 16,
                        color: Color(0xFF64748B),
                      ),
                      tooltip: 'Salin Kode Booking',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: bookingCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Kode booking disalin ke clipboard'),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _buildStatusChip(paymentStatus, status),
                    if (isOverduePickup ||
                        status == 'no_show' ||
                        status == 'expired')
                      Container(
                        key: const Key('detail_late_pickup_badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (status == 'no_show' ||
                                  status == 'expired' ||
                                  latePickupMinutes >= 60)
                              ? const Color(0xFFFEF2F2)
                              : const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.schedule_outlined,
                              size: 13,
                              color: (status == 'no_show' ||
                                      status == 'expired' ||
                                      latePickupMinutes >= 60)
                                  ? const Color(0xFFDC2626)
                                  : const Color(0xFFB45309),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status == 'no_show'
                                  ? 'NO-SHOW'
                                  : (status == 'expired'
                                      ? 'KEDALUWARSA'
                                      : latePickupLabel),
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: (status == 'no_show' ||
                                        status == 'expired' ||
                                        latePickupMinutes >= 60)
                                    ? const Color(0xFFDC2626)
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.storefront_outlined,
                      size: 15,
                      color: Color(0xFF64748B),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        branchMetaLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const Divider(
                  height: 28,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),

                // 2. Customer & Staff Info (Clean borderless key-value rows)
                const Text(
                  'PIHAK TERKAIT',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                _buildDetailKvRow(
                  'Pelanggan',
                  customer['name']?.toString() ?? 'Pelanggan Walk-In',
                ),
                if (customer['phone'] != null) ...[
                  const SizedBox(height: 6),
                  _buildDetailKvRow('Telepon', customer['phone'].toString()),
                ],
                if (ref.watch(businessProvider).isCollateralEnabled ||
                    hasCollateralRecord(b)) ...[
                  const SizedBox(height: 6),
                  _buildDetailKvRow(
                    'Jaminan',
                    formatCollateralSummary(b),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  'Petugas/Kasir: ${creator['name'] ?? 'Kasir'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                  ),
                ),

                const Divider(
                  height: 28,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),

                // 3. Rented Assets & Identifiers (Subtle #F8FAFC strip)
                const Text(
                  'UNIT PERANGKAT DISEWA',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                if (items.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      b['items_summary']?.toString() ?? 'Perangkat Sewa',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
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
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.phone_iphone_rounded,
                                size: 20,
                                color: Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '$modelName $storage $color'.trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (b['status'] == 'rented' &&
                                  item['status'] != 'exchanged')
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 0,
                                    ),
                                    side: const BorderSide(
                                      color: Color(0xFFCBD5E1),
                                    ),
                                    foregroundColor: const Color(0xFF0F172A),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.swap_horiz_rounded,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Tukar Unit',
                                    style: TextStyle(fontSize: 11.5),
                                  ),
                                  onPressed: () async {
                                    Navigator.pop(context);
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ExchangeWizardScreen(booking: b),
                                      ),
                                    );
                                    if (res != null) {
                                      ref.invalidate(bookingsListProvider);
                                    }
                                  },
                                )
                              else if (item['status'] == 'exchanged')
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'DITUKAR',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFB45309),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'SN: $sn',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              Text(
                                'IMEI: $imei',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),

                // 3b. Exchange History Summary & Direct Access
                if (exchanges.isNotEmpty) ...[
                  const Divider(
                    height: 28,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'RIWAYAT PERTUKARAN UNIT',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        icon: const Icon(Icons.open_in_new_rounded, size: 14),
                        label: const Text(
                          'Detail Lengkap',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => ExchangeHistorySheet.show(context, b),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ...exchanges.asMap().entries.map((entry) {
                    final idx = entry.key + 1;
                    final exc = entry.value as Map;
                    final oldAsset =
                        exc['old_asset'] as Map? ??
                        exc['oldAsset'] as Map? ??
                        {};
                    final newAsset =
                        exc['new_asset'] as Map? ??
                        exc['newAsset'] as Map? ??
                        {};
                    final oldModel = oldAsset['model'] as Map? ?? {};
                    final newModel = newAsset['model'] as Map? ?? {};
                    final diff = CurrencyFormatter.parse(
                      exc['price_differential'],
                    );
                    final waived = exc['fee_waived'] == true;
                    final timeElapsed = exc['time_elapsed_hours'];
                    final category = exc['reported_issue_category'] ?? 'other';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pertukaran #$idx  •  ${exc['exchange_reference'] ?? 'EXC-${exc['id']}'}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              if (timeElapsed != null)
                                Text(
                                  '+${timeElapsed}j dari awal sewa',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.phonelink_erase_rounded,
                                size: 14,
                                color: Color(0xFFDC2626),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Lama: ${oldModel['name'] ?? 'Unit Lama'} (${oldAsset['asset_code'] ?? '-'})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF475569),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Color(0xFF0F172A),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Ganti: ${newModel['name'] ?? 'Unit Baru'} (${newAsset['asset_code'] ?? '-'})',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Keluhan: "${exc['customer_complaint'] ?? category}"',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const Divider(height: 14, color: Color(0xFFE2E8F0)),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                waived
                                    ? 'Selisih: Bebas Biaya (Waived)'
                                    : (diff > 0
                                          ? 'Selisih: +${CurrencyFormatter.format(diff)}'
                                          : 'Selisih: Setara (Rp 0)'),
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: waived
                                      ? const Color(0xFFB45309)
                                      : (diff > 0
                                            ? const Color(0xFF047857)
                                            : const Color(0xFF475569)),
                                ),
                              ),
                              Text(
                                'Staff: ${exc['handler']?['name'] ?? 'Staff'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                const Divider(
                  height: 28,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),

                // 4. Rental Timeline (Clean borderless key-value rows)
                const Text(
                  'PERIODE & DURASI RENTAL',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                _buildTimelineRow('Mulai Rental', b['start_at']),
                const SizedBox(height: 8),
                _buildTimelineRow('Jadwal Kembali', b['end_at']),
                if (returnInspection['returned_at'] != null) ...[
                  const SizedBox(height: 8),
                  _buildTimelineRow(
                    'Waktu Pengembalian',
                    returnInspection['returned_at'],
                  ),
                ],
                const SizedBox(height: 8),
                _buildDetailKvRow(
                  'Total Durasi',
                  '${b['duration_hours'] ?? 24} Jam',
                ),

                // 4b. Audit Keterlambatan Pengembalian (Overdue & Late Fee Audit)
                if (returnInspection.isNotEmpty &&
                    (lateMinutes > 0 || lateFee > 0)) ...[
                  const Divider(
                    height: 28,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'AUDIT KETERLAMBATAN & DENDA',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: lateFee > 0
                              ? (remainingPenaltyDue <= 0
                                    ? const Color(0xFFECFDF5)
                                    : const Color(0xFFFFFBEB))
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          lateFee > 0
                              ? (remainingPenaltyDue <= 0
                                    ? 'LUNAS'
                                    : 'BELUM LUNAS')
                              : 'GRACE PERIOD',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: lateFee > 0
                                ? (remainingPenaltyDue <= 0
                                      ? const Color(0xFF047857)
                                      : const Color(0xFFB45309))
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildTimelineRow('Jadwal Kembali', b['end_at']),
                  const SizedBox(height: 8),
                  _buildTimelineRow(
                    'Waktu Pengembalian',
                    returnInspection['returned_at'],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Durasi Keterlambatan',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        overdueDurationText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                          color: lateFee > 0
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailKvRow(
                    'Toleransi Bebas Denda',
                    '60 Menit (Grace Period)',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailKvRow(
                    'Tarif Denda per Jam',
                    '${CurrencyFormatter.format(hourlyRate)} / Jam',
                  ),
                  const SizedBox(height: 8),
                  _buildDetailKvRow(
                    'Jam Keterlambatan Dihitung',
                    '$billableHours Jam Billable',
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Denda Keterlambatan',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(lateFee),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13.5,
                          color: Color(0xFFDC2626),
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Status Pembayaran Denda',
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      Text(
                        penaltyPaymentStatusText,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                          color: remainingPenaltyDue <= 0
                              ? const Color(0xFF047857)
                              : const Color(0xFFB45309),
                        ),
                      ),
                    ],
                  ),
                ],

                const Divider(
                  height: 28,
                  thickness: 1,
                  color: Color(0xFFF1F5F9),
                ),

                // 5. Financial Audit Breakdown
                const Text(
                  'RINCIAN TAGIHAN & PEMBAYARAN',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 10),
                _buildPriceRow('Harga Sewa Pokok', subtotal),
                if (discount > 0) ...[
                  const SizedBox(height: 6),
                  _buildPriceRow(
                    'Diskon / Voucher',
                    -discount,
                    isDiscount: true,
                  ),
                ],
                if (extensions.isNotEmpty) ...[
                  ...extensions.map((ext) {
                    final addHours = ext['additional_hours'] ?? 0;
                    final addFee = CurrencyFormatter.parse(
                      ext['additional_fee'],
                    );
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPriceRow(
                        'Perpanjangan ($addHours Jam)',
                        addFee,
                      ),
                    );
                  }),
                ],
                if (exchanges.isNotEmpty) ...[
                  ...exchanges.map((exc) {
                    final oldAsset =
                        (exc['old_asset'] as Map? ??
                                exc['oldAsset'] as Map? ??
                                {})
                            .cast<String, dynamic>();
                    final newAsset =
                        (exc['new_asset'] as Map? ??
                                exc['newAsset'] as Map? ??
                                {})
                            .cast<String, dynamic>();
                    final oldModel =
                        (oldAsset['model'] as Map?)?['name'] ?? 'Unit Lama';
                    final newModel =
                        (newAsset['model'] as Map?)?['name'] ?? 'Unit Baru';
                    final diff = CurrencyFormatter.parse(
                      exc['price_differential'],
                    );
                    final waived = exc['fee_waived'] == true;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPriceRow(
                        waived
                            ? 'Tukar: $oldModel ➔ $newModel (Waived)'
                            : 'Tukar: $oldModel ➔ $newModel',
                        waived ? 0.0 : diff,
                      ),
                    );
                  }),
                ],
                if (returnInspection.isNotEmpty) ...[
                  if (CurrencyFormatter.parse(returnInspection['late_fee']) > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPriceRow(
                        'Denda Keterlambatan',
                        CurrencyFormatter.parse(returnInspection['late_fee']),
                      ),
                    ),
                  if (CurrencyFormatter.parse(returnInspection['damage_fee']) >
                      0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: _buildPriceRow(
                        'Biaya Kerusakan/Denda',
                        CurrencyFormatter.parse(returnInspection['damage_fee']),
                      ),
                    ),
                ],
                const Divider(height: 20, color: Color(0xFFF1F5F9)),
                _buildPriceRow(
                  'TOTAL TAGIHAN',
                  totalBill + totalPenaltyDue,
                  isBold: true,
                  fontSize: 14.5,
                ),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'Total Terbayar',
                  totalPaid + penaltyPaid,
                  color: const Color(0xFF047857),
                ),
                const SizedBox(height: 6),
                _buildPriceRow(
                  'Sisa Tagihan',
                  remainingDue,
                  isBold: true,
                  color: remainingDue > 0
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF047857),
                  fontSize: 14.5,
                ),

                // 6. Payment Transaction History Logs
                if (payments.isNotEmpty) ...[
                  const Divider(
                    height: 28,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                  ),
                  const Text(
                    'Riwayat Pembayaran',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...payments.map((p) {
                    final pAmt = CurrencyFormatter.parse(p['amount']);
                    final rawMethod =
                        (p['payment_method'] is Map
                            ? p['payment_method']['name']
                            : p['payment_method']) ??
                        'Tunai';
                    final pMethod =
                        rawMethod.toString().toLowerCase().contains('qris')
                        ? 'QRIS'
                        : rawMethod;
                    final rawDate = p['transacted_at'] ?? p['created_at'] ?? '';
                    final pDate = DateFormatter.formatFull(rawDate);
                    final pCashier =
                        (p['processor'] is Map
                            ? p['processor']['name']
                            : (p['processed_by'] is Map
                                  ? p['processed_by']['name']
                                  : p['processed_by'])) ??
                        'Kasir';
                    final pType = p['type']?.toString().toLowerCase();
                    final pTypeLabel =
                        p['type_label'] ??
                        (pType == 'penalty'
                            ? 'Denda Keterlambatan'
                            : (pType == 'extension'
                                  ? 'Perpanjangan'
                                  : 'Sewa Kontrak'));

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$pMethod • $pTypeLabel',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$pDate • Oleh: $pCashier',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF64748B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                CurrencyFormatter.format(pAmt),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: Color(0xFF0F172A),
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                              if (p['status'] != 'void') ...[
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(
                                    Icons.cancel_outlined,
                                    size: 18,
                                    color: Color(0xFFDC2626),
                                  ),
                                  tooltip: 'Batalkan Pembayaran (Void)',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _showVoidDialog(
                                    context,
                                    ref,
                                    p,
                                    b['id'] ?? b['booking_id'],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
        _buildStickyFooter(
          context,
          ref,
          b,
          isAwaitingHandover: isAwaitingHandover,
          isOverduePickup: isOverduePickup,
          remainingDue: remainingDue,
        ),
      ],
    );
  }

  Widget _buildStickyFooter(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> b, {
    required bool isAwaitingHandover,
    required bool isOverduePickup,
    required double remainingDue,
  }) {
    final showOverdueActions = isAwaitingHandover && isOverduePickup;
    final showPayPrimary = !showOverdueActions && remainingDue > 0;

    return SafeArea(
      top: false,
      child: Container(
        color: const Color(0xFFFFFFFF),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showOverdueActions) ...[
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  key: const Key('detail_handover_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: const Color(0xFFFFFFFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    RentalQueueActions.handleHandoverUnit(context, ref, b);
                  },
                  child: const Text(
                    'Serahkan Unit',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        key: const Key('detail_extend_pickup_button'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFFFF),
                          foregroundColor: const Color(0xFF0F172A),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          await RentalQueueActions.extendPickupGrace(
                            context,
                            ref,
                            b,
                            additionalMinutes: 30,
                          );
                        },
                        child: const Text(
                          'Perpanjang (+30m)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: OutlinedButton(
                        key: const Key('detail_mark_noshow_button'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: const Color(0xFFFFFFFF),
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: Color(0xFFFECACA)),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          RentalQueueActions.confirmMarkNoShow(
                            context,
                            ref,
                            b,
                            onRefresh: () {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                            },
                          );
                        },
                        child: const Text(
                          'Tandai No-Show',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const Key('reprint_receipt_button'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 16),
                  label: const Text(
                    'Cetak Ulang Struk',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  onPressed: () =>
                      _printBookingReceipt(context, ref, b, isReprint: true),
                ),
              ),
            ] else ...[
              if (showPayPrimary) ...[
                SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: const Color(0xFFFFFFFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                    label: const Text(
                      'Bayar di Kasir',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      onPaymentRequested?.call(b);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              SizedBox(
                height: 40,
                child: OutlinedButton.icon(
                  key: const Key('reprint_receipt_button'),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFFFFF),
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.print_outlined, size: 17),
                  label: const Text(
                    'Cetak Ulang Struk',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                  onPressed: () =>
                      _printBookingReceipt(context, ref, b, isReprint: true),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTitleCase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed != trimmed.toLowerCase()) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  Widget _buildDetailKvRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13.5,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
              color: Color(0xFF0F172A),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusChip(String paymentStatus, String bookingStatus) {
    final isPaid = paymentStatus == 'paid';
    final isPartial = paymentStatus == 'partial';
    final bg = isPaid
        ? const Color(0xFFECFDF5)
        : (isPartial ? const Color(0xFFFFFBEB) : const Color(0xFFFEF2F2));
    final fg = isPaid
        ? const Color(0xFF047857)
        : (isPartial ? const Color(0xFFB45309) : const Color(0xFFDC2626));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isPaid ? 'Lunas' : (isPartial ? 'Sebagian' : 'Belum Lunas'),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 11.5,
        ),
      ),
    );
  }

  Widget _buildTimelineRow(String label, dynamic value) {
    final parsed = DateFormatter.parseLocal(value);
    final strVal = parsed != null
        ? DateFormatter.formatFull(parsed)
        : (value?.toString() ?? '-');
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          strVal,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
            color: Color(0xFF0F172A),
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceRow(
    String label,
    double amount, {
    bool isBold = false,
    bool isDiscount = false,
    Color? color,
    double fontSize = 13.5,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: color ??
                  (isBold ? const Color(0xFF0F172A) : const Color(0xFF475569)),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          (isDiscount ? '- ' : '') + CurrencyFormatter.format(amount.abs()),
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isDiscount
                ? const Color(0xFFDC2626)
                : (color ?? const Color(0xFF0F172A)),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  void _printBookingReceipt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> b, {
    bool isReprint = true,
  }) async {
    try {
      final repo = ref.read(cashierRepositoryProvider);
      final payments = (b['payments'] as List?) ?? [];
      final latestTx = payments.isNotEmpty ? payments.last : null;
      final receiptId =
          latestTx?['receipt_number'] ?? latestTx?['id'] ?? b['id'];

      final receiptData = await repo.fetchReceipt(receiptId);
      if (!context.mounted) return;

      final bizState = ref.read(businessProvider);
      final printerSettings = ref.read(printerProvider).settings;
      final document = ReceiptDocumentData.fromTransaction(
        business: bizState,
        booking: b,
        receiptData: receiptData,
        settings: printerSettings,
        title: 'STRUK TRANSAKSI POS',
        isReprint: isReprint,
      );

      showDialog(
        context: context,
        builder: (ctx) => ThermalReceiptPreviewDialog.fromDocument(
          title: isReprint ? 'Cetak Ulang Struk POS' : 'Struk Transaksi POS',
          document: document,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mencetak struk: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showVoidDialog(
    BuildContext context,
    WidgetRef ref,
    Map p,
    dynamic bookingId,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) =>
          _VoidTransactionDialog(payment: p, bookingId: bookingId),
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
  ConsumerState<_VoidTransactionDialog> createState() =>
      _VoidTransactionDialogState();
}

class _VoidTransactionDialogState
    extends ConsumerState<_VoidTransactionDialog> {
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
    final pCode =
        p['transaction_code'] ?? p['receipt_number'] ?? 'TX-${p['id']}';

    try {
      final repo = ref.read(cashierRepositoryProvider);
      await repo.voidTransaction(
        transactionId: p['id'],
        reason: _reasonController.text.trim(),
        managerPin: _pinController.text.trim().isNotEmpty
            ? _pinController.text.trim()
            : null,
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
      final isPinError =
          errStr.toLowerCase().contains('pin') ||
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
    final pCode =
        p['transaction_code'] ?? p['receipt_number'] ?? 'TX-${p['id']}';
    final pAmt = CurrencyFormatter.parse(p['amount']);
    final isLockedOut =
        _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);
    final remainingSeconds = isLockedOut
        ? _lockoutUntil!.difference(DateTime.now()).inSeconds + 1
        : 0;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.dangerLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.danger,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          const Text(
            'Batalkan Transaksi (Void)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
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
                        Text(
                          pCode,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(pAmt),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Metode: ${(() { final raw = (p['payment_method'] is Map ? p['payment_method']['name'] : p['payment_method']) ?? 'Tunai'; return raw.toString().toLowerCase().contains('qris') ? 'QRIS' : raw; })()} • Tipe: ${p['type_label'] ?? p['type'] ?? 'Bayar'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Alasan Pembatalan *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Salah input nominal, duplikasi, dsb.',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 5) {
                    return 'Alasan wajib diisi minimal 5 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'PIN Manager Cabang',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
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
                  hintText: isLockedOut
                      ? 'Terkunci sementara'
                      : '6 digit PIN Manager',
                  hintStyle: const TextStyle(fontSize: 12),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
              if (isLockedOut) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        color: AppColors.danger,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Akses PIN dikunci sementara: $remainingSeconds detik tersisa.',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (_pinError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _pinError!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  _countdownTimer?.cancel();
                  Navigator.pop(context);
                },
          child: const Text('Batal'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: (_isSubmitting || isLockedOut) ? null : _handleVoidSubmit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isLockedOut
                      ? 'Terkunci ($remainingSeconds s)'
                      : 'Void Transaksi',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}

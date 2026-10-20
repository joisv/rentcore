import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/thermal_printer_models.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../printer/providers/printer_provider.dart';

class ExchangeHistorySheet extends ConsumerWidget {
  final Map<String, dynamic> booking;

  const ExchangeHistorySheet({
    super.key,
    required this.booking,
  });

  static Future<void> show(BuildContext context, Map<String, dynamic> booking) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExchangeHistorySheet(booking: booking),
    );
  }

  static const Map<String, String> _categoryLabels = {
    'camera': 'Kamera / Lensa',
    'screen': 'Layar / Sentuh',
    'battery': 'Baterai / Power',
    'network': 'Sinyal / Wi-Fi',
    'audio': 'Speaker / Mic',
    'system': 'Sistem / OS',
    'other': 'Lainnya',
  };

  static const Map<String, IconData> _categoryIcons = {
    'camera': Icons.camera_alt_outlined,
    'screen': Icons.screen_lock_portrait_outlined,
    'battery': Icons.battery_alert_outlined,
    'network': Icons.signal_cellular_alt_rounded,
    'audio': Icons.volume_up_outlined,
    'system': Icons.settings_system_daydream_outlined,
    'other': Icons.build_circle_outlined,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rawExchanges = (booking['exchanges'] as List?) ?? [];
    final exchanges = rawExchanges.map((e) => (e as Map).cast<String, dynamic>()).toList();
    final customer = (booking['customer'] as Map?) ?? {};
    final bookingCode = booking['booking_code'] ?? '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.infoLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.history_rounded, color: AppColors.info, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Riwayat Pertukaran Unit',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.obsidian,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$bookingCode • ${customer['name'] ?? 'Pelanggan'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.borderSubtle),

              // Content Area
              Expanded(
                child: exchanges.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(20),
                        itemCount: exchanges.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          // Display in chronological or reverse order with clear sequence
                          final exc = exchanges[index];
                          final exchangeIndex = index + 1;
                          return _buildExchangeCard(context, ref, exc, exchangeIndex);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.phonelink_erase_rounded, size: 40, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const Text(
              'Belum Ada Riwayat Pertukaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sewa ini masih menggunakan unit asli pertama dan belum pernah mengalami pergantian perangkat akibat kendala teknis.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExchangeCard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> exc,
    int index,
  ) {
    final oldAsset = (exc['old_asset'] as Map? ?? exc['oldAsset'] as Map? ?? {}).cast<String, dynamic>();
    final newAsset = (exc['new_asset'] as Map? ?? exc['newAsset'] as Map? ?? {}).cast<String, dynamic>();
    final oldModel = (oldAsset['model'] as Map? ?? {}).cast<String, dynamic>();
    final newModel = (newAsset['model'] as Map? ?? {}).cast<String, dynamic>();

    final handler = (exc['handler'] as Map? ?? {}).cast<String, dynamic>();
    final manager = (exc['manager'] as Map? ?? {}).cast<String, dynamic>();
    final payment = (exc['payment'] as Map? ?? {}).cast<String, dynamic>();
    final paymentMethod = payment['payment_method'] is Map
        ? payment['payment_method']['name']
        : (payment['payment_method'] ?? 'Tunai');

    final exchangedAt = exc['exchanged_at'] ?? exc['created_at'];
    final timeElapsedHours = exc['time_elapsed_hours'];
    final category = exc['reported_issue_category'] ?? 'other';
    final categoryLabel = _categoryLabels[category] ?? category;
    final categoryIcon = _categoryIcons[category] ?? Icons.build_circle_outlined;

    final priceDiff = CurrencyFormatter.parse(exc['price_differential']);
    final feeWaived = exc['fee_waived'] == true;
    final refCode = exc['exchange_reference'] ?? 'EXC-${exc['id']}';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Card: Sequence, Date, Reference
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Pertukaran #$index',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      refCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                Text(
                  DateFormatter.formatFull(exchangedAt),
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Elapsed time badge if available
                if (timeElapsedHours != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                      const SizedBox(width: 6),
                      Text(
                        'Dilakukan $timeElapsedHours jam setelah sewa berlangsung',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // 1. Old Unit (Defective / Replaced)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.danger.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'UNIT LAMA (BERMASALAH)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Kondisi: Grade ${exc['old_unit_condition_grade'] ?? oldAsset['condition_grade'] ?? '-'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.danger),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        oldModel['name'] ?? 'Perangkat Lama',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode: ${oldAsset['asset_code'] ?? '-'}  •  SN: ${oldAsset['serial_number'] ?? '-'}  •  IMEI: ${oldAsset['imei_1'] ?? '-'}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1, color: AppColors.borderSubtle),
                      const SizedBox(height: 10),

                      // Issue category & complaint
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(categoryIcon, size: 16, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Keluhan: $categoryLabel',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '"${exc['customer_complaint'] ?? 'Keluhan teknis pada unit.'}"',
                                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                                ),
                                if (exc['staff_diagnosis'] != null && exc['staff_diagnosis'].toString().trim().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Diagnosa Staff: ${exc['staff_diagnosis']}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // iCloud verification & disposition tag
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded, size: 14, color: AppColors.success),
                              SizedBox(width: 4),
                              Text(
                                'iCloud Sign Out Terverifikasi',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Disposisi: ${exc['old_asset_disposition'] ?? 'maintenance'}',
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Replacement Direction Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.info),
                            SizedBox(width: 4),
                            Text(
                              'Digantikan Oleh Unit Baru',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.info),
                            ),
                          ],
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.borderSubtle)),
                    ],
                  ),
                ),

                // 2. New Replacement Unit (Active)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.successLight.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.2)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'UNIT BARU (PENGGANTI AKTIF)',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Kondisi: Grade ${newAsset['condition_grade'] ?? 'A'}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.success),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        newModel['name'] ?? 'Perangkat Pengganti',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode: ${newAsset['asset_code'] ?? '-'}  •  SN: ${newAsset['serial_number'] ?? '-'}  •  IMEI: ${newAsset['imei_1'] ?? '-'}',
                        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 3. Financial & Staff Audit Summary
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Penyesuaian Biaya:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                          if (feeWaived)
                            const StatusBadge(
                              label: 'BEBAS BIAYA (WAIVED)',
                              textColor: AppColors.warning,
                              backgroundColor: AppColors.warningLight,
                              borderRadius: 6,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            )
                          else if (priceDiff > 0)
                            Text(
                              '+ ${CurrencyFormatter.format(priceDiff)}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.success),
                            )
                          else
                            const StatusBadge(
                              label: 'SETARA (RP 0)',
                              textColor: AppColors.info,
                              backgroundColor: AppColors.infoLight,
                              borderRadius: 6,
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            ),
                        ],
                      ),
                      if (feeWaived && exc['waiver_reason'] != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Text('Alasan:', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                exc['waiver_reason'].toString(),
                                style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!feeWaived && priceDiff > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Metode Pembayaran:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text(paymentMethod.toString(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                      const Divider(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ditangani: ${handler['name'] ?? 'Staff'}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          if (manager['name'] != null)
                            Text(
                              'Disetujui: ${manager['name']}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.obsidian),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 4. Action: Reprint / Preview Exchange Slip
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(36),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.receipt_long_rounded, size: 16),
                  label: const Text('Cetak Bukti Pertukaran Unit', style: TextStyle(fontSize: 11)),
                  onPressed: () => _printExchangeReceipt(context, ref, exc),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _printExchangeReceipt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> exc,
  ) {
    final customer = (booking['customer'] as Map?) ?? {};
    final affiliate = (booking['affiliate'] as Map?) ?? {};
    final oldAsset = (exc['old_asset'] as Map? ?? exc['oldAsset'] as Map? ?? {}).cast<String, dynamic>();
    final newAsset = (exc['new_asset'] as Map? ?? exc['newAsset'] as Map? ?? {}).cast<String, dynamic>();
    final oldModel = (oldAsset['model'] as Map? ?? {}).cast<String, dynamic>();
    final newModel = (newAsset['model'] as Map? ?? {}).cast<String, dynamic>();
    final handler = (exc['handler'] as Map? ?? {}).cast<String, dynamic>();
    final payment = (exc['payment'] as Map? ?? {}).cast<String, dynamic>();

    final printerState = ref.read(printerProvider);
    final printerService = ThermalPrinterService();
    final settings = printerState.settings;

    final diff = CurrencyFormatter.parse(exc['price_differential']);
    final feeWaived = exc['fee_waived'] == true;
    final paymentMethodName = feeWaived
        ? 'Bebas Biaya (Disetujui)'
        : (diff > 0
            ? (payment['payment_method'] is Map ? payment['payment_method']['name'] : (payment['payment_method'] ?? 'Tunai'))
            : 'Tanpa Biaya (Setara)');

    final doc = ReceiptDataModel(
      type: ReceiptType.rentalExchange,
      title: 'BUKTI PENGGANTIAN UNIT',
      branchName: affiliate['name'] ?? 'RentCore Store',
      receiptNumber: exc['exchange_reference'] ?? 'EXC-${exc['id']}',
      bookingCode: booking['booking_code'],
      customerName: customer['name'] ?? 'Pelanggan',
      customerPhone: customer['phone'] ?? '-',
      cashierName: handler['name'] ?? 'Staff',
      oldUnitName: oldModel['name'] ?? 'Unit Lama',
      oldUnitSerial: oldAsset['serial_number'] ?? oldAsset['asset_code'] ?? '-',
      exchangeReason: exc['customer_complaint'] ?? _categoryLabels[exc['reported_issue_category']] ?? 'Kendala Teknis',
      unitName: newModel['name'] ?? 'Unit Pengganti',
      unitSerial: newAsset['serial_number'] ?? newAsset['asset_code'] ?? '-',
      rentalEndDate: booking['end_at'],
      priceDifferential: feeWaived ? 0.0 : diff,
      totalAmount: feeWaived ? 0.0 : diff,
      paymentMethod: paymentMethodName.toString(),
      cashReceived: payment['cash_received'] != null ? CurrencyFormatter.parse(payment['cash_received']) : null,
      cashChange: payment['cash_change'] != null ? CurrencyFormatter.parse(payment['cash_change']) : null,
    );

    final escposBytes = printerService.buildPosPaymentSlipBytes(doc, settings);

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Bukti Penggantian Unit',
        branchName: doc.branchName,
        escposBytes: escposBytes,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('No: ${doc.receiptNumber}', style: const TextStyle(fontSize: 11)),
            Text('Booking: ${doc.bookingCode}', style: const TextStyle(fontSize: 11)),
            Text('Pelanggan: ${doc.customerName}', style: const TextStyle(fontSize: 11)),
            const Divider(height: 16),
            const Text('UNIT LAMA (DIKEMBALIKAN):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text('${doc.oldUnitName}', style: const TextStyle(fontSize: 12)),
            Text('SN: ${doc.oldUnitSerial}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            Text('Kendala: ${doc.exchangeReason}', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            const Text('UNIT BARU (PENGGANTI):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            Text('${doc.unitName}', style: const TextStyle(fontSize: 12)),
            Text('SN: ${doc.unitSerial}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selisih Biaya', style: TextStyle(fontSize: 12)),
                Text(
                  doc.priceDifferential != null && doc.priceDifferential! > 0
                      ? CurrencyFormatter.format(doc.priceDifferential)
                      : 'Rp 0',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Metode:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text('${doc.paymentMethod}', style: const TextStyle(fontSize: 11)),
              ],
            ),
            const Divider(height: 16),
            Text('Petugas: ${doc.cashierName}', style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ),
    );
  }
}

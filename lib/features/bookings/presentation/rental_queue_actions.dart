import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../cashier/presentation/pos_transaction_detail_sheet.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/booking_provider.dart';
import 'exchange_wizard_screen.dart';
import 'return_wizard_screen.dart';

class _AdjustmentTarget {
  final int? itemId;
  final String label;
  final String shortName;
  final bool isPrimary;
  final int currentDurationHours;
  final double currentPrice;
  final Map<String, dynamic>? model;

  const _AdjustmentTarget({
    this.itemId,
    required this.label,
    required this.shortName,
    required this.isPrimary,
    required this.currentDurationHours,
    required this.currentPrice,
    this.model,
  });
}

class _DurationOption {
  final int? rateId;
  final int hours;
  final double price;
  final String label;

  const _DurationOption({
    this.rateId,
    required this.hours,
    required this.price,
    required this.label,
  });
}

List<_DurationOption> _getDurationOptionsForTarget(
  Map<String, dynamic>? model,
) {
  final rawTiers =
      (model?['pricing_tiers'] as List?) ??
      (model?['pricingTiers'] as List?) ??
      [];
  final options = <_DurationOption>[];

  for (final t in rawTiers) {
    if (t is Map) {
      final rateId = (t['id'] is num)
          ? (t['id'] as num).toInt()
          : int.tryParse(t['id']?.toString() ?? '');
      final hours = int.tryParse(t['duration_hours']?.toString() ?? '0') ?? 0;
      final price = (t['price'] is num)
          ? (t['price'] as num).toDouble()
          : (double.tryParse(t['price']?.toString() ?? '0') ?? 0.0);
      final isActive = t['is_active'] != false;
      if (hours > 0 && isActive) {
        final val =
            int.tryParse(t['duration_value']?.toString() ?? '') ?? hours;
        final unit = (t['duration_unit']?.toString() ?? 'hour').toLowerCase();
        String lbl;
        if (unit == 'day') {
          lbl = '$val Hari ($hours Jam)';
        } else if (unit == 'week') {
          lbl = '$val Minggu ($hours Jam)';
        } else {
          lbl = '$hours Jam';
        }
        options.add(
          _DurationOption(
            rateId: rateId,
            hours: hours,
            price: price,
            label: lbl,
          ),
        );
      }
    }
  }

  options.sort((a, b) => a.hours.compareTo(b.hours));

  // Fallback if no specific pricing tiers configured
  if (options.isEmpty) {
    final hourlyRate = ((model?['tier']?['hourly_rate'] ?? 15000) as num)
        .toDouble();
    for (final h in [6, 12, 24]) {
      options.add(
        _DurationOption(hours: h, price: h * hourlyRate, label: '$h Jam'),
      );
    }
  }

  return options;
}

/// Shared rental queue actions used by Beranda (Dashboard) and Bookings views.
class RentalQueueActions {
  RentalQueueActions._();

  static const List<({List<String> keywords, IconData icon})>
  _categoryIconRules = [
    (
      keywords: [
        'tenda',
        'camp',
        'outdoor',
        'gunung',
        'carrier',
        'sleeping bag',
        'matras',
        'flysheet',
      ],
      icon: Icons.cabin_rounded,
    ),
    (
      keywords: [
        'kamera',
        'camera',
        'dslr',
        'mirrorless',
        'lensa',
        'lens',
        'sony a',
        'canon',
        'fujifilm',
      ],
      icon: Icons.camera_alt_rounded,
    ),
    (
      keywords: ['laptop', 'macbook', 'notebook', 'komputer', 'pc'],
      icon: Icons.laptop_mac_rounded,
    ),
    (
      keywords: ['proyektor', 'projector', 'infocus'],
      icon: Icons.videocam_rounded,
    ),
    (
      keywords: [
        'game',
        'konsol',
        'playstation',
        'ps4',
        'ps5',
        'nintendo',
        'xbox',
      ],
      icon: Icons.sports_esports_rounded,
    ),
    (
      keywords: ['tablet', 'ipad', 'tab'],
      icon: Icons.tablet_mac_rounded,
    ),
    (
      keywords: ['audio', 'speaker', 'sound', 'headphone', 'headset', 'mic'],
      icon: Icons.headphones_rounded,
    ),
    (keywords: ['drone', 'dji'], icon: Icons.flight_takeoff_rounded),
    (
      keywords: ['motor', 'sepeda', 'vehicle', 'mobil'],
      icon: Icons.two_wheeler_rounded,
    ),
    (
      keywords: [
        'phone',
        'iphone',
        'samsung',
        'xiaomi',
        'oppo',
        'vivo',
        'hp',
        'gadget',
        'smartphone',
      ],
      icon: Icons.phone_iphone_rounded,
    ),
    (
      keywords: ['alat', 'gear', 'aksesoris'],
      icon: Icons.inventory_2_outlined,
    ),
  ];

  /// Maps asset category, model name, and asset code to a display icon.
  static IconData getItemCategoryIcon({
    Map<String, dynamic>? model,
    Map<String, dynamic>? asset,
    Map<String, dynamic>? primaryItem,
  }) {
    final rawCat = model?['category'];
    final catName =
        (rawCat is Map ? rawCat['name'] : rawCat)?.toString().toLowerCase() ??
        '';
    final modelName = (model?['name'] ?? primaryItem?['name'] ?? '')
        .toString()
        .toLowerCase();
    final assetCode = (asset?['asset_code'] ?? '').toString().toLowerCase();

    final combined = '$catName $modelName $assetCode';
    for (final rule in _categoryIconRules) {
      if (rule.keywords.any(combined.contains)) {
        return rule.icon;
      }
    }
    return Icons.devices_other_rounded;
  }

  static void _invalidateQueueProviders(WidgetRef ref) {
    ref.invalidate(bookingsListProvider);
    ref.invalidate(dashboardQueueBookingsProvider);
    ref.invalidate(dashboardKpiProvider);
  }

  /// Opens the full transaction detail bottom sheet with payment callback.
  static void openTransactionDetail(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosTransactionDetailSheet(
        booking: booking,
        onPaymentRequested: (activeBooking) => openPosPaymentModal(
          context,
          ref,
          activeBooking,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  /// Opens the POS settlement / penalty payment sheet for a booking.
  static void openPosPaymentModal(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final returnInspection =
        booking['return_inspection'] as Map? ??
        booking['returnInspection'] as Map? ??
        {};
    final totalPenaltyDue = CurrencyFormatter.parse(
      returnInspection['total_penalty'] ??
          returnInspection['late_fee'] ??
          returnInspection['penalty_amount'] ??
          booking['total_penalty'] ??
          booking['penalty_amount'] ??
          booking['late_fee'] ??
          0,
    );
    final payments = (booking['payments'] as List?) ?? [];
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      if (p['type']?.toString().toLowerCase() == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingPenalty = (totalPenaltyDue - penaltyPaid).clamp(
      0.0,
      double.infinity,
    );

    final totalBill = CurrencyFormatter.parse(booking['total_bill']);
    double rentalPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pt = p['type']?.toString().toLowerCase();
      if (pt == 'settlement' ||
          pt == 'dp' ||
          pt == 'extension' ||
          pt == 'rental' ||
          pt == 'exchange') {
        rentalPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingRental = (totalBill - rentalPaid).clamp(
      0.0,
      double.infinity,
    );

    final isPenaltyTarget = remainingRental <= 0 && remainingPenalty > 0;
    final paymentContext = isPenaltyTarget
        ? PaymentContext.penalty(booking: booking, penaltyDue: remainingPenalty)
        : PaymentContext.settlement(
            booking: booking,
            remainingDue: remainingRental > 0
                ? remainingRental
                : (remainingPenalty > 0 ? remainingPenalty : totalBill),
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentPage(
        paymentContext: paymentContext,
        isModal: true,
        onPaymentSuccess: () {
          _invalidateQueueProviders(ref);
          onRefresh?.call();
        },
      ),
    );
  }

  /// Fetches and previews/prints the thermal receipt for a booking.
  static Future<void> printBookingReceipt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking,
  ) async {
    try {
      final payments = (booking['payments'] as List?) ?? [];
      final latestTx = payments.isNotEmpty ? payments.last : null;
      final receiptId =
          latestTx?['receipt_number'] ?? latestTx?['id'] ?? booking['id'];

      final repo = ref.read(cashierRepositoryProvider);
      final receiptData = await repo.fetchReceipt(receiptId);

      if (!context.mounted) return;
      final branchName =
          receiptData['outlet_name'] ??
          booking['affiliate']?['name'] ??
          'RentCore';
      final cashierName = receiptData['cashier_name'] ?? 'Kasir';
      final receiptNum =
          receiptData['receipt_number'] ?? booking['booking_code'] ?? '-';
      final customerName =
          receiptData['customer_name'] ?? booking['customer']?['name'] ?? '-';
      final totalAmt = CurrencyFormatter.parse(
        receiptData['total_amount'] ?? booking['total_bill'],
      );
      final cashRec = CurrencyFormatter.parse(receiptData['cash_received']);
      final cashChg = CurrencyFormatter.parse(receiptData['cash_change']);
      final method = receiptData['payment_method'] ?? 'Tunai';

      final printerService = ThermalPrinterService();
      final printerSettings = ref.read(printerProvider).settings;
      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI SEWA',
        branchName: branchName,
        receiptNumber: receiptNum,
        bookingCode: booking['booking_code']?.toString(),
        customerName: customerName,
        cashierName: cashierName,
        totalAmount: totalAmt,
        paymentMethod: method,
        cashReceived: cashRec,
        cashChange: cashChg,
        transactedAt:
            receiptData['transacted_at']?.toString() ??
            DateTime.now().toString().substring(0, 16),
      );
      final escposBytes = printerService.buildPosPaymentSlipBytes(
        model,
        printerSettings,
      );

      showDialog(
        context: context,
        builder: (ctx) => ThermalReceiptPreviewDialog(
          title: 'Struk Transaksi Sewa',
          branchName: branchName,
          escposBytes: escposBytes,
          content: Column(
            children: [
              const Text(
                'STRUK SEWA CABANG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text('No: $receiptNum', style: const TextStyle(fontSize: 11)),
              Text(
                'Pelanggan: $customerName',
                style: const TextStyle(fontSize: 11),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    CurrencyFormatter.format(totalAmt),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat struk: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Launches the unit exchange wizard for swapping physical units.
  static Future<void> openExchangeWizard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExchangeWizardScreen(booking: booking)),
    );
    if (res != null) {
      _invalidateQueueProviders(ref);
      onRefresh?.call();
    }
  }

  /// Opens the Return Wizard, fetching booking detail first if items are missing.
  static Future<void> openReturnWizard(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) async {
    final items = booking['items'];
    if (items is List && items.isNotEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReturnWizardScreen(booking: booking)),
      );
      _invalidateQueueProviders(ref);
      onRefresh?.call();
      return;
    }

    final rawId = booking['booking_id'] ?? booking['id'];
    final bookingId = rawId is num
        ? rawId.toInt()
        : int.tryParse(rawId?.toString() ?? '') ?? 0;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppColors.obsidian),
      ),
    );

    try {
      final fullBooking = await ref
          .read(bookingRepositoryProvider)
          .fetchBookingDetail(bookingId);
      if (context.mounted) {
        Navigator.pop(context);
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ReturnWizardScreen(booking: fullBooking),
          ),
        );
        _invalidateQueueProviders(ref);
        onRefresh?.call();
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat detail sewa: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  /// Opens the unit handover sheet for awaiting-handover bookings.
  static void handleHandoverUnit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final bookingCode =
        booking['booking_code']?.toString() ?? '#${booking['id'] ?? ''}';
    final customerName =
        booking['customer']?['name']?.toString() ??
        booking['customer_name']?.toString() ??
        'Pelanggan';
    final paymentStatus = (booking['payment_status'] ?? 'paid')
        .toString()
        .toLowerCase();
    final isPaid = paymentStatus == 'paid';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Penyerahan Unit • $bookingCode',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.obsidian,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Penyewa: $customerName • Status bayar: ${isPaid ? 'Lunas' : 'Belum Lunas'}',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (!isPaid) ...[
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.payments_rounded, size: 18),
                  label: const Text(
                    'Bayar & Serahkan Unit',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    openPosPaymentModal(
                      context,
                      ref,
                      booking,
                      onRefresh: onRefresh,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.obsidian,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.print_rounded, size: 18),
                label: const Text(
                  'Cetak Slip Serah Terima',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  printBookingReceipt(context, ref, booking);
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  openTransactionDetail(
                    context,
                    ref,
                    booking,
                    onRefresh: onRefresh,
                  );
                },
                child: const Text(
                  'Lihat Rincian Booking',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.obsidian,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the overflow actions bottom sheet (`[ ⋮ ]`) for a rental queue card.
  static void showOverflowActionsSheet(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final status = (booking['status'] ?? '').toString().toLowerCase();
    final isReturned = status == 'returned' || status == 'completed';
    final bookingCode = booking['booking_code']?.toString() ?? 'Sewa';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Aksi Transaksi • $bookingCode',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.obsidian,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                enabled: !isReturned,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.more_time_rounded,
                    size: 20,
                    color: isReturned
                        ? AppColors.textMuted
                        : AppColors.obsidian,
                  ),
                ),
                title: const Text(
                  'Tambah Jam / Perpanjang',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  isReturned
                      ? 'Tidak tersedia untuk sewa yang sudah selesai'
                      : 'Perpanjang atau sesuaikan durasi sewa unit',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: isReturned
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        showDurationAdjustmentDialog(
                          context,
                          ref,
                          booking,
                          onRefresh: onRefresh,
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
                enabled: !isReturned,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.obsidian.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.swap_horiz_rounded,
                    size: 20,
                    color: isReturned
                        ? AppColors.textMuted
                        : AppColors.obsidian,
                  ),
                ),
                title: const Text(
                  'Ganti Unit Fisik',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  isReturned
                      ? 'Tidak tersedia untuk sewa yang sudah selesai'
                      : 'Tukar unit fisik jika ada kendala perangkat',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: isReturned
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        openExchangeWizard(
                          context,
                          ref,
                          booking,
                          onRefresh: onRefresh,
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
                    Icons.print_rounded,
                    size: 20,
                    color: AppColors.obsidian,
                  ),
                ),
                title: const Text(
                  'Cetak Ulang Struk',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: const Text(
                  'Preview & cetak ulang struk thermal ESC/POS',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  printBookingReceipt(context, ref, booking);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Opens the duration adjustment modal (`+ Tambah Jam` / `- Kurangi Jam`).
  static void showDurationAdjustmentDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item, {
    VoidCallback? onRefresh,
  }) {
    final bookingId = (item['id'] as num).toInt();
    final bookingCode = item['booking_code']?.toString() ?? '#$bookingId';
    final customer = (item['customer'] as Map?) ?? {};
    final customerName = customer['name']?.toString() ?? 'Pelanggan';

    Map<String, dynamic>? resolvedModel;
    final rawItems = item['items'] as List?;
    if (rawItems != null && rawItems.isNotEmpty) {
      final first = rawItems.first;
      if (first is Map) {
        final asset = first['asset'] as Map?;
        if (asset != null && asset['model'] is Map) {
          resolvedModel = Map<String, dynamic>.from(asset['model']);
        }
      }
    }
    if (resolvedModel == null) {
      final primaryAsset =
          (item['primary_asset'] as Map?) ??
          (item['active_asset'] as Map?) ??
          (item['device'] as Map?) ??
          {};
      if (primaryAsset['model'] is Map) {
        resolvedModel = Map<String, dynamic>.from(primaryAsset['model']);
      } else if (primaryAsset['asset_model'] is Map) {
        resolvedModel = Map<String, dynamic>.from(primaryAsset['asset_model']);
      }
    }

    final deviceModel = resolvedModel?['name']?.toString() ?? 'Unit Sewa';
    final currentEndAt = DateTime.tryParse(item['end_at']?.toString() ?? '')
        ?.toLocal();

    final targets = <_AdjustmentTarget>[];
    if (rawItems != null && rawItems.isNotEmpty) {
      Map? primaryItem;
      for (final it in rawItems) {
        if (it is Map && it['item_type'] == 'primary') {
          primaryItem = it;
          break;
        }
      }
      primaryItem ??= rawItems.first is Map ? (rawItems.first as Map) : null;
      if (primaryItem != null) {
        final pAsset = primaryItem['asset'] as Map? ?? {};
        final pModel = pAsset['model'] as Map? ?? resolvedModel;
        final pName = pModel?['name']?.toString() ?? deviceModel;
        final pDur =
            int.tryParse(primaryItem['duration_value']?.toString() ?? '') ??
            int.tryParse(item['duration_hours']?.toString() ?? '24') ??
            24;
        final pPrice = (primaryItem['unit_price'] != null)
            ? CurrencyFormatter.parse(primaryItem['unit_price'])
            : CurrencyFormatter.parse(
                item['primary_subtotal'] ?? item['total_bill'] ?? 0,
              );

        targets.add(
          _AdjustmentTarget(
            itemId: primaryItem['id'] as int?,
            label: 'Utama: $pName',
            shortName: pName,
            isPrimary: true,
            currentDurationHours: pDur,
            currentPrice: pPrice,
            model: pModel != null ? Map<String, dynamic>.from(pModel) : null,
          ),
        );
      }

      for (final it in rawItems) {
        if (it is Map && it['item_type'] == 'addon') {
          final aAsset = it['asset'] as Map? ?? {};
          final aModel = aAsset['model'] as Map?;
          final aName = aModel?['name']?.toString() ?? 'Aksesoris';
          final aDur =
              int.tryParse(it['duration_value']?.toString() ?? '') ??
              int.tryParse(item['duration_hours']?.toString() ?? '24') ??
              24;
          final aPrice = CurrencyFormatter.parse(it['unit_price'] ?? 0);

          targets.add(
            _AdjustmentTarget(
              itemId: it['id'] as int?,
              label: 'Add-on: $aName',
              shortName: aName,
              isPrimary: false,
              currentDurationHours: aDur,
              currentPrice: aPrice,
              model: aModel != null ? Map<String, dynamic>.from(aModel) : null,
            ),
          );
        }
      }
    }

    if (targets.isEmpty) {
      final pDur =
          int.tryParse(item['duration_hours']?.toString() ?? '24') ?? 24;
      final pPrice = CurrencyFormatter.parse(
        item['primary_subtotal'] ?? item['total_bill'] ?? 0,
      );
      targets.add(
        _AdjustmentTarget(
          itemId: null,
          label: 'Utama: $deviceModel',
          shortName: deviceModel,
          isPrimary: true,
          currentDurationHours: pDur,
          currentPrice: pPrice,
          model: resolvedModel,
        ),
      );
    }

    int selectedTargetIndex = 0;
    String direction = 'increase';
    int selectedHours = 6;
    int multiplier = 1;
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    final payments = (item['payments'] as List?) ?? [];
    double alreadyPaidNet = 0.0;
    for (final p in payments) {
      if (p is Map) {
        if (p['status']?.toString().toLowerCase() == 'void') continue;
        final dir = p['direction']?.toString().toLowerCase();
        final type = p['type']?.toString().toLowerCase();
        final amt = CurrencyFormatter.parse(p['amount'] ?? 0);
        if (dir == 'inflow' ||
            type == 'settlement' ||
            type == 'dp' ||
            type == 'rental' ||
            type == 'extension') {
          alreadyPaidNet += amt;
        } else if (dir == 'outflow' || type == 'refund') {
          alreadyPaidNet -= amt;
        }
      }
    }

    final originalTotalBill = CurrencyFormatter.parse(
      item['total_bill'] ?? item['total_amount'] ?? 0,
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeTarget = targets[selectedTargetIndex];
            final isIncrease = direction == 'increase';

            final durationOptions = _getDurationOptionsForTarget(
              activeTarget.model,
            );
            if (!durationOptions.any((o) => o.hours == selectedHours)) {
              selectedHours = durationOptions.isNotEmpty
                  ? durationOptions.first.hours
                  : 6;
            }

            final selectedOption = durationOptions.firstWhere(
              (o) => o.hours == selectedHours,
              orElse: () => durationOptions.isNotEmpty
                  ? durationOptions.first
                  : const _DurationOption(
                      hours: 6,
                      price: 90000,
                      label: '6 Jam',
                    ),
            );
            final maxAllowedMultiplier = _computeMaxDurationMultiplier(
              isIncrease: isIncrease,
              optionHours: selectedOption.hours,
              currentDurationHours: activeTarget.currentDurationHours,
              isPrimary: activeTarget.isPrimary,
              currentEndAt: currentEndAt,
            );
            if (multiplier > maxAllowedMultiplier) {
              multiplier = maxAllowedMultiplier;
            }
            final totalDeltaHours = selectedOption.hours * multiplier;
            final totalAdjustmentAmount = selectedOption.price * multiplier;
            final fee = totalAdjustmentAmount;
            final deltaFee = isIncrease ? fee : -fee;

            DateTime? newEndAt;
            bool isEndAtInPast = false;
            if (activeTarget.isPrimary && currentEndAt != null) {
              if (isIncrease) {
                newEndAt = currentEndAt.add(Duration(hours: totalDeltaHours));
              } else {
                newEndAt = currentEndAt.subtract(
                  Duration(hours: totalDeltaHours),
                );
                isEndAtInPast = newEndAt.isBefore(DateTime.now());
              }
            } else if (currentEndAt != null) {
              newEndAt = currentEndAt;
            }

            final isBelowMinimumDuration =
                !isIncrease &&
                (activeTarget.currentDurationHours - totalDeltaHours < 1);

            final estimatedNewTotal = (originalTotalBill + deltaFee).clamp(
              0.0,
              double.infinity,
            );
            final refundDue =
                (!isIncrease && alreadyPaidNet > estimatedNewTotal)
                ? (alreadyPaidNet - estimatedNewTotal)
                : 0.0;

            final hasBoundaryError = isEndAtInPast || isBelowMinimumDuration;
            final canSubmitReduction =
                !hasBoundaryError &&
                (!isIncrease &&
                    (refundDue == 0 || pinController.text.trim().length >= 4));

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Atur Durasi Sewa',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            bookingCode,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                              color: AppColors.obsidian,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pelanggan: $customerName',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    if (targets.length > 1) ...[
                      const Text(
                        'Pilih Item yang Disesuaikan:',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(targets.length, (idx) {
                          final t = targets[idx];
                          final isSel = selectedTargetIndex == idx;
                          return ChoiceChip(
                            label: Text(
                              '${t.label} (${t.currentDurationHours}j)',
                            ),
                            selected: isSel,
                            onSelected: (_) => setModalState(() {
                              selectedTargetIndex = idx;
                              multiplier = 1;
                            }),
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              color: isSel
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontWeight: isSel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontSize: 12,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],

                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() {
                                direction = 'increase';
                                multiplier = 1;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isIncrease
                                      ? AppColors.obsidian
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isIncrease
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '+ Tambah Jam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isIncrease
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: isIncrease
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() {
                                direction = 'decrease';
                                multiplier = 1;
                              }),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: !isIncrease
                                      ? AppColors.obsidian
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !isIncrease
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '- Kurangi Jam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !isIncrease
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    color: !isIncrease
                                        ? Colors.white
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      isIncrease
                          ? 'Pilihan Durasi Perpanjangan (Sesuai Tarif Model):'
                          : 'Pilihan Durasi Pengurangan (Sesuai Tarif Model):',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: durationOptions.map((opt) {
                          final isSel = selectedHours == opt.hours;
                          final wouldBePast =
                              !isIncrease &&
                              activeTarget.isPrimary &&
                              currentEndAt != null &&
                              currentEndAt
                                  .subtract(Duration(hours: opt.hours))
                                  .isBefore(DateTime.now());
                          final wouldBeBelowOne =
                              !isIncrease &&
                              (activeTarget.currentDurationHours - opt.hours <
                                  1);
                          final isDisabled = wouldBePast || wouldBeBelowOne;

                          final priceFormatted = CurrencyFormatter.format(
                            opt.price,
                          );
                          final chipText = isIncrease
                              ? '${opt.label} • $priceFormatted'
                              : '${opt.label} • -$priceFormatted';

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(chipText),
                              selected: isSel && !isDisabled,
                              onSelected: isDisabled
                                  ? null
                                  : (_) => setModalState(() {
                                      selectedHours = opt.hours;
                                      multiplier = 1;
                                    }),
                              showCheckmark: true,
                              checkmarkColor: isSel && !isDisabled
                                  ? Colors.white
                                  : AppColors.obsidian,
                              selectedColor: AppColors.obsidian,
                              backgroundColor: AppColors.surface,
                              disabledColor: AppColors.surfaceMuted,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSel && !isDisabled
                                      ? AppColors.obsidian
                                      : (isDisabled
                                            ? AppColors.borderSubtle
                                            : AppColors.border),
                                  width: isSel && !isDisabled ? 1.5 : 1.0,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: isSel && !isDisabled
                                    ? Colors.white
                                    : (isDisabled
                                          ? AppColors.textMuted
                                          : AppColors.textPrimary),
                                fontWeight: isSel
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildDurationMultiplierRow(
                      multiplier: multiplier,
                      maxAllowedMultiplier: maxAllowedMultiplier,
                      totalDeltaHours: totalDeltaHours,
                      isSubmitting: isSubmitting,
                      onDecrement: () => setModalState(() {
                        if (multiplier > 1) multiplier--;
                      }),
                      onIncrement: () => setModalState(() {
                        if (multiplier < maxAllowedMultiplier) multiplier++;
                      }),
                    ),
                    const SizedBox(height: 14),

                    if (isEndAtInPast) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 16,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batas waktu baru tidak valid (lewat dari batas waktu saat ini).',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else if (isBelowMinimumDuration) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 16,
                              color: AppColors.danger,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Durasi sewa tidak dapat dikurangi hingga kurang dari 1 jam.',
                                style: TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isIncrease
                                      ? 'Biaya Tambahan ($totalDeltaHours Jam)'
                                      : 'Potongan Biaya ($totalDeltaHours Jam)',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isIncrease
                                    ? CurrencyFormatter.format(deltaFee.abs())
                                    : '- ${CurrencyFormatter.format(deltaFee.abs())}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isIncrease
                                      ? AppColors.obsidian
                                      : AppColors.success,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          if (newEndAt != null) ...[
                            const SizedBox(height: 10),
                            const Divider(
                              height: 1,
                              color: AppColors.borderSubtle,
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Batas Waktu Pengembalian Baru:',
                                    style: TextStyle(
                                      color: AppColors.textSecondary,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormatter.formatFull(newEndAt),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                    color: AppColors.obsidian,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(
                            height: 1,
                            color: AppColors.borderSubtle,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Estimasi Total Tagihan Baru:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12.5,
                                    color: AppColors.obsidian,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(estimatedNewTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.obsidian,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    if (refundDue > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.warning.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.payments_outlined,
                                  size: 18,
                                  color: AppColors.warning,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pengembalian Dana (Refund): ${CurrencyFormatter.format(refundDue)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: AppColors.obsidian,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Otorisasi PIN Manager diperlukan untuk pengeluaran kas refund.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: 'PIN Manager *',
                                hintText: '6 digit PIN Manager',
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  size: 18,
                                ),
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    if (!isIncrease) ...[
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'Alasan Pengurangan Durasi (Opsional)',
                          hintText: 'mis. Pelanggan selesai lebih awal',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (isIncrease) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidian,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                final result =
                                    await Navigator.push<PaymentResult>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentPage(
                                          paymentContext:
                                              PaymentContext.extension(
                                                booking: item,
                                                bookingId: bookingId,
                                                bookingCode: bookingCode,
                                                customerName: customerName,
                                                deviceModel:
                                                    activeTarget.shortName,
                                                additionalHours:
                                                    totalDeltaHours,
                                                extensionFee: fee,
                                                extraPayload: {
                                                  if (activeTarget.itemId !=
                                                      null)
                                                    'booking_item_id':
                                                        activeTarget.itemId,
                                                  if (selectedOption.rateId !=
                                                      null)
                                                    'rate_id':
                                                        selectedOption.rateId,
                                                  'multiplier': multiplier,
                                                },
                                              ),
                                        ),
                                      ),
                                    );

                                if (result != null && result.isSuccess) {
                                  _invalidateQueueProviders(ref);
                                  onRefresh?.call();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Perpanjangan sewa $totalDeltaHours jam berhasil dibayar & diperbarui!',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: const Text(
                          'Proses pembayaran',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.obsidian,
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 1.2,
                          ),
                          backgroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref
                                      .read(bookingRepositoryProvider)
                                      .adjustDuration(
                                        bookingId: bookingId,
                                        bookingItemId: activeTarget.itemId,
                                        direction: 'increase',
                                        hoursDelta: totalDeltaHours,
                                        additionalFee: fee,
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _invalidateQueueProviders(ref);
                                  onRefresh?.call();
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Sewa diperpanjang $totalDeltaHours jam (tagihan dicatat).',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.receipt_long_outlined,
                                size: 16,
                                color: AppColors.obsidian,
                              ),
                        label: const Text(
                          'Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmitReduction
                              ? AppColors.obsidian
                              : AppColors.surfaceMuted,
                          foregroundColor: canSubmitReduction
                              ? Colors.white
                              : AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: (!canSubmitReduction || isSubmitting)
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref
                                      .read(bookingRepositoryProvider)
                                      .adjustDuration(
                                        bookingId: bookingId,
                                        bookingItemId: activeTarget.itemId,
                                        direction: 'decrease',
                                        hoursDelta: totalDeltaHours,
                                        additionalFee: fee,
                                        managerPin: refundDue > 0
                                            ? pinController.text.trim()
                                            : null,
                                        reason:
                                            reasonController.text
                                                .trim()
                                                .isNotEmpty
                                            ? reasonController.text.trim()
                                            : null,
                                      );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _invalidateQueueProviders(ref);
                                  onRefresh?.call();
                                  if (context.mounted) {
                                    final refundText = refundDue > 0
                                        ? ' Refund ${CurrencyFormatter.format(refundDue)} dicatat.'
                                        : '';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Durasi sewa berhasil dikurangi $totalDeltaHours jam.$refundText',
                                        ),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal: $e'),
                                        backgroundColor: AppColors.danger,
                                      ),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Konfirmasi Pengurangan Durasi',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text(
                          'Batal',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Computes the upper bound for the duration package multiplier (max 30,
  /// clamped in decrease mode so reduced hours keep >= 1h and stay in future).
  static int _computeMaxDurationMultiplier({
    required bool isIncrease,
    required int optionHours,
    required int currentDurationHours,
    required bool isPrimary,
    required DateTime? currentEndAt,
  }) {
    const maxCap = 30;
    if (isIncrease || optionHours <= 0) {
      return maxCap;
    }
    var maxAllowedHours = (currentDurationHours - 1).clamp(0, 100000);
    if (isPrimary && currentEndAt != null) {
      final remainingMinutes = currentEndAt
          .difference(DateTime.now())
          .inMinutes;
      final maxByDeadline = remainingMinutes > 0 ? (remainingMinutes ~/ 60) : 0;
      if (maxByDeadline < maxAllowedHours) {
        maxAllowedHours = maxByDeadline;
      }
    }
    return (maxAllowedHours ~/ optionHours).clamp(1, maxCap);
  }

  /// Renders the horizontal `Jumlah Kelipatan` stepper row directly under rate chips.
  static Widget _buildDurationMultiplierRow({
    required int multiplier,
    required int maxAllowedMultiplier,
    required int totalDeltaHours,
    required bool isSubmitting,
    required VoidCallback onDecrement,
    required VoidCallback onIncrement,
  }) {
    final canDecrement = !isSubmitting && multiplier > 1;
    final canIncrement = !isSubmitting && multiplier < maxAllowedMultiplier;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Jumlah Kelipatan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$totalDeltaHours Jam',
                key: const Key('duration_multiplier_total_hours'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('duration_multiplier_decrement'),
                  onTap: canDecrement ? onDecrement : null,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(9),
                  ),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.remove,
                      size: 16,
                      color: canDecrement
                          ? AppColors.textPrimary
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 40),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: Alignment.center,
                child: Text(
                  '${multiplier}x',
                  key: const Key('duration_multiplier_value'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const Key('duration_multiplier_increment'),
                  onTap: canIncrement ? onIncrement : null,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(9),
                  ),
                  child: SizedBox(
                    width: 34,
                    height: 34,
                    child: Icon(
                      Icons.add,
                      size: 16,
                      color: canIncrement
                          ? AppColors.textPrimary
                          : const Color(0xFFCBD5E1),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

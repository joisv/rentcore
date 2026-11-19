import 'package:dio/dio.dart';
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

  static String _extractReadableError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstVal = errors.values.first;
          if (firstVal is List && firstVal.isNotEmpty) {
            return firstVal.first.toString();
          }
          return firstVal.toString();
        }
        final msg = data['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) {
          return msg;
        }
      }
    }
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
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

  /// Opens the unit handover / check-in sheet for awaiting-handover bookings.
  static void handleHandoverUnit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final navigator = Navigator.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (_) => _CheckInHandoverSheet(
        booking: booking,
        onCompleted: () {
          _invalidateQueueProviders(ref);
          ref.invalidate(readyAssetsProvider);
          onRefresh?.call();
        },
        onProceedToHandoverPayment: ({
          required double remainingAmount,
          int? assetUnitId,
          required String collateralStorageSlot,
          bool startNow = false,
          bool keepOriginalEndAt = false,
          double? adjustedContractTotal,
        }) {
          final paymentContext = PaymentContext.settlement(
            booking: booking,
            remainingDue: remainingAmount,
            isHandoverSettlement: true,
            assetUnitId: assetUnitId,
            collateralType: booking['collateral_type']?.toString() ?? 'KTP Asli',
            collateralStorageSlot: collateralStorageSlot,
            startNow: startNow,
            keepOriginalEndAt: keepOriginalEndAt,
            contractTotalOverride: adjustedContractTotal,
          );
          navigator.push(
            MaterialPageRoute(
              builder: (_) => PaymentPage(
                paymentContext: paymentContext,
                onPaymentSuccess: () {
                  _invalidateQueueProviders(ref);
                  ref.invalidate(readyAssetsProvider);
                  onRefresh?.call();
                },
              ),
            ),
          );
        },
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
    final isNoShow = status == 'no_show' || status == 'cancelled';
    final isAwaitingHandover = status == 'booked' ||
        status == 'reserved' ||
        status == 'confirmed' ||
        status == 'waiting_handover';
    final isActive = !isAwaitingHandover && !isReturned && !isNoShow;
    final bookingCode = booking['booking_code']?.toString() ?? 'Sewa';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        final actionTiles = <Widget>[
          if (isAwaitingHandover) ...[
            _buildOverflowActionTile(
              key: const Key('overflow_reschedule_tile'),
              icon: Icons.edit_calendar_rounded,
              title: 'Ubah Jadwal',
              subtitle: 'Majukan atau geser tanggal & jam ambil',
              onTap: () {
                Navigator.pop(ctx);
                openRescheduleFlow(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
            _buildOverflowActionTile(
              icon: Icons.schedule_rounded,
              title: 'Perpanjang Batas Ambil (+30 mnt)',
              subtitle: 'Tambah toleransi sebelum No-Show',
              onTap: () async {
                Navigator.pop(ctx);
                await _handleExtendGracePeriod(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
            _buildOverflowActionTile(
              key: const Key('overflow_mark_noshow_tile'),
              icon: Icons.person_off_outlined,
              title: 'Tandai No-Show',
              subtitle: 'Batalkan & lepas slot unit',
              isDanger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmMarkNoShow(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
            _buildOverflowActionTile(
              key: const Key('overflow_cancel_booking_tile'),
              icon: Icons.cancel_outlined,
              title: 'Batalkan Booking',
              subtitle: 'Batalkan pesanan & kembalikan slot',
              isDanger: true,
              onTap: () {
                Navigator.pop(ctx);
                _confirmCancelBooking(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
          ] else if (isActive) ...[
            _buildOverflowActionTile(
              icon: Icons.more_time_rounded,
              title: 'Tambah Jam / Perpanjang',
              subtitle: 'Sesuaikan durasi sewa berjalan',
              onTap: () {
                Navigator.pop(ctx);
                showDurationAdjustmentDialog(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
            _buildOverflowActionTile(
              icon: Icons.swap_horiz_rounded,
              title: 'Ganti Unit Fisik',
              subtitle: 'Tukar unit jika ada kendala perangkat',
              onTap: () {
                Navigator.pop(ctx);
                openExchangeWizard(
                  context,
                  ref,
                  booking,
                  onRefresh: onRefresh,
                );
              },
            ),
            _buildOverflowActionTile(
              icon: Icons.print_rounded,
              title: 'Cetak Ulang Struk',
              subtitle: 'Cetak struk transaksi ke printer',
              onTap: () {
                Navigator.pop(ctx);
                printBookingReceipt(context, ref, booking);
              },
            ),
          ] else ...[
            _buildOverflowActionTile(
              icon: Icons.print_rounded,
              title: 'Cetak Ulang Struk',
              subtitle: 'Cetak struk transaksi ke printer',
              onTap: () {
                Navigator.pop(ctx);
                printBookingReceipt(context, ref, booking);
              },
            ),
          ],
        ];

        final dividedChildren = <Widget>[];
        for (var i = 0; i < actionTiles.length; i++) {
          if (i > 0) {
            dividedChildren.add(
              const Divider(
                height: 1,
                indent: 56,
                endIndent: 20,
                color: AppColors.border,
              ),
            );
          }
          dividedChildren.add(actionTiles[i]);
        }

        return SafeArea(
          top: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 4,
                    ),
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
                  ...dividedChildren,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static Widget _buildOverflowActionTile({
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    final iconColor = isDanger ? AppColors.danger : AppColors.obsidian;
    final bgColor = isDanger
        ? AppColors.dangerLight
        : AppColors.obsidian.withValues(alpha: 0.08);
    return ListTile(
      key: key,
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: isDanger ? AppColors.danger : AppColors.obsidian,
        ),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
        ),
      ),
      onTap: onTap,
    );
  }

  /// Opens date & time pickers in `#111111` monochrome theme and confirms a booking reschedule.
  static Future<void> openRescheduleFlow(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) async {
    final bookingId = (booking['id'] as num?)?.toInt();
    if (bookingId == null) return;

    final now = DateTime.now();
    final currentStart =
        DateTime.tryParse(booking['start_at']?.toString() ?? '')?.toLocal() ??
        now;
    final currentEnd =
        DateTime.tryParse(booking['end_at']?.toString() ?? '')?.toLocal();
    final durationHours =
        ((booking['duration_hours'] as num?)?.toInt() ??
                (currentEnd != null
                    ? currentEnd.difference(currentStart).inHours
                    : 24))
            .clamp(1, 24 * 365);

    final firstDate = DateTime(now.year - 1);
    final lastDate = DateTime(now.year + 2);
    final initialDate = currentStart.isBefore(firstDate)
        ? firstDate
        : (currentStart.isAfter(lastDate) ? lastDate : currentStart);

    ThemeData buildMonochromeTheme(BuildContext pickerCtx) {
      return Theme.of(pickerCtx).copyWith(
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF111111),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Color(0xFF111111),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF111111),
          ),
        ),
      );
    }

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Pilih Tanggal Mulai Baru',
      builder: (ctx, child) =>
          Theme(data: buildMonochromeTheme(ctx), child: child!),
    );
    if (pickedDate == null || !context.mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentStart),
      helpText: 'Pilih Jam Mulai Baru',
      builder: (ctx, child) =>
          Theme(data: buildMonochromeTheme(ctx), child: child!),
    );
    if (pickedTime == null || !context.mounted) return;

    final newStartAt = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    final newEndAt = newStartAt.add(Duration(hours: durationHours));
    final previewLine =
        'Jadwal Baru: ${DateFormatter.formatFull(newStartAt)} • Selesai: ${DateFormatter.formatFull(newEndAt)}';

    final messenger = ScaffoldMessenger.of(context);
    var isSaving = false;
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dCtx) => StatefulBuilder(
        builder: (dCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.edit_calendar_rounded,
                color: Color(0xFF111111),
                size: 20,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Konfirmasi Ubah Jadwal',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                key: const Key('reschedule_preview_box'),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  previewLine,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Jadwal sebelumnya: ${DateFormatter.formatFull(currentStart)} ($durationHours jam)',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textSecondary,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  key: const Key('reschedule_error_banner'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.danger.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dCtx),
              child: const Text(
                'Batal',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            ElevatedButton(
              key: const Key('confirm_reschedule_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });
                      try {
                        await ref
                            .read(bookingRepositoryProvider)
                            .rescheduleBooking(
                              bookingId,
                              newStartAt: newStartAt,
                              keepOriginalEndAt: false,
                            );
                        if (!dCtx.mounted) return;
                        Navigator.pop(dCtx);
                        _invalidateQueueProviders(ref);
                        ref.invalidate(readyAssetsProvider);
                        onRefresh?.call();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Jadwal booking berhasil diperbarui.'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      } catch (e) {
                        if (!dCtx.mounted) return;
                        setDialogState(() {
                          isSaving = false;
                          errorMessage = _extractReadableError(e);
                        });
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Jadwal'),
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _handleExtendGracePeriod(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) async {
    final bookingId = (booking['id'] as num?)?.toInt();
    if (bookingId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(bookingRepositoryProvider)
          .extendGracePeriod(bookingId, additionalMinutes: 30);
      _invalidateQueueProviders(ref);
      onRefresh?.call();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Batas ambil diperpanjang +30 menit.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal memperpanjang batas ambil: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  static void _confirmMarkNoShow(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final bookingId = (booking['id'] as num?)?.toInt();
    if (bookingId == null) return;
    final bookingCode = booking['booking_code']?.toString() ?? '#$bookingId';
    final paidAmount = CurrencyFormatter.parse(booking['paid_amount']);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.person_off_outlined, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Tandai No-Show',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking $bookingCode akan ditandai No-Show dan slot unit akan dilepas kembali ke inventaris.'
              '${paidAmount > 0 ? '\n\nDP / pembayaran sebesar ${CurrencyFormatter.format(paidAmount)} akan dicatat sebagai hangus.' : ''}',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Catatan alasan (opsional)',
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(dCtx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(bookingRepositoryProvider)
                    .markNoShow(bookingId, reason: reason);
                _invalidateQueueProviders(ref);
                onRefresh?.call();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Booking $bookingCode ditandai No-Show.'),
                    backgroundColor: AppColors.obsidian,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal menandai No-Show: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Konfirmasi No-Show'),
          ),
        ],
      ),
    );
  }

  static void _confirmCancelBooking(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking, {
    VoidCallback? onRefresh,
  }) {
    final bookingId = (booking['id'] as num?)?.toInt();
    if (bookingId == null) return;
    final bookingCode = booking['booking_code']?.toString() ?? '#$bookingId';
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Batalkan Booking',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Booking $bookingCode akan dibatalkan dan slot unit akan dilepas kembali ke inventaris.',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Catatan alasan pembatalan (opsional)',
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx),
            child: const Text(
              'Tutup',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () async {
              final reason = reasonController.text.trim();
              Navigator.pop(dCtx);
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref
                    .read(bookingRepositoryProvider)
                    .cancelBooking(bookingId, reason: reason);
                _invalidateQueueProviders(ref);
                onRefresh?.call();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Booking $bookingCode berhasil dibatalkan.'),
                    backgroundColor: AppColors.obsidian,
                  ),
                );
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Gagal membatalkan booking: $e'),
                    backgroundColor: AppColors.danger,
                  ),
                );
              }
            },
            child: const Text('Konfirmasi Batal'),
          ),
        ],
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
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
                                borderRadius: BorderRadius.circular(8),
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
                        borderRadius: BorderRadius.circular(10),
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
                          borderRadius: BorderRadius.circular(10),
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
                                  borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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
                            borderRadius: BorderRadius.circular(8),
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

class _CheckInHandoverSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;
  final VoidCallback onCompleted;
  final void Function({
    required double remainingAmount,
    int? assetUnitId,
    required String collateralStorageSlot,
    bool startNow,
    bool keepOriginalEndAt,
    double? adjustedContractTotal,
  }) onProceedToHandoverPayment;

  const _CheckInHandoverSheet({
    required this.booking,
    required this.onCompleted,
    required this.onProceedToHandoverPayment,
  });

  @override
  ConsumerState<_CheckInHandoverSheet> createState() =>
      _CheckInHandoverSheetState();
}

class _CheckInHandoverSheetState extends ConsumerState<_CheckInHandoverSheet> {
  late final TextEditingController _slotController;
  List<Map<String, dynamic>> _readyUnits = [];
  bool _isLoadingUnits = false;
  String? _unitsError;
  String? _submitError;
  int? _selectedUnitId;
  bool _isSubmitting = false;
  bool _keepOriginalEndAt = false;

  bool get _isFloating => widget.booking['asset_unit_id'] == null;

  DateTime? get _scheduledStartAt =>
      DateTime.tryParse(widget.booking['start_at']?.toString() ?? '')?.toLocal();

  DateTime? get _scheduledEndAt =>
      DateTime.tryParse(widget.booking['end_at']?.toString() ?? '')?.toLocal();

  bool get _isEarlyPickup {
    final start = _scheduledStartAt;
    return start != null && DateTime.now().isBefore(start);
  }

  @override
  void initState() {
    super.initState();
    _slotController = TextEditingController(
      text:
          widget.booking['collateral_storage_slot']?.toString() ??
          'Brankas A, Slot 01',
    );
    _selectedUnitId = (widget.booking['asset_unit_id'] as num?)?.toInt();
    if (_isFloating) {
      _loadReadyUnits();
    }
  }

  @override
  void dispose() {
    _slotController.dispose();
    super.dispose();
  }

  Future<void> _loadReadyUnits() async {
    final bookingId = (widget.booking['id'] as num?)?.toInt();
    if (bookingId == null) return;
    setState(() {
      _isLoadingUnits = true;
      _unitsError = null;
    });
    try {
      final units = await ref
          .read(bookingRepositoryProvider)
          .fetchAvailableUnitsForBooking(
            bookingId,
            startNow: _isEarlyPickup,
            keepOriginalEndAt: _isEarlyPickup && _keepOriginalEndAt,
          );
      if (!mounted) return;
      setState(() {
        _readyUnits = units;
        final hasCurrent =
            _selectedUnitId != null &&
            units.any((u) => (u['id'] as num?)?.toInt() == _selectedUnitId);
        if (!hasCurrent) {
          _selectedUnitId =
              units.isNotEmpty ? (units.first['id'] as num?)?.toInt() : null;
        }
        _isLoadingUnits = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingUnits = false;
        _unitsError = RentalQueueActions._extractReadableError(e);
      });
    }
  }

  ({
    double remainingAmount,
    double totalBill,
    double extraFee,
    int estimatedHours,
  })
  _computeAdjustedTotals() {
    final booking = widget.booking;
    final baseTotalBill = CurrencyFormatter.parse(
      booking['total_bill'] ?? booking['total_amount'] ?? 0,
    );
    double baseRemaining;
    if (booking['remaining_balance'] != null) {
      baseRemaining = CurrencyFormatter.parse(
        booking['remaining_balance'],
      ).clamp(0.0, double.infinity);
    } else {
      final payments = (booking['payments'] as List?) ?? [];
      double paid = 0.0;
      for (final p in payments) {
        if (p is Map) {
          if (p['status']?.toString().toLowerCase() == 'void') continue;
          final pt = p['type']?.toString().toLowerCase();
          if (pt == 'settlement' ||
              pt == 'dp' ||
              pt == 'extension' ||
              pt == 'rental' ||
              pt == 'exchange') {
            paid += CurrencyFormatter.parse(p['amount']);
          }
        }
      }
      if (paid <= 0 && booking['paid_amount'] != null) {
        paid = CurrencyFormatter.parse(booking['paid_amount']);
      }
      final paymentStatus =
          (booking['payment_status'] ?? '').toString().toLowerCase();
      baseRemaining = (paid <= 0 && paymentStatus == 'paid')
          ? 0.0
          : (baseTotalBill - paid).clamp(0.0, double.infinity);
    }

    final endAt = _scheduledEndAt;
    final startAt = _scheduledStartAt;
    final baseHours = ((booking['duration_hours'] as num?)?.toInt() ??
            ((startAt != null && endAt != null)
                ? endAt.difference(startAt).inHours
                : 24))
        .clamp(1, 24 * 365);

    if (!(_isEarlyPickup && _keepOriginalEndAt && endAt != null)) {
      return (
        remainingAmount: baseRemaining,
        totalBill: baseTotalBill,
        extraFee: 0.0,
        estimatedHours: baseHours,
      );
    }

    final now = DateTime.now();
    final newHours =
        ((endAt.difference(now).inMinutes) / 60.0).ceil().clamp(baseHours, 24 * 365);
    final extraHours = newHours - baseHours;
    if (extraHours <= 0) {
      return (
        remainingAmount: baseRemaining,
        totalBill: baseTotalBill,
        extraFee: 0.0,
        estimatedHours: baseHours,
      );
    }

    final primarySub = CurrencyFormatter.parse(
      booking['primary_subtotal'] ?? booking['subtotal_amount'] ?? baseTotalBill,
    );
    final modelMap =
        (booking['asset_model'] as Map?) ??
        (booking['active_asset']?['model'] as Map?) ??
        {};
    final tiers = (modelMap['pricing_tiers'] as List?) ?? [];
    double? newPrimarySub;
    double hourlyRate = baseHours > 0 ? (primarySub / baseHours) : 15000.0;

    for (final t in tiers) {
      if (t is Map) {
        final tHours = (t['duration_hours'] as num?)?.toInt();
        final extRate = CurrencyFormatter.parse(t['extension_hourly_rate'] ?? 0);
        if (extRate > 0) hourlyRate = extRate;
        if (tHours == newHours) {
          newPrimarySub = CurrencyFormatter.parse(t['price']);
          break;
        }
      }
    }
    newPrimarySub ??= primarySub + (extraHours * hourlyRate);
    final extraFee = (newPrimarySub - primarySub).clamp(0.0, double.infinity);

    return (
      remainingAmount: baseRemaining + extraFee,
      totalBill: baseTotalBill + extraFee,
      extraFee: extraFee,
      estimatedHours: newHours,
    );
  }

  bool _validateHandoverInputs() {
    if (_isFloating && _selectedUnitId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih unit fisik yang akan diserahkan terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return false;
    }
    if (_slotController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Isi data jaminan / slot brankas terlebih dahulu.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return false;
    }
    return true;
  }

  void _proceedToPaymentForHandover(
    double remainingAmount,
    double adjustedContractTotal,
  ) {
    if (!_validateHandoverInputs()) return;
    final slot = _slotController.text.trim();
    final unitId = _selectedUnitId;
    final startNow = _isEarlyPickup;
    final keepOriginalEndAt = startNow && _keepOriginalEndAt;
    Navigator.pop(context);
    widget.onProceedToHandoverPayment(
      remainingAmount: remainingAmount,
      assetUnitId: unitId,
      collateralStorageSlot: slot,
      startNow: startNow,
      keepOriginalEndAt: keepOriginalEndAt,
      adjustedContractTotal: adjustedContractTotal,
    );
  }

  Future<void> _submitCheckIn() async {
    final bookingId = (widget.booking['id'] as num?)?.toInt();
    if (bookingId == null) return;
    if (!_validateHandoverInputs()) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(bookingRepositoryProvider).checkInBooking(
            bookingId,
            assetUnitId: _selectedUnitId,
            collateralStorageSlot: _slotController.text.trim(),
            startNow: _isEarlyPickup,
            keepOriginalEndAt: _isEarlyPickup && _keepOriginalEndAt,
          );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCompleted();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Unit berhasil diserahkan dan sewa kini aktif.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final readable = RentalQueueActions._extractReadableError(e);
      setState(() {
        _isSubmitting = false;
        _submitError = readable;
      });
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyerahkan unit: $readable'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  String _buildUnitSpecsText(Map<dynamic, dynamic> unit) {
    final sn = unit['serial_number']?.toString();
    final grade = unit['condition_grade']?.toString();
    final bh = unit['battery_health'];
    return [
      if (sn != null && sn.isNotEmpty) 'SN: $sn',
      if (grade != null && grade.isNotEmpty) 'Grade $grade',
      if (bh != null) 'BH $bh%',
    ].join(' • ');
  }

  Widget _buildEarlyPickupRadioOption({
    required Key key,
    required bool value,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _keepOriginalEndAt == value;
    return InkWell(
      key: key,
      onTap: () {
        if (_keepOriginalEndAt == value) return;
        setState(() {
          _keepOriginalEndAt = value;
          _submitError = null;
        });
        if (_isFloating) {
          _loadReadyUnits();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF111111)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 16,
              height: 16,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF111111)
                      : AppColors.textMuted,
                  width: 1.5,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF111111),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final bookingCode =
        booking['booking_code']?.toString() ?? '#${booking['id'] ?? ''}';
    final customerName =
        booking['customer']?['name']?.toString() ??
        booking['customer_name']?.toString() ??
        'Pelanggan';

    final modelName =
        booking['asset_model']?['name']?.toString() ??
        booking['active_asset']?['model']?['name']?.toString() ??
        'Unit Sewa';
    final pinnedAsset =
        (booking['asset_unit'] as Map?) ??
        (booking['active_asset'] as Map?);

    final graceStr = booking['grace_expires_at']?.toString();
    final graceAt =
        graceStr != null ? DateTime.tryParse(graceStr)?.toLocal() : null;
    final isOverduePickup =
        booking['is_overdue_pickup'] == true ||
        (graceAt != null && graceAt.isBefore(DateTime.now()));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
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
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Serahkan Unit',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$customerName • $modelName • $bookingCode',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_isEarlyPickup && _scheduledStartAt != null) ...[
                const SizedBox(height: 16),
                Column(
                  key: const Key('early_pickup_banner'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'AMBIL LEBIH AWAL • JADWAL: ${DateFormatter.formatDayMonth(_scheduledStartAt!).toUpperCase()}, ${DateFormatter.formatTime(_scheduledStartAt!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildEarlyPickupRadioOption(
                      key: const Key('early_pickup_shift_option'),
                      value: false,
                      title: 'Mulai sekarang, durasi tetap',
                      subtitle: 'Waktu selesai ikut maju otomatis',
                    ),
                    const SizedBox(height: 8),
                    _buildEarlyPickupRadioOption(
                      key: const Key('early_pickup_keep_end_option'),
                      value: true,
                      title: 'Mulai sekarang, batas kembali tetap',
                      subtitle: 'Tambah durasi & selisih tagihan',
                    ),
                  ],
                ),
              ],
              if (graceAt != null && !_isEarlyPickup) ...[
                const SizedBox(height: 12),
                Container(
                  key: const Key('handover_grace_pill'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isOverduePickup
                        ? AppColors.dangerLight
                        : AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOverduePickup
                          ? AppColors.danger.withValues(alpha: 0.3)
                          : const Color(0xFFE5E7EB),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOverduePickup
                            ? Icons.warning_amber_rounded
                            : Icons.schedule_rounded,
                        size: 15,
                        color: isOverduePickup
                            ? AppColors.danger
                            : const Color(0xFF111111),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          isOverduePickup
                              ? 'Lewat Jadwal Ambil (Batas: ${DateFormatter.formatTime(graceAt)})'
                              : 'Batas ambil: ${DateFormatter.formatTime(graceAt)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOverduePickup
                                ? AppColors.danger
                                : const Color(0xFF111111),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Unit Selection for Floating Unit vs Pinned Display
              if (_isFloating) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'UNIT FISIK',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B7280),
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (_isLoadingUnits)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_unitsError != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _unitsError!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                      ),
                    ),
                  )
                else if (!_isLoadingUnits && _readyUnits.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warningLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'Belum ada unit fisik berstatus Ready untuk model ini.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: _readyUnits.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (_, idx) {
                        final unit = _readyUnits[idx];
                        final unitId = (unit['id'] as num?)?.toInt();
                        final isSelected = _selectedUnitId == unitId;
                        final code = unit['asset_code']?.toString() ?? '-';
                        final specs = _buildUnitSpecsText(unit);

                        return InkWell(
                          key: Key('checkin_unit_option_$unitId'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _selectedUnitId = unitId),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF111111)
                                    : const Color(0xFFE5E7EB),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected
                                      ? Icons.radio_button_checked
                                      : Icons.radio_button_off,
                                  size: 18,
                                  color: isSelected
                                      ? const Color(0xFF111111)
                                      : AppColors.textMuted,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        code,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF111111),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (specs.isNotEmpty)
                                        Text(
                                          specs,
                                          style: const TextStyle(
                                            fontSize: 11.5,
                                            color: Color(0xFF6B7280),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ] else if (pinnedAsset != null) ...[
                const Text(
                  'UNIT FISIK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: Color(0xFF111111),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Builder(
                          builder: (_) {
                            final code =
                                pinnedAsset['asset_code']?.toString() ?? '-';
                            final specs = _buildUnitSpecsText(pinnedAsset);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF111111),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (specs.isNotEmpty)
                                  Text(
                                    specs,
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      color: Color(0xFF6B7280),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),
              TextField(
                key: const Key('handover_collateral_field'),
                controller: _slotController,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF111111),
                ),
                decoration: InputDecoration(
                  labelText: 'Slot Brankas Jaminan (KTP/SIM)',
                  labelStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE5E7EB),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF111111),
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              Builder(
                builder: (context) {
                  final totals = _computeAdjustedTotals();
                  final remainingAmount = totals.remainingAmount;
                  final needsSettlement = remainingAmount > 0;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (needsSettlement) ...[
                        const SizedBox(height: 16),
                        Row(
                          key: const Key('handover_remaining_balance_row'),
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sisa Tagihan',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                CurrencyFormatter.format(remainingAmount),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF111111),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (totals.extraFee > 0) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Termasuk selisih jadwal (${totals.estimatedHours} jam): +${CurrencyFormatter.format(totals.extraFee)}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ],
                      if (_submitError != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          key: const Key('handover_submit_error_banner'),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.dangerLight,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.danger.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            _submitError!,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          key: const Key('confirm_checkin_button'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF111111),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : (needsSettlement
                                  ? () => _proceedToPaymentForHandover(
                                      remainingAmount,
                                      totals.totalBill,
                                    )
                                  : _submitCheckIn),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  needsSettlement
                                      ? 'Bayar & Serahkan Unit'
                                      : 'Serahkan Unit',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

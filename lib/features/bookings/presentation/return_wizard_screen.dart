import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cash_suggestion_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/booking_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';

class ReturnWizardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;

  const ReturnWizardScreen({super.key, required this.booking});

  @override
  ConsumerState<ReturnWizardScreen> createState() => _ReturnWizardScreenState();
}

class _ReturnWizardScreenState extends ConsumerState<ReturnWizardScreen> {
  bool _icloudRemoved = false; // CRITICAL GUARD
  bool _screenOk = true;
  final bool _cameraOk = true;
  bool _cableReturned = true;
  bool _adapterReturned = true;
  String _conditionGrade = 'A';
  bool _isSubmitting = false;

  bool _payPenaltyNow = true;

  bool get _requiresFrpCheck {
    final items = (widget.booking['items'] as List?) ?? [];
    if (items.isEmpty) return true; // Default safety
    for (final it in items) {
      final model = it['asset']?['model'];
      if (model != null) {
        if (model['requires_frp_check'] == true) return true;
        final brand = (model['brand']?.toString() ?? '').toLowerCase();
        final name = (model['name']?.toString() ?? '').toLowerCase();
        if (brand == 'apple' || brand == 'samsung' || brand == 'google' || brand == 'xiaomi' || brand == 'oppo' || brand == 'vivo') {
          return true;
        }
        if (name.contains('iphone') || name.contains('ipad')) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final customer = booking['customer'] ?? {};
    final endAt = booking['end_at'] != null ? DateTime.tryParse(booking['end_at']) : null;
    final now = DateTime.now();

    // Calculate late penalty (60-minute grace period formula)
    int lateMinutes = 0;
    double penaltyAmount = 0.0;
    if (endAt != null && now.isAfter(endAt)) {
      lateMinutes = now.difference(endAt).inMinutes;
      if (lateMinutes > 60) {
        final billableHours = ((lateMinutes - 60) / 60).ceil();
        penaltyAmount = billableHours * 15000.0;
      }
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Pengembalian: ${booking['booking_code']}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer & Slot Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_outline_rounded, color: AppColors.obsidian),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name'] ?? 'Pelanggan',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        Text(
                          'Jaminan KTP di: ${booking['collateral_storage_slot'] ?? 'Brankas Cabang'}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Overtime Status Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: lateMinutes > 60 ? AppColors.dangerLight : AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: lateMinutes > 60 ? AppColors.danger.withValues(alpha: 0.3) : AppColors.border,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jadwal Selesai Sewa:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(DateFormatter.formatFull(endAt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Waktu Fisik Kembali:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(DateFormatter.formatFull(now), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                    ],
                  ),
                  if (lateMinutes > 0) ...[
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          lateMinutes <= 60 ? 'Terlambat (Grace Period Bebas Denda):' : 'Denda Keterlambatan ($lateMinutes mnt):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: lateMinutes > 60 ? AppColors.danger : AppColors.warning,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(penaltyAmount),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: lateMinutes > 60 ? AppColors.danger : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // CRITICAL GUARD: iCloud / Google Sign-Out Check (Only when required)
            if (_requiresFrpCheck)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _icloudRemoved ? AppColors.successLight : AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _icloudRemoved ? AppColors.success : AppColors.danger,
                    width: 1.5,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _icloudRemoved ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
                          color: _icloudRemoved ? AppColors.success : AppColors.danger,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'iCLOUD / GOOGLE FRP GUARD (WAJIB)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Akun iCloud / Apple ID / Google telah logout & Find My dinonaktifkan',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      value: _icloudRemoved,
                      onChanged: (val) => setState(() => _icloudRemoved = val),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Perangkat non-smartphone: Bebas akun iCloud / Google FRP Lock.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // Physical Condition Checklist
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'INSPEKSI KONDISI FISIK & KELENGKAPAN',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: ['A', 'B', 'C'].map((grade) {
                      final isSel = _conditionGrade == grade;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text('Grade $grade'),
                          selected: isSel,
                          onSelected: (_) => setState(() => _conditionGrade = grade),
                          selectedColor: AppColors.obsidian,
                          labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Layar sentuh & kamera berfungsi normal', style: TextStyle(fontSize: 13)),
                    value: _screenOk,
                    onChanged: (v) => setState(() => _screenOk = v ?? false),
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kabel charger dikembalikan', style: TextStyle(fontSize: 13)),
                    value: _cableReturned,
                    onChanged: (v) => setState(() => _cableReturned = v ?? false),
                  ),
                    CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Adaptor charger dikembalikan', style: TextStyle(fontSize: 13)),
                    value: _adapterReturned,
                    onChanged: (v) => setState(() => _adapterReturned = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Penalty Payment Section (Rendered when penalty > 0)
            if (penaltyAmount > 0) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.5), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, color: AppColors.danger, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'PEMBAYARAN DENDA (${CurrencyFormatter.format(penaltyAmount)})',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.danger,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ChoiceChip(
                          label: const Text('Bayar Sekarang di Counter'),
                          selected: _payPenaltyNow,
                          onSelected: (_) => setState(() => _payPenaltyNow = true),
                          selectedColor: AppColors.obsidian,
                          labelStyle: TextStyle(
                            color: _payPenaltyNow ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('Bayar Nanti di Kasir'),
                          selected: !_payPenaltyNow,
                          onSelected: (_) => setState(() => _payPenaltyNow = false),
                          selectedColor: AppColors.obsidian,
                          labelStyle: TextStyle(
                            color: !_payPenaltyNow ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _payPenaltyNow
                          ? 'Setelah inspeksi disimpan, sistem akan membuka Terminal Kasir POS untuk memproses & mencetak struk denda.'
                          : 'Denda akan dicatat sebagai tagihan belum lunas dan dapat diselesaikan di menu Kasir POS.',
                      style: TextStyle(
                        fontSize: 12,
                        color: _payPenaltyNow ? AppColors.textSecondary : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Submit Return
            ElevatedButton(
              onPressed: _isSubmitting ? null : () => _processReturn(penaltyAmount),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Selesaikan Pengembalian & Ambil KTP 📥'),
            ),
          ],
        ),
      ),
    );
  }

  void _processReturn(double penaltyAmount) async {
    if (_requiresFrpCheck && !_icloudRemoved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PERINGATAN: Akun iCloud / Apple ID / Google wajib dipastikan logout sebelum unit dapat diterima kembali!'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'condition_grade': _conditionGrade,
        'checklist_results': {
          if (_requiresFrpCheck) 'icloud_removed': _icloudRemoved,
          'screen_ok': _screenOk,
          'camera_ok': _cameraOk,
        },
        'accessories_returned': {
          'cable': _cableReturned,
          'adapter': _adapterReturned,
        },
      };

      await ref.read(bookingRepositoryProvider).processReturn(widget.booking['id'], payload);
      ref.invalidate(bookingsListProvider);
      ref.invalidate(closingSummaryProvider);

      if (!mounted) return;

      bool penaltyPaid = false;
      if (penaltyAmount > 0 && _payPenaltyNow) {
        // Launch Shared Payment Page for Authoritative Penalty Settlement
        final result = await Navigator.push<PaymentResult>(
          context,
          MaterialPageRoute(
            builder: (_) => PaymentPage(
              paymentContext: PaymentContext.penalty(
                booking: widget.booking,
                penaltyDue: penaltyAmount,
              ),
            ),
          ),
        );

        if (result != null && result.isSuccess) {
          penaltyPaid = true;
          ref.invalidate(bookingsListProvider);
          ref.invalidate(closingSummaryProvider);
        }
      }

      if (mounted) {
        _showReturnSuccessDialog(penaltyAmount, penaltyPaid);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memproses kembali: $e'), backgroundColor: AppColors.danger),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showReturnSuccessDialog(double penaltyAmount, bool penaltyPaid) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_rounded, color: AppColors.success),
            SizedBox(width: 8),
            Text('Unit Berhasil Kembali!'),
          ],
        ),
        content: Text(
          'Pemeriksaan pengembalian selesai.\n'
          'Unit kini siap disewakan kembali.\n'
          '${penaltyPaid ? 'Denda keterlambatan berhasil dibayar & tercatat di revenue.\n' : (penaltyAmount > 0 ? 'Denda keterlambatan dicatat ke kasir (belum lunas).\n' : '')}'
          'Silakan kembalikan KTP fisik kepada tamu.',
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 18),
            label: const Text('Cetak Bukti'),
            onPressed: () {
              final printerService = ThermalPrinterService();
              final printerSettings = ref.read(printerProvider).settings;
              final branchName = ref.read(businessProvider).activeBranchName ?? 'RentCore';
              final model = ReceiptDataModel(
                type: ReceiptType.rentalReturn,
                title: 'BUKTI PENGEMBALIAN UNIT',
                branchName: branchName,
                bookingCode: widget.booking['booking_code']?.toString() ?? '',
                customerName: widget.booking['customer']?['name']?.toString() ?? 'Pelanggan',
                unitName: widget.booking['asset']?['name']?.toString() ?? 'Perangkat Gadget',
                conditionGrade: 'Grade $_conditionGrade',
                checklistNotes: 'Screen: ${_screenOk ? "OK" : "Minus"} • Kamera: ${_cameraOk ? "OK" : "Minus"}',
                accessoriesNotes: 'Kabel: ${_cableReturned ? "OK" : "Kurang"} • Adaptor: ${_adapterReturned ? "OK" : "Kurang"}',
                penaltyAmount: penaltyPaid ? penaltyAmount : 0.0,
                paymentMethod: penaltyPaid ? 'Lunas Denda' : null,
                totalAmount: penaltyPaid ? penaltyAmount : 0.0,
                transactedAt: DateTime.now().toString().substring(0, 16),
              );
              final escposBytes = printerService.buildRentalReturnSlipBytes(model, printerSettings);
              showDialog(
                context: context,
                builder: (dCtx) => ThermalReceiptPreviewDialog(
                  title: 'Bukti Pengembalian',
                  branchName: branchName,
                  escposBytes: escposBytes,
                  qrData: widget.booking['booking_code']?.toString(),
                  content: Column(
                    children: [
                      const Text('BUKTI PENGEMBALIAN UNIT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text('Kode: ${widget.booking['booking_code'] ?? "-"}', style: const TextStyle(fontSize: 11)),
                      Text('Pelanggan: ${widget.booking['customer']?['name'] ?? "-"}', style: const TextStyle(fontSize: 11)),
                      Text('Kondisi: Grade $_conditionGrade', style: const TextStyle(fontSize: 11)),
                      const Divider(height: 16),
                      const Text('KTP Fisik Telah Diserahkan Kembali', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.success)),
                    ],
                  ),
                ),
              );
            },
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Selesai'),
          ),
        ],
      ),
    );
  }
}
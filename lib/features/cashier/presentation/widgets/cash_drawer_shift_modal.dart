import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/thermal_printer_models.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../../auth/providers/business_provider.dart';
import '../../../printer/providers/printer_provider.dart';
import '../../providers/cashier_provider.dart';

class CashDrawerShiftModal extends ConsumerStatefulWidget {
  final Map<String, dynamic>? activeShift;
  final double expectedDrawerCash;
  final int? branchId;
  final VoidCallback? onShiftUpdated;

  const CashDrawerShiftModal({
    super.key,
    this.activeShift,
    this.expectedDrawerCash = 0.0,
    this.branchId,
    this.onShiftUpdated,
  });

  @override
  ConsumerState<CashDrawerShiftModal> createState() => _CashDrawerShiftModalState();
}

class _CashDrawerShiftModalState extends ConsumerState<CashDrawerShiftModal> {
  final _formKey = GlobalKey<FormState>();

  // Open Shift Form
  final _floatController = TextEditingController(text: '500000');
  final _openNotesController = TextEditingController();

  // Close Shift Form (Denominations)
  final _count100kController = TextEditingController();
  final _count50kController = TextEditingController();
  final _count20kController = TextEditingController();
  final _count10kController = TextEditingController();
  final _count5kController = TextEditingController();
  final _count2kController = TextEditingController();
  final _coinController = TextEditingController();
  final _reasonController = TextEditingController();
  final _closeNotesController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  bool get _isOpenMode => widget.activeShift == null || widget.activeShift!['status'] != 'open';

  @override
  void dispose() {
    _floatController.dispose();
    _openNotesController.dispose();
    _count100kController.dispose();
    _count50kController.dispose();
    _count20kController.dispose();
    _count10kController.dispose();
    _count5kController.dispose();
    _count2kController.dispose();
    _coinController.dispose();
    _reasonController.dispose();
    _closeNotesController.dispose();
    super.dispose();
  }

  double get _actualCountedTotal {
    final c100 = (int.tryParse(_count100kController.text) ?? 0) * 100000.0;
    final c50 = (int.tryParse(_count50kController.text) ?? 0) * 50000.0;
    final c20 = (int.tryParse(_count20kController.text) ?? 0) * 20000.0;
    final c10 = (int.tryParse(_count10kController.text) ?? 0) * 10000.0;
    final c5 = (int.tryParse(_count5kController.text) ?? 0) * 5000.0;
    final c2 = (int.tryParse(_count2kController.text) ?? 0) * 2000.0;
    final coin = double.tryParse(_coinController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    return c100 + c50 + c20 + c10 + c5 + c2 + coin;
  }

  double get _effectiveExpectedCash {
    if (widget.activeShift != null && widget.activeShift!['expected_cash_now'] != null) {
      return CurrencyFormatter.parse(widget.activeShift!['expected_cash_now']);
    }
    return widget.expectedDrawerCash;
  }

  double get _cashDifference {
    return _actualCountedTotal - _effectiveExpectedCash;
  }

  bool get _hasDiscrepancy => _cashDifference.abs() > 5000.0;

  Future<void> _submitOpenShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(cashierRepositoryProvider);
      final rawFloat = double.tryParse(_floatController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

      await repo.openShift(
        openingCashFloat: rawFloat,
        branchId: widget.branchId,
        notes: _openNotesController.text.trim().isEmpty ? null : _openNotesController.text.trim(),
      );

      if (!mounted) return;

      ref.invalidate(currentShiftProvider);
      ref.invalidate(closingSummaryProvider);
      widget.onShiftUpdated?.call();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift kasir berhasil dibuka.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _submitCloseShift() async {
    if (!_formKey.currentState!.validate()) return;

    if (_actualCountedTotal <= 0 && _effectiveExpectedCash > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konfirmasi Kas Fisik 0'),
          content: const Text('Hasil hitung fisik uang kas bernilai Rp 0. Apakah Anda yakin ingin menutup shift ini?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(cashierRepositoryProvider);
      final shiftId = widget.activeShift?['id'];

      final result = await repo.closeShift(
        actualCashCounted: _actualCountedTotal,
        shiftId: shiftId is int ? shiftId : null,
        differenceReason: _hasDiscrepancy ? _reasonController.text.trim() : null,
        closingNotes: _closeNotesController.text.trim().isEmpty ? null : _closeNotesController.text.trim(),
        branchId: widget.branchId,
      );

      if (!mounted) return;

      ref.invalidate(currentShiftProvider);
      ref.invalidate(closingSummaryProvider);
      widget.onShiftUpdated?.call();

      Navigator.pop(context);

      // Offer printing shift closing receipt
      _showClosingPrintDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  void _showClosingPrintDialog(Map<String, dynamic> shiftData) {
    final shiftNum = shiftData['shift_number'] ?? 'SHF-CLOSING';
    final actual = CurrencyFormatter.parse(shiftData['actual_cash_counted']);
    final expected = CurrencyFormatter.parse(shiftData['expected_cash_total']);
    final diff = CurrencyFormatter.parse(shiftData['cash_difference']);

    final printerSettings = ref.read(printerProvider).settings;
    final printerService = ThermalPrinterService();

    final receiptData = ReceiptDataModel(
      type: ReceiptType.closingShift,
      title: 'LAPORAN REKAP TUTUP SHIFT',
      branchName: 'Cabang Mataram Central',
      receiptNumber: shiftNum,
      cashierName: 'Staff Kasir',
      totalAmount: actual,
      subtotal: expected,
      discount: diff,
      items: [
        {'name': 'Modal Awal Kas Laci', 'price': CurrencyFormatter.parse(shiftData['opening_cash_float'])},
        {'name': 'Kas Masuk Penjualan (Net)', 'price': CurrencyFormatter.parse(shiftData['cash_inflow'])},
        {'name': 'Pengeluaran Beban Laci', 'price': -CurrencyFormatter.parse(shiftData['cash_expenses'])},
        {'name': 'Fisik Kas Harus Ada', 'price': expected},
        {'name': 'Fisik Kas Hasil Hitung', 'price': actual},
        {'name': 'Selisih Kas (Variance)', 'price': diff},
      ],
      qrData: shiftNum,
    );

    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: 'Cabang Kasir',
      cashierName: 'Staff Kasir',
      date: DateTime.now().toString().substring(0, 16),
      totalTransactions: 1,
      totalRevenue: actual,
      paymentBreakdown: {
        'Modal Awal': CurrencyFormatter.parse(shiftData['opening_cash_float']),
        'Kas Masuk': CurrencyFormatter.parse(shiftData['cash_inflow']),
        'Beban Laci': -CurrencyFormatter.parse(shiftData['cash_expenses']),
        'Fisik Kas Dihitung': actual,
      },
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Struk Tutup Shift Kasir',
        branchName: 'Cabang Kasir',
        escposBytes: escposBytes,
        content: Column(
          children: [
            const Text('LAPORAN TUTUP SHIFT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            Text('No: $shiftNum', style: const TextStyle(fontSize: 11)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fisik Kas Dihitung:', style: TextStyle(fontSize: 11)),
                Text(CurrencyFormatter.format(actual), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Selisih Kas:', style: TextStyle(fontSize: 11)),
                Text(
                  CurrencyFormatter.format(diff),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: diff < 0 ? AppColors.danger : (diff > 0 ? AppColors.info : AppColors.success),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isOpenMode ? Icons.login_rounded : Icons.lock_clock_rounded,
                        color: AppColors.obsidian,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isOpenMode ? 'Buka Shift Kasir' : 'Tutup Shift & Rekonsiliasi Kas',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 16),

              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.dangerLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              if (_isOpenMode) _buildOpenShiftContent() else _buildCloseShiftContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenShiftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Masukkan jumlah uang tunai modal awal (opening float) yang ada di brankas/laci kasir sebelum memulai transaksi.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Modal Awal Kas Laci (Opening Float) *',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _floatController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            prefixText: 'Rp ',
            hintText: '500.000',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) return 'Modal awal wajib diisi.';
            return null;
          },
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [200000, 300000, 500000, 1000000].map((amt) {
            return ActionChip(
              label: Text(
                CurrencyFormatter.format(amt),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              onPressed: () {
                _floatController.text = amt.toString();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        const Text(
          'Catatan Pembukaan Shift (Opsional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _openNotesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Keterangan pembukaan shift...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.lock_open_rounded, size: 18),
          label: Text(
            _isLoading ? 'Membuka Shift...' : 'Buka Shift Kasir Sekarang',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _isLoading ? null : _submitOpenShift,
        ),
      ],
    );
  }

  Widget _buildCloseShiftContent() {
    final shiftNum = widget.activeShift?['shift_number'] ?? 'SHF-ACTIVE';
    final openedAt = widget.activeShift?['opened_at'] ?? '';
    final floatAmt = CurrencyFormatter.parse(widget.activeShift?['opening_cash_float']);
    final inflowAmt = widget.activeShift?['current_cash_inflow'] != null
        ? CurrencyFormatter.parse(widget.activeShift?['current_cash_inflow'])
        : 0.0;
    final refundAmt = widget.activeShift?['current_cash_refund'] != null
        ? CurrencyFormatter.parse(widget.activeShift?['current_cash_refund'])
        : 0.0;
    final expensesAmt = widget.activeShift?['current_cash_expenses'] != null
        ? CurrencyFormatter.parse(widget.activeShift?['current_cash_expenses'])
        : 0.0;
    final diff = _cashDifference;
    final isMatch = diff == 0.0;
    final isSurplus = diff > 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // System Expected Summary Card
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
                  Text(
                    shiftNum,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('SHIFT AKTIF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('Dibuka: $openedAt', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Modal Awal Laci', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  Text(CurrencyFormatter.format(floatAmt), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
              if (inflowAmt > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Kas Masuk Shift (Penjualan/Denda)', style: TextStyle(fontSize: 12, color: AppColors.success)),
                    Text('+${CurrencyFormatter.format(inflowAmt)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.success)),
                  ],
                ),
              ],
              if (refundAmt > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Pengembalian Kas (Refund)', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                    Text('-${CurrencyFormatter.format(refundAmt)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.danger)),
                  ],
                ),
              ],
              if (expensesAmt > 0) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Beban Pengeluaran Laci', style: TextStyle(fontSize: 12, color: AppColors.danger)),
                    Text('-${CurrencyFormatter.format(expensesAmt)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.danger)),
                  ],
                ),
              ],
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('FISIK KAS HARUS ADA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                  Text(
                    CurrencyFormatter.format(_effectiveExpectedCash),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Physical Cash Denomination Counter
        const Text(
          'HITUNG FISIK UANG KAS (DENOMINASI)',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 8),

        _buildDenominationRow('Rp 100.000', _count100kController, 100000),
        _buildDenominationRow('Rp  50.000', _count50kController, 50000),
        _buildDenominationRow('Rp  20.000', _count20kController, 20000),
        _buildDenominationRow('Rp  10.000', _count10kController, 10000),
        _buildDenominationRow('Rp   5.000', _count5kController, 5000),
        _buildDenominationRow('Rp   2.000', _count2kController, 2000),

        // Coin / Other Field
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const SizedBox(
                width: 90,
                child: Text('Koin / Lain', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _coinController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    prefixText: 'Rp ',
                    hintText: '0',
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 16),

        // Comparison Result Card
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isMatch
                ? AppColors.successLight
                : (isSurplus ? Colors.amber.withValues(alpha: 0.15) : AppColors.dangerLight),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isMatch ? AppColors.success : (isSurplus ? Colors.amber.shade700 : AppColors.danger),
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Fisik Hasil Hitung:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  Text(
                    CurrencyFormatter.format(_actualCountedTotal),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isMatch ? 'Status: SELISIH NIHIL (COCOK)' : (isSurplus ? 'Status: SELISIH LEBIH' : 'Status: SELISIH KURANG'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isMatch ? AppColors.success : (isSurplus ? Colors.amber.shade900 : AppColors.danger),
                    ),
                  ),
                  Text(
                    '${isSurplus ? '+' : ''}${CurrencyFormatter.format(diff)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isMatch ? AppColors.success : (isSurplus ? Colors.amber.shade900 : AppColors.danger),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Discrepancy Reason Field (mandatory if > 5000)
        if (_hasDiscrepancy) ...[
          const Text(
            'Alasan / Keterangan Selisih Kas *',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.danger),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: _reasonController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Jelaskan penyebab selisih uang kas fisik...',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            validator: (val) {
              if (_hasDiscrepancy && (val == null || val.trim().isEmpty)) {
                return 'Alasan selisih kas wajib diisi jika selisih > Rp 5.000.';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
        ],

        // Closing Notes
        const Text(
          'Catatan Rekap Closing (Opsional)',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _closeNotesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Catatan serah terima shift kasir...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _isLoading
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(
            _isLoading ? 'Menutup Shift...' : 'Tutup Shift & Rekapitulasi Kasir',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          onPressed: _isLoading ? null : _submitCloseShift,
        ),
      ],
    );
  }

  Widget _buildDenominationRow(String label, TextEditingController controller, int multiplier) {
    final count = int.tryParse(controller.text) ?? 0;
    final total = count * multiplier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 85,
            child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 75,
            child: TextFormField(
              controller: controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: '0',
                isDense: true,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),
          const Text('lbr =', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
          const Spacer(),
          Text(
            CurrencyFormatter.format(total.toDouble()),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

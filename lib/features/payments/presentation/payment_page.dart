import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/thermal_printer_models.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/cash_suggestion_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../data/payment_repository.dart';
import '../models/payment_context.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final PaymentContext paymentContext;
  final bool isModal;
  final VoidCallback? onPaymentSuccess;

  const PaymentPage({
    super.key,
    required this.paymentContext,
    this.isModal = false,
    this.onPaymentSuccess,
  });

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _cashReceivedController = TextEditingController();
  final _notesController = TextEditingController();

  int? _selectedMethodId;
  String _selectedMethodCode = 'CASH';
  String _selectedMethodName = 'Tunai';
  bool _nonCashConfirmed = true;
  bool _isProcessing = false;
  bool _methodInitialized = false;
  PaymentResult? _completedResult;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(() {
      if (mounted) setState(() {});
    });
    _cashReceivedController.text = widget.paymentContext.remainingDue.toInt().toString();
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.paymentContext;
    final amountDue = ctx.remainingDue;
    final isCash = _selectedMethodCode == 'CASH';

    final cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
    final cashShortage = isCash
        ? CashPaymentSuggestionHelper.calculateShortage(amountDue: amountDue, cashReceived: cashReceived)
        : 0.0;
    final cashChange = isCash
        ? CashPaymentSuggestionHelper.calculateChange(amountDue: amountDue, cashReceived: cashReceived)
        : 0.0;

    final isButtonEnabled = !_isProcessing &&
        (!isCash || cashShortage <= 0) &&
        (isCash || _nonCashConfirmed);

    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    // Initialize default payment method when methods load
    paymentMethodsAsync.whenData((methods) {
      if (!_methodInitialized && methods.isNotEmpty) {
        _methodInitialized = true;
        final cashMethod = methods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH').firstOrNull ?? methods.first;
        _selectedMethodId = cashMethod['id'] as int?;
        _selectedMethodCode = (cashMethod['code'] ?? 'CASH').toString().toUpperCase();
        _selectedMethodName = cashMethod['name'] ?? 'Tunai';
      }
    });

    final content = SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Drag handle for modal sheet
          if (widget.isModal) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // 2. Header: TERMINAL KASIR POS & Booking Code / Type
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'TERMINAL KASIR POS',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                  ),
                  Text(
                    ctx.bookingCode ?? ctx.transactionTypeTitle,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  Navigator.pop(context, const PaymentResult(status: PaymentStatus.cancelled));
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Transaction Summary Card
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _getBadgeBackgroundColor(ctx.transactionType),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            ctx.typeBadgeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _getBadgeTextColor(ctx.transactionType),
                            ),
                          ),
                        ),
                        if (ctx.bookingCode != null) ...[
                          const SizedBox(width: 8),
                          Text(
                            ctx.bookingCode!,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                    if (ctx.branchName != null && ctx.branchName!.isNotEmpty)
                      Text(
                        ctx.branchName!,
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.customerName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (ctx.customerPhone != null && ctx.customerPhone!.isNotEmpty)
                      Text(
                        ctx.customerPhone!,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                  ],
                ),
                if (ctx.customerAddress != null && ctx.customerAddress!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Alamat: ${ctx.customerAddress!}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (ctx.deviceName != null && ctx.deviceName!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    ctx.assetCode != null && ctx.assetCode!.isNotEmpty
                        ? '${ctx.deviceName} (${ctx.assetCode})'
                        : ctx.deviceName!,
                    style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Tagihan', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text(
                      CurrencyFormatter.format(ctx.totalAmountDue),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                if (ctx.previouslyPaidAmount > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Sudah Terbayar', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      Text(
                        CurrencyFormatter.format(ctx.previouslyPaidAmount),
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      ctx.transactionType == PaymentTransactionType.penalty
                          ? 'SISA DENDA HARUS DIBAYAR'
                          : 'SISA TAGIHAN SEWA',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.danger),
                    ),
                    Text(
                      CurrencyFormatter.format(amountDue),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        color: amountDue > 0 ? AppColors.danger : AppColors.success,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Payment Method Selector
          const Text(
            'PILIH METODE PEMBAYARAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),

          paymentMethodsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal: $e'),
            data: (methods) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: methods.map((m) {
                final mId = m['id'] as int;
                final isSelected = (_selectedMethodId == mId) ||
                    (_selectedMethodId == null && (m['code'] ?? '').toString().toUpperCase() == 'CASH');
                final mCode = (m['code'] ?? 'CASH').toString().toUpperCase();
                final mName = m['name'] ?? mCode;

                return ChoiceChip(
                  label: Text(mName),
                  selected: isSelected,
                  onSelected: (_) {
                    setState(() {
                      _selectedMethodId = mId;
                      _selectedMethodCode = mCode;
                      _selectedMethodName = mName;
                      if (mCode == 'CASH') {
                        _cashReceivedController.text = amountDue.toInt().toString();
                      }
                    });
                  },
                  selectedColor: AppColors.obsidian,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // 5. Cash Input & Real-Time Change / Suggestions (Only if CASH)
          if (isCash) ...[
            TextField(
              controller: _cashReceivedController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Jumlah Uang Diterima (Rp)',
                hintText: 'Nominal tunai pelanggan',
                prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  tooltip: 'Uang Pas',
                  onPressed: () {
                    _cashReceivedController.text = amountDue.toInt().toString();
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Cash Denomination Dynamic Suggestions
            Builder(
              builder: (context) {
                final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(amountDue);
                if (suggestions.isEmpty) return const SizedBox.shrink();

                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: suggestions.map((amt) {
                    final isExact = amt == amountDue.toInt();
                    return ActionChip(
                      label: Text(
                        CurrencyFormatter.format(amt),
                        style: const TextStyle(fontSize: 11),
                      ),
                      tooltip: isExact ? 'Uang Pas' : null,
                      onPressed: () {
                        _cashReceivedController.text = amt.toString();
                      },
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 12),

            // Change / Shortage Container
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cashShortage > 0 ? AppColors.dangerLight : AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        cashShortage > 0 ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                        color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        cashShortage > 0 ? 'Kekurangan Uang:' : 'Kembalian Pelanggan:',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    CurrencyFormatter.format(cashShortage > 0 ? cashShortage : cashChange),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: cashShortage > 0 ? AppColors.danger : AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Non-Cash Confirmation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _nonCashConfirmed,
                    activeColor: AppColors.obsidian,
                    onChanged: (val) {
                      setState(() => _nonCashConfirmed = val ?? false);
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Konfirmasi pembayaran non-tunai (QRIS / Transfer) telah diverifikasi dan masuk.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // Optional Notes
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Catatan (Opsional)',
              hintText: 'Contoh: Titipan DP, bayar tunai di counter',
              prefixIcon: Icon(Icons.edit_note_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 20),

          // PROCESS PAYMENT BUTTON
          ElevatedButton(
            onPressed: isButtonEnabled ? () => _processPayment(amountDue) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _getButtonColor(ctx.transactionType),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    isCash && cashShortage > 0
                        ? 'Uang Tunai Kurang (${CurrencyFormatter.format(cashShortage)})'
                        : 'Konfirmasi Bayar (${CurrencyFormatter.format(amountDue)}) 🖨️',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                  ),
          ),
        ],
      ),
    );

    final Widget contentBody = _completedResult != null
        ? _buildSuccessView(context, _completedResult!)
        : content;

    if (widget.isModal) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: contentBody,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(ctx.transactionTypeTitle),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: _completedResult != null ? 'Tutup' : 'Batalkan Pembayaran',
          onPressed: () {
            Navigator.pop(
              context,
              _completedResult ?? const PaymentResult(status: PaymentStatus.cancelled),
            );
          },
        ),
      ),
      body: contentBody,
    );
  }

  Color _getBadgeBackgroundColor(PaymentTransactionType type) {
    switch (type) {
      case PaymentTransactionType.booking:
        return AppColors.infoLight;
      case PaymentTransactionType.settlement:
        return AppColors.successLight;
      case PaymentTransactionType.penalty:
        return Colors.deepOrange.withValues(alpha: 0.15);
      case PaymentTransactionType.extension:
        return AppColors.warningLight;
    }
  }

  Color _getBadgeTextColor(PaymentTransactionType type) {
    switch (type) {
      case PaymentTransactionType.booking:
        return AppColors.info;
      case PaymentTransactionType.settlement:
        return AppColors.success;
      case PaymentTransactionType.penalty:
        return Colors.deepOrange.shade800;
      case PaymentTransactionType.extension:
        return AppColors.warning;
    }
  }

  Color _getButtonColor(PaymentTransactionType type) {
    switch (type) {
      case PaymentTransactionType.penalty:
        return Colors.deepOrange.shade800;
      default:
        return AppColors.obsidian;
    }
  }

  Future<void> _processPayment(double amountDue) async {
    setState(() => _isProcessing = true);

    try {
      final isCash = _selectedMethodCode == 'CASH';
      final cashReceived = isCash
          ? CurrencyFormatter.parse(_cashReceivedController.text)
          : amountDue;

      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.executePayment(
        context: widget.paymentContext,
        paymentMethodId: _selectedMethodId ?? 1,
        paymentMethodCode: _selectedMethodCode,
        paymentMethodName: _selectedMethodName,
        amountToPay: amountDue,
        cashReceived: cashReceived,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      widget.onPaymentSuccess?.call();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _completedResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pembayaran: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted && _completedResult == null) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Widget _buildSuccessView(BuildContext context, PaymentResult result) {
    final ctx = widget.paymentContext;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.isModal) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pembayaran Berhasil Dicatat!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.obsidian),
          ),
          const SizedBox(height: 6),
          Text(
            'Transaksi ${ctx.transactionTypeTitle} berhasil diselesaikan.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.receiptNumber != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('No. Struk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(result.receiptNumber!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Metode Pembayaran', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(result.paymentMethodName ?? _selectedMethodName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Dibayar', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(CurrencyFormatter.format(result.amountPaid), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.obsidian)),
                  ],
                ),
                if (result.cashReceived > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tunai Diterima', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(result.cashReceived), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                      Text(CurrencyFormatter.format(result.cashChange), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Cetak Struk Transaksi (ESC/POS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () => _printPaymentReceipt(result),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () => Navigator.pop(context, result),
          ),
        ],
      ),
    );
  }

  void _printPaymentReceipt(PaymentResult result) {
    try {
      final printerService = ThermalPrinterService();
      final printerSettings = ref.read(printerProvider).settings;
      final ctx = widget.paymentContext;

      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: ctx.branchName ?? 'RentCore Central Hub',
        receiptNumber: result.receiptNumber,
        bookingCode: ctx.bookingCode,
        customerName: ctx.customerName,
        customerPhone: ctx.customerPhone,
        cashierName: 'Kasir RentCore',
        unitName: ctx.deviceName,
        totalAmount: result.amountPaid,
        paymentMethod: result.paymentMethodName ?? _selectedMethodName,
        cashReceived: result.cashReceived,
        cashChange: result.cashChange,
        transactedAt: DateTime.now().toString().substring(0, 16),
      );

      final escposBytes = printerService.buildPosPaymentSlipBytes(model, printerSettings);

      showDialog(
        context: context,
        builder: (dCtx) => ThermalReceiptPreviewDialog(
          title: 'Struk Pembayaran POS',
          branchName: ctx.branchName ?? 'RentCore',
          escposBytes: escposBytes,
          content: Column(
            children: [
              Text(ctx.transactionTypeTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('No: ${result.receiptNumber ?? "-"}', style: const TextStyle(fontSize: 11)),
              Text('Pelanggan: ${ctx.customerName}', style: const TextStyle(fontSize: 11)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bayar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(CurrencyFormatter.format(result.amountPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencetak struk: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}

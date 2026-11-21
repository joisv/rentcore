import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/models/thermal_printer_models.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/business_provider.dart';
import '../../../printer/providers/printer_provider.dart';
import '../../data/cashier_repository.dart';
import '../../providers/cashier_provider.dart';

enum CashCountMode {
  denominations,
  directTotal,
}

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
  ConsumerState<CashDrawerShiftModal> createState() =>
      _CashDrawerShiftModalState();
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

  // Direct Lump-sum Mode
  final _directTotalController = TextEditingController();

  // Focus Nodes for auto-selection
  final _count100kFocus = FocusNode();
  final _count50kFocus = FocusNode();
  final _count20kFocus = FocusNode();
  final _count10kFocus = FocusNode();
  final _count5kFocus = FocusNode();
  final _count2kFocus = FocusNode();
  final _coinFocus = FocusNode();
  final _directTotalFocus = FocusNode();
  final _reasonFocus = FocusNode();
  final _reasonFieldKey = GlobalKey();

  CashCountMode _countMode = CashCountMode.denominations;

  bool _isLoading = false;
  bool _serverRequiresReason = false;
  String? _errorMessage;

  bool get _isOpenMode =>
      widget.activeShift == null || widget.activeShift!['status'] != 'open';

  @override
  void initState() {
    super.initState();
    _setupAutoSelectFocus(_count100kFocus, _count100kController);
    _setupAutoSelectFocus(_count50kFocus, _count50kController);
    _setupAutoSelectFocus(_count20kFocus, _count20kController);
    _setupAutoSelectFocus(_count10kFocus, _count10kController);
    _setupAutoSelectFocus(_count5kFocus, _count5kController);
    _setupAutoSelectFocus(_count2kFocus, _count2kController);
    _setupAutoSelectFocus(_coinFocus, _coinController);
    _setupAutoSelectFocus(_directTotalFocus, _directTotalController);
  }

  void _setupAutoSelectFocus(
    FocusNode focusNode,
    TextEditingController controller,
  ) {
    focusNode.addListener(() {
      if (focusNode.hasFocus && controller.text.isNotEmpty) {
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
      }
    });
  }

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
    _directTotalController.dispose();

    _count100kFocus.dispose();
    _count50kFocus.dispose();
    _count20kFocus.dispose();
    _count10kFocus.dispose();
    _count5kFocus.dispose();
    _count2kFocus.dispose();
    _coinFocus.dispose();
    _directTotalFocus.dispose();
    _reasonFocus.dispose();
    super.dispose();
  }

  double get _actualDenominationTotal {
    final c100 = (int.tryParse(_count100kController.text) ?? 0) * 100000.0;
    final c50 = (int.tryParse(_count50kController.text) ?? 0) * 50000.0;
    final c20 = (int.tryParse(_count20kController.text) ?? 0) * 20000.0;
    final c10 = (int.tryParse(_count10kController.text) ?? 0) * 10000.0;
    final c5 = (int.tryParse(_count5kController.text) ?? 0) * 5000.0;
    final c2 = (int.tryParse(_count2kController.text) ?? 0) * 2000.0;
    final coin =
        double.tryParse(
          _coinController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0.0;

    return c100 + c50 + c20 + c10 + c5 + c2 + coin;
  }

  double get _actualCountedTotal {
    if (_countMode == CashCountMode.directTotal) {
      return double.tryParse(
            _directTotalController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0.0;
    }
    return _actualDenominationTotal;
  }

  bool _isDifferenceReasonError(Object error) {
    if (error is CashierApiException) {
      if (error.requiresDifferenceReason) return true;
      final msg = error.message.toLowerCase();
      return msg.contains('difference_reason') ||
          msg.contains('alasan selisih') ||
          msg.contains('selisih');
    }
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        if (data['requires_difference_reason'] == true) {
          return true;
        }
        final errors = data['errors'];
        if (errors is Map && errors.containsKey('difference_reason')) {
          return true;
        }
        final msg = data['message']?.toString().toLowerCase() ?? '';
        if (msg.contains('difference_reason') ||
            msg.contains('alasan selisih') ||
            msg.contains('selisih')) {
          return true;
        }
      }
    }
    final raw = error.toString().toLowerCase();
    return raw.contains('difference_reason') || raw.contains('alasan selisih');
  }

  String _formatErrorMessage(Object error) {
    return ApiClient.extractErrorMessage(error);
  }

  String _formatOpenedAt(dynamic openedAt) {
    if (openedAt == null || openedAt.toString().trim().isEmpty) return '-';
    final raw = openedAt.toString().trim();
    if (raw.endsWith('WIB')) return raw;
    final dt = openedAt is DateTime
        ? openedAt.toLocal()
        : DateTime.tryParse(raw)?.toLocal();
    if (dt == null) return raw;
    return '${DateFormatter.formatFull(dt)} WIB';
  }

  Future<void> _submitOpenShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(cashierRepositoryProvider);
      final rawFloat =
          double.tryParse(
            _floatController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0.0;

      await repo.openShift(
        openingCashFloat: rawFloat,
        branchId: widget.branchId,
        notes: _openNotesController.text.trim().isEmpty
            ? null
            : _openNotesController.text.trim(),
      );

      if (!mounted) return;

      ref.invalidate(currentShiftProvider);
      ref.invalidate(closingSummaryProvider);
      ref.invalidate(shiftHistoryProvider);
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
        _errorMessage = _formatErrorMessage(e);
      });
    }
  }

  Future<void> _submitCloseShift() async {
    if (!_formKey.currentState!.validate()) return;

    if (_actualCountedTotal <= 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Konfirmasi Kas Fisik 0'),
          content: const Text(
            'Hasil hitung fisik uang kas bernilai Rp 0. Apakah Anda yakin ingin menutup shift ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjutkan'),
            ),
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
      final reasonText = _reasonController.text.trim();
      final notesText = _closeNotesController.text.trim();

      final result = await repo.closeShift(
        actualCashCounted: _actualCountedTotal,
        shiftId: shiftId is int ? shiftId : null,
        differenceReason: reasonText.isEmpty ? null : reasonText,
        closingNotes: notesText.isEmpty ? null : notesText,
        branchId: widget.branchId,
      );

      if (!mounted) return;

      ref.invalidate(currentShiftProvider);
      ref.invalidate(closingSummaryProvider);
      ref.invalidate(shiftHistoryProvider);
      widget.onShiftUpdated?.call();

      Navigator.pop(context);

      // Offer printing shift closing receipt with post-close system comparison
      _showClosingPrintDialog(result);
    } catch (e) {
      if (!mounted) return;
      final requiresReason = _isDifferenceReasonError(e);
      setState(() {
        _isLoading = false;
        if (requiresReason) {
          _serverRequiresReason = true;
          _errorMessage = _formatErrorMessage(e);
        } else {
          _errorMessage = _formatErrorMessage(e);
        }
      });
      if (requiresReason) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final reasonContext = _reasonFieldKey.currentContext;
          if (reasonContext != null) {
            Scrollable.ensureVisible(
              reasonContext,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            );
          }
          _reasonFocus.requestFocus();
        });
      }
    }
  }

  Widget _buildPostCloseComparisonRow(
    String label,
    double amount, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showClosingPrintDialog(Map<String, dynamic> shiftData) {
    final shiftNum = (shiftData['shift_number'] ?? widget.activeShift?['shift_number'] ?? 'SHF-CLOSING').toString();
    final openingFloat = CurrencyFormatter.parse(
      shiftData['opening_cash_float'],
    );
    final cashInflow = CurrencyFormatter.parse(shiftData['cash_inflow']);
    final cashOutflow = CurrencyFormatter.parse(
      shiftData['cash_outflow'] ?? shiftData['cash_refund'],
    );
    final nonCashInflow = CurrencyFormatter.parse(shiftData['non_cash_inflow']);
    final cashExpenses = CurrencyFormatter.parse(shiftData['cash_expenses']);
    final totalCashOut = cashOutflow + cashExpenses;
    final actual = CurrencyFormatter.parse(shiftData['actual_cash_counted']);
    final expected = CurrencyFormatter.parse(shiftData['expected_cash_total']);
    final diff = CurrencyFormatter.parse(shiftData['cash_difference']);
    final String diffStatusLabel = diff == 0
        ? 'Pas'
        : (diff < 0 ? 'Kurang' : 'Lebih');
    final totalTx = int.tryParse(shiftData['total_transactions']?.toString() ?? '') ?? 0;

    final authUser = ref.exists(authProvider) ? ref.read(authProvider).user : null;
    final bizState = ref.exists(businessProvider) ? ref.read(businessProvider) : null;
    final printerSettings = ref.read(printerProvider).settings;

    final resolvedBranchName = (shiftData['branch_name'] ??
            widget.activeShift?['branch_name'] ??
            bizState?.activeBranchName ??
            authUser?['affiliate']?['name'] ??
            'Cabang Utama')
        .toString();
    final resolvedCashierName = (shiftData['closed_by_name'] ??
            shiftData['opened_by_name'] ??
            widget.activeShift?['opened_by_name'] ??
            authUser?['name'] ??
            'Kasir Bertugas')
        .toString();
    final openedAtFormatted = _formatOpenedAt(
      shiftData['opened_at'] ?? widget.activeShift?['opened_at'],
    );
    final closedAtFormatted = _formatOpenedAt(shiftData['closed_at']);

    final printerService = ThermalPrinterService();
    final shopName = bizState?.resolvedStoreName ?? '';
    final branchAddress = bizState?.resolvedBranchAddress ?? '';
    final branchPhone = bizState?.resolvedBranchPhone ?? '';
    final breakdown = <String, double>{
      'Tunai (Net)': cashInflow,
      if (nonCashInflow > 0) 'Non-Tunai': nonCashInflow,
    };

    final escposBytes = printerService.buildClosingShiftSlipBytes(
      branchName: resolvedBranchName,
      cashierName: resolvedCashierName,
      date: DateTime.now().toLocal().toString().substring(0, 16),
      totalTransactions: totalTx,
      totalRevenue: cashInflow + nonCashInflow,
      paymentBreakdown: breakdown,
      paperWidth: printerSettings.paperWidth,
      openedAt: openedAtFormatted == '-' ? null : openedAtFormatted,
      closedAt: closedAtFormatted == '-' ? null : closedAtFormatted,
      openingCashFloat: openingFloat > 0 ? openingFloat : null,
      netCashRevenue: cashInflow,
      nonCashInflow: nonCashInflow > 0 ? nonCashInflow : null,
      cashDrawerExpenses: cashExpenses > 0 ? cashExpenses : null,
      expectedCashInDrawer: expected,
      actualCashCounted: actual,
      cashDifference: diff,
      shiftNumber: shiftNum,
      shopName: shopName.isNotEmpty ? shopName : null,
      branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
      branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
      settings: printerSettings,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Hasil Rekonsiliasi Tutup Shift',
        shopName: shopName.isNotEmpty ? shopName : null,
        branchName: resolvedBranchName,
        branchAddress: branchAddress.isNotEmpty ? branchAddress : null,
        branchPhone: branchPhone.isNotEmpty ? branchPhone : null,
        escposBytes: escposBytes,
        content: Column(
          children: [
            const Text(
              'HASIL REKONSILIASI TUTUP SHIFT',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Text('No: $shiftNum', style: const TextStyle(fontSize: 11)),
            const Divider(height: 16),
            _buildPostCloseComparisonRow('Modal Awal Laci:', openingFloat),
            const SizedBox(height: 4),
            _buildPostCloseComparisonRow('Penerimaan Tunai:', cashInflow),
            const SizedBox(height: 4),
            _buildPostCloseComparisonRow(
              'Pengeluaran/Refund Tunai:',
              totalCashOut > 0 ? -totalCashOut : 0.0,
              valueColor: totalCashOut > 0 ? AppColors.danger : null,
            ),
            const Divider(height: 12),
            _buildPostCloseComparisonRow(
              'Ekspektasi Kas Sistem:',
              expected,
              isBold: true,
            ),
            const SizedBox(height: 4),
            _buildPostCloseComparisonRow(
              'Uang Fisik Dihitung:',
              actual,
              isBold: true,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Selisih Kas ($diffStatusLabel):',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.format(diff),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: diff < 0
                          ? AppColors.danger
                          : (diff > 0 ? AppColors.info : AppColors.success),
                    ),
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              _buildHeader(),
              const Divider(height: 1),

              // Error banner if any
              if (_errorMessage != null) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],

              // Middle Scrollable Content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: _isOpenMode
                      ? _buildOpenShiftContent()
                      : _buildCloseShiftMiddleContent(),
                ),
              ),

              // Sticky Footer Container
              if (!_isOpenMode)
                _buildStickyCloseFooter()
              else
                _buildStickyOpenFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final shiftNum = widget.activeShift?['shift_number'] ?? 'SHF-ACTIVE';
    final openedAt = widget.activeShift?['opened_at'];
    final formattedOpenedAt = _formatOpenedAt(openedAt);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Row(
              children: [
                Icon(
                  _isOpenMode
                      ? Icons.login_rounded
                      : Icons.lock_clock_rounded,
                  color: AppColors.obsidian,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isOpenMode
                            ? 'Buka Shift Kasir'
                            : 'Tutup Shift & Rekonsiliasi Kas',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: AppColors.obsidian,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (!_isOpenMode) ...[
                        const SizedBox(height: 2),
                        Text.rich(
                          TextSpan(
                            text: shiftNum,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(
                                text: ' • ',
                                style: TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                              TextSpan(
                                text: formattedOpenedAt != '-'
                                    ? 'Dibuka $formattedOpenedAt'
                                    : 'Shift Aktif',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            onPressed: () => Navigator.pop(context),
          ),
        ],
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
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Masukkan jumlah uang tunai modal awal (opening float) yang ada di brankas/laci kasir sebelum memulai transaksi.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        const Text(
          'Modal Awal Kas Laci (Opening Float) *',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Modal awal wajib diisi.';
            }
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
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              backgroundColor: AppColors.surfaceMuted,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              onPressed: () {
                _floatController.text = amt.toString();
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),

        const Text(
          'Catatan Pembukaan Shift (Opsional)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _openNotesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Keterangan pembukaan shift...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyOpenFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.obsidian,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          elevation: 0,
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.lock_open_rounded, size: 18),
        label: Text(
          _isLoading ? 'Membuka Shift...' : 'Buka Shift Kasir Sekarang',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        onPressed: _isLoading ? null : _submitOpenShift,
      ),
    );
  }

  Widget _buildCloseShiftMiddleContent() {
    final shiftNum = widget.activeShift?['shift_number'] ?? 'SHF-ACTIVE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Blind Close Notice Card (no expected cash / system totals exposed while open)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      shiftNum,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Shift Aktif',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 14),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.visibility_off_rounded,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mode Blind Close Aktif',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Mode True Blind Close: Hitung seluruh uang tunai fisik di laci. Target kas sistem baru ditampilkan setelah shift dikunci.',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Section Title
        const Text(
          'Hitung Fisik Uang Kas (Denominasi)',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: AppColors.textMuted,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(
          width: 0,
          height: 0,
          child: Text(
            'HITUNG FISIK UANG KAS (DENOMINASI)',
            style: TextStyle(fontSize: 0),
          ),
        ),
        const SizedBox(height: 8),

        // Dual Cash Count Toggle
        _buildModeToggle(),
        const SizedBox(height: 12),

        // Mode Content
        if (_countMode == CashCountMode.denominations) ...[
          _buildDenominationRow(
            'Rp 100.000',
            _count100kController,
            _count100kFocus,
            100000,
          ),
          _buildDenominationRow(
            'Rp  50.000',
            _count50kController,
            _count50kFocus,
            50000,
          ),
          _buildDenominationRow(
            'Rp  20.000',
            _count20kController,
            _count20kFocus,
            20000,
          ),
          _buildDenominationRow(
            'Rp  10.000',
            _count10kController,
            _count10kFocus,
            10000,
          ),
          _buildDenominationRow(
            'Rp   5.000',
            _count5kController,
            _count5kFocus,
            5000,
          ),
          _buildDenominationRow(
            'Rp   2.000',
            _count2kController,
            _count2kFocus,
            2000,
          ),
          _buildCoinRow(),
        ] else ...[
          _buildDirectTotalInput(),
        ],

        const SizedBox(height: 12),

        // Discrepancy Reason Field (shown when required by server during blind close)
        if (_serverRequiresReason) ...[
          Container(
            key: _reasonFieldKey,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.dangerLight.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.danger, width: 1.25),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Alasan Selisih Kas *',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _reasonController,
                  focusNode: _reasonFocus,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Jelaskan penyebab selisih uang kas fisik...',
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: AppColors.danger),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(
                        color: AppColors.danger,
                        width: 1.5,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                  validator: (val) {
                    if (_serverRequiresReason &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Alasan selisih kas wajib diisi sebelum mengirim ulang.';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Closing Notes
        const Text(
          'Catatan Rekap Closing (Opsional)',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _closeNotesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Catatan serah terima shift kasir...',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeToggle() {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_countMode != CashCountMode.denominations) {
                  setState(() {
                    _countMode = CashCountMode.denominations;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _countMode == CashCountMode.denominations
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _countMode == CashCountMode.denominations
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Hitung Lembaran',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _countMode == CashCountMode.denominations
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _countMode == CashCountMode.denominations
                        ? AppColors.obsidian
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (_countMode != CashCountMode.directTotal) {
                  setState(() {
                    _countMode = CashCountMode.directTotal;
                    if (_directTotalController.text.isEmpty &&
                        _actualDenominationTotal > 0) {
                      _directTotalController.text =
                          _actualDenominationTotal.toInt().toString();
                    }
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _countMode == CashCountMode.directTotal
                      ? AppColors.surface
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _countMode == CashCountMode.directTotal
                      ? [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  'Input Total Langsung',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: _countMode == CashCountMode.directTotal
                        ? FontWeight.w700
                        : FontWeight.w500,
                    color: _countMode == CashCountMode.directTotal
                        ? AppColors.obsidian
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectTotalInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Total Uang Fisik di Laci',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _directTotalController,
          focusNode: _directTotalFocus,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.obsidian,
          ),
          onTap: () {
            if (_directTotalController.text.isNotEmpty) {
              _directTotalController.selection = TextSelection(
                baseOffset: 0,
                extentOffset: _directTotalController.text.length,
              );
            }
          },
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.obsidian,
            ),
            hintText: '0',
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                color: AppColors.obsidian,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 6),
        const Text(
          'Masukkan total seluruh uang kas fisik yang ada di laci kasir.',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildDenominationRow(
    String label,
    TextEditingController controller,
    FocusNode focusNode,
    int multiplier,
  ) {
    final count = int.tryParse(controller.text) ?? 0;
    final total = count * multiplier;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Left: Denomination label
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Middle: Compact numeric input container (44px height, auto-select on focus)
          SizedBox(
            width: 70,
            height: 44,
            child: TextFormField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.obsidian,
              ),
              onTap: () {
                if (controller.text.isNotEmpty) {
                  controller.selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controller.text.length,
                  );
                }
              },
              decoration: InputDecoration(
                hintText: '0',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: AppColors.obsidian,
                    width: 1.5,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const SizedBox(width: 8),

          // Right: Auto-calculated total right-aligned
          Expanded(
            child: Text(
              CurrencyFormatter.format(total.toDouble()),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: total > 0 ? AppColors.obsidian : AppColors.textMuted,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoinRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 80,
            child: Text(
              'Koin / Lain',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextFormField(
                controller: _coinController,
                focusNode: _coinFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.obsidian,
                ),
                onTap: () {
                  if (_coinController.text.isNotEmpty) {
                    _coinController.selection = TextSelection(
                      baseOffset: 0,
                      extentOffset: _coinController.text.length,
                    );
                  }
                },
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                  hintText: '0',
                  hintStyle: const TextStyle(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: AppColors.obsidian,
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Uang Fisik yang Anda Hitung',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 2),
                Text(
                  'Rekap selisih dihitung oleh sistem saat Tutup Shift',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textMuted,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            CurrencyFormatter.format(_actualCountedTotal),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.obsidian,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyCloseFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border.withOpacity(0.8),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            offset: const Offset(0, -3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle_rounded, size: 18),
            label: Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 0,
                  height: 0,
                  child: Text(
                    'Tutup Shift & Rekapitulasi Kas',
                    style: TextStyle(fontSize: 0),
                  ),
                ),
                Text(
                  _isLoading
                      ? 'Menutup Shift...'
                      : 'Tutup Shift & Rekapitulasi Kasir',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            onPressed: _isLoading ? null : _submitCloseShift,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../providers/cashier_provider.dart';

/// Clean in-place modal bottom sheet for cashiers to quickly open an active shift
/// directly from the checkout or payment screen without losing cart / payment context.
class QuickOpenShiftModal extends ConsumerStatefulWidget {
  final int? branchId;
  final VoidCallback? onShiftOpened;

  const QuickOpenShiftModal({
    super.key,
    this.branchId,
    this.onShiftOpened,
  });

  /// Helper static method to display this modal bottom sheet cleanly.
  static Future<bool?> show(
    BuildContext context, {
    int? branchId,
    VoidCallback? onShiftOpened,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickOpenShiftModal(
        branchId: branchId,
        onShiftOpened: onShiftOpened,
      ),
    );
  }

  @override
  ConsumerState<QuickOpenShiftModal> createState() => _QuickOpenShiftModalState();
}

class _QuickOpenShiftModalState extends ConsumerState<QuickOpenShiftModal> {
  final _formKey = GlobalKey<FormState>();
  final _floatController = TextEditingController(text: '0');
  final _focusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  static const List<double> _quickAmounts = [0, 100000, 250000, 500000];

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _floatController.text.isNotEmpty) {
        _floatController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _floatController.text.length,
        );
      }
    });
  }

  @override
  void dispose() {
    _floatController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _formatInput(String raw) {
    final cleanDigits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isEmpty) {
      _floatController.value = const TextEditingValue(
        text: '0',
        selection: TextSelection.collapsed(offset: 1),
      );
      return;
    }
    final val = double.tryParse(cleanDigits) ?? 0.0;
    final formatted = CurrencyFormatter.format(val).replaceAll('Rp ', '').trim();
    _floatController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  void _setQuickAmount(double amount) {
    final formatted = amount == 0
        ? '0'
        : CurrencyFormatter.format(amount).replaceAll('Rp ', '').trim();
    _floatController.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
    setState(() {});
  }

  Future<void> _submitOpenShift() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(cashierRepositoryProvider);
      final rawDigits = _floatController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final rawFloat = double.tryParse(rawDigits) ?? 0.0;

      await repo.openShift(
        openingCashFloat: rawFloat,
        branchId: widget.branchId,
        notes: 'Dibuka via Quick-Open dari Layar Pembayaran',
      );

      if (!mounted) return;

      ref.invalidate(currentShiftProvider);
      ref.invalidate(closingSummaryProvider);
      ref.invalidate(shiftHistoryProvider);
      if (widget.branchId != null) {
        ref.invalidate(currentShiftByBranchProvider(widget.branchId));
      }

      widget.onShiftOpened?.call();

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shift kasir berhasil dibuka! Silakan lanjutkan konfirmasi pembayaran.'),
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag Handle Indicator
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title & Close Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Buka Shift Kasir',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF18181B),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Masukkan uang modal awal di laci kasir sebelum memulai transaksi.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                    splashRadius: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 16),

              // Error Banner (if any)
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Label: Modal Kas Awal (Rp)
              const Text(
                'Modal Kas Awal (Rp)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF18181B),
                ),
              ),
              const SizedBox(height: 8),

              // Currency Input
              TextFormField(
                key: const Key('quick_open_shift_float_input'),
                controller: _floatController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _formatInput,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF18181B),
                ),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF18181B),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF18181B), width: 1.5),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Modal kas awal tidak boleh kosong';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Quick Preset Chips
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _quickAmounts.map((amt) {
                  final label = amt == 0
                      ? 'Rp 0'
                      : CurrencyFormatter.format(amt).replaceAll('Rp ', '').trim();
                  final currentVal = double.tryParse(
                        _floatController.text.replaceAll(RegExp(r'[^0-9]'), ''),
                      ) ??
                      0.0;
                  final isSelected = (amt == currentVal);

                  return ChoiceChip(
                    label: Text(amt == 0 ? 'Rp 0' : 'Rp $label'),
                    selected: isSelected,
                    onSelected: (_) => _setQuickAmount(amt),
                    labelStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF334155),
                    ),
                    selectedColor: const Color(0xFF18181B),
                    backgroundColor: const Color(0xFFF1F5F9),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected ? const Color(0xFF18181B) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),

              const SizedBox(height: 24),

              // Primary Action Button: "Buka Shift & Lanjutkan Bayar"
              ElevatedButton(
                key: const Key('quick_open_shift_submit_button'),
                onPressed: _isLoading ? null : _submitOpenShift,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF18181B),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF18181B).withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Buka Shift & Lanjutkan Bayar',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

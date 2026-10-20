import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/currency_formatter.dart';

/// A thumb-friendly POS on-screen numeric keypad designed for counter ergonomics,
/// tablet displays, and handheld Android POS terminals (Sunmi, iMin, Pax).
class PosNumpad extends StatelessWidget {
  final TextEditingController? controller;
  final ValueChanged<String>? onInputChanged;
  final double? exactAmount;
  final List<int> quickAddAmounts;
  final bool showQuickAdd;
  final bool showExactAmountButton;

  const PosNumpad({
    super.key,
    this.controller,
    this.onInputChanged,
    this.exactAmount,
    this.quickAddAmounts = const [10000, 20000, 50000, 100000],
    this.showQuickAdd = true,
    this.showExactAmountButton = true,
  });

  void _handleDigit(String digit) {
    HapticFeedback.lightImpact();
    if (controller != null) {
      final currentText = controller!.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (currentText == '0' && digit != '0' && digit != '00') {
        controller!.text = digit;
      } else {
        controller!.text = currentText + digit;
      }
      onInputChanged?.call(controller!.text);
    }
  }

  void _handleBackspace() {
    HapticFeedback.lightImpact();
    if (controller != null) {
      final currentText = controller!.text.replaceAll(RegExp(r'[^0-9]'), '');
      if (currentText.isNotEmpty) {
        final updated = currentText.substring(0, currentText.length - 1);
        controller!.text = updated;
        onInputChanged?.call(updated);
      }
    }
  }

  void _handleClear() {
    HapticFeedback.mediumImpact();
    if (controller != null) {
      controller!.text = '';
      onInputChanged?.call('');
    }
  }

  void _handleQuickAdd(int amount) {
    HapticFeedback.lightImpact();
    if (controller != null) {
      final currentVal = CurrencyFormatter.parse(controller!.text);
      final nextVal = currentVal + amount;
      controller!.text = nextVal.toInt().toString();
      onInputChanged?.call(controller!.text);
    }
  }

  void _handleExactAmount() {
    HapticFeedback.selectionClick();
    if (controller != null && exactAmount != null) {
      controller!.text = exactAmount!.toInt().toString();
      onInputChanged?.call(controller!.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Quick Denominations Row & Exact Amount
          if (showQuickAdd || showExactAmountButton) ...[
            Row(
              children: [
                if (showExactAmountButton && exactAmount != null && exactAmount! > 0) ...[
                  Expanded(
                    flex: 2,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        backgroundColor: AppColors.obsidianLight.withValues(alpha: 0.05),
                        side: const BorderSide(color: AppColors.obsidian, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _handleExactAmount,
                      child: Text(
                        'Pas (${CurrencyFormatter.format(exactAmount!)})',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11, color: AppColors.obsidian),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                if (showQuickAdd)
                  ...quickAddAmounts.map((amt) {
                    final label = '+${amt >= 1000 ? '${amt ~/ 1000}k' : amt.toString()}';
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _handleQuickAdd(amt),
                          child: Text(
                            label,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 10),
          ],

          // 2. Numeric Keypad Grid
          Row(
            children: [
              _buildKey('1'),
              _buildKey('2'),
              _buildKey('3'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKey('4'),
              _buildKey('5'),
              _buildKey('6'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildKey('7'),
              _buildKey('8'),
              _buildKey('9'),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _buildActionKey(
                label: 'C',
                color: AppColors.danger,
                bgColor: AppColors.dangerLight,
                onTap: _handleClear,
              ),
              _buildKey('0'),
              _buildKey('00'),
              _buildActionKey(
                icon: Icons.backspace_outlined,
                color: AppColors.textPrimary,
                bgColor: AppColors.surfaceMuted,
                onTap: _handleBackspace,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKey(String digit) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: () => _handleDigit(digit),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Center(
              child: Text(
                digit,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.obsidian,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey({
    String? label,
    IconData? icon,
    required Color color,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, size: 20, color: color)
                  : Text(
                      label ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

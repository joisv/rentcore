import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/business_provider.dart';
import '../../providers/cashier_provider.dart';

class AddBranchExpenseModal extends ConsumerStatefulWidget {
  final int? branchId;
  final VoidCallback? onExpenseCreated;

  const AddBranchExpenseModal({
    super.key,
    this.branchId,
    this.onExpenseCreated,
  });

  @override
  ConsumerState<AddBranchExpenseModal> createState() => _AddBranchExpenseModalState();
}

class _AddBranchExpenseModalState extends ConsumerState<AddBranchExpenseModal> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _notesController = TextEditingController();
  final _pinController = TextEditingController();

  String _selectedCategory = 'operational';
  String _selectedPaymentSource = 'cash_drawer';
  bool _isLoading = false;
  String? _errorMessage;

  static const List<Map<String, String>> _categories = [
    {'key': 'operational', 'label': 'Operasional Toko'},
    {'key': 'utilities', 'label': 'Utilitas (Listrik/Air/WiFi)'},
    {'key': 'supplies', 'label': 'ATK & Cetak Struk'},
    {'key': 'maintenance', 'label': 'Servis Unit Gadget'},
    {'key': 'marketing', 'label': 'Marketing / Promo'},
    {'key': 'other', 'label': 'Lainnya'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  double get _currentAmount {
    final raw = _amountController.text.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(raw) ?? 0.0;
  }

  bool get _requiresManagerPin => _currentAmount > 100000.0;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final bizState = ref.read(businessProvider);
    final posBranchFilter = ref.read(posFilterBranchIdProvider);
    final int? effectiveBranch = widget.branchId ?? (posBranchFilter != -1 ? (posBranchFilter ?? bizState.activeBranchId) : bizState.activeBranchId);

    try {
      final repo = ref.read(cashierRepositoryProvider);
      await repo.createExpense(
        title: _titleController.text.trim(),
        amount: _currentAmount,
        category: _selectedCategory,
        paymentSource: _selectedPaymentSource,
        branchId: effectiveBranch,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        managerPin: _requiresManagerPin ? _pinController.text.trim() : null,
      );

      if (!mounted) return;

      ref.invalidate(closingSummaryProvider);
      ref.invalidate(cashierExpensesProvider);
      ref.invalidate(currentShiftProvider);

      widget.onExpenseCreated?.call();

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengeluaran cabang berhasil dicatat.'),
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

              // Title Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.receipt_long_rounded, color: AppColors.obsidian, size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Catat Pengeluaran Cabang',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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

              // Category Selector
              const Text(
                'Kategori Pengeluaran *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem(
                    value: c['key'],
                    child: Text(c['label']!, style: const TextStyle(fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 14),

              // Title Field
              const Text(
                'Judul / Keterangan Singkat *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'Contoh: Token Listrik PLN 100k, Kertas Struk, dll.',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Judul pengeluaran wajib diisi.';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // Nominal Field
              const Text(
                'Jumlah Nominal (IDR) *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  hintText: '0',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                onChanged: (_) => setState(() {}),
                validator: (_) {
                  if (_currentAmount <= 0) return 'Nominal pengeluaran harus lebih dari 0.';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [10000, 25000, 50000, 100000].map((amt) {
                  final label = '+${amt >= 1000 ? '${amt ~/ 1000}k' : amt.toString()}';
                  return ActionChip(
                    label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    backgroundColor: AppColors.surfaceMuted,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    onPressed: () {
                      final curr = _currentAmount;
                      final next = curr + amt;
                      _amountController.text = next.toInt().toString();
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Payment Source
              const Text(
                'Sumber Dana Pembayaran *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.point_of_sale_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Kas Laci (Drawer)', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      selected: _selectedPaymentSource == 'cash_drawer',
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedPaymentSource = 'cash_drawer');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.account_balance_rounded, size: 16),
                          SizedBox(width: 6),
                          Text('Transfer Bank', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      selected: _selectedPaymentSource == 'bank_transfer',
                      onSelected: (sel) {
                        if (sel) setState(() => _selectedPaymentSource = 'bank_transfer');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Manager PIN section if > 100k
              if (_requiresManagerPin) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.security_rounded, size: 18, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            'Otorisasi Manager Diperlukan',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.amber.shade900),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Pengeluaran di atas Rp 100.000 wajib diverifikasi dengan PIN Manager Cabang.',
                        style: TextStyle(fontSize: 11, color: Colors.amber.shade900),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pinController,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        decoration: InputDecoration(
                          hintText: 'Masukkan 6 digit PIN Manager',
                          filled: true,
                          fillColor: AppColors.surface,
                          counterText: '',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        validator: (val) {
                          if (_requiresManagerPin && (val == null || val.trim().isEmpty)) {
                            return 'PIN Manager wajib diisi untuk nominal > Rp 100.000.';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Notes
              const Text(
                'Catatan Tambahan (Opsional)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Keterangan tambahan...',
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isLoading
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Menyimpan...' : 'Simpan Pengeluaran',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                onPressed: _isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

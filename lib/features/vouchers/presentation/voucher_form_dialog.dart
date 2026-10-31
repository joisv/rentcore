import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/voucher_provider.dart';

class VoucherFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? voucher;
  final List<dynamic> branches;

  const VoucherFormDialog({
    super.key,
    this.voucher,
    required this.branches,
  });

  static Future<bool?> show(
    BuildContext context, {
    Map<String, dynamic>? voucher,
    required List<dynamic> branches,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoucherFormDialog(
        voucher: voucher,
        branches: branches,
      ),
    );
  }

  @override
  ConsumerState<VoucherFormDialog> createState() => _VoucherFormDialogState();
}

class _VoucherFormDialogState extends ConsumerState<VoucherFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _discountPercentController;
  late final TextEditingController _maxCapController;
  late final TextEditingController _minSpendController;
  late final TextEditingController _totalQuotaController;
  late final TextEditingController _customerQuotaController;

  late int? _selectedBranchId;
  late String _barcodeType;
  late DateTime _startDate;
  late DateTime _endDate;
  late bool _isActive;
  late bool _isUsed;
  String? _errorMessage;

  bool get isEditMode => widget.voucher != null;

  @override
  void initState() {
    super.initState();
    final v = widget.voucher;
    _isUsed = (v?['usage_count'] ?? 0) > 0;

    _codeController = TextEditingController(text: v?['code'] ?? _generateRandomCode());
    _nameController = TextEditingController(text: v?['name'] ?? '');
    _descController = TextEditingController(text: v?['description'] ?? '');
    
    final discountPercent = v?['discount_percentage'];
    _discountPercentController = TextEditingController(
      text: discountPercent != null ? CurrencyFormatter.parse(discountPercent).toStringAsFixed(0) : '15',
    );

    final maxCap = v?['max_discount_cap'];
    _maxCapController = TextEditingController(
      text: maxCap != null ? CurrencyFormatter.parse(maxCap).toStringAsFixed(0) : '',
    );

    final minSpend = v?['min_transaction_amount'];
    _minSpendController = TextEditingController(
      text: minSpend != null ? CurrencyFormatter.parse(minSpend).toStringAsFixed(0) : '300000',
    );

    final totalLimit = v?['usage_limit_total'];
    _totalQuotaController = TextEditingController(
      text: totalLimit != null ? totalLimit.toString() : '',
    );

    final custLimit = v?['usage_limit_per_customer'];
    _customerQuotaController = TextEditingController(
      text: custLimit != null ? custLimit.toString() : '1',
    );

    _selectedBranchId = v?['affiliate_id'] is int ? v!['affiliate_id'] : int.tryParse(v?['affiliate_id']?.toString() ?? '');
    _barcodeType = v?['barcode_type'] ?? 'qr_code';

    final startAtStr = v?['start_at'];
    _startDate = startAtStr != null ? DateTime.tryParse(startAtStr.toString()) ?? DateTime.now() : DateTime.now().subtract(const Duration(hours: 1));

    final endAtStr = v?['end_at'];
    _endDate = endAtStr != null ? DateTime.tryParse(endAtStr.toString()) ?? DateTime.now().add(const Duration(days: 30)) : DateTime.now().add(const Duration(days: 30));

    _isActive = v?['is_active'] ?? true;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _descController.dispose();
    _discountPercentController.dispose();
    _maxCapController.dispose();
    _minSpendController.dispose();
    _totalQuotaController.dispose();
    _customerQuotaController.dispose();
    super.dispose();
  }

  String _generateRandomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random();
    final randomString = List.generate(6, (index) => chars[random.nextInt(chars.length)]).join();
    return 'RC-VCR-$randomString';
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.obsidian,
              onPrimary: Colors.white,
              surface: AppColors.surface,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final payload = <String, dynamic>{
      'name': _nameController.text.trim(),
      'description': _descController.text.trim().isNotEmpty ? _descController.text.trim() : null,
      'min_transaction_amount': double.parse(_minSpendController.text.trim()),
      'max_discount_cap': _maxCapController.text.trim().isNotEmpty ? double.parse(_maxCapController.text.trim()) : null,
      'barcode_type': _barcodeType,
      'start_at': _startDate.toIso8601String(),
      'end_at': _endDate.toIso8601String(),
      'affiliate_id': _selectedBranchId,
      'usage_limit_total': _totalQuotaController.text.trim().isNotEmpty ? int.parse(_totalQuotaController.text.trim()) : null,
      'usage_limit_per_customer': int.tryParse(_customerQuotaController.text.trim()) ?? 1,
      'is_active': _isActive,
    };

    if (!isEditMode || !_isUsed) {
      payload['code'] = _codeController.text.trim().toUpperCase();
      payload['discount_percentage'] = double.parse(_discountPercentController.text.trim());
    }

    try {
      final notifier = ref.read(voucherProvider.notifier);
      if (isEditMode) {
        final id = widget.voucher!['id'] is int ? widget.voucher!['id'] : int.parse(widget.voucher!['id'].toString());
        await notifier.updateVoucher(id, payload);
      } else {
        await notifier.createVoucher(payload);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEditMode ? 'Voucher promo berhasil diperbarui!' : 'Voucher promo baru berhasil diterbitkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceAll('Exception: ', ''));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditMode ? 'Edit Voucher Promo' : 'Buat Voucher Promo Baru',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.danger, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 1. Voucher Code
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _codeController,
                      enabled: !_isUsed,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Kode Voucher *',
                        hintText: 'Contoh: RC-VCR-8921',
                        helperText: _isUsed ? 'Terkunci karena voucher telah digunakan' : null,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) {
                          return 'Kode voucher wajib diisi';
                        }
                        return null;
                      },
                    ),
                  ),
                  if (!_isUsed) ...[
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(80, 50),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        child: const Text('Acak', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _codeController.text = _generateRandomCode();
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // 2. Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Voucher *',
                  hintText: 'Contoh: Promo Spesial Weekend 15%',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Nama voucher wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 3. Description
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi Promo (Opsional)',
                  hintText: 'Contoh: Diskon khusus sewa minimal 1 hari.',
                ),
              ),
              const SizedBox(height: 14),

              // 4. Discount % & Max Cap
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountPercentController,
                      enabled: !_isUsed,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Diskon (%) *',
                        hintText: '15',
                        suffixText: '%',
                        helperText: _isUsed ? 'Terkunci (sudah dipakai)' : null,
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        final num = double.tryParse(val.trim());
                        if (num == null || num < 1 || num > 100) return '1 - 100%';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxCapController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Plafon Maksimal',
                        hintText: 'Tanpa batas',
                        prefixText: 'Rp ',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 5. Min Spend
              TextFormField(
                controller: _minSpendController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Minimal Transaksi *',
                  hintText: '300000',
                  prefixText: 'Rp ',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Minimal transaksi wajib diisi';
                  final num = double.tryParse(val.trim());
                  if (num == null || num < 0) return 'Nominal tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 14),

              // 6. Branch Scope Dropdown
              DropdownButtonFormField<int?>(
                isExpanded: true,
                initialValue: _selectedBranchId,
                decoration: const InputDecoration(
                  labelText: 'Cakupan Cabang Berlaku *',
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Semua Cabang', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  ...widget.branches.map((b) {
                    final id = b['id'] is int ? b['id'] as int : int.parse(b['id'].toString());
                    final name = b['name'] ?? 'Cabang $id';
                    final code = b['code'] ?? '';
                    return DropdownMenuItem<int?>(
                      value: id,
                      child: Text('[$code] $name'),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedBranchId = val),
              ),
              const SizedBox(height: 14),

              // 7. Validity Date Range
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                    color: AppColors.surface,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Periode Berlaku',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${dateFormat.format(_startDate)}  s/d  ${dateFormat.format(_endDate)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const Text(
                        'Ubah',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.obsidian),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 8. Usage Limits (Total Quota & Per-Customer)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _totalQuotaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kuota',
                        hintText: 'Tak terbatas',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _customerQuotaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Batas / Pelanggan *',
                        hintText: '1',
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        final num = int.tryParse(val.trim());
                        if (num == null || num < 1) return 'Min 1';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 9. Barcode Format Dropdown
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _barcodeType,
                decoration: const InputDecoration(
                  labelText: 'Format Barcode *',
                ),
                items: const [
                  DropdownMenuItem(value: 'qr_code', child: Text('QR Code')),
                  DropdownMenuItem(value: 'code128', child: Text('Barcode Garis (Code 128)')),
                  DropdownMenuItem(value: 'datamatrix', child: Text('DataMatrix')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _barcodeType = val);
                },
              ),
              const SizedBox(height: 14),

              // 10. Active status switch (Edit mode)
              if (isEditMode) ...[
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Status Voucher Aktif', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      _isActive ? 'Voucher dapat divalidasi dan digunakan saat sewa' : 'Voucher ditangguhkan (tidak dapat digunakan)',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    value: _isActive,
                    activeTrackColor: AppColors.obsidian,
                    onChanged: (val) => setState(() => _isActive = val),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              const SizedBox(height: 12),

              // Submit & Cancel
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _submit,
                      child: Text(isEditMode ? 'Simpan Perubahan' : 'Terbitkan Voucher'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

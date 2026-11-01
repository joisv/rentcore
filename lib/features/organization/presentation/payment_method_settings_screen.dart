import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../providers/organization_provider.dart';

class PaymentMethodSettingsScreen extends ConsumerStatefulWidget {
  const PaymentMethodSettingsScreen({super.key});

  @override
  ConsumerState<PaymentMethodSettingsScreen> createState() => _PaymentMethodSettingsScreenState();
}

class _PaymentMethodSettingsScreenState extends ConsumerState<PaymentMethodSettingsScreen> {
  int? _selectedBranchId;
  bool _isInitialized = false;
  bool _isSaving = false;

  // Configuration state
  bool _ewalletMasterEnabled = true;
  bool _shopeepayEnabled = true;
  bool _danaEnabled = true;
  bool _linkajaEnabled = true;
  bool _ovoEnabled = true;
  bool _qrisEnabled = true;
  bool _cashEnabled = true;
  bool _bankTransferEnabled = true;

  String? _qrisImageUrl;
  String? _newQrisBase64;
  XFile? _pickedQrisImage;
  Uint8List? _pickedQrisBytes;
  bool _removeQrisImage = false;

  void _populateFromConfig(Map<String, dynamic> data) {
    if (_isInitialized) return;
    _isInitialized = true;

    final config = (data['config'] as Map<String, dynamic>?) ?? {};
    _ewalletMasterEnabled = config['ewallet_enabled'] != false;

    final providers = (config['ewallet_providers'] as Map<String, dynamic>?) ?? {};
    _shopeepayEnabled = providers['shopeepay'] != false;
    _danaEnabled = providers['dana'] != false;
    _linkajaEnabled = providers['linkaja'] != false;
    _ovoEnabled = providers['ovo'] != false;

    _qrisEnabled = config['qris_statis_enabled'] != false;
    _cashEnabled = config['cash_enabled'] != false;
    _bankTransferEnabled = config['bank_transfer_enabled'] != false;
    _qrisImageUrl = config['qris_image_url'] as String?;
  }

  Future<void> _pickQrisImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final sizeInBytes = bytes.length;
      final maxBytes = 2 * 1024 * 1024; // 2MB

      if (sizeInBytes > maxBytes) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ukuran gambar melebihi batas 2MB. Harap pilih gambar lain.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      final ext = picked.name.split('.').last.toLowerCase();
      if (!['png', 'jpg', 'jpeg'].contains(ext)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Format gambar tidak didukung. Harap pilih file PNG atau JPG.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
        return;
      }

      setState(() {
        _pickedQrisImage = picked;
        _pickedQrisBytes = bytes;
        _newQrisBase64 = 'data:image/$ext;base64,${base64Encode(bytes)}';
        _removeQrisImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gambar "${picked.name}" berhasil dipilih. Klik "Simpan Pengaturan" untuk menerapkan.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memilih gambar: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showImageUploadDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner_rounded, color: AppColors.obsidian, size: 22),
            SizedBox(width: 8),
            Text('Unggah Gambar QRIS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan data gambar QRIS berupa Base64 URI atau pilih sampel barcode toko untuk demonstrasi kasir.',
              style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Data Gambar Base64',
                hintText: 'data:image/png;base64,iVBORw0KGgo...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text('Gunakan Sampel QRIS Toko', style: TextStyle(fontSize: 12)),
              onPressed: () {
                // Standard transparent 1x1 PNG data URI for quick test
                textController.text =
                    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final raw = textController.text.trim();
              if (raw.isNotEmpty) {
                setState(() {
                  _newQrisBase64 = raw;
                  _pickedQrisImage = null;
                  _pickedQrisBytes = null;
                  _removeQrisImage = false;
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Gunakan Gambar'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(cashierRepositoryProvider);

      if (_pickedQrisImage != null && _pickedQrisBytes != null) {
        final formData = FormData.fromMap({
          if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
          'ewallet_enabled': _ewalletMasterEnabled ? 1 : 0,
          'wallet_enable': _ewalletMasterEnabled ? 1 : 0,
          'ewallet_providers[shopeepay]': _shopeepayEnabled ? 1 : 0,
          'ewallet_providers[dana]': _danaEnabled ? 1 : 0,
          'ewallet_providers[linkaja]': _linkajaEnabled ? 1 : 0,
          'ewallet_providers[ovo]': _ovoEnabled ? 1 : 0,
          'qris_statis_enabled': _qrisEnabled ? 1 : 0,
          'cash_enabled': _cashEnabled ? 1 : 0,
          'bank_transfer_enabled': _bankTransferEnabled ? 1 : 0,
          if (_removeQrisImage) 'remove_qris_image': 1,
          'qris_image': MultipartFile.fromBytes(
            _pickedQrisBytes!,
            filename: _pickedQrisImage!.name,
          ),
        });
        await repo.updatePaymentSettings(formData);
      } else {
        final payload = <String, dynamic>{
          if (_selectedBranchId != null) 'branch_id': _selectedBranchId,
          'ewallet_enabled': _ewalletMasterEnabled,
          'wallet_enable': _ewalletMasterEnabled,
          'ewallet_providers': {
            'shopeepay': _shopeepayEnabled,
            'dana': _danaEnabled,
            'linkaja': _linkajaEnabled,
            'ovo': _ovoEnabled,
          },
          'qris_statis_enabled': _qrisEnabled,
          'cash_enabled': _cashEnabled,
          'bank_transfer_enabled': _bankTransferEnabled,
        };

        if (_removeQrisImage) {
          payload['remove_qris_image'] = true;
        } else if (_newQrisBase64 != null) {
          payload['qris_image_base64'] = _newQrisBase64;
        }

        await repo.updatePaymentSettings(payload);
      }

      // Invalidate relevant providers to force fresh refresh
      ref.invalidate(paymentSettingsProvider(_selectedBranchId));
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(paymentMethodsForBranchProvider(_selectedBranchId));

      setState(() {
        _isInitialized = false;
        _pickedQrisImage = null;
        _pickedQrisBytes = null;
        _newQrisBase64 = null;
        _removeQrisImage = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi metode pembayaran berhasil disimpan.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan pengaturan: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);
    final currentBiz = bState.currentBusiness;
    final userRole = currentBiz?['role']?.toString().toLowerCase() ?? user?['role']?.toString().toLowerCase() ?? '';
    final isSuperAdmin = user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final isOwnerOrAdmin = userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final branches = ref.watch(organizationProvider).branches;

    final settingsAsync = ref.watch(paymentSettingsProvider(_selectedBranchId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(
        title: 'Metode Pembayaran',
      ),
      bottomNavigationBar: isOwnerOrAdmin
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: SafeArea(
                child: ElevatedButton.icon(
                  key: const Key('save_payment_settings_button'),
                  onPressed: _isSaving ? null : _saveSettings,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline_rounded, size: 20),
                  label: Text(
                    _isSaving ? 'Menyimpan...' : 'Simpan Pengaturan',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                ),
              ),
            )
          : null,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text('Gagal memuat pengaturan:\n$err', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(paymentSettingsProvider(_selectedBranchId)),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          _populateFromConfig(data);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 1. Role Authorization Notice
              if (!isOwnerOrAdmin)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF59E0B)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pengaturan metode pembayaran hanya dapat diubah oleh Owner atau Admin. Anda melihat konfigurasi aktif ini dalam mode baca saja.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Branch Scope Selector
              if (branches.isNotEmpty) ...[
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
                      const Text(
                        'CAKUPAN CABANG',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedBranchId,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Semua Cabang (Standar Bisnis Pusat)', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          ...branches.map((b) {
                            final bId = b['id'] is int ? b['id'] as int : int.parse(b['id'].toString());
                            return DropdownMenuItem<int?>(
                              value: bId,
                              child: Text(b['name'] ?? 'Cabang #$bId'),
                            );
                          }),
                        ],
                        onChanged: isOwnerOrAdmin
                            ? (val) {
                                setState(() {
                                  _selectedBranchId = val;
                                  _isInitialized = false;
                                });
                              }
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 3. Static QRIS Card
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('QRIS Statis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              Text('Tampilkan barcode QR untuk pembayaran m-Banking/E-Wallet', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('qris_statis_toggle'),
                          value: _qrisEnabled,
                          activeThumbColor: AppColors.obsidian,
                          onChanged: isOwnerOrAdmin ? (val) => setState(() => _qrisEnabled = val) : null,
                        ),
                      ],
                    ),
                    if (_qrisEnabled) ...[
                      const Divider(height: 24),
                      const Text(
                        'GAMBAR KODE QRIS TOKO',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 10),
                      if (!_removeQrisImage && (_newQrisBase64 != null || _qrisImageUrl != null)) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                alignment: Alignment.center,
                                child: _pickedQrisBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(6),
                                        child: Image.memory(_pickedQrisBytes!, fit: BoxFit.contain),
                                      )
                                    : (_newQrisBase64 != null
                                        ? const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 32)
                                        : Image.network(
                                            _qrisImageUrl!,
                                            fit: BoxFit.contain,
                                            loadingBuilder: (context, child, loadingProgress) {
                                              if (loadingProgress == null) return child;
                                              return const Center(
                                                child: SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                                                ),
                                              );
                                            },
                                            errorBuilder: (_, _, _) => const Icon(Icons.qr_code_rounded, size: 36),
                                          )),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedQrisImage != null || _newQrisBase64 != null
                                          ? 'Gambar Baru Dipilih'
                                          : 'Gambar QRIS Aktif Tersimpan',
                                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _pickedQrisImage != null || _newQrisBase64 != null
                                          ? 'Klik "Simpan Pengaturan" untuk menerapkan gambar.'
                                          : 'Tampil di layar pembayaran kasir.',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(height: 8),
                                    if (isOwnerOrAdmin)
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                                            label: const Text('Ganti', style: TextStyle(fontSize: 11)),
                                            onPressed: _pickQrisImage,
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.danger,
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                            icon: const Icon(Icons.delete_outline_rounded, size: 14),
                                            label: const Text('Hapus', style: TextStyle(fontSize: 11)),
                                            onPressed: () => setState(() {
                                              _removeQrisImage = true;
                                              _newQrisBase64 = null;
                                              _pickedQrisImage = null;
                                              _pickedQrisBytes = null;
                                            }),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        InkWell(
                          onTap: isOwnerOrAdmin ? _pickQrisImage : null,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.cloud_upload_outlined, size: 36, color: AppColors.textSecondary),
                                const SizedBox(height: 8),
                                const Text(
                                  'Belum ada gambar barcode QRIS',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ketuk di sini untuk mengunggah gambar QRIS toko (PNG, JPG, maks. 2MB)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                                if (isOwnerOrAdmin) ...[
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed: _pickQrisImage,
                                    icon: const Icon(Icons.add_photo_alternate_rounded, size: 16),
                                    label: const Text('Pilih Gambar QRIS', style: TextStyle(fontSize: 12)),
                                  ),
                                  const SizedBox(height: 6),
                                  TextButton(
                                    onPressed: _showImageUploadDialog,
                                    child: const Text('Atau masukkan manual / sampel test', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 4. E-Wallet Card (Master Toggle + Sub-toggles)
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Dompet Digital (E-Wallet)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                              Text('Aktifkan semua e-wallet', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            ],
                          ),
                        ),
                        Switch(
                          key: const Key('ewallet_master_toggle'),
                          value: _ewalletMasterEnabled,
                          activeThumbColor: AppColors.obsidian,
                          onChanged: isOwnerOrAdmin ? (val) => setState(() => _ewalletMasterEnabled = val) : null,
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    const Text(
                      'PENYEDIA E-WALLET',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Preferensi pilihan masing-masing penyedia akan tetap tersimpan meskipun master toggle dimatikan.',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),

                    // ShopeePay
                    _buildProviderTile(
                      key: 'toggle_shopeepay',
                      name: 'ShopeePay',
                      subtitle: 'Pembayaran melalui saldo ShopeePay',
                      value: _shopeepayEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: true,
                      onChanged: (val) => setState(() => _shopeepayEnabled = val),
                    ),
                    const Divider(height: 16),

                    // DANA
                    _buildProviderTile(
                      key: 'toggle_dana',
                      name: 'DANA',
                      subtitle: 'Dompet digital DANA Indonesia',
                      value: _danaEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: true,
                      onChanged: (val) => setState(() => _danaEnabled = val),
                    ),
                    const Divider(height: 16),

                    // LinkAja
                    _buildProviderTile(
                      key: 'toggle_linkaja',
                      name: 'LinkAja',
                      subtitle: 'Layanan uang elektronik BUMN LinkAja',
                      value: _linkajaEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: true,
                      onChanged: (val) => setState(() => _linkajaEnabled = val),
                    ),
                    const Divider(height: 16),

                    // OVO
                    _buildProviderTile(
                      key: 'toggle_ovo',
                      name: 'OVO',
                      subtitle: 'Dompet digital OVO Grab / Tokopedia',
                      value: _ovoEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: true,
                      onChanged: (val) => setState(() => _ovoEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 5. Baseline Payment Methods (Tunai & Transfer)
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
                    const Text(
                      'METODE LAINNYA',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 12),
                    _buildProviderTile(
                      key: 'toggle_cash',
                      name: 'Tunai di Meja Kasir (CASH)',
                      subtitle: null,
                      value: _cashEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: false,
                      onChanged: (val) => setState(() => _cashEnabled = val),
                    ),
                    const Divider(height: 16),
                    _buildProviderTile(
                      key: 'toggle_bank_transfer',
                      name: 'Transfer Bank (BCA / Mandiri / BRI)',
                      subtitle: 'Transfer rekening bank langsung ke rekening toko',
                      value: _bankTransferEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: false,
                      onChanged: (val) => setState(() => _bankTransferEnabled = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProviderTile({
    required String key,
    required String name,
    String? subtitle,
    required bool value,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    bool isEwalletProvider = false,
  }) {
    final effectiveEnabled = enabled && (!isEwalletProvider || _ewalletMasterEnabled);
    final isDimmed = isEwalletProvider && !_ewalletMasterEnabled;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isDimmed ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
              if (subtitle != null && subtitle.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
        ),
        Switch(
          key: Key(key),
          value: value,
          activeThumbColor: AppColors.obsidian,
          onChanged: effectiveEnabled ? onChanged : null,
        ),
      ],
    );
  }
}

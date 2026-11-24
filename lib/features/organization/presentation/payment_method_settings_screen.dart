import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../shared/widgets/airy_settings_widgets.dart';
import '../../../../shared/widgets/authenticated_network_image.dart';
import '../../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../providers/organization_provider.dart';

class PaymentMethodSettingsScreen extends ConsumerStatefulWidget {
  const PaymentMethodSettingsScreen({super.key});

  @override
  ConsumerState<PaymentMethodSettingsScreen> createState() =>
      _PaymentMethodSettingsScreenState();
}

class _PaymentMethodSettingsScreenState
    extends ConsumerState<PaymentMethodSettingsScreen> {
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
  bool _isDynamicQrisEnabled = false;
  String? _qrisRawPayload;
  bool _cashEnabled = true;
  bool _bankTransferEnabled = true;

  String? _qrisImageUrl;
  String? _newQrisBase64;
  XFile? _pickedQrisImage;
  Uint8List? _pickedQrisBytes;
  bool _removeQrisImage = false;

  bool get _hasUploadedQrisImage =>
      !_removeQrisImage &&
      ((_qrisImageUrl != null && _qrisImageUrl!.trim().isNotEmpty) ||
          (_newQrisBase64 != null && _newQrisBase64!.trim().isNotEmpty) ||
          _pickedQrisImage != null ||
          _pickedQrisBytes != null);

  bool get _hasValidQrisPayload =>
      !_removeQrisImage &&
      ((_qrisRawPayload != null && _qrisRawPayload!.trim().isNotEmpty) ||
          (_newQrisBase64 != null && _newQrisBase64!.trim().isNotEmpty) ||
          _pickedQrisBytes != null);

  void _populateFromConfig(Map<String, dynamic> data, {bool force = false}) {
    if (_isInitialized && !force) return;
    _isInitialized = true;

    final config =
        (data['config'] is Map
            ? data['config'] as Map<String, dynamic>
            : null) ??
        (data['payment_methods_config'] is Map
            ? data['payment_methods_config'] as Map<String, dynamic>
            : null) ??
        (data['payment_methods_config_override'] is Map
            ? data['payment_methods_config_override'] as Map<String, dynamic>
            : null) ??
        data;

    _ewalletMasterEnabled =
        config['ewallet_enabled'] != false && config['wallet_enable'] != false;

    final providers =
        (config['ewallet_providers'] as Map<String, dynamic>?) ?? {};
    _shopeepayEnabled = providers['shopeepay'] != false;
    _danaEnabled = providers['dana'] != false;
    _linkajaEnabled = providers['linkaja'] != false;
    _ovoEnabled = providers['ovo'] != false;

    _qrisRawPayload = config['qris_raw_payload'] as String?;
    _qrisImageUrl = config['qris_image_url'] as String?;
    final qrisPath = config['qris_image_path']?.toString().trim() ?? '';
    final hasImage =
        (_qrisImageUrl != null && _qrisImageUrl!.trim().isNotEmpty) ||
        qrisPath.isNotEmpty ||
        config['has_qris_image'] == true;

    _qrisEnabled =
        hasImage &&
        config['qris_statis_enabled'] != false &&
        config['is_qris_enabled'] != false;
    _isDynamicQrisEnabled =
        hasImage &&
        (_qrisRawPayload != null && _qrisRawPayload!.trim().isNotEmpty) &&
        config['is_dynamic_qris_enabled'] == true;
    _cashEnabled = config['cash_enabled'] != false;
    _bankTransferEnabled = config['bank_transfer_enabled'] != false;
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
              content: Text(
                'Ukuran gambar melebihi batas 2MB. Harap pilih gambar lain.',
              ),
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
              content: Text(
                'Format gambar tidak didukung. Harap pilih file PNG atau JPG.',
              ),
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
            content: Text(
              'Gambar "${picked.name}" berhasil dipilih. Klik "Simpan Pengaturan" untuk menerapkan.',
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Row(
          children: [
            Icon(
              Icons.qr_code_scanner_rounded,
              color: AppColors.obsidian,
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Unggah Gambar QRIS',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan data gambar QRIS berupa Base64 URI atau pilih sampel barcode toko untuk demonstrasi kasir.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: textController,
              maxLines: 3,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              decoration: InputDecoration(
                labelText: 'Data Gambar Base64',
                hintText: 'data:image/png;base64,iVBORw0KGgo...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.auto_awesome_rounded, size: 16),
              label: const Text(
                'Gunakan Sampel QRIS Toko',
                style: TextStyle(fontSize: 12),
              ),
              onPressed: () {
                // Standard transparent 1x1 PNG data URI for quick test
                textController.text = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=';
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
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

      Map<String, dynamic> updatedData;
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
          'is_qris_enabled': _qrisEnabled ? 1 : 0,
          'is_dynamic_qris_enabled': _isDynamicQrisEnabled ? 1 : 0,
          'cash_enabled': _cashEnabled ? 1 : 0,
          'bank_transfer_enabled': _bankTransferEnabled ? 1 : 0,
          if (_removeQrisImage) 'remove_qris_image': 1,
          'qris_image': MultipartFile.fromBytes(
            _pickedQrisBytes!,
            filename: _pickedQrisImage!.name,
          ),
        });
        updatedData = await repo.updatePaymentSettings(formData);
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
          'is_qris_enabled': _qrisEnabled,
          'is_dynamic_qris_enabled': _isDynamicQrisEnabled,
          'cash_enabled': _cashEnabled,
          'bank_transfer_enabled': _bankTransferEnabled,
        };

        if (_removeQrisImage) {
          payload['remove_qris_image'] = true;
        } else if (_newQrisBase64 != null) {
          payload['qris_image_base64'] = _newQrisBase64;
        }

        updatedData = await repo.updatePaymentSettings(payload);
      }

      // 1. Immediately mutate local state from freshly returned data
      if (updatedData.isNotEmpty) {
        setState(() {
          _populateFromConfig(updatedData, force: true);
          _pickedQrisImage = null;
          _pickedQrisBytes = null;
          _newQrisBase64 = null;
          _removeQrisImage = false;
        });
      }

      // 2. Invalidate caches for all related providers
      ref.invalidate(paymentSettingsProvider(_selectedBranchId));
      ref.invalidate(paymentSettingsProvider(null));
      ref.invalidate(paymentMethodsProvider);
      ref.invalidate(paymentMethodsForBranchProvider(_selectedBranchId));
      ref.invalidate(paymentMethodsForBranchProvider(null));
      try {
        ref.read(businessProvider.notifier).refresh();
      } catch (_) {}

      // 3. Synchronously refresh paymentSettingsProvider to ensure Riverpod cache is in sync
      try {
        final freshData = await ref.refresh(
          paymentSettingsProvider(_selectedBranchId).future,
        );
        if (mounted && freshData.isNotEmpty) {
          setState(() {
            _populateFromConfig(freshData, force: true);
          });
        }
      } catch (_) {
        // Fallback: local state already updated from updatedData
      }

      // 4. Show success notification strictly after network execution & state sync succeed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Konfigurasi metode pembayaran berhasil disimpan.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      String errorMessage = 'Gagal menyimpan pengaturan: $e';
      if (e is DioException && e.response?.data is Map) {
        final resMap = e.response!.data as Map;
        errorMessage = resMap['message']?.toString() ?? errorMessage;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
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
    final userRole =
        currentBiz?['role']?.toString().toLowerCase() ??
        user?['role']?.toString().toLowerCase() ??
        '';
    final isSuperAdmin =
        user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final isOwnerOrAdmin =
        userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final branches = ref.watch(organizationProvider).branches;

    final settingsAsync = ref.watch(paymentSettingsProvider(_selectedBranchId));

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: const RentCoreAppBar(title: 'Metode Pembayaran'),
      bottomNavigationBar: isOwnerOrAdmin
          ? airyStickyFooter(
              child: airyPrimaryCta(
                buttonKey: const Key('save_payment_settings_button'),
                label: 'Simpan Pengaturan',
                isLoading: _isSaving,
                icon: Icons.check_circle_outline_rounded,
                onPressed: _isSaving ? null : _saveSettings,
              ),
            )
          : null,
      body: settingsAsync.when(
        loading: () => const SettingsGroupSkeleton(groupCount: 2, itemsPerGroup: 3),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat pengaturan:\n$err',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(
                    paymentSettingsProvider(_selectedBranchId),
                  ),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          _populateFromConfig(data);

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // 1. Role Authorization Notice
              if (!isOwnerOrAdmin)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFFB45309),
                          size: 18,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Pengaturan metode pembayaran hanya dapat diubah oleh Owner atau Admin. Anda melihat konfigurasi aktif ini dalam mode baca saja.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // 2. Branch Scope Selector
              if (branches.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      airySectionHeader('Cakupan Cabang'),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedBranchId,
                        decoration: airyInputDecoration(
                          enabled: isOwnerOrAdmin,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        dropdownColor: AirySettingsColors.canvas,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text(
                              'Semua Cabang (Standar Bisnis Pusat)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: AirySettingsColors.obsidian,
                              ),
                            ),
                          ),
                          ...branches.map((b) {
                            final bId = b['id'] is int
                                ? b['id'] as int
                                : int.parse(b['id'].toString());
                            return DropdownMenuItem<int?>(
                              value: bId,
                              child: Text(
                                b['name'] ?? 'Cabang #$bId',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.5,
                                  color: AirySettingsColors.obsidian,
                                ),
                              ),
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
                airyHairlineDivider(),
              ],

              // 3. Static QRIS Section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QRIS Statis',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: _hasUploadedQrisImage
                                      ? AirySettingsColors.obsidian
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Tampilkan barcode QR untuk pembayaran m-Banking/E-Wallet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _hasUploadedQrisImage
                                      ? AirySettingsColors.inkSecondary
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        airySwitch(
                          key: const Key('qris_statis_toggle'),
                          value: _hasUploadedQrisImage ? _qrisEnabled : false,
                          onChanged: (isOwnerOrAdmin && _hasUploadedQrisImage)
                              ? (val) => setState(() => _qrisEnabled = val)
                              : null,
                        ),
                      ],
                    ),
                    if (!_hasUploadedQrisImage) ...[
                      const SizedBox(height: 12),
                      Container(
                        key: const Key('qris_upload_required_banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AirySettingsColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AirySettingsColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              size: 16,
                              color: AirySettingsColors.inkMuted,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Unggah gambar barcode QRIS terlebih dahulu untuk mengaktifkan pembayaran QRIS.',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: AirySettingsColors.inkMuted,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    ...[
                      const SizedBox(height: 18),
                      airySectionHeader('Gambar Kode QRIS Toko'),
                      const SizedBox(height: 10),
                      if (!_removeQrisImage &&
                          (_newQrisBase64 != null ||
                              _qrisImageUrl != null)) ...[
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AirySettingsColors.surfaceSubtle,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AirySettingsColors.border,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 68,
                                height: 68,
                                decoration: BoxDecoration(
                                  color: AirySettingsColors.canvas,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AirySettingsColors.border,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: _pickedQrisBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          _pickedQrisBytes!,
                                          fit: BoxFit.contain,
                                        ),
                                      )
                                    : (_newQrisBase64 != null
                                          ? const Icon(
                                              Icons.check_circle_rounded,
                                              color: AppColors.success,
                                              size: 30,
                                            )
                                          : AuthenticatedNetworkImage(
                                              url: _qrisImageUrl!,
                                              fit: BoxFit.contain,
                                              loadingBuilder:
                                                  (
                                                    context,
                                                    child,
                                                    loadingProgress,
                                                  ) {
                                                    if (loadingProgress == null) {
                                                      return child;
                                                    }
                                                    return const Center(
                                                      child: SizedBox(
                                                        width: 20,
                                                        height: 20,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                              color:
                                                                  AirySettingsColors
                                                                      .obsidian,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                              errorBuilder: (_, _, _) =>
                                                  const Icon(
                                                    Icons.qr_code_rounded,
                                                    size: 32,
                                                  ),
                                            )),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _pickedQrisImage != null ||
                                              _newQrisBase64 != null
                                          ? 'Gambar Baru Dipilih'
                                          : 'Gambar QRIS Aktif Tersimpan',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13.5,
                                        color: AirySettingsColors.obsidian,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _pickedQrisImage != null ||
                                              _newQrisBase64 != null
                                          ? 'Klik "Simpan Pengaturan" untuk menerapkan gambar.'
                                          : 'Tampil di layar pembayaran kasir.',
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AirySettingsColors.inkSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (isOwnerOrAdmin)
                                      Row(
                                        children: [
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  AirySettingsColors.obsidian,
                                              side: const BorderSide(
                                                color:
                                                    AirySettingsColors.border,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              Icons.swap_horiz_rounded,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Ganti',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: _pickQrisImage,
                                          ),
                                          const SizedBox(width: 8),
                                          TextButton.icon(
                                            style: TextButton.styleFrom(
                                              foregroundColor: AppColors.danger,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 6,
                                                  ),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                            icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              size: 14,
                                            ),
                                            label: const Text(
                                              'Hapus',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            onPressed: () => setState(() {
                                              _removeQrisImage = true;
                                              _newQrisBase64 = null;
                                              _pickedQrisImage = null;
                                              _pickedQrisBytes = null;
                                              _qrisRawPayload = null;
                                              _qrisEnabled = false;
                                              _isDynamicQrisEnabled = false;
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
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 22,
                              horizontal: 16,
                            ),
                            decoration: BoxDecoration(
                              color: AirySettingsColors.surfaceSubtle,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AirySettingsColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AirySettingsColors.canvas,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AirySettingsColors.border,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 22,
                                    color: AirySettingsColors.obsidian,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Belum ada gambar barcode QRIS',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.5,
                                    color: AirySettingsColors.obsidian,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Ketuk di sini untuk mengunggah gambar QRIS toko (PNG, JPG, maks. 2MB)',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AirySettingsColors.inkSecondary,
                                    height: 1.35,
                                  ),
                                ),
                                if (isOwnerOrAdmin) ...[
                                  const SizedBox(height: 14),
                                  SizedBox(
                                    height: 42,
                                    child: ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AirySettingsColors.obsidian,
                                        foregroundColor: Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 18,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: _pickQrisImage,
                                      icon: const Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 16,
                                      ),
                                      label: const Text(
                                        'Pilih Gambar QRIS',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  TextButton(
                                    onPressed: _showImageUploadDialog,
                                    child: const Text(
                                      'Atau masukkan manual / sampel test',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: AirySettingsColors.inkSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      airyHairlineDivider(),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'QRIS Dinamis',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                        color: (_hasUploadedQrisImage &&
                                                _hasValidQrisPayload)
                                            ? AirySettingsColors.obsidian
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AirySettingsColors.pillSurface,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'NOMINAL OTOMATIS',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                          color: (_hasUploadedQrisImage &&
                                                  _hasValidQrisPayload)
                                              ? AirySettingsColors.obsidian
                                              : const Color(0xFF94A3B8),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'Kunci nominal transaksi secara real-time pada barcode aplikasi pelanggan',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: (_hasUploadedQrisImage &&
                                            _hasValidQrisPayload)
                                        ? AirySettingsColors.inkSecondary
                                        : const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          airySwitch(
                            key: const Key('is_dynamic_qris_enabled_toggle'),
                            value: (_hasUploadedQrisImage &&
                                    _hasValidQrisPayload)
                                ? _isDynamicQrisEnabled
                                : false,
                            onChanged: (isOwnerOrAdmin &&
                                    _hasUploadedQrisImage &&
                                    _hasValidQrisPayload)
                                ? (val) => setState(
                                    () => _isDynamicQrisEnabled = val,
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!_hasValidQrisPayload)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: Color(0xFFB45309),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Unggah gambar QRIS statis terlebih dahulu untuk mengaktifkan QRIS Dinamis.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF92400E),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFBBF7D0)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.check_circle_outline_rounded,
                                size: 16,
                                color: Color(0xFF15803D),
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Barcode QRIS terdeteksi & siap untuk nominal otomatis.',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFF166534),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              ),
              airyHairlineDivider(),

              // 4. E-Wallet Section (Master Toggle + Sub-toggles)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
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
                              Text(
                                'Dompet Digital (E-Wallet)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: AirySettingsColors.obsidian,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Aktifkan semua e-wallet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirySettingsColors.inkSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        airySwitch(
                          key: const Key('ewallet_master_toggle'),
                          value: _ewalletMasterEnabled,
                          onChanged: isOwnerOrAdmin
                              ? (val) => setState(
                                  () => _ewalletMasterEnabled = val,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    airySectionHeader('Penyedia E-Wallet'),
                    const SizedBox(height: 4),
                    const Text(
                      'Preferensi pilihan masing-masing penyedia akan tetap tersimpan meskipun master toggle dimatikan.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AirySettingsColors.inkSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // ShopeePay
                    _buildProviderTile(
                      key: 'toggle_shopeepay',
                      name: 'ShopeePay',
                      subtitle: 'Pembayaran melalui saldo ShopeePay',
                      value: _shopeepayEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: true,
                      onChanged: (val) =>
                          setState(() => _shopeepayEnabled = val),
                    ),
                    airyHairlineDivider(),

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
                    airyHairlineDivider(),

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
                    airyHairlineDivider(),

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
              airyHairlineDivider(),

              // 5. Baseline Payment Methods (Tunai & Transfer)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    airySectionHeader('Metode Lainnya'),
                    const SizedBox(height: 8),
                    _buildProviderTile(
                      key: 'toggle_cash',
                      name: 'Tunai di Meja Kasir (CASH)',
                      subtitle: null,
                      value: _cashEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: false,
                      onChanged: (val) => setState(() => _cashEnabled = val),
                    ),
                    airyHairlineDivider(),
                    _buildProviderTile(
                      key: 'toggle_bank_transfer',
                      name: 'Transfer Bank (BCA / Mandiri / BRI)',
                      subtitle:
                          'Transfer rekening bank langsung ke rekening toko',
                      value: _bankTransferEnabled,
                      enabled: isOwnerOrAdmin,
                      isEwalletProvider: false,
                      onChanged: (val) =>
                          setState(() => _bankTransferEnabled = val),
                    ),
                  ],
                ),
              ),
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
    final effectiveEnabled =
        enabled && (!isEwalletProvider || _ewalletMasterEnabled);
    final isDimmed = isEwalletProvider && !_ewalletMasterEnabled;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isDimmed
                        ? AirySettingsColors.inkSecondary
                        : AirySettingsColors.obsidian,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AirySettingsColors.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          airySwitch(
            key: Key(key),
            value: value,
            onChanged: effectiveEnabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}

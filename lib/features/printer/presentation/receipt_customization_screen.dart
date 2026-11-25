import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/widgets/unified_thermal_receipt_preview.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/printer_provider.dart';
import 'printer_settings_screen.dart';

class ReceiptCustomizationScreen extends ConsumerStatefulWidget {
  const ReceiptCustomizationScreen({super.key});

  @override
  ConsumerState<ReceiptCustomizationScreen> createState() => _ReceiptCustomizationScreenState();
}

class _ReceiptCustomizationScreenState extends ConsumerState<ReceiptCustomizationScreen> {
  late ReceiptCustomizationSettings _currentSettings;
  bool _initialized = false;
  PrintMode _previewTab = PrintMode.normal;
  bool _isPrintingStandard = false;
  bool _isPrintingEcho = false;

  late final TextEditingController _shopNameCtrl;
  late final TextEditingController _branchNameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _footerMsgCtrl;
  late final TextEditingController _termsCtrl;

  @override
  void initState() {
    super.initState();
    final savedSettings = ref.read(printerProvider).settings;
    _currentSettings = savedSettings;
    _previewTab = savedSettings.printMode;

    final biz = ref.read(businessProvider);
    final fallbackShop = savedSettings.customShopName.isNotEmpty
        ? savedSettings.customShopName
        : (biz.resolvedStoreName.isNotEmpty ? biz.resolvedStoreName : 'Toko Rental');
    final fallbackBranch = savedSettings.customBranchName.isNotEmpty
        ? savedSettings.customBranchName
        : (biz.resolvedBranchName.isNotEmpty ? biz.resolvedBranchName : 'Cabang Utama');
    final fallbackAddress = savedSettings.storeAddress.isNotEmpty
        ? savedSettings.storeAddress
        : biz.resolvedBranchAddress;
    final fallbackPhone = savedSettings.storePhone.isNotEmpty
        ? savedSettings.storePhone
        : biz.resolvedBranchPhone;

    _shopNameCtrl = TextEditingController(text: fallbackShop);
    _branchNameCtrl = TextEditingController(text: fallbackBranch);
    _addressCtrl = TextEditingController(text: fallbackAddress);
    _phoneCtrl = TextEditingController(text: fallbackPhone);
    _footerMsgCtrl = TextEditingController(text: savedSettings.customFooterMessage);
    _termsCtrl = TextEditingController(text: savedSettings.returnTermsText);
    _initialized = true;
  }

  @override
  void dispose() {
    _shopNameCtrl.dispose();
    _branchNameCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _footerMsgCtrl.dispose();
    _termsCtrl.dispose();
    super.dispose();
  }

  void _syncTextToSettings() {
    setState(() {
      _currentSettings = _currentSettings.copyWith(
        customShopName: _shopNameCtrl.text.trim(),
        customBranchName: _branchNameCtrl.text.trim(),
        storeAddress: _addressCtrl.text.trim(),
        storePhone: _phoneCtrl.text.trim(),
        customFooterMessage: _footerMsgCtrl.text.trim(),
        returnTermsText: _termsCtrl.text.trim(),
      );
    });
  }

  Future<void> _confirmResetToDefault() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Pengaturan Struk?'),
        content: const Text(
          'Semua perubahan desain struk akan dikembalikan ke pengaturan bawaan toko. Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset ke Bawaan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      _resetToDefault();
    }
  }

  void _resetToDefault() {
    final biz = ref.read(businessProvider);
    final defaultShop = biz.resolvedStoreName.isNotEmpty ? biz.resolvedStoreName : 'Toko Rental';
    final defaultBranch = biz.resolvedBranchName.isNotEmpty ? biz.resolvedBranchName : 'Cabang Utama';

    final def = ReceiptCustomizationSettings.defaultSettings(
      shopName: defaultShop,
      branchName: defaultBranch,
    );

    setState(() {
      _currentSettings = def;
      _shopNameCtrl.text = defaultShop;
      _branchNameCtrl.text = defaultBranch;
      _addressCtrl.text = biz.resolvedBranchAddress;
      _phoneCtrl.text = biz.resolvedBranchPhone;
      _footerMsgCtrl.text = def.customFooterMessage;
      _termsCtrl.text = def.returnTermsText;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Konfigurasi struk dikembalikan ke bawaan.')),
    );
  }

  Future<void> _saveSettings() async {
    _syncTextToSettings();
    await ref.read(printerProvider.notifier).saveSettings(_currentSettings);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pengaturan layout struk berhasil disimpan!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return const SizedBox.shrink();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RentCoreAppBar(
        title: 'Desain & Layout Struk',
        actions: [
          TextButton(
            key: const Key('receipt_layout_reset_button'),
            onPressed: _confirmResetToDefault,
            child: const Text('Reset', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            key: const Key('receipt_layout_save_button'),
            onPressed: _saveSettings,
            child: const Text('Simpan', style: TextStyle(color: AppColors.obsidian, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: ListView(
        cacheExtent: 2500,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          // Preview Card Section
          _buildLivePreviewCard(),
          const SizedBox(height: 20),

          // Form Controls
          _buildHeaderSettingsCard(),
          const SizedBox(height: 16),

          _buildFieldTogglesCard(),
          const SizedBox(height: 16),

          _buildFooterSettingsCard(),
        ],
      ),
    );
  }

  // --- 1. Dual-Mode Live Preview (Single Source of Truth: UnifiedThermalReceiptPreview) ---
  Widget _buildLivePreviewCard() {
    final bizState = ref.watch(businessProvider);
    final standardData = ReceiptDocumentData.sample(
      bizState,
      settings: _currentSettings,
      modeOverride: PrintMode.normal,
    );
    final echoData = ReceiptDocumentData.sample(
      bizState,
      settings: _currentSettings,
      modeOverride: PrintMode.echo,
    );
    final is58mm = _currentSettings.paperWidth == ReceiptPaperWidth.mm58;
    final isStandard = _previewTab == PrintMode.normal;
    final activeData = isStandard ? standardData : echoData;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.visibility_rounded, size: 16, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'PRATINJAU LANGSUNG',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  is58mm ? '58mm Standar' : '80mm POS',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Dual Preview Tab Selector
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildPreviewTabButton(
                    title: 'Standar (58mm)',
                    icon: Icons.receipt_long_rounded,
                    isSelected: isStandard,
                    onTap: () => setState(() => _previewTab = PrintMode.normal),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPreviewTabButton(
                    title: 'Kompak',
                    icon: Icons.eco_outlined,
                    isSelected: !isStandard,
                    onTap: () => setState(() => _previewTab = PrintMode.echo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Preview Render via UnifiedThermalReceiptPreview
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: is58mm ? 320.0 : 400.0),
              child: Column(
                children: [
                  UnifiedThermalReceiptPreview(
                    data: activeData,
                    paperEdgeLabel: isStandard
                        ? (is58mm
                            ? 'TEAR BAR MANUAL (58MM)'
                            : 'AUTO-CUTTER POS (80MM)')
                        : (is58mm
                            ? 'MODE ECHO • KOMPAK (58MM)'
                            : 'MODE ECHO • KOMPAK (80MM)'),
                    paperEdgeIcon: isStandard
                        ? (is58mm
                            ? Icons.straighten_rounded
                            : Icons.content_cut_rounded)
                        : Icons.eco_rounded,
                    paperEdgeIconColor:
                        isStandard ? AppColors.textMuted : AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: (isStandard ? _isPrintingStandard : _isPrintingEcho)
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isStandard
                                  ? Icons.print_rounded
                                  : Icons.print_outlined,
                              size: 18,
                            ),
                      label: Text(
                        isStandard
                            ? (_isPrintingStandard
                                ? 'Mencetak Standard...'
                                : 'Print Standard')
                            : (_isPrintingEcho
                                ? 'Memproses Echo...'
                                : 'Print Echo'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      onPressed: (_isPrintingStandard || _isPrintingEcho)
                          ? null
                          : () => _printPreviewReceipt(
                                isStandard ? PrintMode.normal : PrintMode.echo,
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewTabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? AppColors.obsidian : AppColors.textMuted,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? AppColors.obsidian : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Per-Mode Printing Action Pipeline ---
  Future<void> _printPreviewReceipt(PrintMode mode) async {
    if (_isPrintingStandard || _isPrintingEcho) return;

    // 1. Sync live edited form text before printing
    _syncTextToSettings();

    setState(() {
      if (mode == PrintMode.normal) {
        _isPrintingStandard = true;
      } else {
        _isPrintingEcho = true;
      }
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final activeSettings = _currentSettings.copyWith(printMode: mode);
      final bizState = ref.read(businessProvider);
      final sampleDoc = ReceiptDocumentData.sample(
        bizState,
        settings: activeSettings,
        modeOverride: mode,
      );

      final success = await ThermalPrinterService().printReceipt(sampleDoc);

      if (mounted) {
        setState(() {
          _isPrintingStandard = false;
          _isPrintingEcho = false;
        });

        messenger.clearSnackBars();
        if (success) {
          final deviceName = ThermalPrinterService().connectedDevice?.name ?? 'Printer Thermal';
          final modeLabel = mode == PrintMode.echo ? 'Echo' : 'Standard';
          messenger.showSnackBar(
            SnackBar(
              content: Text('Print $modeLabel berhasil dikirim ke $deviceName!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          final err = ThermalPrinterService().lastError ??
              'Gagal mencetak. Printer tidak terhubung atau Bluetooth terputus.';
          messenger.showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: AppColors.danger,
              action: SnackBarAction(
                label: 'Buka Pengaturan',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPrintingStandard = false;
          _isPrintingEcho = false;
        });
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Terjadi kesalahan saat mencetak: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  // --- 2. Header Settings Card ---
  Widget _buildHeaderSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'INFORMASI HEADER STRUK',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _shopNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Usaha / Toko',
              hintText: 'Contoh: Toko Kamera Nusantara',
              isDense: true,
            ),
            onChanged: (_) => _syncTextToSettings(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _branchNameCtrl,
            decoration: const InputDecoration(
              labelText: 'Nama Cabang / Outlet',
              hintText: 'Contoh: Cabang Mataram',
              isDense: true,
            ),
            onChanged: (_) => _syncTextToSettings(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(
              labelText: 'Alamat Toko (Opsional)',
              hintText: 'Jl. Pejanggik No. 88, Mataram',
              isDense: true,
            ),
            onChanged: (_) => _syncTextToSettings(),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Nomor Telepon / WhatsApp',
              hintText: '0812-3456-7890',
              isDense: true,
            ),
            keyboardType: TextInputType.phone,
            onChanged: (_) => _syncTextToSettings(),
          ),
          const SizedBox(height: 14),

          // Header Alignment Radio
          const Text('Posisi Teks Header:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: 'Rata Tengah',
                  isSelected: _currentSettings.headerAlignment == ReceiptHeaderAlignment.center,
                  onTap: () {
                    setState(() {
                      _currentSettings = _currentSettings.copyWith(headerAlignment: ReceiptHeaderAlignment.center);
                    });
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(
                  label: 'Rata Kiri',
                  isSelected: _currentSettings.headerAlignment == ReceiptHeaderAlignment.left,
                  onTap: () {
                    setState(() {
                      _currentSettings = _currentSettings.copyWith(headerAlignment: ReceiptHeaderAlignment.left);
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Field Toggles Card ---
  Widget _buildFieldTogglesCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PILIHAN KOLOM & PRIVASI PELANGGAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          _buildSwitchRow(
            title: 'Tampilkan Nama Kasir',
            subtitle: 'Mencantumkan identitas kasir yang melayani',
            value: _currentSettings.showCashierName,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showCashierName: val)),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSwitchRow(
            title: 'Tampilkan Nomor Telepon Pelanggan',
            subtitle: 'Mencetak kontak customer pada struk sewa',
            value: _currentSettings.showCustomerPhone,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showCustomerPhone: val)),
          ),
          if (_currentSettings.showCustomerPhone) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            _buildSwitchRow(
              title: 'Sensor Nomor HP (Privasi Masking)',
              subtitle: 'Sembunyikan angka tengah: 0812****8890',
              value: _currentSettings.maskCustomerPhone,
              onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(maskCustomerPhone: val)),
            ),
          ],
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSwitchRow(
            title: 'Tampilkan Slot Jaminan KTP',
            subtitle: 'Memudahkan identifikasi brankas saat pengembalian',
            value: _currentSettings.showCollateralInfo,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showCollateralInfo: val)),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSwitchRow(
            title: 'Cetak QR Code Booking',
            subtitle: 'Bisa di-scan cepat oleh kasir saat unit dikembalikan',
            value: _currentSettings.showQrBarcode,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showQrBarcode: val)),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSwitchRow(
            title: 'Tampilkan Uang Diterima & Kembalian',
            subtitle: 'Rincian nominal tunai pelanggan',
            value: _currentSettings.showChangeDue,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showChangeDue: val)),
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _buildSwitchRow(
            title: 'Garis Pembatas Ganda (=)',
            subtitle: 'Gunakan karakter ganda "=" bukan garis putus-putus "-"',
            value: _currentSettings.separatorStyle == 'double',
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(separatorStyle: val ? 'double' : 'dash')),
          ),
        ],
      ),
    );
  }

  // --- 4. Footer Settings Card ---
  Widget _buildFooterSettingsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATATAN FOOTER & SYARAT PENGEMBALIAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 10),
          _buildSwitchRow(
            title: 'Cetak Ketentuan Pengembalian',
            subtitle: 'Tampilkan klausul jadwal & denda di bagian bawah struk',
            value: _currentSettings.showReturnTerms,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showReturnTerms: val)),
          ),
          if (_currentSettings.showReturnTerms) ...[
            Divider(height: 1, color: Colors.grey.shade100),
            const SizedBox(height: 12),
            TextFormField(
              controller: _termsCtrl,
              maxLines: 2,
              maxLength: 150,
              decoration: InputDecoration(
                labelText: 'Klausul Pengembalian',
                hintText: 'Harap mengembalikan unit tepat waktu...',
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
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
                  borderSide: const BorderSide(color: AppColors.obsidian, width: 1.5),
                ),
              ),
              onChanged: (_) => _syncTextToSettings(),
            ),
          ],
          const SizedBox(height: 14),
          TextFormField(
            controller: _footerMsgCtrl,
            maxLines: 2,
            maxLength: 120,
            decoration: InputDecoration(
              labelText: 'Pesan Penutup / Ucapan Terima Kasih',
              hintText: '*** TERIMA KASIH ***\nSimpan struk ini...',
              isDense: true,
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.obsidian, width: 1.5),
              ),
            ),
            onChanged: (_) => _syncTextToSettings(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.obsidian,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.obsidian : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 12,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

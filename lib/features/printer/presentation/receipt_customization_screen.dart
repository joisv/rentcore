import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
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
        : (biz.activeBusinessName ?? 'RENTCORE GADGETS');
    final fallbackBranch = savedSettings.customBranchName.isNotEmpty
        ? savedSettings.customBranchName
        : (biz.activeBranchName ?? 'Pusat Operasional');

    _shopNameCtrl = TextEditingController(text: fallbackShop);
    _branchNameCtrl = TextEditingController(text: fallbackBranch);
    _addressCtrl = TextEditingController(text: savedSettings.storeAddress);
    _phoneCtrl = TextEditingController(text: savedSettings.storePhone);
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

  void _resetToDefault() {
    final biz = ref.read(businessProvider);
    final defaultShop = biz.activeBusinessName ?? 'RENTCORE GADGETS';
    final defaultBranch = biz.activeBranchName ?? 'Pusat Operasional';

    final def = ReceiptCustomizationSettings.defaultSettings(
      shopName: defaultShop,
      branchName: defaultBranch,
    );

    setState(() {
      _currentSettings = def;
      _shopNameCtrl.text = defaultShop;
      _branchNameCtrl.text = defaultBranch;
      _addressCtrl.text = '';
      _phoneCtrl.text = '';
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
      appBar: AppBar(
        title: const Text(
          'Desain & Layout Struk',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _resetToDefault,
            child: const Text('Reset', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
          IconButton(
            icon: const Icon(Icons.check_rounded, color: AppColors.obsidian),
            tooltip: 'Simpan',
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
            const SizedBox(height: 24),

            // Bottom Actions
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.save_rounded, size: 20),
              label: const Text('Simpan Pengaturan Desain', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _saveSettings,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // --- 1. Dual-Mode Live Preview (Standard Thermal & Echo Clean Receipt) ---
  Widget _buildLivePreviewCard() {
    final sampleData = ThermalPrinterService().getSampleBookingReceipt(_currentSettings);
    final standardDoc = ThermalPrinterService().buildReceiptDocument(sampleData, _currentSettings, PrintMode.normal);
    final echoDoc = ThermalPrinterService().buildReceiptDocument(sampleData, _currentSettings, PrintMode.echo);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
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
              const Row(
                children: [
                  Icon(Icons.visibility_rounded, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text(
                    'PRATINJAU LANGSUNG (LIVE PREVIEW)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _currentSettings.paperWidth.label,
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
                    title: 'Standard (Kertas Thermal)',
                    icon: Icons.receipt_long_rounded,
                    isSelected: _previewTab == PrintMode.normal,
                    onTap: () => setState(() => _previewTab = PrintMode.normal),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildPreviewTabButton(
                    title: 'Echo (Kompak)',
                    icon: Icons.eco_outlined,
                    isSelected: _previewTab == PrintMode.echo,
                    onTap: () => setState(() => _previewTab = PrintMode.echo),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Active Preview Render
          if (_previewTab == PrintMode.normal)
            _buildStandardThermalPreview(standardDoc, _currentSettings)
          else
            _buildEchoThermalPreview(echoDoc, _currentSettings),
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

  // --- Standard Mode: Physical Thermal Paper Roll Preview ---
  Widget _buildStandardThermalPreview(
    ReceiptPrintDocument doc,
    ReceiptCustomizationSettings settings,
  ) {
    final is58mm = settings.paperWidth == ReceiptPaperWidth.mm58;
    final maxWidth = is58mm ? 320.0 : 400.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Tear Bar / Auto-cutter representation
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      border: Border(
                        bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          is58mm ? Icons.straighten_rounded : Icons.content_cut_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            is58mm ? 'TEAR BAR MANUAL (58MM)' : 'AUTO-CUTTER POS (80MM)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Printed Receipt Content (Rendered from doc.lines)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: doc.lines.map((line) => _buildStandardLineWidget(line, settings)).toList(),
                    ),
                  ),

                  // Bottom Paper Roll Finish
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Center(
                      child: Text(
                        is58mm ? '· · · · · · · · · · · · · · · ·' : '· · · · · · · · · · · · · · · · · · · · · · · ·',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Dedicated Print Standard Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isPrintingStandard
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print_rounded, size: 18),
                label: Text(
                  _isPrintingStandard ? 'Mencetak Standard...' : 'Print Standard',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: (_isPrintingStandard || _isPrintingEcho)
                    ? null
                    : () => _printPreviewReceipt(PrintMode.normal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Echo Mode: Clean & Compact Thermal Receipt Preview ---
  Widget _buildEchoThermalPreview(
    ReceiptPrintDocument doc,
    ReceiptCustomizationSettings settings,
  ) {
    final is58mm = settings.paperWidth == ReceiptPaperWidth.mm58;
    final maxWidth = is58mm ? 320.0 : 400.0;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Tear Bar / Eco Badge
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted.withValues(alpha: 0.4),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                      border: Border(
                        bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.6)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.eco_rounded, size: 12, color: AppColors.success),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            is58mm
                                ? 'MODE ECHO • KOMPAK (58MM)'
                                : 'MODE ECHO • KOMPAK (80MM)',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Compact Printed Receipt Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: doc.lines
                          .map((line) => _buildStandardLineWidget(line, settings, isCompact: true))
                          .toList(),
                    ),
                  ),

                  // Bottom Paper Roll Finish
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted.withValues(alpha: 0.2),
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                    ),
                    child: Center(
                      child: Text(
                        is58mm ? '· · · · · · · · · · · · · · · ·' : '· · · · · · · · · · · · · · · · · · · · · · · ·',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 8,
                          color: Colors.grey.shade400,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Dedicated Print Echo Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _isPrintingEcho
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.print_outlined, size: 18),
                label: Text(
                  _isPrintingEcho ? 'Memproses Echo...' : 'Print Echo',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: (_isPrintingStandard || _isPrintingEcho)
                    ? null
                    : () => _printPreviewReceipt(PrintMode.echo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStandardLineWidget(
    ReceiptLineItem line,
    ReceiptCustomizationSettings settings, {
    bool isCompact = false,
  }) {
    final isCenter = line.alignment == ReceiptHeaderAlignment.center;
    final is58mm = settings.paperWidth == ReceiptPaperWidth.mm58;

    switch (line.type) {
      case ReceiptLineType.header:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 0.0 : 0.5),
          child: Text(
            line.text,
            textAlign: isCenter ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: line.isDoubleSize ? 14 : (isCompact ? 11 : 11),
              fontWeight: line.isBold ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: line.isDoubleSize ? 0.6 : 0,
              color: AppColors.obsidian,
            ),
          ),
        );

      case ReceiptLineType.text:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 0.5 : 1.0),
          child: Text(
            line.text,
            textAlign: isCenter ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: isCompact ? 10.5 : 11,
              fontWeight: line.isBold ? FontWeight.w800 : FontWeight.normal,
              color: AppColors.textPrimary,
            ),
          ),
        );

      case ReceiptLineType.keyValue:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 1.0 : 1.5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  line.leftText ?? '',
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: isCompact ? 10.0 : 10.5,
                    fontWeight: line.isBold ? FontWeight.bold : FontWeight.normal,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                line.rightText ?? '',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: isCompact ? 10.0 : 10.5,
                  fontWeight: line.isBold ? FontWeight.bold : FontWeight.normal,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        );

      case ReceiptLineType.divider:
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isCompact ? 1.0 : 2.0),
          child: Text(
            line.text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              color: Colors.grey.shade400,
              letterSpacing: 0.5,
            ),
          ),
        );

      case ReceiptLineType.qrCode:
        return Column(
          children: [
            SizedBox(height: isCompact ? 4 : 6),
            Center(
              child: QrImageView(
                data: line.qrData ?? line.text,
                version: QrVersions.auto,
                size: is58mm ? (isCompact ? 60.0 : 75.0) : (isCompact ? 80.0 : 95.0),
                padding: const EdgeInsets.all(2),
              ),
            ),
            const SizedBox(height: 2),
            Center(
              child: Text(
                line.qrData ?? line.text,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            SizedBox(height: isCompact ? 4 : 6),
          ],
        );

      case ReceiptLineType.emptyFeed:
        return SizedBox(height: isCompact ? 4 : 8);
    }
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
      final sampleData = ThermalPrinterService().getSampleBookingReceipt(activeSettings);
      final doc = ThermalPrinterService().buildReceiptDocument(sampleData, activeSettings, mode);
      final bytes = ThermalPrinterService().buildSlipBytesFromDocument(doc, activeSettings);

      final success = await ThermalPrinterService().sendPrintJob(bytes, mode);

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
        borderRadius: BorderRadius.circular(20),
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
              hintText: 'Contoh: RENTCORE GADGETS',
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
        borderRadius: BorderRadius.circular(20),
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
          const Divider(height: 16),
          _buildSwitchRow(
            title: 'Tampilkan Nomor Telepon Pelanggan',
            subtitle: 'Mencetak kontak customer pada struk sewa',
            value: _currentSettings.showCustomerPhone,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showCustomerPhone: val)),
          ),
          if (_currentSettings.showCustomerPhone) ...[
            const Divider(height: 16),
            _buildSwitchRow(
              title: 'Sensor Nomor HP (Privasi Masking)',
              subtitle: 'Sembunyikan angka tengah: 0812****8890',
              value: _currentSettings.maskCustomerPhone,
              onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(maskCustomerPhone: val)),
            ),
          ],
          const Divider(height: 16),
          _buildSwitchRow(
            title: 'Tampilkan Slot Jaminan KTP',
            subtitle: 'Memudahkan identifikasi brankas saat pengembalian',
            value: _currentSettings.showCollateralInfo,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showCollateralInfo: val)),
          ),
          const Divider(height: 16),
          _buildSwitchRow(
            title: 'Cetak QR Code Booking',
            subtitle: 'Bisa di-scan cepat oleh kasir saat unit dikembalikan',
            value: _currentSettings.showQrBarcode,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showQrBarcode: val)),
          ),
          const Divider(height: 16),
          _buildSwitchRow(
            title: 'Tampilkan Uang Diterima & Kembalian',
            subtitle: 'Rincian nominal tunai pelanggan',
            value: _currentSettings.showChangeDue,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showChangeDue: val)),
          ),
          const Divider(height: 16),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CATATAN FOOTER & SYARAT PENGEMBALIAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _buildSwitchRow(
            title: 'Cetak Ketentuan Pengembalian',
            subtitle: 'Tampilkan klausul jadwal & denda di bagian bawah struk',
            value: _currentSettings.showReturnTerms,
            onChanged: (val) => setState(() => _currentSettings = _currentSettings.copyWith(showReturnTerms: val)),
          ),
          if (_currentSettings.showReturnTerms) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _termsCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Klausul Pengembalian',
                hintText: 'Harap mengembalikan unit tepat waktu...',
                isDense: true,
              ),
              onChanged: (_) => _syncTextToSettings(),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _footerMsgCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Pesan Penutup / Ucapan Terima Kasih',
              hintText: '*** TERIMA KASIH ***\nSimpan struk ini...',
              isDense: true,
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
    return Row(
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
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
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

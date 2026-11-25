import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/receipt_document_data.dart';
import '../../../core/models/thermal_printer_models.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../core/widgets/unified_thermal_receipt_preview.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/printer_provider.dart';
import 'receipt_customization_screen.dart';

class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(printerProvider.notifier).scanDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(printerProvider);
    final notifier = ref.read(printerProvider.notifier);

    ref.listen<PrinterState>(printerProvider, (prev, next) {
      final err = next.errorMessage;
      if (err != null &&
          err != prev?.errorMessage &&
          err.toLowerCase().contains('izin bluetooth') &&
          context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(err),
              backgroundColor: AppColors.danger,
            ),
          );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RentCoreAppBar(
        title: 'Pengaturan Printer Thermal',
        actions: [
          IconButton(
            icon: state.isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                  )
                : const Icon(Icons.refresh_rounded),
            tooltip: 'Pindai Ulang',
            onPressed: state.isScanning ? null : () => notifier.scanDevices(),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.obsidian,
        onRefresh: () => notifier.scanDevices(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Connection Status Card
              _buildConnectionStatusCard(context, state, notifier),
              const SizedBox(height: 16),

              // Echo Mode Notice
              if (state.settings.printMode == PrintMode.echo) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: AppColors.info, size: 20),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Mode Echo Aktif: Cetak struk menggunakan layout kompak hemat kertas dengan tetap mempertahankan seluruh rincian transaksi.',
                          style: TextStyle(fontSize: 12, color: AppColors.info, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // 2. Hardware Configuration Card
              _buildHardwareOptionsCard(context, state, notifier),
              const SizedBox(height: 16),

              // 3. Quick Actions (Test Print & Customization)
              _buildQuickActionsCard(context, state, notifier),
              const SizedBox(height: 16),

              // 4. Advanced ESC/POS Settings (Extra Feed Lines & Raster QR)
              _buildAdvancedEscPosCard(context, state, notifier),
              const SizedBox(height: 20),

              // 5. Bluetooth Discovery List
              _buildDiscoveredDevicesSection(context, state, notifier),
              const SizedBox(height: 20),

              // 6. Live Sample Receipt Preview (Single Source of Truth)
              _buildSampleReceiptPreviewCard(context, state),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSampleReceiptPreviewCard(
    BuildContext context,
    PrinterState state,
  ) {
    final bizState = ref.watch(businessProvider);
    final sampleDoc = ReceiptDocumentData.sample(
      bizState,
      settings: state.settings,
    );
    final is58mm = sampleDoc.paperWidthMm < 80;
    final isEcho = sampleDoc.isCompactEcho;

    return Container(
      key: const Key('printer_settings_sample_preview_card'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'PRATINJAU STRUK SAMPEL',
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
                  is58mm ? '58mm • 32 Kolom' : '80mm • 48 Kolom',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          UnifiedThermalReceiptPreview(
            data: sampleDoc,
            paperEdgeLabel: isEcho
                ? (is58mm
                    ? 'MODE ECHO • KOMPAK (58MM)'
                    : 'MODE ECHO • KOMPAK (80MM)')
                : (is58mm
                    ? 'TEAR BAR MANUAL (58MM)'
                    : 'AUTO-CUTTER POS (80MM)'),
            paperEdgeIcon: isEcho
                ? Icons.eco_rounded
                : (is58mm
                    ? Icons.straighten_rounded
                    : Icons.content_cut_rounded),
            paperEdgeIconColor: isEcho ? AppColors.success : AppColors.textMuted,
          ),
        ],
      ),
    );
  }

  // --- 1. Connection Status Card ---
  Widget _buildConnectionStatusCard(
    BuildContext context,
    PrinterState state,
    PrinterNotifier notifier,
  ) {
    final connected = state.connectedDevice;
    final isConnected = state.status == PrinterConnectionStatus.connected && connected != null;
    final hasSavedDevice = connected != null && !isConnected;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConnected ? AppColors.successLight : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isConnected ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isConnected ? AppColors.success : AppColors.obsidian,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isConnected ? Icons.print_rounded : Icons.bluetooth_searching_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isConnected
                          ? connected.name
                          : (hasSavedDevice ? connected.name : 'Tidak Ada Printer Terhubung'),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isConnected
                          ? 'MAC: ${connected.address} • ${state.settings.paperWidth.label}'
                          : (hasSavedDevice
                              ? 'Tersimpan (MAC: ${connected.address}) • Terputus'
                              : 'Hubungkan printer Bluetooth dari daftar di bawah'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isConnected ? AppColors.success : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isConnected)
                TextButton(
                  onPressed: () => notifier.disconnect(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Putus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                )
              else if (hasSavedDevice)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: state.isConnecting ? null : () => notifier.connectDevice(connected),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.info,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: state.isConnecting
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Sambung', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                    TextButton(
                      onPressed: () => notifier.disconnect(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textMuted,
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Hapus', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
            ],
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      state.errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.danger, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. Hardware Configuration Card ---
  Widget _buildHardwareOptionsCard(
    BuildContext context,
    PrinterState state,
    PrinterNotifier notifier,
  ) {
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
            'KONFIGURASI PERANGKAT KERAS',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // Paper Width Radio
          const Text('Lebar Kertas Thermal:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: '58mm Portabel',
                  subtitle: '32 Kolom',
                  isSelected: state.settings.paperWidth == ReceiptPaperWidth.mm58,
                  onTap: () => notifier.setPaperWidth(ReceiptPaperWidth.mm58),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(
                  label: '80mm POS',
                  subtitle: '48 Kolom',
                  isSelected: state.settings.paperWidth == ReceiptPaperWidth.mm80,
                  onTap: () => notifier.setPaperWidth(ReceiptPaperWidth.mm80),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Print Mode Radio
          const Text('Mode Eksekusi Cetak:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoiceChip(
                  label: 'Normal',
                  subtitle: 'Cetak Fisik',
                  isSelected: state.settings.printMode == PrintMode.normal,
                  onTap: () => notifier.setPrintMode(PrintMode.normal),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildChoiceChip(
                  label: 'Echo',
                  subtitle: 'Format Kompak',
                  isSelected: state.settings.printMode == PrintMode.echo,
                  onTap: () => notifier.setPrintMode(PrintMode.echo),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAdvancedEscPosCard(
    BuildContext context,
    PrinterState state,
    PrinterNotifier notifier,
  ) {
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
            'KOMPATIBILITAS ESC/POS LANJUTAN',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),

          // Extra Feed Lines (default 3)
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Jarak Feed Kertas Akhir',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Jumlah baris kosong sebelum potong struk',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('feed_lines_decrement_button'),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: state.settings.extraFeedLines > 0
                        ? () => notifier.setExtraFeedLines(state.settings.extraFeedLines - 1)
                        : null,
                  ),
                  SizedBox(
                    width: 28,
                    child: Text(
                      '${state.settings.extraFeedLines}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ),
                  IconButton(
                    key: const Key('feed_lines_increment_button'),
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: state.settings.extraFeedLines < 15
                        ? () => notifier.setExtraFeedLines(state.settings.extraFeedLines + 1)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),

          // Raster QR Toggle (default false)
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode QR Raster Bitmap',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Cetak QR sebagai gambar monokrom untuk printer ESC/POS ekonomis',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('use_raster_qr_switch'),
                value: state.settings.useRasterQr,
                activeTrackColor: AppColors.obsidian,
                onChanged: (val) => notifier.setUseRasterQr(val),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.obsidian : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                color: isSelected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 3. Quick Actions Card ---
  Widget _buildQuickActionsCard(
    BuildContext context,
    PrinterState state,
    PrinterNotifier notifier,
  ) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surfaceMuted,
              foregroundColor: AppColors.textPrimary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: AppColors.border),
              ),
            ),
            icon: state.isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                  )
                : const Icon(Icons.print_outlined, size: 18),
            label: Text(
              state.isPrinting ? 'Mencetak...' : 'Test Print',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: state.isPrinting
                ? null
                : () async {
                    final ok = await notifier.printTestReceipt();
                    if (context.mounted) {
                      final errorMsg = ref.read(printerProvider).errorMessage;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            ok
                                ? 'Test print ${state.settings.printMode == PrintMode.echo ? "[ECHO]" : ""} berhasil dikirim!'
                                : (errorMsg ?? 'Gagal mengirim test print. Periksa koneksi printer.'),
                          ),
                          backgroundColor: ok ? AppColors.success : AppColors.danger,
                        ),
                      );
                    }
                  },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text(
              'Desain Struk',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ReceiptCustomizationScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  // --- 4. Discovered Devices Section ---
  Widget _buildDiscoveredDevicesSection(
    BuildContext context,
    PrinterState state,
    PrinterNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'PRINTER BLUETOOTH TERSEDIA',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: AppColors.textMuted,
              ),
            ),
            if (state.isScanning)
              const Row(
                children: [
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.obsidian),
                  ),
                  SizedBox(width: 6),
                  Text('Memindai...', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (state.discoveredDevices.isEmpty && state.isScanning)
          const SkeletonPulseWrapper(
            child: Column(
              children: [
                SkeletonCard(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SkeletonBox(width: 32, height: 32, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 140, height: 13, borderRadius: 4),
                            SizedBox(height: 4),
                            SkeletonBox(width: 90, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      SkeletonBox(width: 68, height: 26, borderRadius: 6),
                    ],
                  ),
                ),
                SkeletonCard(
                  margin: EdgeInsets.only(bottom: 8),
                  padding: EdgeInsets.all(12),
                  child: Row(
                    children: [
                      SkeletonBox(width: 32, height: 32, borderRadius: 8),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 120, height: 13, borderRadius: 4),
                            SizedBox(height: 4),
                            SkeletonBox(width: 80, height: 11, borderRadius: 4),
                          ],
                        ),
                      ),
                      SkeletonBox(width: 68, height: 26, borderRadius: 6),
                    ],
                  ),
                ),
              ],
            ),
          )
        else if (state.discoveredDevices.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.bluetooth_disabled_rounded, size: 36, color: AppColors.textMuted),
                const SizedBox(height: 10),
                const Text(
                  'Belum Menemukan Printer',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pastikan printer Bluetooth menyala, terpasang kertas, dan sudah dipasangkan (paired) di HP/tablet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => notifier.scanDevices(),
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Pindai Ulang Bluetooth', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                ),
              ],
            ),
          )
        else
          ...state.discoveredDevices.map((device) {
            final isCurrent = state.connectedDevice?.address == device.address &&
                state.status == PrinterConnectionStatus.connected;
            final isConnectingThis = state.isConnecting &&
                state.connectedDevice?.address == device.address;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrent ? AppColors.successLight : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isCurrent ? AppColors.success.withValues(alpha: 0.4) : AppColors.border,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isCurrent ? AppColors.success : AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.print_rounded,
                      size: 20,
                      color: isCurrent ? Colors.white : AppColors.obsidian,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'MAC: ${device.address}${device.isBonded ? ' • Paired' : ''}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (isCurrent)
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 22)
                  else
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: isConnectingThis
                          ? null
                          : () async {
                              final success = await notifier.connectDevice(device);
                              if (context.mounted) {
                                final err = ref.read(printerProvider).errorMessage;
                                ScaffoldMessenger.of(context)
                                  ..hideCurrentSnackBar()
                                  ..showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        success
                                            ? 'Berhasil terhubung ke ${device.name}'
                                            : (err ?? 'Gagal terhubung ke ${device.name}'),
                                      ),
                                      backgroundColor: success ? AppColors.success : AppColors.danger,
                                    ),
                                  );
                              }
                            },
                      child: isConnectingThis
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Hubungkan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }
}

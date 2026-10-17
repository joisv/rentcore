import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/thermal_printer_models.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../features/printer/presentation/printer_settings_screen.dart';
import '../../features/printer/providers/printer_provider.dart';

class ThermalReceiptPreviewDialog extends ConsumerStatefulWidget {
  final String title;
  final String branchName;
  final Uint8List escposBytes;
  final Widget content;
  final String? qrData;

  const ThermalReceiptPreviewDialog({
    super.key,
    required this.title,
    required this.branchName,
    required this.escposBytes,
    required this.content,
    this.qrData,
  });

  @override
  ConsumerState<ThermalReceiptPreviewDialog> createState() => _ThermalReceiptPreviewDialogState();
}

class _ThermalReceiptPreviewDialogState extends ConsumerState<ThermalReceiptPreviewDialog> {
  final _printerService = ThermalPrinterService();
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);
    final connectedDevice = printerState.connectedDevice ?? _printerService.connectedDevice;
    final isConnected = printerState.status == PrinterConnectionStatus.connected && connectedDevice != null;
    final isEcho = printerState.settings.printMode == PrintMode.echo;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Dialog
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Printer Connection Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isEcho
                  ? AppColors.infoLight
                  : (isConnected ? AppColors.successLight : AppColors.surfaceMuted),
              child: Row(
                children: [
                  Icon(
                    isEcho
                        ? Icons.visibility_rounded
                        : (isConnected ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded),
                    size: 18,
                    color: isEcho
                        ? AppColors.info
                        : (isConnected ? AppColors.success : AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEcho
                              ? 'Mode Echo (Virtual Audit)'
                              : (connectedDevice?.name ?? 'Tidak ada printer terhubung'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isEcho ? AppColors.info : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${printerState.settings.paperWidth.label} • ${isEcho ? "Simulasi Layar" : (isConnected ? "Siap Cetak" : "Offline")}',
                          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PrinterSettingsScreen()),
                      );
                    },
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Atur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Thermal Slip Paper Simulation
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Paper Header
                      Center(
                        child: Text(
                          printerState.settings.customShopName.isNotEmpty
                              ? printerState.settings.customShopName
                              : 'RENTCORE GADGETS',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          printerState.settings.customBranchName.isNotEmpty
                              ? printerState.settings.customBranchName
                              : widget.branchName,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        printerState.settings.separatorStyle == 'double'
                            ? '================================'
                            : '--------------------------------',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      // Injected Slip Content
                      widget.content,

                      // Optional 2D QR Code
                      if (widget.qrData != null && printerState.settings.showQrBarcode) ...[
                        const SizedBox(height: 12),
                        Center(
                          child: QrImageView(
                            data: widget.qrData!,
                            version: QrVersions.auto,
                            size: 130.0,
                            padding: const EdgeInsets.all(4),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            widget.qrData!,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 12),
                      Text(
                        printerState.settings.separatorStyle == 'double'
                            ? '================================'
                            : '--------------------------------',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'monospace', color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        printerState.settings.customFooterMessage.isNotEmpty
                            ? printerState.settings.customFooterMessage
                            : '*** TERIMA KASIH ***\nSimpan struk ini sebagai bukti resmi',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Print Action Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isPrinting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Icon(isEcho ? Icons.visibility_rounded : Icons.print_rounded, size: 20),
                label: Text(
                  _isPrinting
                      ? 'Memproses Cetak...'
                      : (isEcho ? 'Cetak Slip Echo (Kompak)' : 'Cetak Thermal (ESC/POS)'),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: _isPrinting ? null : () => _handlePrint(printerState),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint(PrinterState printerState) async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await _printerService.sendPrintJob(
        widget.escposBytes,
        printerState.settings.printMode,
      );

      if (mounted) {
        setState(() => _isPrinting = false);
        if (success) {
          Navigator.pop(context);
          final isEcho = printerState.settings.printMode == PrintMode.echo;
          messenger.showSnackBar(
            SnackBar(
              content: Text(
                'Berhasil mencetak slip ${isEcho ? "[ECHO] " : ""}ke ${_printerService.connectedDevice?.name ?? "Printer"}!',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Printer tidak terhubung atau Bluetooth terputus. Buka Pengaturan Printer.'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal mengirim data ke printer: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }
}

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../core/services/thermal_printer_service.dart';

class ThermalReceiptPreviewDialog extends StatefulWidget {
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
  State<ThermalReceiptPreviewDialog> createState() => _ThermalReceiptPreviewDialogState();
}

class _ThermalReceiptPreviewDialogState extends State<ThermalReceiptPreviewDialog> {
  final _printerService = ThermalPrinterService();
  bool _isPrinting = false;

  @override
  Widget build(BuildContext context) {
    final connectedDevice = _printerService.connectedDevice;

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
                  Text(
                    widget.title,
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: AppColors.surface,
              child: Row(
                children: [
                  Icon(
                    connectedDevice != null ? Icons.bluetooth_connected_rounded : Icons.bluetooth_disabled_rounded,
                    size: 18,
                    color: connectedDevice != null ? AppColors.success : AppColors.textMuted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      connectedDevice?.name ?? 'Tidak ada printer terhubung',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: _showPrinterSelectorDialog,
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Ganti', style: TextStyle(fontSize: 12)),
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
                      const Center(
                        child: Text(
                          'RENTCORE ELECTRONICS',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      Center(
                        child: Text(
                          widget.branchName,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '================================',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey),
                      ),
                      const SizedBox(height: 8),

                      // Injected Slip Content
                      widget.content,

                      // Optional 2D QR Code
                      if (widget.qrData != null) ...[
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
                      const Text(
                        '================================',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'monospace', color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '*** TERIMA KASIH ***\nSimpan struk ini sebagai bukti resmi',
                        textAlign: TextAlign.center,
                        style: TextStyle(
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
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.print_rounded, size: 20),
                label: Text(
                  _isPrinting ? 'Mencetak Slip...' : 'Cetak Thermal (ESC/POS)',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                onPressed: _isPrinting ? null : _handlePrint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePrint() async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final success = await _printerService.sendPrintJob(widget.escposBytes);
      if (mounted) {
        setState(() => _isPrinting = false);
        if (success) {
          Navigator.pop(context);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Berhasil mencetak slip ke ${_printerService.connectedDevice?.name}!'),
              backgroundColor: AppColors.success,
            ),
          );
        } else {
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Printer tidak terhubung atau Bluetooth terputus.'),
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

  void _showPrinterSelectorDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pilih Printer Bluetooth', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.print_rounded, color: AppColors.obsidian),
              title: const Text('RPP-02N Bluetooth (58mm)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: const Text('MAC: 00:11:22:33:44:55 • Paired', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success),
              onTap: () {
                _printerService.setConnectedDevice(const ThermalPrinterDevice(
                  name: 'RPP-02N Bluetooth Printer (58mm)',
                  address: '00:11:22:33:44:55',
                  isConnected: true,
                ));
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.print_rounded, color: AppColors.textMuted),
              title: const Text('PT-210 Mobile Printer (80mm)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              subtitle: const Text('MAC: 66:77:88:99:AA:BB • Ready', style: TextStyle(fontSize: 11)),
              onTap: () {
                _printerService.setConnectedDevice(const ThermalPrinterDevice(
                  name: 'PT-210 Mobile Printer (80mm)',
                  address: '66:77:88:99:AA:BB',
                  isConnected: true,
                ));
                setState(() {});
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup')),
        ],
      ),
    );
  }
}

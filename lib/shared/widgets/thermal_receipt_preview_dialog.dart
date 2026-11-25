import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/services/thermal_printer_service.dart';
import '../../core/widgets/unified_thermal_receipt_preview.dart';
import '../../features/auth/providers/business_provider.dart';
import '../../features/printer/presentation/printer_settings_screen.dart';
import '../../features/printer/providers/printer_provider.dart';

class ThermalReceiptPreviewDialog extends ConsumerStatefulWidget {
  final String title;
  final String branchName;
  final String? shopName;
  final String? branchAddress;
  final String? branchPhone;
  final bool isReprint;
  final bool autoShareOnOpen;
  final Future<void> Function(Uint8List pngBytes, String caption)? onShareImage;
  final Uint8List escposBytes;
  final Widget? content;
  final ReceiptDocumentData? document;
  final String? qrData;

  const ThermalReceiptPreviewDialog({
    super.key,
    required this.title,
    required this.branchName,
    required this.escposBytes,
    this.content,
    this.document,
    this.shopName,
    this.branchAddress,
    this.branchPhone,
    this.isReprint = false,
    this.autoShareOnOpen = false,
    this.onShareImage,
    this.qrData,
  });

  /// Unified constructor backed by [ReceiptDocumentData] (Single Source of Truth).
  factory ThermalReceiptPreviewDialog.fromDocument({
    Key? key,
    required String title,
    required ReceiptDocumentData document,
    bool autoShareOnOpen = false,
    Future<void> Function(Uint8List pngBytes, String caption)? onShareImage,
  }) {
    return ThermalReceiptPreviewDialog(
      key: key,
      title: title,
      shopName: document.storeName,
      branchName: document.branchName,
      branchAddress: document.storeAddress.isNotEmpty ? document.storeAddress : null,
      branchPhone: document.storePhone.isNotEmpty ? document.storePhone : null,
      isReprint: document.isReprint,
      autoShareOnOpen: autoShareOnOpen,
      onShareImage: onShareImage,
      qrData: document.effectiveQrData,
      document: document,
      escposBytes: ThermalReceiptEscPosBuilder.build(document),
    );
  }

  @override
  ConsumerState<ThermalReceiptPreviewDialog> createState() =>
      _ThermalReceiptPreviewDialogState();
}

class _ThermalReceiptPreviewDialogState
    extends ConsumerState<ThermalReceiptPreviewDialog> {
  final _printerService = ThermalPrinterService();
  final _receiptBoundaryKey = GlobalKey();
  bool _isPrinting = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoShareOnOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _handleShareReceipt();
        }
      });
    }
  }

  String _resolveFirstNonEmpty(List<String?> candidates, String fallback) {
    for (final candidate in candidates) {
      final trimmed = candidate?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final printerState = ref.watch(printerProvider);
    final bizState = ref.watch(businessProvider);
    final connectedDevice =
        printerState.connectedDevice ?? _printerService.connectedDevice;
    final isConnected =
        printerState.status == PrinterConnectionStatus.connected &&
        connectedDevice != null;
    final isEcho = printerState.settings.printMode == PrintMode.echo;

    final resolvedShopName = _resolveFirstNonEmpty(
      [
        printerState.settings.customShopName,
        widget.shopName,
        bizState.resolvedStoreName,
      ],
      'Toko Rental',
    );
    final resolvedBranchName = _resolveFirstNonEmpty(
      [
        printerState.settings.customBranchName,
        widget.branchName,
        bizState.resolvedBranchName,
      ],
      'Cabang Utama',
    );
    final resolvedAddress = _resolveFirstNonEmpty(
      [
        printerState.settings.storeAddress,
        widget.branchAddress,
        bizState.resolvedBranchAddress,
      ],
      '',
    );
    final resolvedPhone = _resolveFirstNonEmpty(
      [
        printerState.settings.storePhone,
        widget.branchPhone,
        bizState.resolvedBranchPhone,
      ],
      '',
    );
    final dividerText = printerState.settings.separatorStyle == 'double'
        ? '================================'
        : '--------------------------------';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
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
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
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
                  : (isConnected
                        ? AppColors.successLight
                        : AppColors.surfaceMuted),
              child: Row(
                children: [
                  Icon(
                    isEcho
                        ? Icons.visibility_rounded
                        : (isConnected
                              ? Icons.bluetooth_connected_rounded
                              : Icons.bluetooth_disabled_rounded),
                    size: 18,
                    color: isEcho
                        ? AppColors.info
                        : (isConnected
                              ? AppColors.success
                              : AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEcho
                              ? 'Mode Echo (Virtual Audit)'
                              : (connectedDevice?.name ??
                                    'Tidak ada printer terhubung'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isEcho
                                ? AppColors.info
                                : AppColors.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${printerState.settings.paperWidth.label} • ${isEcho ? "Simulasi Layar" : (isConnected ? "Siap Cetak" : (connectedDevice != null ? "Siap Auto-Reconnect" : "Offline"))}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PrinterSettingsScreen(),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text(
                      'Atur',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.border),

            // Thermal Slip Paper Simulation wrapped in RepaintBoundary for PNG share
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: _receiptBoundaryKey,
                  child: widget.document != null
                      ? UnifiedThermalReceiptPreview(
                          data: widget.document!.applySettings(
                            printerState.settings,
                            business: bizState,
                          ),
                          showBottomTearEdge: true,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
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
                                  resolvedShopName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                              if (printerState.settings.customSlogan.trim().isNotEmpty)
                                Center(
                                  child: Text(
                                    printerState.settings.customSlogan.trim(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              Center(
                                child: Text(
                                  resolvedBranchName,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (resolvedAddress.isNotEmpty)
                                Center(
                                  child: Text(
                                    resolvedAddress,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              if (resolvedPhone.isNotEmpty)
                                Center(
                                  child: Text(
                                    'Telp: $resolvedPhone',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 6),
                              Text(
                                dividerText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.grey,
                                ),
                              ),
                              if (widget.isReprint) ...[
                                const SizedBox(height: 4),
                                const Center(
                                  child: Text(
                                    '-- CETAK ULANG --',
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),

                              // Injected Slip Content
                              if (widget.content != null) widget.content!,

                              // Optional 2D QR Code
                              if (widget.qrData != null &&
                                  printerState.settings.showQrBarcode) ...[
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
                                dividerText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.grey,
                                ),
                              ),
                              if (printerState.settings.showReturnTerms &&
                                  printerState.settings.returnTermsText.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  printerState.settings.returnTermsText.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 9.5,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                              if (printerState.settings.customFooterMessage.trim().isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  printerState.settings.customFooterMessage.trim(),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 10,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),
            ),

            // Action Buttons: Bagikan Struk (WhatsApp/PNG) + Cetak Thermal
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('share_receipt_png_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.obsidian,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isSharing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.obsidian,
                              ),
                            )
                          : const Icon(Icons.share_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Bagikan Struk',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      onPressed: (_isSharing || _isPrinting)
                          ? null
                          : _handleShareReceipt,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('print_thermal_receipt_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: _isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              isEcho ? Icons.visibility_rounded : Icons.print_rounded,
                              size: 18,
                            ),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          _isPrinting
                              ? 'Mencetak...'
                              : (isEcho ? 'Cetak Echo' : 'Cetak Thermal'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      onPressed: (_isPrinting || _isSharing)
                          ? null
                          : () => _handlePrint(printerState),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleShareReceipt() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final boundary = _receiptBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) {
        throw StateError('Pratinjau struk belum siap dirender.');
      }

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('Gagal mengonversi struk menjadi PNG.');
      }
      final pngBytes = byteData.buffer.asUint8List();

      final shopLabel = _resolveFirstNonEmpty(
        [
          ref.read(printerProvider).settings.customShopName,
          widget.shopName,
          ref.read(businessProvider).resolvedStoreName,
        ],
        'Struk Digital',
      );
      final caption = '${widget.title} - $shopLabel';

      if (widget.onShareImage != null) {
        await widget.onShareImage!(pngBytes, caption);
      } else {
        final tempDir = await getTemporaryDirectory();
        final filePath =
            '${tempDir.path}${Platform.pathSeparator}struk_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes, flush: true);
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(file.path, mimeType: 'image/png')],
            text: caption,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Gagal membagikan struk: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
      }
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _handlePrint(PrinterState printerState) async {
    setState(() => _isPrinting = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final bool success;
      if (widget.document != null) {
        final effectiveDoc = widget.document!.applySettings(
          printerState.settings,
          business: ref.read(businessProvider),
        );
        success = await ref
            .read(printerProvider.notifier)
            .printReceiptDocument(effectiveDoc);
      } else {
        success = await ref
            .read(printerProvider.notifier)
            .sendRawBytes(widget.escposBytes);
      }

      if (mounted) {
        setState(() => _isPrinting = false);
        if (success) {
          Navigator.pop(context);
          final isEcho = printerState.settings.printMode == PrintMode.echo;
          final printerName =
              _printerService.connectedDevice?.name ??
              printerState.connectedDevice?.name ??
              'Printer';
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  'Berhasil mencetak slip ${isEcho ? "[ECHO] " : ""}ke $printerName!',
                ),
                backgroundColor: AppColors.success,
              ),
            );
        } else {
          final err =
              ref.read(printerProvider).errorMessage ??
              _printerService.lastError ??
              'Printer tidak terhubung atau Bluetooth terputus. Buka Pengaturan Printer.';
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(err),
                backgroundColor: AppColors.danger,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isPrinting = false);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Gagal mengirim data ke printer: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
      }
    }
  }
}

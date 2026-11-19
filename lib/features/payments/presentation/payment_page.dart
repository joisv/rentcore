import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/qris_service.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/cash_suggestion_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/idempotency_helper.dart';
import '../../../core/widgets/animated_success_checkmark.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/presentation/widgets/quick_open_shift_modal.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../data/payment_repository.dart';
import '../models/payment_context.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final PaymentContext paymentContext;
  final bool isModal;
  final VoidCallback? onPaymentSuccess;
  final PaymentResult? initialResult;

  const PaymentPage({
    super.key,
    required this.paymentContext,
    this.isModal = false,
    this.onPaymentSuccess,
    this.initialResult,
  });

  /// Factory constructor to launch universal payment screen with raw transaction parameters
  factory PaymentPage.fromTransaction({
    Key? key,
    required dynamic transactionType,
    int? referenceId,
    int? bookingId,
    String? bookingCode,
    required double totalAmount,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
    String? deviceName,
    String? assetCode,
    int? branchId,
    String? branchName,
    bool isCentral = false,
    int? additionalHours,
    Map<String, dynamic>? metadata,
    List<PaymentItem>? items,
    bool isModal = false,
    VoidCallback? onPaymentSuccess,
  }) {
    final ctx = PaymentContext.fromGeneric(
      transactionType: transactionType,
      referenceId: referenceId,
      bookingId: bookingId,
      bookingCode: bookingCode,
      totalAmount: totalAmount,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      deviceName: deviceName,
      assetCode: assetCode,
      branchId: branchId,
      branchName: branchName,
      isCentral: isCentral,
      additionalHours: additionalHours,
      metadata: metadata,
      items: items,
    );
    return PaymentPage(
      key: key,
      paymentContext: ctx,
      isModal: isModal,
      onPaymentSuccess: onPaymentSuccess,
    );
  }

  @override
  ConsumerState<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends ConsumerState<PaymentPage> {
  final _cashReceivedController = TextEditingController();
  final _notesController = TextEditingController();
  final _externalRefController = TextEditingController();

  String _formatEditableAmount(double amount) {
    return amount % 1 == 0 ? amount.toInt().toString() : amount.toStringAsFixed(2);
  }

  int? _selectedMethodId;
  String _selectedMethodCode = 'CASH';
  String _selectedMethodName = 'Tunai';
  String? _selectedQrisImageUrl;
  bool _isDynamicQrisEnabled = false;
  String? _qrisRawPayload;
  String _selectedEwallet = 'ShopeePay';
  bool _nonCashConfirmed = true;
  bool _isProcessing = false;
  bool _methodInitialized = false;
  PaymentResult? _completedResult;
  late final String _attemptIdempotencyKey;

  @override
  void initState() {
    super.initState();
    final ctxKey = widget.paymentContext.idempotencyKey?.trim();
    _attemptIdempotencyKey = (ctxKey != null && ctxKey.isNotEmpty)
        ? ctxKey
        : IdempotencyHelper.generateUuidV4();
    if (widget.initialResult != null) {
      _completedResult = widget.initialResult;
    }
    _cashReceivedController.addListener(() {
      if (mounted) setState(() {});
    });
    _cashReceivedController.text = _formatEditableAmount(widget.paymentContext.remainingDue);
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _notesController.dispose();
    _externalRefController.dispose();
    super.dispose();
  }

  String _formatNumber(num value) {
    final str = value.toInt().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }

  bool _checkShiftActive(Map<String, dynamic>? data) {
    if (data == null) return false;
    if (data['has_active_shift'] == true) return true;
    if (data['is_active'] == true) return true;
    final shift = data['shift'] ?? data['data']?['shift'];
    if (shift is Map && (shift['status'] == 'open' || shift['is_active'] == true)) {
      return true;
    }
    return false;
  }

  bool _requiresOpenShift(Map<String, dynamic>? data) {
    return isShiftEnforcementEnabledFromPayload(data) && !_checkShiftActive(data);
  }

  void _showQuickOpenShiftModal(BuildContext context, int? branchId) {
    QuickOpenShiftModal.show(
      context,
      branchId: branchId,
      onShiftOpened: () {
        ref.invalidate(currentShiftProvider);
        if (branchId != null) {
          ref.invalidate(currentShiftByBranchProvider(branchId));
        }
      },
    );
  }

  Widget _buildShiftWarningBanner(BuildContext context, int? branchId) {
    return Material(
      key: const Key('shift_activation_warning_banner'),
      color: Colors.transparent,
      child: InkWell(
        key: const Key('open_shift_now_button'),
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showQuickOpenShiftModal(context, branchId),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: Color(0xFFB45309),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Shift kasir belum dibuka',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              Text(
                'Buka Shift ›',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF92400E),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShiftWarningSlot(
    BuildContext context,
    int? branchId,
    AsyncValue<Map<String, dynamic>> currentShiftByBranchAsync,
    AsyncValue<Map<String, dynamic>> currentShiftGeneralAsync,
  ) {
    Widget renderIfUnopened(Map<String, dynamic> shiftData) {
      if (!_requiresOpenShift(shiftData)) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _buildShiftWarningBanner(context, branchId),
      );
    }

    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: currentShiftByBranchAsync.maybeWhen(
        data: renderIfUnopened,
        orElse: () {
          if (currentShiftByBranchAsync.isLoading) {
            return const SizedBox.shrink();
          }
          return currentShiftGeneralAsync.maybeWhen(
            data: renderIfUnopened,
            orElse: () => const SizedBox.shrink(),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctx = widget.paymentContext;
    final amountDue = ctx.remainingDue;
    final bizState = ref.watch(businessProvider);
    final effectiveBranchId = ctx.branchId ?? bizState.activeBranchId;
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final paymentSettingsAsync = ref.watch(paymentSettingsProvider(effectiveBranchId));

    final currentShiftByBranchAsync = ref.watch(currentShiftByBranchProvider(effectiveBranchId));
    final currentShiftGeneralAsync = ref.watch(currentShiftProvider);

    final settingsData = paymentSettingsAsync.value;
    final config = (settingsData?['config'] as Map<String, dynamic>?) ??
                   (settingsData?['data']?['config'] as Map<String, dynamic>?);

    final paymentMethods = paymentMethodsAsync.value ?? [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai', 'is_active': true},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS', 'is_active': true},
      {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank', 'is_active': true},
    ];

    // Method active toggles from settings / payment methods
    final isCashEnabled = config != null
        ? (config['cash_enabled'] != false)
        : paymentMethods.any((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH' && m['is_active'] != false);

    final isQrisEnabled = config != null
        ? (config['qris_statis_enabled'] != false)
        : paymentMethods.any((m) => (m['code'] ?? '').toString().toUpperCase() == 'QRIS' && m['is_active'] != false);

    final isEwalletMasterEnabled = config != null ? (config['ewallet_enabled'] != false) : true;
    final providers = (config?['ewallet_providers'] as Map<String, dynamic>?) ?? {};
    final isShopeePayEnabled = isEwalletMasterEnabled && (providers['shopeepay'] != false);
    final isDanaEnabled = isEwalletMasterEnabled && (providers['dana'] != false);
    final isLinkAjaEnabled = isEwalletMasterEnabled && (providers['linkaja'] != false);
    final isOvoEnabled = isEwalletMasterEnabled && (providers['ovo'] != false);
    final isGopayEnabled = isEwalletMasterEnabled && (providers['gopay'] != false);
    final hasAnyActiveEwallet = isShopeePayEnabled || isDanaEnabled || isLinkAjaEnabled || isOvoEnabled || isGopayEnabled;

    final isBankTransferEnabled = config != null ? (config['bank_transfer_enabled'] != false) : true;

    final hasOtherDirectMethod = paymentMethods.any((m) {
      final code = (m['code'] ?? '').toString().toUpperCase();
      return code != 'CASH' && code != 'QRIS' && m['is_active'] != false;
    });
    final isOtherEnabled = hasAnyActiveEwallet || isBankTransferEnabled || hasOtherDirectMethod;

    final qrisMethod = paymentMethods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'QRIS').firstOrNull;
    final isDynamicQrisEnabled = config != null
        ? (config['is_dynamic_qris_enabled'] == true)
        : (qrisMethod?['is_dynamic_qris_enabled'] == true);
    final qrisRawPayload = config?['qris_raw_payload'] as String? ?? (qrisMethod?['qris_raw_payload'] as String?);
    final qrisImageUrl = config?['qris_image_url'] as String? ?? (qrisMethod?['qris_image_url'] as String?);

    paymentMethodsAsync.whenData((methods) {
      if (!_methodInitialized && methods.isNotEmpty) {
        _methodInitialized = true;
        if (isCashEnabled) {
          final cashMethod = methods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH').firstOrNull ?? methods.first;
          _selectedMethodId = cashMethod['id'] as int?;
          _selectedMethodCode = (cashMethod['code'] ?? 'CASH').toString().toUpperCase();
          _selectedMethodName = cashMethod['name'] ?? 'Tunai';
        } else if (isQrisEnabled) {
          final qrisMethod = methods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'QRIS').firstOrNull ?? methods.first;
          _selectedMethodId = qrisMethod['id'] as int?;
          _selectedMethodCode = (qrisMethod['code'] ?? 'QRIS').toString().toUpperCase();
          _selectedMethodName = qrisMethod['name'] ?? 'QRIS';
        } else if (isOtherEnabled) {
          final otherMethod = methods.where((m) => (m['code'] ?? '').toString().toUpperCase() != 'CASH' && (m['code'] ?? '').toString().toUpperCase() != 'QRIS').firstOrNull ?? methods.first;
          _selectedMethodId = otherMethod['id'] as int?;
          _selectedMethodCode = (otherMethod['code'] ?? 'TRANSFER').toString().toUpperCase();
          _selectedMethodName = otherMethod['name'] ?? 'Pembayaran Lainnya';
        }
      }
    });

    if (_completedResult != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: AppColors.obsidian),
            onPressed: () => Navigator.pop(context, _completedResult),
          ),
          title: const Text('Pembayaran Sukses'),
        ),
        body: _buildSuccessView(context, _completedResult!),
      );
    }

    // Default: The Unified Universal Review & Pay Gateway
    return PopScope<PaymentResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(
          context,
          _completedResult ?? const PaymentResult(status: PaymentStatus.cancelled),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.obsidian),
            tooltip: 'Batalkan Pembayaran',
            onPressed: () {
              Navigator.pop(
                context,
                _completedResult ?? const PaymentResult(status: PaymentStatus.cancelled),
              );
            },
          ),
          title: Text(ctx.pageHeaderTitle),
          centerTitle: false,
        ),
        body: SafeArea(
          child: Column(
            children: [
              // Vertically Centered Tagihan + Rp Amount + Detail Link
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        ctx.tagihanLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rp${_formatNumber(amountDue)}',
                        style: const TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111111),
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () => _showDetailSewaSheet(context, ctx, amountDue),
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            ctx.detailLinkText,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0A93B9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Action Buttons: Dynamically filtered based on toggles
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildShiftWarningSlot(
                      context,
                      effectiveBranchId,
                      currentShiftByBranchAsync,
                      currentShiftGeneralAsync,
                    ),
                    Builder(
                      builder: (context) {
                        final activeCards = <Widget>[];

                        if (isQrisEnabled) {
                          activeCards.add(
                            Expanded(
                              child: _buildBottomMethodCard(
                                title: 'QRIS',
                                customIcon: _buildQrisLogoWidget(),
                                onTap: () {
                                  final qMethod = paymentMethods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'QRIS').firstOrNull;
                                  _selectedMethodId = qMethod?['id'] as int? ?? 2;
                                  _selectedMethodCode = 'QRIS';
                                  _selectedMethodName = qMethod?['name'] ?? 'QRIS';
                                  _selectedQrisImageUrl = qrisImageUrl;
                                  _isDynamicQrisEnabled = isDynamicQrisEnabled;
                                  _qrisRawPayload = qrisRawPayload;
                                  _showQrisSheet(context, ctx, amountDue);
                                },
                              ),
                            ),
                          );
                        }

                        if (isCashEnabled) {
                          activeCards.add(
                            Expanded(
                              child: _buildBottomMethodCard(
                                title: 'Tunai',
                                customIcon: _buildCashBillIconWidget(),
                                onTap: () {
                                  final cashMethod = paymentMethods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH').firstOrNull;
                                  _selectedMethodId = cashMethod?['id'] as int? ?? 1;
                                  _selectedMethodCode = 'CASH';
                                  _selectedMethodName = cashMethod?['name'] ?? 'Tunai';
                                  _cashReceivedController.text = _formatEditableAmount(amountDue);
                                  _showCashSheet(context, ctx, amountDue);
                                },
                              ),
                            ),
                          );
                        }

                        if (isOtherEnabled) {
                          activeCards.add(
                            Expanded(
                              child: _buildBottomMethodCard(
                                title: 'Lainnya',
                                customIcon: _buildOptionIconWidget(),
                                onTap: () {
                                  if (_selectedEwallet.isNotEmpty) {
                                    _applySelectedPaymentOption(_selectedEwallet, paymentMethods);
                                  } else {
                                    final otherMethod = paymentMethods.where((m) {
                                      final code = (m['code'] ?? '').toString().toUpperCase();
                                      return code != 'CASH' && code != 'QRIS';
                                    }).firstOrNull;
                                    _selectedMethodId = otherMethod?['id'] as int? ?? 3;
                                    _selectedMethodCode = otherMethod?['code']?.toString().toUpperCase() ?? 'TRANSFER';
                                    _selectedMethodName = otherMethod?['name'] ?? 'Pembayaran Lainnya';
                                  }
                                  _showEwalletSheet(
                                    context,
                                    ctx,
                                    amountDue,
                                    paymentMethods,
                                    isEwalletMasterEnabled: isEwalletMasterEnabled,
                                    isBankTransferEnabled: isBankTransferEnabled,
                                    isShopeePayEnabled: isShopeePayEnabled,
                                    isDanaEnabled: isDanaEnabled,
                                    isLinkAjaEnabled: isLinkAjaEnabled,
                                    isOvoEnabled: isOvoEnabled,
                                    isGopayEnabled: isGopayEnabled,
                                  );
                                },
                              ),
                            ),
                          );
                        }

                        if (activeCards.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF2F2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFEF4444)),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.info_outline_rounded, color: Color(0xFFDC2626), size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Tidak ada metode pembayaran aktif.',
                                  style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ],
                            ),
                          );
                        }

                        return Row(
                          children: [
                            for (int i = 0; i < activeCards.length; i++) ...[
                              if (i > 0) const SizedBox(width: 12),
                              activeCards[i],
                            ],
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BOTTOM METHOD BUTTONS (CARD STYLE WITH BLACK BORDER)
  // =========================================================================
  Widget _buildBottomMethodCard({
    required String title,
    required Widget customIcon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.black,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon,
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrisLogoWidget() {
    return SvgPicture.asset(
      'assets/logos/QRIS Logo - Black - zonalogo.com.svg',
      height: 24,
      fit: BoxFit.contain,
    );
  }

  Widget _buildCashBillIconWidget() {
    return SvgPicture.asset(
      'assets/logos/cash-stack-svgrepo-com.svg',
      height: 24,
      width: 24,
      fit: BoxFit.contain,
    );
  }

  Widget _buildOptionIconWidget() {
    return SvgPicture.asset(
      'assets/logos/option-svgrepo-com.svg',
      height: 22,
      width: 22,
      fit: BoxFit.contain,
    );
  }

  Widget _buildDetailBreakdownRow(
    String label,
    String value, {
    Color labelColor = const Color(0xFF6B7280),
    Color valueColor = const Color(0xFF111111),
    FontWeight labelWeight = FontWeight.w500,
    FontWeight valueWeight = FontWeight.w600,
    double labelSize = 12,
    double valueSize = 12,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: labelSize,
                fontWeight: labelWeight,
                color: labelColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: valueWeight,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BOTTOM SHEET 1: DETAIL SEWA (MATCHING IMAGE 2)
  // =========================================================================
  void _showDetailSewaSheet(BuildContext context, PaymentContext ctx, double amountDue) {
    final now = DateTime.now();
    final formattedDate =
        '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final subtotal = (ctx.primarySubtotal != null || ctx.addonSubtotal != null)
        ? ((ctx.primarySubtotal ?? 0) + (ctx.addonSubtotal ?? 0))
        : ctx.totalAmountDue;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final bizState = ref.watch(businessProvider);
            final effectiveBranchId = ctx.branchId ?? bizState.activeBranchId;
            final currentShiftByBranchAsync = ref.watch(currentShiftByBranchProvider(effectiveBranchId));
            final currentShiftGeneralAsync = ref.watch(currentShiftProvider);
            final currentShiftData = currentShiftByBranchAsync.value ?? currentShiftGeneralAsync.value;
            final requiresOpenShift = _requiresOpenShift(currentShiftData);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title: Detail Sewa / Detail Denda RC-2610-20-0002
                  Center(
                    child: Text(
                      '${ctx.detailLinkText} ${ctx.bookingCode ?? "RC-2610-20-0002"}',
                      style: AppTextStyles.pageHeader,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, thickness: 1, color: Color(0xFF71717A)),
                  const SizedBox(height: 14),

                  // Header Info: Customer (Left) & Branch/Date (Right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ctx.customerName.isNotEmpty ? ctx.customerName : 'Dimas Jois Vanka',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (ctx.customerPhone != null && ctx.customerPhone!.isNotEmpty)
                                  ? ctx.customerPhone!
                                  : '0831-4683-8432',
                              style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                            ),
                            if (ctx.customerAddress != null && ctx.customerAddress!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                ctx.customerAddress!,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF71717A)),
                              ),
                            ] else ...[
                              const SizedBox(height: 2),
                              const Text('Sempu Gambiran', style: TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'Cabang ${ctx.branchName ?? "Sukonatar"}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            formattedDate,
                            style: const TextStyle(fontSize: 11, color: Colors.black),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Itemized List
                  if (ctx.items.isNotEmpty) ...[
                    ...ctx.items.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      item.name,
                                      style: const TextStyle(fontSize: 12, color: Colors.black),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (item.isAddon) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: const Color(0xFFA1A1AA)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('add-on', style: TextStyle(fontSize: 8, color: Color(0xFF71717A))),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_formatNumber(item.price)} × ${item.durationText ?? "24 Jam"}',
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                            ),
                          ],
                        ),
                      );
                    }),
                  ] else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              ctx.deviceName ?? 'iPhone XR Hijau',
                              style: const TextStyle(fontSize: 12, color: Colors.black),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text('${_formatNumber(ctx.totalAmountDue)} × 24 Jam', style: const TextStyle(fontSize: 12, color: Colors.black)),
                        ],
                      ),
                    ),
                  ],

                  // Durasi Sewa
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Durasi Sewa', style: TextStyle(fontSize: 12, color: Colors.black)),
                        Text('${ctx.additionalHours ?? 24} Jam', style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ],
                    ),
                  ),

                  // Diskon
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Diskon', style: TextStyle(fontSize: 12, color: Colors.black)),
                        Text(
                          (ctx.discountAmount != null && ctx.discountAmount! > 0)
                              ? '- Rp ${_formatNumber(ctx.discountAmount!)}'
                              : '-',
                          style: const TextStyle(fontSize: 12, color: Colors.black),
                        ),
                      ],
                    ),
                  ),

                  // Subtotal
                  _buildDetailBreakdownRow(
                    'Subtotal',
                    'Rp ${_formatNumber(subtotal)}',
                    labelColor: Colors.black,
                    valueColor: Colors.black,
                    labelWeight: FontWeight.w400,
                    valueWeight: FontWeight.w400,
                  ),

                  const SizedBox(height: 6),
                  const Divider(height: 1, thickness: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 12),

                  // Payment & DP Breakdown
                  Column(
                    key: const Key('detail_sheet_payment_breakdown'),
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ctx.isDownPayment) ...[
                        _buildDetailBreakdownRow(
                          'Total Sewa',
                          'Rp ${_formatNumber(ctx.effectiveContractTotal)}',
                        ),
                        _buildDetailBreakdownRow(
                          'Nominal DP Dibayar Sekarang',
                          'Rp ${_formatNumber(amountDue)}',
                          labelColor: const Color(0xFF111111),
                          valueColor: const Color(0xFF22C55E),
                          labelWeight: FontWeight.w700,
                          valueWeight: FontWeight.w700,
                          labelSize: 13,
                          valueSize: 14,
                        ),
                        if (ctx.remainingAfterCurrentPayment > 0)
                          _buildDetailBreakdownRow(
                            'Sisa Tagihan (Saat Ambil Unit)',
                            'Rp ${_formatNumber(ctx.remainingAfterCurrentPayment)}',
                            labelColor: const Color(0xFF111111),
                            valueColor: const Color(0xFF111111),
                            labelWeight: FontWeight.w700,
                            valueWeight: FontWeight.w700,
                          ),
                      ] else if (ctx.transactionType ==
                              PaymentTransactionType.settlement &&
                          ctx.previouslyPaidAmount > 0) ...[
                        _buildDetailBreakdownRow(
                          'Total Sewa',
                          'Rp ${_formatNumber(ctx.effectiveContractTotal)}',
                        ),
                        _buildDetailBreakdownRow(
                          'Sudah Dibayar',
                          '- Rp ${_formatNumber(ctx.previouslyPaidAmount)}',
                          valueColor: const Color(0xFF6B7280),
                          valueWeight: FontWeight.w500,
                        ),
                        _buildDetailBreakdownRow(
                          'Sisa Tagihan (Saat Ambil Unit)',
                          'Rp ${_formatNumber(amountDue)}',
                          labelColor: const Color(0xFF111111),
                          valueColor: const Color(0xFF111111),
                          labelWeight: FontWeight.w700,
                          valueWeight: FontWeight.w700,
                          labelSize: 13,
                          valueSize: 14,
                        ),
                      ] else ...[
                        if (ctx.transactionType !=
                            PaymentTransactionType.penalty)
                          _buildDetailBreakdownRow(
                            'Total Sewa',
                            'Rp ${_formatNumber(ctx.effectiveContractTotal)}',
                          ),
                        _buildDetailBreakdownRow(
                          'Total',
                          'Rp ${_formatNumber(amountDue)}',
                          labelColor: const Color(0xFF111111),
                          valueColor: const Color(0xFF22C55E),
                          labelWeight: FontWeight.w700,
                          valueWeight: FontWeight.w700,
                          labelSize: 13,
                          valueSize: 14,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (requiresOpenShift) ...[
                    _buildShiftWarningBanner(sheetContext, effectiveBranchId),
                    const SizedBox(height: 12),
                  ],

                  // Button: KONFIRMASI PEMBAYARAN
                  ElevatedButton(
                    key: const Key('detail_sheet_confirm_button'),
                    onPressed: requiresOpenShift
                        ? null
                        : () {
                            Navigator.pop(sheetContext);
                            _showCashSheet(context, ctx, amountDue);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF18181B).withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'KONFIRMASI PEMBAYARAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  // =========================================================================
  // BOTTOM SHEET 2: PEMBAYARAN TUNAI (MATCHING IMAGE 3)
  // =========================================================================
  void _showCashSheet(BuildContext context, PaymentContext ctx, double amountDue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final bizState = ref.watch(businessProvider);
            final effectiveBranchId = ctx.branchId ?? bizState.activeBranchId;
            final currentShiftByBranchAsync = ref.watch(currentShiftByBranchProvider(effectiveBranchId));
            final currentShiftGeneralAsync = ref.watch(currentShiftProvider);
            final currentShiftData = currentShiftByBranchAsync.value ?? currentShiftGeneralAsync.value;
            final requiresOpenShift = _requiresOpenShift(currentShiftData);

            return StatefulBuilder(
              builder: (context, setSheetState) {
            final cashReceived = CurrencyFormatter.parse(_cashReceivedController.text);
            final cashShortage = CashPaymentSuggestionHelper.calculateShortage(amountDue: amountDue, cashReceived: cashReceived);
            final cashChange = CashPaymentSuggestionHelper.calculateChange(amountDue: amountDue, cashReceived: cashReceived);

            final suggestions = CashPaymentSuggestionHelper.getSuggestedAmounts(amountDue);
            final displaySuggestions = suggestions.isNotEmpty
                ? suggestions
                : [amountDue.toInt(), (amountDue * 2).toInt()];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title: PEMBAYARAN TUNAI
                      const Center(
                        child: Text(
                          'PEMBAYARAN TUNAI',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Box 1: Tagihan Sewa
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF71717A)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ctx.isDownPayment ? 'Nominal DP Dibayar Sekarang' : 'Tagihan Sewa',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF676767)),
                            ),
                            Text(
                              'Rp  ${_formatNumber(amountDue)}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF676767)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Box 2: Jumlah Uang Diterima Input (Aligned with Customer Form InputDecoration)
                      TextFormField(
                        controller: _cashReceivedController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Jumlah uang diterima',
                          labelStyle: const TextStyle(color: Color(0xFF676767), fontSize: 11, fontWeight: FontWeight.w400),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF71717A), width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF71717A), width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.black, width: 1.5),
                          ),
                          prefixIcon: const SizedBox(
                            width: 38,
                            child: Center(
                              child: Text(
                                'Rp',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: Color(0xFF676767),
                                ),
                              ),
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_circle_outline_rounded, color: Colors.black),
                            tooltip: 'Uang Pas',
                            onPressed: () {
                              _cashReceivedController.text = _formatEditableAmount(amountDue);
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                        ),
                        onChanged: (_) {
                          setSheetState(() {});
                          setState(() {});
                        },
                      ),
                      const SizedBox(height: 12),

                      // Quick Chips: Rp 50.000 / Rp 100.000 (Active is solid black)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: displaySuggestions.take(3).map((amt) {
                          final isSelected = cashReceived.toInt() == amt;
                          return InkWell(
                            onTap: () {
                              _cashReceivedController.text = amt.toString();
                              setSheetState(() {});
                              setState(() {});
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.black : Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.black, width: 1.0),
                              ),
                              child: Text(
                                'Rp ${_formatNumber(amt)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),

                      // Box 3: Kembalian Pelanggan (Light Green Box)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: cashShortage > 0
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFF86EFAC).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: cashShortage > 0 ? const Color(0xFFEF4444) : const Color(0xFF22C55E),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              cashShortage > 0 ? 'Kekurangan Uang:' : 'Kembalian Pelanggan',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 12,
                                color: cashShortage > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                            Text(
                              'Rp ${_formatNumber(cashShortage > 0 ? cashShortage : cashChange)}',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: cashShortage > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (requiresOpenShift) ...[
                        _buildShiftWarningBanner(sheetContext, effectiveBranchId),
                        const SizedBox(height: 12),
                      ],

                      // Button: PROSES PEMBAYARAN
                      ElevatedButton(
                        key: const Key('cash_sheet_process_button'),
                        onPressed: _isProcessing || cashShortage > 0 || requiresOpenShift
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _executePaymentProcess(amountDue);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18181B),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF18181B).withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'PROSES PEMBAYARAN',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  },
);
  }

  // =========================================================================
  // BOTTOM SHEET 3: QRIS STATIS & DINAMIS
  // =========================================================================
  void _showQrisSheet(BuildContext context, PaymentContext ctx, double amountDue) {
    final isDynamic = _isDynamicQrisEnabled &&
        _qrisRawPayload != null &&
        QrisService.isValidQrisPayload(_qrisRawPayload);
    final String? dynamicPayload = isDynamic
        ? QrisService.generateDynamicQris(_qrisRawPayload!, amountDue.round())
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final bizState = ref.watch(businessProvider);
            final effectiveBranchId = ctx.branchId ?? bizState.activeBranchId;
            final currentShiftByBranchAsync = ref.watch(currentShiftByBranchProvider(effectiveBranchId));
            final currentShiftGeneralAsync = ref.watch(currentShiftProvider);
            final currentShiftData = currentShiftByBranchAsync.value ?? currentShiftGeneralAsync.value;
            final requiresOpenShift = _requiresOpenShift(currentShiftData);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 4.5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Title & Subtitle
                  Center(
                    child: SvgPicture.asset(
                      'assets/logos/QRIS Logo - Black - zonalogo.com.svg',
                      height: 24,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      isDynamic ? 'QRIS DINAMIS' : 'QRIS STATIS',
                      key: const Key('qris_modal_title'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      isDynamic
                          ? 'Pindai untuk membayar. Nominal otomatis terisi dan terkunci di aplikasi pelanggan.'
                          : 'Pastikan jumlah yang Anda ketik sesuai\ndengan total pada struk/layar kasir.',
                      key: const Key('qris_modal_subtitle'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF6C6B6B), height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Big Centered QR Code
                  Center(
                    child: isDynamic && dynamicPayload != null
                        ? Container(
                            key: const Key('dynamic_qris_qr_container'),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: QrImageView(
                              key: const Key('dynamic_qris_qr_image'),
                              data: dynamicPayload,
                              version: QrVersions.auto,
                              size: 200,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          )
                        : ((_selectedQrisImageUrl != null && _selectedQrisImageUrl!.trim().isNotEmpty)
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _selectedQrisImageUrl!,
                                  width: 220,
                                  height: 220,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Container(
                                      width: 220,
                                      height: 220,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                          strokeWidth: 2,
                                          color: const Color(0xFF18181B),
                                        ),
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, _, _) => _buildQrCodePattern(),
                                ),
                              )
                            : _buildQrCodePattern()),
                  ),
                  const SizedBox(height: 16),

                  // Amount: Rp 50.000
                  Center(
                    child: Text(
                      'Rp ${_formatNumber(amountDue)}',
                      key: const Key('qris_modal_amount_text'),
                      style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: Colors.black, letterSpacing: -0.5),
                    ),
                  ),
                  if (ctx.isDownPayment) ...[
                    const SizedBox(height: 4),
                    Center(
                      child: Text(
                        'DP dari Total Sewa ${CurrencyFormatter.format(ctx.effectiveContractTotal)} • Sisa ${CurrencyFormatter.format(ctx.remainingAfterCurrentPayment)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  _buildNonCashReferenceSection(),
                  const SizedBox(height: 16),

                  if (requiresOpenShift) ...[
                    _buildShiftWarningBanner(sheetContext, effectiveBranchId),
                    const SizedBox(height: 12),
                  ],

                  // Button: PROSES PEMBAYARAN
                  ElevatedButton(
                    key: const Key('qris_sheet_process_button'),
                    onPressed: _isProcessing || requiresOpenShift
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _executePaymentProcess(amountDue);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF18181B).withValues(alpha: 0.4),
                      disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'PROSES PEMBAYARAN',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  },
);
  }

  Widget _buildQrCodePattern() {
    return Container(
      width: 220,
      height: 220,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Center(
        child: Icon(Icons.qr_code_2_rounded, size: 190, color: Colors.black),
      ),
    );
  }

  // =========================================================================
  // BOTTOM SHEET 4: PEMBAYARAN LAINYA (MATCHING IMAGE 5)
  // =========================================================================
  void _showEwalletSheet(
    BuildContext context,
    PaymentContext ctx,
    double amountDue,
    List<Map<String, dynamic>> paymentMethods, {
    required bool isEwalletMasterEnabled,
    required bool isBankTransferEnabled,
    required bool isShopeePayEnabled,
    required bool isDanaEnabled,
    required bool isLinkAjaEnabled,
    required bool isOvoEnabled,
    required bool isGopayEnabled,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, _) {
            final bizState = ref.watch(businessProvider);
            final effectiveBranchId = ctx.branchId ?? bizState.activeBranchId;
            final currentShiftByBranchAsync = ref.watch(currentShiftByBranchProvider(effectiveBranchId));
            final currentShiftGeneralAsync = ref.watch(currentShiftProvider);
            final currentShiftData = currentShiftByBranchAsync.value ?? currentShiftGeneralAsync.value;
            final requiresOpenShift = _requiresOpenShift(currentShiftData);

            return StatefulBuilder(
              builder: (context, setSheetState) {
            final activeEwalletTiles = <Widget>[
              if (isShopeePayEnabled) _buildEwalletTile('ShopeePay', _buildShopeeBadge(), setSheetState, paymentMethods),
              if (isDanaEnabled) _buildEwalletTile('DANA', _buildDanaBadge(), setSheetState, paymentMethods),
              if (isGopayEnabled) _buildEwalletTile('GoPay', _buildGopayBadge(), setSheetState, paymentMethods),
              if (isOvoEnabled) _buildEwalletTile('OVO', _buildOvoBadge(), setSheetState, paymentMethods),
              if (isLinkAjaEnabled) _buildEwalletTile('LinkAja!', _buildLinkAjaBadge(), setSheetState, paymentMethods),
            ];

            final activeBankTiles = <Widget>[
              if (isBankTransferEnabled) ...[
                _buildEwalletTile('BCA', _buildBankBadge('BCA'), setSheetState, paymentMethods),
                _buildEwalletTile('Mandiri', _buildBankBadge('Mandiri'), setSheetState, paymentMethods),
                _buildEwalletTile('BRI', _buildBankBadge('BRI'), setSheetState, paymentMethods),
                _buildEwalletTile('BNI', _buildBankBadge('BNI'), setSheetState, paymentMethods),
              ],
            ];

            final availableOptionIds = <String>[
              if (isShopeePayEnabled) 'ShopeePay',
              if (isDanaEnabled) 'DANA',
              if (isGopayEnabled) 'GoPay',
              if (isOvoEnabled) 'OVO',
              if (isLinkAjaEnabled) 'LinkAja!',
              if (isBankTransferEnabled) ...['BCA', 'Mandiri', 'BRI', 'BNI'],
            ];

            if (!availableOptionIds.contains(_selectedEwallet) && availableOptionIds.isNotEmpty) {
              _selectedEwallet = availableOptionIds.first;
              _applySelectedPaymentOption(_selectedEwallet, paymentMethods);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(sheetContext).viewInsets.bottom + 20),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag Handle
                      Center(
                        child: Container(
                          width: 44,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Title: PEMBAYARAN LAINNYA
                      const Center(
                        child: Text(
                          'PEMBAYARAN LAINNYA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Dompet Digital (E-Wallet) Box
                      if (isEwalletMasterEnabled && activeEwalletTiles.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF71717A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Dompet Digital',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              _buildDynamicTileGrid(activeEwalletTiles, columns: 3),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Bank Transfer Card Box
                      if (isBankTransferEnabled && activeBankTiles.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF71717A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Transfer Bank',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              _buildDynamicTileGrid(activeBankTiles, columns: 2),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],

                      if ((!isEwalletMasterEnabled || activeEwalletTiles.isEmpty) && (!isBankTransferEnabled || activeBankTiles.isEmpty)) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFEF4444)),
                          ),
                          child: const Center(
                            child: Text(
                              'Tidak ada metode pembayaran lainnya yang aktif.',
                              style: TextStyle(color: Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      if (availableOptionIds.isNotEmpty) ...[
                        _buildNonCashReferenceSection(),
                        const SizedBox(height: 16),
                      ],

                      if (requiresOpenShift) ...[
                        _buildShiftWarningBanner(sheetContext, effectiveBranchId),
                        const SizedBox(height: 12),
                      ],

                      // Button: PROSES PEMBAYARAN
                      ElevatedButton(
                        key: const Key('ewallet_sheet_process_button'),
                        onPressed: (_isProcessing || availableOptionIds.isEmpty || requiresOpenShift)
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _executePaymentProcess(amountDue);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18181B),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFF18181B).withValues(alpha: 0.4),
                          disabledForegroundColor: Colors.white.withValues(alpha: 0.7),
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'PROSES PEMBAYARAN',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  },
);
  }

  Widget _buildDynamicTileGrid(List<Widget> tiles, {int columns = 3}) {
    final rows = <Widget>[];
    for (int i = 0; i < tiles.length; i += columns) {
      final end = (i + columns < tiles.length) ? i + columns : tiles.length;
      final rowItems = tiles.sublist(i, end);
      rows.add(
        Row(
          children: [
            for (int j = 0; j < rowItems.length; j++) ...[
              if (j > 0) const SizedBox(width: 8),
              Expanded(child: rowItems[j]),
            ],
            for (int k = rowItems.length; k < columns; k++) ...[
              const SizedBox(width: 8),
              const Expanded(child: SizedBox()),
            ],
          ],
        ),
      );
      if (end < tiles.length) {
        rows.add(const SizedBox(height: 8));
      }
    }
    return Column(children: rows);
  }

  String _mapProviderToCode(String id) {
    final cleanId = id.replaceAll('!', '').trim().toUpperCase();
    switch (cleanId) {
      case 'SHOPEEPAY': return 'SHOPEEPAY';
      case 'DANA': return 'DANA';
      case 'GOPAY': return 'GOPAY';
      case 'OVO': return 'OVO';
      case 'LINKAJA': return 'LINKAJA';
      case 'BCA': return 'BCA';
      case 'MANDIRI': return 'MANDIRI';
      case 'BRI': return 'BRI';
      case 'BNI': return 'BNI';
      default: return 'TRANSFER';
    }
  }

  void _applySelectedPaymentOption(
    String optionId,
    List<Map<String, dynamic>> paymentMethods,
  ) {
    final targetCode = _mapProviderToCode(optionId);
    final matched = paymentMethods.where((m) {
      final code = (m['code'] ?? '').toString().toUpperCase();
      final name = (m['name'] ?? '').toString().toUpperCase();
      return code == targetCode || name.contains(targetCode);
    }).firstOrNull;

    if (matched != null) {
      _selectedMethodId = matched['id'] as int?;
      _selectedMethodCode = (matched['code'] ?? targetCode).toString().toUpperCase();
      _selectedMethodName = matched['name'] ?? optionId;
    } else {
      _selectedMethodCode = targetCode;
      _selectedMethodName = optionId;
    }
  }

  Widget _buildEwalletTile(
    String id,
    Widget badge,
    void Function(void Function()) setSheetState,
    List<Map<String, dynamic>> paymentMethods,
  ) {
    final isSelected = _selectedEwallet == id;
    return InkWell(
      key: ValueKey('tile_$id'),
      onTap: () {
        setSheetState(() {
          _selectedEwallet = id;
          _applySelectedPaymentOption(id, paymentMethods);
        });
        setState(() {
          _selectedEwallet = id;
          _applySelectedPaymentOption(id, paymentMethods);
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFF1F5F9) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.black : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Center(child: badge),
      ),
    );
  }

  Widget _buildBankBadge(String name) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.account_balance_rounded, size: 15, color: Color(0xFF1E293B)),
        const SizedBox(width: 6),
        Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            fontSize: 12,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildShopeeBadge() {
    return SvgPicture.asset(
      'assets/logos/ShopeePay Logo - Colored - zonalogo.com.svg',
      height: 20,
      fit: BoxFit.contain,
    );
  }

  Widget _buildDanaBadge() {
    return SvgPicture.asset(
      'assets/logos/Dana Logo - Colored - zonalogo.com.svg',
      height: 18,
      fit: BoxFit.contain,
    );
  }

  Widget _buildGopayBadge() {
    return SvgPicture.asset(
      'assets/logos/GoPay Logo - Colored - zonalogo.com.svg',
      height: 18,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLainyaBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SvgPicture.asset(
          'assets/logos/option-svgrepo-com.svg',
          height: 14,
          width: 14,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 4),
        const Text(
          'Lainnya',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF374151),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildOvoBadge() {
    return SvgPicture.asset(
      'assets/logos/OVO Logo - Colored - zonalogo.com.svg',
      height: 18,
      fit: BoxFit.contain,
    );
  }

  Widget _buildLinkAjaBadge() {
    return SvgPicture.asset(
      'assets/logos/LinkAja Logo - Colored - zonalogo.com.svg',
      height: 18,
      fit: BoxFit.contain,
    );
  }

  // =========================================================================
  // EXECUTE PAYMENT TRANSACTION
  // =========================================================================
  Future<void> _executePaymentProcess(double amountDue) async {
    final bizState = ref.read(businessProvider);
    final effectiveBranchId = widget.paymentContext.branchId ?? bizState.activeBranchId;
    final settingsAsync = ref.read(paymentSettingsProvider(effectiveBranchId));
    final config = (settingsAsync.value?['config'] as Map<String, dynamic>?) ??
                   (settingsAsync.value?['data']?['config'] as Map<String, dynamic>?);

    if (config != null) {
      if (_selectedMethodCode == 'CASH' && config['cash_enabled'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metode pembayaran Tunai dinonaktifkan oleh pengaturan toko.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      if (_selectedMethodCode == 'QRIS' && config['qris_statis_enabled'] == false) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Metode pembayaran QRIS dinonaktifkan oleh pengaturan toko.'),
            backgroundColor: AppColors.danger,
          ),
        );
        return;
      }
      final cleanMethod = _selectedMethodCode.toUpperCase();
      if (['SHOPEEPAY', 'DANA', 'GOPAY', 'OVO', 'LINKAJA'].contains(cleanMethod)) {
        if (config['ewallet_enabled'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metode pembayaran Dompet Digital dinonaktifkan oleh pengaturan toko.'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
        final providers = (config['ewallet_providers'] as Map<String, dynamic>?) ?? {};
        final providerKey = cleanMethod.toLowerCase();
        if (providers.containsKey(providerKey) && providers[providerKey] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Metode pembayaran $_selectedMethodName sedang dinonaktifkan.'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      } else if (['BCA', 'MANDIRI', 'BRI', 'BNI', 'TRANSFER'].contains(cleanMethod)) {
        if (config['bank_transfer_enabled'] == false) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Metode pembayaran Transfer Bank dinonaktifkan oleh pengaturan toko.'),
              backgroundColor: AppColors.danger,
            ),
          );
          return;
        }
      }
    }

    setState(() => _isProcessing = true);

    try {
      final isCash = _selectedMethodCode == 'CASH';
      final cashReceived = isCash
          ? CurrencyFormatter.parse(_cashReceivedController.text)
          : amountDue;

      final trimmedExternalRef = _externalRefController.text.trim();
      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.executePayment(
        context: widget.paymentContext,
        paymentMethodId: _selectedMethodId ?? 1,
        paymentMethodCode: _selectedMethodCode,
        paymentMethodName: _selectedMethodName,
        amountToPay: amountDue,
        cashReceived: cashReceived,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        idempotencyKey: _attemptIdempotencyKey,
        externalReference: !isCash && trimmedExternalRef.isNotEmpty ? trimmedExternalRef : null,
      );

      widget.onPaymentSuccess?.call();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _completedResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      final readableError = _extractReadablePaymentError(e);
      final errorStr = readableError.toLowerCase();
      if (errorStr.contains('shift kasir belum dibuka') ||
          errorStr.contains('shift belum dibuka') ||
          errorStr.contains('cash_shift') ||
          errorStr.contains('shift_not_active')) {
        final bizState = ref.read(businessProvider);
        final effectiveBranchId = widget.paymentContext.branchId ?? bizState.activeBranchId;
        _showQuickOpenShiftModal(context, effectiveBranchId);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pembayaran: $readableError'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted && _completedResult == null) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _extractReadablePaymentError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map) {
        final errors = data['errors'];
        if (errors is Map && errors.isNotEmpty) {
          final firstVal = errors.values.first;
          if (firstVal is List && firstVal.isNotEmpty) {
            return firstVal.first.toString();
          }
          return firstVal.toString();
        }
        final msg = data['message']?.toString();
        if (msg != null && msg.trim().isNotEmpty) return msg;
      }
    }
    return error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
  }

  String _normalizePaymentMethodDisplayName(String? name, String? code) {
    final raw = (name ?? code ?? '').trim();
    if (raw.isEmpty) return 'Tunai';
    if (raw.contains('QRIS Dinamis / Statis') || raw.toUpperCase() == 'QRIS') {
      return 'QRIS Dinamis';
    }
    return raw;
  }

  Widget _buildSuccessView(BuildContext context, PaymentResult result) {
    final methodCode = (result.paymentMethodCode ?? _selectedMethodCode).toUpperCase();
    final rawMethodName = result.paymentMethodName ?? _selectedMethodName;
    final displayMethodName = _normalizePaymentMethodDisplayName(rawMethodName, methodCode);
    final isCash = methodCode == 'CASH' || rawMethodName.toLowerCase().contains('tunai');
    final ctx = widget.paymentContext;
    final isDp = ctx.isDownPayment || result.status == PaymentStatus.partial;

    return _PaymentSuccessView(
      result: result,
      displayMethodName: displayMethodName,
      isCash: isCash,
      isDownPayment: isDp,
      isHandoverSettlement: ctx.isHandoverSettlement,
      contractTotalAmount: ctx.effectiveContractTotal,
      remainingBalance: ctx.remainingAfterCurrentPayment,
      onPrintReceipt: () => _printPaymentReceipt(result),
      onDone: () => Navigator.pop(context, result),
    );
  }

  Widget _buildNonCashReferenceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Pastikan dana telah masuk ke mutasi/notifikasi merchant sebelum konfirmasi.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('external_reference_input'),
          controller: _externalRefController,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'No. Referensi / Approval (Opsional)',
            hintText: 'Contoh: APR-99812 / Kode mutasi bank',
            isDense: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _printPaymentReceipt(PaymentResult result) {
    try {
      final printerService = ThermalPrinterService();
      final printerSettings = ref.read(printerProvider).settings;
      final authState = ref.read(authProvider);
      final bizState = ref.read(businessProvider);
      final ctx = widget.paymentContext;

      final resolvedBranchName = (ctx.branchName != null && ctx.branchName!.trim().isNotEmpty)
          ? ctx.branchName!.trim()
          : ((bizState.activeBranchName != null && bizState.activeBranchName!.trim().isNotEmpty)
              ? bizState.activeBranchName!.trim()
              : 'Cabang');
      final rawCashierName = authState.user?['name']?.toString().trim();
      final resolvedCashierName =
          (rawCashierName != null && rawCashierName.isNotEmpty) ? rawCashierName : 'Kasir';

      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: resolvedBranchName,
        receiptNumber: result.receiptNumber,
        bookingCode: ctx.bookingCode,
        customerName: ctx.customerName,
        customerPhone: ctx.customerPhone,
        cashierName: resolvedCashierName,
        unitName: ctx.deviceName,
        items: ctx.items.isNotEmpty
            ? ctx.items
                .map((i) => {
                      'name': i.isAddon ? '${i.name} (Add-on)' : i.name,
                      'asset_code': i.assetCode,
                      'price': i.price,
                      'duration': i.durationText,
                    })
                .toList()
            : null,
        subtotal: (ctx.primarySubtotal != null || ctx.addonSubtotal != null)
            ? ((ctx.primarySubtotal ?? 0) + (ctx.addonSubtotal ?? 0))
            : null,
        discount: ctx.discountAmount,
        totalAmount: result.amountPaid,
        paymentMethod: result.paymentMethodName ?? _selectedMethodName,
        cashReceived: result.cashReceived,
        cashChange: result.cashChange,
        isDownPayment: ctx.isDownPayment,
        remainingBalance: ctx.remainingAfterCurrentPayment,
        transactedAt: DateTime.now().toString().substring(0, 16),
      );

      final escposBytes = printerService.buildPosPaymentSlipBytes(model, printerSettings);

      showDialog(
        context: context,
        builder: (dCtx) => ThermalReceiptPreviewDialog(
          title: 'Struk Pembayaran POS',
          branchName: ctx.branchName ?? 'RentCore',
          escposBytes: escposBytes,
          content: Column(
            children: [
              Text(ctx.transactionTypeTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              Text('No: ${result.receiptNumber ?? "-"}', style: const TextStyle(fontSize: 11)),
              Text('Pelanggan: ${ctx.customerName}', style: const TextStyle(fontSize: 11)),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total Bayar:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  Text(CurrencyFormatter.format(result.amountPaid), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mencetak struk: $e'), backgroundColor: AppColors.danger),
      );
    }
  }
}


class _PaymentSuccessView extends StatefulWidget {
  final PaymentResult result;
  final String displayMethodName;
  final bool isCash;
  final bool isDownPayment;
  final bool isHandoverSettlement;
  final double contractTotalAmount;
  final double remainingBalance;
  final VoidCallback onPrintReceipt;
  final VoidCallback onDone;

  const _PaymentSuccessView({
    required this.result,
    required this.displayMethodName,
    required this.isCash,
    this.isDownPayment = false,
    this.isHandoverSettlement = false,
    this.contractTotalAmount = 0.0,
    this.remainingBalance = 0.0,
    required this.onPrintReceipt,
    required this.onDone,
  });

  @override
  State<_PaymentSuccessView> createState() => _PaymentSuccessViewState();
}

typedef _StaggerTrack = ({
  Animation<double> fade,
  Animation<Offset> slide,
});

class _PaymentSuccessViewState extends State<_PaymentSuccessView>
    with SingleTickerProviderStateMixin {
  static const int _totalDurationMs = 700;

  late final AnimationController _entranceController;
  late final _StaggerTrack _headerTrack;
  late final _StaggerTrack _cardTrack;
  late final _StaggerTrack _actionsTrack;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _totalDurationMs),
    );

    _headerTrack = _createStaggeredTrack(300, 560);
    _cardTrack = _createStaggeredTrack(370, 630);
    _actionsTrack = _createStaggeredTrack(440, 700);

    _entranceController.forward();
  }

  _StaggerTrack _createStaggeredTrack(int startMs, int endMs) {
    final curve = CurvedAnimation(
      parent: _entranceController,
      curve: Interval(
        startMs / _totalDurationMs,
        endMs / _totalDurationMs,
        curve: Curves.easeOutCubic,
      ),
    );
    return (
      fade: Tween<double>(begin: 0.0, end: 1.0).animate(curve),
      slide: Tween<Offset>(
        begin: const Offset(0, 0.06),
        end: Offset.zero,
      ).animate(curve),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Widget _buildStaggeredItem({
    required _StaggerTrack track,
    required Widget child,
  }) {
    return FadeTransition(
      opacity: track.fade,
      child: SlideTransition(position: track.slide, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: AnimatedSuccessCheckmark(size: 88)),
          const SizedBox(height: 16),
          _buildStaggeredItem(
            track: _headerTrack,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.isHandoverSettlement
                      ? 'Pembayaran Lunas & Unit Diserahkan'
                      : 'Pembayaran Berhasil Dicatat!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppColors.obsidian,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.isHandoverSettlement
                      ? 'Unit telah diserahkan dan kini aktif di daftar Sewa Aktif.'
                      : (widget.isDownPayment
                          ? 'DP booking terjadwal berhasil dicatat.'
                          : 'Pembayaran sewa unit berhasil diselesaikan.'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildStaggeredItem(
            track: _cardTrack,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.receiptNumber != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'No. Struk',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            result.receiptNumber!,
                            textAlign: TextAlign.end,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                  ],
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Metode Pembayaran',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          widget.displayMethodName,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Dibayar',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(result.amountPaid),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.obsidian,
                        ),
                      ),
                    ],
                  ),
                  if (widget.isDownPayment) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total Sewa',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(widget.contractTotalAmount),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Sisa Tagihan (Saat Ambil Unit)',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(widget.remainingBalance),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (widget.isCash) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Tunai Diterima',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(result.cashReceived),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kembalian',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.format(result.cashChange),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (!widget.isCash || widget.isDownPayment || widget.isHandoverSettlement) ...[
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          widget.isHandoverSettlement ? 'Status Sewa' : 'Status',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: (widget.isDownPayment
                                    ? AppColors.warning
                                    : AppColors.success)
                                .withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            widget.isDownPayment
                                ? 'DP DIBAYAR'
                                : (widget.isHandoverSettlement
                                    ? 'AKTIF DISEWA'
                                    : 'LUNAS OTOMATIS'),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: widget.isDownPayment
                                  ? AppColors.warning
                                  : AppColors.success,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildStaggeredItem(
            track: _actionsTrack,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  key: const Key('print_payment_receipt_button'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.print_rounded, size: 18),
                  label: const Text(
                    'Cetak Struk Transaksi (ESC/POS)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: widget.onPrintReceipt,
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  key: const Key('payment_success_done_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF18181B),
                    backgroundColor: Colors.white,
                    side: const BorderSide(
                      color: Color(0xFFCBD5E1),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  onPressed: widget.onDone,
                  child: const Text(
                    'Selesai',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

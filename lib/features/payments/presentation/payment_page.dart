import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/cash_suggestion_helper.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../cashier/presentation/widgets/cash_drawer_shift_modal.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../data/payment_repository.dart';
import '../models/payment_context.dart';

class PaymentPage extends ConsumerStatefulWidget {
  final PaymentContext paymentContext;
  final bool isModal;
  final VoidCallback? onPaymentSuccess;

  const PaymentPage({
    super.key,
    required this.paymentContext,
    this.isModal = false,
    this.onPaymentSuccess,
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

  int? _selectedMethodId;
  String _selectedMethodCode = 'CASH';
  String _selectedMethodName = 'Tunai';
  String? _selectedQrisImageUrl;
  String _selectedEwallet = 'ShopeePay';
  bool _nonCashConfirmed = true;
  bool _isProcessing = false;
  bool _methodInitialized = false;
  PaymentResult? _completedResult;

  @override
  void initState() {
    super.initState();
    _cashReceivedController.addListener(() {
      if (mounted) setState(() {});
    });
    _cashReceivedController.text = widget.paymentContext.remainingDue.toInt().toString();
  }

  @override
  void dispose() {
    _cashReceivedController.dispose();
    _notesController.dispose();
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

  @override
  Widget build(BuildContext context) {
    final ctx = widget.paymentContext;
    final amountDue = ctx.remainingDue;
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    paymentMethodsAsync.whenData((methods) {
      if (!_methodInitialized && methods.isNotEmpty) {
        _methodInitialized = true;
        final cashMethod = methods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH').firstOrNull ?? methods.first;
        _selectedMethodId = cashMethod['id'] as int?;
        _selectedMethodCode = (cashMethod['code'] ?? 'CASH').toString().toUpperCase();
        _selectedMethodName = cashMethod['name'] ?? 'Tunai';
      }
    });

    final paymentMethods = paymentMethodsAsync.value ?? [
      {'id': 1, 'code': 'CASH', 'name': 'Tunai'},
      {'id': 2, 'code': 'QRIS', 'name': 'QRIS'},
      {'id': 3, 'code': 'TRANSFER', 'name': 'Transfer Bank'},
    ];

    if (_completedResult != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.black),
            onPressed: () => Navigator.pop(context, _completedResult),
          ),
          title: const Text('Pembayaran Sukses', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
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
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            tooltip: 'Batalkan Pembayaran',
            onPressed: () {
              Navigator.pop(
                context,
                _completedResult ?? const PaymentResult(status: PaymentStatus.cancelled),
              );
            },
          ),
          title: Text(
            ctx.pageHeaderTitle,
            style: const TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF71717A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Rp${_formatNumber(amountDue)}',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          color: Colors.black,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showDetailSewaSheet(context, ctx, amountDue),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          child: Text(
                            ctx.detailLinkText,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0EA5E9),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom 3 Action Buttons: QRIS, Tunai, Lainya
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                child: Row(
                  children: [
                    // 1. QRIS Card
                    Expanded(
                      child: _buildBottomMethodCard(
                        title: 'QRIS',
                        customIcon: _buildQrisLogoWidget(),
                        onTap: () {
                          final qrisMethod = paymentMethods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'QRIS').firstOrNull;
                          _selectedMethodId = qrisMethod?['id'] as int? ?? 2;
                          _selectedMethodCode = 'QRIS';
                          _selectedMethodName = qrisMethod?['name'] ?? 'QRIS';
                          _selectedQrisImageUrl = qrisMethod?['qris_image_url'] as String?;
                          _showQrisSheet(context, ctx, amountDue);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 2. Tunai Card
                    Expanded(
                      child: _buildBottomMethodCard(
                        title: 'Tunai',
                        customIcon: _buildCashBillIconWidget(),
                        onTap: () {
                          final cashMethod = paymentMethods.where((m) => (m['code'] ?? '').toString().toUpperCase() == 'CASH').firstOrNull;
                          _selectedMethodId = cashMethod?['id'] as int? ?? 1;
                          _selectedMethodCode = 'CASH';
                          _selectedMethodName = cashMethod?['name'] ?? 'Tunai';
                          _cashReceivedController.text = amountDue.toInt().toString();
                          _showCashSheet(context, ctx, amountDue);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),

                    // 3. Lainya Card
                    Expanded(
                      child: _buildBottomMethodCard(
                        title: 'Lainya',
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
                          _showEwalletSheet(context, ctx, amountDue, paymentMethods);
                        },
                      ),
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
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black, width: 1.5),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            customIcon,
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black),
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
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Subtotal', style: TextStyle(fontSize: 12, color: Colors.black)),
                        Text('Rp ${_formatNumber(subtotal)}', style: const TextStyle(fontSize: 12, color: Colors.black)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),
                  const Divider(height: 1, thickness: 1, color: Color(0xFF71717A)),
                  const SizedBox(height: 12),

                  // Total Row (Bold Green)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black)),
                      Text(
                        'Rp ${_formatNumber(amountDue)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF22C55E)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Button: KONFIRMASI PEMBAYARAN
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showCashSheet(context, ctx, amountDue);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text(
                      'KONFIRMASI PEMBAYARAN',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
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
                            const Text('Tagihan Sewa', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                            Text(
                              'Rp  ${_formatNumber(amountDue)}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Box 2: Jumlah Uang Diterima Input (Aligned with Customer Form InputDecoration)
                      TextFormField(
                        controller: _cashReceivedController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black),
                        decoration: InputDecoration(
                          labelText: 'Jumlah uang diterima *',
                          labelStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border, width: 1),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.border, width: 1),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: AppColors.obsidian, width: 1.5),
                          ),
                          prefixIcon: const SizedBox(
                            width: 44,
                            child: Center(
                              child: Text(
                                'Rp',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.check_circle_outline_rounded, color: AppColors.obsidian),
                            tooltip: 'Uang Pas',
                            onPressed: () {
                              _cashReceivedController.text = amountDue.toInt().toString();
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
                                  fontWeight: FontWeight.bold,
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
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: cashShortage > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                            Text(
                              'Rp ${_formatNumber(cashShortage > 0 ? cashShortage : cashChange)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: cashShortage > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Button: PROSES PEMBAYARAN
                      ElevatedButton(
                        onPressed: _isProcessing || cashShortage > 0
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
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
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
  // BOTTOM SHEET 3: QRIS STATIS (MATCHING IMAGE 4)
  // =========================================================================
  void _showQrisSheet(BuildContext context, PaymentContext ctx, double amountDue) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                  const Center(
                    child: Text(
                      'QRIS STATIS',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Center(
                    child: Text(
                      'Pastikan jumlah yang Anda ketik sesuai\ndengan total pada struk/layar kasir.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: Color(0xFF71717A), height: 1.3),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Big Centered QR Code
                  Center(
                    child: _selectedQrisImageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              _selectedQrisImageUrl!,
                              width: 220,
                              height: 220,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => _buildQrCodePattern(),
                            ),
                          )
                        : _buildQrCodePattern(),
                  ),
                  const SizedBox(height: 16),

                  // Amount: Rp 50.000
                  Center(
                    child: Text(
                      'Rp ${_formatNumber(amountDue)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.black, letterSpacing: -0.5),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Button: PROSES PEMBAYARAN
                  ElevatedButton(
                    onPressed: _isProcessing
                        ? null
                        : () async {
                            Navigator.pop(sheetContext);
                            await _executePaymentProcess(amountDue);
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF18181B),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isProcessing
                        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'PROSES PEMBAYARAN',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
                          ),
                  ),
                ],
              ),
            ),
          ),
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
    List<Map<String, dynamic>> paymentMethods,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
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

                      // Title: PEMBAYARAN LAINYA
                      const Center(
                        child: Text(
                          'PEMBAYARAN LAINYA',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black, letterSpacing: 0.5),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // E-Wallet Card Box
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
                              'E-Wallet',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black),
                            ),
                            const SizedBox(height: 12),

                            // 2x3 Grid: ShopeePay, DANA, GoPay, Lainya, OVO, LinkAja!
                            Row(
                              children: [
                                Expanded(child: _buildEwalletTile('ShopeePay', _buildShopeeBadge(), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('DANA', _buildDanaBadge(), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('GoPay', _buildGopayBadge(), setSheetState, paymentMethods)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildEwalletTile('Lainya', _buildLainyaBadge(), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('OVO', _buildOvoBadge(), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('LinkAja!', _buildLinkAjaBadge(), setSheetState, paymentMethods)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Bank Transfer Card Box (Task 2)
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
                            Row(
                              children: [
                                Expanded(child: _buildEwalletTile('BCA', _buildBankBadge('BCA'), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('Mandiri', _buildBankBadge('Mandiri'), setSheetState, paymentMethods)),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(child: _buildEwalletTile('BRI', _buildBankBadge('BRI'), setSheetState, paymentMethods)),
                                const SizedBox(width: 8),
                                Expanded(child: _buildEwalletTile('BNI', _buildBankBadge('BNI'), setSheetState, paymentMethods)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Button: PROSES PEMBAYARAN
                      ElevatedButton(
                        onPressed: _isProcessing
                            ? null
                            : () async {
                                Navigator.pop(sheetContext);
                                await _executePaymentProcess(amountDue);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF18181B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: _isProcessing
                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text(
                                'PROSES PEMBAYARAN',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 0.5),
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
          'Lainya',
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
    setState(() => _isProcessing = true);

    try {
      final isCash = _selectedMethodCode == 'CASH';
      final cashReceived = isCash
          ? CurrencyFormatter.parse(_cashReceivedController.text)
          : amountDue;

      final repo = ref.read(paymentRepositoryProvider);
      final result = await repo.executePayment(
        context: widget.paymentContext,
        paymentMethodId: _selectedMethodId ?? 1,
        paymentMethodCode: _selectedMethodCode,
        paymentMethodName: _selectedMethodName,
        amountToPay: amountDue,
        cashReceived: cashReceived,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      widget.onPaymentSuccess?.call();

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _completedResult = result;
      });
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('shift kasir belum dibuka') || errorStr.contains('cash_shift')) {
        _showOpenShiftPromptDialog(context);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memproses pembayaran: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted && _completedResult == null) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showOpenShiftPromptDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_clock_rounded, color: AppColors.warning),
            SizedBox(width: 8),
            Text('Shift Kasir Belum Dibuka'),
          ],
        ),
        content: const Text(
          'Transaksi kasir memerlukan shift kasir yang aktif.\n\n'
          'Silakan buka shift kasir terlebih dahulu untuk mencatat modal awal dan mengaktifkan laci kasir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.meeting_room_rounded, size: 18),
            label: const Text('Buka Shift Sekarang'),
            onPressed: () {
              Navigator.pop(ctx);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => CashDrawerShiftModal(
                  branchId: widget.paymentContext.branchId,
                  onShiftUpdated: () {
                    ref.invalidate(currentShiftProvider);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Shift kasir berhasil dibuka! Silakan lanjutkan konfirmasi pembayaran.'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(BuildContext context, PaymentResult result) {
    final ctx = widget.paymentContext;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.successLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Pembayaran Berhasil Dicatat!',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.obsidian),
          ),
          const SizedBox(height: 6),
          Text(
            'Transaksi ${ctx.transactionTypeTitle} berhasil diselesaikan.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (result.receiptNumber != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('No. Struk', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(result.receiptNumber!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Divider(height: 16),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Metode Pembayaran', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(result.paymentMethodName ?? _selectedMethodName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Dibayar', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(CurrencyFormatter.format(result.amountPaid), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.obsidian)),
                  ],
                ),
                if (result.cashReceived > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Tunai Diterima', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      Text(CurrencyFormatter.format(result.cashReceived), style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Kembalian', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success)),
                      Text(CurrencyFormatter.format(result.cashChange), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.print_rounded, size: 18),
            label: const Text('Cetak Struk Transaksi (ESC/POS)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () => _printPaymentReceipt(result),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Selesai', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            onPressed: () => Navigator.pop(context, result),
          ),
        ],
      ),
    );
  }

  void _printPaymentReceipt(PaymentResult result) {
    try {
      final printerService = ThermalPrinterService();
      final printerSettings = ref.read(printerProvider).settings;
      final ctx = widget.paymentContext;

      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI POS',
        branchName: ctx.branchName ?? 'RentCore Central Hub',
        receiptNumber: result.receiptNumber,
        bookingCode: ctx.bookingCode,
        customerName: ctx.customerName,
        customerPhone: ctx.customerPhone,
        cashierName: 'Kasir RentCore',
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

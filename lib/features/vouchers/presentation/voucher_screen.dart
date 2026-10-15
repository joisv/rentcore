import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/voucher_provider.dart';
import 'voucher_detail_dialog.dart';
import 'voucher_form_dialog.dart';

class VoucherScreen extends ConsumerStatefulWidget {
  const VoucherScreen({super.key});

  @override
  ConsumerState<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends ConsumerState<VoucherScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showThermalSlipModal(BuildContext context, Map<String, dynamic> voucher) {
    final code = voucher['code'] ?? '';
    final percent = CurrencyFormatter.parse(voucher['discount_percentage']);
    final minSpend = CurrencyFormatter.parse(voucher['min_transaction_amount']);
    final validUntil = voucher['end_at'] != null ? DateFormatter.formatShort(voucher['end_at']) : '-';
    final branchName = voucher['affiliate']?['name'] ?? 'Semua Cabang RentCore';

    final printerService = ThermalPrinterService();
    final escposBytes = printerService.buildVoucherSlipBytes(
      shopName: 'RENTCORE GADGETS',
      branchName: branchName,
      voucherCode: code,
      discountPercentage: percent,
      minTransaction: minSpend,
      validUntil: validUntil,
    );

    showDialog(
      context: context,
      builder: (ctx) => ThermalReceiptPreviewDialog(
        title: 'Cetak Slip Voucher Fisik',
        branchName: branchName,
        escposBytes: escposBytes,
        qrData: code,
        content: Column(
          children: [
            const Text(
              'VOUCHER DISKON SPESIAL',
              style: TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w800, fontSize: 13),
            ),
            Text(
              '*** ${percent.toInt()}% OFF ***',
              style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w900, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'Kode Voucher  : $code',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w700),
            ),
            Text(
              'Min. Transaksi: ${CurrencyFormatter.format(minSpend)}',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
            Text(
              'Berlaku s/d   : $validUntil',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voucherState = ref.watch(voucherProvider);
    final authState = ref.watch(authProvider);
    final bizState = ref.watch(businessProvider);
    final orgState = ref.watch(organizationProvider);

    // Resolve user role in active business
    final activeBiz = bizState.businesses.where((b) => b['id'] == bizState.activeBusinessId).firstOrNull;
    final role = activeBiz?['role']?.toString() ?? authState.user?['role']?.toString();
    final isSuperAdmin = authState.user?['role'] == 'super_admin' || authState.user?['is_platform_admin'] == true;
    final isOwner = isSuperAdmin || role == 'owner';

    // Get accessible branches for branch selector
    final branches = orgState.branches.isNotEmpty
        ? orgState.branches
        : (activeBiz?['branches'] is List ? activeBiz!['branches'] as List : <dynamic>[]);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: _isSearchExpanded
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Cari kode promo atau nama voucher...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 14),
                ),
                onChanged: (val) {
                  ref.read(voucherProvider.notifier).setSearchQuery(val.trim());
                },
              )
            : const Text('Voucher & Barcode 2D'),
        actions: [
          IconButton(
            icon: Icon(_isSearchExpanded ? Icons.close_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                if (_isSearchExpanded) {
                  _searchController.clear();
                  ref.read(voucherProvider.notifier).setSearchQuery('');
                  _isSearchExpanded = false;
                } else {
                  _isSearchExpanded = true;
                }
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.read(voucherProvider.notifier).loadVouchers(),
          ),
        ],
      ),
      floatingActionButton: isOwner
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Buat Voucher', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () => VoucherFormDialog.show(
                context,
                branches: branches,
              ),
            )
          : null,
      body: Column(
        children: [
          // Owner Filter Chips
          if (isOwner)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surface,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Semua', 'all', voucherState.statusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip('Aktif', 'active', voucherState.statusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip('Nonaktif', 'inactive', voucherState.statusFilter),
                    const SizedBox(width: 8),
                    _buildFilterChip('Kedaluwarsa', 'expired', voucherState.statusFilter),
                  ],
                ),
              ),
            ),

          // Main List / State View
          Expanded(
            child: Builder(
              builder: (context) {
                if (voucherState.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (voucherState.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                          const SizedBox(height: 12),
                          Text(
                            'Gagal memuat voucher:\n${voucherState.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Coba Lagi'),
                            onPressed: () => ref.read(voucherProvider.notifier).loadVouchers(),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final vouchers = voucherState.vouchers;
                if (vouchers.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.confirmation_number_outlined, size: 54, color: AppColors.textMuted),
                        const SizedBox(height: 14),
                        const Text(
                          'Belum ada voucher promo.',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Voucher promo yang diterbitkan akan muncul di sini.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                        if (isOwner) ...[
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Terbitkan Voucher Pertama'),
                            onPressed: () => VoucherFormDialog.show(
                              context,
                              branches: branches,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 100),
                  itemCount: vouchers.length,
                  itemBuilder: (context, index) {
                    final v = vouchers[index];
                    final discountPercent = CurrencyFormatter.parse(v['discount_percentage']);
                    final minSpend = CurrencyFormatter.parse(v['min_transaction_amount']);
                    final maxCap = v['max_discount_cap'] != null ? CurrencyFormatter.parse(v['max_discount_cap']) : null;
                    final isActive = v['is_active'] == true;
                    final endAt = v['end_at'] != null ? DateTime.tryParse(v['end_at'].toString()) : null;
                    final isExpired = endAt != null && endAt.isBefore(DateTime.now());
                    final branchName = v['affiliate']?['name'];
                    final usageCount = v['usage_count'] ?? 0;
                    final totalQuota = v['usage_limit_total'];
                    final id = v['id'] is int ? v['id'] as int : int.parse(v['id'].toString());

                    return InkWell(
                      onTap: () => VoucherDetailDialog.show(
                        context,
                        voucher: v,
                        isOwner: isOwner,
                        branches: branches,
                        onPrintThermal: () => _showThermalSlipModal(context, v),
                      ),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !isActive
                                ? AppColors.borderSubtle
                                : isExpired
                                    ? AppColors.danger.withValues(alpha: 0.3)
                                    : AppColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top Row: Discount Pill, Branch Badge & Status Tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.obsidian,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${discountPercent.toInt()}% OFF',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: branchName != null
                                            ? AppColors.info.withValues(alpha: 0.1)
                                            : AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            branchName != null ? Icons.store_rounded : Icons.public_rounded,
                                            size: 12,
                                            color: branchName != null ? AppColors.info : AppColors.textSecondary,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            branchName ?? 'Semua Cabang',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: branchName != null ? AppColors.info : AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: !isActive
                                        ? AppColors.surfaceMuted
                                        : isExpired
                                            ? AppColors.danger.withValues(alpha: 0.1)
                                            : AppColors.success.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    !isActive
                                        ? 'Nonaktif'
                                        : isExpired
                                            ? 'Kedaluwarsa'
                                            : 'Aktif',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: !isActive
                                          ? AppColors.textMuted
                                          : isExpired
                                              ? AppColors.danger
                                              : AppColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Name & Description
                            Text(
                              v['name'] ?? 'Voucher Promo',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                            ),
                            if (v['description'] != null && v['description'].toString().isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                v['description'].toString(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Min Spend & Cap
                            Row(
                              children: [
                                const Icon(Icons.shopping_bag_outlined, size: 14, color: AppColors.textSecondary),
                                const SizedBox(width: 4),
                                Text(
                                  'Min: ${CurrencyFormatter.format(minSpend)}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                if (maxCap != null) ...[
                                  const SizedBox(width: 12),
                                  const Icon(Icons.vertical_align_top_rounded, size: 14, color: AppColors.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Plafon: ${CurrencyFormatter.format(maxCap)}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Validity & Usage
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Berlaku s/d ${DateFormatter.formatShort(endAt)}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                                ),
                                Text(
                                  totalQuota != null ? '$usageCount / $totalQuota terpakai' : '$usageCount kali dipakai',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                                ),
                              ],
                            ),

                            const SizedBox(height: 14),
                            const Divider(height: 1, color: AppColors.borderSubtle),
                            const SizedBox(height: 10),

                            // Bottom Action Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.qr_code_2_rounded, size: 16, color: AppColors.obsidian),
                                    const SizedBox(width: 6),
                                    Text(
                                      v['code'] ?? '',
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (isOwner) ...[
                                      Switch(
                                        value: isActive,
                                        activeTrackColor: AppColors.obsidian,
                                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                        onChanged: (val) async {
                                          try {
                                            await ref.read(voucherProvider.notifier).toggleStatus(id);
                                          } catch (e) {
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined, size: 18),
                                        tooltip: 'Edit Voucher',
                                        onPressed: () => VoucherFormDialog.show(
                                          context,
                                          voucher: v,
                                          branches: branches,
                                        ),
                                      ),
                                    ],
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size(120, 36),
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                      ),
                                      icon: const Icon(Icons.print_outlined, size: 15),
                                      label: const Text('Cetak Slip', style: TextStyle(fontSize: 11)),
                                      onPressed: () => _showThermalSlipModal(context, v),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String activeValue) {
    final isSelected = value == activeValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      onSelected: (_) {
        ref.read(voucherProvider.notifier).setStatusFilter(value);
      },
    );
  }
}

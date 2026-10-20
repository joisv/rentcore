import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../providers/cashier_provider.dart';
import 'pos_transaction_detail_sheet.dart';

class FinancialActivityLedgerScreen extends ConsumerStatefulWidget {
  const FinancialActivityLedgerScreen({super.key});

  @override
  ConsumerState<FinancialActivityLedgerScreen> createState() => _FinancialActivityLedgerScreenState();
}

class _FinancialActivityLedgerScreenState extends ConsumerState<FinancialActivityLedgerScreen> {
  final _searchController = TextEditingController();
  String _searchFilter = '';
  String _selectedType = 'all'; // all, inflow, expense, refund, void

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final closingAsync = ref.watch(closingSummaryProvider);
    final expensesAsync = ref.watch(cashierExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buku Aktivitas Keuangan (Ledger)', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Cari kode TX / Struk / Booking / Catatan...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchFilter = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onChanged: (val) => setState(() => _searchFilter = val.trim().toLowerCase()),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'Semua Aktivitas'),
                      _buildFilterChip('inflow', 'Pemasukan (In)'),
                      _buildFilterChip('expense', 'Beban Cabang (Out)'),
                      _buildFilterChip('refund', 'Refund Deposit (Out)'),
                      _buildFilterChip('void', 'Dibatalkan (Void)'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Ledger Activity List
          Expanded(
            child: closingAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Gagal memuat buku kas: $e', style: const TextStyle(color: AppColors.danger))),
              data: (closingData) {
                final recentTx = (closingData['recent_transactions'] as List?) ?? [];
                final expensesList = (expensesAsync.value?['expenses'] as List?) ?? [];

                // Combine transactions & expenses into a unified ledger stream
                final ledgerItems = <Map<String, dynamic>>[];

                for (final tx in recentTx) {
                  if (tx is Map) {
                    final txMap = Map<String, dynamic>.from(tx);
                    txMap['item_kind'] = 'transaction';
                    ledgerItems.add(txMap);
                  }
                }

                for (final exp in expensesList) {
                  if (exp is Map) {
                    final expMap = Map<String, dynamic>.from(exp);
                    expMap['item_kind'] = 'expense';
                    expMap['transacted_at'] = exp['disbursed_at'] ?? exp['created_at'];
                    ledgerItems.add(expMap);
                  }
                }

                // Sort by date descending
                ledgerItems.sort((a, b) {
                  final tA = a['transacted_at']?.toString() ?? '';
                  final tB = b['transacted_at']?.toString() ?? '';
                  return tB.compareTo(tA);
                });

                // Apply Search & Type Filtering
                final filtered = ledgerItems.where((item) {
                  final kind = item['item_kind'];
                  final isTx = kind == 'transaction';
                  final txType = item['type']?.toString().toLowerCase();
                  final direction = item['direction']?.toString().toLowerCase();
                  final status = item['status']?.toString().toLowerCase();

                  // Type Filter
                  if (_selectedType == 'inflow') {
                    if (!isTx || direction == 'outflow' || txType == 'refund' || status == 'void') {
                      return false;
                    }
                  } else if (_selectedType == 'expense') {
                    if (kind != 'expense') return false;
                  } else if (_selectedType == 'refund') {
                    if (!isTx || (txType != 'refund' && direction != 'outflow')) return false;
                  } else if (_selectedType == 'void') {
                    if (status != 'void') return false;
                  }

                  // Search Filter
                  if (_searchFilter.isNotEmpty) {
                    final code = (item['transaction_code'] ?? item['expense_number'] ?? '').toString().toLowerCase();
                    final receipt = (item['receipt_number'] ?? '').toString().toLowerCase();
                    final title = (item['title'] ?? item['booking_code'] ?? '').toString().toLowerCase();
                    final customer = (item['customer_name'] ?? item['requested_by_name'] ?? '').toString().toLowerCase();

                    return code.contains(_searchFilter) ||
                        receipt.contains(_searchFilter) ||
                        title.contains(_searchFilter) ||
                        customer.contains(_searchFilter);
                  }

                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textMuted),
                          SizedBox(height: 12),
                          Text('Tidak ada aktivitas keuangan yang cocok.', style: TextStyle(color: AppColors.textMuted)),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) => _buildLedgerTile(ctx, filtered[idx]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedType == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        selected: isSelected,
        selectedColor: AppColors.obsidian,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(color: isSelected ? Colors.white : AppColors.textPrimary),
        onSelected: (sel) {
          if (sel) setState(() => _selectedType = key);
        },
      ),
    );
  }

  Widget _buildLedgerTile(BuildContext context, Map<String, dynamic> item) {
    final isExpense = item['item_kind'] == 'expense';
    final amount = CurrencyFormatter.parse(item['amount']);
    final status = (item['status'] ?? 'completed').toString().toLowerCase();
    final isVoid = status == 'void';
    final isRefund = !isExpense && (item['type'] == 'refund' || item['direction'] == 'outflow');

    final code = isExpense ? (item['expense_number'] ?? 'EXP') : (item['transaction_code'] ?? 'TX');
    final title = isExpense
        ? (item['title'] ?? 'Beban Operasional')
        : (item['customer_name'] != null
            ? '${item['customer_name']} • ${item['items_summary'] ?? item['booking_code'] ?? ''}'.trim()
            : '${item['type_label'] ?? item['type']} • ${item['booking_code'] ?? ''}');
    final sub = isExpense
        ? 'Sumber: ${item['payment_source'] == 'cash_drawer' ? 'Kas Laci' : 'Transfer'} • Oleh: ${item['requested_by_name'] ?? 'Staff'}'
        : 'Metode: ${(item['payment_method'] is Map ? item['payment_method']['name'] : item['payment_method']) ?? 'Tunai'} • Oleh: ${(item['cashier_name'] is Map ? item['cashier_name']['name'] : item['cashier_name']) ?? 'Kasir'}';
    final timeStr = item['transacted_at']?.toString().split('T').last.split('.').first ?? '';

    final isOutflow = isExpense || isRefund;
    final color = isVoid
        ? AppColors.textMuted
        : (isOutflow ? AppColors.danger : AppColors.success);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (!isExpense && item['booking_id'] != null) {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => PosTransactionDetailSheet(booking: item),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isVoid ? AppColors.border : (isOutflow ? AppColors.danger.withValues(alpha: 0.2) : AppColors.border)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isVoid
                    ? AppColors.surfaceMuted
                    : (isOutflow ? AppColors.dangerLight : AppColors.successLight),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isVoid
                    ? Icons.block_rounded
                    : (isExpense
                        ? Icons.shopping_bag_outlined
                        : (isRefund ? Icons.assignment_return_rounded : Icons.payments_outlined)),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(code, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'monospace')),
                      if (timeStr.isNotEmpty)
                        Text(timeStr, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: isVoid ? AppColors.textMuted : AppColors.textPrimary,
                      decoration: isVoid ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${isOutflow ? '-' : '+'}${CurrencyFormatter.format(amount)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: color,
                    decoration: isVoid ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isVoid
                        ? AppColors.surfaceMuted
                        : (isOutflow ? AppColors.dangerLight : AppColors.successLight),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isVoid ? 'VOID' : (isExpense ? 'DISETUJUI' : 'BERHASIL'),
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

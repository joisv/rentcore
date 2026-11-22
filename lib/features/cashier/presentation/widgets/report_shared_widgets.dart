import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../financial_activity_ledger_screen.dart';
import '../pos_transaction_detail_sheet.dart';

/// Formats branch display names cleanly with title case while preserving
/// already-capitalized brand words (e.g. "siliragung" -> "Siliragung",
/// "RentCore Pusat" -> "RentCore Pusat").
String formatReportBranchName(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .map((word) {
        if (word.isEmpty) return word;
        final first = word[0];
        if (first == first.toLowerCase() && first != first.toUpperCase()) {
          return '${first.toUpperCase()}${word.substring(1)}';
        }
        return word;
      })
      .join(' ');
}

/// Compact single-line branch scope bar shared by Revenue & Shift tabs.
class ReportBranchScopeBar extends StatelessWidget {
  final String branchLabel;
  final bool isConsolidated;
  final bool switchable;
  final VoidCallback? onTapSwitch;

  const ReportBranchScopeBar({
    super.key,
    required this.branchLabel,
    required this.isConsolidated,
    required this.switchable,
    this.onTapSwitch,
  });

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConsolidated
              ? AppColors.warning.withValues(alpha: 0.65)
              : const Color(0xFFE2E8F0),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConsolidated ? Icons.hub_outlined : Icons.storefront_outlined,
            size: 18,
            color: isConsolidated
                ? AppColors.warning
                : const Color(0xFF0F172A),
          ),
          const SizedBox(width: 8),
          const Text(
            'Cakupan:',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              branchLabel,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          if (switchable)
            const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ganti',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                SizedBox(width: 2),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 16,
                  color: Color(0xFF64748B),
                ),
              ],
            )
          else
            const Text(
              'Terkunci',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
        ],
      ),
    );

    if (switchable && onTapSwitch != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTapSwitch,
          borderRadius: BorderRadius.circular(12),
          child: content,
        ),
      );
    }

    return content;
  }
}

/// Sleek 34dp pill chip for date filters across Pendapatan & Riwayat Shift.
class ReportFilterPill extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? leadingIcon;

  const ReportFilterPill({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.leadingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? const Color(0xFF0F172A) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingIcon != null) ...[
                Icon(
                  leadingIcon,
                  size: 14,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF475569),
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Understated section header matching the Airy Minimalist design tokens.
class ReportSectionHeader extends StatelessWidget {
  final String title;
  final EdgeInsetsGeometry padding;

  const ReportSectionHeader({
    super.key,
    required this.title,
    this.padding = const EdgeInsets.fromLTRB(20, 20, 20, 8),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          color: Color(0xFF64748B),
        ),
      ),
    );
  }
}

/// Hairline-separated payment method breakdown list (no boxed cards or colored badges).
class ReportPaymentMethodList extends StatelessWidget {
  final Map<String, dynamic> breakdown;
  final bool isBlindClose;

  const ReportPaymentMethodList({
    super.key,
    required this.breakdown,
    this.isBlindClose = false,
  });

  IconData _resolveMethodIcon(String kStr) {
    if (kStr.contains('tunai') || kStr == 'cash') {
      return Icons.payments_outlined;
    }
    if (kStr.contains('qris')) {
      return Icons.qr_code_scanner_rounded;
    }
    if (kStr.contains('transfer') || kStr.contains('bank')) {
      return Icons.account_balance_outlined;
    }
    if (kStr.contains('edc') || kStr.contains('card') || kStr.contains('kartu')) {
      return Icons.credit_card_outlined;
    }
    return Icons.account_balance_wallet_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ReportSectionHeader(title: 'Rincian Metode Pembayaran'),
        if (breakdown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Text(
              'Belum ada transaksi pembayaran di periode ini.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
            ),
          )
        else
          for (int i = 0; i < breakdown.entries.length; i++) ...[
            if (i > 0)
              const Divider(
                height: 1,
                thickness: 1,
                indent: 20,
                endIndent: 20,
                color: Color(0xFFF1F5F9),
              ),
            Builder(
              builder: (_) {
                final entry = breakdown.entries.elementAt(i);
                final val = entry.value is Map ? (entry.value as Map) : {};
                final total = CurrencyFormatter.parse(val['total']);
                final count = val['count'] ?? 0;
                final kStr = entry.key.toString().toLowerCase();
                final hiddenCash = isBlindClose &&
                    (val['is_blind_close'] == true ||
                        val['total'] == null ||
                        kStr.contains('tunai') ||
                        kStr == 'cash');

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _resolveMethodIcon(kStr),
                        size: 20,
                        color: const Color(0xFF0F172A),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$count Transaksi',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        hiddenCash
                            ? 'Disembunyikan'
                            : CurrencyFormatter.format(total),
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: hiddenCash ? 12 : 14.5,
                          color: hiddenCash
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF0F172A),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
      ],
    );
  }
}

/// Hairline-separated Recent Transactions audit section with "Buku Kas Lengkap >" link.
class ReportRecentTransactionsList extends StatelessWidget {
  final List transactions;
  final bool isConsolidated;

  const ReportRecentTransactionsList({
    super.key,
    required this.transactions,
    required this.isConsolidated,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'Transaksi Terbaru',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const FinancialActivityLedgerScreen(),
                    ),
                  );
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Buku Kas Lengkap',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFF0F172A),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        for (int i = 0; i < transactions.length; i++) ...[
          if (i > 0)
            const Divider(
              height: 1,
              thickness: 1,
              indent: 20,
              endIndent: 20,
              color: Color(0xFFF1F5F9),
            ),
          Builder(
            builder: (_) {
              final tx = transactions[i] is Map ? transactions[i] as Map : {};
              final txCode =
                  tx['receipt_number'] ?? tx['transaction_code'] ?? 'TX';
              final custName = tx['customer_name'] ?? 'Pelanggan';
              final brName = formatReportBranchName(
                (tx['branch_name'] ?? 'Cabang').toString(),
              );
              final isCent = tx['is_central'] == true;
              final txAmt = CurrencyFormatter.parse(tx['amount']);
              final pMethod = tx['payment_method'] ?? 'Tunai';
              final itemsSummary = tx['items_summary'] ?? 'Perangkat Apple';
              final txType = tx['type']?.toString().toLowerCase();

              final String categoryLabel;
              if (txType == 'penalty') {
                categoryLabel = 'Denda';
              } else if (txType == 'extension') {
                categoryLabel = 'Perpanjangan';
              } else {
                categoryLabel = 'Sewa';
              }

              final metaLine = isConsolidated
                  ? '$pMethod • $categoryLabel • ${isCent ? 'Pusat' : brName}'
                  : '$pMethod • $categoryLabel';

              return InkWell(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => PosTransactionDetailSheet(
                      booking: Map<String, dynamic>.from(tx),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    txCode.toString(),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: Color(0xFF0F172A),
                                      fontFeatures: [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (txType == 'penalty') ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF7ED),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFFED7AA),
                                      ),
                                    ),
                                    child: const Text(
                                      'Denda',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFFC2410C),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '$custName • $itemsSummary',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              metaLine,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFF64748B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            CurrencyFormatter.format(txAmt),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: Color(0xFF0F172A),
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}

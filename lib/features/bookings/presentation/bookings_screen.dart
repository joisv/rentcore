import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../providers/booking_provider.dart';
import 'direct_rental_screen.dart';
import 'exchange_history_sheet.dart';
import 'exchange_wizard_screen.dart';
import 'return_wizard_screen.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFilter = ref.watch(bookingFilterStatusProvider);
    final bookingsAsync = ref.watch(bookingsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Antrean Sewa Cabang'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            tooltip: 'Sewa Baru',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DirectRentalScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.refresh(bookingsListProvider),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Capsule Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildFilterChip(ref, 'Sedang Sewa', 'rented', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Terlambat', 'overdue', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Semua', 'all', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Selesai', 'returned', currentFilter),
              ],
            ),
          ),

          // Bookings List
          Expanded(
            child: bookingsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Gagal memuat daftar sewa: $e'),
                ),
              ),
              data: (bookings) {
                if (bookings.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'Tidak ada data sewa untuk filter ini.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => ref.refresh(bookingsListProvider.future),
                  child: ListView.builder(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                    itemCount: bookings.length,
                    itemBuilder: (context, index) {
                      final item = bookings[index];
                      final customer = item['customer'] ?? {};
                      final items = (item['items'] as List?) ?? [];
                      final exchanges = (item['exchanges'] as List?) ?? [];
                      Map<String, dynamic>? activeItem;
                      for (final it in items) {
                        if (it is Map && (it['status'] == 'active' || it['status'] == null)) {
                          activeItem = (it as Map).cast<String, dynamic>();
                          break;
                        }
                      }
                      activeItem ??= (items.isNotEmpty && items.first is Map)
                          ? (items.first as Map).cast<String, dynamic>()
                          : null;
                      final activeAsset = (item['active_asset'] as Map?)?.cast<String, dynamic>() ??
                          (activeItem?['asset'] as Map?)?.cast<String, dynamic>();
                      final model = activeAsset?['model'];

                      final endAt = item['end_at'] != null ? DateTime.tryParse(item['end_at']) : null;
                      final isReturned = item['status'] == 'returned';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Row: Code, Exchange tag & Relative time tag
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceMuted,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        item['booking_code'] ?? '',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    if (exchanges.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () => ExchangeHistorySheet.show(context, item),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: AppColors.infoLight,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.info.withOpacity(0.3)),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.swap_horiz_rounded, size: 12, color: AppColors.info),
                                              const SizedBox(width: 3),
                                              Text(
                                                'Ditukar (${exchanges.length}x)',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.info),
                                              ),
                                              const SizedBox(width: 2),
                                              const Icon(Icons.info_outline_rounded, size: 11, color: AppColors.info),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                StatusBadge(
                                  label: isReturned ? 'SELESAI' : DateFormatter.formatRelative(endAt),
                                  textColor: isReturned
                                      ? AppColors.textSecondary
                                      : (endAt != null && endAt.isBefore(DateTime.now()))
                                          ? AppColors.danger
                                          : AppColors.info,
                                  backgroundColor: isReturned
                                      ? AppColors.surfaceMuted
                                      : (endAt != null && endAt.isBefore(DateTime.now()))
                                          ? AppColors.dangerLight
                                          : AppColors.infoLight,
                                  borderRadius: 12,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Main Details
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.borderSubtle),
                                  ),
                                  child: const Icon(Icons.smartphone_rounded, size: 28),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model?['name'] ?? 'Perangkat Sewa',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      if (activeAsset?['asset_code'] != null || activeAsset?['serial_number'] != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          '${activeAsset?['asset_code'] ?? ''}${activeAsset?['serial_number'] != null ? ' • SN: ${activeAsset?['serial_number']}' : ''}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontFamily: 'monospace',
                                            color: AppColors.textMuted,
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        '${customer['name'] ?? 'Pelanggan'} • ${customer['phone'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.lock_clock_outlined, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Jaminan: ${item['collateral_storage_slot'] ?? 'Brankas Cabang'}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (!isReturned) ...[
                              const SizedBox(height: 14),
                              const Divider(height: 1, color: AppColors.borderSubtle),
                              const SizedBox(height: 12),

                              // Direct Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () => _showExtendDialog(context, ref, item),
                                      child: const Text('+ Tambah Jam', style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.info,
                                        side: const BorderSide(color: AppColors.info),
                                      ),
                                      onPressed: () async {
                                        final res = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ExchangeWizardScreen(booking: item),
                                          ),
                                        );
                                        if (res != null) {
                                          ref.invalidate(bookingsListProvider);
                                        }
                                      },
                                      child: const Text('Ganti Unit', style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReturnWizardScreen(booking: item),
                                          ),
                                        );
                                      },
                                      child: const Text('Pengembalian', style: TextStyle(fontSize: 11)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(WidgetRef ref, String label, String value, String? currentFilter) {
    final isSelected = currentFilter == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) {
        ref.read(bookingFilterStatusProvider.notifier).setFilter(value);
      },
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.obsidian : AppColors.border,
        ),
      ),
      showCheckmark: false,
    );
  }

  void _showExtendDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    int selectedHours = 6;
    final bookingId = (item['id'] as num).toInt();
    final bookingCode = item['booking_code']?.toString() ?? '#$bookingId';
    final customer = (item['customer'] as Map?) ?? {};
    final customerName = customer['name']?.toString() ?? 'Pelanggan';
    final device = (item['device'] as Map?) ?? {};
    final model = (device['asset_model'] as Map?) ?? {};
    final deviceModel = model['name']?.toString() ?? 'Unit Sewa';
    final hourlyRate = ((model['tier']?['hourly_rate'] ?? 15000) as num).toInt();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final fee = selectedHours * hourlyRate;

            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Perpanjang Masa Sewa Unit',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tarif perpanjangan: ${CurrencyFormatter.format(hourlyRate)} / jam.',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [6, 12, 24].map((hours) {
                      final isSel = selectedHours == hours;
                      return ChoiceChip(
                        label: Text('$hours Jam'),
                        selected: isSel,
                        onSelected: (_) => setModalState(() => selectedHours = hours),
                        selectedColor: AppColors.obsidian,
                        labelStyle: TextStyle(color: isSel ? Colors.white : AppColors.textPrimary),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Biaya Tambahan:', style: TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          CurrencyFormatter.format(fee),
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      final result = await Navigator.push<PaymentResult>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PaymentPage(
                            paymentContext: PaymentContext.extension(
                              bookingId: bookingId,
                              bookingCode: bookingCode,
                              customerName: customerName,
                              deviceModel: deviceModel,
                              additionalHours: selectedHours,
                              extensionFee: fee.toDouble(),
                            ),
                          ),
                        ),
                      );

                      if (result != null && result.isSuccess) {
                        ref.invalidate(bookingsListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Perpanjangan sewa $selectedHours jam berhasil dibayar & diperbarui!'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      }
                    },
                    child: const Text('Lanjut ke Pembayaran POS 💳'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        await ref.read(bookingRepositoryProvider).extendRental(bookingId, selectedHours);
                        ref.invalidate(bookingsListProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sewa diperpanjang $selectedHours jam (tagihan dicatat).')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
                          );
                        }
                      }
                    },
                    child: const Text(
                      'Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

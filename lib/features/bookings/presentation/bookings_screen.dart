import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../providers/booking_provider.dart';
import 'direct_rental_screen.dart';
import 'exchange_history_sheet.dart';
import 'exchange_wizard_screen.dart';
import 'return_wizard_screen.dart';

class _ExtensionOption {
  final int hours;
  final double price;
  final String label;

  const _ExtensionOption({
    required this.hours,
    required this.price,
    required this.label,
  });
}

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

                      // Reliably distinguish primary device and associated add-ons
                      Map<String, dynamic>? primaryItem;
                      final addonItems = <Map<String, dynamic>>[];

                      for (final it in items) {
                        if (it is Map) {
                          final itMap = Map<String, dynamic>.from(it);
                          final itemType = itMap['item_type']?.toString().toLowerCase();
                          final asset = itMap['asset'] as Map?;
                          final m = asset?['model'] as Map?;
                          final isAddon = itemType == 'addon' ||
                              m?['is_addon'] == true ||
                              m?['is_addon'] == 1;

                          if (isAddon) {
                            addonItems.add(itMap);
                          } else {
                            final isActive = itMap['status'] == 'active' || itMap['status'] == null;
                            if (isActive && primaryItem == null) {
                              primaryItem = itMap;
                            } else {
                              primaryItem ??= itMap;
                            }
                          }
                        }
                      }

                      // Fallback: If no primary item identified, use first item
                      if (primaryItem == null && items.isNotEmpty && items.first is Map) {
                        primaryItem = Map<String, dynamic>.from(items.first as Map);
                        addonItems.remove(primaryItem);
                      }

                      final activeAsset = (item['primary_asset'] as Map?)?.cast<String, dynamic>() ??
                          (item['active_asset'] as Map?)?.cast<String, dynamic>() ??
                          (primaryItem?['asset'] as Map?)?.cast<String, dynamic>();
                      final model = activeAsset?['model'];

                      final endAt = item['end_at'] != null ? DateTime.tryParse(item['end_at']) : null;
                      final isReturned = item['status'] == 'returned';
                      final paymentStatus = (item['payment_status'] ?? 'paid').toString().toLowerCase();
                      final hasUnpaidPenalty = isReturned && paymentStatus != 'paid';

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
                                            border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
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
                                  label: isReturned
                                      ? (hasUnpaidPenalty ? 'SELESAI (DENDA BELUM LUNAS)' : 'SELESAI')
                                      : DateFormatter.formatRelative(endAt),
                                  textColor: hasUnpaidPenalty
                                      ? AppColors.warning
                                      : isReturned
                                          ? AppColors.textSecondary
                                          : (endAt != null && endAt.isBefore(DateTime.now()))
                                              ? AppColors.danger
                                              : AppColors.info,
                                  backgroundColor: hasUnpaidPenalty
                                      ? AppColors.warningLight
                                      : isReturned
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

                            // Associated Add-on Items Section
                            if (addonItems.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: AppColors.borderSubtle),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.extension_outlined, size: 14, color: AppColors.obsidian),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Item Add-on (${addonItems.length}):',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 4,
                                      children: addonItems.map((addon) {
                                        final aAsset = addon['asset'] as Map? ?? {};
                                        final aModel = aAsset['model'] as Map? ?? {};
                                        final aName = aModel['name']?.toString() ?? 'Aksesoris';
                                        final aCode = aAsset['asset_code']?.toString();
                                        final aPrice = addon['unit_price'] != null ? CurrencyFormatter.parse(addon['unit_price']) : 0.0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.border),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check_circle_outline_rounded, size: 12, color: AppColors.success),
                                              const SizedBox(width: 4),
                                              Text(
                                                aCode != null ? '$aName ($aCode)' : aName,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                              ),
                                              if (aPrice > 0) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '• ${CurrencyFormatter.format(aPrice)}',
                                                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                                                ),
                                              ],
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Pricing & Subtotal Summary Row
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                if (item['addon_subtotal'] != null && CurrencyFormatter.parse(item['addon_subtotal']) > 0)
                                  Text(
                                    'Utama: ${CurrencyFormatter.format(item['primary_subtotal'] ?? 0)} • Add-on: ${CurrencyFormatter.format(item['addon_subtotal'])}',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                  )
                                else
                                  const SizedBox(),
                                Builder(
                                  builder: (_) {
                                    final totalBill = CurrencyFormatter.parse(item['total_bill'] ?? item['total_amount'] ?? 0);
                                    final returnInspection = item['return_inspection'] as Map? ?? item['returnInspection'] as Map? ?? {};
                                    final penaltyDue = CurrencyFormatter.parse(returnInspection['total_penalty']);
                                    final effectiveTotal = totalBill + penaltyDue;
                                    return Text(
                                      penaltyDue > 0
                                          ? 'Total: ${CurrencyFormatter.format(effectiveTotal)} (+ Denda)'
                                          : 'Total: ${CurrencyFormatter.format(totalBill)}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                                    );
                                  },
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
    final bookingId = (item['id'] as num).toInt();
    final bookingCode = item['booking_code']?.toString() ?? '#$bookingId';
    final customer = (item['customer'] as Map?) ?? {};
    final customerName = customer['name']?.toString() ?? 'Pelanggan';

    Map<String, dynamic>? resolvedModel;
    final items = item['items'] as List?;
    if (items != null && items.isNotEmpty) {
      final first = items.first;
      if (first is Map) {
        final asset = first['asset'] as Map?;
        if (asset != null && asset['model'] is Map) {
          resolvedModel = Map<String, dynamic>.from(asset['model']);
        }
      }
    }
    if (resolvedModel == null) {
      final primaryAsset = (item['primary_asset'] as Map?) ??
          (item['active_asset'] as Map?) ??
          (item['device'] as Map?) ?? {};
      if (primaryAsset['model'] is Map) {
        resolvedModel = Map<String, dynamic>.from(primaryAsset['model']);
      } else if (primaryAsset['asset_model'] is Map) {
        resolvedModel = Map<String, dynamic>.from(primaryAsset['asset_model']);
      }
    }

    final deviceModel = resolvedModel?['name']?.toString() ?? 'Unit Sewa';

    // Extract rates configured on the model
    final rawTiers = (resolvedModel?['pricing_tiers'] as List?) ??
        (resolvedModel?['pricingTiers'] as List?) ?? [];
    final options = <_ExtensionOption>[];

    for (final t in rawTiers) {
      if (t is Map) {
        final hours = int.tryParse(t['duration_hours']?.toString() ?? '0') ?? 0;
        final price = (t['price'] is num)
            ? (t['price'] as num).toDouble()
            : (double.tryParse(t['price']?.toString() ?? '0') ?? 0.0);
        final isActive = t['is_active'] != false;
        if (hours > 0 && isActive) {
          options.add(_ExtensionOption(
            hours: hours,
            price: price,
            label: '$hours Jam',
          ));
        }
      }
    }

    options.sort((a, b) => a.hours.compareTo(b.hours));

    // Fallback if no specific pricing tiers configured
    if (options.isEmpty) {
      final hourlyRate = ((resolvedModel?['tier']?['hourly_rate'] ?? 15000) as num).toDouble();
      for (final h in [6, 12, 24]) {
        options.add(_ExtensionOption(
          hours: h,
          price: h * hourlyRate,
          label: '$h Jam',
        ));
      }
    }

    int selectedHours = options.first.hours;
    final currentEndAt = DateTime.tryParse(item['end_at']?.toString() ?? '')?.toLocal();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final selectedOption = options.firstWhere(
              (o) => o.hours == selectedHours,
              orElse: () => options.first,
            );
            final fee = selectedOption.price;
            final newEndAt = currentEndAt?.add(Duration(hours: selectedHours));

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
                  const SizedBox(height: 4),
                  Text(
                    'Perangkat: $deviceModel • $bookingCode',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Pilihan Durasi Perpanjangan (Sesuai Tarif Model):',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: options.map((opt) {
                        final isSel = selectedHours == opt.hours;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('${opt.label} • ${CurrencyFormatter.format(opt.price)}'),
                            selected: isSel,
                            onSelected: (_) => setModalState(() => selectedHours = opt.hours),
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Biaya Perpanjangan:', style: TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              CurrencyFormatter.format(fee),
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.obsidian),
                            ),
                          ],
                        ),
                        if (newEndAt != null) ...[
                          const SizedBox(height: 8),
                          const Divider(height: 1, color: AppColors.borderSubtle),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Batas Waktu Baru:', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                              Text(
                                DateFormatter.formatFull(newEndAt),
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textPrimary),
                              ),
                            ],
                          ),
                        ],
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
                              extensionFee: fee,
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

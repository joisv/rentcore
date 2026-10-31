import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/business_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../providers/booking_provider.dart';
import 'direct_rental_screen.dart';
import 'exchange_history_sheet.dart';
import 'exchange_wizard_screen.dart';
import 'return_wizard_screen.dart';

class _AdjustmentTarget {
  final int? itemId;
  final String label;
  final String shortName;
  final bool isPrimary;
  final int currentDurationHours;
  final double currentPrice;
  final Map<String, dynamic>? model;

  const _AdjustmentTarget({
    this.itemId,
    required this.label,
    required this.shortName,
    required this.isPrimary,
    required this.currentDurationHours,
    required this.currentPrice,
    this.model,
  });
}

class _DurationOption {
  final int hours;
  final double price;
  final String label;

  const _DurationOption({
    required this.hours,
    required this.price,
    required this.label,
  });
}

List<_DurationOption> _getDurationOptionsForTarget(Map<String, dynamic>? model) {
  final rawTiers = (model?['pricing_tiers'] as List?) ??
      (model?['pricingTiers'] as List?) ?? [];
  final options = <_DurationOption>[];

  for (final t in rawTiers) {
    if (t is Map) {
      final hours = int.tryParse(t['duration_hours']?.toString() ?? '0') ?? 0;
      final price = (t['price'] is num)
          ? (t['price'] as num).toDouble()
          : (double.tryParse(t['price']?.toString() ?? '0') ?? 0.0);
      final isActive = t['is_active'] != false;
      if (hours > 0 && isActive) {
        final val = int.tryParse(t['duration_value']?.toString() ?? '') ?? hours;
        final unit = (t['duration_unit']?.toString() ?? 'hour').toLowerCase();
        String lbl;
        if (unit == 'day') {
          lbl = '$val Hari ($hours Jam)';
        } else if (unit == 'week') {
          lbl = '$val Minggu ($hours Jam)';
        } else {
          lbl = '$hours Jam';
        }
        options.add(_DurationOption(
          hours: hours,
          price: price,
          label: lbl,
        ));
      }
    }
  }

  options.sort((a, b) => a.hours.compareTo(b.hours));

  // Fallback if no specific pricing tiers configured
  if (options.isEmpty) {
    final hourlyRate = ((model?['tier']?['hourly_rate'] ?? 15000) as num).toDouble();
    for (final h in [6, 12, 24]) {
      options.add(_DurationOption(
        hours: h,
        price: h * hourlyRate,
        label: '$h Jam',
      ));
    }
  }

  return options;
}

IconData _getItemCategoryIcon({
  Map<String, dynamic>? model,
  Map<String, dynamic>? asset,
  Map<String, dynamic>? primaryItem,
}) {
  final rawCat = model?['category'];
  final catName = (rawCat is Map ? rawCat['name'] : rawCat)?.toString().toLowerCase() ?? '';
  final modelName = (model?['name'] ?? primaryItem?['name'] ?? '').toString().toLowerCase();
  final assetCode = (asset?['asset_code'] ?? '').toString().toLowerCase();

  final combined = '$catName $modelName $assetCode';

  if (combined.contains('tenda') ||
      combined.contains('camp') ||
      combined.contains('outdoor') ||
      combined.contains('gunung') ||
      combined.contains('carrier') ||
      combined.contains('sleeping bag') ||
      combined.contains('matras') ||
      combined.contains('flysheet')) {
    return Icons.cabin_rounded;
  }
  if (combined.contains('kamera') ||
      combined.contains('camera') ||
      combined.contains('dslr') ||
      combined.contains('mirrorless') ||
      combined.contains('lensa') ||
      combined.contains('lens') ||
      combined.contains('sony a') ||
      combined.contains('canon') ||
      combined.contains('fujifilm')) {
    return Icons.camera_alt_rounded;
  }
  if (combined.contains('laptop') ||
      combined.contains('macbook') ||
      combined.contains('notebook') ||
      combined.contains('komputer') ||
      combined.contains('pc')) {
    return Icons.laptop_mac_rounded;
  }
  if (combined.contains('proyektor') ||
      combined.contains('projector') ||
      combined.contains('infocus')) {
    return Icons.videocam_rounded;
  }
  if (combined.contains('game') ||
      combined.contains('konsol') ||
      combined.contains('playstation') ||
      combined.contains('ps4') ||
      combined.contains('ps5') ||
      combined.contains('nintendo') ||
      combined.contains('xbox')) {
    return Icons.sports_esports_rounded;
  }
  if (combined.contains('tablet') ||
      combined.contains('ipad') ||
      combined.contains('tab')) {
    return Icons.tablet_mac_rounded;
  }
  if (combined.contains('audio') ||
      combined.contains('speaker') ||
      combined.contains('sound') ||
      combined.contains('headphone') ||
      combined.contains('headset') ||
      combined.contains('mic')) {
    return Icons.headphones_rounded;
  }
  if (combined.contains('drone') || combined.contains('dji')) {
    return Icons.flight_takeoff_rounded;
  }
  if (combined.contains('motor') ||
      combined.contains('sepeda') ||
      combined.contains('vehicle') ||
      combined.contains('mobil')) {
    return Icons.two_wheeler_rounded;
  }
  if (combined.contains('phone') ||
      combined.contains('iphone') ||
      combined.contains('samsung') ||
      combined.contains('xiaomi') ||
      combined.contains('oppo') ||
      combined.contains('vivo') ||
      combined.contains('hp') ||
      combined.contains('gadget') ||
      combined.contains('smartphone')) {
    return Icons.phone_iphone_rounded;
  }
  if (combined.contains('alat') || combined.contains('gear') || combined.contains('aksesoris')) {
    return Icons.inventory_2_outlined;
  }
  return Icons.devices_other_rounded;
}

class BookingsScreen extends ConsumerStatefulWidget {
  const BookingsScreen({super.key});

  @override
  ConsumerState<BookingsScreen> createState() => _BookingsScreenState();
}

class _BookingsScreenState extends ConsumerState<BookingsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  final List<Map<String, dynamic>> _extraBookings = [];
  int _currentBookingPage = 1;
  bool _hasMoreBookings = true;
  bool _isLoadingMoreBookings = false;

  void _resetBookingPagination() {
    _extraBookings.clear();
    _currentBookingPage = 1;
    _hasMoreBookings = true;
    _isLoadingMoreBookings = false;
  }

  void _onBookingsScroll() async {
    if (!_scrollController.hasClients || _isLoadingMoreBookings || !_hasMoreBookings) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 250) {
      final bizState = ref.read(businessProvider);
      final repo = ref.read(bookingRepositoryProvider);
      final status = ref.read(bookingFilterStatusProvider);
      final searchQuery = ref.read(bookingSearchQueryProvider);

      setState(() => _isLoadingMoreBookings = true);
      try {
        final nextPage = _currentBookingPage + 1;
        final res = await repo.fetchBookingsPaginated(
          status: status == 'all' ? null : status,
          search: searchQuery.trim().isEmpty ? null : searchQuery.trim(),
          branchId: bizState.activeBranchId,
          allBranches: bizState.isConsolidated,
          page: nextPage,
        );

        if (mounted) {
          setState(() {
            _currentBookingPage = nextPage;
            _hasMoreBookings = res.hasMore;
            _extraBookings.addAll(res.items);
            _isLoadingMoreBookings = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingMoreBookings = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(bookingSearchQueryProvider);
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }

    _scrollController.addListener(_onBookingsScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _resetBookingPagination();
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        ref.read(bookingSearchQueryProvider.notifier).setQuery(val.trim());
      }
    });
    setState(() {});
  }

  void _clearSearch() {
    _resetBookingPagination();
    _debounceTimer?.cancel();
    _searchController.clear();
    ref.read(bookingSearchQueryProvider.notifier).clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentFilter = ref.watch(bookingFilterStatusProvider);
    final bookingsAsync = ref.watch(bookingsListProvider);
    final currentSearch = ref.watch(bookingSearchQueryProvider);

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
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 2),
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 13, color: AppColors.obsidian),
                textInputAction: TextInputAction.search,
                onSubmitted: (val) {
                  _debounceTimer?.cancel();
                  ref.read(bookingSearchQueryProvider.notifier).setQuery(val.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Cari kode booking, nama, telp, atau unit...',
                  hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w400),
                  prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.obsidian, width: 1.2),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                ),
                onChanged: _onSearchChanged,
              ),
            ),
          ),

          // Filter Capsule Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  final isSearching = currentSearch.isNotEmpty;
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isSearching ? Icons.search_off_rounded : Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSearching
                                ? 'Tidak ditemukan transaksi sewa yang cocok.'
                                : 'Tidak ada data sewa untuk filter ini.',
                            style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center,
                          ),
                          if (isSearching) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Kata kunci: "$currentSearch"',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Reset Pencarian', style: TextStyle(fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.obsidian,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final combinedBookings = [...bookings, ..._extraBookings];

                return RefreshIndicator(
                  onRefresh: () async {
                    _resetBookingPagination();
                    return ref.refresh(bookingsListProvider.future);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 100),
                    itemCount: combinedBookings.length + (_isLoadingMoreBookings ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= combinedBookings.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      final item = combinedBookings[index];
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
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: AppColors.borderSubtle),
                                          ),
                                          child: Text(
                                            item['booking_code'] ?? '',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.obsidian,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                ),
                                const SizedBox(width: 8),
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
                            if (endAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(Icons.schedule_rounded, size: 11, color: AppColors.textSecondary),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Batas sewa: ${DateFormatter.formatFull(endAt)}',
                                      style: const TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.end,
                                    ),
                                  ),
                                ],
                              ),
                            ],
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
                                  child: Icon(
                                    _getItemCategoryIcon(
                                      model: model is Map ? Map<String, dynamic>.from(model) : null,
                                      asset: activeAsset,
                                      primaryItem: primaryItem,
                                    ),
                                    size: 26,
                                    color: AppColors.obsidian,
                                  ),
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                      const SizedBox(height: 4),
                                      Text(
                                        '${customer['name'] ?? 'Pelanggan'} • ${customer['phone'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.lock_clock_outlined, size: 14, color: AppColors.textMuted),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Jaminan: ${item['collateral_storage_slot'] ?? 'Brankas Cabang'}',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
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
                                              Flexible(
                                                child: Text(
                                                  aCode != null ? '$aName ($aCode)' : aName,
                                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
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

                            // Pricing & Subtotal Summary Container
                            Container(
                              margin: const EdgeInsets.only(top: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.borderSubtle),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      (item['addon_subtotal'] != null && CurrencyFormatter.parse(item['addon_subtotal']) > 0)
                                          ? 'Utama: ${CurrencyFormatter.format(item['primary_subtotal'] ?? 0)} • Add-on: ${CurrencyFormatter.format(item['addon_subtotal'])}'
                                          : 'Total Tagihan',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
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
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.obsidian,
                                          letterSpacing: -0.2,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
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
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                      onPressed: () => _showExtendDialog(context, ref, item),
                                      child: const Text('Tambah Jam', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(color: AppColors.border),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                                      child: const Text('Ganti Unit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.obsidian,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReturnWizardScreen(booking: item),
                                          ),
                                        );
                                      },
                                      child: const Text('Pengembalian', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
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
        _resetBookingPagination();
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
    _showDurationAdjustmentDialog(context, ref, item);
  }

  void _showDurationAdjustmentDialog(BuildContext context, WidgetRef ref, Map<String, dynamic> item) {
    final bookingId = (item['id'] as num).toInt();
    final bookingCode = item['booking_code']?.toString() ?? '#$bookingId';
    final customer = (item['customer'] as Map?) ?? {};
    final customerName = customer['name']?.toString() ?? 'Pelanggan';

    // 1. Resolve Primary Model
    Map<String, dynamic>? resolvedModel;
    final rawItems = item['items'] as List?;
    if (rawItems != null && rawItems.isNotEmpty) {
      final first = rawItems.first;
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
    final currentEndAt = DateTime.tryParse(item['end_at']?.toString() ?? '')?.toLocal();

    // 2. Build Targets (Primary + Addons)
    final targets = <_AdjustmentTarget>[];
    if (rawItems != null && rawItems.isNotEmpty) {
      Map? primaryItem;
      for (final it in rawItems) {
        if (it is Map && it['item_type'] == 'primary') {
          primaryItem = it;
          break;
        }
      }
      primaryItem ??= rawItems.first is Map ? (rawItems.first as Map) : null;
      if (primaryItem != null) {
        final pAsset = primaryItem['asset'] as Map? ?? {};
        final pModel = pAsset['model'] as Map? ?? resolvedModel;
        final pName = pModel?['name']?.toString() ?? deviceModel;
        final pDur = int.tryParse(primaryItem['duration_value']?.toString() ?? '') ??
            int.tryParse(item['duration_hours']?.toString() ?? '24') ?? 24;
        final pPrice = (primaryItem['unit_price'] != null)
            ? CurrencyFormatter.parse(primaryItem['unit_price'])
            : CurrencyFormatter.parse(item['primary_subtotal'] ?? item['total_bill'] ?? 0);

        targets.add(_AdjustmentTarget(
          itemId: primaryItem['id'] as int?,
          label: 'Utama: $pName',
          shortName: pName,
          isPrimary: true,
          currentDurationHours: pDur,
          currentPrice: pPrice,
          model: pModel != null ? Map<String, dynamic>.from(pModel) : null,
        ));
      }

      for (final it in rawItems) {
        if (it is Map && it['item_type'] == 'addon') {
          final aAsset = it['asset'] as Map? ?? {};
          final aModel = aAsset['model'] as Map?;
          final aName = aModel?['name']?.toString() ?? 'Aksesoris';
          final aDur = int.tryParse(it['duration_value']?.toString() ?? '') ??
              int.tryParse(item['duration_hours']?.toString() ?? '24') ?? 24;
          final aPrice = CurrencyFormatter.parse(it['unit_price'] ?? 0);

          targets.add(_AdjustmentTarget(
            itemId: it['id'] as int?,
            label: 'Add-on: $aName',
            shortName: aName,
            isPrimary: false,
            currentDurationHours: aDur,
            currentPrice: aPrice,
            model: aModel != null ? Map<String, dynamic>.from(aModel) : null,
          ));
        }
      }
    }

    if (targets.isEmpty) {
      final pDur = int.tryParse(item['duration_hours']?.toString() ?? '24') ?? 24;
      final pPrice = CurrencyFormatter.parse(item['primary_subtotal'] ?? item['total_bill'] ?? 0);
      targets.add(_AdjustmentTarget(
        itemId: null,
        label: 'Utama: $deviceModel',
        shortName: deviceModel,
        isPrimary: true,
        currentDurationHours: pDur,
        currentPrice: pPrice,
        model: resolvedModel,
      ));
    }

    int selectedTargetIndex = 0;
    String direction = 'increase';
    int selectedHours = 6;
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    bool isSubmitting = false;

    // Calculate Net Payments Paid so far
    final payments = (item['payments'] as List?) ?? [];
    double alreadyPaidNet = 0.0;
    for (final p in payments) {
      if (p is Map) {
        if (p['status']?.toString().toLowerCase() == 'void') continue;
        final dir = p['direction']?.toString().toLowerCase();
        final type = p['type']?.toString().toLowerCase();
        final amt = CurrencyFormatter.parse(p['amount'] ?? 0);
        if (dir == 'inflow' || type == 'settlement' || type == 'dp' || type == 'rental' || type == 'extension') {
          alreadyPaidNet += amt;
        } else if (dir == 'outflow' || type == 'refund') {
          alreadyPaidNet -= amt;
        }
      }
    }

    final originalTotalBill = CurrencyFormatter.parse(item['total_bill'] ?? item['total_amount'] ?? 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeTarget = targets[selectedTargetIndex];
            final isIncrease = direction == 'increase';

            // Available duration options configured on the model
            final durationOptions = _getDurationOptionsForTarget(activeTarget.model);
            if (!durationOptions.any((o) => o.hours == selectedHours)) {
              selectedHours = durationOptions.isNotEmpty ? durationOptions.first.hours : 6;
            }

            final selectedOption = durationOptions.firstWhere(
              (o) => o.hours == selectedHours,
              orElse: () => durationOptions.isNotEmpty
                  ? durationOptions.first
                  : const _DurationOption(hours: 6, price: 90000, label: '6 Jam'),
            );
            final fee = selectedOption.price;
            final deltaFee = isIncrease ? fee : -fee;

            // Compute Boundary Checks
            DateTime? newEndAt;
            bool isEndAtInPast = false;
            if (activeTarget.isPrimary && currentEndAt != null) {
              if (isIncrease) {
                newEndAt = currentEndAt.add(Duration(hours: selectedHours));
              } else {
                newEndAt = currentEndAt.subtract(Duration(hours: selectedHours));
                isEndAtInPast = newEndAt.isBefore(DateTime.now());
              }
            } else if (currentEndAt != null) {
              newEndAt = currentEndAt;
            }

            final isBelowMinimumDuration = !isIncrease &&
                (activeTarget.currentDurationHours - selectedHours < 1);

            // Check if Overpayment / Refund is produced
            final estimatedNewTotal = (originalTotalBill + deltaFee).clamp(0.0, double.infinity);
            final refundDue = (!isIncrease && alreadyPaidNet > estimatedNewTotal)
                ? (alreadyPaidNet - estimatedNewTotal)
                : 0.0;

            final hasBoundaryError = isEndAtInPast || isBelowMinimumDuration;
            final canSubmitReduction = !hasBoundaryError &&
                (!isIncrease && (refundDue == 0 || pinController.text.trim().length >= 4));

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle Bar
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Atur Durasi Sewa',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            bookingCode,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: AppColors.obsidian),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Pelanggan: $customerName',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    // Target Selector (if add-ons exist)
                    if (targets.length > 1) ...[
                      const Text(
                        'Pilih Item yang Disesuaikan:',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: List.generate(targets.length, (idx) {
                          final t = targets[idx];
                          final isSel = selectedTargetIndex == idx;
                          return ChoiceChip(
                            label: Text('${t.label} (${t.currentDurationHours}j)'),
                            selected: isSel,
                            onSelected: (_) => setModalState(() => selectedTargetIndex = idx),
                            selectedColor: AppColors.obsidian,
                            labelStyle: TextStyle(
                              color: isSel ? Colors.white : AppColors.textPrimary,
                              fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Direction Toggle (+ Tambah vs - Kurangi)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => direction = 'increase'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: isIncrease ? AppColors.obsidian : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: isIncrease
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '+ Tambah Jam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isIncrease ? FontWeight.w800 : FontWeight.w600,
                                    color: isIncrease ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: InkWell(
                              onTap: () => setModalState(() => direction = 'decrease'),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                decoration: BoxDecoration(
                                  color: !isIncrease ? AppColors.obsidian : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: !isIncrease
                                      ? const [
                                          BoxShadow(
                                            color: Color(0x18000000),
                                            blurRadius: 4,
                                            offset: Offset(0, 1),
                                          ),
                                        ]
                                      : null,
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  '- Kurangi Jam',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: !isIncrease ? FontWeight.w800 : FontWeight.w600,
                                    color: !isIncrease ? Colors.white : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Duration Options from Model
                    Text(
                      isIncrease
                          ? 'Pilihan Durasi Perpanjangan (Sesuai Tarif Model):'
                          : 'Pilihan Durasi Pengurangan (Sesuai Tarif Model):',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: durationOptions.map((opt) {
                          final isSel = selectedHours == opt.hours;
                          final wouldBePast = !isIncrease &&
                              activeTarget.isPrimary &&
                              currentEndAt != null &&
                              currentEndAt.subtract(Duration(hours: opt.hours)).isBefore(DateTime.now());
                          final wouldBeBelowOne = !isIncrease && (activeTarget.currentDurationHours - opt.hours < 1);
                          final isDisabled = wouldBePast || wouldBeBelowOne;

                          final priceFormatted = CurrencyFormatter.format(opt.price);
                          final chipText = isIncrease
                              ? '${opt.label} • $priceFormatted'
                              : '${opt.label} • -$priceFormatted';

                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(chipText),
                              selected: isSel && !isDisabled,
                              onSelected: isDisabled
                                  ? null
                                  : (_) => setModalState(() => selectedHours = opt.hours),
                              showCheckmark: true,
                              checkmarkColor: isSel && !isDisabled ? Colors.white : AppColors.obsidian,
                              selectedColor: AppColors.obsidian,
                              backgroundColor: AppColors.surface,
                              disabledColor: AppColors.surfaceMuted,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: isSel && !isDisabled
                                      ? AppColors.obsidian
                                      : (isDisabled ? AppColors.borderSubtle : AppColors.border),
                                  width: isSel && !isDisabled ? 1.5 : 1.0,
                                ),
                              ),
                              labelStyle: TextStyle(
                                color: isSel && !isDisabled
                                    ? Colors.white
                                    : (isDisabled ? AppColors.textMuted : AppColors.textPrimary),
                                fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Boundary Warning Banner
                    if (isEndAtInPast) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.danger.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.danger),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Batas waktu baru tidak valid (lewat dari batas waktu saat ini).',
                                style: TextStyle(color: AppColors.danger, fontSize: 11.5, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else if (isBelowMinimumDuration) ...[
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.danger),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.error_outline_rounded, size: 16, color: AppColors.danger),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Durasi sewa tidak dapat dikurangi hingga kurang dari 1 jam.',
                                style: TextStyle(color: AppColors.danger, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Financial & Deadline Preview Box
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  isIncrease ? 'Biaya Tambahan:' : 'Selisih Pengurangan Biaya:',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isIncrease
                                    ? CurrencyFormatter.format(deltaFee.abs())
                                    : '- ${CurrencyFormatter.format(deltaFee.abs())}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: isIncrease ? AppColors.obsidian : AppColors.success,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                          if (newEndAt != null) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1, color: AppColors.borderSubtle),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Batas Waktu Pengembalian Baru:',
                                    style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5, fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  DateFormatter.formatFull(newEndAt),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5, color: AppColors.obsidian),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.borderSubtle),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Expanded(
                                child: Text(
                                  'Estimasi Total Tagihan Baru:',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppColors.obsidian),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                CurrencyFormatter.format(estimatedNewTotal),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.5,
                                  color: AppColors.obsidian,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Overpayment / Refund Notice & PIN Required
                    if (refundDue > 0) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.warning.withOpacity(0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.payments_outlined, size: 18, color: AppColors.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Pengembalian Dana (Refund): ${CurrencyFormatter.format(refundDue)}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppColors.obsidian),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Otorisasi PIN Manager diperlukan untuk pengeluaran kas refund.',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: pinController,
                              obscureText: true,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              onChanged: (_) => setModalState(() {}),
                              decoration: InputDecoration(
                                labelText: 'PIN Manager *',
                                hintText: '6 digit PIN Manager',
                                prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
                                filled: true,
                                fillColor: AppColors.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: const BorderSide(color: AppColors.border),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                counterText: '',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // Reason Input (for decrease)
                    if (!isIncrease) ...[
                      TextField(
                        controller: reasonController,
                        decoration: InputDecoration(
                          labelText: 'Alasan Pengurangan Durasi (Opsional)',
                          hintText: 'mis. Pelanggan selesai lebih awal',
                          prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                          filled: true,
                          fillColor: AppColors.surface,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Buttons
                    if (isIncrease) ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidian,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                Navigator.pop(ctx);
                                final result = await Navigator.push<PaymentResult>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentPage(
                                      paymentContext: PaymentContext.extension(
                                        booking: item,
                                        bookingId: bookingId,
                                        bookingCode: bookingCode,
                                        customerName: customerName,
                                        deviceModel: activeTarget.shortName,
                                        additionalHours: selectedHours,
                                        extensionFee: fee,
                                        extraPayload: activeTarget.itemId != null
                                            ? {'booking_item_id': activeTarget.itemId}
                                            : null,
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
                        child: const Text('Proses pembayaran', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.obsidian,
                          side: const BorderSide(color: AppColors.border, width: 1.2),
                          backgroundColor: AppColors.surface,
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref.read(bookingRepositoryProvider).adjustDuration(
                                    bookingId: bookingId,
                                    bookingItemId: activeTarget.itemId,
                                    direction: 'increase',
                                    hoursDelta: selectedHours,
                                    additionalFee: fee,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  ref.invalidate(bookingsListProvider);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sewa diperpanjang $selectedHours jam (tagihan dicatat).')),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
                                    );
                                  }
                                }
                              },
                        icon: isSubmitting
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.receipt_long_outlined, size: 16, color: AppColors.obsidian),
                        label: const Text(
                          'Perpanjang Tanpa Bayar Langsung (Catat ke Tagihan)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ] else ...[
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canSubmitReduction ? AppColors.obsidian : AppColors.surfaceMuted,
                          foregroundColor: canSubmitReduction ? Colors.white : AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: (!canSubmitReduction || isSubmitting)
                            ? null
                            : () async {
                                setModalState(() => isSubmitting = true);
                                try {
                                  await ref.read(bookingRepositoryProvider).adjustDuration(
                                    bookingId: bookingId,
                                    bookingItemId: activeTarget.itemId,
                                    direction: 'decrease',
                                    hoursDelta: selectedHours,
                                    additionalFee: fee,
                                    managerPin: refundDue > 0 ? pinController.text.trim() : null,
                                    reason: reasonController.text.trim().isNotEmpty
                                        ? reasonController.text.trim()
                                        : null,
                                  );
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  ref.invalidate(bookingsListProvider);
                                  if (context.mounted) {
                                    final refundText = refundDue > 0
                                        ? ' Refund ${CurrencyFormatter.format(refundDue)} dicatat.'
                                        : '';
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Durasi sewa berhasil dikurangi $selectedHours jam.$refundText'),
                                        backgroundColor: AppColors.success,
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  setModalState(() => isSubmitting = false);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Gagal: $e'), backgroundColor: AppColors.danger),
                                    );
                                  }
                                }
                              },
                        child: isSubmitting
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Text('Konfirmasi Pengurangan Durasi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

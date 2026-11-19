import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/business_provider.dart';
import '../../payments/models/payment_context.dart';
import '../../payments/presentation/payment_page.dart';
import '../../cashier/presentation/pos_transaction_detail_sheet.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../providers/booking_provider.dart';
import 'direct_rental_screen.dart';
import 'exchange_history_sheet.dart';
import 'exchange_wizard_screen.dart';
import 'rental_queue_actions.dart';
import 'return_wizard_screen.dart';

int _getBookingPriority(Map<String, dynamic> b, DateTime now) {
  final status = (b['status'] ?? '').toString().toLowerCase();
  final endAt = b['end_at'] != null
      ? DateTime.tryParse(b['end_at'].toString())?.toLocal()
      : null;

  if (status == 'returned' || status == 'completed') return 5; // Completed
  if (status == 'no_show') return 6;
  if (status == 'cancelled') return 7;

  // 3. Awaiting Handover (Booked / Reserved)
  if (status == 'pending' ||
      status == 'confirmed' ||
      status == 'waiting_handover' ||
      status == 'booked' ||
      status == 'reserved') {
    return 3;
  }

  // 1. Overdue active rental first
  if (endAt != null && endAt.isBefore(now)) {
    return 1;
  }
  // 2. Due Today
  if (endAt != null &&
      endAt.year == now.year &&
      endAt.month == now.month &&
      endAt.day == now.day) {
    return 2;
  }
  // 4. Active
  if (status == 'rented' || status == 'active') {
    return 4;
  }
  return 8;
}

IconData _getItemCategoryIcon({
  Map<String, dynamic>? model,
  Map<String, dynamic>? asset,
  Map<String, dynamic>? primaryItem,
}) => RentalQueueActions.getItemCategoryIcon(
  model: model,
  asset: asset,
  primaryItem: primaryItem,
);

class BookingsScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const BookingsScreen({
    super.key,
    this.initialFilter,
  });

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
    if (!_scrollController.hasClients ||
        _isLoadingMoreBookings ||
        !_hasMoreBookings) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 250) {
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
    if (widget.initialFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _resetBookingPagination();
          ref
              .read(bookingFilterStatusProvider.notifier)
              .setFilter(widget.initialFilter);
        }
      });
    }
    final initialQuery = ref.read(bookingSearchQueryProvider);
    if (initialQuery.isNotEmpty) {
      _searchController.text = initialQuery;
    }

    _scrollController.addListener(_onBookingsScroll);
  }

  @override
  void didUpdateWidget(covariant BookingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != null &&
        widget.initialFilter != oldWidget.initialFilter) {
      _resetBookingPagination();
      ref
          .read(bookingFilterStatusProvider.notifier)
          .setFilter(widget.initialFilter);
    }
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
                  ref
                      .read(bookingSearchQueryProvider.notifier)
                      .setQuery(val.trim());
                },
                decoration: InputDecoration(
                  hintText: 'Cari kode booking, nama, telp, atau unit...',
                  hintStyle: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w400,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                    color: Color(0xFF94A3B8),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppColors.obsidian,
                      width: 1.2,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Color(0xFFE2E8F0),
                      width: 1,
                    ),
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
                _buildFilterChip(ref, 'Booking', 'booked', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'Terlambat', 'overdue', currentFilter),
                const SizedBox(width: 8),
                _buildFilterChip(ref, 'No-Show', 'no_show', currentFilter),
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
              loading: () => const SkeletonPulseWrapper(
                child: RentalQueueListSkeleton(
                  count: 5,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
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
                            isSearching
                                ? Icons.search_off_rounded
                                : Icons.inbox_outlined,
                            size: 48,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isSearching
                                ? 'Tidak ditemukan transaksi sewa yang cocok.'
                                : 'Tidak ada data sewa untuk filter ini.',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (isSearching) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Kata kunci: "$currentSearch"',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                                fontSize: 12,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text(
                                'Reset Pencarian',
                                style: TextStyle(fontSize: 12),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.obsidian,
                                side: const BorderSide(color: AppColors.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }

                final combinedBookings = [...bookings, ..._extraBookings];
                final now = DateTime.now();
                combinedBookings.sort((a, b) {
                  final prioA = _getBookingPriority(a, now);
                  final prioB = _getBookingPriority(b, now);
                  if (prioA != prioB) {
                    return prioA.compareTo(prioB);
                  }
                  final endA = a['end_at'] != null
                      ? DateTime.tryParse(a['end_at'].toString())
                      : null;
                  final endB = b['end_at'] != null
                      ? DateTime.tryParse(b['end_at'].toString())
                      : null;
                  if (endA != null && endB != null) {
                    return endA.compareTo(endB);
                  }
                  final idA = int.tryParse(a['id']?.toString() ?? '0') ?? 0;
                  final idB = int.tryParse(b['id']?.toString() ?? '0') ?? 0;
                  return idB.compareTo(idA);
                });

                return RefreshIndicator(
                  onRefresh: () async {
                    _resetBookingPagination();
                    return ref.refresh(bookingsListProvider.future);
                  },
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 4,
                      bottom: 100,
                    ),
                    itemCount:
                        combinedBookings.length +
                        (_isLoadingMoreBookings ? 1 : 0),
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
                          final itemType = itMap['item_type']
                              ?.toString()
                              .toLowerCase();
                          final asset = itMap['asset'] as Map?;
                          final m = asset?['model'] as Map?;
                          final isAddon =
                              itemType == 'addon' ||
                              m?['is_addon'] == true ||
                              m?['is_addon'] == 1;

                          if (isAddon) {
                            addonItems.add(itMap);
                          } else {
                            final isActive =
                                itMap['status'] == 'active' ||
                                itMap['status'] == null;
                            if (isActive && primaryItem == null) {
                              primaryItem = itMap;
                            } else {
                              primaryItem ??= itMap;
                            }
                          }
                        }
                      }

                      // Fallback: If no primary item identified, use first item
                      if (primaryItem == null &&
                          items.isNotEmpty &&
                          items.first is Map) {
                        primaryItem = Map<String, dynamic>.from(
                          items.first as Map,
                        );
                        addonItems.remove(primaryItem);
                      }

                      final activeAsset =
                          (item['primary_asset'] as Map?)
                              ?.cast<String, dynamic>() ??
                          (item['active_asset'] as Map?)
                              ?.cast<String, dynamic>() ??
                          (item['asset_unit'] as Map?)
                              ?.cast<String, dynamic>() ??
                          (primaryItem?['asset'] as Map?)
                              ?.cast<String, dynamic>();
                      final model = activeAsset?['model'] ??
                          item['asset_model'] ??
                          primaryItem?['asset_model'];

                      final statusLower =
                          (item['status'] ?? '').toString().toLowerCase();
                      final startAt = DateFormatter.parseLocal(item['start_at']);
                      final endAt = DateFormatter.parseLocal(item['end_at']);
                      final graceAt = DateFormatter.parseLocal(item['grace_expires_at']);
                      final isReturned = statusLower == 'returned';
                      final isNoShow = statusLower == 'no_show';
                      final isBookedStatus = statusLower == 'booked' ||
                          statusLower == 'reserved' ||
                          statusLower == 'confirmed' ||
                          statusLower == 'waiting_handover';
                      final isFloatingUnit = item['is_floating_unit'] == true ||
                          (isBookedStatus &&
                              item['asset_unit_id'] == null &&
                              activeAsset == null);
                      final isOverduePickup = isBookedStatus &&
                          (item['is_overdue_pickup'] == true ||
                              (graceAt != null &&
                                  graceAt.isBefore(DateTime.now())));
                      final isGraceWarningWindow = isBookedStatus &&
                          !isOverduePickup &&
                          graceAt != null &&
                          graceAt.difference(DateTime.now()).inMinutes <= 15;
                      final paymentStatus = (item['payment_status'] ?? 'paid')
                          .toString()
                          .toLowerCase();
                      final isPaid = paymentStatus == 'paid';
                      final hasUnpaidPenalty =
                          isReturned && paymentStatus != 'paid';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(10),
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
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surfaceMuted,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.borderSubtle,
                                            ),
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
                                          onTap: () =>
                                              ExchangeHistorySheet.show(
                                                context,
                                                item,
                                              ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 3,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.infoLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: AppColors.info
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.swap_horiz_rounded,
                                                  size: 12,
                                                  color: AppColors.info,
                                                ),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'Ditukar (${exchanges.length}x)',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.info,
                                                  ),
                                                ),
                                                const SizedBox(width: 2),
                                                const Icon(
                                                  Icons.info_outline_rounded,
                                                  size: 11,
                                                  color: AppColors.info,
                                                ),
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
                                      ? (hasUnpaidPenalty
                                            ? 'SELESAI (DENDA BELUM LUNAS)'
                                            : 'SELESAI')
                                      : isNoShow
                                      ? 'NO-SHOW'
                                      : isOverduePickup
                                      ? 'Lewat Jadwal Ambil'
                                      : isBookedStatus
                                      ? (graceAt != null
                                            ? 'Batas ambil: ${DateFormatter.formatTime(graceAt)}'
                                            : 'Siap Diambil')
                                      : DateFormatter.formatRelative(endAt),
                                  textColor: hasUnpaidPenalty
                                      ? AppColors.warning
                                      : isReturned
                                      ? AppColors.textSecondary
                                      : isNoShow || isOverduePickup
                                      ? AppColors.danger
                                      : isBookedStatus
                                      ? (isGraceWarningWindow
                                            ? AppColors.warning
                                            : AppColors.info)
                                      : (endAt != null &&
                                            endAt.isBefore(DateTime.now()))
                                      ? AppColors.danger
                                      : AppColors.info,
                                  backgroundColor: hasUnpaidPenalty
                                      ? AppColors.warningLight
                                      : isReturned
                                      ? AppColors.surfaceMuted
                                      : isNoShow || isOverduePickup
                                      ? AppColors.dangerLight
                                      : isBookedStatus
                                      ? (isGraceWarningWindow
                                            ? AppColors.warningLight
                                            : AppColors.infoLight)
                                      : (endAt != null &&
                                            endAt.isBefore(DateTime.now()))
                                      ? AppColors.dangerLight
                                      : AppColors.infoLight,
                                  borderRadius: 12,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                ),
                              ],
                            ),
                            if (isBookedStatus && startAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.event_available_rounded,
                                    size: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      'Jadwal ambil: ${DateFormatter.formatFull(startAt)}',
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
                            ] else if (endAt != null) ...[
                              const SizedBox(height: 4),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  const Icon(
                                    Icons.schedule_rounded,
                                    size: 11,
                                    color: AppColors.textSecondary,
                                  ),
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
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.borderSubtle,
                                    ),
                                  ),
                                  child: Icon(
                                    _getItemCategoryIcon(
                                      model: model is Map
                                          ? Map<String, dynamic>.from(model)
                                          : null,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                      if (isFloatingUnit) ...[
                                        const SizedBox(height: 2),
                                        const Text(
                                          'Floating Unit • Belum Pilih SN',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.textSecondary,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ] else if (activeAsset?['asset_code'] != null ||
                                          activeAsset?['serial_number'] !=
                                              null) ...[
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
                                          const Icon(
                                            Icons.lock_clock_outlined,
                                            size: 14,
                                            color: AppColors.textMuted,
                                          ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.borderSubtle,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.extension_outlined,
                                          size: 14,
                                          color: AppColors.obsidian,
                                        ),
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
                                        final aAsset =
                                            addon['asset'] as Map? ?? {};
                                        final aModel =
                                            aAsset['model'] as Map? ?? {};
                                        final aName =
                                            aModel['name']?.toString() ??
                                            'Aksesoris';
                                        final aCode = aAsset['asset_code']
                                            ?.toString();
                                        final aPrice =
                                            addon['unit_price'] != null
                                            ? CurrencyFormatter.parse(
                                                addon['unit_price'],
                                              )
                                            : 0.0;
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: AppColors.border,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                size: 12,
                                                color: AppColors.success,
                                              ),
                                              const SizedBox(width: 4),
                                              Flexible(
                                                child: Text(
                                                  aCode != null
                                                      ? '$aName ($aCode)'
                                                      : aName,
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (aPrice > 0) ...[
                                                const SizedBox(width: 4),
                                                Text(
                                                  '• ${CurrencyFormatter.format(aPrice)}',
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderSubtle,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      (item['addon_subtotal'] != null &&
                                              CurrencyFormatter.parse(
                                                    item['addon_subtotal'],
                                                  ) >
                                                  0)
                                          ? 'Utama: ${CurrencyFormatter.format(item['primary_subtotal'] ?? 0)} • Add-on: ${CurrencyFormatter.format(item['addon_subtotal'])}'
                                          : 'Total Tagihan',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Builder(
                                    builder: (_) {
                                      final totalBill = CurrencyFormatter.parse(
                                        item['total_bill'] ??
                                            item['total_amount'] ??
                                            0,
                                      );
                                      final paidAmt = CurrencyFormatter.parse(
                                        item['paid_amount'] ?? 0,
                                      );
                                      final remBalance = item['remaining_balance'] != null
                                          ? CurrencyFormatter.parse(item['remaining_balance'])
                                          : (totalBill - paidAmt).clamp(0.0, double.infinity);
                                      final returnInspection =
                                          item['return_inspection'] as Map? ??
                                          item['returnInspection'] as Map? ??
                                          {};
                                      final penaltyDue =
                                          CurrencyFormatter.parse(
                                            returnInspection['total_penalty'],
                                          );
                                      final effectiveTotal =
                                          totalBill + penaltyDue;
                                      if (isBookedStatus && paymentStatus == 'partial') {
                                        return Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.warningLight,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'DP',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                      color: AppColors.warning,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  CurrencyFormatter.format(totalBill),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w800,
                                                    color: AppColors.obsidian,
                                                    letterSpacing: -0.2,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Sisa: ${CurrencyFormatter.format(remBalance)}',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                          ],
                                        );
                                      }
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

                            const SizedBox(height: 14),
                            const Divider(
                              height: 1,
                              color: AppColors.borderSubtle,
                            ),
                            const SizedBox(height: 12),

                            if (isNoShow) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openTransactionDetailSheet(
                                            context,
                                            item,
                                          ),
                                      child: const Text(
                                        'Rincian No-Show',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isBookedStatus) ...[
                              Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openTransactionDetailSheet(
                                            context,
                                            item,
                                          ),
                                      child: const Text(
                                        'Rincian',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    flex: 6,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.obsidian,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () =>
                                          RentalQueueActions.handleHandoverUnit(
                                            context,
                                            ref,
                                            item,
                                          ),
                                      child: const Text(
                                        'Serahkan Unit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 38,
                                    height: 38,
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => RentalQueueActions
                                          .showOverflowActionsSheet(
                                            context,
                                            ref,
                                            item,
                                          ),
                                      child: const Icon(
                                        Icons.more_vert_rounded,
                                        size: 18,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ] else if (isReturned) ...[
                              // Actions for completed / returned rentals
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openTransactionDetailSheet(
                                            context,
                                            item,
                                          ),
                                      child: const Text(
                                        'Rincian',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _printBookingReceipt(
                                        context,
                                        ref,
                                        item,
                                      ),
                                      child: const Text(
                                        'Cetak Struk',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (hasUnpaidPenalty) ...[
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              Colors.deepOrange.shade800,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size.fromHeight(
                                            38,
                                          ),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () =>
                                            _openPosPaymentModal(context, item),
                                        child: const Text(
                                          'Bayar Denda',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ] else ...[
                              // Secondary action row for active rentals: Rincian, Tambah Jam, Ganti Unit
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(34),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _openTransactionDetailSheet(
                                            context,
                                            item,
                                          ),
                                      child: const Text(
                                        'Rincian',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(34),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showExtendDialog(context, ref, item),
                                      child: const Text(
                                        'Tambah Jam',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(34),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      onPressed: () async {
                                        final res = await Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) =>
                                                ExchangeWizardScreen(
                                                  booking: item,
                                                ),
                                          ),
                                        );
                                        if (res != null) {
                                          ref.invalidate(bookingsListProvider);
                                        }
                                      },
                                      child: const Text(
                                        'Ganti Unit',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Primary action row: Bayar (if unpaid), Cetak Struk, Kembalikan
                              Row(
                                children: [
                                  if (!isPaid) ...[
                                    Expanded(
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: AppColors.obsidian,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size.fromHeight(
                                            38,
                                          ),
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          elevation: 0,
                                        ),
                                        onPressed: () =>
                                            _openPosPaymentModal(context, item),
                                        child: const Text(
                                          'Bayar',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        foregroundColor: AppColors.obsidian,
                                        side: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                      onPressed: () => _printBookingReceipt(
                                        context,
                                        ref,
                                        item,
                                      ),
                                      child: const Text(
                                        'Cetak Struk',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: isPaid
                                            ? AppColors.obsidian
                                            : AppColors.surfaceMuted,
                                        foregroundColor: isPaid
                                            ? Colors.white
                                            : AppColors.obsidian,
                                        minimumSize: const Size.fromHeight(38),
                                        padding: EdgeInsets.zero,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          side: isPaid
                                              ? BorderSide.none
                                              : const BorderSide(
                                                  color: AppColors.border,
                                                ),
                                        ),
                                        elevation: 0,
                                      ),
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ReturnWizardScreen(
                                              booking: item,
                                            ),
                                          ),
                                        );
                                      },
                                      child: const Text(
                                        'Kembalikan',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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

  Widget _buildFilterChip(
    WidgetRef ref,
    String label,
    String value,
    String? currentFilter,
  ) {
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
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? AppColors.obsidian : AppColors.border,
        ),
      ),
      showCheckmark: false,
    );
  }

  void _openTransactionDetailSheet(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PosTransactionDetailSheet(
        booking: booking,
        onPaymentRequested: (activeBooking) =>
            _openPosPaymentModal(context, activeBooking),
      ),
    );
  }

  void _openPosPaymentModal(
    BuildContext context,
    Map<String, dynamic> booking,
  ) {
    final returnInspection =
        booking['return_inspection'] as Map? ??
        booking['returnInspection'] as Map? ??
        {};
    final totalPenaltyDue = CurrencyFormatter.parse(
      returnInspection['total_penalty'] ??
          returnInspection['late_fee'] ??
          returnInspection['penalty_amount'] ??
          booking['total_penalty'] ??
          booking['penalty_amount'] ??
          booking['late_fee'] ??
          0,
    );
    final payments = (booking['payments'] as List?) ?? [];
    double penaltyPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      if (p['type']?.toString().toLowerCase() == 'penalty') {
        penaltyPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingPenalty = (totalPenaltyDue - penaltyPaid).clamp(
      0.0,
      double.infinity,
    );

    final totalBill = CurrencyFormatter.parse(booking['total_bill']);
    double rentalPaid = 0.0;
    for (final p in payments) {
      if (p['status']?.toString().toLowerCase() == 'void') continue;
      final pt = p['type']?.toString().toLowerCase();
      if (pt == 'settlement' ||
          pt == 'dp' ||
          pt == 'extension' ||
          pt == 'rental' ||
          pt == 'exchange') {
        rentalPaid += CurrencyFormatter.parse(p['amount']);
      }
    }
    final remainingRental = (totalBill - rentalPaid).clamp(
      0.0,
      double.infinity,
    );

    final isPenaltyTarget = remainingRental <= 0 && remainingPenalty > 0;
    final paymentContext = isPenaltyTarget
        ? PaymentContext.penalty(booking: booking, penaltyDue: remainingPenalty)
        : PaymentContext.settlement(
            booking: booking,
            remainingDue: remainingRental > 0
                ? remainingRental
                : (remainingPenalty > 0 ? remainingPenalty : totalBill),
          );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PaymentPage(
        paymentContext: paymentContext,
        isModal: true,
        onPaymentSuccess: () {
          ref.invalidate(bookingsListProvider);
        },
      ),
    );
  }

  void _printBookingReceipt(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> booking,
  ) async {
    try {
      final payments = (booking['payments'] as List?) ?? [];
      final latestTx = payments.isNotEmpty ? payments.last : null;
      final receiptId =
          latestTx?['receipt_number'] ?? latestTx?['id'] ?? booking['id'];

      final repo = ref.read(cashierRepositoryProvider);
      final receiptData = await repo.fetchReceipt(receiptId);

      if (!context.mounted) return;
      final branchName =
          receiptData['outlet_name'] ??
          booking['affiliate']?['name'] ??
          'RentCore';
      final cashierName = receiptData['cashier_name'] ?? 'Kasir';
      final receiptNum =
          receiptData['receipt_number'] ?? booking['booking_code'] ?? '-';
      final customerName =
          receiptData['customer_name'] ?? booking['customer']?['name'] ?? '-';
      final totalAmt = CurrencyFormatter.parse(
        receiptData['total_amount'] ?? booking['total_bill'],
      );
      final cashRec = CurrencyFormatter.parse(receiptData['cash_received']);
      final cashChg = CurrencyFormatter.parse(receiptData['cash_change']);
      final method = receiptData['payment_method'] ?? 'Tunai';

      final printerService = ThermalPrinterService();
      final printerSettings = ref.read(printerProvider).settings;
      final model = ReceiptDataModel(
        type: ReceiptType.posPayment,
        title: 'STRUK TRANSAKSI SEWA',
        branchName: branchName,
        receiptNumber: receiptNum,
        bookingCode: booking['booking_code']?.toString(),
        customerName: customerName,
        cashierName: cashierName,
        totalAmount: totalAmt,
        paymentMethod: method,
        cashReceived: cashRec,
        cashChange: cashChg,
        transactedAt:
            receiptData['transacted_at']?.toString() ??
            DateTime.now().toString().substring(0, 16),
      );
      final escposBytes = printerService.buildPosPaymentSlipBytes(
        model,
        printerSettings,
      );

      showDialog(
        context: context,
        builder: (ctx) => ThermalReceiptPreviewDialog(
          title: 'Struk Transaksi Sewa',
          branchName: branchName,
          escposBytes: escposBytes,
          content: Column(
            children: [
              const Text(
                'STRUK SEWA CABANG',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text('No: $receiptNum', style: const TextStyle(fontSize: 11)),
              Text(
                'Pelanggan: $customerName',
                style: const TextStyle(fontSize: 11),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    CurrencyFormatter.format(totalAmt),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat struk: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _showExtendDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) {
    _showDurationAdjustmentDialog(context, ref, item);
  }

  void _showDurationAdjustmentDialog(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> item,
  ) {
    RentalQueueActions.showDurationAdjustmentDialog(
      context,
      ref,
      item,
      onRefresh: () => ref.invalidate(bookingsListProvider),
    );
  }
}

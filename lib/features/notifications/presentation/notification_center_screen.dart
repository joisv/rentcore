import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../auth/providers/business_provider.dart';
import '../../bookings/presentation/bookings_screen.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../inventory/presentation/inventory_screen.dart';
import '../../organization/presentation/manage_organization_screen.dart';
import '../../transfers/presentation/transfers_screen.dart';
import '../models/notification_item.dart';
import '../providers/notification_provider.dart';

class NotificationCenterScreen extends ConsumerStatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  ConsumerState<NotificationCenterScreen> createState() => _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends ConsumerState<NotificationCenterScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).fetchNotifications(refresh: true);
    });
  }

  Future<void> _markAllAsRead() async {
    final scaffold = ScaffoldMessenger.of(context);
    final success = await ref.read(notificationProvider.notifier).markAllAsRead();
    if (success && mounted) {
      scaffold.showSnackBar(
        const SnackBar(
          content: Text('Semua pemberitahuan telah ditandai sebagai dibaca.'),
          duration: Duration(seconds: 2),
          backgroundColor: AppColors.obsidian,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        titleSpacing: 4,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF111111)),
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
            ),
            const Expanded(
              child: Text(
                'Notifikasi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.pageHeader,
              ),
            ),
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton(
                onPressed: _markAllAsRead,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF111111),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Tandai Dibaca',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            ),
        ],
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111111),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(53),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCategoryTabs(state),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
            ],
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(notificationProvider.notifier).fetchNotifications(refresh: true),
        color: AppColors.obsidian,
        child: _buildBody(state),
      ),
    );
  }

  Widget _buildCategoryTabs(NotificationState state) {
    final categories = [
      {'key': 'all', 'label': 'Semua'},
      {'key': 'unread', 'label': 'Belum Dibaca'},
      {'key': 'transfer', 'label': 'Mutasi Unit'},
      {'key': 'membership', 'label': 'Organisasi & Staf'},
      {'key': 'rental', 'label': 'Sewa & Unit'},
      {'key': 'cashier', 'label': 'Keuangan'},
    ];

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = state.selectedCategory == cat['key'];

          return FilterChip(
            selected: isSelected,
            label: Text(cat['label']!),
            selectedColor: AppColors.obsidian,
            backgroundColor: AppColors.surfaceMuted,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            side: BorderSide(
              color: isSelected ? AppColors.obsidian : AppColors.border,
            ),
            showCheckmark: false,
            onSelected: (_) {
              ref.read(notificationProvider.notifier).setCategoryFilter(cat['key']!);
            },
          );
        },
      ),
    );
  }

  Widget _buildBody(NotificationState state) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const PhysicalUnitsTabSkeleton(count: 6);
    }

    if (state.errorMessage != null && state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text(
                state.errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(notificationProvider.notifier).fetchNotifications(refresh: true),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.obsidian),
                child: const Text('Coba Lagi', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (state.notifications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceMuted,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 48,
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tidak Ada Pemberitahuan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                state.selectedCategory == 'unread'
                    ? 'Hebat! Semua pemberitahuan sudah dibaca.'
                    : 'Pemberitahuan aktivitas mutasi, sewa, dan tim akan muncul di sini.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Group notifications by date: Hari Ini, Kemarin, Lebih Lama
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <NotificationItem>[];
    final yesterdayItems = <NotificationItem>[];
    final olderItems = <NotificationItem>[];

    for (final item in state.notifications) {
      final itemDate = DateTime(item.createdAt.year, item.createdAt.month, item.createdAt.day);
      if (itemDate.isAtSameMomentAs(today)) {
        todayItems.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        yesterdayItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 40),
      children: [
        if (todayItems.isNotEmpty) ...[
          _buildDateHeader('Hari Ini'),
          ...todayItems.map(_buildNotificationRow),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          _buildDateHeader('Kemarin'),
          ...yesterdayItems.map(_buildNotificationRow),
        ],
        if (olderItems.isNotEmpty) ...[
          _buildDateHeader('Lebih Lama'),
          ...olderItems.map(_buildNotificationRow),
        ],
      ],
    );
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNotificationRow(NotificationItem item) {
    final isUnread = !item.isRead;
    final categoryIcon = _getCategoryIcon(item.category, item.type);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () {
              if (!item.isRead) {
                ref.read(notificationProvider.notifier).markAsRead(item.id);
              }
              _handleAction(item);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      categoryIcon,
                      size: 20,
                      color: const Color(0xFF111111),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: item.title,
                                  style: TextStyle(
                                    fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                                    fontSize: 13.5,
                                    color: const Color(0xFF111111),
                                    height: 1.3,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: ' • ${item.timeAgo}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w400,
                                        fontSize: 12,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 8),
                              Container(
                                margin: const EdgeInsets.only(top: 5),
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF111111),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.body,
                          style: TextStyle(
                            fontSize: 13,
                            color: isUnread
                                ? const Color(0xFF1F2937)
                                : const Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                        if (_hasAction(item)) ...[
                          const SizedBox(height: 8),
                          Text(
                            '${_getActionLabel(item)} ›',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111111),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
      ],
    );
  }

  IconData _getCategoryIcon(String category, [String? type]) {
    if (type == 'rental.overdue') {
      return Icons.alarm_on_rounded;
    }
    if (type == 'booking.grace_warning') {
      return Icons.schedule_rounded;
    }
    if (type == 'booking.auto_noshow') {
      return Icons.person_off_outlined;
    }
    if (type == 'inventory.low_stock') {
      return Icons.warning_amber_rounded;
    }

    switch (category) {
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'membership':
        return Icons.badge_outlined;
      case 'rental':
        return Icons.assignment_outlined;
      case 'cashier':
        return Icons.point_of_sale_rounded;
      case 'inventory':
        return Icons.inventory_2_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  bool _hasAction(NotificationItem item) {
    return item.actionRoute != null ||
        item.type == 'rental.overdue' ||
        item.type == 'booking.grace_warning' ||
        item.type == 'booking.auto_noshow' ||
        item.type == 'inventory.low_stock' ||
        item.category == 'transfer' ||
        item.category == 'membership' ||
        item.category == 'rental' ||
        item.category == 'inventory';
  }

  String _getActionLabel(NotificationItem item) {
    if (item.type == 'rental.overdue') {
      return 'Proses Pengembalian / Antrean';
    } else if (item.type == 'booking.grace_warning') {
      return 'Serahkan Unit / Cek Booking';
    } else if (item.type == 'booking.auto_noshow') {
      return 'Lihat Antrean No-Show';
    } else if (item.type == 'inventory.low_stock') {
      return 'Cek Stok Unit Siap';
    } else if (item.category == 'transfer') {
      return 'Lihat Mutasi Unit';
    } else if (item.category == 'membership') {
      return 'Tinjau Organisasi';
    } else if (item.category == 'rental') {
      return 'Lihat Antrean Sewa';
    } else if (item.category == 'inventory') {
      return 'Lihat Inventaris Unit';
    }
    return 'Buka Detail';
  }

  void _handleAction(NotificationItem item) {
    if (item.type == 'rental.overdue' ||
        item.type == 'booking.grace_warning' ||
        item.type == 'booking.auto_noshow' ||
        item.category == 'rental' ||
        item.actionRoute == '/bookings') {
      final bookingCode = item.actionPayload?['booking_code']?.toString();
      if (bookingCode != null && bookingCode.isNotEmpty) {
        ref.read(bookingFilterStatusProvider.notifier).setFilter('all');
        ref.read(bookingSearchQueryProvider.notifier).setQuery(bookingCode);
      }
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BookingsScreen()),
      );
    } else if (item.type == 'inventory.low_stock' || item.category == 'inventory' || item.actionRoute == '/inventory') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const InventoryScreen(initialStatusFilter: 'ready'),
        ),
      );
    } else if (item.category == 'transfer') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const TransfersScreen()),
      );
    } else if (item.category == 'membership') {
      final biz = ref.read(businessProvider).currentBusiness;
      if (biz != null && biz['id'] != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ManageOrganizationScreen(
              businessId: biz['id'] as int,
              businessName: biz['name']?.toString() ?? 'Bisnis Rental',
            ),
          ),
        );
      }
    }
  }
}

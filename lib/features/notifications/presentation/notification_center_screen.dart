import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            const Text(
              'Pusat Pemberitahuan',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            if (state.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${state.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (state.unreadCount > 0)
            TextButton.icon(
              onPressed: () async {
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
              },
              icon: const Icon(Icons.done_all_rounded, size: 18, color: AppColors.obsidian),
              label: const Text(
                'Tandai Dibaca',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.obsidian),
              ),
            ),
        ],
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _buildCategoryTabs(state),
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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.obsidian),
      );
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        if (todayItems.isNotEmpty) ...[
          _buildDateHeader('Hari Ini'),
          ...todayItems.map((item) => _buildNotificationCard(item)),
        ],
        if (yesterdayItems.isNotEmpty) ...[
          _buildDateHeader('Kemarin'),
          ...yesterdayItems.map((item) => _buildNotificationCard(item)),
        ],
        if (olderItems.isNotEmpty) ...[
          _buildDateHeader('Lebih Lama'),
          ...olderItems.map((item) => _buildNotificationCard(item)),
        ],
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildDateHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8, left: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: AppColors.textMuted,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final isUnread = !item.isRead;
    final categoryDetails = _getCategoryDetails(item.category, item.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isUnread ? Colors.white : AppColors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isUnread ? (categoryDetails['color'] as Color).withValues(alpha: 0.4) : AppColors.border,
          width: isUnread ? 1.5 : 1.0,
        ),
        boxShadow: isUnread
            ? [
                BoxShadow(
                  color: (categoryDetails['color'] as Color).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (!item.isRead) {
            ref.read(notificationProvider.notifier).markAsRead(item.id);
          }
          _handleAction(item);
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Icon Avatar
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: (categoryDetails['color'] as Color).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      categoryDetails['icon'] as IconData,
                      size: 20,
                      color: categoryDetails['color'] as Color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title & Timestamp
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.title,
                                style: TextStyle(
                                  fontWeight: isUnread ? FontWeight.w800 : FontWeight.w700,
                                  fontSize: 13,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                            if (isUnread) ...[
                              const SizedBox(width: 6),
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.info,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.timeAgo,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Body message
              Padding(
                padding: const EdgeInsets.only(left: 48),
                child: Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnread ? AppColors.textPrimary : AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              // Action Button if applicable
              if (_hasAction(item)) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.only(left: 48),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: categoryDetails['color'] as Color,
                        side: BorderSide(color: (categoryDetails['color'] as Color).withValues(alpha: 0.5)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (!item.isRead) {
                          ref.read(notificationProvider.notifier).markAsRead(item.id);
                        }
                        _handleAction(item);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getActionLabel(item),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_rounded, size: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryDetails(String category, [String? type]) {
    if (type == 'rental.overdue') {
      return {
        'icon': Icons.alarm_on_rounded,
        'color': const Color(0xFFE11D48), // Rose Red
      };
    }
    if (type == 'inventory.low_stock') {
      return {
        'icon': Icons.warning_amber_rounded,
        'color': const Color(0xFFD97706), // Amber
      };
    }

    switch (category) {
      case 'transfer':
        return {
          'icon': Icons.swap_horiz_rounded,
          'color': const Color(0xFF0284C7), // Sky Blue
        };
      case 'membership':
        return {
          'icon': Icons.badge_outlined,
          'color': const Color(0xFFD97706), // Amber
        };
      case 'rental':
        return {
          'icon': Icons.assignment_outlined,
          'color': const Color(0xFF6366F1), // Indigo
        };
      case 'cashier':
        return {
          'icon': Icons.point_of_sale_rounded,
          'color': const Color(0xFF059669), // Emerald
        };
      case 'inventory':
        return {
          'icon': Icons.inventory_2_outlined,
          'color': const Color(0xFF0D9488), // Teal
        };
      default:
        return {
          'icon': Icons.notifications_outlined,
          'color': AppColors.obsidian,
        };
    }
  }

  bool _hasAction(NotificationItem item) {
    return item.actionRoute != null ||
        item.type == 'rental.overdue' ||
        item.type == 'inventory.low_stock' ||
        item.category == 'transfer' ||
        item.category == 'membership' ||
        item.category == 'rental' ||
        item.category == 'inventory';
  }

  String _getActionLabel(NotificationItem item) {
    if (item.type == 'rental.overdue') {
      return 'Proses Pengembalian / Antrean';
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
    if (item.type == 'rental.overdue' || item.category == 'rental' || item.actionRoute == '/bookings') {
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

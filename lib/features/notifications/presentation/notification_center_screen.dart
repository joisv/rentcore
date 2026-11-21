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
                        if (_isInteractiveResignationNotification(item))
                          _buildResignationNotificationActions(item)
                        else if (_hasAction(item)) ...[
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

  bool _isInteractiveResignationNotification(NotificationItem item) {
    final isResignType = item.type == 'staff.resignation_submitted' ||
        item.type == 'resignation_request';
    if (!isResignType) return false;
    final payload = item.actionPayload;
    if (payload == null) return false;
    return (payload['resignation_request_id'] ?? payload['resignation_id']) != null;
  }

  int? _extractResignationId(NotificationItem item) {
    final raw = item.actionPayload?['resignation_request_id'] ??
        item.actionPayload?['resignation_id'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Widget _buildResignationNotificationActions(NotificationItem item) {
    final payload = item.actionPayload ?? const <String, dynamic>{};
    final staffName = payload['staff_name']?.toString();
    final branchName = payload['branch_name']?.toString();
    final reason = payload['reason']?.toString();
    final status = (payload['status']?.toString() ?? 'pending').toLowerCase();
    final resignationId = _extractResignationId(item);
    final isProcessing =
        ref.watch(notificationProvider).processingNotificationId == item.id;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((staffName != null && staffName.isNotEmpty) ||
              (branchName != null && branchName.isNotEmpty) ||
              (reason != null && reason.isNotEmpty))
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (staffName != null && staffName.isNotEmpty)
                    Text(
                      'Staf: $staffName${branchName != null && branchName.isNotEmpty ? ' • $branchName' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF111111),
                      ),
                    ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Alasan: "$reason"',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B5563),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (status == 'pending' && resignationId != null)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _promptRejectResignation(item, resignationId),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: AppColors.danger),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Tolak',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: isProcessing
                        ? null
                        : () => _confirmApproveResignation(item, resignationId),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Setujui',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: status == 'approved'
                    ? const Color(0xFFDCFCE7)
                    : const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                status == 'approved' ? 'Disetujui' : 'Ditolak',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: status == 'approved'
                      ? const Color(0xFF166534)
                      : const Color(0xFF991B1B),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _confirmApproveResignation(NotificationItem item, int resignationId) {
    final staffName = item.actionPayload?['staff_name']?.toString() ?? 'staf ini';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Setujui Pengajuan Resign?',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Text(
          'Menyetujui resign $staffName akan menonaktifkan keanggotaan dan seluruh akses cabangnya secara permanen.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final notifier = ref.read(notificationProvider.notifier);
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(ctx);
              final err = await notifier.approveResignationNotification(
                resignationRequestId: resignationId,
                notificationId: item.id,
              );
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    err ?? 'Permohonan resign disetujui. Akses staf telah dicabut.',
                  ),
                  backgroundColor: err == null ? AppColors.success : AppColors.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Setujui', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _promptRejectResignation(NotificationItem item, int resignationId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Tolak Pengajuan Resign',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: TextField(
          controller: reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Alasan Penolakan (Opsional)',
            hintText: 'Contoh: Masih dibutuhkan untuk periode akhir pekan...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Batal',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final notifier = ref.read(notificationProvider.notifier);
              final messenger = ScaffoldMessenger.of(context);
              final reason = reasonController.text.trim();
              Navigator.pop(ctx);
              final err = await notifier.rejectResignationNotification(
                resignationRequestId: resignationId,
                notificationId: item.id,
                rejectionReason: reason.isNotEmpty ? reason : null,
              );
              if (!mounted) return;
              messenger.showSnackBar(
                SnackBar(
                  content: Text(err ?? 'Permohonan resign ditolak.'),
                  backgroundColor: err == null ? AppColors.obsidian : AppColors.danger,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tolak', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
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
              businessName: (biz['name']?.toString().trim().isNotEmpty == true)
                  ? biz['name'].toString().trim()
                  : 'Usaha Rental',
            ),
          ),
        );
      }
    }
  }
}

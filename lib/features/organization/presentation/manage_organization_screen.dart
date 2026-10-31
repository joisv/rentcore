import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../providers/organization_provider.dart';

class ManageOrganizationScreen extends ConsumerStatefulWidget {
  final int businessId;
  final String businessName;

  const ManageOrganizationScreen({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  @override
  ConsumerState<ManageOrganizationScreen> createState() => _ManageOrganizationScreenState();
}

class _ManageOrganizationScreenState extends ConsumerState<ManageOrganizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(organizationProvider.notifier).loadOrganization(
            widget.businessId,
            businessName: widget.businessName,
          );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openAddBranchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBranchBottomSheet(businessId: widget.businessId),
    );
  }

  void _openInviteMemberSheet(BuildContext context, List<dynamic> branches) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _InviteMemberBottomSheet(
        businessId: widget.businessId,
        branches: branches,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(organizationProvider);
    final isOwnerOrAdmin = orgState.isOwnerOrAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RentCoreAppBar(
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName,
              style: const TextStyle(
                color: AppColors.obsidian,
                fontWeight: FontWeight.w800,
                fontSize: 17,
                letterSpacing: -0.3,
              ),
            ),
            const Text(
              'Kelola Cabang & Tim',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.obsidian),
            tooltip: 'Segarkan',
            onPressed: () => ref.read(organizationProvider.notifier).refresh(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.obsidian,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.obsidian,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(
              icon: const Icon(Icons.storefront_outlined, size: 20),
              text: 'Cabang (${orgState.branches.length})',
            ),
            Tab(
              icon: const Icon(Icons.group_outlined, size: 20),
              text: 'Tim & Staf (${orgState.members.length})',
            ),
            const Tab(
              icon: Icon(Icons.policy_outlined, size: 20),
              text: 'Kebijakan Sewa',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // If restricted staff: show view-only notice
          if (!isOwnerOrAdmin && !orgState.isLoading)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.warning, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode Lihat: Penambahan cabang, staf, dan perubahan kebijakan hanya dapat dilakukan oleh Owner atau Admin.',
                      style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),

          // Main Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBranchesTab(orgState),
                _buildMembersTab(orgState),
                _RentalRulesTabView(
                  businessId: widget.businessId,
                  initialRules: orgState.rentalRules,
                  isOwnerOrAdmin: isOwnerOrAdmin,
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: isOwnerOrAdmin
          ? AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                if (_tabController.index == 2) {
                  return const SizedBox.shrink();
                }
                final isBranchesTab = _tabController.index == 0;
                return FloatingActionButton.extended(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  icon: Icon(isBranchesTab ? Icons.add_business_rounded : Icons.person_add_alt_1_rounded),
                  label: Text(isBranchesTab ? 'Tambah Cabang' : 'Undang Staf'),
                  onPressed: () {
                    if (isBranchesTab) {
                      _openAddBranchSheet(context);
                    } else {
                      _openInviteMemberSheet(context, orgState.branches);
                    }
                  },
                );
              },
            )
          : null,
    );
  }

  // --- TAB 1: Cabang & Outlets ---
  Widget _buildBranchesTab(OrganizationState state) {
    if (state.isLoading && state.branches.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.obsidian));
    }

    if (state.error != null && state.branches.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.branches.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.store_mall_directory_outlined, size: 54, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Cabang Terdaftar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tambahkan cabang atau outlet fisik untuk mulai mendistribusikan inventaris gadget.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.obsidian,
      onRefresh: () => ref.read(organizationProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: state.branches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final branch = state.branches[index] as Map<String, dynamic>;
          final isCentral = branch['is_central'] == true;
          final code = branch['code'] ?? '';
          final name = branch['name'] ?? '';
          final city = branch['city'];
          final address = branch['address'];
          final phone = branch['phone'];

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isCentral ? AppColors.obsidian : AppColors.border,
                width: isCentral ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isCentral ? AppColors.obsidian : AppColors.surfaceMuted,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isCentral ? Icons.stars_rounded : Icons.store_rounded,
                        color: isCentral ? Colors.white : AppColors.obsidian,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMuted,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (city != null && city.toString().isNotEmpty)
                            Text(
                              city.toString(),
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                        ],
                      ),
                    ),
                    if (isCentral)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'PUSAT',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                if ((address != null && address.toString().isNotEmpty) ||
                    (phone != null && phone.toString().isNotEmpty)) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.border),
                  const SizedBox(height: 10),
                  if (address != null && address.toString().isNotEmpty)
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            address.toString(),
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  if (phone != null && phone.toString().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(
                          phone.toString(),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: Tim & Staf ---
  Widget _buildMembersTab(OrganizationState state) {
    if (state.isLoading && state.members.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: AppColors.obsidian));
    }

    if (state.error != null && state.members.isEmpty) {
      return _buildErrorState(state.error!);
    }

    if (state.members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.group_off_outlined, size: 54, color: AppColors.textMuted),
              const SizedBox(height: 16),
              const Text(
                'Belum Ada Anggota Tim',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Undang kasir atau administrator bisnis Anda untuk mulai mengoperasikan counter rental.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.obsidian,
      onRefresh: () => ref.read(organizationProvider.notifier).refresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
        itemCount: state.members.length + (state.isOwnerOrAdmin && state.pendingResignations.isNotEmpty ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (state.isOwnerOrAdmin && state.pendingResignations.isNotEmpty && index == 0) {
            return _buildPendingResignationBanner(context, state);
          }
          final memberIndex = (state.isOwnerOrAdmin && state.pendingResignations.isNotEmpty) ? index - 1 : index;
          final member = state.members[memberIndex] as Map<String, dynamic>;
          final user = (member['user'] as Map<String, dynamic>?) ?? {};
          final role = (member['role'] ?? 'staff').toString();
          final name = user['name'] ?? 'Pengguna';
          final email = user['email'] ?? '';
          final branchMembers = (member['branch_members'] as List<dynamic>?) ?? [];
          final pendingResignation = state.pendingResignations.where((r) => r['user_id'] == user['id']).firstOrNull as Map<String, dynamic>?;

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: pendingResignation != null ? const Color(0xFFF59E0B) : AppColors.border,
                width: pendingResignation != null ? 1.5 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: pendingResignation != null ? const Color(0xFFD97706) : AppColors.obsidian,
                      child: Text(
                        (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _buildRoleBadge(role),
                    if (pendingResignation != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFF59E0B)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.hourglass_top_rounded, size: 10, color: Color(0xFFB45309)),
                            SizedBox(width: 3),
                            Text(
                              'Resign',
                              style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (state.isOwnerOrAdmin && role.toLowerCase() != 'owner') ...[
                      const SizedBox(width: 4),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColors.textSecondary),
                        padding: EdgeInsets.zero,
                        onSelected: (val) {
                          if (val == 'review_resignation') {
                            _showReviewResignationDialog(context, pendingResignation!, member);
                          } else if (val == 'reassign') {
                            _showReassignBranchDialog(context, member, state.branches);
                          } else if (val == 'pin') {
                            _showSetManagerPinDialog(context, member);
                          } else if (val == 'deactivate') {
                            _confirmDeactivateMember(context, member);
                          }
                        },
                        itemBuilder: (ctx) => [
                          if (pendingResignation != null)
                            const PopupMenuItem(
                              value: 'review_resignation',
                              child: Row(
                                children: [
                                  Icon(Icons.assignment_ind_outlined, size: 18, color: Color(0xFFD97706)),
                                  SizedBox(width: 8),
                                  Text('Tinjau Resign', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF92400E))),
                                ],
                              ),
                            ),
                          const PopupMenuItem(
                            value: 'reassign',
                            child: Row(
                              children: [
                                Icon(Icons.swap_horiz_rounded, size: 18, color: AppColors.obsidian),
                                SizedBox(width: 8),
                                Text('Pindah Cabang', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'pin',
                            child: Row(
                              children: [
                                Icon(Icons.pin_rounded, size: 18, color: AppColors.obsidian),
                                SizedBox(width: 8),
                                Text('Atur PIN Manager', style: TextStyle(fontSize: 13)),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'deactivate',
                            child: Row(
                              children: [
                                Icon(Icons.person_remove_rounded, size: 18, color: AppColors.danger),
                                SizedBox(width: 8),
                                Text('Nonaktifkan', style: TextStyle(fontSize: 13, color: AppColors.danger)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_city_rounded, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _formatAssignedBranches(role, branchMembers),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRoleBadge(String role) {
    Color badgeColor;
    String label;

    switch (role.toLowerCase()) {
      case 'owner':
        badgeColor = Colors.purple;
        label = 'OWNER';
        break;
      case 'admin':
        badgeColor = AppColors.info;
        label = 'ADMIN';
        break;
      default:
        badgeColor = AppColors.success;
        label = 'STAFF';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: badgeColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  String _formatAssignedBranches(String role, List<dynamic> branchMembers) {
    if (role.toLowerCase() == 'owner' || role.toLowerCase() == 'admin') {
      return 'Akses Penuh (Semua Cabang)';
    }

    if (branchMembers.isEmpty) {
      return 'Belum Ditugaskan ke Cabang Tertentu';
    }

    final branchNames = branchMembers.map((bm) {
      final b = (bm as Map<String, dynamic>)['branch'];
      return b != null ? (b['name'] ?? '') : '';
    }).where((n) => n.isNotEmpty).toList();

    return 'Ditugaskan di: ${branchNames.join(', ')}';
  }

  Widget _buildPendingResignationBanner(BuildContext context, OrganizationState state) {
    final count = state.pendingResignations.length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notification_important_rounded, color: Color(0xFFB45309), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Permohonan Resign Menunggu Peninjauan',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF92400E)),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Tinjau dan proses permohonan pengunduran diri staf.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final first = state.pendingResignations.first as Map<String, dynamic>;
              final member = state.members.where((m) => m['id'] == first['business_member_id']).firstOrNull as Map<String, dynamic>?;
              _showReviewResignationDialog(context, first, member ?? {});
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Tinjau', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  void _showReviewResignationDialog(
    BuildContext context,
    Map<String, dynamic> resignation,
    Map<String, dynamic> member,
  ) {
    final user = (member['user'] as Map<String, dynamic>?) ?? (resignation['user'] as Map<String, dynamic>?) ?? {};
    final name = user['name'] ?? 'Staf';
    final email = user['email'] ?? '';
    final reason = resignation['reason'] ?? 'Tidak ada alasan dicantumkan.';
    final decisionNotesController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.assignment_late_outlined, color: Color(0xFFB45309), size: 20),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Tinjau Permohonan Resign',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(email, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    const Text('Alasan Pengunduran Diri:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text('"$reason"', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: decisionNotesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan Keputusan (Opsional)',
                  hintText: 'Pesan untuk staf...',
                  hintStyle: const TextStyle(fontSize: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Menyetujui resign akan mencabut seluruh akses cabang staf ini secara permanen. '
                'Riwayat transaksi terdahulu tetap tersimpan.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.35),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(organizationProvider.notifier).reviewResignation(
                    resignation['id'] as int,
                    approve: false,
                    decisionNotes: decisionNotesController.text.trim(),
                  );
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Permohonan resign ditolak.'), backgroundColor: AppColors.obsidian),
                  );
                } else {
                  final err = ref.read(organizationProvider).error ?? 'Gagal memproses permohonan.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Tolak'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _confirmApproveResignation(context, resignation['id'] as int, name, decisionNotesController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Setujui Resign', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmApproveResignation(BuildContext context, int requestId, String staffName, String decisionNotes) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 22),
            SizedBox(width: 8),
            Text('Konfirmasi Persetujuan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menyetujui pengunduran diri $staffName? '
          'Akses staf ke seluruh cabang rental akan langsung dicabut seketika.',
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(organizationProvider.notifier).reviewResignation(
                    requestId,
                    approve: true,
                    decisionNotes: decisionNotes,
                  );
              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Pengunduran diri $staffName telah disetujui.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  final err = ref.read(organizationProvider).error ?? 'Gagal menyetujui pengunduran diri.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('Ya, Setujui & Cabut Akses', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showReassignBranchDialog(
    BuildContext context,
    Map<String, dynamic> member,
    List<dynamic> branches,
  ) {
    final memberId = member['id'] as int;
    final user = (member['user'] as Map<String, dynamic>?) ?? {};
    final name = user['name'] ?? 'Staf';
    final branchMembers = (member['branch_members'] as List<dynamic>?) ?? [];
    final currentBranchId = branchMembers.isNotEmpty
        ? (branchMembers.first as Map<String, dynamic>)['affiliate_id'] as int?
        : null;

    int? selectedToBranchId;
    final reasonController = TextEditingController();

    // Available target branches (filter out current branch)
    final availableBranches = branches.where((b) {
      final bId = b['id'] as int?;
      return bId != null && bId != currentBranchId;
    }).toList();

    if (availableBranches.isNotEmpty) {
      selectedToBranchId = availableBranches.first['id'] as int;
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.swap_horiz_rounded, color: AppColors.obsidian),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Pindah Cabang: $name',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Pilih cabang tujuan baru untuk staf ini:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              if (availableBranches.isEmpty)
                const Text(
                  'Tidak ada cabang lain yang tersedia di bisnis ini.',
                  style: TextStyle(color: AppColors.danger, fontSize: 13),
                )
              else
                DropdownButtonFormField<int>(
                  value: selectedToBranchId,
                  decoration: InputDecoration(
                    labelText: 'Cabang Tujuan',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  items: availableBranches.map((b) {
                    final bId = b['id'] as int;
                    final bName = b['name'] ?? 'Cabang #$bId';
                    final bCode = b['code'] ?? '';
                    return DropdownMenuItem<int>(
                      value: bId,
                      child: Text('$bName ($bCode)'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedToBranchId = val);
                  },
                ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: 'Alasan Pemindahan (Opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
              ),
              onPressed: selectedToBranchId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      final success = await ref
                          .read(organizationProvider.notifier)
                          .reassignMemberBranch(
                            memberId: memberId,
                            fromBranchId: currentBranchId,
                            toBranchId: selectedToBranchId!,
                            reason: reasonController.text.trim(),
                          );

                      if (context.mounted) {
                        final orgState = ref.read(organizationProvider);
                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Penugasan $name berhasil dipindahkan.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        } else if (orgState.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(orgState.error!),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
              child: const Text('Pindahkan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSetManagerPinDialog(BuildContext context, Map<String, dynamic> member) {
    final memberId = member['id'] as int;
    final user = (member['user'] as Map<String, dynamic>?) ?? {};
    final name = user['name'] ?? 'Staf';
    final pinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.pin_rounded, color: AppColors.obsidian),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Atur PIN Manager: $name',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'PIN Manager digunakan untuk otorisasi pengeluaran kas di atas ambang batas dan pembatalan transaksi.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'PIN 6-Digit Angka',
                hintText: 'Contoh: 123456',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(organizationProvider.notifier)
                  .revokeManagerPin(memberId);
              if (context.mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('PIN Manager $name berhasil dicabut.')),
                );
              }
            },
            child: const Text('Cabut PIN'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.length != 6 || int.tryParse(pin) == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN harus berupa 6 digit angka.'),
                    backgroundColor: AppColors.danger,
                  ),
                );
                return;
              }
              Navigator.pop(ctx);
              final success = await ref
                  .read(organizationProvider.notifier)
                  .setManagerPin(memberId: memberId, pin: pin);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('PIN Manager $name berhasil disimpan.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  final err = ref.read(organizationProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? 'Gagal menyimpan PIN.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Simpan PIN'),
          ),
        ],
      ),
    );
  }

  void _confirmDeactivateMember(BuildContext context, Map<String, dynamic> member) {
    final memberId = member['id'] as int;
    final user = (member['user'] as Map<String, dynamic>?) ?? {};
    final name = user['name'] ?? 'Staf';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.danger),
            SizedBox(width: 10),
            Text('Nonaktifkan Staf?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menonaktifkan $name dari bisnis ini? '
          'Staf tidak akan dapat mengakses data bisnis lagi. Riwayat transaksi sebelumnya tetap tersimpan aman.',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref
                  .read(organizationProvider.notifier)
                  .removeMember(memberId);

              if (context.mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$name berhasil dinonaktifkan.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  final err = ref.read(organizationProvider).error;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err ?? 'Gagal menonaktifkan staf.'),
                      backgroundColor: AppColors.danger,
                    ),
                  );
                }
              }
            },
            child: const Text('Nonaktifkan'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.read(organizationProvider.notifier).refresh(),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL BOTTOM SHEET: TAMBAH CABANG
// =============================================================================
class _AddBranchBottomSheet extends ConsumerStatefulWidget {
  final int businessId;

  const _AddBranchBottomSheet({required this.businessId});

  @override
  ConsumerState<_AddBranchBottomSheet> createState() => _AddBranchBottomSheetState();
}

class _AddBranchBottomSheetState extends ConsumerState<_AddBranchBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _codeController = TextEditingController();
  final _cityController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _cityController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final success = await ref.read(organizationProvider.notifier).createBranch(
          name: _nameController.text.trim(),
          code: _codeController.text.trim().toUpperCase(),
          city: _cityController.text.trim().isNotEmpty ? _cityController.text.trim() : null,
          address: _addressController.text.trim().isNotEmpty ? _addressController.text.trim() : null,
          phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cabang baru berhasil ditambahkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final err = ref.read(organizationProvider).error ?? 'Gagal menambahkan cabang.';
        setState(() => _errorMessage = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(organizationProvider).isSubmitting;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Tambah Cabang / Outlet Baru',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Cabang *',
                  hintText: 'Contoh: SkyRental Canggu',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama cabang wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _codeController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Kode Cabang (Singkatan 2-10 Karakter) *',
                  hintText: 'Contoh: CGU',
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Kode cabang wajib diisi';
                  if (val.trim().length < 2 || val.trim().length > 10) {
                    return 'Kode harus terdiri dari 2 hingga 10 karakter';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(
                  labelText: 'Kota / Wilayah',
                  hintText: 'Contoh: Badung, Bali',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  hintText: 'Contoh: Jl. Pantai Batu Bolong No. 12',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon / WhatsApp Cabang',
                  hintText: 'Contoh: 081234567890',
                ),
              ),
              const SizedBox(height: 22),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Simpan Cabang Baru',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// MODAL BOTTOM SHEET: UNDANG STAF / ANGGOTA TIM
// =============================================================================
class _InviteMemberBottomSheet extends ConsumerStatefulWidget {
  final int businessId;
  final List<dynamic> branches;

  const _InviteMemberBottomSheet({
    required this.businessId,
    required this.branches,
  });

  @override
  ConsumerState<_InviteMemberBottomSheet> createState() => _InviteMemberBottomSheetState();
}

class _InviteMemberBottomSheetState extends ConsumerState<_InviteMemberBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedRole = 'staff';
  final Set<int> _selectedBranchIds = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Default: select all existing branches
    for (final b in widget.branches) {
      if (b['id'] != null) {
        _selectedBranchIds.add(b['id'] as int);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _errorMessage = null);

    final success = await ref.read(organizationProvider.notifier).inviteMember(
          email: _emailController.text.trim().toLowerCase(),
          name: _nameController.text.trim().isNotEmpty ? _nameController.text.trim() : null,
          role: _selectedRole,
          branchIds: _selectedRole == 'staff' ? _selectedBranchIds.toList() : null,
        );

    if (mounted) {
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staf berhasil diundang ke bisnis rental!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final err = ref.read(organizationProvider).error ?? 'Gagal mengundang staf.';
        setState(() => _errorMessage = err);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = ref.watch(organizationProvider).isSubmitting;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.person_add_alt_1_rounded, color: AppColors.obsidian, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Undang Anggota / Staf Baru',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Akun Google Staf *',
                  hintText: 'staf@gmail.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Email wajib diisi';
                  if (!val.contains('@') || !val.contains('.')) return 'Format email tidak valid';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Lengkap (Opsional)',
                  hintText: 'Contoh: Budi Santoso',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 16),

              // Role Selection
              const Text(
                'Peran & Hak Akses',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildRoleChoice(
                      role: 'staff',
                      title: 'Staff Kasir',
                      subtitle: 'Operasional & rental',
                      icon: Icons.point_of_sale_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildRoleChoice(
                      role: 'admin',
                      title: 'Admin Bisnis',
                      subtitle: 'Katalog & inventaris',
                      icon: Icons.admin_panel_settings_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Branch Assignment Checklist (only if staff)
              if (_selectedRole == 'staff' && widget.branches.isNotEmpty) ...[
                const Text(
                  'Penugasan Cabang Operasional',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: widget.branches.map((b) {
                      final bId = b['id'] as int;
                      final bName = b['name'] ?? '';
                      final isSelected = _selectedBranchIds.contains(bId);

                      return CheckboxListTile(
                        dense: true,
                        activeColor: AppColors.obsidian,
                        title: Text(
                          bName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        value: isSelected,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedBranchIds.add(bId);
                            } else {
                              _selectedBranchIds.remove(bId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
              ],

              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: isSubmitting ? null : _submit,
                child: isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Kirim Undangan Staf',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleChoice({
    required String role,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;

    return InkWell(
      onTap: () => setState(() => _selectedRole = role),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.obsidian : AppColors.surfaceMuted,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.obsidian : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: isSelected ? Colors.white : AppColors.obsidian),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 10,
                color: isSelected ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// TAB 3: KEBIJAKAN SEWA & ADD-ONS
// ==========================================
class _RentalRulesTabView extends ConsumerStatefulWidget {
  final int businessId;
  final Map<String, dynamic>? initialRules;
  final bool isOwnerOrAdmin;

  const _RentalRulesTabView({
    required this.businessId,
    required this.initialRules,
    required this.isOwnerOrAdmin,
  });

  @override
  ConsumerState<_RentalRulesTabView> createState() => _RentalRulesTabViewState();
}

class _RentalRulesTabViewState extends ConsumerState<_RentalRulesTabView> {
  late bool _idLimitEnabled;
  late TextEditingController _maxPrimaryController;
  late bool _addonsEnabled;
  late bool _unlimitedAddons;
  late TextEditingController _maxAddonsController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final rules = widget.initialRules ?? {};
    _idLimitEnabled = rules['id_document_limit_enabled'] ?? true;
    _maxPrimaryController = TextEditingController(
      text: (rules['max_primary_devices_per_id'] ?? 1).toString(),
    );
    _addonsEnabled = rules['addons_enabled'] ?? true;
    _unlimitedAddons = rules['max_addons_per_rental'] == null;
    _maxAddonsController = TextEditingController(
      text: (rules['max_addons_per_rental'] ?? 5).toString(),
    );
  }

  @override
  void didUpdateWidget(covariant _RentalRulesTabView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialRules != oldWidget.initialRules && widget.initialRules != null) {
      final rules = widget.initialRules!;
      setState(() {
        _idLimitEnabled = rules['id_document_limit_enabled'] ?? true;
        _maxPrimaryController.text = (rules['max_primary_devices_per_id'] ?? 1).toString();
        _addonsEnabled = rules['addons_enabled'] ?? true;
        _unlimitedAddons = rules['max_addons_per_rental'] == null;
        _maxAddonsController.text = (rules['max_addons_per_rental'] ?? 5).toString();
      });
    }
  }

  @override
  void dispose() {
    _maxPrimaryController.dispose();
    _maxAddonsController.dispose();
    super.dispose();
  }

  Future<void> _saveRules() async {
    final maxPrimary = int.tryParse(_maxPrimaryController.text.trim()) ?? 1;
    final maxAddons = int.tryParse(_maxAddonsController.text.trim()) ?? 5;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    final payload = <String, dynamic>{
      'id_document_limit_enabled': _idLimitEnabled,
      'max_primary_devices_per_id': maxPrimary,
      'addons_enabled': _addonsEnabled,
      'allow_unlimited_addons': _unlimitedAddons,
      if (!_unlimitedAddons) 'max_addons_per_rental': maxAddons,
    };

    final success = await ref.read(organizationProvider.notifier).updateRentalRules(payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Kebijakan sewa dan add-on berhasil disimpan!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan kebijakan: ${ref.read(organizationProvider).error ?? 'Terjadi kesalahan'}'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined, color: AppColors.obsidian, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Kelola aturan batas sewa per dokumen identitas (KTP/SIM) dan fitur aksesoris add-on agar operasional toko tetap aman dan terkontrol.',
                    style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // SECTION 1: Identity Document Rental Limit
          _buildCard(
            title: 'Batas Dokumen Identitas (KTP / SIM)',
            subtitle: 'Kontrol berapa banyak perangkat utama yang boleh disewa oleh 1 identitas pelanggan.',
            icon: Icons.badge_outlined,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Batasi Sewa per Dokumen Identitas',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Mencegah 1 pelanggan menyewa unit utama melebihi kuota sebelum sewa sebelumnya dikembalikan.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                value: _idLimitEnabled,
                activeColor: AppColors.obsidian,
                onChanged: widget.isOwnerOrAdmin ? (val) => setState(() => _idLimitEnabled = val) : null,
              ),
              if (_idLimitEnabled) ...[
                const Divider(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Maksimal Unit Utama per Identitas',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Default: 1 unit utama (iPhone, iPad, Kamera, Laptop)',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        controller: _maxPrimaryController,
                        enabled: widget.isOwnerOrAdmin,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.infoLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_rounded, size: 16, color: AppColors.info),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Add-on (power bank, charger) TIDAK dihitung sebagai perangkat utama.',
                          style: TextStyle(fontSize: 11, color: AppColors.info, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),

          // SECTION 2: Add-on Accessories Feature
          _buildCard(
            title: 'Fitur Add-on & Aksesoris Sewa',
            subtitle: 'Atur ketersediaan dan kuota sewa aksesoris tambahan (Power Bank, Charger, Tripod, dll).',
            icon: Icons.extension_outlined,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Aktifkan Fitur Add-on / Aksesoris',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Izinkan kasir menambahkan item add-on bersama unit utama saat membuat transaksi sewa.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                value: _addonsEnabled,
                activeColor: AppColors.obsidian,
                onChanged: widget.isOwnerOrAdmin ? (val) => setState(() => _addonsEnabled = val) : null,
              ),
              if (_addonsEnabled) ...[
                const Divider(height: 24),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Tanpa Batas Unit Add-on (Unlimited)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                  subtitle: const Text(
                    'Pelanggan dapat menyewa add-on sebanyak stok fisik yang tersedia.',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  value: _unlimitedAddons,
                  activeColor: AppColors.obsidian,
                  onChanged: widget.isOwnerOrAdmin ? (val) => setState(() => _unlimitedAddons = val ?? false) : null,
                ),
                if (!_unlimitedAddons) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maksimal Unit Add-on per Sewa',
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Batas kuota total add-on dalam 1 struk sewa',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 80,
                        child: TextFormField(
                          controller: _maxAddonsController,
                          enabled: widget.isOwnerOrAdmin,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 24),

          // SAVE BUTTON
          if (widget.isOwnerOrAdmin)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.obsidian,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Menyimpan Kebijakan...' : 'Simpan Kebijakan Rental',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                onPressed: _isSaving ? null : _saveRules,
              ),
            ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.obsidian, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

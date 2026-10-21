import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.businessName,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
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
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
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
        itemCount: state.members.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final member = state.members[index] as Map<String, dynamic>;
          final user = (member['user'] as Map<String, dynamic>?) ?? {};
          final role = (member['role'] ?? 'staff').toString();
          final name = user['name'] ?? 'Pengguna';
          final email = user['email'] ?? '';
          final branchMembers = (member['branch_members'] as List<dynamic>?) ?? [];

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.obsidian,
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
              const Row(
                children: [
                  Icon(Icons.add_business_rounded, color: AppColors.obsidian, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Tambah Cabang / Outlet Baru',
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
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Nama Cabang *',
                  hintText: 'Contoh: SkyRental Canggu',
                  prefixIcon: Icon(Icons.storefront_rounded),
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
                  prefixIcon: Icon(Icons.tag_rounded),
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
                  prefixIcon: Icon(Icons.location_city_rounded),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Alamat Lengkap',
                  hintText: 'Contoh: Jl. Pantai Batu Bolong No. 12',
                  prefixIcon: Icon(Icons.map_outlined),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'No. Telepon / WhatsApp Cabang',
                  hintText: 'Contoh: 081234567890',
                  prefixIcon: Icon(Icons.phone_outlined),
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

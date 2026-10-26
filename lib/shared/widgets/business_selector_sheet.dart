import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/providers/business_provider.dart';
import '../../features/organization/presentation/manage_organization_screen.dart';

class BusinessSelectorSheet extends ConsumerStatefulWidget {
  const BusinessSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const BusinessSelectorSheet(),
    );
  }

  @override
  ConsumerState<BusinessSelectorSheet> createState() => _BusinessSelectorSheetState();
}

class _BusinessSelectorSheetState extends ConsumerState<BusinessSelectorSheet> {
  void _openOnboardingDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (ctx) => const _BusinessOnboardingDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final businessState = ref.watch(businessProvider);
    final user = ref.watch(authProvider).user;
    final businesses = businessState.businesses;

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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // User Header
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.obsidian,
                backgroundImage: user?['avatar_url'] != null
                    ? NetworkImage(user!['avatar_url'])
                    : null,
                child: user?['avatar_url'] == null
                    ? Text(
                        (user?['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?['name'] ?? 'Pengguna SkyRental',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      user?['email'] ?? '',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded, color: AppColors.danger),
                tooltip: 'Keluar',
                onPressed: () {
                  Navigator.pop(context);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'PILIH USAHA RENTAL AKTIF',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              TextButton.icon(
                onPressed: _openOnboardingDialog,
                icon: const Icon(Icons.add_business_rounded, size: 16),
                label: const Text(
                  'Tambah Usaha',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(50, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Error alert
          if (businessState.error != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.dangerLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      businessState.error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.read(businessProvider.notifier).refresh(),
                    style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    child: const Text('Coba Lagi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Business list
          if (businesses.isEmpty && businessState.error == null)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(Icons.storefront_outlined, size: 40, color: AppColors.textMuted),
                  const SizedBox(height: 10),
                  const Text(
                    'Belum Terhubung ke Usaha Rental',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Daftarkan bisnis rental Anda sekarang untuk mulai mengelola perangkat dan booking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: _openOnboardingDialog,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Daftarkan Usaha Baru'),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: businesses.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final biz = businesses[index] as Map<String, dynamic>;
                  final isSelected = biz['id'] == businessState.activeBusinessId;
                  final role = biz['role'] ?? 'owner';
                  final branches = (biz['branches'] as List<dynamic>?) ?? [];

                  return Material(
                    color: isSelected ? AppColors.infoLight : AppColors.surfaceMuted,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: isSelected ? AppColors.info : AppColors.border,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: ExpansionTile(
                      initiallyExpanded: isSelected,
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.info : AppColors.obsidian,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.apartment_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              biz['name'] ?? 'Rental Business',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isSelected ? AppColors.info : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _roleBadgeColor(role).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              role.toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _roleBadgeColor(role),
                              ),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        '${branches.length} Cabang • ${biz['city'] ?? 'Indonesia'}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      children: [
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        if (role == 'owner' && branches.length > 1) ...[
                          ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            leading: Icon(
                              Icons.corporate_fare_rounded,
                              size: 18,
                              color: isSelected && businessState.activeBranchId == null
                                  ? AppColors.warning
                                  : AppColors.textSecondary,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  'Semua Cabang (Konsolidasi)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected && businessState.activeBranchId == null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isSelected && businessState.activeBranchId == null
                                        ? const Color(0xFFB45309)
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFFDE68A)),
                                  ),
                                  child: const Text(
                                    'KONSOLIDASI',
                                    style: TextStyle(
                                      fontSize: 8,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: const Text(
                              'Laporan & analitik gabungan seluruh cabang',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                            trailing: isSelected && businessState.activeBranchId == null
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.warning, size: 18)
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              await ref.read(businessProvider.notifier).selectContext(
                                business: biz,
                                isConsolidated: true,
                              );
                            },
                          ),
                          const Divider(height: 1, indent: 32, endIndent: 16),
                        ],
                        ...branches.map((b) {
                          final branchMap = b as Map<String, dynamic>;
                          final isBranchActive = isSelected && branchMap['id'] == businessState.activeBranchId;
                          final isCentral = branchMap['is_central'] == true;

                          return ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                            leading: Icon(
                              isCentral ? Icons.hub_rounded : Icons.store_rounded,
                              size: 18,
                              color: isBranchActive ? AppColors.info : AppColors.textSecondary,
                            ),
                            title: Row(
                              children: [
                                Text(
                                  branchMap['name'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isBranchActive ? FontWeight.bold : FontWeight.normal,
                                    color: isBranchActive ? AppColors.info : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                if (isCentral)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AppColors.obsidian.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'PUSAT',
                                      style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppColors.obsidian),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: branchMap['city'] != null
                                ? Text(
                                    '${branchMap['code'] ?? ''} • ${branchMap['city']}'.trim(),
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  )
                                : null,
                            trailing: isBranchActive
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.info, size: 18)
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              await ref.read(businessProvider.notifier).selectContext(
                                business: biz,
                                branch: branchMap,
                              );
                            },
                          );
                        }),
                        if (role == 'owner' || role == 'admin') ...[
                          const Divider(height: 1, indent: 16, endIndent: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.obsidian,
                                  visualDensity: VisualDensity.compact,
                                ),
                                icon: const Icon(Icons.manage_accounts_outlined, size: 16),
                                label: const Text(
                                  'Kelola Tim & Cabang',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ManageOrganizationScreen(
                                        businessId: biz['id'] as int,
                                        businessName: biz['name'] as String,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Color _roleBadgeColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return Colors.purple;
      case 'admin':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }
}

class _BusinessOnboardingDialog extends ConsumerStatefulWidget {
  const _BusinessOnboardingDialog();

  @override
  ConsumerState<_BusinessOnboardingDialog> createState() => _BusinessOnboardingDialogState();
}

class _BusinessOnboardingDialogState extends ConsumerState<_BusinessOnboardingDialog> {
  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Denpasar');
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (name.isEmpty || city.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama usaha rental dan kota wajib diisi.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final success = await ref.read(businessProvider.notifier).registerNewBusiness(
      name: name,
      city: city,
      address: _addressCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Usaha rental "$name" berhasil didaftarkan!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final err = ref.read(businessProvider).error ?? 'Gagal mendaftarkan usaha.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_business_rounded, color: AppColors.obsidian),
          SizedBox(width: 10),
          Text('Daftar Usaha Rental Baru', style: TextStyle(fontSize: 16)),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Buat ruang bisnis baru untuk mengelola inventaris, tarif sewa, kasir, dan tim cabang Anda secara terisolasi.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Usaha Rental *',
                hintText: 'Contoh: SkyRental Bali',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Kota / Lokasi Domisili *',
                hintText: 'Contoh: Denpasar',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Alamat Cabang Utama',
                hintText: 'Jl. Sunset Road No. 88',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Nomor Telepon / WhatsApp',
                hintText: '081234567890',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Simpan & Mulai'),
        ),
      ],
    );
  }
}

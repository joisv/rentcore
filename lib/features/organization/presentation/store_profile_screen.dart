import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';

class StoreProfileScreen extends ConsumerStatefulWidget {
  const StoreProfileScreen({super.key});

  @override
  ConsumerState<StoreProfileScreen> createState() => _StoreProfileScreenState();
}

class _StoreProfileScreenState extends ConsumerState<StoreProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _sloganController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isLoading = false;
  bool _isInitLoaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _loadStoreData());
  }

  void _loadStoreData() {
    final bState = ref.read(businessProvider);
    final currentBiz = bState.currentBusiness;
    if (currentBiz != null) {
      _nameController.text = currentBiz['name']?.toString() ?? '';
      _sloganController.text = currentBiz['slogan']?.toString() ?? '';
      _addressController.text = currentBiz['address']?.toString() ?? '';
      _phoneController.text = currentBiz['phone']?.toString() ?? '';
    } else if (bState.activeBusinessName != null) {
      _nameController.text = bState.activeBusinessName!;
    }
    setState(() => _isInitLoaded = true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _sloganController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final bState = ref.read(businessProvider);
    final bizId = bState.activeBusinessId;

    if (bizId == null) {
      setState(() => _isLoading = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Bisnis rental aktif tidak ditemukan.'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    try {
      final repo = ref.read(authRepositoryProvider);
      final payload = <String, dynamic>{
        'name': _nameController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      await repo.updateBusiness(bizId, payload);
      await ref.read(businessProvider.notifier).refresh();

      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Informasi profil toko berhasil disimpan & diperbarui!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan profil toko: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);

    final isSuperAdmin = user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final currentBiz = bState.currentBusiness;
    final userRole = currentBiz?['role']?.toString().toLowerCase() ?? user?['role']?.toString().toLowerCase() ?? '';
    final isOwnerOrAdmin = userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(
        title: 'Profil Usaha & Toko',
      ),
      body: !_isInitLoaded
          ? const Center(child: CircularProgressIndicator(color: AppColors.obsidian))
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Role Permission Notice for Staff
                    if (!isOwnerOrAdmin) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.lock_rounded, color: AppColors.warning, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Anda masuk sebagai Staf. Pengaturan profil dan identitas toko hanya dapat diubah oleh Owner atau Admin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Section Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.storefront_rounded, size: 18, color: AppColors.obsidian),
                              SizedBox(width: 8),
                              Text(
                                'Identitas Toko & Header Struk',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Store Name
                          const Text('Nama Usaha / Toko *', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _nameController,
                            enabled: isOwnerOrAdmin,
                            decoration: InputDecoration(
                              hintText: 'Contoh: SkyRent Gadget Center',
                              filled: true,
                              fillColor: isOwnerOrAdmin ? AppColors.surfaceMuted : AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                            validator: (val) => (val == null || val.trim().isEmpty) ? 'Nama toko wajib diisi' : null,
                          ),
                          const SizedBox(height: 14),

                          // Slogan / Tagline
                          const Text('Slogan / Tagline Toko (Opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _sloganController,
                            enabled: isOwnerOrAdmin,
                            decoration: InputDecoration(
                              hintText: 'Contoh: Sewa iPhone & Gadget Terpercaya Sejak 2020',
                              filled: true,
                              fillColor: isOwnerOrAdmin ? AppColors.surfaceMuted : AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Store Phone
                          const Text('Nomor Telepon / WhatsApp Toko', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _phoneController,
                            enabled: isOwnerOrAdmin,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              hintText: 'Contoh: 081234567890',
                              filled: true,
                              fillColor: isOwnerOrAdmin ? AppColors.surfaceMuted : AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Store Address
                          const Text('Alamat Usaha / Toko', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _addressController,
                            enabled: isOwnerOrAdmin,
                            maxLines: 2,
                            decoration: InputDecoration(
                              hintText: 'Contoh: Jl. Sudirman No. 45, Jakarta Pusat',
                              filled: true,
                              fillColor: isOwnerOrAdmin ? AppColors.surfaceMuted : AppColors.background,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Catatan: Nama, slogan, telepon, dan alamat ini akan tercetak pada header struk kasir dan dokumen penyewaan.',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Save Button
                    if (isOwnerOrAdmin)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.obsidian,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isLoading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Icon(Icons.save_rounded, size: 18),
                          label: Text(
                            _isLoading ? 'Menyimpan...' : 'Simpan Profil Toko',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                          onPressed: _isLoading ? null : _saveStoreProfile,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../onboarding/providers/onboarding_provider.dart';

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
    final bizId =
        bState.activeBusinessId ?? parseEntityIntId(bState.currentBusiness?['id']);

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
      final trimmedName = _nameController.text.trim();
      final payload = <String, dynamic>{
        'name': trimmedName,
        'slogan': _sloganController.text.trim(),
        'address': _addressController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      final updatedBiz = await repo.updateBusiness(bizId, payload);
      final mergedFields = <String, dynamic>{
        ...payload,
        ...updatedBiz,
        'name': (updatedBiz['name']?.toString().trim().isNotEmpty == true)
            ? updatedBiz['name'].toString().trim()
            : trimmedName,
      };
      await ref
          .read(businessProvider.notifier)
          .updateActiveBusinessProfile(bizId, mergedFields);
      ref
          .read(authProvider.notifier)
          .syncUpdatedBusiness(bizId, mergedFields);
      try {
        await ref.read(businessProvider.notifier).refresh();
      } catch (_) {}
      ref.invalidate(onboardingProvider);
      ref.invalidate(storeChecklistProvider);

      if (mounted) {
        setState(() => _isLoading = false);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Informasi profil toko berhasil disimpan & diperbarui!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(true);
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
    final isInitialLoading = !_isInitLoaded || (bState.isLoading && bState.currentBusiness == null);

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: const RentCoreAppBar(
        title: 'Profil Usaha & Toko',
      ),
      body: isInitialLoading
          ? const SettingsGroupSkeleton(groupCount: 1, itemsPerGroup: 4)
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                          color: AirySettingsColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AirySettingsColors.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              color: AirySettingsColors.obsidian,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Anda masuk sebagai Staf. Pengaturan profil dan identitas toko hanya dapat diubah oleh Owner atau Admin.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirySettingsColors.inkMuted,
                                  fontWeight: FontWeight.w500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    airySectionHeader('Identitas Toko & Header Struk'),
                    const SizedBox(height: 16),

                    // Store Name
                    airyFieldLabel('Nama Usaha / Toko *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      enabled: isOwnerOrAdmin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        hintText: 'Contoh: Rental Kamera & Studio',
                        enabled: isOwnerOrAdmin,
                      ),
                      validator: (val) => (val == null || val.trim().isEmpty)
                          ? 'Nama toko wajib diisi'
                          : null,
                    ),
                    const SizedBox(height: 16),

                    // Slogan / Tagline
                    airyFieldLabel('Slogan / Tagline Toko (Opsional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _sloganController,
                      enabled: isOwnerOrAdmin,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        hintText:
                            'Contoh: Sewa iPhone & Gadget Terpercaya Sejak 2020',
                        enabled: isOwnerOrAdmin,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Store Phone
                    airyFieldLabel('Nomor Telepon / WhatsApp Toko'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _phoneController,
                      enabled: isOwnerOrAdmin,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        hintText: 'Contoh: 081234567890',
                        enabled: isOwnerOrAdmin,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Store Address
                    airyFieldLabel('Alamat Usaha / Toko'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _addressController,
                      enabled: isOwnerOrAdmin,
                      maxLines: 2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        hintText: 'Contoh: Jl. Sudirman No. 45, Jakarta Pusat',
                        enabled: isOwnerOrAdmin,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Nama, slogan, telepon, dan alamat ini akan tercetak pada header struk kasir dan dokumen penyewaan.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: AirySettingsColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: (!isInitialLoading && isOwnerOrAdmin)
          ? airyStickyFooter(
              child: airyPrimaryCta(
                label: 'Simpan Profil Toko',
                isLoading: _isLoading,
                onPressed: _isLoading ? null : _saveStoreProfile,
              ),
            )
          : null,
    );
  }
}

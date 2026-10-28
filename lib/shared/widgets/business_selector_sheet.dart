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
  int _currentStep = 0; // 0: Info Bisnis, 1: Situasi Cabang, 2: Kategori Rental

  final _nameCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Denpasar');
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // Branch situation
  String _branchSituation = 'single'; // 'single' or 'multi'
  final _branchNameCtrl = TextEditingController();
  final _branchCodeCtrl = TextEditingController();

  // Selected categories
  final Set<String> _selectedCategories = {};
  bool _isSubmitting = false;

  static const List<Map<String, String>> _availableCategories = [
    {
      'id': 'smartphones_electronics',
      'label': 'Smartphone & Gadget',
      'desc': 'iPhone, Android, tablet, aksesoris charger',
      'icon': '📱',
    },
    {
      'id': 'cameras_photography',
      'label': 'Kamera & Fotografi',
      'desc': 'Mirrorless, DSLR, lensa, lighting, drone',
      'icon': '📷',
    },
    {
      'id': 'tools_equipment',
      'label': 'Alat & Perkakas (Tools)',
      'desc': 'Mesin bor, genset, tangga, scaffolding, perkakas tukang',
      'icon': '🔧',
    },
    {
      'id': 'vehicles',
      'label': 'Kendaraan & Transportasi',
      'desc': 'Rental motor, mobil, sepeda, scooter listrik',
      'icon': '🚗',
    },
    {
      'id': 'event_supplies',
      'label': 'Perlengkapan Event & Pesta',
      'desc': 'Tenda, sound system, panggung, proyektor, kursi',
      'icon': '🎪',
    },
    {
      'id': 'furniture_household',
      'label': 'Furnitur & Rumah Tangga',
      'desc': 'Sofa, kasur lipat, meja event, peralatan bayi',
      'icon': '🛋️',
    },
    {
      'id': 'other',
      'label': 'Usaha Rental Lainnya',
      'desc': 'Kostum, alat camping, konsol game, mainan, dll.',
      'icon': '📦',
    },
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      if (_branchSituation == 'single' && _branchNameCtrl.text.isEmpty) {
        // Auto-update branch preview if not manually typed
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _cityCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _branchNameCtrl.dispose();
    _branchCodeCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      final name = _nameCtrl.text.trim();
      final city = _cityCtrl.text.trim();
      if (name.isEmpty || city.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nama usaha rental dan kota domisili wajib diisi.')),
        );
        return;
      }
      if (_branchNameCtrl.text.trim().isEmpty) {
        _branchNameCtrl.text = '$name Pusat';
      }
      if (_branchCodeCtrl.text.trim().isEmpty) {
        final clean = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
        _branchCodeCtrl.text = clean.length >= 3 ? clean.substring(0, 3) : 'PST';
      }
    }
    setState(() => _currentStep++);
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  void _submit() async {
    final name = _nameCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    if (name.isEmpty || city.isEmpty) {
      setState(() => _currentStep = 0);
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
      businessCategories: _selectedCategories.isNotEmpty ? _selectedCategories.toList() : null,
      initialBranchName: _branchNameCtrl.text.trim().isNotEmpty ? _branchNameCtrl.text.trim() : null,
      initialBranchCode: _branchCodeCtrl.text.trim().isNotEmpty ? _branchCodeCtrl.text.trim() : null,
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
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header & Step indicator
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.obsidian,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add_business_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Onboarding Bisnis Rental',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                        Text(
                          'Langkah ${_currentStep + 1} dari 3: ${_getStepTitle()}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: (_currentStep + 1) / 3,
                backgroundColor: AppColors.surfaceMuted,
                color: AppColors.obsidian,
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
              const SizedBox(height: 16),

              // Step Content
              Flexible(
                child: SingleChildScrollView(
                  child: _buildCurrentStepBody(),
                ),
              ),
              const SizedBox(height: 20),

              // Navigation Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentStep > 0)
                    TextButton.icon(
                      onPressed: _isSubmitting ? null : _prevStep,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Kembali'),
                    )
                  else
                    TextButton(
                      onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  Row(
                    children: [
                      if (_currentStep == 2) ...[
                        TextButton(
                          onPressed: _isSubmitting ? null : _submit,
                          child: const Text('Lewati Kategori'),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.obsidian,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : (_currentStep < 2 ? _nextStep : _submit),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                _currentStep < 2 ? 'Lanjutkan' : 'Selesai & Masuk',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0:
        return 'Identitas Usaha';
      case 1:
        return 'Situasi Cabang';
      case 2:
        return 'Kategori Rental';
      default:
        return '';
    }
  }

  Widget _buildCurrentStepBody() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Identity();
      case 1:
        return _buildStep2Branch();
      case 2:
        return _buildStep3Categories();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStep1Identity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Masukkan identitas nama usaha dan domisili rental Anda.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nama Usaha Rental *',
            hintText: 'Misal: SkyRental Bali / Sumber Teknik Perkakas',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityCtrl,
          decoration: const InputDecoration(
            labelText: 'Kota / Lokasi Domisili *',
            hintText: 'Contoh: Denpasar / Surabaya / Jakarta',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _addressCtrl,
          decoration: const InputDecoration(
            labelText: 'Alamat Operasional',
            hintText: 'Jl. Sunset Road No. 88 (Opsional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Nomor WhatsApp / Hotline',
            hintText: '081234567890 (Opsional)',
            border: OutlineInputBorder(),
            isDense: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2Branch() {
    final businessName = _nameCtrl.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Jelaskan situasi operasional outlet atau cabang usaha Anda saat ini.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),
        RadioListTile<String>(
          value: 'single',
          groupValue: _branchSituation,
          contentPadding: EdgeInsets.zero,
          title: const Text('1 Lokasi / Toko Utama Tunggal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: const Text('Operasional berpusat di satu toko utama (default central branch).', style: TextStyle(fontSize: 11)),
          onChanged: (v) {
            setState(() {
              _branchSituation = v!;
              _branchNameCtrl.text = '$businessName Pusat';
              final clean = businessName.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
              _branchCodeCtrl.text = clean.length >= 3 ? clean.substring(0, 3) : 'PST';
            });
          },
        ),
        RadioListTile<String>(
          value: 'multi',
          groupValue: _branchSituation,
          contentPadding: EdgeInsets.zero,
          title: const Text('Memiliki Banyak Cabang / Nama Khusus', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          subtitle: const Text('Atur nama dan kode identifikasi cabang awal secara spesifik.', style: TextStyle(fontSize: 11)),
          onChanged: (v) => setState(() => _branchSituation = v!),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Konfigurasi Cabang Utama Awal', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
              const SizedBox(height: 10),
              TextField(
                controller: _branchNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Cabang Utama',
                  hintText: 'Misal: SkyRental Pusat / Cabang Teuku Umar',
                  border: OutlineInputBorder(),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _branchCodeCtrl,
                textCapitalization: TextCapitalization.characters,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Kode Cabang (3-6 Huruf)',
                  hintText: 'PST / TMR',
                  border: OutlineInputBorder(),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  counterText: '',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Categories() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Pilih satu atau lebih kategori yang Anda sewakan. Kategori ini digunakan untuk menyesuaikan form katalog produk dan unit Anda.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 12),
        ..._availableCategories.map((cat) {
          final isSelected = _selectedCategories.contains(cat['id']);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(cat['id']);
                  } else {
                    _selectedCategories.add(cat['id']!);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3B82F6) : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Text(cat['icon']!, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cat['label']!,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isSelected ? const Color(0xFF1D4ED8) : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            cat['desc']!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: isSelected,
                      activeColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedCategories.add(cat['id']!);
                          } else {
                            _selectedCategories.remove(cat['id']);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

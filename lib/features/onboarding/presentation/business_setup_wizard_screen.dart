import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import 'feature_walkthrough_screen.dart';

class BusinessSetupWizardScreen extends ConsumerStatefulWidget {
  const BusinessSetupWizardScreen({super.key});

  @override
  ConsumerState<BusinessSetupWizardScreen> createState() =>
      _BusinessSetupWizardScreenState();
}

class _BusinessSetupWizardScreenState
    extends ConsumerState<BusinessSetupWizardScreen> {
  int _currentStep = 0; // 0: Nama Bisnis, 1: Cabang Utama, 2: Preset Rental

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _branchNameController = TextEditingController();
  final _cityController = TextEditingController();
  final _scrollController = ScrollController();
  bool _branchNameEditedManually = false;

  // Step 2: Branch Structure
  // Options: 'single_location', 'multi_branch', 'single_scalable'
  String _branchStructure = 'single_location';

  // Step 3: Niche Preset (and synced category tag)
  String? _selectedPreset;
  final Set<String> _selectedCategories = {};

  bool _isSubmitting = false;
  int? _pendingBusinessId;
  String? _errorMessage;
  String? _boundUserId;

  static const List<Map<String, dynamic>> _nichePresets = [
    {
      'id': 'iphone_gadget',
      'category_tag': 'iphone_smartphone',
      'label': 'iPhone & Gadget',
      'desc': 'iPhone, Android & Tablet, Powerbank',
      'starter_categories': ['iPhone', 'Android & Tablet', 'Powerbank & Charger'],
      'icon': Icons.smartphone_outlined,
    },
    {
      'id': 'playstation_console',
      'category_tag': 'gadget_electronics',
      'label': 'PlayStation & Konsol',
      'desc': 'PS5/PS4, Stik DualSense, TV & VR',
      'starter_categories': ['PlayStation 5 & 4', 'Stik & Controller', 'TV / Monitor & VR'],
      'icon': Icons.sports_esports_outlined,
    },
    {
      'id': 'camera_lens',
      'category_tag': 'camera',
      'label': 'Kamera & Lensa',
      'desc': 'Mirrorless, Lensa Gimbal, Lighting',
      'starter_categories': ['Kamera Mirrorless & DSLR', 'Lensa & Gimbal', 'Lighting & Audio'],
      'icon': Icons.photo_camera_outlined,
    },
    {
      'id': 'custom',
      'category_tag': 'other',
      'label': 'Mulai Kosong / Kustom',
      'desc': 'Atur kategori sendiri dari nol',
      'starter_categories': <String>[],
      'icon': Icons.tune_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    _branchNameController.dispose();
    _cityController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _resetFormState() {
    _nameController.clear();
    _branchNameController.clear();
    _cityController.clear();
    _branchNameEditedManually = false;
    _currentStep = 0;
    _branchStructure = 'single_location';
    _selectedPreset = null;
    _selectedCategories.clear();
    _pendingBusinessId = null;
    _errorMessage = null;
  }

  Future<void> _loadDraft() async {
    final user = ref.read(authProvider).user;
    final currentUserId = user?['id']?.toString();

    if (_boundUserId != null && _boundUserId != currentUserId) {
      _resetFormState();
    }
    _boundUserId = currentUserId;

    final repo = ref.read(authRepositoryProvider);
    final draft = await repo.loadWizardDraft(userId: currentUserId);
    if (!mounted) return;

    setState(() {
      _currentStep = (draft['step'] as int? ?? 0).clamp(0, 2);
      final draftName = draft['name'] as String? ?? '';
      _nameController.text = draftName;
      if (!_branchNameEditedManually &&
          draftName.trim().isNotEmpty &&
          _branchNameController.text.isEmpty) {
        _branchNameController.text = '${draftName.trim()} Pusat';
      }
      final draftStructure = draft['branch_structure'] as String?;
      _branchStructure = (draftStructure != null && draftStructure.isNotEmpty)
          ? draftStructure
          : 'single_location';
      _selectedCategories.clear();
      final draftCats = draft['categories'] as List<dynamic>?;
      if (draftCats != null && draftCats.isNotEmpty) {
        _selectedCategories.addAll(draftCats.cast<String>());
      }
      _pendingBusinessId = draft['pending_biz_id'] as int?;
    });
  }

  Future<void> _saveDraft() async {
    final user = ref.read(authProvider).user;
    final currentUserId = user?['id']?.toString();

    final repo = ref.read(authRepositoryProvider);
    await repo.saveWizardDraft(
      userId: currentUserId,
      step: _currentStep,
      name: _nameController.text.trim(),
      branchStructure: _branchStructure,
      categories: _selectedCategories.toList(),
      pendingBusinessId: _pendingBusinessId,
    );
  }

  bool get _isStep1Valid => _nameController.text.trim().length >= 3;

  void _syncDefaultBranchName() {
    if (!_branchNameEditedManually && _nameController.text.trim().isNotEmpty) {
      _branchNameController.text = '${_nameController.text.trim()} Pusat';
    }
  }

  void _nextStep() {
    setState(() => _errorMessage = null);

    if (_currentStep == 0) {
      if (!_isStep1Valid) {
        setState(() {
          _errorMessage =
              'Nama bisnis / toko wajib diisi (minimal 3 karakter).';
        });
        return;
      }
      _syncDefaultBranchName();
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _saveDraft();
    } else {
      _submitSetup();
    }
  }

  void _prevStep() {
    setState(() => _errorMessage = null);
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _saveDraft();
    }
  }

  void _skipPresetAndFinish() {
    _selectedPreset = 'custom';
    _selectedCategories.clear();
    _submitSetup();
  }

  void _selectPreset(Map<String, dynamic> preset) {
    final presetId = preset['id'] as String;
    final catTag = preset['category_tag'] as String;
    setState(() {
      if (_selectedPreset == presetId) {
        _selectedPreset = null;
        _selectedCategories.clear();
      } else {
        _selectedPreset = presetId;
        _selectedCategories
          ..clear()
          ..add(catTag);
      }
    });
    _saveDraft();
  }

  Future<void> _submitSetup() async {
    final storeName = _nameController.text.trim();
    if (storeName.length < 3) {
      setState(() {
        _currentStep = 0;
        _errorMessage = 'Nama usaha wajib diisi minimal 3 karakter.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final branchName = _branchNameController.text.trim();
    final city = _cityController.text.trim();

    final success =
        await ref.read(businessProvider.notifier).registerNewBusiness(
              name: storeName,
              city: city.isNotEmpty ? city : null,
              nichePreset: _selectedPreset,
              branchStructure: _branchStructure,
              initialBranchName: branchName.isNotEmpty ? branchName : null,
              businessCategories: _selectedCategories.isNotEmpty
                  ? _selectedCategories.toList()
                  : null,
              pendingBusinessId: _pendingBusinessId,
            );

    if (!mounted) return;

    if (success) {
      final user = ref.read(authProvider).user;
      final currentUserId = user?['id']?.toString();
      final repo = ref.read(authRepositoryProvider);
      await repo.clearWizardDraft(userId: currentUserId);
      _resetFormState();

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const FeatureWalkthroughScreen(),
        ),
      );
    } else {
      final err =
          ref.read(businessProvider).error ?? 'Gagal mendaftarkan bisnis usaha.';
      setState(() {
        _isSubmitting = false;
        _errorMessage = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final userName = user?['name']?.toString() ?? 'Pemilik Rental';

    ref.listen<AuthState>(authProvider, (previous, next) {
      final prevId = previous?.user?['id']?.toString();
      final nextId = next.user?['id']?.toString();
      if (prevId != nextId) {
        _resetFormState();
        _loadDraft();
      }
    });

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: AppBar(
        backgroundColor: AirySettingsColors.canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: AirySettingsColors.obsidian,
                ),
                onPressed: _prevStep,
                tooltip: 'Kembali',
              )
            : null,
        title: const Text(
          'Inisialisasi Bisnis Rental',
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            color: AirySettingsColors.obsidian,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_currentStep == 2)
            TextButton(
              onPressed: _isSubmitting ? null : _skipPresetAndFinish,
              style: TextButton.styleFrom(
                foregroundColor: AirySettingsColors.inkSecondary,
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              child: const Text(
                'Lewati',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: AirySettingsColors.inkSecondary,
                size: 20,
              ),
              tooltip: 'Keluar Akun',
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded,
                                color: AppColors.danger, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppColors.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (_currentStep == 0)
                      _buildStep1BusinessName(userName)
                    else if (_currentStep == 1)
                      _buildStep2BranchSetup()
                    else
                      _buildStep3NichePreset(),
                  ],
                ),
              ),
            ),
            _buildBottomActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: AirySettingsColors.canvas,
        border: Border(
          bottom: BorderSide(color: AirySettingsColors.divider, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildStepDot(0, 'Usaha'),
          _buildStepDivider(0),
          _buildStepDot(1, 'Cabang'),
          _buildStepDivider(1),
          _buildStepDot(2, 'Preset'),
        ],
      ),
    );
  }

  Widget _buildStepDot(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (isDone || isActive)
                ? AirySettingsColors.obsidian
                : AirySettingsColors.border,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 13)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isActive
                          ? Colors.white
                          : AirySettingsColors.inkSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
            color: isActive || isDone
                ? AirySettingsColors.obsidian
                : AirySettingsColors.inkSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int fromStep) {
    final isDone = _currentStep > fromStep;
    return Expanded(
      child: Container(
        height: 1.5,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? AirySettingsColors.obsidian : AirySettingsColors.border,
      ),
    );
  }

  // --- Step 1: Welcome + Nama Bisnis ---
  Widget _buildStep1BusinessName(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $userName 👋',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AirySettingsColors.inkSecondary,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Apa nama usaha rental Anda?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AirySettingsColors.obsidian,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nama ini akan muncul pada nota sewa pelanggan, laporan kasir, serta identitas toko Anda.',
          style: TextStyle(
            fontSize: 13,
            color: AirySettingsColors.inkSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AirySettingsColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AirySettingsColors.border),
          ),
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: true,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AirySettingsColors.obsidian,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Contoh: Lensa Nusantara Jember',
              hintStyle: TextStyle(
                fontSize: 14,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w400,
              ),
              labelText: 'Nama Bisnis / Toko',
              labelStyle: TextStyle(
                fontSize: 12,
                color: AirySettingsColors.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (_) {
              setState(() {});
              _saveDraft();
            },
            onSubmitted: (_) {
              if (_isStep1Valid) _nextStep();
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              _isStep1Valid
                  ? Icons.check_circle_rounded
                  : Icons.info_outline_rounded,
              size: 14,
              color: _isStep1Valid
                  ? AppColors.success
                  : AirySettingsColors.inkSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Minimal 3 karakter. Tersimpan otomatis ke profil toko Anda.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: _isStep1Valid
                      ? AppColors.success
                      : AirySettingsColors.inkSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 2: Cabang Utama & Struktur ---
  Widget _buildStep2BranchSetup() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Struktur Operasional Toko',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AirySettingsColors.obsidian,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih model lokasi dan beri nama cabang utama Anda agar siap dipakai di kasir.',
          style: TextStyle(
            fontSize: 13,
            color: AirySettingsColors.inkSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        _buildBranchOptionCard(
          id: 'single_location',
          title: 'Satu lokasi / toko utama',
          subtitle:
              'Operasional terpusat pada satu gerai utama. Simpel dan cepat untuk kasir harian.',
          badge: 'Rekomendasi',
        ),
        const SizedBox(height: 10),
        _buildBranchOptionCard(
          id: 'multi_branch',
          title: 'Sudah memiliki beberapa cabang',
          subtitle:
              'Dukungan multi-outlet dengan stok terpisah, mutasi antar cabang, dan hak akses kasir.',
          badge: 'Multi-Outlet',
        ),
        const SizedBox(height: 10),
        _buildBranchOptionCard(
          id: 'single_scalable',
          title: 'Satu lokasi, berencana ekspansi',
          subtitle:
              'Mulai dari satu toko dengan infrastruktur siap membuka cabang baru sewaktu-waktu.',
          badge: 'Skalabilitas',
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AirySettingsColors.surfaceSubtle,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AirySettingsColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Detail Cabang Utama (Opsional)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AirySettingsColors.obsidian,
                ),
              ),
              const SizedBox(height: 12),
              airyFieldLabel('Nama Cabang Utama'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('wizard_branch_name_input'),
                controller: _branchNameController,
                onChanged: (_) => _branchNameEditedManually = true,
                decoration: airyInputDecoration(
                  hintText: 'Contoh: Pusat Malang',
                ),
              ),
              const SizedBox(height: 10),
              airyFieldLabel('Kota / Lokasi'),
              const SizedBox(height: 6),
              TextField(
                key: const Key('wizard_city_input'),
                controller: _cityController,
                decoration: airyInputDecoration(
                  hintText: 'Contoh: Malang',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBranchOptionCard({
    required String id,
    required String title,
    required String subtitle,
    required String badge,
  }) {
    final isSelected = _branchStructure == id;

    return InkWell(
      onTap: () {
        setState(() => _branchStructure = id);
        _saveDraft();
      },
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AirySettingsColors.canvas,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AirySettingsColors.obsidian
                : AirySettingsColors.border,
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AirySettingsColors.obsidian
                      : AirySettingsColors.border,
                  width: isSelected ? 6 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AirySettingsColors.obsidian,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AirySettingsColors.obsidian
                              : AirySettingsColors.pillSurface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AirySettingsColors.inkSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AirySettingsColors.inkSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Step 3: Smart Rental Niche Presets ---
  Widget _buildStep3NichePreset() {
    final selectedMap = _nichePresets
        .where((p) => p['id'] == _selectedPreset)
        .firstOrNull;
    final starterCategories =
        (selectedMap?['starter_categories'] as List<String>?) ?? const [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Bisnis Rental',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AirySettingsColors.obsidian,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih preset usaha rental agar kategori awal otomatis siap pakai. Anda dapat menyesuaikannya nanti.',
          style: TextStyle(
            fontSize: 13,
            color: AirySettingsColors.inkSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _nichePresets.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.45,
          ),
          itemBuilder: (context, index) {
            final preset = _nichePresets[index];
            final presetId = preset['id'] as String;
            final isSelected = _selectedPreset == presetId;

            return InkWell(
              key: Key('wizard_preset_$presetId'),
              onTap: () => _selectPreset(preset),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AirySettingsColors.obsidian
                      : AirySettingsColors.canvas,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AirySettingsColors.obsidian
                        : AirySettingsColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      preset['icon'] as IconData,
                      size: 20,
                      color: isSelected
                          ? Colors.white
                          : AirySettingsColors.obsidian,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      preset['label'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isSelected
                            ? Colors.white
                            : AirySettingsColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      preset['desc'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: isSelected
                            ? const Color(0xFFCBD5E1)
                            : AirySettingsColors.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (starterCategories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AirySettingsColors.surfaceSubtle,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirySettingsColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kategori Awal yang Akan Dibuat Otomatis:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AirySettingsColors.inkMuted,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: starterCategories.map((cat) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AirySettingsColors.canvas,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AirySettingsColors.border),
                      ),
                      child: Text(
                        cat,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AirySettingsColors.obsidian,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // --- Bottom Action Bar ---
  Widget _buildBottomActionBar() {
    final isStep1 = _currentStep == 0;
    final isStep3 = _currentStep == 2;
    final isButtonEnabled = !_isSubmitting && (!isStep1 || _isStep1Valid);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        color: AirySettingsColors.canvas,
        border: Border(
          top: BorderSide(color: AirySettingsColors.divider, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: isButtonEnabled ? _nextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AirySettingsColors.obsidian,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AirySettingsColors.border,
            disabledForegroundColor: AirySettingsColors.inkSecondary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  isStep3 ? 'Selesai & Buka Dashboard' : 'Lanjut',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

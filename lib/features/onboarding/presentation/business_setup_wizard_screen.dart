import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
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
  int _currentStep = 0; // 0: Nama Bisnis, 1: Struktur Cabang, 2: Kategori Bisnis

  final _nameController = TextEditingController();
  final _nameFocusNode = FocusNode();

  // Step 2: Branch Structure
  // Options: 'single_location', 'multi_branch', 'single_scalable'
  String _branchStructure = 'single_location';

  // Step 3: Selected Rental Categories (Personalization)
  final Set<String> _selectedCategories = {};

  bool _isSubmitting = false;
  int? _pendingBusinessId;
  String? _errorMessage;
  String? _boundUserId;

  static const List<Map<String, String>> _categories = [
    {
      'id': 'iphone_smartphone',
      'label': 'iPhone & Smartphone',
      'desc': 'iPhone, Android, tablet, aksesoris charger',
    },
    {
      'id': 'gadget_electronics',
      'label': 'Gadget & Elektronik',
      'desc': 'Konsol game, laptop, proyektor, audio sound',
    },
    {
      'id': 'camera',
      'label': 'Kamera',
      'desc': 'Mirrorless, DSLR, lensa, lighting, gimbal',
    },
    {
      'id': 'vehicle',
      'label': 'Kendaraan',
      'desc': 'Rental motor, mobil, sepeda, scooter listrik',
    },
    {
      'id': 'outdoor',
      'label': 'Alat Outdoor',
      'desc': 'Tenda camping, carrier, hammock, kompor portable',
    },
    {
      'id': 'other',
      'label': 'Lainnya',
      'desc': 'Kostum, perlengkapan event, furnitur, perkakas',
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
    super.dispose();
  }

  void _resetFormState() {
    _nameController.clear();
    _currentStep = 0;
    _branchStructure = 'single_location';
    _selectedCategories.clear();
    _pendingBusinessId = null;
    _errorMessage = null;
  }

  Future<void> _loadDraft() async {
    final user = ref.read(authProvider).user;
    final currentUserId = user?['id']?.toString();

    // Verify whether the bound user ID matches current auth state
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
    }

    if (_currentStep < 2) {
      setState(() => _currentStep++);
      _saveDraft();
    } else {
      _submitSetup();
    }
  }

  void _prevStep() {
    setState(() => _errorMessage = null);
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _saveDraft();
    }
  }

  void _skipCategoriesAndFinish() {
    _selectedCategories.clear();
    _submitSetup();
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

    final success =
        await ref.read(businessProvider.notifier).registerNewBusiness(
              name: storeName,
              branchStructure: _branchStructure,
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

      // Transition to Feature Walkthrough
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

    // In-memory form state cleanup when switching accounts
    ref.listen<AuthState>(authProvider, (previous, next) {
      final prevId = previous?.user?['id']?.toString();
      final nextId = next.user?['id']?.toString();
      if (prevId != nextId) {
        _resetFormState();
        _loadDraft();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded,
                    color: AppColors.textPrimary),
                onPressed: _prevStep,
                tooltip: 'Kembali',
              )
            : null,
        title: const Text('Inisialisasi Bisnis Rental'),
        centerTitle: true,
        actions: [
          if (_currentStep == 2)
            TextButton(
              onPressed: _isSubmitting ? null : _skipCategoriesAndFinish,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.textSecondary,
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
              icon: const Icon(Icons.logout_rounded,
                  color: AppColors.textSecondary, size: 20),
              tooltip: 'Keluar Akun',
              onPressed: () => ref.read(authProvider.notifier).logout(),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Minimal Step Progress Indicator
            _buildStepIndicator(),

            // Scrollable Content area with bottom clearance to eliminate RenderFlex overflow
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.danger.withValues(alpha: 0.3),
                          ),
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

                    // Step View Builder
                    if (_currentStep == 0)
                      _buildStep1BusinessName(userName)
                    else if (_currentStep == 1)
                      _buildStep2BranchStructure()
                    else
                      _buildStep3CategoryPersonalization(),
                  ],
                ),
              ),
            ),

            // Persistent Bottom Action Bar
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
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildStepDot(0, 'Nama Bisnis'),
          _buildStepDivider(0),
          _buildStepDot(1, 'Cabang'),
          _buildStepDivider(1),
          _buildStepDot(2, 'Kategori'),
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
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDone
                ? AppColors.obsidian
                : isActive
                    ? AppColors.obsidian
                    : AppColors.border,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : Text(
                    '${stepIndex + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontSize: 12,
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
                ? AppColors.textPrimary
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStepDivider(int fromStep) {
    final isDone = _currentStep > fromStep;
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        color: isDone ? AppColors.obsidian : AppColors.border,
      ),
    );
  }

  // --- Step 1: Nama Bisnis ---
  Widget _buildStep1BusinessName(String userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Halo, $userName 👋',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Apa nama usaha rental Anda?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nama ini akan muncul pada nota sewa pelanggan, laporan kasir, serta identitas toko Anda.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          padding: EdgeInsets.zero,
          child: TextField(
            controller: _nameController,
            focusNode: _nameFocusNode,
            autofocus: true,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Contoh: Lensa Nusantara Jember',
              hintStyle: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w400,
              ),
              labelText: 'Nama Bisnis / Toko',
              labelStyle: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onChanged: (val) {
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
              color: _isStep1Valid ? AppColors.success : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Minimal 3 karakter. Anda dapat mengubah nama ini kapan saja nanti.',
                style: TextStyle(
                  fontSize: 11,
                  color:
                      _isStep1Valid ? AppColors.success : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Step 2: Struktur Cabang ---
  Widget _buildStep2BranchStructure() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Struktur Operasional Toko',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih model lokasi yang paling menggambarkan kondisi bisnis rental Anda saat ini. Tidak memerlukan input alamat lengkap sekarang.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
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
        const SizedBox(height: 12),
        _buildBranchOptionCard(
          id: 'multi_branch',
          title: 'Sudah memiliki beberapa cabang',
          subtitle:
              'Dukungan multi-outlet dengan stok terpisah, mutasi antar cabang, dan hak akses kasir.',
          badge: 'Multi-Outlet',
        ),
        const SizedBox(height: 12),
        _buildBranchOptionCard(
          id: 'single_scalable',
          title: 'Satu lokasi, berencana ekspansi',
          subtitle:
              'Mulai dari satu toko dengan infrastruktur yang siap membuka cabang baru sewaktu-waktu.',
          badge: 'Skalabilitas',
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
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.obsidian : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                  color: isSelected ? AppColors.obsidian : AppColors.border,
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
                            color: isSelected
                                ? AppColors.obsidian
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.obsidian.withValues(alpha: 0.08)
                              : AppColors.background,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.obsidian
                                : AppColors.textSecondary,
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
                      color: AppColors.textSecondary,
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

  // --- Step 3: Kategori Bisnis (Personalization) ---
  Widget _buildStep3CategoryPersonalization() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Kategori Bisnis Rental',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih kategori barang yang Anda sewakan. Kategori dapat diubah atau ditambahkan kapan saja.',
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 20),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.8,
          ),
          itemBuilder: (context, index) {
            final cat = _categories[index];
            final catId = cat['id']!;
            final isSelected = _selectedCategories.contains(catId);

            return InkWell(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedCategories.remove(catId);
                  } else {
                    _selectedCategories.add(catId);
                  }
                });
                _saveDraft();
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.obsidian : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.obsidian : AppColors.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Text(
                  cat['label']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            );
          },
        ),
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
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isButtonEnabled ? _nextStep : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.border,
            disabledForegroundColor: AppColors.textSecondary,
            animationDuration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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

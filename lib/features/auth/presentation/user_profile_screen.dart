import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/legal_links.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../organization/presentation/widgets/staff_resignation_sheet.dart';
import '../../organization/providers/organization_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/business_provider.dart';

class UserProfileScreen extends ConsumerStatefulWidget {
  const UserProfileScreen({super.key});

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  final _profileFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isProfileLoading = false;
  bool _isPasswordLoading = false;

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authProvider).user;
    _nameController = TextEditingController(text: user?['name']?.toString() ?? '');
    _phoneController = TextEditingController(text: user?['phone']?.toString() ?? '');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bState = ref.read(businessProvider);
      final role = (bState.currentBusiness?['role'] ?? 'owner').toString();
      if (bState.activeBusinessId != null && role != 'owner') {
        final storeLabel = bState.resolvedStoreName.isNotEmpty
            ? bState.resolvedStoreName
            : 'Usaha Rental';
        ref.read(organizationProvider.notifier).ensureBusinessResignationsLoaded(
              bState.activeBusinessId!,
              businessName: storeLabel,
            );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSaveProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;
    setState(() => _isProfileLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(authProvider.notifier).updateProfile(
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
        );

    if (mounted) {
      setState(() => _isProfileLoading = false);
      if (success) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Profil berhasil diperbarui.'),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = ref.read(authProvider).errorMessage ?? 'Gagal memperbarui profil.';
        messenger.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _handleSavePassword(bool hasExistingPassword) async {
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() => _isPasswordLoading = true);

    final messenger = ScaffoldMessenger.of(context);
    final success = await ref.read(authProvider.notifier).updatePassword(
          currentPassword: hasExistingPassword ? _currentPasswordController.text.trim() : null,
          newPassword: _newPasswordController.text.trim(),
          newPasswordConfirmation: _confirmPasswordController.text.trim(),
        );

    if (mounted) {
      setState(() => _isPasswordLoading = false);
      if (success) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              hasExistingPassword
                  ? 'Kata sandi berhasil diperbarui.'
                  : 'Kata sandi berhasil dibuat. Anda dapat login dengan email dan kata sandi.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        final error = ref.read(authProvider).errorMessage ?? 'Gagal memperbarui kata sandi.';
        messenger.showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final userName = user?['name']?.toString() ?? 'Pengguna';
    final userEmail = user?['email']?.toString() ?? '-';
    final userRole = user?['role']?.toString().toUpperCase() ?? 'STAFF';
    final avatarUrl = user?['avatar_url']?.toString();
    final isGoogleUser = user?['google_id'] != null;
    final hasPassword = user?['has_password'] == true;

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: const RentCoreAppBar(
        title: 'Profil & Keamanan Akun',
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // User Avatar & Badges Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AirySettingsColors.obsidian,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: 80,
                                height: 80,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Text(
                                  _getInitials(userName),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                              _getInitials(userName),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AirySettingsColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AirySettingsColors.pillSurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            userRole,
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AirySettingsColors.inkMuted,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                        if (isGoogleUser) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: const Color(0xFFDBEAFE),
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 11,
                                  color: Color(0xFF1D4ED8),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Google Account',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1D4ED8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            airyHairlineDivider(),

            // SECTION 1: Personal Information Form
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: _profileFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    airySectionHeader('Informasi Pribadi'),
                    const SizedBox(height: 16),

                    // Email (Readonly)
                    airyFieldLabel('Alamat Email (Akun)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('profile_email_field'),
                      initialValue: userEmail,
                      readOnly: true,
                      enabled: false,
                      decoration: airyInputDecoration(
                        enabled: false,
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: AirySettingsColors.inkSecondary,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AirySettingsColors.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Display Name
                    airyFieldLabel('Nama Lengkap *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('profile_name_field'),
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        prefixIcon: const Icon(
                          Icons.person_outline_rounded,
                          size: 18,
                          color: AirySettingsColors.inkSecondary,
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Nama lengkap wajib diisi.';
                        }
                        if (value.trim().length < 2) {
                          return 'Nama lengkap minimal 2 karakter.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Phone Number
                    airyFieldLabel('Nomor Telepon / WhatsApp'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('profile_phone_field'),
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        hintText: 'Contoh: 081234567890',
                        prefixIcon: const Icon(
                          Icons.phone_outlined,
                          size: 18,
                          color: AirySettingsColors.inkSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    airyPrimaryCta(
                      label: 'Simpan Perubahan Profil',
                      isLoading: _isProfileLoading,
                      onPressed:
                          _isProfileLoading ? null : _handleSaveProfile,
                    ),
                  ],
                ),
              ),
            ),
            airyHairlineDivider(),

            // SECTION 2: Security & Password Management
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Form(
                key: _passwordFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      hasPassword ? 'Ubah Kata Sandi' : 'Buat Kata Sandi Akun',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AirySettingsColors.obsidian,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Google-connected notice if user does NOT have a password
                    if (!hasPassword) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AirySettingsColors.surfaceSubtle,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AirySettingsColors.border),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: AirySettingsColors.inkMuted,
                              size: 18,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Akun Anda saat ini login via Google. Buat kata sandi lokal agar Anda dapat login langsung menggunakan email dan kata sandi tanpa bergantung pada Google.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AirySettingsColors.inkMuted,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Current Password field (ONLY if user already has an existing password)
                    if (hasPassword) ...[
                      airyFieldLabel('Kata Sandi Saat Ini *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        key: const Key('profile_current_password_field'),
                        controller: _currentPasswordController,
                        obscureText: _obscureCurrent,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AirySettingsColors.obsidian,
                        ),
                        decoration: airyInputDecoration(
                          prefixIcon: const Icon(
                            Icons.key_outlined,
                            size: 18,
                            color: AirySettingsColors.inkSecondary,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureCurrent
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: AirySettingsColors.inkSecondary,
                            ),
                            onPressed: () => setState(
                              () => _obscureCurrent = !_obscureCurrent,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (hasPassword && (value == null || value.isEmpty)) {
                            return 'Kata sandi saat ini wajib diisi.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),
                    ],

                    // New Password field
                    airyFieldLabel(
                      hasPassword
                          ? 'Kata Sandi Baru *'
                          : 'Buat Kata Sandi Baru *',
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('profile_new_password_field'),
                      controller: _newPasswordController,
                      obscureText: _obscureNew,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AirySettingsColors.inkSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AirySettingsColors.inkSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Kata sandi baru wajib diisi.';
                        }
                        if (value.length < 8) {
                          return 'Kata sandi baru minimal 8 karakter.';
                        }
                        if (hasPassword &&
                            value == _currentPasswordController.text) {
                          return 'Kata sandi baru harus berbeda dari kata sandi saat ini.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Confirm New Password field
                    airyFieldLabel('Konfirmasi Kata Sandi Baru *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      key: const Key('profile_confirm_password_field'),
                      controller: _confirmPasswordController,
                      obscureText: _obscureConfirm,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AirySettingsColors.obsidian,
                      ),
                      decoration: airyInputDecoration(
                        prefixIcon: const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                          color: AirySettingsColors.inkSecondary,
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 18,
                            color: AirySettingsColors.inkSecondary,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Konfirmasi kata sandi baru wajib diisi.';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Konfirmasi kata sandi tidak cocok.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    airyPrimaryCta(
                      label: hasPassword
                          ? 'Perbarui Kata Sandi'
                          : 'Buat Kata Sandi Sekarang',
                      isLoading: _isPasswordLoading,
                      onPressed: _isPasswordLoading
                          ? null
                          : () => _handleSavePassword(hasPassword),
                    ),
                  ],
                ),
              ),
            ),

            // SECTION 3: Employment Status & Resignation (non-owner)
            Builder(
              builder: (context) {
                final bState = ref.watch(businessProvider);
                final orgState = ref.watch(organizationProvider);
                final userId = ref.watch(authProvider).user?['id'];
                final currentBiz = bState.currentBusiness;
                final bizRole = (currentBiz?['role'] ?? 'owner').toString();
                if (bState.activeBusinessId == null || bizRole == 'owner') {
                  return const SizedBox.shrink();
                }
                final storeLabel = bState.resolvedStoreName.isNotEmpty
                    ? bState.resolvedStoreName
                    : 'Usaha Rental';

                Map<String, dynamic>? latestRequest;
                if (orgState.businessId == bState.activeBusinessId &&
                    orgState.resignationRequests.isNotEmpty) {
                  for (final raw in orgState.resignationRequests) {
                    if (raw is Map &&
                        (userId == null ||
                            raw['user_id']?.toString() == userId.toString())) {
                      latestRequest = Map<String, dynamic>.from(raw);
                      break;
                    }
                  }
                }

                final resignStatus = (latestRequest?['status'] ??
                        currentBiz?['resign_status'] ??
                        '')
                    .toString()
                    .trim()
                    .toLowerCase();
                final isPending = resignStatus == 'pending';
                final isRejected = resignStatus == 'rejected';
                final submittedReason = (latestRequest?['reason'] ??
                        currentBiz?['resign_reason'] ??
                        '')
                    .toString()
                    .trim();
                final rejectionReason = (latestRequest?['decision_notes'] ??
                        latestRequest?['rejection_reason'] ??
                        currentBiz?['resign_rejection_reason'] ??
                        '')
                    .toString()
                    .trim();
                final requestedAtRaw = (latestRequest?['created_at'] ??
                        currentBiz?['resign_requested_at'])
                    ?.toString();
                final requestedAtLabel =
                    requestedAtRaw != null && requestedAtRaw.isNotEmpty
                        ? DateFormatter.formatShort(requestedAtRaw)
                        : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    airyHairlineDivider(),
                    InkWell(
                      key: const Key('user_profile_resign_tile'),
                      onTap: () {
                        StaffResignationSheet.show(
                          context,
                          businessId: bState.activeBusinessId!,
                          businessName: storeLabel,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.badge_outlined,
                                color: AirySettingsColors.obsidian,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Expanded(
                                        child: Text(
                                          'Status Kepegawaian & Resign',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: AirySettingsColors.obsidian,
                                          ),
                                        ),
                                      ),
                                      if (isPending)
                                        Container(
                                          key: const Key('profile_resign_pending_pill'),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFFFBEB),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFFDE68A),
                                            ),
                                          ),
                                          child: const Text(
                                            'Menunggu Persetujuan Resign',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFB45309),
                                            ),
                                          ),
                                        )
                                      else if (isRejected)
                                        Container(
                                          key: const Key('profile_resign_rejected_pill'),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFEF2F2),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: const Color(0xFFFECACA),
                                            ),
                                          ),
                                          child: const Text(
                                            'Resign Ditolak',
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w700,
                                              color: Color(0xFFDC2626),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  if (isPending) ...[
                                    Text(
                                      requestedAtLabel != null
                                          ? '$storeLabel • Diajukan $requestedAtLabel'
                                          : '$storeLabel • Pengajuan sedang ditinjau Owner',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AirySettingsColors.inkSecondary,
                                      ),
                                    ),
                                    if (submittedReason.isNotEmpty) ...[
                                      const SizedBox(height: 3),
                                      Text(
                                        'Alasan: "$submittedReason"',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AirySettingsColors.inkSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ] else if (isRejected) ...[
                                    Text(
                                      rejectionReason.isNotEmpty
                                          ? 'Catatan Owner: "$rejectionReason"'
                                          : '$storeLabel • Ajukan ulang bila diperlukan',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AirySettingsColors.inkSecondary,
                                      ),
                                    ),
                                  ] else ...[
                                    Text(
                                      '$storeLabel • Ajukan Resign',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AirySettingsColors.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Padding(
                              padding: EdgeInsets.only(top: 2),
                              child: Icon(
                                Icons.chevron_right_rounded,
                                size: 20,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
            airyHairlineDivider(),

            // SECTION 4: Privacy & Account
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 6),
              child: airySectionHeader('Privasi & Akun'),
            ),
            InkWell(
              key: const Key('profile_privacy_policy_tile'),
              onTap: () =>
                  LegalLinks.openExternal(context, LegalLinks.privacyPolicyUri),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 20,
                      color: AirySettingsColors.obsidian,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kebijakan Privasi',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AirySettingsColors.obsidian,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Penggunaan data, izin Bluetooth & isolasi tenant',
                            style: TextStyle(
                              fontSize: 12,
                              color: AirySettingsColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: airyHairlineDivider(),
            ),
            InkWell(
              key: const Key('profile_account_deletion_tile'),
              onTap: () => LegalLinks.openExternal(
                context,
                LegalLinks.accountDeletionUri,
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.danger,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hapus Akun',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: AppColors.danger,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Ajukan penonaktifan & penghapusan data akun',
                            style: TextStyle(
                              fontSize: 12,
                              color: AirySettingsColors.inkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 16,
                      color: Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

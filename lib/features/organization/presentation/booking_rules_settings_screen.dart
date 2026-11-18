import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';

class BookingRulesSettingsScreen extends ConsumerStatefulWidget {
  const BookingRulesSettingsScreen({super.key});

  @override
  ConsumerState<BookingRulesSettingsScreen> createState() =>
      _BookingRulesSettingsScreenState();
}

class _BookingRulesSettingsScreenState
    extends ConsumerState<BookingRulesSettingsScreen> {
  static const List<int> _gracePeriodOptions = [15, 30, 60, 120];

  int? _selectedBranchId;
  int _gracePeriodMinutes = 60;
  bool _autoNoShow = true;
  bool _allowFloatingUnit = true;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initBranchAndLoad();
    });
  }

  void _initBranchAndLoad() {
    final bState = ref.read(businessProvider);
    final branches =
        (bState.currentBusiness?['branches'] as List?)
            ?.whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .toList() ??
        [];

    final initialBranchId =
        bState.activeBranchId ??
        (branches.isNotEmpty ? (branches.first['id'] as num?)?.toInt() : null);

    if (initialBranchId == null) {
      setState(() {
        _isLoading = false;
        _loadError = 'Cabang aktif belum ditemukan.';
      });
      return;
    }

    _selectedBranchId = initialBranchId;
    _loadRules(initialBranchId);
  }

  Future<void> _loadRules(int branchId) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data = await ref
          .read(authRepositoryProvider)
          .fetchBranchBookingRules(branchId);
      if (!mounted) return;
      setState(() {
        _gracePeriodMinutes =
            (data['booking_grace_period_minutes'] as num?)?.toInt() ?? 60;
        _autoNoShow = data['booking_auto_noshow'] != false;
        _allowFloatingUnit = data['allow_floating_unit_booking'] != false;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      });
    }
  }

  Future<void> _saveRules() async {
    final branchId = _selectedBranchId;
    if (branchId == null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await ref.read(authRepositoryProvider).updateBranchBookingRules(branchId, {
        'booking_grace_period_minutes': _gracePeriodMinutes,
        'booking_auto_noshow': _autoNoShow,
        'allow_floating_unit_booking': _allowFloatingUnit,
      });

      await ref.read(businessProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _isSaving = false);

      messenger.showSnackBar(
        const SnackBar(
          content: Text('Aturan booking & no-show berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Gagal menyimpan aturan: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final bState = ref.watch(businessProvider);

    final isSuperAdmin =
        user?['is_platform_admin'] == true || user?['role'] == 'super_admin';
    final currentBiz = bState.currentBusiness;
    final userRole =
        currentBiz?['role']?.toString().toLowerCase() ??
        user?['role']?.toString().toLowerCase() ??
        '';
    final isOwnerOrAdmin =
        userRole == 'owner' || userRole == 'admin' || isSuperAdmin;

    final branches =
        (currentBiz?['branches'] as List?)
            ?.whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .toList() ??
        [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(title: 'Aturan Booking & No-Show'),
      body: _isLoading
          ? const SettingsGroupSkeleton(groupCount: 2, itemsPerGroup: 3)
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 44,
                      color: AppColors.danger,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _loadError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _selectedBranchId != null
                          ? () => _loadRules(_selectedBranchId!)
                          : _initBranchAndLoad,
                      child: const Text('Muat Ulang'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!isOwnerOrAdmin) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          size: 18,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mode Hanya Baca: Pengaturan aturan booking hanya dapat diubah oleh Owner atau Admin.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (branches.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        isExpanded: true,
                        value: _selectedBranchId,
                        items: branches.map((b) {
                          final id = (b['id'] as num).toInt();
                          return DropdownMenuItem<int>(
                            value: id,
                            child: Text(
                              'Cabang: ${b['name']}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.obsidian,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null && val != _selectedBranchId) {
                            setState(() => _selectedBranchId = val);
                            _loadRules(val);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Grace Period Section
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
                      const Text(
                        'GRACE PERIOD PENGAMBILAN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.7,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Batas waktu toleransi keterlambatan pelanggan sebelum booking berstatus lewat jadwal ambil atau No-Show.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _gracePeriodOptions.map((mins) {
                          final isSelected = _gracePeriodMinutes == mins;
                          return ChoiceChip(
                            key: Key('grace_period_chip_$mins'),
                            label: Text('$mins menit'),
                            selected: isSelected,
                            showCheckmark: false,
                            selectedColor: AppColors.obsidian,
                            backgroundColor: AppColors.surfaceMuted,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.obsidian
                                  : AppColors.border,
                            ),
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.obsidian,
                            ),
                            onSelected: isOwnerOrAdmin
                                ? (_) => setState(() => _gracePeriodMinutes = mins)
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Toggles Section
                Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      SwitchListTile.adaptive(
                        key: const Key('toggle_auto_noshow'),
                        value: _autoNoShow,
                        activeColor: AppColors.obsidian,
                        onChanged: isOwnerOrAdmin
                            ? (v) => setState(() => _autoNoShow = v)
                            : null,
                        title: const Text(
                          'Otomatis Tandai No-Show',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                        ),
                        subtitle: const Text(
                          'Batalkan booking otomatis setelah melewati grace period dan kembalikan slot unit ke stok tersedia.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                      const Divider(height: 1, color: AppColors.border),
                      SwitchListTile.adaptive(
                        key: const Key('toggle_floating_unit'),
                        value: _allowFloatingUnit,
                        activeColor: AppColors.obsidian,
                        onChanged: isOwnerOrAdmin
                            ? (v) => setState(() => _allowFloatingUnit = v)
                            : null,
                        title: const Text(
                          'Booking Floating Unit (Tanpa Kunci Unit Awal)',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.obsidian,
                          ),
                        ),
                        subtitle: const Text(
                          'Pelanggan cukup memesan model perangkat; nomor seri/IMEI unit fisik dipilih kasir saat serah terima.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                if (isOwnerOrAdmin)
                  ElevatedButton.icon(
                    key: const Key('save_booking_rules_button'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Menyimpan...' : 'Simpan Aturan Booking',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    onPressed: _isSaving ? null : _saveRules,
                  ),
              ],
            ),
    );
  }
}

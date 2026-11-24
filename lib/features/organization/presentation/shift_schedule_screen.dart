import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/skeleton_loading.dart';
import '../../../../shared/widgets/airy_settings_widgets.dart';
import '../../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../cashier/providers/cashier_provider.dart';

class ShiftScheduleScreen extends ConsumerStatefulWidget {
  const ShiftScheduleScreen({super.key});

  @override
  ConsumerState<ShiftScheduleScreen> createState() => _ShiftScheduleScreenState();
}

class _ShiftScheduleScreenState extends ConsumerState<ShiftScheduleScreen> {
  final _formKey = GlobalKey<FormState>();

  int? _selectedBranchId;
  bool _enforcementEnabled = false;
  TimeOfDay _openingTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _closingTime = const TimeOfDay(hour: 22, minute: 0);
  final _gracePeriodController = TextEditingController(text: '30');

  // Branch override fields
  bool _hasBranchOverride = false;
  TimeOfDay _branchOpeningTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _branchClosingTime = const TimeOfDay(hour: 22, minute: 0);

  bool _isSaving = false;
  bool _isInitialized = false;

  @override
  void dispose() {
    _gracePeriodController.dispose();
    super.dispose();
  }

  void _populateFromSchedule(Map<String, dynamic> data) {
    if (_isInitialized) return;
    _isInitialized = true;

    _enforcementEnabled = data['shift_enforcement_enabled'] == true;

    if (data['shift_opening_time'] is String) {
      _openingTime = _parseTimeOfDay(data['shift_opening_time'] as String) ?? _openingTime;
    }
    if (data['shift_closing_time'] is String) {
      _closingTime = _parseTimeOfDay(data['shift_closing_time'] as String) ?? _closingTime;
    }
    if (data['shift_grace_period_minutes'] != null) {
      _gracePeriodController.text = data['shift_grace_period_minutes'].toString();
    }

    _hasBranchOverride = data['is_branch_override'] == true;
    if (_hasBranchOverride) {
      _branchOpeningTime = _openingTime;
      _branchClosingTime = _closingTime;
    }
  }

  TimeOfDay? _parseTimeOfDay(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);
      if (hour != null && minute != null) {
        return TimeOfDay(hour: hour, minute: minute);
      }
    }
    return null;
  }

  String _formatTimeOfDay(TimeOfDay tod) {
    final h = tod.hour.toString().padLeft(2, '0');
    final m = tod.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickTime({
    required BuildContext context,
    required TimeOfDay initialTime,
    required ValueChanged<TimeOfDay> onSelected,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initialTime,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child ?? const SizedBox(),
        );
      },
    );
    if (picked != null) {
      onSelected(picked);
    }
  }

  Future<void> _saveSchedule() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final repo = ref.read(cashierRepositoryProvider);
      final payload = <String, dynamic>{
        'shift_enforcement_enabled': _enforcementEnabled,
        'shift_opening_time': _formatTimeOfDay(_openingTime),
        'shift_closing_time': _formatTimeOfDay(_closingTime),
        'shift_grace_period_minutes': int.tryParse(_gracePeriodController.text) ?? 30,
      };

      if (_selectedBranchId != null) {
        payload['branch_id'] = _selectedBranchId;
        if (_hasBranchOverride) {
          payload['branch_opening_override'] = _formatTimeOfDay(_branchOpeningTime);
          payload['branch_closing_override'] = _formatTimeOfDay(_branchClosingTime);
        } else {
          payload['branch_opening_override'] = null;
          payload['branch_closing_override'] = null;
        }
      }

      await repo.updateShiftSchedule(payload);

      ref.invalidate(shiftScheduleProvider);
      ref.invalidate(currentShiftProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Jadwal operasional shift berhasil diperbarui.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan jadwal: ${e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '')}'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
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

    final branches = (currentBiz?['branches'] as List<dynamic>?)
            ?.whereType<Map>()
            .map((b) => Map<String, dynamic>.from(b))
            .toList() ??
        [];

    final effectiveBranchId = _selectedBranchId ?? bState.activeBranchId;
    final scheduleAsync = ref.watch(shiftScheduleProvider(effectiveBranchId));

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: const RentCoreAppBar(
        title: 'Jadwal Operasional Shift',
      ),
      bottomNavigationBar: (scheduleAsync.hasValue && isOwnerOrAdmin)
          ? airyStickyFooter(
              child: airyPrimaryCta(
                label: 'Simpan Jadwal Operasional',
                loadingLabel: 'Menyimpan Jadwal...',
                isLoading: _isSaving,
                icon: Icons.check_circle_outline_rounded,
                onPressed: _isSaving ? null : _saveSchedule,
              ),
            )
          : null,
      body: scheduleAsync.when(
        loading: () =>
            const SettingsGroupSkeleton(groupCount: 2, itemsPerGroup: 3),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 12),
                Text(
                  'Gagal memuat jadwal shift:\n$err',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(shiftScheduleProvider),
                  child: const Text('Coba Lagi'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          _populateFromSchedule(data);

          final operationalState =
              data['operational_state']?.toString() ?? 'unknown';
          final statusMessage = data['status_message']?.toString() ?? '-';
          final timezone = data['timezone']?.toString() ?? 'Asia/Jakarta';
          final scheduledOpen =
              data['shift_opening_time']?.toString() ??
              _formatTimeOfDay(_openingTime);
          final scheduledClose =
              data['shift_closing_time']?.toString() ??
              _formatTimeOfDay(_closingTime);
          final graceMinutes =
              data['shift_grace_period_minutes']?.toString() ??
              _gracePeriodController.text;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                // Read-only notice for staff
                if (!isOwnerOrAdmin)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AirySettingsColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AirySettingsColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: AirySettingsColors.obsidian,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Mode Hanya Baca: Pengaturan jadwal operasional shift hanya dapat diubah oleh Owner atau Admin.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AirySettingsColors.inkMuted,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Top Schedule Selector Strip
                if (branches.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Container(
                      height: 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AirySettingsColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AirySettingsColors.border),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          isExpanded: true,
                          value: _selectedBranchId,
                          dropdownColor: AirySettingsColors.canvas,
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AirySettingsColors.inkMuted,
                          ),
                          hint: const Text(
                            'Semua Cabang (Jadwal Utama Bisnis)',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: AirySettingsColors.obsidian,
                            ),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'Jadwal Utama Bisnis (Default)',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AirySettingsColors.obsidian,
                                ),
                              ),
                            ),
                            ...branches.map((b) {
                              return DropdownMenuItem<int?>(
                                value: b['id'] as int?,
                                child: Text(
                                  'Cabang: ${b['name']}',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: AirySettingsColors.obsidian,
                                  ),
                                ),
                              );
                            }),
                          ],
                          onChanged: (val) {
                            setState(() {
                              _selectedBranchId = val;
                              _isInitialized = false;
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                  airyHairlineDivider(),
                ],

                // Operational Status Open Section
                _buildStatusSection(
                  operationalState,
                  statusMessage,
                  timezone,
                  scheduledOpen,
                  scheduledClose,
                  graceMinutes,
                ),
                airyHairlineDivider(),

                // General Shift Schedule Settings Open Section
                _buildScheduleSettingsSection(isOwnerOrAdmin),

                // Branch Override Open Section (Only when a specific branch is selected)
                if (_selectedBranchId != null) ...[
                  airyHairlineDivider(),
                  _buildBranchOverrideSection(isOwnerOrAdmin),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusSection(
    String state,
    String message,
    String timezone,
    String openTime,
    String closeTime,
    String graceMin,
  ) {
    Color pillBg;
    Color pillFg;
    String stateLabel;
    IconData stateIcon;

    switch (state) {
      case 'active':
        pillBg = const Color(0xFFF0FDF4);
        pillFg = const Color(0xFF15803D);
        stateLabel = 'SHIFT SEDANG AKTIF';
        stateIcon = Icons.check_circle_outline_rounded;
        break;
      case 'opening_required':
        pillBg = const Color(0xFFFFFBEB);
        pillFg = const Color(0xFFB45309);
        stateLabel = 'WAJIB BUKA SHIFT';
        stateIcon = Icons.alarm_on_rounded;
        break;
      case 'closed':
        pillBg = AirySettingsColors.pillSurface;
        pillFg = AirySettingsColors.inkMuted;
        stateLabel = 'SHIFT DITUTUP';
        stateIcon = Icons.lock_clock_outlined;
        break;
      case 'disabled':
        pillBg = const Color(0xFFEFF6FF);
        pillFg = const Color(0xFF1D4ED8);
        stateLabel = 'BATASAN NONAKTIF';
        stateIcon = Icons.info_outline_rounded;
        break;
      default:
        pillBg = AirySettingsColors.surfaceSubtle;
        pillFg = AirySettingsColors.obsidian;
        stateLabel = 'BELUM DIBUKA';
        stateIcon = Icons.schedule_rounded;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: airySectionHeader('STATUS OPERASIONAL HARI INI'),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stateIcon, size: 12, color: pillFg),
                    const SizedBox(width: 4),
                    Text(
                      stateLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: pillFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AirySettingsColors.obsidian,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildMetricItem('Jam Buka', openTime)),
              Expanded(child: _buildMetricItem('Jam Tutup', closeTime)),
              Expanded(
                child: _buildMetricItem('Toleransi Tutup', '$graceMin menit'),
              ),
              Expanded(
                child: _buildMetricItem('Zona Waktu', timezone.split('/').last),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            color: AirySettingsColors.inkSecondary,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: AirySettingsColors.obsidian,
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleSettingsSection(bool isEditable) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          airySectionHeader('PENGATURAN UTAMA JADWAL SHIFT'),
          const SizedBox(height: 14),

          // Enforcement Switch
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Wajibkan Batasan Shift Kasir',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AirySettingsColors.obsidian,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Bila aktif, kasir wajib membuka shift di dalam rentang jam operasional sebelum transaksi POS diproses.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AirySettingsColors.inkSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              airySwitch(
                value: _enforcementEnabled,
                onChanged: isEditable
                    ? (val) => setState(() => _enforcementEnabled = val)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 16),
          airyHairlineDivider(),
          const SizedBox(height: 16),

          // Opening and Closing Time
          Row(
            children: [
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Jam Buka Shift',
                  time: _openingTime,
                  isEditable: isEditable,
                  onPick: (t) => setState(() => _openingTime = t),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimePickerTile(
                  label: 'Jam Tutup Shift',
                  time: _closingTime,
                  isEditable: isEditable,
                  onPick: (t) => setState(() => _closingTime = t),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Grace Period Input
          airyFieldLabel('Toleransi Keterlambatan Tutup Shift (Menit) *'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _gracePeriodController,
            enabled: isEditable,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AirySettingsColors.obsidian,
            ),
            decoration: airyInputDecoration(
              hintText: '30',
              enabled: isEditable,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
            ).copyWith(suffixText: 'Menit'),
            validator: (val) {
              if (val == null || val.trim().isEmpty) {
                return 'Toleransi wajib diisi.';
              }
              final num = int.tryParse(val);
              if (num == null || num < 0 || num > 240) {
                return 'Isi antara 0 - 240 menit.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBranchOverrideSection(bool isEditable) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          airySectionHeader('OVERRIDE JADWAL KHUSUS CABANG'),
          const SizedBox(height: 14),
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gunakan Jam Khusus Untuk Cabang Ini',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AirySettingsColors.obsidian,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Cabang ini akan memiliki jam buka dan tutup yang berbeda dari jadwal default bisnis.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AirySettingsColors.inkSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              airySwitch(
                value: _hasBranchOverride,
                onChanged: isEditable
                    ? (val) => setState(() => _hasBranchOverride = val)
                    : null,
              ),
            ],
          ),
          if (_hasBranchOverride) ...[
            const SizedBox(height: 16),
            airyHairlineDivider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTimePickerTile(
                    label: 'Override Jam Buka',
                    time: _branchOpeningTime,
                    isEditable: isEditable,
                    onPick: (t) => setState(() => _branchOpeningTime = t),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimePickerTile(
                    label: 'Override Jam Tutup',
                    time: _branchClosingTime,
                    isEditable: isEditable,
                    onPick: (t) => setState(() => _branchClosingTime = t),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTimePickerTile({
    required String label,
    required TimeOfDay time,
    required bool isEditable,
    required ValueChanged<TimeOfDay> onPick,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        airyFieldLabel(label),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isEditable
              ? () => _pickTime(
                    context: context,
                    initialTime: time,
                    onSelected: onPick,
                  )
              : null,
          child: Container(
            height: 46,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isEditable
                  ? AirySettingsColors.surfaceSubtle
                  : AirySettingsColors.pillSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AirySettingsColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeOfDay(time),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AirySettingsColors.obsidian,
                  ),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: isEditable
                      ? AirySettingsColors.obsidian
                      : AirySettingsColors.inkSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

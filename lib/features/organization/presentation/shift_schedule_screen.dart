import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
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
      backgroundColor: AppColors.background,
      appBar: const RentCoreAppBar(
        title: 'Jadwal Operasional Shift',
      ),
      body: scheduleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                const SizedBox(height: 12),
                Text('Gagal memuat jadwal shift:\n$err', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
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

          final operationalState = data['operational_state']?.toString() ?? 'unknown';
          final statusMessage = data['status_message']?.toString() ?? '-';
          final timezone = data['timezone']?.toString() ?? 'Asia/Jakarta';
          final scheduledOpen = data['shift_opening_time']?.toString() ?? _formatTimeOfDay(_openingTime);
          final scheduledClose = data['shift_closing_time']?.toString() ?? _formatTimeOfDay(_closingTime);
          final graceMinutes = data['shift_grace_period_minutes']?.toString() ?? _gracePeriodController.text;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Read-only notice for staff
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
                        Icon(Icons.lock_rounded, size: 20, color: AppColors.textSecondary),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Mode Hanya Baca: Pengaturan jadwal operasional shift hanya dapat diubah oleh Owner atau Admin.',
                            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Branch Filter Selector (if multiple branches)
                if (branches.length > 1) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int?>(
                        isExpanded: true,
                        value: _selectedBranchId,
                        hint: const Text('Semua Cabang (Jadwal Utama Bisnis)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Jadwal Utama Bisnis (Default)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                          ...branches.map((b) {
                            return DropdownMenuItem<int?>(
                              value: b['id'] as int?,
                              child: Text('Cabang: ${b['name']}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  const SizedBox(height: 16),
                ],

                // Operational Status Card
                _buildStatusCard(operationalState, statusMessage, timezone, scheduledOpen, scheduledClose, graceMinutes),
                const SizedBox(height: 18),

                // General Shift Schedule Settings Card
                _buildScheduleSettingsCard(isOwnerOrAdmin),
                const SizedBox(height: 18),

                // Branch Override Card (Only when a specific branch is selected)
                if (_selectedBranchId != null) ...[
                  _buildBranchOverrideCard(isOwnerOrAdmin),
                  const SizedBox(height: 24),
                ],

                // Save Action Button
                if (isOwnerOrAdmin) ...[
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.obsidian,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: _isSaving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline_rounded, size: 20),
                    label: Text(
                      _isSaving ? 'Menyimpan Jadwal...' : 'Simpan Jadwal Operasional',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: _isSaving ? null : _saveSchedule,
                  ),
                  const SizedBox(height: 32),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    String state,
    String message,
    String timezone,
    String openTime,
    String closeTime,
    String graceMin,
  ) {
    Color stateColor;
    String stateLabel;
    IconData stateIcon;

    switch (state) {
      case 'active':
        stateColor = AppColors.success;
        stateLabel = 'SHIFT SEDANG AKTIF';
        stateIcon = Icons.check_circle_rounded;
        break;
      case 'opening_required':
        stateColor = Colors.orange;
        stateLabel = 'WAJIB BUKA SHIFT';
        stateIcon = Icons.alarm_on_rounded;
        break;
      case 'closed':
        stateColor = AppColors.textMuted;
        stateLabel = 'SHIFT DITUTUP';
        stateIcon = Icons.lock_clock_rounded;
        break;
      case 'disabled':
        stateColor = AppColors.info;
        stateLabel = 'BATASAN NONAKTIF';
        stateIcon = Icons.info_outline_rounded;
        break;
      default:
        stateColor = AppColors.obsidian;
        stateLabel = 'BELUM DIBUKA';
        stateIcon = Icons.schedule_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.timelapse_rounded, size: 18, color: AppColors.obsidian),
                  SizedBox(width: 8),
                  Text(
                    'STATUS OPERASIONAL HARI INI',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: stateColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(stateIcon, size: 12, color: stateColor),
                    const SizedBox(width: 4),
                    Text(
                      stateLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: stateColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(fontSize: 13, height: 1.4, fontWeight: FontWeight.w600, color: AppColors.obsidian),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetricItem('Jam Buka', openTime),
              _buildMetricItem('Jam Tutup', closeTime),
              _buildMetricItem('Toleransi Tutup', '$graceMin menit'),
              _buildMetricItem('Zona Waktu', timezone.split('/').last),
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
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.obsidian)),
      ],
    );
  }

  Widget _buildScheduleSettingsCard(bool isEditable) {
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
            const Text(
              'PENGATURAN UTAMA JADWAL SHIFT',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),

            // Enforcement Switch
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _enforcementEnabled,
              activeColor: AppColors.obsidian,
              title: const Text(
                'Wajibkan Batasan Shift Kasir',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Bila aktif, kasir wajib membuka shift di dalam rentang jam operasional sebelum transaksi POS diproses.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              onChanged: isEditable
                  ? (val) {
                      setState(() => _enforcementEnabled = val);
                    }
                  : null,
            ),
            const Divider(height: 20),

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
            const Text(
              'Toleransi Keterlambatan Tutup Shift (Menit) *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _gracePeriodController,
              enabled: isEditable,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                suffixText: 'Menit',
                hintText: '30',
                filled: true,
                fillColor: isEditable ? AppColors.surface : AppColors.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'Toleransi wajib diisi.';
                final num = int.tryParse(val);
                if (num == null || num < 0 || num > 240) return 'Isi antara 0 - 240 menit.';
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBranchOverrideCard(bool isEditable) {
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
            const Text(
              'OVERRIDE JADWAL KHUSUS CABANG',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              value: _hasBranchOverride,
              activeColor: AppColors.obsidian,
              title: const Text(
                'Gunakan Jam Khusus Untuk Cabang Ini',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Cabang ini akan memiliki jam buka dan tutup yang berbeda dari jadwal default bisnis.',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              onChanged: isEditable
                  ? (val) {
                      setState(() => _hasBranchOverride = val);
                    }
                  : null,
            ),
            if (_hasBranchOverride) ...[
              const Divider(height: 20),
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
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary),
        ),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isEditable ? AppColors.surface : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTimeOfDay(time),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.obsidian),
                ),
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: isEditable ? AppColors.obsidian : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

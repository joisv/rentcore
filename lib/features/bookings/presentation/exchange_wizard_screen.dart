import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/thermal_printer_service.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/thermal_receipt_preview_dialog.dart';
import '../../cashier/providers/cashier_provider.dart';
import '../../printer/providers/printer_provider.dart';
import '../providers/booking_provider.dart';

class ExchangeWizardScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> booking;

  const ExchangeWizardScreen({super.key, required this.booking});

  @override
  ConsumerState<ExchangeWizardScreen> createState() => _ExchangeWizardScreenState();
}

class _ExchangeWizardScreenState extends ConsumerState<ExchangeWizardScreen> {
  int _currentStep = 0; // 0: Diagnosa, 1: Pilih Unit, 2: Biaya & PIN, 3: Selesai

  // Step 1: Diagnostic State
  String _reportedCategory = 'camera';
  final TextEditingController _complaintController = TextEditingController();
  final TextEditingController _diagnosisController = TextEditingController();
  String _oldConditionGrade = 'B';
  bool _icloudSignedOut = false;
  String _oldDisposition = 'maintenance';

  // Step 2: Selected Replacement Device
  Map<String, dynamic>? _selectedCandidate;
  String _candidateFilter = 'all';

  // Step 3: Financial & Authorization State
  bool _feeWaived = false;
  final TextEditingController _waiverReasonController = TextEditingController();
  final TextEditingController _managerPinController = TextEditingController();
  int? _selectedPaymentMethodId;
  double _cashReceived = 0.0;
  final TextEditingController _cashReceivedController = TextEditingController();

  // Execution State
  bool _isLoadingCandidates = true;
  String? _candidateLoadError;
  List<Map<String, dynamic>> _candidates = [];
  Map<String, dynamic>? _currentAssetInfo;
  bool _isSubmitting = false;
  Map<String, dynamic>? _exchangeResult;

  final Map<String, String> _categoryLabels = {
    'camera': 'Kamera / Lensa',
    'screen': 'Layar / Sentuh',
    'battery': 'Baterai / Power',
    'network': 'Sinyal / Wi-Fi',
    'audio': 'Speaker / Mic',
    'system': 'Sistem / OS',
    'other': 'Lainnya',
  };

  bool get _requiresFrpCheck {
    final items = (widget.booking['items'] as List?) ?? [];
    if (items.isEmpty) return true;
    for (final it in items) {
      final model = it['asset']?['model'];
      if (model != null) {
        if (model['requires_frp_check'] == true) return true;
        final brand = (model['brand']?.toString() ?? '').toLowerCase();
        final name = (model['name']?.toString() ?? '').toLowerCase();
        if (brand == 'apple' || brand == 'samsung' || brand == 'google' || brand == 'xiaomi' || brand == 'oppo' || brand == 'vivo') {
          return true;
        }
        if (name.contains('iphone') || name.contains('ipad') || name.contains('galaxy') || name.contains('pixel')) {
          return true;
        }
      }
    }
    return false;
  }

  Map<String, dynamic>? _resolveActiveItem() {
    final items = (widget.booking['items'] as List?) ?? [];
    for (final it in items) {
      if (it is Map && (it['status'] == 'active' || it['status'] == null)) {
        return (it as Map).cast<String, dynamic>();
      }
    }
    if (items.isNotEmpty && items.first is Map) {
      return (items.first as Map).cast<String, dynamic>();
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadAvailableReplacements();
  }

  @override
  void dispose() {
    _complaintController.dispose();
    _diagnosisController.dispose();
    _waiverReasonController.dispose();
    _managerPinController.dispose();
    _cashReceivedController.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableReplacements() async {
    setState(() {
      _isLoadingCandidates = true;
      _candidateLoadError = null;
    });

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final bookingId = widget.booking['id'] ?? widget.booking['booking_id'];

      final activeItem = _resolveActiveItem();
      final activeAssetId = widget.booking['active_asset']?['id'] ??
          activeItem?['asset_id'] ??
          activeItem?['asset']?['id'];

      final data = await repo.fetchAvailableReplacements(bookingId, assetId: activeAssetId);

      if (mounted) {
        setState(() {
          _candidates = ((data['candidates'] as List?) ?? []).cast<Map<String, dynamic>>();
          _currentAssetInfo = data['current_asset'] as Map<String, dynamic>?;
          _isLoadingCandidates = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _candidateLoadError = e.toString();
          _isLoadingCandidates = false;
        });
      }
    }
  }

  double get _calculatedDifferential {
    if (_selectedCandidate == null) return 0.0;
    final diff = (_selectedCandidate!['price_differential'] as num?)?.toDouble() ?? 0.0;
    return diff > 0 ? diff : 0.0;
  }

  double get _payableDifferential {
    if (_feeWaived) return 0.0;
    return _calculatedDifferential;
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final customer = (booking['customer'] as Map?) ?? {};
    final bookingCode = booking['booking_code'] ?? 'Sewa';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: RentCoreAppBar(
        title: 'Tukar Unit: $bookingCode',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang Stok',
            onPressed: _loadAvailableReplacements,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Stepper Header
            _buildStepperHeader(),

            // Content Area
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Info Card: Customer & Current Active Unit
                    _buildCurrentUnitHeader(customer),
                    const SizedBox(height: 16),

                    // Active Step Content
                    if (_currentStep == 0) _buildStep1Diagnostic(),
                    if (_currentStep == 1) _buildStep2SelectCandidate(),
                    if (_currentStep == 2) _buildStep3FinancialAndAuth(),
                    if (_currentStep == 3) _buildStep4HandoverAndReceipt(),
                  ],
                ),
              ),
            ),

            // Bottom Navigation Bar
            if (_currentStep < 3) _buildBottomNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildStepperHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          _buildStepPill(0, '1. Diagnosa'),
          const SizedBox(width: 6),
          _buildStepDivider(),
          const SizedBox(width: 6),
          _buildStepPill(1, '2. Unit Baru'),
          const SizedBox(width: 6),
          _buildStepDivider(),
          const SizedBox(width: 6),
          _buildStepPill(2, '3. Biaya'),
          const SizedBox(width: 6),
          _buildStepDivider(),
          const SizedBox(width: 6),
          _buildStepPill(3, '4. Struk'),
        ],
      ),
    );
  }

  Widget _buildStepPill(int stepIndex, String title) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? AppColors.obsidian
              : isDone
                  ? AppColors.surfaceMuted
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive || isDone ? FontWeight.w700 : FontWeight.w500,
            color: isActive
                ? Colors.white
                : isDone
                    ? AppColors.textPrimary
                    : AppColors.textMuted,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildStepDivider() {
    return Container(
      width: 10,
      height: 1,
      color: AppColors.border,
    );
  }

  Widget _buildCurrentUnitHeader(Map customer) {
    final activeItem = _resolveActiveItem();
    final activeAsset = (widget.booking['active_asset'] as Map?)?.cast<String, dynamic>() ??
        (activeItem?['asset'] as Map?)?.cast<String, dynamic>();
    final model = (activeAsset?['model'] as Map?)?.cast<String, dynamic>();
    final endAt = widget.booking['end_at'] != null ? DateTime.tryParse(widget.booking['end_at']) : null;

    final unitName = _currentAssetInfo?['model_name'] ?? (model != null ? model['name'] : 'Perangkat Sewa');
    final assetCode = _currentAssetInfo?['asset_code'] ??
        (activeAsset != null ? (activeAsset['asset_code'] ?? activeAsset['code']) : '-');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.phonelink_erase_rounded, size: 20, color: AppColors.danger),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'UNIT SEWA YANG DITUKAR (BERMASALAH)',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$unitName ($assetCode)',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.borderSubtle),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pelanggan: ${customer['name'] ?? 'Pelanggan'}',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              StatusBadge(
                label: 'Batas: ${DateFormatter.formatRelative(endAt)}',
                textColor: AppColors.obsidian,
                backgroundColor: AppColors.surfaceMuted,
                borderRadius: 8,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // STEP 1: Diagnosa & Intake
  // ==========================================
  Widget _buildStep1Diagnostic() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Kategori Kendala Hardware / Masalah',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categoryLabels.entries.map((e) {
            final isSelected = _reportedCategory == e.key;
            return ChoiceChip(
              label: Text(e.value),
              selected: isSelected,
              onSelected: (_) => setState(() => _reportedCategory = e.key),
              selectedColor: AppColors.obsidian,
              backgroundColor: AppColors.surface,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 12,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),

        // Customer Complaint Input
        const Text(
          '2. Deskripsi Keluhan Pelanggan',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _complaintController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Contoh: Kamera belakang bergetar saat zoom 1x dan tidak fokus...',
            fillColor: AppColors.surface,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),

        // Staff Diagnostic Notes
        const Text(
          '3. Catatan Diagnosa Tim Konter / Staf',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _diagnosisController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Hasil pemeriksaan fisik staf (opsional)...',
            fillColor: AppColors.surface,
            filled: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        const SizedBox(height: 20),

        // Old Unit Physical Grade & Disposition
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
                'Kondisi Fisik Saat Diterima Kembali',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: ['A', 'B', 'C'].map((grade) {
                  final isSel = _oldConditionGrade == grade;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text('Grade $grade'),
                      selected: isSel,
                      onSelected: (_) => setState(() => _oldConditionGrade = grade),
                      selectedColor: AppColors.obsidian,
                      backgroundColor: AppColors.surfaceMuted,
                      labelStyle: TextStyle(
                        color: isSel ? Colors.white : AppColors.textPrimary,
                        fontSize: 12,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.build_circle_outlined, size: 16, color: AppColors.warning),
                  const SizedBox(width: 6),
                  const Text(
                    'Disposisi: Masuk Karantina / Servis (maintenance)',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // CRITICAL SECURITY GUARD: iCloud / FRP Sign-Out Toggle
        if (_requiresFrpCheck)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _icloudSignedOut ? AppColors.surface : AppColors.dangerLight.withOpacity(0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _icloudSignedOut ? AppColors.border : AppColors.danger),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  _icloudSignedOut ? Icons.check_circle_rounded : Icons.lock_person_rounded,
                  color: _icloudSignedOut ? AppColors.success : AppColors.danger,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pemeriksaan Akun iCloud / FRP (Wajib)',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Pastikan pelanggan telah melakukan Sign Out / Hapus Akun Apple ID / Google FRP dari unit lama sebelum unit pengganti diserahkan.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Material(
                        color: Colors.transparent,
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Akun sudah dikeluarkan (Sign Out)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                          value: _icloudSignedOut,
                          onChanged: (val) => setState(() => _icloudSignedOut = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ==========================================
  // STEP 2: Pilih Unit Pengganti
  // ==========================================
  Widget _buildStep2SelectCandidate() {
    if (_isLoadingCandidates) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Column(
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text('Memeriksa stok unit siap sewa di cabang...'),
            ],
          ),
        ),
      );
    }

    if (_candidateLoadError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.dangerLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text('Gagal memuat unit pengganti: $_candidateLoadError'),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _loadAvailableReplacements,
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      );
    }

    // Filter candidate list
    final filtered = _candidates.where((c) {
      if (_candidateFilter == 'same_tier') return c['tier_category'] == 'same_tier';
      if (_candidateFilter == 'upgrade') return c['tier_category'] == 'upgrade';
      if (_candidateFilter == 'downgrade') return c['tier_category'] == 'downgrade';
      return true;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pilih Perangkat Pengganti dari Stok Cabang',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 4),
        const Text(
          'Sistem otomatis menghitung selisih biaya berdasarkan paket durasi sewa aktif.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 14),

        // Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCandidateFilterChip('Semua (${_candidates.length})', 'all'),
              const SizedBox(width: 8),
              _buildCandidateFilterChip(
                'Tipe Setara (Rp 0)',
                'same_tier',
              ),
              const SizedBox(width: 8),
              _buildCandidateFilterChip(
                'Upgrade (+Biaya)',
                'upgrade',
              ),
              const SizedBox(width: 8),
              _buildCandidateFilterChip(
                'Downgrade',
                'downgrade',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textMuted),
                const SizedBox(height: 10),
                const Text(
                  'Tidak ada unit siap sewa untuk kategori filter ini.',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Coba pilih filter lain atau lakukan mutasi stok antar-cabang.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final c = filtered[index];
              final isSelected = _selectedCandidate?['asset_id'] == c['asset_id'];
              final model = c['model'] ?? {};
              final diff = (c['price_differential'] as num?)?.toDouble() ?? 0.0;
              final tierCat = c['tier_category'] ?? 'same_tier';

              return GestureDetector(
                onTap: () => setState(() => _selectedCandidate = c),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.surfaceMuted : AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? AppColors.obsidian : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Radio<int>(
                        value: c['asset_id'],
                        groupValue: _selectedCandidate?['asset_id'],
                        onChanged: (_) => setState(() => _selectedCandidate = c),
                        activeColor: AppColors.obsidian,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    model['name'] ?? 'Perangkat',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                                  ),
                                ),
                                _buildTierBadge(tierCat, diff),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Kode: ${c['asset_code']} • SN: ${c['serial_number'] ?? '-'}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Grade ${c['condition_grade']} • Bat: ${c['battery_health'] ?? 100}%',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                                ),
                                const Spacer(),
                                Text(
                                  CurrencyFormatter.format(c['calculated_rate']),
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCandidateFilterChip(String label, String value) {
    final isSel = _candidateFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSel,
      onSelected: (_) => setState(() => _candidateFilter = value),
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surface,
      labelStyle: TextStyle(
        color: isSel ? Colors.white : AppColors.textPrimary,
        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
    );
  }

  Widget _buildTierBadge(String tierCat, double diff) {
    if (tierCat == 'same_tier' || diff == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Setara (Rp 0)',
          style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
    }
    if (tierCat == 'upgrade') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Upgrade (+${CurrencyFormatter.format(diff)})',
          style: const TextStyle(color: AppColors.info, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Downgrade (${CurrencyFormatter.format(diff)})',
        style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 11),
      ),
    );
  }

  // ==========================================
  // STEP 3: Rincian Biaya & Otorisasi
  // ==========================================
  Widget _buildStep3FinancialAndAuth() {
    final currentItemRate = (_currentAssetInfo?['unit_price'] as num?)?.toDouble() ?? 0.0;
    final replacementRate = (_selectedCandidate?['calculated_rate'] as num?)?.toDouble() ?? 0.0;
    final diff = _calculatedDifferential;
    final payable = _payableDifferential;

    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rincian Biaya Penggantian Unit',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const SizedBox(height: 12),

        // Financial Breakdown Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              _buildBillingRow('Tarif Unit Lama (Paket Berjalan)', CurrencyFormatter.format(currentItemRate)),
              const SizedBox(height: 8),
              _buildBillingRow(
                'Tarif Unit Baru (${_selectedCandidate?['model']?['name'] ?? 'Unit Baru'})',
                CurrencyFormatter.format(replacementRate),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 10),
              _buildBillingRow(
                'Selisih Tarif Kotor',
                diff > 0 ? '+${CurrencyFormatter.format(diff)}' : 'Rp 0 (Setara)',
                isBold: true,
              ),
              if (_feeWaived) ...[
                const SizedBox(height: 8),
                _buildBillingRow('Pembebasan Biaya (Courtesy Waiver)', '-${CurrencyFormatter.format(diff)}', textColor: AppColors.success),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.borderSubtle),
              const SizedBox(height: 10),
              _buildBillingRow(
                'TOTAL WAJIB DIBAYAR KASIR',
                CurrencyFormatter.format(payable),
                isBold: true,
                textColor: payable > 0 ? AppColors.obsidian : AppColors.success,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Courtesy Fee Waiver Checkbox
        if (diff > 0) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Bebaskan Biaya Selisih (Kompensasi / Kebijakan Toko)',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
                subtitle: const Text(
                  'Memerlukan otorisasi PIN Manager Toko.',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
                value: _feeWaived,
                onChanged: (val) => setState(() => _feeWaived = val ?? false),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Manager PIN Input if fee waived
        if (_feeWaived) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warningLight.withOpacity(0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.warning),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppColors.warning),
                    SizedBox(width: 8),
                    Text(
                      'Otorisasi Manager Diperlukan',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _waiverReasonController,
                  decoration: InputDecoration(
                    labelText: 'Alasan Pembebasan Biaya',
                    hintText: 'Contoh: Kompensasi stok unit sama habis...',
                    fillColor: AppColors.surface,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _managerPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'PIN Manager Override',
                    hintText: 'Masukkan 6 digit PIN Manager',
                    fillColor: AppColors.surface,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Payment Method & Cash Calculator (if payable > 0)
        if (payable > 0) ...[
          const Text(
            'Metode Pembayaran Kasir',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          paymentMethodsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Gagal memuat metode pembayaran: $e'),
            data: (methods) {
              if (methods.isEmpty) {
                return const Text('Tidak ada metode pembayaran aktif.');
              }
              if (_selectedPaymentMethodId == null && methods.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  setState(() => _selectedPaymentMethodId = methods.first['id']);
                });
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedPaymentMethodId,
                    isExpanded: true,
                    items: methods.map((m) {
                      return DropdownMenuItem<int>(
                        value: m['id'],
                        child: Text('${m['name']} (${m['code']})'),
                      );
                    }).toList(),
                    onChanged: (id) => setState(() => _selectedPaymentMethodId = id),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Quick Cash Received Input
          TextField(
            controller: _cashReceivedController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Uang Tunai Diterima (Rp)',
              hintText: '0',
              fillColor: AppColors.surface,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onChanged: (val) {
              setState(() {
                _cashReceived = double.tryParse(val) ?? 0.0;
              });
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCashChip('Pas (Rp ${CurrencyFormatter.format(payable)})', payable),
              const SizedBox(width: 8),
              _buildCashChip('Rp 50.000', 50000.0),
              const SizedBox(width: 8),
              _buildCashChip('Rp 100.000', 100000.0),
            ],
          ),
          if (_cashReceived >= payable && payable > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.successLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Kembalian Tunai:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(
                    CurrencyFormatter.format(_cashReceived - payable),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppColors.success),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildBillingRow(String label, String value, {bool isBold = false, Color? textColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
              color: textColor ?? AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: textColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildCashChip(String label, double amount) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _cashReceived = amount;
          _cashReceivedController.text = amount.toInt().toString();
        });
      },
      backgroundColor: AppColors.surfaceMuted,
    );
  }

  // ==========================================
  // STEP 4: Konfirmasi & Struk
  // ==========================================
  Widget _buildStep4HandoverAndReceipt() {
    final receiptData = _exchangeResult?['receipt_data'] as Map<String, dynamic>?;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.successLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              const Icon(Icons.check_circle_rounded, size: 48, color: AppColors.success),
              const SizedBox(height: 10),
              const Text(
                'Penggantian Unit Selesai!',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Unit lama telah dipindahkan ke karantina/servis dan unit baru telah aktif dalam sistem.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Handover Transition Card
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
                'Rincian Transisi Perangkat:',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
              const SizedBox(height: 12),
              _buildHandoverRow('Unit Lama', receiptData?['old_asset_name'] ?? '-', 'Masuk Karantina', AppColors.danger),
              const SizedBox(height: 10),
              _buildHandoverRow('Unit Baru', receiptData?['new_asset_name'] ?? '-', 'Aktif Disewa', AppColors.success),
              const SizedBox(height: 10),
              _buildHandoverRow('Batas Sewa Tetap', receiptData?['end_at'] ?? '-', 'Jadwal Normal', AppColors.info),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Print Thermal Receipt Button
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.obsidian,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.print_rounded, color: Colors.white),
          label: const Text(
            'Cetak Struk Penggantian Unit',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
          onPressed: () => _printExchangeReceipt(receiptData),
        ),
        const SizedBox(height: 12),

        // Finish & Return to Bookings Button
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: () {
            ref.invalidate(bookingsListProvider);
            Navigator.pop(context, _exchangeResult ?? true);
          },
          child: const Text('Selesai & Kembali ke Antrean Sewa'),
        ),
      ],
    );
  }

  Widget _buildHandoverRow(String label, String value, String tag, Color tagColor) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: tagColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            tag,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: tagColor),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // Bottom Action Bar
  // ==========================================
  Widget _buildBottomNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => setState(() => _currentStep--),
                child: const Text('Kembali'),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: AppColors.obsidian,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isSubmitting ? null : _handleNextStep,
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 2 ? 'Konfirmasi Tukar Unit' : 'Lanjut ➔',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleNextStep() {
    if (_currentStep == 0) {
      if (_complaintController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap masukkan deskripsi keluhan pelanggan.')),
        );
        return;
      }
      if (_requiresFrpCheck && !_icloudSignedOut) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Akun iCloud / FRP wajib dipastikan sudah Sign Out sebelum lanjut.')),
        );
        return;
      }
      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_selectedCandidate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Harap pilih salah satu unit pengganti terlebih dahulu.')),
        );
        return;
      }
      setState(() => _currentStep = 2);
    } else if (_currentStep == 2) {
      _executeExchangeSubmission();
    }
  }

  Future<void> _executeExchangeSubmission() async {
    final payable = _payableDifferential;
    if (payable > 0 && _selectedPaymentMethodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap pilih metode pembayaran selisih tukar unit.')),
      );
      return;
    }
    if (_feeWaived && _managerPinController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harap masukkan PIN Manager untuk pembebasan biaya.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(bookingRepositoryProvider);
      final bookingId = widget.booking['id'] ?? widget.booking['booking_id'];

      final activeItem = _resolveActiveItem();
      final activeAssetId = widget.booking['active_asset']?['id'] ??
          activeItem?['asset_id'] ??
          activeItem?['asset']?['id'];

      final oldAssetId = _currentAssetInfo?['asset_id'] ?? activeAssetId;

      final payload = {
        'old_asset_id': oldAssetId,
        'new_asset_id': _selectedCandidate!['asset_id'],
        'reported_issue_category': _reportedCategory,
        'customer_complaint': _complaintController.text.trim(),
        'staff_diagnosis': _diagnosisController.text.trim().isNotEmpty ? _diagnosisController.text.trim() : null,
        'old_unit_condition_grade': _oldConditionGrade,
        'icloud_signout_verified': _icloudSignedOut,
        'old_asset_disposition': _oldDisposition,
        'fee_waived': _feeWaived,
        'waiver_reason': _feeWaived ? _waiverReasonController.text.trim() : null,
        'manager_pin': _feeWaived ? _managerPinController.text.trim() : null,
        'payment_method_id': payable > 0 ? _selectedPaymentMethodId : null,
        'cash_received': payable > 0 ? _cashReceived : null,
      };

      final result = await repo.exchangeRentalUnit(bookingId, payload);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _exchangeResult = result;
          _currentStep = 3;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Gagal melakukan tukar unit: $e'),
          ),
        );
      }
    }
  }

  void _printExchangeReceipt(Map<String, dynamic>? receiptData) {
    if (receiptData == null) return;

    final printerState = ref.read(printerProvider);
    final printerService = ThermalPrinterService();
    final settings = printerState.settings;

    final doc = ReceiptDataModel(
      type: ReceiptType.rentalExchange,
      title: 'BUKTI PENGGANTIAN UNIT',
      branchName: receiptData['branch_name'] ?? 'Cabang',
      receiptNumber: receiptData['receipt_number'],
      bookingCode: receiptData['booking_code'],
      customerName: receiptData['customer_name'],
      customerPhone: receiptData['customer_phone'],
      cashierName: receiptData['cashier_name'],
      oldUnitName: receiptData['old_asset_name'],
      oldUnitSerial: receiptData['old_asset_serial'] ?? receiptData['old_asset_code'],
      exchangeReason: receiptData['reported_issue'],
      unitName: receiptData['new_asset_name'],
      unitSerial: receiptData['new_asset_serial'] ?? receiptData['new_asset_code'],
      rentalEndDate: receiptData['end_at'],
      priceDifferential: (receiptData['price_differential'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (receiptData['price_differential'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: receiptData['payment_method'],
      cashReceived: (receiptData['cash_received'] as num?)?.toDouble(),
      cashChange: (receiptData['cash_change'] as num?)?.toDouble(),
    );

    final printDoc = printerService.buildReceiptDocument(doc, settings);
    final escposBytes = printerService.buildSlipBytesFromDocument(printDoc, settings);

    showDialog(
      context: context,
      builder: (_) => ThermalReceiptPreviewDialog(
        title: 'Bukti Penggantian Unit',
        branchName: doc.branchName,
        escposBytes: escposBytes,
        qrData: doc.bookingCode,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'BUKTI PENGGANTIAN UNIT',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text('No. Struk : ${doc.receiptNumber ?? '-'}', style: const TextStyle(fontSize: 11)),
            Text('No. Sewa  : ${doc.bookingCode ?? '-'}', style: const TextStyle(fontSize: 11)),
            Text('Pelanggan : ${doc.customerName ?? '-'}', style: const TextStyle(fontSize: 11)),
            const Divider(height: 16),
            const Text('UNIT LAMA (DIKEMBALIKAN):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
            Text(doc.oldUnitName ?? '-', style: const TextStyle(fontSize: 12)),
            if (doc.exchangeReason != null)
              Text('Kendala: ${doc.exchangeReason}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            const Divider(height: 16),
            const Text('UNIT BARU (PENGGANTI):', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
            Text(doc.unitName ?? '-', style: const TextStyle(fontSize: 12)),
            Text('Batas Sewa Tetap: ${doc.rentalEndDate ?? '-'}', style: const TextStyle(fontSize: 11)),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('SELISIH BIAYA', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                Text(
                  (doc.priceDifferential ?? 0) > 0 ? CurrencyFormatter.format(doc.priceDifferential!) : 'Rp 0 (Setara)',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
              ],
            ),
            if (doc.paymentMethod != null)
              Text('Metode: ${doc.paymentMethod}', style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

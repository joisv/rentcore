import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/collateral_helper.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';

class CollateralSettingsScreen extends ConsumerStatefulWidget {
  final bool isReadOnly;

  const CollateralSettingsScreen({
    super.key,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<CollateralSettingsScreen> createState() =>
      _CollateralSettingsScreenState();
}

class _CollateralSettingsScreenState
    extends ConsumerState<CollateralSettingsScreen> {
  late bool _enableCollateral;
  late bool _requireCollateral;
  late List<CollateralTypeOption> _types;
  bool _initializedFromState = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final biz = ref.read(businessProvider).currentBusiness;
    _enableCollateral = resolveEnableCollateral(biz);
    _requireCollateral = resolveRequireCollateral(biz);
    _types = resolveBusinessCollateralTypes(biz);
    _initializedFromState = true;
    _fetchLatest();
  }

  Future<void> _fetchLatest() async {
    final bizId = ref.read(businessProvider).activeBusinessId;
    if (bizId == null) return;
    try {
      final data =
          await ref.read(authRepositoryProvider).getCollateralSettings(bizId);
      if (!mounted || data.isEmpty) return;
      setState(() {
        _enableCollateral = resolveEnableCollateral(data);
        _requireCollateral = resolveRequireCollateral(data);
        _types = resolveBusinessCollateralTypes(data);
      });
    } catch (_) {
      // Keep locally resolved state when offline or inside mocked tests.
    }
  }

  int get _activeCount => _types.where((t) => t.isActive).length;

  void _toggleTypeActive(int index, bool nextVal) {
    if (!nextVal && _enableCollateral && _requireCollateral && _activeCount <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Minimal 1 tipe jaminan harus aktif selama Wajibkan Jaminan diaktifkan.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    setState(() {
      _types[index] = _types[index].copyWith(isActive: nextVal);
    });
  }

  Future<void> _openAddOrEditSheet({
    CollateralTypeOption? existing,
    int? index,
  }) async {
    final result = await showModalBottomSheet<CollateralTypeOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CollateralTypeFormSheet(existing: existing),
    );
    if (result == null || !mounted) return;

    setState(() {
      if (index != null) {
        _types[index] = result;
      } else {
        var candidateId = result.id;
        var suffix = 2;
        while (_types.any((t) => t.id == candidateId)) {
          candidateId = '${result.id}_$suffix';
          suffix++;
        }
        _types.add(result.copyWith(id: candidateId));
      }
    });
  }

  Future<void> _saveSettings() async {
    if (_enableCollateral && _requireCollateral && _activeCount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Minimal 1 tipe jaminan harus aktif saat Wajibkan Jaminan aktif.',
          ),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final bizId = ref.read(businessProvider).activeBusinessId;
    if (bizId == null) return;

    setState(() => _isSaving = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final serialized = _types.map((t) => t.toJson()).toList();
      await ref.read(authRepositoryProvider).updateCollateralSettings(
            bizId,
            enableCollateral: _enableCollateral,
            requireCollateral: _requireCollateral,
            collateralTypes: serialized,
          );
      await ref.read(businessProvider.notifier).refresh();
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pengaturan jaminan & deposit berhasil disimpan.'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyimpan pengaturan jaminan: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bState = ref.watch(businessProvider);
    final user = ref.watch(authProvider).user;
    final currentBiz = bState.currentBusiness;
    if (!_initializedFromState && currentBiz != null) {
      _enableCollateral = resolveEnableCollateral(currentBiz);
      _requireCollateral = resolveRequireCollateral(currentBiz);
      _types = resolveBusinessCollateralTypes(currentBiz);
      _initializedFromState = true;
    }

    final role = (currentBiz?['role'] ?? user?['role'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final isSuperAdmin =
        user?['is_platform_admin'] == true || role == 'super_admin';
    final canEdit =
        !widget.isReadOnly && (role == 'owner' || role == 'admin' || isSuperAdmin);

    return Scaffold(
      backgroundColor: AirySettingsColors.canvas,
      appBar: const RentCoreAppBar(title: 'Jaminan & Deposit'),
      bottomNavigationBar: canEdit
          ? airyStickyFooter(
              child: airyPrimaryCta(
                buttonKey: const Key('save_collateral_settings_button'),
                label: 'Simpan Pengaturan',
                isLoading: _isSaving,
                icon: Icons.check_circle_outline_rounded,
                onPressed: _isSaving ? null : _saveSettings,
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (!canEdit)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AirySettingsColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AirySettingsColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AirySettingsColors.inkSecondary,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mode lihat saja. Hubungi Owner atau Admin untuk mengubah aturan jaminan.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AirySettingsColors.inkMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Master Toggle: Enable / Disable Collateral & Deposit Feature
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 16, 18),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aktifkan Fitur Jaminan & Deposit',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AirySettingsColors.obsidian,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Tampilkan pilihan jaminan dokumen atau deposit tunai saat kasir mencatat sewa.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AirySettingsColors.inkSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                airySwitch(
                  key: const Key('switch_enable_collateral'),
                  value: _enableCollateral,
                  onChanged: canEdit
                      ? (val) => setState(() => _enableCollateral = val)
                      : null,
                ),
              ],
            ),
          ),

          if (!_enableCollateral)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: Container(
                key: const Key('collateral_disabled_status_strip'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AirySettingsColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AirySettingsColors.border),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      size: 18,
                      color: AirySettingsColors.inkSecondary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Fitur jaminan & deposit saat ini dimatikan. Kasir dapat memproses transaksi tanpa kolom jaminan.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AirySettingsColors.inkMuted,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            const Divider(
              height: 1,
              thickness: 1,
              indent: 20,
              endIndent: 20,
              color: AirySettingsColors.divider,
            ),

            // Secondary Policy Toggle: Require Collateral
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Wajibkan Jaminan Saat Sewa',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AirySettingsColors.obsidian,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Jika nonaktif, kasir dapat memilih "Tanpa Jaminan" saat transaksi.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AirySettingsColors.inkSecondary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  airySwitch(
                    key: const Key('switch_require_collateral'),
                    value: _requireCollateral,
                    onChanged: canEdit
                        ? (val) => setState(() => _requireCollateral = val)
                        : null,
                  ),
                ],
              ),
            ),

            Container(height: 8, color: AirySettingsColors.surfaceSubtle),

            // Configured Collateral Types Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'TIPE JAMINAN TERSEDIA',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AirySettingsColors.inkSecondary,
                    ),
                  ),
                  if (canEdit)
                    TextButton.icon(
                      key: const Key('add_collateral_type_button'),
                      onPressed: () => _openAddOrEditSheet(),
                      style: TextButton.styleFrom(
                        foregroundColor: AirySettingsColors.obsidian,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 17),
                      label: const Text(
                        'Tambah Tipe Kustom',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            for (int i = 0; i < _types.length; i++) ...[
              Builder(
                builder: (context) {
                  final item = _types[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: item.isActive
                                      ? AirySettingsColors.obsidian
                                      : AirySettingsColors.inkSecondary,
                                ),
                              ),
                              const SizedBox(height: 5),
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
                                  CollateralInputMode.label(item.inputMode),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AirySettingsColors.inkMuted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (canEdit)
                          IconButton(
                            key: Key('edit_collateral_type_${item.id}'),
                            icon: const Icon(
                              Icons.edit_outlined,
                              size: 19,
                              color: AirySettingsColors.inkSecondary,
                            ),
                            tooltip: 'Ubah Tipe Jaminan',
                            onPressed: () =>
                                _openAddOrEditSheet(existing: item, index: i),
                          ),
                        const SizedBox(width: 4),
                        airySwitch(
                          key: Key('switch_collateral_type_${item.id}'),
                          value: item.isActive,
                          onChanged: canEdit
                              ? (val) => _toggleTypeActive(i, val)
                              : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
              if (i < _types.length - 1)
                const Divider(
                  height: 1,
                  thickness: 1,
                  indent: 20,
                  endIndent: 20,
                  color: AirySettingsColors.divider,
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CollateralTypeFormSheet extends StatefulWidget {
  final CollateralTypeOption? existing;

  const _CollateralTypeFormSheet({this.existing});

  @override
  State<_CollateralTypeFormSheet> createState() =>
      _CollateralTypeFormSheetState();
}

class _CollateralTypeFormSheetState extends State<_CollateralTypeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late String _selectedMode;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _selectedMode =
        widget.existing?.inputMode ?? CollateralInputMode.vaultSlot;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    final id = widget.existing?.id ??
        name
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'^_+|_+$'), '');

    Navigator.of(context).pop(
      CollateralTypeOption(
        id: id.isNotEmpty ? id : 'custom_collateral',
        name: name,
        inputMode: _selectedMode,
        isActive: widget.existing?.isActive ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Tipe Jaminan' : 'Tambah Tipe Jaminan',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AirySettingsColors.obsidian,
                ),
              ),
              const SizedBox(height: 16),
              airyFieldLabel('Nama Tipe Jaminan'),
              const SizedBox(height: 6),
              TextFormField(
                key: const Key('collateral_type_name_input'),
                controller: _nameController,
                style: const TextStyle(
                  fontSize: 14,
                  color: AirySettingsColors.obsidian,
                ),
                decoration: airyInputDecoration(
                  hintText: 'Contoh: Paspor, Kartu Keluarga',
                ),
                validator: (v) {
                  if (v == null || v.trim().length < 2) {
                    return 'Nama tipe jaminan wajib diisi (min. 2 karakter)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              airyFieldLabel('Mode Pencatatan'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: CollateralInputMode.editableModes.map((mode) {
                  final selected = _selectedMode == mode;
                  return ChoiceChip(
                    key: Key('collateral_mode_chip_$mode'),
                    label: Text(CollateralInputMode.label(mode)),
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: AirySettingsColors.obsidian,
                    backgroundColor: AirySettingsColors.canvas,
                    side: BorderSide(
                      color: selected
                          ? AirySettingsColors.obsidian
                          : AirySettingsColors.border,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelStyle: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? Colors.white
                          : AirySettingsColors.inkMuted,
                    ),
                    onSelected: (_) => setState(() => _selectedMode = mode),
                  );
                }).toList(),
              ),
              const SizedBox(height: 22),
              airyPrimaryCta(
                buttonKey: const Key('confirm_collateral_type_button'),
                label: isEditing ? 'Simpan Perubahan' : 'Tambahkan',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

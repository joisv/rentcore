import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/utils/collateral_helper.dart';
import 'airy_settings_widgets.dart';

/// Shared Airy Minimalist collateral type pills & dynamic detail input shared
/// across DirectRentalScreen (Step 2) and Handover Sheet.
class CollateralPickerSection extends StatelessWidget {
  final List<CollateralTypeOption> activeTypes;
  final bool requireCollateral;
  final String selectedTypeId;
  final ValueChanged<String> onTypeSelected;

  // Input mode controls
  final bool useVaultDropdown;
  final List<String> vaultSlots;
  final String? selectedVaultSlot;
  final ValueChanged<String?>? onVaultSlotChanged;
  final TextEditingController vaultOrNoteController;
  final TextEditingController depositController;
  final bool isOptionalDetail;
  final Key? vaultDropdownKey;
  final Key? vaultOrNoteFieldKey;
  final Key? depositFieldKey;

  const CollateralPickerSection({
    super.key,
    required this.activeTypes,
    required this.requireCollateral,
    required this.selectedTypeId,
    required this.onTypeSelected,
    required this.vaultOrNoteController,
    required this.depositController,
    this.useVaultDropdown = false,
    this.vaultSlots = const [],
    this.selectedVaultSlot,
    this.onVaultSlotChanged,
    this.isOptionalDetail = false,
    this.vaultDropdownKey,
    this.vaultOrNoteFieldKey,
    this.depositFieldKey,
  });

  CollateralTypeOption? get _selectedOption {
    if (selectedTypeId == CollateralInputMode.none) return null;
    for (final opt in activeTypes) {
      if (opt.id == selectedTypeId) return opt;
    }
    return activeTypes.isNotEmpty ? activeTypes.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final currentOption = _selectedOption;
    final effectiveMode = selectedTypeId == CollateralInputMode.none
        ? CollateralInputMode.none
        : (currentOption?.inputMode ?? CollateralInputMode.vaultSlot);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          isOptionalDetail ? 'Tipe Jaminan' : 'Tipe Jaminan *',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AirySettingsColors.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final opt in activeTypes)
              _buildTypePill(
                key: Key('collateral_type_pill_${opt.id}'),
                label: opt.name,
                isSelected: selectedTypeId == opt.id,
                onTap: () => onTypeSelected(opt.id),
              ),
            if (!requireCollateral)
              _buildTypePill(
                key: const Key('collateral_type_pill_none'),
                label: 'Tanpa Jaminan',
                isSelected: selectedTypeId == CollateralInputMode.none,
                onTap: () => onTypeSelected(CollateralInputMode.none),
              ),
          ],
        ),
        if (effectiveMode != CollateralInputMode.none) ...[
          const SizedBox(height: 14),
          if (effectiveMode == CollateralInputMode.vaultSlot) ...[
            airyFieldLabel(
              isOptionalDetail
                  ? 'Slot Brankas Jaminan'
                  : 'Slot Brankas Jaminan *',
            ),
            const SizedBox(height: 6),
            if (useVaultDropdown && vaultSlots.isNotEmpty)
              DropdownButtonFormField<String>(
                key: vaultDropdownKey,
                initialValue: (selectedVaultSlot != null &&
                        vaultSlots.contains(selectedVaultSlot))
                    ? selectedVaultSlot
                    : vaultSlots.first,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AirySettingsColors.inkSecondary,
                  size: 20,
                ),
                decoration: airyInputDecoration(
                  prefixIcon: const Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: AirySettingsColors.inkSecondary,
                  ),
                ),
                isExpanded: true,
                items: vaultSlots
                    .map(
                      (slot) => DropdownMenuItem<String>(
                        value: slot,
                        child: Text(
                          slot,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AirySettingsColors.obsidian,
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onVaultSlotChanged,
                validator: (v) {
                  if (!isOptionalDetail && (v == null || v.trim().isEmpty)) {
                    return 'Slot brankas jaminan wajib dipilih';
                  }
                  return null;
                },
              )
            else
              TextFormField(
                key: vaultOrNoteFieldKey,
                controller: vaultOrNoteController,
                style: const TextStyle(
                  fontSize: 14,
                  color: AirySettingsColors.obsidian,
                ),
                decoration: airyInputDecoration(
                  hintText: 'Contoh: Brankas A, Slot 05',
                  prefixIcon: const Icon(
                    Icons.shield_outlined,
                    size: 20,
                    color: AirySettingsColors.inkSecondary,
                  ),
                ),
                validator: (v) {
                  if (!isOptionalDetail && (v == null || v.trim().isEmpty)) {
                    return 'Slot brankas jaminan wajib diisi';
                  }
                  return null;
                },
              ),
          ] else if (effectiveMode == CollateralInputMode.cashDeposit) ...[
            airyFieldLabel(
              isOptionalDetail
                  ? 'Nominal Deposit Tunai (Rp)'
                  : 'Nominal Deposit Tunai (Rp) *',
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: depositFieldKey ?? const Key('collateral_deposit_amount_input'),
              controller: depositController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(
                fontSize: 14,
                color: AirySettingsColors.obsidian,
              ),
              decoration: airyInputDecoration(
                hintText: 'Contoh: 200000',
                prefixIcon: const Icon(
                  Icons.payments_outlined,
                  size: 20,
                  color: AirySettingsColors.inkSecondary,
                ),
              ),
              validator: (v) {
                if (!isOptionalDetail) {
                  final val = double.tryParse(v?.trim() ?? '');
                  if (val == null || val <= 0) {
                    return 'Nominal deposit tunai wajib lebih dari 0';
                  }
                }
                return null;
              },
            ),
          ] else if (effectiveMode == CollateralInputMode.noteOnly) ...[
            airyFieldLabel(
              isOptionalDetail
                  ? 'Nomor / Keterangan Jaminan'
                  : 'Nomor / Keterangan Jaminan *',
            ),
            const SizedBox(height: 6),
            TextFormField(
              key: vaultOrNoteFieldKey ?? const Key('collateral_note_input'),
              controller: vaultOrNoteController,
              style: const TextStyle(
                fontSize: 14,
                color: AirySettingsColors.obsidian,
              ),
              decoration: airyInputDecoration(
                hintText: 'Contoh: NIM / No. Kartu',
                prefixIcon: const Icon(
                  Icons.badge_outlined,
                  size: 20,
                  color: AirySettingsColors.inkSecondary,
                ),
              ),
              validator: (v) {
                if (!isOptionalDetail && (v == null || v.trim().isEmpty)) {
                  return 'Nomor atau keterangan jaminan wajib diisi';
                }
                return null;
              },
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildTypePill({
    Key? key,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AirySettingsColors.obsidian : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? AirySettingsColors.obsidian
                : AirySettingsColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AirySettingsColors.inkMuted,
          ),
        ),
      ),
    );
  }
}

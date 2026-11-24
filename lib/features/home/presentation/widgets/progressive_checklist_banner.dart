import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/business_provider.dart';
import '../../../inventory/presentation/add_product_sheet.dart';
import '../../../inventory/presentation/inventory_screen.dart';
import '../../../onboarding/providers/onboarding_provider.dart';
import '../../../organization/presentation/payment_method_settings_screen.dart';

/// Compact, dismissible Airy Minimalist setup checklist displayed above the KPI
/// matrix on [HomeScreen] for Store Owners until all 3 starter steps are done
/// or dismissed for the active business.
class ProgressiveChecklistBanner extends ConsumerWidget {
  final int totalModelCount;
  final int totalAssetCount;
  final VoidCallback? onOpenCreateModel;
  final VoidCallback? onOpenInventory;

  const ProgressiveChecklistBanner({
    super.key,
    this.totalModelCount = 0,
    this.totalAssetCount = 0,
    this.onOpenCreateModel,
    this.onOpenInventory,
  });

  bool _isPaymentOrQrisConfigured(
    Map<String, dynamic> currentBiz,
    Map<String, dynamic>? activeBranch,
  ) {
    final bizConfig = currentBiz['payment_methods_config'] is Map
        ? Map<String, dynamic>.from(currentBiz['payment_methods_config'] as Map)
        : <String, dynamic>{};
    final branchOverride = activeBranch?['payment_methods_config_override'];
    if (branchOverride is Map) {
      branchOverride.forEach((k, v) => bizConfig[k.toString()] = v);
    }

    final rawPayload =
        (bizConfig['qris_raw_payload'] ??
                activeBranch?['qris_raw_payload'] ??
                currentBiz['qris_raw_payload'] ??
                '')
            .toString()
            .trim();
    final qrisImage =
        (bizConfig['qris_image_url'] ??
                bizConfig['qris_image_path'] ??
                activeBranch?['qris_image_url'] ??
                currentBiz['qris_image_url'] ??
                '')
            .toString()
            .trim();
    final hasQrisEnabled =
        bizConfig['is_qris_enabled'] == true ||
        bizConfig['qris_statis_enabled'] == true ||
        bizConfig['is_dynamic_qris_enabled'] == true ||
        activeBranch?['is_dynamic_qris_enabled'] == true;

    return rawPayload.isNotEmpty || qrisImage.isNotEmpty || hasQrisEnabled;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessState = ref.watch(businessProvider);
    final onboardingState = ref.watch(onboardingProvider);
    final currentBiz = businessState.currentBusiness;

    if (currentBiz == null || onboardingState.isChecklistDismissed) {
      return const SizedBox.shrink();
    }

    // Checklist applies strictly to Owners (never shown to staff/cashier roles)
    final role = (currentBiz['role'] ?? 'owner').toString().trim().toLowerCase();
    if (role != 'owner') {
      return const SizedBox.shrink();
    }

    final bizId = businessState.activeBusinessId;
    final hasModels = totalModelCount > 0 || totalAssetCount > 0;
    final hasUnits = totalAssetCount > 0;
    final hasPaymentOrQris =
        _isPaymentOrQrisConfigured(currentBiz, businessState.currentBranch);

    final completedCount = [
      hasModels,
      hasUnits,
      hasPaymentOrQris,
    ].where((c) => c).length;

    // Automatically hide once all 3 onboarding steps are complete
    if (completedCount >= 3) {
      return const SizedBox.shrink();
    }

    final progressPercent = completedCount / 3.0;

    return Container(
      key: const Key('owner_setup_checklist_card'),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Panduan Persiapan Toko',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$completedCount dari 3 langkah selesai',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Color(0xFF0F172A),
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  key: const Key('checklist_dismiss_button'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    if (bizId != null) {
                      ref
                          .read(onboardingProvider.notifier)
                          .dismissChecklist(bizId);
                    }
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          Icons.close_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          _buildChecklistItem(
            itemKey: const Key('checklist_step_create_model'),
            title: 'Buat Model & Tarif Pertama',
            subtitle: 'Tentukan nama unit dan tarif sewa harian atau per jam',
            isCompleted: hasModels,
            onTap: () {
              if (onOpenCreateModel != null) {
                onOpenCreateModel!();
                return;
              }
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.white,
                builder: (_) => AddProductSheet(
                  onSuccess: () {
                    if (context.mounted) {
                      ref.read(businessProvider.notifier).refreshSilently();
                    }
                  },
                ),
              );
            },
          ),
          const Divider(
            height: 1,
            thickness: 1,
            indent: 48,
            color: Color(0xFFF1F5F9),
          ),
          _buildChecklistItem(
            itemKey: const Key('checklist_step_register_unit'),
            title: 'Daftarkan Unit Fisik Pertama',
            subtitle: 'Tambahkan stok perangkat siap sewa ke Daftar Aset',
            isCompleted: hasUnits,
            onTap: () {
              if (onOpenInventory != null) {
                onOpenInventory!();
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InventoryScreen()),
                );
              }
            },
          ),
          const Divider(
            height: 1,
            thickness: 1,
            indent: 48,
            color: Color(0xFFF1F5F9),
          ),
          _buildChecklistItem(
            itemKey: const Key('checklist_step_payment_qris'),
            title: 'Atur Metode Pembayaran / QRIS',
            subtitle: 'Unggah barcode QRIS toko dan aktifkan kanal pembayaran',
            isCompleted: hasPaymentOrQris,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentMethodSettingsScreen(),
                ),
              );
              if (context.mounted) {
                try {
                  ref.read(businessProvider.notifier).refresh();
                } catch (_) {}
              }
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required Key itemKey,
    required String title,
    required String subtitle,
    required bool isCompleted,
    VoidCallback? onTap,
  }) {
    return InkWell(
      key: itemKey,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? AppColors.success : Colors.transparent,
                border: Border.all(
                  color:
                      isCompleted ? AppColors.success : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
              ),
              child: isCompleted
                  ? const Icon(Icons.check_rounded,
                      color: Colors.white, size: 14)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isCompleted
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF0F172A),
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/business_provider.dart';
import '../../../onboarding/providers/onboarding_provider.dart';
import '../../../organization/presentation/payment_method_settings_screen.dart';
import '../../../organization/presentation/store_profile_screen.dart';
import '../../../printer/presentation/printer_settings_screen.dart';
import '../../../printer/providers/printer_provider.dart';

class ProgressiveChecklistBanner extends ConsumerWidget {
  final int totalAssetCount;
  final VoidCallback? onOpenInventory;

  const ProgressiveChecklistBanner({
    super.key,
    this.totalAssetCount = 0,
    this.onOpenInventory,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final businessState = ref.watch(businessProvider);
    final onboardingState = ref.watch(onboardingProvider);
    final printerState = ref.watch(printerProvider);
    final currentBiz = businessState.currentBusiness;

    if (currentBiz == null ||
        onboardingState.isChecklistDismissed ||
        printerState.hasEverConnectedPrinter) {
      return const SizedBox.shrink();
    }

    final bizId = businessState.activeBusinessId;

    // Check completion criteria
    final hasProfile = (currentBiz['phone'] != null &&
            currentBiz['phone'].toString().isNotEmpty) ||
        (currentBiz['address'] != null &&
            currentBiz['address'].toString().isNotEmpty) ||
        (currentBiz['slogan'] != null &&
            currentBiz['slogan'].toString().isNotEmpty);

    final hasUnits = totalAssetCount > 0;

    // Reactively evaluate QRIS readiness across active branch override and business config
    final activeBranch = businessState.currentBranch;
    final branchOverride = activeBranch?['payment_methods_config_override'];
    final branchConfig = branchOverride is Map ? branchOverride : null;

    final bizConfig = currentBiz['payment_methods_config'] is Map
        ? currentBiz['payment_methods_config'] as Map
        : null;

    bool checkQrisReady(Map? cfg, Map? rawContainer) {
      if (cfg == null && rawContainer == null) return false;
      final rawPayload = (cfg?['qris_raw_payload'] ??
              rawContainer?['qris_raw_payload'])
          ?.toString()
          .trim();
      final hasPayload = rawPayload != null && rawPayload.isNotEmpty;
      final isQrisEnabled = cfg?['is_qris_enabled'] == true ||
          cfg?['qris_statis_enabled'] == true ||
          rawContainer?['is_qris_enabled'] == true ||
          rawContainer?['qris_statis_enabled'] == true;
      final isDynamicEnabled = cfg?['is_dynamic_qris_enabled'] == true ||
          rawContainer?['is_dynamic_qris_enabled'] == true;
      final hasImagePath = (cfg?['qris_image_path'] ??
                  rawContainer?['qris_image_path'])
              ?.toString()
              .trim()
              .isNotEmpty ==
          true ||
          (cfg?['qris_image_url'] ?? rawContainer?['qris_image_url'])
              ?.toString()
              .trim()
              .isNotEmpty ==
          true;

      return hasPayload || isQrisEnabled || isDynamicEnabled || hasImagePath;
    }

    final hasQris = checkQrisReady(branchConfig, activeBranch) ||
        checkQrisReady(bizConfig, currentBiz);

    // Reactively evaluate paired / connected thermal printer
    final hasPrinter =
        printerState.isPairedOrConnected || printerState.hasEverConnectedPrinter;

    final completedCount = [
      hasProfile,
      hasUnits,
      hasQris,
      hasPrinter,
    ].where((c) => c).length;

    final progressPercent = completedCount / 4.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row with progress & dismiss button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 10, 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          const Text(
                            'Panduan Persiapan Toko',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: AppColors.obsidian.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '$completedCount dari 4 Selesai',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.obsidian,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progressPercent,
                          backgroundColor: AppColors.border,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.obsidian,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 18, color: AppColors.textSecondary),
                  tooltip: 'Sembunyikan Panduan',
                  onPressed: () {
                    if (bizId != null) {
                      ref
                          .read(onboardingProvider.notifier)
                          .dismissChecklist(bizId);
                    }
                  },
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.border),

          // Checklist items
          _buildChecklistItem(
            context: context,
            title: 'Lengkapi Profil Usaha',
            subtitle: 'Alamat toko, nomor telepon WhatsApp, dan slogan rental',
            isCompleted: hasProfile,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StoreProfileScreen(),
                ),
              );
              if (context.mounted) {
                try {
                  ref.read(businessProvider.notifier).refresh();
                } catch (_) {}
              }
            },
          ),
          const Divider(height: 1, indent: 46, color: AppColors.border),
          _buildChecklistItem(
            context: context,
            title: 'Daftarkan Unit Pertama',
            subtitle: 'Tambahkan stok barang rental siap sewa ke katalog',
            isCompleted: hasUnits,
            onTap: onOpenInventory,
          ),
          const Divider(height: 1, indent: 46, color: AppColors.border),
          _buildChecklistItem(
            context: context,
            title: 'Atur Metode Pembayaran QRIS',
            subtitle: 'Aktifkan QRIS dinamis otomatis atau transfer bank',
            isCompleted: hasQris,
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
          const Divider(height: 1, indent: 46, color: AppColors.border),
          _buildChecklistItem(
            context: context,
            title: 'Hubungkan Printer Thermal',
            subtitle: 'Pasangkan printer kasir Bluetooth ESC/POS 58mm / 80mm',
            isCompleted: hasPrinter,
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrinterSettingsScreen(),
                ),
              );
              if (context.mounted) {
                ref.invalidate(printerProvider);
              }
            },
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _buildChecklistItem({
    required BuildContext context,
    required String title,
    required String subtitle,
    required bool isCompleted,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted
                    ? AppColors.success
                    : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? AppColors.success : AppColors.border,
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isCompleted
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: isCompleted
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

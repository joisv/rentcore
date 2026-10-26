import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../auth/providers/business_provider.dart';
import '../../providers/organization_provider.dart';

class StaffResignationSheet extends ConsumerStatefulWidget {
  final int businessId;
  final String businessName;

  const StaffResignationSheet({
    super.key,
    required this.businessId,
    required this.businessName,
  });

  static Future<void> show(BuildContext context, {required int businessId, required String businessName}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StaffResignationSheet(
        businessId: businessId,
        businessName: businessName,
      ),
    );
  }

  @override
  ConsumerState<StaffResignationSheet> createState() => _StaffResignationSheetState();
}

class _StaffResignationSheetState extends ConsumerState<StaffResignationSheet> {
  final _reasonController = TextEditingController();
  bool _showSubmitForm = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(organizationProvider.notifier).loadResignations();
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _confirmSubmit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
            SizedBox(width: 8),
            Text('Konfirmasi Resign', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin mengajukan pengunduran diri? '
          'Setelah disetujui oleh Owner, akses Anda ke bisnis dan cabang ini akan berakhir secara permanen. '
          'Akun utama dan bisnis rental milik Anda tetap aman.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(organizationProvider.notifier).submitResignation(
                    reason: _reasonController.text.trim(),
                  );
              if (mounted) {
                if (success) {
                  setState(() => _showSubmitForm = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Permohonan pengunduran diri berhasil diajukan ke Owner.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  final err = ref.read(organizationProvider).error ?? 'Gagal mengajukan pengunduran diri.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Ya, Ajukan Resign', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _confirmCancel(int requestId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pengajuan', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
        content: const Text(
          'Apakah Anda yakin ingin membatalkan permohonan pengunduran diri? Anda akan tetap bertugas sebagai staf aktif.',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Kembali', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await ref.read(organizationProvider.notifier).cancelResignation(requestId);
              if (mounted) {
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Pengajuan pengunduran diri dibatalkan.'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } else {
                  final err = ref.read(organizationProvider).error ?? 'Gagal membatalkan pengajuan.';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err), backgroundColor: AppColors.danger),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: const Text('Batalkan Pengajuan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final orgState = ref.watch(organizationProvider);
    final user = ref.watch(authProvider).user;
    final bState = ref.watch(businessProvider);
    final currentBiz = bState.currentBusiness;
    final branches = (currentBiz?['branches'] as List<dynamic>?) ?? [];

    final myRequests = orgState.resignationRequests.where((r) => r['user_id'] == user?['id']).toList();
    final latestRequest = myRequests.isNotEmpty ? myRequests.first as Map<String, dynamic> : null;
    final isPending = latestRequest != null && latestRequest['status'] == 'pending';
    final isRejected = latestRequest != null && latestRequest['status'] == 'rejected';

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.badge_outlined, color: AppColors.obsidian, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Status Kepegawaian',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        widget.businessName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 18),

            // Active Employment Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Peran Penugasan',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.obsidian,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          (currentBiz?['role'] ?? 'STAFF').toString().toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Cabang yang Ditugaskan:',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  if (branches.isEmpty)
                    const Text('Belum ada penugasan cabang spesifik', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: branches.map((b) {
                        final bMap = b as Map<String, dynamic>;
                        return Chip(
                          visualDensity: VisualDensity.compact,
                          backgroundColor: Colors.white,
                          side: const BorderSide(color: AppColors.border),
                          avatar: const Icon(Icons.storefront_outlined, size: 14, color: AppColors.obsidian),
                          label: Text(
                            bMap['name'] ?? '',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Resignation Status Section
            if (isPending) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.hourglass_top_rounded, color: Color(0xFFB45309), size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Menunggu Persetujuan Owner',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF92400E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Permohonan resign Anda sedang ditinjau oleh Owner bisnis. '
                      'Selama masa peninjauan, Anda tetap memiliki akses kerja sampai Owner menyetujui permohonan.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), height: 1.4),
                    ),
                    if (latestRequest['reason'] != null && latestRequest['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Alasan yang diajukan: "${latestRequest['reason']}"',
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF78350F)),
                      ),
                    ],
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: orgState.isSubmitting
                          ? null
                          : () => _confirmCancel(latestRequest['id'] as int),
                      icon: const Icon(Icons.cancel_outlined, size: 16),
                      label: const Text('Batalkan Pengajuan Resign'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF92400E),
                        side: const BorderSide(color: Color(0xFFD97706)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (isRejected && !_showSubmitForm) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFEF4444)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Permohonan Resign Ditolak',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (latestRequest['decision_notes'] != null)
                      Text(
                        'Catatan Owner: "${latestRequest['decision_notes']}"',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), fontStyle: FontStyle.italic),
                      ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => setState(() => _showSubmitForm = true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.obsidian,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      child: const Text('Ajukan Permohonan Baru', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Information banner
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, color: Color(0xFF1D4ED8), size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pengunduran diri hanya akan mengakhiri keanggotaan Anda pada bisnis ini. '
                        'Akun global RentCore, riwayat transaksi terdahulu, dan bisnis independen yang Anda miliki tetap aman.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF1E40AF),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Reason input
              TextField(
                controller: _reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alasan Pengunduran Diri (Opsional)',
                  hintText: 'Contoh: Pindah domisili, fokus wirausaha, atau alasan pribadi lainnya...',
                  hintStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 18),

              ElevatedButton.icon(
                onPressed: orgState.isSubmitting ? null : _confirmSubmit,
                icon: orgState.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.exit_to_app_rounded, size: 18),
                label: Text(
                  orgState.isSubmitting ? 'Mengirim Pengajuan...' : 'Ajukan Pengunduran Diri',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

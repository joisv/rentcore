import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/skeleton_loading.dart';
import '../../../shared/widgets/rentcore_app_bar.dart';
import '../../auth/providers/auth_provider.dart';
import '../../auth/providers/business_provider.dart';
import '../../bookings/providers/booking_provider.dart';
import '../../home/providers/dashboard_provider.dart';
import '../../inventory/providers/asset_provider.dart';
import '../providers/transfer_provider.dart';

String _formatBranchDisplayName(String? raw, {String fallback = 'Pusat'}) {
  final trimmed = (raw ?? '').trim();
  if (trimmed.isEmpty) return fallback;
  if (trimmed != trimmed.toLowerCase()) return trimmed;
  return trimmed
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  void _invalidateAllInventoryAndTransfers() {
    ref.invalidate(transfersListProvider);
    ref.invalidate(readyAssetsProvider);
    ref.invalidate(inventoryListProvider);
    ref.invalidate(dashboardKpiProvider);
  }

  @override
  Widget build(BuildContext context) {
    final selectedDirection = ref.watch(selectedTransferDirectionProvider);
    final selectedStatus = ref.watch(selectedTransferStatusProvider);
    final transfersAsync = ref.watch(transfersListProvider);

    final authState = ref.watch(authProvider);
    final currentUserId = authState.user?['id']?.toString();

    final bizState = ref.watch(businessProvider);
    final currentBiz = bizState.businesses
        .whereType<Map>()
        .where(
          (b) =>
              normalizeEntityId(b['id']) ==
              normalizeEntityId(bizState.activeBusinessId),
        )
        .firstOrNull;
    final userRole = currentBiz?['role']?.toString() ?? authState.user?['role']?.toString() ?? 'staff';
    final isOwner = userRole == 'owner';
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        automaticallyImplyLeading: false,
        leading: canPop
            ? const RentCoreBackButton(color: Color(0xFF475569))
            : null,
        title: const Text(
          'Mutasi Unit Antar Cabang',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: Color(0xFF0F172A),
          ),
        ),
        actions: [
          IconButton(
            key: const Key('transfers_refresh_button'),
            icon: const Icon(
              Icons.refresh_rounded,
              color: Color(0xFF475569),
              size: 22,
            ),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(transfersListProvider),
          ),
        ],
      ),
      floatingActionButton: _buildPrimaryActionButton(context),
      body: Column(
        children: [
          // Direction Segmented Pill Switcher
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildDirectionSegment('all', 'Semua', selectedDirection),
                  _buildDirectionSegment('inbound', 'Masuk', selectedDirection),
                  _buildDirectionSegment('outbound', 'Keluar', selectedDirection),
                ],
              ),
            ),
          ),

          // Status Filter Row
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStatusChip(null, 'Semua', selectedStatus),
                  const SizedBox(width: 8),
                  _buildStatusChip('pending', 'Menunggu', selectedStatus),
                  const SizedBox(width: 8),
                  _buildStatusChip('in_transit', 'Dikirim', selectedStatus),
                  const SizedBox(width: 8),
                  _buildStatusChip('received', 'Diterima', selectedStatus),
                  const SizedBox(width: 8),
                  _buildStatusChip('rejected', 'Ditolak', selectedStatus),
                  const SizedBox(width: 8),
                  _buildStatusChip('cancelled', 'Dibatalkan', selectedStatus),
                ],
              ),
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Content List
          Expanded(
            child: transfersAsync.when(
              loading: () => const PhysicalUnitsTabSkeleton(count: 5),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text('Gagal memuat mutasi: $err', textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(transfersListProvider),
                        child: const Text('Coba Lagi'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (transfers) {
                if (transfers.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.swap_horiz_rounded,
                              size: 32,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Mutasi Unit',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gunakan tombol "Kirim Unit" di bawah untuk memindahkan stok siap sewa ke cabang lain.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transfersListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: transfers.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = transfers[index];
                      return _buildTransferCard(context, item, currentUserId, isOwner);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryActionButton(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F0F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: const Key('transfer_kirim_unit_button'),
          borderRadius: BorderRadius.circular(14),
          onTap: () => _showInitiateTransferSheet(context),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Kirim Unit',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectionSegment(String value, String label, String currentValue) {
    final isActive = value == currentValue;
    return Expanded(
      child: GestureDetector(
        key: Key('transfer_direction_$value'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          ref.read(selectedTransferDirectionProvider.notifier).setDirection(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: isActive
                ? Border.all(color: const Color(0xFFE2E8F0), width: 1)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              color: isActive
                  ? const Color(0xFF0F172A)
                  : const Color(0xFF64748B),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? value, String label, String? currentValue) {
    final isSelected = value == currentValue;
    final keyName = value ?? 'all';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('transfer_status_$keyName'),
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          ref.read(selectedTransferStatusProvider.notifier).setStatus(value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : const Color(0xFFE2E8F0),
              width: 1,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF64748B),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 12.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTransferStatusPill(int transferId, String status) {
    final (String label, Color bg, Color text) = switch (status.toLowerCase()) {
      'received' => (
        'Diterima',
        const Color(0xFFECFDF5),
        const Color(0xFF047857),
      ),
      'pending' => (
        'Menunggu',
        const Color(0xFFFFFBEB),
        const Color(0xFFB45309),
      ),
      'in_transit' => (
        'Dikirim',
        const Color(0xFFEFF6FF),
        const Color(0xFF1D4ED8),
      ),
      'rejected' => (
        'Ditolak',
        const Color(0xFFFEF2F2),
        const Color(0xFFBE123C),
      ),
      _ => (
        'Dibatalkan',
        const Color(0xFFF1F5F9),
        const Color(0xFF475569),
      ),
    };

    return Container(
      key: Key('transfer_card_status_$transferId'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: text,
        ),
      ),
    );
  }

  Widget _buildTransferCard(BuildContext context, Map<String, dynamic> item, String? currentUserId, bool isOwner) {
    final id = item['id'] as int;
    final code = item['transfer_code']?.toString() ?? 'TRF-UNKNOWN';
    final status = item['status']?.toString() ?? 'pending';
    final asset = item['asset'] as Map<String, dynamic>?;
    final model = asset?['model'] as Map<String, dynamic>?;
    final fromAffiliate = item['from_affiliate'] as Map<String, dynamic>?;
    final toAffiliate = item['to_affiliate'] as Map<String, dynamic>?;
    final sender = item['sender'] as Map<String, dynamic>?;
    final receiver = item['receiver'] as Map<String, dynamic>?;
    final recipient = item['recipient'] as Map<String, dynamic>?;
    final approver = item['approver'] as Map<String, dynamic>?;
    final rejecter = item['rejecter'] as Map<String, dynamic>?;
    final notes = item['notes'] as String?;
    final rejectionReason = item['rejection_reason'] as String?;

    final recipientId = item['recipient_id']?.toString() ?? recipient?['id']?.toString();
    final senderId = item['sent_by']?.toString() ?? sender?['id']?.toString();

    // Strict Permissions:
    // Only the explicitly assigned recipient may receive!
    final isAssignedRecipient = currentUserId != null && currentUserId == recipientId;
    final isSender = currentUserId != null && currentUserId == senderId;
    final canCancel = (status == 'pending' || status == 'in_transit') && (isOwner || isSender);

    final auditParts = <String>[
      'Diajukan: ${sender?['name'] ?? 'Staff'}',
      if (approver != null) 'Disetujui: ${approver['name']}',
      if (rejecter != null) 'Ditolak: ${rejecter['name']}',
      if (receiver != null) 'Diterima: ${receiver['name']}',
    ];

    return Container(
      key: Key('transfer_card_$id'),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code & Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  code,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                    letterSpacing: 0.2,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              _buildTransferStatusPill(id, status),
            ],
          ),
          const SizedBox(height: 12),

          // Asset Summary Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.smartphone_rounded,
                    size: 20,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model?['name']?.toString() ?? 'Perangkat Elektronik',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode: ${asset?['asset_code'] ?? '-'} • SN: ${asset?['serial_number'] ?? '-'}',
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clean Branch Transfer Route: Asal -> Tujuan
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cabang Asal',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBranchDisplayName(fromAffiliate?['name']?.toString()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Cabang Tujuan',
                      style: TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatBranchDisplayName(toAffiliate?['name']?.toString()),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Subtle Assigned Receiver Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline_rounded,
                  size: 16,
                  color: Color(0xFF334155),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Penerima: ${recipient?['name'] ?? 'Belum ditentukan'}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isAssignedRecipient) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1),
                    ),
                    child: const Text(
                      'Anda',
                      style: TextStyle(
                        color: Color(0xFF047857),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: $notes',
              style: const TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Color(0xFF64748B),
              ),
            ),
          ],

          if (rejectionReason != null && rejectionReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECDD3), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alasan Ditolak: $rejectionReason',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Compact Audit Trail Footer
          const SizedBox(height: 10),
          Text(
            auditParts.join(' • '),
            style: const TextStyle(
              fontSize: 11.5,
              color: Color(0xFF94A3B8),
              height: 1.4,
            ),
          ),

          // Action Buttons:
          // 1. Pending Approval Actions (Owner only can approve / reject)
          if (status == 'pending') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            if (isOwner)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECDD3), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _showRejectTransferDialog(id, code),
                      child: const Text('Tolak', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmApproveTransfer(id, code),
                      child: const Text('Setujui', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Menunggu persetujuan dari Business Owner.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (canCancel)
                    TextButton(
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      onPressed: () => _confirmCancelTransfer(id, code),
                      child: const Text('Batalkan', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
          ],

          // 2. In Transit Actions (Only the assigned recipient can confirm receipt!)
          if (status == 'in_transit') ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            const SizedBox(height: 12),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: Color(0xFFFECDD3), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmCancelTransfer(id, code),
                      child: const Text('Batalkan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                if (canCancel && isAssignedRecipient) const SizedBox(width: 10),
                if (isAssignedRecipient)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 42),
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmReceiveTransfer(id, code),
                      child: const Text('Terima Unit', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  )
                else if (!canCancel)
                  Expanded(
                    child: Text(
                      'Menunggu penerimaan oleh ${recipient?['name'] ?? 'staf yang ditugaskan'}.',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _confirmApproveTransfer(int id, String code) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Setujui Mutasi Unit?'),
        content: Text('Konfirmasi persetujuan mutasi $code. Unit akan segera masuk ke status Dalam Pengiriman.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(transferRepositoryProvider);
                await repo.approveTransfer(id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Mutasi $code berhasil disetujui!'), backgroundColor: AppColors.success),
                );
                _invalidateAllInventoryAndTransfers();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menyetujui mutasi: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Setujui Mutasi'),
          ),
        ],
      ),
    );
  }

  void _showRejectTransferDialog(int id, String code) {
    final reasonController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak Mutasi Unit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Masukkan alasan penolakan mutasi $code. Unit akan dikembalikan ke status Siap Sewa di cabang asal:'),
            const SizedBox(height: 10),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Misal: Perangkat sedang disiapkan untuk booking offline...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Alasan penolakan wajib diisi!'), backgroundColor: AppColors.danger),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                final repo = ref.read(transferRepositoryProvider);
                await repo.rejectTransfer(id, reason);
                messenger.showSnackBar(
                  SnackBar(content: Text('Mutasi $code telah ditolak.'), backgroundColor: AppColors.obsidian),
                );
                _invalidateAllInventoryAndTransfers();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menolak mutasi: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Tolak Mutasi'),
          ),
        ],
      ),
    );
  }

  void _confirmReceiveTransfer(int id, String code) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Terima Mutasi Unit?'),
        content: Text('Konfirmasi penerimaan unit untuk kode transfer $code. Status perangkat akan diubah menjadi Siap Sewa di cabang Anda.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(transferRepositoryProvider);
                await repo.receiveTransfer(id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Unit transfer $code berhasil diterima!'), backgroundColor: AppColors.success),
                );
                _invalidateAllInventoryAndTransfers();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal menerima unit: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Terima Unit'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelTransfer(int id, String code) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Mutasi Unit?'),
        content: Text('Apakah Anda yakin ingin membatalkan mutasi $code? Perangkat akan dikembalikan ke status Siap Sewa di cabang asal.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kembali')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(transferRepositoryProvider);
                await repo.cancelTransfer(id);
                messenger.showSnackBar(
                  SnackBar(content: Text('Mutasi $code berhasil dibatalkan.'), backgroundColor: AppColors.obsidian),
                );
                _invalidateAllInventoryAndTransfers();
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal membatalkan mutasi: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Batalkan Mutasi'),
          ),
        ],
      ),
    );
  }

  void _showInitiateTransferSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _InitiateTransferForm(
        onSuccess: () {
          Navigator.pop(ctx);
          _invalidateAllInventoryAndTransfers();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pengajuan mutasi unit berhasil dikirim!'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }
}

class _InitiateTransferForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const _InitiateTransferForm({required this.onSuccess});

  @override
  ConsumerState<_InitiateTransferForm> createState() => _InitiateTransferFormState();
}

class _InitiateTransferFormState extends ConsumerState<_InitiateTransferForm> {
  int? _selectedAssetId;
  int? _selectedDestinationAffiliateId;
  String? _selectedRecipientId;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  List<Map<String, dynamic>> _readyAssets = [];
  bool _isLoadingAssets = true;

  List<Map<String, dynamic>> _recipients = [];
  bool _isLoadingRecipients = false;

  @override
  void initState() {
    super.initState();
    _loadReadyAssets();
  }

  Future<void> _loadReadyAssets() async {
    try {
      final activeBranchId = ref.read(businessProvider).activeBranchId;
      final bookingRepo = ref.read(bookingRepositoryProvider);
      final assets = await bookingRepo.fetchReadyAssets(branchId: activeBranchId);
      if (mounted) {
        setState(() {
          _readyAssets = assets;
          _isLoadingAssets = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingAssets = false);
    }
  }

  Future<void> _loadRecipients(int branchId) async {
    setState(() {
      _isLoadingRecipients = true;
      _recipients = [];
      _selectedRecipientId = null;
    });

    try {
      final repo = ref.read(transferRepositoryProvider);
      final recipients = await repo.fetchRecipients(branchId);
      if (mounted) {
        setState(() {
          _recipients = recipients;
          _isLoadingRecipients = false;
          if (_recipients.length == 1) {
            _selectedRecipientId = _recipients.first['id']?.toString();
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRecipients = false);
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  InputDecoration _buildInputDecoration({String? hintText}) {
    const defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFFE2E8F0), width: 1),
    );
    const focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: Color(0xFF0F172A), width: 1.5),
    );
    const errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.danger, width: 1),
    );
    const focusedErrorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: AppColors.danger, width: 1.5),
    );

    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF94A3B8),
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: defaultBorder,
      enabledBorder: defaultBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: focusedErrorBorder,
    );
  }

  Widget _buildFieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: Color(0xFF334155),
      ),
    );
  }

  Widget _buildEmptyFieldBox(String message, {Color textColor = const Color(0xFF64748B)}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(color: textColor, fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinationsAsync = ref.watch(destinationAffiliatesProvider);
    final bool isFormValid = !_isLoading &&
        _selectedAssetId != null &&
        _selectedDestinationAffiliateId != null &&
        _selectedRecipientId != null;

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // Sheet Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kirim Unit Antar Cabang',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.3,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Pindahkan unit siap sewa ke cabang tujuan',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Material(
                color: const Color(0xFFF1F5F9),
                shape: const CircleBorder(),
                child: InkWell(
                  key: const Key('close_transfer_sheet_button'),
                  customBorder: const CircleBorder(),
                  onTap: () => Navigator.pop(context),
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Asset Selector
          _buildFieldLabel('Pilih Unit Siap Sewa'),
          const SizedBox(height: 6),
          if (_isLoadingAssets)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_readyAssets.isEmpty)
            _buildEmptyFieldBox('Tidak ada unit siap sewa di cabang Anda saat ini.')
          else
            DropdownButtonFormField<int>(
              key: const Key('transfer_asset_dropdown'),
              initialValue: _selectedAssetId,
              isExpanded: true,
              dropdownColor: Colors.white,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
                size: 20,
              ),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
              decoration: _buildInputDecoration(hintText: 'Pilih Perangkat...'),
              items: _readyAssets.map((asset) {
                final model = asset['model'] as Map<String, dynamic>?;
                return DropdownMenuItem<int>(
                  value: asset['id'] as int,
                  child: Text(
                    '${model?['name'] ?? 'Device'} (${asset['asset_code']})',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAssetId = val),
            ),
          const SizedBox(height: 16),

          // Destination Branch Selector
          _buildFieldLabel('Cabang Tujuan'),
          const SizedBox(height: 6),
          destinationsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
            error: (err, _) => Text(
              'Gagal memuat cabang tujuan: $err',
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
            data: (destinations) {
              if (destinations.isEmpty) {
                return _buildEmptyFieldBox('Tidak ada cabang tujuan lain yang aktif.');
              }
              return DropdownButtonFormField<int>(
                key: const Key('transfer_destination_dropdown'),
                initialValue: _selectedDestinationAffiliateId,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(hintText: 'Pilih Cabang Tujuan...'),
                items: destinations.map((branch) {
                  return DropdownMenuItem<int>(
                    value: branch['id'] as int,
                    child: Text(
                      '${_formatBranchDisplayName(branch['name']?.toString(), fallback: '-')} (${branch['code']})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedDestinationAffiliateId = val);
                  if (val != null) {
                    _loadRecipients(val);
                  }
                },
              );
            },
          ),

          // Recipient Selector
          if (_selectedDestinationAffiliateId != null) ...[
            const SizedBox(height: 16),
            _buildFieldLabel('Staf Penerima di Cabang Tujuan'),
            const SizedBox(height: 6),
            if (_isLoadingRecipients)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (_recipients.isEmpty)
              _buildEmptyFieldBox(
                'Belum ada staf yang terdaftar di cabang tujuan ini.',
                textColor: AppColors.danger,
              )
            else
              DropdownButtonFormField<String>(
                key: const Key('transfer_recipient_dropdown'),
                initialValue: _selectedRecipientId,
                isExpanded: true,
                dropdownColor: Colors.white,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF64748B),
                  size: 20,
                ),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
                decoration: _buildInputDecoration(hintText: 'Pilih Staf Penerima...'),
                items: _recipients.map((r) {
                  return DropdownMenuItem<String>(
                    value: r['id']?.toString(),
                    child: Text(
                      '${r['name']} (${r['role'] ?? 'staff'})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedRecipientId = val),
              ),
          ],
          const SizedBox(height: 16),

          // Notes
          _buildFieldLabel('Catatan Mutasi (Opsional)'),
          const SizedBox(height: 6),
          TextField(
            key: const Key('transfer_notes_field'),
            controller: _notesController,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF0F172A),
            ),
            decoration: _buildInputDecoration(
              hintText: 'Misal: Kebutuhan lonjakan sewa akhir pekan...',
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            height: 48,
            width: double.infinity,
            child: ElevatedButton(
              key: const Key('transfer_submit_button'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFF1F5F9),
                disabledForegroundColor: const Color(0xFF94A3B8),
                elevation: 0,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isFormValid
                      ? BorderSide.none
                      : const BorderSide(color: Color(0xFFE2E8F0), width: 1),
                ),
              ),
              onPressed: !isFormValid
                  ? null
                  : () async {
                      setState(() => _isLoading = true);
                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        final repo = ref.read(transferRepositoryProvider);
                        await repo.createTransfer(
                          assetId: _selectedAssetId!,
                          toAffiliateId: _selectedDestinationAffiliateId!,
                          recipientId: _selectedRecipientId!,
                          notes: _notesController.text.trim(),
                        );
                        widget.onSuccess();
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Gagal inisiasi mutasi: $e'),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    },
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Konfirmasi & Kirim Unit',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

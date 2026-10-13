import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../../bookings/data/booking_repository.dart';
import '../providers/transfer_provider.dart';

class TransfersScreen extends ConsumerStatefulWidget {
  const TransfersScreen({super.key});

  @override
  ConsumerState<TransfersScreen> createState() => _TransfersScreenState();
}

class _TransfersScreenState extends ConsumerState<TransfersScreen> {
  final _bookingRepo = BookingRepository();

  @override
  Widget build(BuildContext context) {
    final selectedDirection = ref.watch(selectedTransferDirectionProvider);
    final transfersAsync = ref.watch(transfersListProvider);
    final authState = ref.watch(authProvider);
    final currentAffiliateId = authState.user?['affiliate_id'] as int?;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Mutasi Unit Antar Cabang',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Segarkan',
            onPressed: () => ref.invalidate(transfersListProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.obsidian,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Kirim Unit', style: TextStyle(fontWeight: FontWeight.w700)),
        onPressed: () => _showInitiateTransferSheet(context),
      ),
      body: Column(
        children: [
          // Direction Filter Tabs
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTabChip('all', 'Semua Mutasi', selectedDirection),
                  const SizedBox(width: 8),
                  _buildTabChip('inbound', 'Unit Masuk (Inbound)', selectedDirection),
                  const SizedBox(width: 8),
                  _buildTabChip('outbound', 'Unit Keluar (Outbound)', selectedDirection),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Content List
          Expanded(
            child: transfersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
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
                          Icon(Icons.swap_horiz_rounded, size: 64, color: AppColors.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Mutasi Unit',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Gunakan tombol "Kirim Unit" di bawah untuk memindahkan stok siap sewa ke cabang lain.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(transfersListProvider),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: transfers.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = transfers[index];
                      return _buildTransferCard(context, item, currentAffiliateId);
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

  Widget _buildTabChip(String value, String label, String currentValue) {
    final isSelected = value == currentValue;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.obsidian,
      backgroundColor: AppColors.surfaceMuted,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        fontSize: 12,
      ),
      onSelected: (_) {
        ref.read(selectedTransferDirectionProvider.notifier).setDirection(value);
      },
    );
  }

  Widget _buildTransferCard(BuildContext context, Map<String, dynamic> item, int? currentAffiliateId) {
    final id = item['id'] as int;
    final code = item['transfer_code'] ?? 'TRF-UNKNOWN';
    final status = item['status'] ?? 'in_transit';
    final asset = item['asset'] as Map<String, dynamic>?;
    final model = asset?['model'] as Map<String, dynamic>?;
    final fromAffiliate = item['from_affiliate'] as Map<String, dynamic>?;
    final toAffiliate = item['to_affiliate'] as Map<String, dynamic>?;
    final sender = item['sender'] as Map<String, dynamic>?;
    final receiver = item['receiver'] as Map<String, dynamic>?;
    final notes = item['notes'] as String?;

    final fromAffiliateId = item['from_affiliate_id'] as int?;
    final toAffiliateId = item['to_affiliate_id'] as int?;

    // Determine permissions
    final canReceive = status == 'in_transit' && (currentAffiliateId == null || currentAffiliateId == toAffiliateId);
    final canCancel = status == 'in_transit' && (currentAffiliateId == null || currentAffiliateId == fromAffiliateId);

    Color statusColor;
    Color statusBg;
    String statusText;
    IconData statusIcon;

    switch (status) {
      case 'received':
        statusColor = AppColors.success;
        statusBg = AppColors.successLight;
        statusText = 'Diterima';
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'cancelled':
        statusColor = AppColors.danger;
        statusBg = AppColors.dangerLight;
        statusText = 'Dibatalkan';
        statusIcon = Icons.cancel_rounded;
        break;
      case 'in_transit':
      default:
        statusColor = AppColors.warning;
        statusBg = AppColors.warningLight;
        statusText = 'Dalam Pengiriman';
        statusIcon = Icons.local_shipping_rounded;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                code,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusColor),
                    const SizedBox(width: 4),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Device Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.smartphone_rounded, size: 28, color: AppColors.obsidian),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model?['name'] ?? 'Perangkat Elektronik',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Kode: ${asset?['asset_code'] ?? '-'} • SN: ${asset?['serial_number'] ?? '-'}',
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Branch Routing: From -> To
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cabang Asal', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    Text(
                      fromAffiliate?['name'] ?? 'Pusat',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, size: 18, color: AppColors.textMuted),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Cabang Tujuan', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    Text(
                      toAffiliate?['name'] ?? 'Pusat',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (notes != null && notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Catatan: $notes',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            'Dikirim oleh ${sender?['name'] ?? 'Staff'}${receiver != null ? ' • Diterima oleh ${receiver['name']}' : ''}',
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),

          // Action Buttons
          if (canReceive || canCancel) ...[
            const SizedBox(height: 14),
            const Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            Row(
              children: [
                if (canCancel)
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmCancelTransfer(id, code),
                      child: const Text('Batalkan', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
                if (canCancel && canReceive) const SizedBox(width: 8),
                if (canReceive)
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () => _confirmReceiveTransfer(id, code),
                      child: const Text('Terima Unit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                  ),
              ],
            ),
          ],
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
                ref.invalidate(transfersListProvider);
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
        content: Text('Apakah Anda yakin ingin membatalkan pengiriman $code? Perangkat akan dikembalikan ke status Siap Sewa di cabang asal.'),
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
                ref.invalidate(transfersListProvider);
              } catch (e) {
                messenger.showSnackBar(
                  SnackBar(content: Text('Gagal membatalkan mutasi: $e'), backgroundColor: AppColors.danger),
                );
              }
            },
            child: const Text('Batalkan Pengiriman'),
          ),
        ],
      ),
    );
  }

  void _showInitiateTransferSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => _InitiateTransferForm(
        bookingRepo: _bookingRepo,
        onSuccess: () {
          Navigator.pop(ctx);
          ref.invalidate(transfersListProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mutasi unit berhasil diinisiasi!'), backgroundColor: AppColors.success),
          );
        },
      ),
    );
  }
}

class _InitiateTransferForm extends ConsumerStatefulWidget {
  final BookingRepository bookingRepo;
  final VoidCallback onSuccess;

  const _InitiateTransferForm({required this.bookingRepo, required this.onSuccess});

  @override
  ConsumerState<_InitiateTransferForm> createState() => _InitiateTransferFormState();
}

class _InitiateTransferFormState extends ConsumerState<_InitiateTransferForm> {
  int? _selectedAssetId;
  int? _selectedDestinationAffiliateId;
  final _notesController = TextEditingController();
  bool _isLoading = false;

  List<Map<String, dynamic>> _readyAssets = [];
  bool _isLoadingAssets = true;

  @override
  void initState() {
    super.initState();
    _loadReadyAssets();
  }

  Future<void> _loadReadyAssets() async {
    try {
      final assets = await widget.bookingRepo.fetchReadyAssets();
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

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinationsAsync = ref.watch(destinationAffiliatesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inisiasi Mutasi Unit',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Asset Selector
          const Text('Pilih Unit Siap Sewa', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          if (_isLoadingAssets)
            const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))
          else if (_readyAssets.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(12)),
              child: const Text('Tidak ada unit siap sewa di cabang Anda saat ini.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            )
          else
            DropdownButtonFormField<int>(
              initialValue: _selectedAssetId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surfaceMuted,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              hint: const Text('Pilih Perangkat...'),
              items: _readyAssets.map((asset) {
                final model = asset['model'] as Map<String, dynamic>?;
                return DropdownMenuItem<int>(
                  value: asset['id'] as int,
                  child: Text(
                    '${model?['name'] ?? 'Device'} (${asset['asset_code']})',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (val) => setState(() => _selectedAssetId = val),
            ),
          const SizedBox(height: 16),

          // Destination Branch Selector
          const Text('Cabang Tujuan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          destinationsAsync.when(
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())),
            error: (err, _) => Text('Gagal memuat cabang tujuan: $err', style: const TextStyle(color: AppColors.danger, fontSize: 12)),
            data: (destinations) {
              if (destinations.isEmpty) {
                return const Text('Tidak ada cabang tujuan lain yang aktif.', style: TextStyle(color: AppColors.textSecondary, fontSize: 12));
              }
              return DropdownButtonFormField<int>(
                initialValue: _selectedDestinationAffiliateId,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.surfaceMuted,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                hint: const Text('Pilih Cabang Tujuan...'),
                items: destinations.map((branch) {
                  return DropdownMenuItem<int>(
                    value: branch['id'] as int,
                    child: Text(
                      '${branch['name']} (${branch['code']})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedDestinationAffiliateId = val),
              );
            },
          ),
          const SizedBox(height: 16),

          // Notes
          const Text('Catatan Mutasi (Opsional)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Misal: Kebutuhan lonjakan sewa akhir pekan...',
              filled: true,
              fillColor: AppColors.surfaceMuted,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: (_isLoading || _selectedAssetId == null || _selectedDestinationAffiliateId == null)
                ? null
                : () async {
                    setState(() => _isLoading = true);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final repo = ref.read(transferRepositoryProvider);
                      await repo.createTransfer(
                        assetId: _selectedAssetId!,
                        toAffiliateId: _selectedDestinationAffiliateId!,
                        notes: _notesController.text.trim(),
                      );
                      widget.onSuccess();
                    } catch (e) {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        messenger.showSnackBar(
                          SnackBar(content: Text('Gagal inisiasi mutasi: $e'), backgroundColor: AppColors.danger),
                        );
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('Konfirmasi & Kirim Unit', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
          ),
        ],
      ),
    );
  }
}

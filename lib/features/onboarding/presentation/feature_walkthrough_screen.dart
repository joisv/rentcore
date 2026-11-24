import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../main.dart';
import '../../../shared/widgets/airy_settings_widgets.dart';
import '../../auth/providers/business_provider.dart';
import '../providers/onboarding_provider.dart';

class FeatureWalkthroughScreen extends ConsumerStatefulWidget {
  final bool replayMode;
  final String? roleOverride;

  const FeatureWalkthroughScreen({
    super.key,
    this.replayMode = false,
    this.roleOverride,
  });

  @override
  ConsumerState<FeatureWalkthroughScreen> createState() =>
      _FeatureWalkthroughScreenState();
}

class _FeatureWalkthroughScreenState
    extends ConsumerState<FeatureWalkthroughScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  bool get _isStaffQuickStart {
    final rawRole = (widget.roleOverride ??
            ref.read(businessProvider).currentBusiness?['role'] ??
            'owner')
        .toString()
        .trim()
        .toLowerCase();
    return rawRole == 'staff' || rawRole == 'cashier';
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _finishWalkthrough() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    if (!widget.replayMode) {
      await ref.read(onboardingProvider.notifier).completeWalkthrough();
    }

    if (!mounted) return;
    if (widget.replayMode) {
      Navigator.of(context).pop();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShellScreen()),
    );
  }

  void _nextPage(int totalPages) {
    if (_currentPage < totalPages - 1) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
    } else {
      _finishWalkthrough();
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = (widget.roleOverride ??
            ref.watch(businessProvider).currentBusiness?['role'] ??
            'owner')
        .toString()
        .trim()
        .toLowerCase();
    final isStaffMode = role == 'staff' || role == 'cashier';
    final totalPages = isStaffMode ? 3 : 4;
    if (_currentPage >= totalPages) {
      _currentPage = totalPages - 1;
    }

    final slides = isStaffMode
        ? [
            _buildSlideContainer(
              previewWidget: _buildStaffQuickCard(
                key: const Key('staff_quickstart_shift'),
                icon: Icons.point_of_sale_rounded,
                badge: 'LANGKAH 1 • KASIR',
                title: 'Shift Pagi Siap Dibuka',
                lines: const [
                  'Catat modal kas awal di laci sebelum melayani transaksi.',
                  'Semua pembayaran Tunai & Non-Tunai otomatis terpisahkan.',
                ],
              ),
              title: 'Buka Shift Kasir',
              description:
                  'Mulai operasional cabang dengan membuka shift kasir dan mencatat saldo modal awal laci.',
            ),
            _buildSlideContainer(
              previewWidget: _buildStaffQuickCard(
                key: const Key('staff_quickstart_handover'),
                icon: Icons.assignment_turned_in_outlined,
                badge: 'LANGKAH 2 • TRANSAKSI',
                title: 'Serahkan Unit ke Penyewa',
                lines: const [
                  'Pilih unit siap sewa atau proses antrean booking pelanggan.',
                  'Verifikasi dokumen jaminan (KTP/SIM) sebelum penyerahan.',
                ],
              ),
              title: 'Catat Sewa & Serahkan Unit',
              description:
                  'Buat sewa baru, proses pembayaran Tunai/QRIS, dan lakukan serah terima unit secara cepat.',
            ),
            _buildSlideContainer(
              previewWidget: _buildStaffQuickCard(
                key: const Key('staff_quickstart_return'),
                icon: Icons.verified_outlined,
                badge: 'LANGKAH 3 • PENGEMBALIAN',
                title: 'Cek Kondisi & Tutup Sewa',
                lines: const [
                  'Periksa kelengkapan aksesoris dan kondisi fisik unit kembali.',
                  'Denda keterlambatan dihitung otomatis sesuai aturan toko.',
                ],
              ),
              title: 'Inspeksi Pengembalian',
              description:
                  'Catat pengembalian unit dengan rapi dan kembalikan unit langsung ke stok siap sewa.',
            ),
          ]
        : [
            _buildSlideContainer(
              previewWidget: _buildSlide1Preview(),
              title: 'Operasional Harian dalam Satu Layar',
              description:
                  'Pantau omzet, batas waktu kembali, dan unit siap sewa langsung saat aplikasi dibuka.',
            ),
            _buildSlideContainer(
              previewWidget: _buildSlide2Preview(),
              title: 'Antrean Terstruktur Berbasis Urgensi',
              description:
                  'Unit terlambat dan jatuh tempo otomatis mengapung di posisi teratas antrean kasir.',
            ),
            _buildSlideContainer(
              previewWidget: _buildSlide3Preview(),
              title: 'QRIS Dinamis Tanpa Input Manual',
              description:
                  'Nominal tagihan otomatis terkunci di aplikasi m-Banking dan e-wallet pelanggan.',
            ),
            _buildSlideContainer(
              previewWidget: _buildSlide4Preview(),
              title: 'Manajemen Shift & Closing Kasir Rapi',
              description:
                  'Pisahkan transaksi sewa dari laci kasir. Rekonsiliasi modal dan omzet fisik dengan dukungan cetak printer ESC/POS.',
            ),
          ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip / Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Langkah ${_currentPage + 1} dari $totalPages',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                  TextButton(
                    onPressed: _isCompleting ? null : _finishWalkthrough,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                    ),
                    child: Text(
                      widget.replayMode ? 'Tutup' : 'Lewati',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page View with Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: slides,
              ),
            ),

            // Bottom Navigation & Dots
            _buildBottomControls(totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffQuickCard({
    required Key key,
    required IconData icon,
    required String badge,
    required String title,
    required List<String> lines,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AirySettingsColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AirySettingsColors.surfaceSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AirySettingsColors.border),
                ),
                child: Icon(icon, size: 22, color: AirySettingsColors.obsidian),
              ),
              const SizedBox(width: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AirySettingsColors.pillSurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AirySettingsColors.obsidian,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AirySettingsColors.obsidian,
            ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_outline_rounded,
                    size: 16,
                    color: AirySettingsColors.obsidian,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lines[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AirySettingsColors.inkSecondary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSlideContainer({
    required Widget previewWidget,
    required String title,
    required String description,
  }) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Native UI Preview Mockup
          previewWidget,
          const SizedBox(height: 28),

          // Copywriting Title
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 10),

          // Copywriting Subtitle
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // --- Slide 1 Native UI Preview: Meja Kerja Operasional Harian ---
  Widget _buildSlide1Preview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top search bar mockup
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.search_rounded,
                    size: 16, color: AppColors.textSecondary),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cari unit rental, nama penyewa...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Clean 2x2 Daily Summary Card (uncluttered, no badge truncation)
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Pendapatan Hari Ini',
                  value: 'Rp 1.450.000',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Sewa Hari Ini',
                  value: '14 Unit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  label: 'Pengembalian Hari Ini',
                  value: '6 Unit',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  label: 'Unit Tersedia',
                  value: '28 Unit',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- Slide 2 Native UI Preview: Antrean Sewa Berbasis Urgensi ---
  Widget _buildSlide2Preview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Booking card header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Text(
                    'RC-261030-0004',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Text(
                    '• Dimas Pratama',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'TERLAMBAT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'iPhone 15 Pro 128GB Black Titanium',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Jatuh tempo: Kemarin, 18:00 (Terlambat 17 jam)',
            style: TextStyle(
              fontSize: 11,
              color: AppColors.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: const BorderSide(color: AppColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Rincian',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.obsidian,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Kembalikan',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Slide 3 Native UI Preview: QRIS Dinamis Otomatis ---
  Widget _buildSlide3Preview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // QR Mockup box
          Container(
            width: 136,
            height: 136,
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.qr_code_2_rounded,
                    size: 76, color: AppColors.obsidian),
                const SizedBox(height: 2),
                Text(
                  'QRIS STANDAR',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary.withValues(alpha: 0.8),
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Locked transaction badge - Cleanly centered
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Tagihan Sewa Terkunci',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Rp 50.000',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Pill "Nominal Otomatis Terkunci" - Cleanly centered
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 13, color: AppColors.success),
                  SizedBox(width: 5),
                  Text(
                    'Nominal Otomatis Terkunci',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Slide 4 Native UI Preview: Meja Kasir & Rekap Shift ---
  Widget _buildSlide4Preview() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shift Pagi • Bayu S.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    '08:00 - 15:00 WIB',
                    style:
                        TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'SESUAI (Rp 0)',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total Tunai Fisik di Laci',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  'Rp 1.150.000',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.print_rounded, size: 16),
            label: const Text('Cetak Struk Rekap Shift'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Bottom Controls (Page Indicator & Next Button) ---
  Widget _buildBottomControls(int totalPages) {
    final isLastPage = _currentPage >= totalPages - 1;
    final finishLabel = _isStaffQuickStart
        ? 'Masuk Dashboard'
        : (widget.replayMode ? 'Selesai' : 'Mulai Operasional');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Page Dots
          Row(
            children: List.generate(totalPages, (index) {
              final isCurrent = _currentPage == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isCurrent ? 24 : 8,
                height: 8,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isCurrent ? AppColors.obsidian : AppColors.border,
                ),
              );
            }),
          ),

          // Next / Get Started Button
          ElevatedButton(
            onPressed: _isCompleting ? null : () => _nextPage(totalPages),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.obsidian,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 0,
            ),
            child: _isCompleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    isLastPage ? finishLabel : 'Lanjut',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

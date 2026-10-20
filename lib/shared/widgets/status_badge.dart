import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Unified status badge widget enforcing consistent typography, padding,
/// border radius, and color semantics across RentCore modules.
class StatusBadge extends StatelessWidget {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color? borderColor;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool isLineThrough;

  const StatusBadge({
    super.key,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.borderColor,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.borderRadius = 8,
    this.isLineThrough = false,
  });

  /// Factory for Rental Booking statuses
  factory StatusBadge.rental(String? status, {DateTime? endAt, bool? isOverdue}) {
    final s = (status ?? '').toLowerCase();
    final bool overdue = isOverdue ?? (endAt != null && endAt.isBefore(DateTime.now()) && s != 'returned');

    if (s == 'returned' || s == 'completed') {
      return const StatusBadge(
        label: 'SELESAI',
        textColor: AppColors.textSecondary,
        backgroundColor: AppColors.surfaceMuted,
        icon: Icons.check_circle_outline_rounded,
      );
    }

    if (overdue || s == 'overdue') {
      return const StatusBadge(
        label: 'TERLAMBAT',
        textColor: AppColors.danger,
        backgroundColor: AppColors.dangerLight,
        icon: Icons.warning_amber_rounded,
      );
    }

    if (s == 'active' || s == 'ongoing' || s == 'rented') {
      return const StatusBadge(
        label: 'SEDANG DISEWA',
        textColor: AppColors.info,
        backgroundColor: AppColors.infoLight,
        icon: Icons.schedule_rounded,
      );
    }

    if (s == 'cancelled' || s == 'canceled') {
      return const StatusBadge(
        label: 'DIBATALKAN',
        textColor: AppColors.textMuted,
        backgroundColor: AppColors.surfaceMuted,
        icon: Icons.cancel_outlined,
      );
    }

    // Default / pending
    return StatusBadge(
      label: s.isNotEmpty ? s.toUpperCase() : 'MENUNGGU',
      textColor: AppColors.warning,
      backgroundColor: AppColors.warningLight,
      icon: Icons.hourglass_empty_rounded,
    );
  }

  /// Factory for POS / Booking Payment statuses
  factory StatusBadge.payment(String? status, {String? bookingStatus}) {
    final s = (status ?? '').toLowerCase();

    if (s == 'paid' || s == 'settlement' || s == 'capture') {
      return const StatusBadge(
        label: 'LUNAS',
        textColor: AppColors.success,
        backgroundColor: AppColors.successLight,
        icon: Icons.check_rounded,
      );
    }

    if (s == 'partial') {
      return const StatusBadge(
        label: 'SEBAGIAN',
        textColor: AppColors.warning,
        backgroundColor: AppColors.warningLight,
        icon: Icons.timelapse_rounded,
      );
    }

    if (s == 'refund' || s == 'refunded') {
      return const StatusBadge(
        label: 'REFUND',
        textColor: AppColors.danger,
        backgroundColor: AppColors.dangerLight,
        icon: Icons.replay_rounded,
      );
    }

    if (s == 'void') {
      return const StatusBadge(
        label: 'VOID',
        textColor: AppColors.textMuted,
        backgroundColor: AppColors.surfaceMuted,
        isLineThrough: true,
        icon: Icons.block_rounded,
      );
    }

    return const StatusBadge(
      label: 'BELUM LUNAS',
      textColor: AppColors.danger,
      backgroundColor: AppColors.dangerLight,
      icon: Icons.error_outline_rounded,
    );
  }

  /// Factory for Device / Inventory Asset statuses
  factory StatusBadge.inventory(String? status) {
    final s = (status ?? '').toLowerCase();

    switch (s) {
      case 'ready':
      case 'available':
        return const StatusBadge(
          label: 'Siap Sewa',
          textColor: AppColors.success,
          backgroundColor: AppColors.successLight,
          icon: Icons.check_circle_outline_rounded,
        );
      case 'rented':
      case 'active':
        return const StatusBadge(
          label: 'Sedang Disewa',
          textColor: AppColors.info,
          backgroundColor: AppColors.infoLight,
          icon: Icons.lock_clock_outlined,
        );
      case 'maintenance':
      case 'repair':
        return const StatusBadge(
          label: 'Perawatan',
          textColor: AppColors.danger,
          backgroundColor: AppColors.dangerLight,
          icon: Icons.build_circle_outlined,
        );
      case 'in_transit':
      case 'transferring':
        return const StatusBadge(
          label: 'Dalam Mutasi',
          textColor: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          icon: Icons.swap_horiz_rounded,
        );
      default:
        return StatusBadge(
          label: s.isNotEmpty ? s.toUpperCase() : 'UNKNOWN',
          textColor: AppColors.textSecondary,
          backgroundColor: AppColors.surfaceMuted,
        );
    }
  }

  /// Factory for Inter-Branch Transfer statuses
  factory StatusBadge.transfer(String? status) {
    final s = (status ?? '').toLowerCase();

    switch (s) {
      case 'pending':
        return const StatusBadge(
          label: 'Menunggu Persetujuan',
          textColor: AppColors.warning,
          backgroundColor: AppColors.warningLight,
          icon: Icons.hourglass_top_rounded,
        );
      case 'in_transit':
        return const StatusBadge(
          label: 'Dalam Pengiriman',
          textColor: AppColors.info,
          backgroundColor: AppColors.infoLight,
          icon: Icons.local_shipping_rounded,
        );
      case 'received':
        return const StatusBadge(
          label: 'Diterima',
          textColor: AppColors.success,
          backgroundColor: AppColors.successLight,
          icon: Icons.check_circle_rounded,
        );
      case 'rejected':
        return const StatusBadge(
          label: 'Ditolak',
          textColor: AppColors.danger,
          backgroundColor: AppColors.dangerLight,
          icon: Icons.highlight_off_rounded,
        );
      case 'cancelled':
      default:
        return const StatusBadge(
          label: 'Dibatalkan',
          textColor: AppColors.textMuted,
          backgroundColor: AppColors.surfaceMuted,
          icon: Icons.cancel_rounded,
        );
    }
  }

  /// Factory for Voucher promotional codes
  factory StatusBadge.voucher({required bool isActive, bool isExpired = false}) {
    if (isExpired) {
      return const StatusBadge(
        label: 'Kadaluarsa',
        textColor: AppColors.danger,
        backgroundColor: AppColors.dangerLight,
        icon: Icons.event_busy_rounded,
      );
    }

    if (isActive) {
      return const StatusBadge(
        label: 'Aktif',
        textColor: AppColors.success,
        backgroundColor: AppColors.successLight,
        icon: Icons.check_circle_rounded,
      );
    }

    return const StatusBadge(
      label: 'Nonaktif',
      textColor: AppColors.textMuted,
      backgroundColor: AppColors.surfaceMuted,
      icon: Icons.pause_circle_outline_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: borderColor != null ? Border.all(color: borderColor!) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: textColor,
              decoration: isLineThrough ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}

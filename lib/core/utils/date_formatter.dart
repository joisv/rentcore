import 'package:intl/intl.dart';

class DateFormatter {
  static String formatFull(dynamic dateTime) {
    if (dateTime == null) return '-';
    final dt = dateTime is DateTime ? dateTime : DateTime.tryParse(dateTime.toString());
    if (dt == null) return dateTime.toString();
    try {
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy, HH:mm').format(dt);
    }
  }

  static String formatShort(dynamic dateTime) {
    if (dateTime == null) return '-';
    final dt = dateTime is DateTime ? dateTime : DateTime.tryParse(dateTime.toString());
    if (dt == null) return dateTime.toString();
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(dt);
    }
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    return DateFormat('HH:mm', 'id_ID').format(dateTime);
  }

  static String formatRelative(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.isNegative) {
      final lateDuration = difference.abs();
      final hours = lateDuration.inHours;
      final mins = lateDuration.inMinutes % 60;
      return 'Terlambat ${hours.toString().padLeft(2, '0')}j ${mins.toString().padLeft(2, '0')}m';
    } else {
      final hours = difference.inHours;
      final mins = difference.inMinutes % 60;
      return 'Sisa ${hours.toString().padLeft(2, '0')}j ${mins.toString().padLeft(2, '0')}m';
    }
  }
}

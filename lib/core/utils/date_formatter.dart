import 'package:intl/intl.dart';

class DateFormatter {
  /// Parses a timestamp once into local time without double-shifting local DateTime/naive strings.
  static DateTime? parseLocal(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toLocal();
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toLocal();
  }

  static String formatFull(dynamic dateTime) {
    if (dateTime == null) return '-';
    final dt = dateTime is DateTime
        ? dateTime
        : DateTime.tryParse(dateTime.toString());
    if (dt == null) return dateTime.toString();
    try {
      return DateFormat('d MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy, HH:mm').format(dt);
    }
  }

  static String formatShort(dynamic dateTime) {
    if (dateTime == null) return '-';
    final dt = dateTime is DateTime
        ? dateTime
        : DateTime.tryParse(dateTime.toString());
    if (dt == null) return dateTime.toString();
    try {
      return DateFormat('d MMM yyyy', 'id_ID').format(dt);
    } catch (_) {
      return DateFormat('d MMM yyyy').format(dt);
    }
  }

  static String formatDayMonth(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return DateFormat('dd MMM', 'id_ID').format(dateTime);
    } catch (_) {
      return DateFormat('dd MMM').format(dateTime);
    }
  }

  static String formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    try {
      return DateFormat('HH:mm', 'id_ID').format(dateTime);
    } catch (_) {
      return DateFormat('HH:mm').format(dateTime);
    }
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

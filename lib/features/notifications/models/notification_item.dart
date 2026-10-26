import 'package:intl/intl.dart';

class NotificationItem {
  final int id;
  final int businessId;
  final int? affiliateId;
  final String category;
  final String type;
  final String title;
  final String body;
  final String? actionRoute;
  final Map<String, dynamic>? actionPayload;
  final DateTime? readAt;
  final DateTime createdAt;
  final Map<String, dynamic>? affiliate;

  NotificationItem({
    required this.id,
    required this.businessId,
    this.affiliateId,
    required this.category,
    required this.type,
    required this.title,
    required this.body,
    this.actionRoute,
    this.actionPayload,
    this.readAt,
    required this.createdAt,
    this.affiliate,
  });

  bool get isRead => readAt != null;

  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inSeconds < 60) {
      return 'Baru saja';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} mnt lalu';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} jam lalu';
    } else if (difference.inDays == 1) {
      return 'Kemarin, ${DateFormat('HH:mm').format(createdAt)} WIB';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} hari lalu';
    } else {
      return DateFormat('d MMM yyyy, HH:mm').format(createdAt);
    }
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: json['id'] as int,
      businessId: json['business_id'] as int,
      affiliateId: json['affiliate_id'] as int?,
      category: (json['category'] as String?) ?? 'system',
      type: (json['type'] as String?) ?? 'generic',
      title: (json['title'] as String?) ?? 'Pemberitahuan',
      body: (json['body'] as String?) ?? '',
      actionRoute: json['action_route'] as String?,
      actionPayload: json['action_payload'] is Map<String, dynamic>
          ? json['action_payload'] as Map<String, dynamic>
          : (json['action_payload'] is Map ? Map<String, dynamic>.from(json['action_payload'] as Map) : null),
      readAt: json['read_at'] != null ? DateTime.tryParse(json['read_at'].toString()) : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      affiliate: json['affiliate'] is Map ? Map<String, dynamic>.from(json['affiliate'] as Map) : null,
    );
  }

  NotificationItem copyWith({
    int? id,
    int? businessId,
    int? affiliateId,
    String? category,
    String? type,
    String? title,
    String? body,
    String? actionRoute,
    Map<String, dynamic>? actionPayload,
    DateTime? readAt,
    DateTime? createdAt,
    Map<String, dynamic>? affiliate,
  }) {
    return NotificationItem(
      id: id ?? this.id,
      businessId: businessId ?? this.businessId,
      affiliateId: affiliateId ?? this.affiliateId,
      category: category ?? this.category,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      actionRoute: actionRoute ?? this.actionRoute,
      actionPayload: actionPayload ?? this.actionPayload,
      readAt: readAt ?? this.readAt,
      createdAt: createdAt ?? this.createdAt,
      affiliate: affiliate ?? this.affiliate,
    );
  }
}

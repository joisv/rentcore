import 'package:flutter/material.dart';

/// Extracts a unit or device model image URL from booking/asset/model maps.
String? extractUnitImageUrl({
  Map<dynamic, dynamic>? model,
  Map<dynamic, dynamic>? asset,
  Map<dynamic, dynamic>? primaryItem,
  Map<dynamic, dynamic>? booking,
}) {
  final candidates = [
    model?['image_url'],
    model?['image'],
    model?['photo_url'],
    model?['thumbnail'],
    asset?['image_url'],
    asset?['unit_image_url'],
    primaryItem?['image_url'],
    primaryItem?['unit_image_url'],
    booking?['unit_image_url'],
    booking?['image_url'],
  ];
  for (final c in candidates) {
    final s = c?.toString().trim();
    if (s != null && s.isNotEmpty) {
      return s;
    }
  }
  return null;
}

/// Standardized 44x44 rounded unit thumbnail with seamless monochrome icon fallback.
class UnitThumbnail extends StatelessWidget {
  final String? imageUrl;
  final IconData fallbackIcon;
  final double size;
  final double borderRadius;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;

  const UnitThumbnail({
    super.key,
    required this.imageUrl,
    required this.fallbackIcon,
    this.size = 44,
    this.borderRadius = 10,
    this.iconSize = 22,
    this.backgroundColor = const Color(0xFFF3F4F6),
    this.iconColor = const Color(0xFF374151),
  });

  Widget _buildFallback() {
    return Center(
      child: Icon(
        fallbackIcon,
        size: iconSize,
        color: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trimmedUrl = imageUrl?.trim();
    final hasImage = trimmedUrl != null && trimmedUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: hasImage
          ? ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.network(
                trimmedUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildFallback(),
              ),
            )
          : _buildFallback(),
    );
  }
}

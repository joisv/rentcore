import 'package:flutter/material.dart';
import '../../core/constants/api_constants.dart';

/// Extracts and resolves a unit or device model image URL from booking/asset/model maps.
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
    model?['image_path'],
    asset?['image_url'],
    asset?['unit_image_url'],
    asset?['image_path'],
    primaryItem?['image_url'],
    primaryItem?['unit_image_url'],
    primaryItem?['image_path'],
    booking?['unit_image_url'],
    booking?['image_url'],
  ];
  for (final c in candidates) {
    final resolved = ApiConstants.resolveMediaUrl(c?.toString());
    if (resolved != null && resolved.isNotEmpty) {
      return resolved;
    }
  }
  return null;
}

/// Standardized 44x44 rounded unit thumbnail with crisp #F8FAFC monochrome icon fallback.
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
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.iconColor = const Color(0xFF475569),
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
    final resolvedUrl = ApiConstants.resolveMediaUrl(imageUrl);
    final hasImage = resolvedUrl != null && resolvedUrl.isNotEmpty;

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
                resolvedUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return _buildFallback();
                },
                errorBuilder: (_, _, _) => _buildFallback(),
              ),
            )
          : _buildFallback(),
    );
  }
}

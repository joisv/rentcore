import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/services/secure_token_storage.dart';

/// Displays a network image, attaching Sanctum Bearer and tenant headers when
/// fetching protected API endpoints such as `/api/v1/payment-settings/qris-image`.
class AuthenticatedNetworkImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  const AuthenticatedNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<AuthenticatedNetworkImage> createState() =>
      _AuthenticatedNetworkImageState();
}

class _AuthenticatedNetworkImageState extends State<AuthenticatedNetworkImage> {
  Future<Map<String, String>>? _headersFuture;

  bool get _needsAuthHeaders =>
      widget.url.contains('/payment-settings/qris-image');

  @override
  void initState() {
    super.initState();
    if (_needsAuthHeaders) {
      _headersFuture = _loadHeaders();
    }
  }

  @override
  void didUpdateWidget(covariant AuthenticatedNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _headersFuture = _needsAuthHeaders ? _loadHeaders() : null;
    }
  }

  Future<Map<String, String>> _loadHeaders() async {
    final headers = <String, String>{};
    final token = await SecureTokenStorage().getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final prefs = await SharedPreferences.getInstance();
    final businessId = prefs.getInt('active_business_id');
    final branchId = prefs.getInt('active_branch_id');
    if (businessId != null && businessId > 0) {
      headers['X-Business-Id'] = '$businessId';
    }
    if (branchId != null && branchId > 0) {
      headers['X-Branch-Id'] = '$branchId';
    }
    return headers;
  }

  @override
  Widget build(BuildContext context) {
    if (!_needsAuthHeaders) {
      return Image.network(
        widget.url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder,
      );
    }

    return FutureBuilder<Map<String, String>>(
      future: _headersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return SizedBox(
            width: widget.width,
            height: widget.height,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return Image.network(
          widget.url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          headers: snapshot.data,
          loadingBuilder: widget.loadingBuilder,
          errorBuilder: widget.errorBuilder,
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';
import '../network/api_client.dart';

class LegalLinks {
  /// Derives the Laravel web root URL from [ApiClient.currentBaseUrl]
  /// by stripping trailing `/api/v1` (or `/api/vN`).
  static String get webBaseUrl {
    final raw = ApiClient().currentBaseUrl.trim();
    return raw
        .replaceFirst(RegExp(r'/api/v\d+/?$'), '')
        .replaceFirst(RegExp(r'/$'), '');
  }

  static Uri get privacyPolicyUri => Uri.parse('$webBaseUrl/privacy-policy');

  static Uri get accountDeletionUri => Uri.parse('$webBaseUrl/account-deletion');

  static Future<void> openExternal(
    BuildContext context,
    Uri uri, {
    Future<bool> Function(Uri uri)? launcher,
  }) async {
    bool launched = false;
    try {
      launched = launcher != null
          ? await launcher(uri)
          : await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka tautan: ${uri.toString()}'),
            backgroundColor: AppColors.danger,
          ),
        );
    }
  }
}

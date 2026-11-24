import 'package:flutter/material.dart';

/// Shared Airy Minimalist tokens and building blocks for Settings screens.
class AirySettingsColors {
  const AirySettingsColors._();

  static const Color canvas = Color(0xFFFFFFFF);
  static const Color surfaceSubtle = Color(0xFFF8FAFC);
  static const Color pillSurface = Color(0xFFF1F5F9);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color obsidian = Color(0xFF0F172A);
  static const Color inkMuted = Color(0xFF475569);
  static const Color inkSecondary = Color(0xFF64748B);
}

/// High-contrast minimalist toggle switch matching Rentcore's Airy design system.
Widget airySwitch({
  Key? key,
  required bool value,
  required ValueChanged<bool>? onChanged,
}) {
  return Switch(
    key: key,
    value: value,
    activeThumbColor: Colors.white,
    activeTrackColor: AirySettingsColors.obsidian,
    inactiveThumbColor: Colors.white,
    inactiveTrackColor: AirySettingsColors.border,
    trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    onChanged: onChanged,
  );
}

/// External top field label used above `#F8FAFC` form fields.
Widget airyFieldLabel(String text) {
  return Text(
    text,
    style: const TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w600,
      color: AirySettingsColors.inkMuted,
    ),
  );
}

/// Unified `#F8FAFC` input decoration with hairline `#E2E8F0` border and
/// `#0F172A` focus border.
InputDecoration airyInputDecoration({
  String? hintText,
  String? errorText,
  Widget? prefixIcon,
  Widget? suffixIcon,
  bool enabled = true,
  EdgeInsetsGeometry contentPadding = const EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 13,
  ),
}) {
  final outline = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: AirySettingsColors.border, width: 1),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(
      color: Color(0xFF94A3B8),
      fontSize: 13.5,
      fontWeight: FontWeight.w400,
    ),
    errorText: errorText,
    prefixIcon: prefixIcon,
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: enabled
        ? AirySettingsColors.surfaceSubtle
        : AirySettingsColors.pillSurface,
    contentPadding: contentPadding,
    border: outline,
    enabledBorder: outline,
    disabledBorder: outline,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(
        color: AirySettingsColors.obsidian,
        width: 1.5,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
  );
}

/// Clean `1px` `#F1F5F9` hairline divider between open settings sections.
Widget airyHairlineDivider() {
  return const Divider(
    height: 1,
    thickness: 1,
    color: AirySettingsColors.divider,
  );
}

/// Muted uppercase section header (`12sp`, `w700`, `letterSpacing: 0.4`).
Widget airySectionHeader(String title) {
  return Text(
    title.toUpperCase(),
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.4,
      color: AirySettingsColors.inkSecondary,
    ),
  );
}

/// Hairline-separated sticky footer container anchored at the bottom of a screen.
Widget airyStickyFooter({required Widget child}) {
  return Container(
    decoration: const BoxDecoration(
      color: AirySettingsColors.canvas,
      border: Border(
        top: BorderSide(color: AirySettingsColors.divider, width: 1),
      ),
    ),
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: child,
      ),
    ),
  );
}

/// Standard Rentcore `#0F172A` primary action button.
Widget airyPrimaryCta({
  Key? buttonKey,
  required String label,
  VoidCallback? onPressed,
  bool isLoading = false,
  String loadingLabel = 'Menyimpan...',
  IconData? icon,
  double height = 48,
}) {
  final textWidget = Text(
    isLoading ? loadingLabel : label,
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
    ),
  );

  final style = ElevatedButton.styleFrom(
    backgroundColor: AirySettingsColors.obsidian,
    disabledBackgroundColor: AirySettingsColors.obsidian.withValues(alpha: 0.5),
    foregroundColor: Colors.white,
    disabledForegroundColor: Colors.white,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    padding: const EdgeInsets.symmetric(horizontal: 16),
  );

  return SizedBox(
    width: double.infinity,
    height: height,
    child: (icon != null || isLoading)
        ? ElevatedButton.icon(
            key: buttonKey,
            style: style,
            onPressed: isLoading ? null : onPressed,
            icon: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Icon(icon, size: 18, color: Colors.white),
            label: textWidget,
          )
        : ElevatedButton(
            key: buttonKey,
            style: style,
            onPressed: onPressed,
            child: textWidget,
          ),
  );
}

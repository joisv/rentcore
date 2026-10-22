import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Standardized tactile back button for the RentCore application.
/// Provides a consistent 18dp iOS-style chevron with standard Obsidian coloring.
class RentCoreBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const RentCoreBackButton({
    super.key,
    this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        size: 18,
        color: color ?? AppColors.obsidian,
      ),
      tooltip: 'Kembali',
      onPressed: onPressed ?? () => Navigator.maybePop(context),
    );
  }
}

/// Standardized AppBar component for the RentCore application.
///
/// Features:
/// - Fixed standard height (56dp + bottom widget height)
/// - Unified 17dp w800 Obsidian typography with -0.3 letter spacing
/// - Zero elevation and surface tint shifting
/// - Consistent iOS-style back navigation chevron
/// - Optional subtle bottom border for clean surface separation
class RentCoreAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final bool automaticallyImplyLeading;
  final Widget? leading;
  final VoidCallback? onBackPressed;
  final Color backgroundColor;
  final bool showBottomBorder;
  final bool centerTitle;

  const RentCoreAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.bottom,
    this.automaticallyImplyLeading = true,
    this.leading,
    this.onBackPressed,
    this.backgroundColor = AppColors.surface,
    this.showBottomBorder = false,
    this.centerTitle = false,
  }) : assert(title != null || titleWidget != null || bottom != null, 'Either title, titleWidget, or bottom must be provided');

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0.0),
      );

  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    final bool canPop = parentRoute?.canPop ?? false;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && automaticallyImplyLeading && canPop) {
      leadingWidget = RentCoreBackButton(onPressed: onBackPressed);
    }

    final effectiveTitleWidget = titleWidget ??
        (title != null
            ? Text(
                title!,
                style: const TextStyle(
                  color: AppColors.obsidian,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              )
            : null);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: showBottomBorder
            ? const Border(
                bottom: BorderSide(
                  color: AppColors.borderSubtle,
                  width: 1.0,
                ),
              )
            : null,
      ),
      child: AppBar(
        title: effectiveTitleWidget,
        centerTitle: centerTitle,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: leadingWidget,
        actions: actions,
        bottom: bottom,
      ),
    );
  }
}

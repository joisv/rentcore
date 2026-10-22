import 'package:flutter/material.dart';

/// Constant height allocated for the floating capsule bottom dock
/// including vertical floating margins and shadow clearance.
const double kDockHeight = 96.0;

/// A spacer widget placed at the bottom of scroll views to ensure the last
/// items or interactive buttons are never obscured behind FloatingCapsuleDock.
class DockClearance extends StatelessWidget {
  final double extra;

  const DockClearance({
    super.key,
    this.extra = 0.0,
  });

  @override
  Widget build(BuildContext context) {
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    return SizedBox(height: kDockHeight + bottomSafeArea + extra);
  }
}

/// Helper extension on [EdgeInsets] to easily append dock clearance padding.
extension DockEdgeInsetsExtension on EdgeInsets {
  EdgeInsets withDockClearance(BuildContext context, {double extra = 0.0}) {
    final bottomSafeArea = MediaQuery.paddingOf(context).bottom;
    return copyWith(
      bottom: bottom + kDockHeight + bottomSafeArea + extra,
    );
  }
}

/// Floating action button location that positions the FAB right above
/// the floating capsule bottom dock, respecting device safe area.
class DockFloatingActionButtonLocation extends FloatingActionButtonLocation {
  final double extraOffset;

  const DockFloatingActionButtonLocation({this.extraOffset = 0.0});

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.floatingActionButtonSize.width -
        kFloatingActionButtonMargin;

    final double bottomInset = scaffoldGeometry.minViewPadding.bottom;
    final double fabY = scaffoldGeometry.scaffoldSize.height -
        scaffoldGeometry.floatingActionButtonSize.height -
        kDockHeight -
        bottomInset -
        extraOffset;

    return Offset(fabX, fabY);
  }
}

/// A wrapper layout that ensures content within tabbed screens has proper
/// scrolling clearance above the floating capsule navigation dock.
class DockAwareScaffold extends StatelessWidget {
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Color? backgroundColor;
  final Widget? bottomSheet;
  final bool resizeToAvoidBottomInset;

  const DockAwareScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.backgroundColor,
    this.bottomSheet,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      backgroundColor: backgroundColor,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation ??
          (floatingActionButton != null ? const DockFloatingActionButtonLocation() : null),
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
    );
  }
}

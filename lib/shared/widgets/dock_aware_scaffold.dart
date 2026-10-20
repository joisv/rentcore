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
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomSheet: bottomSheet,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: body,
    );
  }
}

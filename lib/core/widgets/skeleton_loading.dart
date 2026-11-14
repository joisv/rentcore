import 'package:flutter/material.dart';

/// Scope holding the animated soft-grey pulse color driven by [SkeletonPulseWrapper].
class SkeletonPulseScope extends InheritedWidget {
  final Color color;

  const SkeletonPulseScope({
    super.key,
    required this.color,
    required super.child,
  });

  static SkeletonPulseScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<SkeletonPulseScope>();
  }

  static Color of(BuildContext context) {
    return maybeOf(context)?.color ?? const Color(0xFFEEEEEE);
  }

  @override
  bool updateShouldNotify(SkeletonPulseScope oldWidget) {
    return color != oldWidget.color;
  }
}

/// A wrapper that drives a synchronized 1200ms easeInOut pulse animation
/// between [Color(0xFFEEEEEE)] (Colors.grey.shade200) and [Color(0xFFF5F5F5)] (Colors.grey.shade100).
///
/// Shares a single ticker across all child skeleton blocks to eliminate ticker overhead.
class SkeletonPulseWrapper extends StatefulWidget {
  final Widget child;

  const SkeletonPulseWrapper({
    super.key,
    required this.child,
  });

  @override
  State<SkeletonPulseWrapper> createState() => _SkeletonPulseWrapperState();
}

class _SkeletonPulseWrapperState extends State<SkeletonPulseWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFEEEEEE), // Colors.grey.shade200
      end: const Color(0xFFF5F5F5),   // Colors.grey.shade100
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _colorAnimation,
      builder: (context, _) {
        return SkeletonPulseScope(
          color: _colorAnimation.value ?? const Color(0xFFEEEEEE),
          child: widget.child,
        );
      },
    );
  }
}

/// Base rounded block colored with the animated soft-grey pulse.
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  const SkeletonBox.circle({
    super.key,
    required double size,
    this.margin,
  })  : width = size,
        height = size,
        borderRadius = size / 2,
        shape = BoxShape.circle;

  @override
  Widget build(BuildContext context) {
    final color = SkeletonPulseScope.of(context);
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        shape: shape,
        borderRadius:
            shape == BoxShape.circle ? null : BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Standard white container with 12dp border radius and Colors.grey.shade200 border.
class SkeletonCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;

  const SkeletonCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: const Color(0xFFEEEEEE)), // Colors.grey.shade200
      ),
      child: child,
    );
  }
}

// =============================================================================
// COMPOSITE SKELETON WIDGETS MATCHING RENTCORE'S PRIMARY SCREEN LAYOUTS
// =============================================================================

/// 2x2 Summary Grid for Dashboard: 4 [SkeletonCard] blocks, each containing
/// 2 stacked [SkeletonBox] placeholders (short label + wide metric figure).
class DashboardSummaryGridSkeleton extends StatelessWidget {
  const DashboardSummaryGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildMetricCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard()),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildMetricCard()),
            const SizedBox(width: 12),
            Expanded(child: _buildMetricCard()),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard() {
    return const SkeletonCard(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 64, height: 12, borderRadius: 4),
              SkeletonBox(width: 14, height: 14, borderRadius: 4),
            ],
          ),
          SizedBox(height: 8),
          SkeletonBox(width: 96, height: 20, borderRadius: 6),
          SizedBox(height: 6),
          SkeletonBox(width: 72, height: 10, borderRadius: 4),
        ],
      ),
    );
  }
}

/// Booking card skeleton: top row (code + pill badge), middle (2 detail lines),
/// bottom (2 action button blocks).
class BookingCardSkeleton extends StatelessWidget {
  final EdgeInsetsGeometry? margin;

  const BookingCardSkeleton({
    super.key,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonCard(
      margin: margin,
      borderRadius: 16,
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Code + Pill Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 100, height: 14, borderRadius: 4),
              SkeletonBox(width: 72, height: 20, borderRadius: 10),
            ],
          ),
          SizedBox(height: 14),

          // Customer line
          SkeletonBox(width: 160, height: 13, borderRadius: 4),
          SizedBox(height: 8),

          // Unit & rental duration line
          SkeletonBox(width: 220, height: 12, borderRadius: 4),
          SizedBox(height: 14),

          Divider(height: 1, color: Color(0xFFF0F0F0)),
          SizedBox(height: 12),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: SkeletonBox(height: 32, borderRadius: 8),
              ),
              SizedBox(width: 10),
              Expanded(
                child: SkeletonBox(height: 32, borderRadius: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Stacked booking card skeletons for rental queue / transactions list.
class RentalQueueListSkeleton extends StatelessWidget {
  final int count;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  const RentalQueueListSkeleton({
    super.key,
    this.count = 3,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final list = List.generate(count, (_) => const BookingCardSkeleton());
    if (shrinkWrap) {
      return Padding(
        padding: padding ?? EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: list,
        ),
      );
    }
    return ListView(
      physics: physics,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: list,
    );
  }
}

/// Complete Dashboard skeleton matching [HomeScreen] initial loading state:
/// Header placeholder + 2x2 Summary Grid + Rental Queue Skeletons.
class DashboardSkeletonView extends StatelessWidget {
  const DashboardSkeletonView({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulseWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 2x2 Summary Metric Grid
          DashboardSummaryGridSkeleton(),
          SizedBox(height: 20),

          // Section Header Placeholder
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 140, height: 16, borderRadius: 4),
              SkeletonBox(width: 60, height: 14, borderRadius: 4),
            ],
          ),
          SizedBox(height: 12),

          // 3 Stacked Rental Queue Booking Skeletons
          BookingCardSkeleton(),
          BookingCardSkeleton(),
          BookingCardSkeleton(),
        ],
      ),
    );
  }
}

/// Unit Fisik Tab Skeleton: 5 compact horizontal unit cards
/// (square code box + 2 text lines + status pill).
class PhysicalUnitsTabSkeleton extends StatelessWidget {
  final int count;

  const PhysicalUnitsTabSkeleton({
    super.key,
    this.count = 5,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulseWrapper(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: count,
        itemBuilder: (context, index) {
          return const SkeletonCard(
            margin: EdgeInsets.only(bottom: 10),
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            borderRadius: 14,
            child: Row(
              children: [
                // Square code box
                SkeletonBox(width: 44, height: 44, borderRadius: 10),
                SizedBox(width: 12),

                // Model name & Serial lines
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SkeletonBox(width: 140, height: 14, borderRadius: 4),
                      SizedBox(height: 6),
                      SkeletonBox(width: 90, height: 12, borderRadius: 4),
                    ],
                  ),
                ),
                SizedBox(width: 8),

                // Status pill
                SkeletonBox(width: 64, height: 22, borderRadius: 11),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Katalog & Tarif Tab Skeleton: 4 catalog cards
/// (model title + daily rate + metadata line + 2 bottom action button blocks).
class CatalogTabSkeleton extends StatelessWidget {
  final int count;

  const CatalogTabSkeleton({
    super.key,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulseWrapper(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: count,
        itemBuilder: (context, index) {
          return const SkeletonCard(
            margin: EdgeInsets.only(bottom: 12),
            borderRadius: 16,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Model Title + Category Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 150, height: 16, borderRadius: 4),
                    SkeletonBox(width: 60, height: 18, borderRadius: 9),
                  ],
                ),
                SizedBox(height: 10),

                // Daily Rate
                SkeletonBox(width: 110, height: 14, borderRadius: 4),
                SizedBox(height: 8),

                // Metadata line (Stock/Units available)
                SkeletonBox(width: 180, height: 12, borderRadius: 4),
                SizedBox(height: 14),

                Divider(height: 1, color: Color(0xFFF0F0F0)),
                SizedBox(height: 12),

                // 2 Action Button Blocks
                Row(
                  children: [
                    Expanded(
                      child: SkeletonBox(height: 32, borderRadius: 8),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: SkeletonBox(height: 32, borderRadius: 8),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shift Aktif Tab Skeleton: Active shift summary card skeleton + bottom action button placeholder.
class ActiveShiftSkeleton extends StatelessWidget {
  const ActiveShiftSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulseWrapper(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Shift Summary Card
          SkeletonCard(
            borderRadius: 18,
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Cashier Name + Status Pill)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 36, height: 36, borderRadius: 18),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 110, height: 14, borderRadius: 4),
                            SizedBox(height: 4),
                            SkeletonBox(width: 70, height: 11, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                    SkeletonBox(width: 76, height: 22, borderRadius: 11),
                  ],
                ),
                SizedBox(height: 18),

                // 2x2 Financial Metric Placeholders
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 100, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 100, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 100, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 70, height: 11, borderRadius: 4),
                          SizedBox(height: 6),
                          SkeletonBox(width: 100, height: 18, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                Divider(height: 1, color: Color(0xFFF0F0F0)),
                SizedBox(height: 12),

                // Time duration note
                SkeletonBox(width: 160, height: 12, borderRadius: 4),
              ],
            ),
          ),
          SizedBox(height: 16),

          // Bottom Action Button Placeholder
          SkeletonBox(height: 46, borderRadius: 12),
        ],
      ),
    );
  }
}

/// Riwayat Shift Tab Skeleton: 4 shift history cards
/// (header + status pill + 2x2 financial metric placeholders).
class ShiftHistoryTabSkeleton extends StatelessWidget {
  final int count;

  const ShiftHistoryTabSkeleton({
    super.key,
    this.count = 4,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulseWrapper(
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        itemBuilder: (context, index) {
          return const SkeletonCard(
            margin: EdgeInsets.only(bottom: 12),
            borderRadius: 16,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header + Status Pill
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        SkeletonBox(width: 32, height: 32, borderRadius: 8),
                        SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 120, height: 13, borderRadius: 4),
                            SizedBox(height: 4),
                            SkeletonBox(width: 80, height: 11, borderRadius: 4),
                          ],
                        ),
                      ],
                    ),
                    SkeletonBox(width: 68, height: 20, borderRadius: 10),
                  ],
                ),
                SizedBox(height: 14),

                // 2x2 Metric placeholders
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 60, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          SkeletonBox(width: 90, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 60, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          SkeletonBox(width: 90, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 60, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          SkeletonBox(width: 90, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 60, height: 10, borderRadius: 3),
                          SizedBox(height: 4),
                          SkeletonBox(width: 90, height: 14, borderRadius: 4),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Settings & Sub-pages Skeleton: Grouped [SkeletonCard] blocks containing
/// 3-4 menu/toggle row placeholders (title + subtitle + trailing switch/chevron box).
class SettingsGroupSkeleton extends StatelessWidget {
  final int groupCount;
  final int itemsPerGroup;
  final EdgeInsetsGeometry padding;

  const SettingsGroupSkeleton({
    super.key,
    this.groupCount = 2,
    this.itemsPerGroup = 3,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulseWrapper(
      child: ListView.builder(
        padding: padding,
        itemCount: groupCount,
        itemBuilder: (context, groupIndex) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Group Section Title
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: SkeletonBox(width: 100, height: 12, borderRadius: 4),
              ),
              SkeletonCard(
                borderRadius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: List.generate(itemsPerGroup, (itemIndex) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              const SkeletonBox(width: 32, height: 32, borderRadius: 8),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SkeletonBox(width: 130, height: 13, borderRadius: 4),
                                    SizedBox(height: 4),
                                    SkeletonBox(width: 190, height: 11, borderRadius: 4),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              SkeletonBox(
                                width: itemIndex % 2 == 0 ? 36 : 18,
                                height: itemIndex % 2 == 0 ? 20 : 18,
                                borderRadius: itemIndex % 2 == 0 ? 10 : 4,
                              ),
                            ],
                          ),
                        ),
                        if (itemIndex < itemsPerGroup - 1)
                          const Divider(height: 1, indent: 44, color: Color(0xFFF5F5F5)),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }
}

/// Detail Views Skeleton (Detail Sewa, Detail Unit, Detail Shift):
/// Status header card skeleton + key-value row list placeholders.
class DetailViewSkeleton extends StatelessWidget {
  final int rowCount;
  final EdgeInsetsGeometry padding;

  const DetailViewSkeleton({
    super.key,
    this.rowCount = 6,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonPulseWrapper(
      child: ListView(
        padding: padding,
        children: [
          // Status Header Card Skeleton
          const SkeletonCard(
            borderRadius: 18,
            padding: EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonBox(width: 120, height: 13, borderRadius: 4),
                    SkeletonBox(width: 80, height: 22, borderRadius: 11),
                  ],
                ),
                SizedBox(height: 12),
                SkeletonBox(width: 180, height: 24, borderRadius: 6),
                SizedBox(height: 6),
                SkeletonBox(width: 140, height: 12, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Key-Value Rows Card Skeleton
          SkeletonCard(
            borderRadius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: List.generate(rowCount, (index) {
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const SkeletonBox(width: 100, height: 12, borderRadius: 4),
                          SkeletonBox(
                            width: (index % 2 == 0) ? 140 : 100,
                            height: 13,
                            borderRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    if (index < rowCount - 1)
                      const Divider(height: 1, color: Color(0xFFF5F5F5)),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

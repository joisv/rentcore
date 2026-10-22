import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// An expandable Floating Action Button for the RentCore Inventory Screen.
///
/// Provides two distinct inventory management actions:
/// 1. Registrasi Unit — Register a physical device / serial asset.
/// 2. Tambah Model — Create a new inventory catalog model.
///
/// Features smooth 45-degree rotation (+ to ✕), staggered action pop-in,
/// tactile obsidian styling, and full accessibility support.
class ExpandableInventoryFab extends StatefulWidget {
  final VoidCallback onRegisterUnit;
  final VoidCallback onAddModel;
  final VoidCallback? onManageTarif;
  final ValueChanged<bool>? onExpansionChanged;

  const ExpandableInventoryFab({
    super.key,
    required this.onRegisterUnit,
    required this.onAddModel,
    this.onManageTarif,
    this.onExpansionChanged,
  });

  @override
  State<ExpandableInventoryFab> createState() => ExpandableInventoryFabState();
}

class ExpandableInventoryFabState extends State<ExpandableInventoryFab>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _expandAnimation;
  bool _isExpanded = false;

  bool get isExpanded => _isExpanded;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void toggle() {
    if (_isExpanded) {
      collapse();
    } else {
      expand();
    }
  }

  void expand() {
    if (!_isExpanded) {
      setState(() => _isExpanded = true);
      _controller.forward();
      widget.onExpansionChanged?.call(true);
    }
  }

  void collapse() {
    if (_isExpanded) {
      _controller.reverse().then((_) {
        if (mounted) {
          setState(() => _isExpanded = false);
        }
      });
      widget.onExpansionChanged?.call(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _expandAnimation.value;
        final showItems = progress > 0.005;

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (showItems) ...[
              // Action 1: Registrasi Unit (Register physical device/unit)
              _buildActionRow(
                key: const Key('fab_action_registrasi_unit'),
                label: 'Registrasi Unit',
                icon: Icons.devices_rounded,
                progress: progress,
                delayFraction: 0.08,
                onTap: () {
                  collapse();
                  widget.onRegisterUnit();
                },
              ),
              const SizedBox(height: 12),

              // Action 2: Tambah Model (Add inventory catalog model)
              _buildActionRow(
                key: const Key('fab_action_tambah_model'),
                label: 'Tambah Model',
                icon: Icons.post_add_rounded,
                progress: progress,
                delayFraction: 0.0,
                onTap: () {
                  collapse();
                  widget.onAddModel();
                },
              ),
              const SizedBox(height: 14),
            ],

            // Main Primary FAB Button
            _buildMainFab(),
          ],
        );
      },
    );
  }

  Widget _buildActionRow({
    required Key key,
    required String label,
    required IconData icon,
    required double progress,
    required double delayFraction,
    required VoidCallback onTap,
  }) {
    final itemProgress =
        ((progress - delayFraction) / (1.0 - delayFraction)).clamp(0.0, 1.0);
    final curved = Curves.easeOutCubic.transform(itemProgress);

    return Opacity(
      opacity: curved,
      child: Transform.translate(
        offset: Offset(0, (1.0 - curved) * 14),
        child: Transform.scale(
          scale: 0.85 + (curved * 0.15),
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Action label chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.obsidian,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Action icon button (44x44, centered above 56px FAB: (56-44)/2 = 6px margin)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.obsidian,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x28000000),
                            blurRadius: 6,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainFab() {
    return Material(
      color: Colors.transparent,
      elevation: 0,
      child: InkWell(
        key: const Key('inventory_expandable_main_fab'),
        onTap: toggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.obsidian,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: RotationTransition(
              turns: _controller.drive(
                Tween<double>(begin: 0.0, end: 0.125), // 45 degree rotation
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

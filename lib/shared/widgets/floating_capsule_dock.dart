import 'package:flutter/material.dart';

class FloatingCapsuleDock extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onAddTap;

  const FloatingCapsuleDock({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildDockItem(
                index: 0,
                icon: Icons.home_outlined,
                activeIcon: Icons.home_rounded,
              ),
              _buildDockItem(
                index: 1,
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long_rounded,
              ),
              _buildCenterActionButton(),
              _buildDockItem(
                index: 2,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2_rounded,
              ),
              _buildDockItem(
                index: 3,
                icon: Icons.settings_outlined,
                activeIcon: Icons.settings_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterActionButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const Key('nav_center_add_button'),
        borderRadius: BorderRadius.circular(12),
        onTap: onAddTap,
        child: Container(
          width: 48,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.add_rounded,
            size: 24,
            color: Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildDockItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () => onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: AnimatedScale(
          scale: isSelected ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: Icon(
            isSelected ? activeIcon : icon,
            size: 24,
            color: isSelected ? const Color(0xFF111111) : Colors.grey.shade500,
          ),
        ),
      ),
    );
  }
}

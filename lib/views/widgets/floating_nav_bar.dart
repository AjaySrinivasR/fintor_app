// lib/views/widgets/floating_nav_bar.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FloatingNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FloatingNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class ModernFloatingNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<FloatingNavItem> items;

  const ModernFloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            // Sculpted modern border design
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.30),
                      Colors.white.withValues(alpha: 0.08),
                      primaryColor.withValues(alpha: 0.40),
                      Colors.white.withValues(alpha: 0.15),
                    ]
                  : [
                      primaryColor.withValues(alpha: 0.45),
                      const Color(0xFFE2E8F0),
                      primaryColor.withValues(alpha: 0.30),
                      const Color(0xFFCBD5E1),
                    ],
              stops: const [0.0, 0.35, 0.7, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 4),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(1.5), // Border stroke width
            height: 66,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              // 100% OPAQUE background: crisp, solid, zero background box artifact
              color: isDark ? const Color(0xFF0F172A) : Colors.white,
              borderRadius: BorderRadius.circular(30.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(items.length, (index) {
                final item = items[index];
                final isSelected = index == currentIndex;

                return Expanded(
                  child: _NavBarButton(
                    item: item,
                    isSelected: isSelected,
                    primaryColor: primaryColor,
                    onTap: () {
                      if (!isSelected) {
                        HapticFeedback.selectionClick();
                        onTap(index);
                      }
                    },
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  final FloatingNavItem item;
  final bool isSelected;
  final Color primaryColor;
  final VoidCallback onTap;

  const _NavBarButton({
    required this.item,
    required this.isSelected,
    required this.primaryColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const unselectedIconColor = Color(0xFF64748B);
    const unselectedTextColor = Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: AnimatedScale(
        scale: isSelected ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 14 : 8,
                vertical: 3.5,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? primaryColor.withValues(alpha: 0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? primaryColor : unselectedIconColor,
                size: 21,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? primaryColor : unselectedTextColor,
                letterSpacing: -0.2,
              ),
              child: Text(
                item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

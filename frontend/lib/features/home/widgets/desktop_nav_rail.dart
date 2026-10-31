import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// A single item definition for [DesktopNavRail].
class DesktopNavRailItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const DesktopNavRailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

/// Vertical navigation rail for the desktop layout.
///
/// Renders a frosted-glass left sidebar with icon+label items and an optional
/// bottom action slot (e.g. a settings / theme toggle button).
class DesktopNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<DesktopNavRailItem> items;

  /// Optional widget pinned to the bottom of the rail (e.g. avatar button).
  final Widget? bottomAction;

  const DesktopNavRail({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
    this.bottomAction,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final theme = ThemeController.instance;
        final isDark = theme.isDark;
        final primaryColor = theme.primaryColor;
        final bgPreset = theme.bgPreset;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xF01E212B)
                    : bgPreset.cardBg.withOpacity(0.92),
                border: Border(
                  right: BorderSide(
                    color: isDark
                        ? Colors.white.withOpacity(0.08)
                        : bgPreset.border.withOpacity(0.6),
                    width: 0.8,
                  ),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 16),

                    // App logo / brand mark
                    _buildLogo(primaryColor),

                    const SizedBox(height: 24),

                    // Nav items
                    ...List.generate(items.length, (i) {
                      final item = items[i];
                      final isSelected = currentIndex == i;
                      return _NavRailItem(
                        item: item,
                        isSelected: isSelected,
                        primaryColor: primaryColor,
                        isDark: isDark,
                        inactiveColor: bgPreset.textSecondary,
                        onTap: () => onTabSelected(i),
                      );
                    }),

                    const Spacer(),

                    // Bottom pinned action
                    if (bottomAction != null) ...[
                      bottomAction!,
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLogo(Color primaryColor) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.35),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(
        CupertinoIcons.chat_bubble_2_fill,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final DesktopNavRailItem item;
  final bool isSelected;
  final Color primaryColor;
  final Color inactiveColor;
  final bool isDark;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.item,
    required this.isSelected,
    required this.primaryColor,
    required this.inactiveColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? primaryColor : inactiveColor;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Tooltip(
        message: item.label,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(isDark ? 0.18 : 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with optional badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isSelected ? item.activeIcon : item.icon,
                      size: 22,
                      color: iconColor,
                    ),
                    if (item.badgeCount != null && item.badgeCount! > 0)
                      Positioned(
                        top: -4,
                        right: -10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            item.badgeCount! > 99
                                ? '99+'
                                : '${item.badgeCount}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                // Label
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: iconColor,
                    decoration: TextDecoration.none,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                // Active indicator dot
                const SizedBox(height: 3),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSelected ? 4 : 0,
                  height: isSelected ? 4 : 0,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

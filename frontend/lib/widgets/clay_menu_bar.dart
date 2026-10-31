import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/theme_controller.dart';

class ClayMenuBarItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int? badgeCount;

  const ClayMenuBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.badgeCount,
  });
}

class ClayMenuBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final List<ClayMenuBarItem> items;

  const ClayMenuBar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        final bottomInset = MediaQuery.of(context).padding.bottom;
        final theme = ThemeController.instance;
        final isDark = theme.isDark;
        final bgPreset = theme.bgPreset;
        final primaryColor = theme.primaryColor;
        final primaryGradient = theme.primaryGradient;
        final style = theme.navBarStyle;

        // All menu styles share the exact same floating capsule location
        final bottomMargin = bottomInset > 0 ? 16.0 : 10.0;

        final barContent = Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (index) {
            final isSelected = currentIndex == index;
            final item = items[index];

            return Expanded(
              child: GestureDetector(
                onTap: () => onTabSelected(index),
                behavior: HitTestBehavior.opaque,
                child: _buildItem(
                  context,
                  item: item,
                  isSelected: isSelected,
                  styleId: style.id,
                  primaryColor: primaryColor,
                  primaryGradient: primaryGradient,
                  bgPreset: bgPreset,
                  isDark: isDark,
                ),
              ),
            );
          }),
        );

        return Padding(
          padding: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xEE1E212B)
                        : bgPreset.cardBg.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withOpacity(0.12)
                          : bgPreset.border.withOpacity(0.8),
                      width: 1.0,
                    ),
                  ),
                  child: barContent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
    BuildContext context, {
    required ClayMenuBarItem item,
    required bool isSelected,
    required String styleId,
    required Color primaryColor,
    required LinearGradient primaryGradient,
    required AppBackgroundPreset bgPreset,
    required bool isDark,
  }) {
    switch (styleId) {
      case 'floating_dock':
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(isDark ? 0.20 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: _buildIconAndLabel(
            item: item,
            isSelected: isSelected,
            activeColor: primaryColor,
            inactiveColor: bgPreset.textSecondary,
          ),
        );

      case 'minimal_dot':
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildIconWithBadge(
                item: item,
                isSelected: isSelected,
                activeColor: primaryColor,
                inactiveColor: bgPreset.textSecondary,
              ),
              const SizedBox(height: 2),
              Text(
                item.label,
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? primaryColor : bgPreset.textSecondary,
                  decoration: TextDecoration.none,
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 5 : 0,
                height: isSelected ? 5 : 0,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        );

      case 'glass_glow':
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 2.5,
              width: isSelected ? 26 : 0,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 4),
            _buildIconAndLabel(
              item: item,
              isSelected: isSelected,
              activeColor: primaryColor,
              inactiveColor: bgPreset.textSecondary,
            ),
          ],
        );

      case 'filled_capsule':
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            gradient: isSelected ? primaryGradient : null,
            color: isSelected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: _buildIconAndLabel(
            item: item,
            isSelected: isSelected,
            activeColor: Colors.white,
            inactiveColor: bgPreset.textSecondary,
          ),
        );

      case 'clay_pill':
      default:
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? primaryColor.withOpacity(isDark ? 0.20 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: _buildIconAndLabel(
            item: item,
            isSelected: isSelected,
            activeColor: primaryColor,
            inactiveColor: bgPreset.textSecondary,
          ),
        );
    }
  }

  Widget _buildIconAndLabel({
    required ClayMenuBarItem item,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildIconWithBadge(
          item: item,
          isSelected: isSelected,
          activeColor: activeColor,
          inactiveColor: inactiveColor,
        ),
        const SizedBox(height: 2),
        Text(
          item.label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? activeColor : inactiveColor,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }

  Widget _buildIconWithBadge({
    required ClayMenuBarItem item,
    required bool isSelected,
    required Color activeColor,
    required Color inactiveColor,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          isSelected ? item.activeIcon : item.icon,
          size: 22,
          color: isSelected ? activeColor : inactiveColor,
        ),
        if (item.badgeCount != null && item.badgeCount! > 0)
          Positioned(
            top: -3,
            right: -8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                item.badgeCount! > 99 ? '99+' : '${item.badgeCount}',
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
    );
  }
}

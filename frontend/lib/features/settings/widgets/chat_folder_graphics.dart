import 'package:flutter/material.dart';

/// Renders the Telegram-style illustrated folder with colored document tabs.
class ChatFolderHeroGraphic extends StatelessWidget {
  final double size;

  const ChatFolderHeroGraphic({super.key, this.size = 96});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.25,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Background Document (Yellow / Cream)
          Positioned(
            top: size * 0.05,
            left: size * 0.22,
            child: Container(
              width: size * 0.72,
              height: size * 0.45,
              decoration: BoxDecoration(
                color: const Color(0xFFFBBF24),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),

          // Middle Document Tab (Blue)
          Positioned(
            top: size * 0.08,
            left: size * 0.36,
            child: Container(
              width: size * 0.36,
              height: size * 0.38,
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          // Front-most Document Tab (Red / Coral)
          Positioned(
            top: size * 0.12,
            right: size * 0.16,
            child: Container(
              width: size * 0.32,
              height: size * 0.32,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),

          // Main Folder Body (Kraft / Golden Tan)
          Positioned(
            bottom: 0,
            left: size * 0.10,
            right: size * 0.10,
            child: Container(
              height: size * 0.72,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE5B869),
                    Color(0xFFD49E45),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  // Folder Front Flap Crease / Highlight
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: size * 0.24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  // Inner Folder Shadow Line
                  Positioned(
                    top: size * 0.22,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 1.5,
                      color: Colors.black.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Mockup card for "Tabs at the top" vs "Tabs on the left" in Settings
class TabsViewMockupCard extends StatelessWidget {
  final bool isTabsOnLeft;
  final bool isSelected;
  final String label;
  final VoidCallback onTap;

  const TabsViewMockupCard({
    super.key,
    required this.isTabsOnLeft,
    required this.isSelected,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF38BDF8);
    final borderColor = isSelected ? activeColor : const Color(0xFF334155);
    final bgColor = isSelected
        ? activeColor.withOpacity(0.08)
        : const Color(0xFF1E293B).withOpacity(0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 154,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 2.0 : 1.2,
          ),
        ),
        child: Column(
          children: [
            // Diagram Box
            Container(
              height: 96,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? activeColor.withOpacity(0.5)
                      : Colors.white.withOpacity(0.1),
                  width: 0.8,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: isTabsOnLeft
                  ? _buildLeftTabsDiagram(activeColor)
                  : _buildTopTabsDiagram(activeColor),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopTabsDiagram(Color activeColor) {
    return Column(
      children: [
        // Top tabs bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 8,
                decoration: BoxDecoration(
                  color: activeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 22,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 18,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        // Chat rows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                // Text bars
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftTabsDiagram(Color activeColor) {
    return Row(
      children: [
        // Left Tabs rail
        Container(
          width: 22,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            border: Border(
              right: BorderSide(
                color: Colors.white.withOpacity(0.06),
                width: 0.5,
              ),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: activeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        // Chat rows
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                // Text bars
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}


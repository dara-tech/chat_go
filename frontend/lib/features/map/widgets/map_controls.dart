import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Floating camera controls (zoom in/out, map style switch, recenter GPS)
class MapControlsBar extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onRecenterGps;
  final VoidCallback onToggleStyle;
  final VoidCallback? onDirections;
  final bool isLocating;
  final bool isDarkStyle;
  final bool hasDirections;

  const MapControlsBar({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onRecenterGps,
    required this.onToggleStyle,
    this.onDirections,
    this.isLocating = false,
    this.isDarkStyle = false,
    this.hasDirections = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Map Style Toggle
        _buildGlassButton(
          icon: isDarkStyle ? CupertinoIcons.sun_max_fill : CupertinoIcons.moon_fill,
          iconColor: isDarkStyle ? const Color(0xFFFFCC00) : const Color(0xFF6366F1),
          onTap: onToggleStyle,
          tooltip: 'Switch Map Style',
        ),
        const SizedBox(height: 10),

        // Zoom In
        _buildGlassButton(
          icon: CupertinoIcons.add,
          onTap: onZoomIn,
          tooltip: 'Zoom In',
        ),
        const SizedBox(height: 10),
        // Zoom Out
        _buildGlassButton(
          icon: CupertinoIcons.minus,
          onTap: onZoomOut,
          tooltip: 'Zoom Out',
        ),
        const SizedBox(height: 10),

        // Recenter to Current GPS Location
        _buildGlassButton(
          icon: CupertinoIcons.location_fill,
          iconColor: const Color(0xFF007AFF),
          isLoading: isLocating,
          onTap: onRecenterGps,
          tooltip: 'My Location',
        ),

        // Optional Directions Trigger
        if (onDirections != null) ...[
          const SizedBox(height: 10),
          _buildGlassButton(
            icon: CupertinoIcons.arrow_turn_up_right,
            iconColor: hasDirections ? const Color(0xFF34C759) : const Color(0xFF007AFF),
            onTap: onDirections!,
            tooltip: 'Directions',
          ),
        ],
      ],
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
    bool isLoading = false,
    String? tooltip,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CupertinoButton(
            padding: EdgeInsets.zero,
            onPressed: isLoading ? null : onTap,
            child: isLoading
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 9)
                : Icon(icon, color: iconColor, size: 20),
          ),
        ),
      ),
    );
  }
}

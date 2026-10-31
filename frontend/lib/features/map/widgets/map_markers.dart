import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:frontend/core/api/api_client.dart';

/// Pulsing marker for user's GPS position, with optional profile avatar
class UserGpsMarker extends StatefulWidget {
  final double accuracyMeters;
  final Color color;
  final String? avatarUrl;
  final String? username;

  const UserGpsMarker({
    super.key,
    this.accuracyMeters = 20,
    this.color = const Color(0xFF007AFF),
    this.avatarUrl,
    this.username,
  });

  @override
  State<UserGpsMarker> createState() => _UserGpsMarkerState();
}

class _UserGpsMarkerState extends State<UserGpsMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.6).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAvatar = widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty;
    final baseSize = hasAvatar ? 34.0 : 18.0;

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulsing halo
            Container(
              width: (baseSize + 16) * _pulseAnimation.value,
              height: (baseSize + 16) * _pulseAnimation.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withOpacity(
                  (1.0 - (_pulseAnimation.value - 0.8) / 0.8).clamp(0.0, 0.4),
                ),
              ),
            ),
            // White outline / avatar container
            Container(
              width: baseSize,
              height: baseSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: Colors.white, width: 2.2),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: hasAvatar
                  ? ClipOval(
                      child: Image.network(
                        ApiClient.resolveAvatarUrl(widget.avatarUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _buildFallback(),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: widget.color,
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFallback() {
    final name = widget.username ?? 'U';
    return Container(
      color: widget.color,
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// Destination pin with pin tip pointing exactly at coordinate
class DestinationPinMarker extends StatelessWidget {
  final String? label;
  final Color pinColor;
  final IconData icon;

  const DestinationPinMarker({
    super.key,
    this.label,
    this.pinColor = const Color(0xFFFF3B30),
    this.icon = Icons.location_on_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null && label!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label!,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: pinColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        // Pin pointer tip
        ClipPath(
          clipper: _PinTipClipper(),
          child: Container(
            width: 14,
            height: 8,
            color: pinColor,
          ),
        ),
      ],
    );
  }
}

/// User avatar marker showing the user's profile picture directly on the map
class UserAvatarMapMarker extends StatelessWidget {
  final String username;
  final String? avatarUrl;
  final String? label;
  final Color accentColor;
  final Color dotColor;
  final double size;
  final bool isLive;

  const UserAvatarMapMarker({
    super.key,
    required this.username,
    this.avatarUrl,
    this.label,
    Color? dotColor,
    this.accentColor = const Color(0xFF6366F1), // Elegant Indigo / Purple matching screenshot
    this.size = 46,
    this.isLive = false,
  }) : dotColor = dotColor ?? accentColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Optional floating label or live badge
        if (isLive)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF34C759),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'LIVE',
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          )
        else if (label != null && label!.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
            margin: const EdgeInsets.only(bottom: 3),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24, width: 0.8),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 4),
              ],
            ),
            child: Text(
              label!,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // Circular Profile Picture with White Border & Soft Glow
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isLive ? const Color(0xFF34C759) : Colors.white,
                  width: 2.8,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black38,
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: ClipOval(
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? Image.network(
                        ApiClient.resolveAvatarUrl(avatarUrl!),
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => _buildFallbackAvatar(),
                      )
                    : _buildFallbackAvatar(),
              ),
            ),
          ],
        ),

        const SizedBox(height: 2),

        // The Pin Dot underneath (matching user's screenshot exactly!)
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 3,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar() {
    return Container(
      color: dotColor,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: (size * 0.42).roundToDouble(),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PinTipClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

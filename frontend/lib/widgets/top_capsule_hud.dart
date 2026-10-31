import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/theme/liquid_glass_theme.dart';
import '../core/theme/theme_controller.dart';

/// Telegram / Dynamic Island style sleek top capsule HUD notification
class TopCapsuleHud {
  static OverlayEntry? _currentEntry;
  static Timer? _dismissTimer;

  static void show(
    BuildContext context, {
    required String message,
    bool isError = false,
    IconData? customIcon,
    Color? customIconColor,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    HapticFeedback.lightImpact();

    // Dismiss any existing HUD immediately
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;

    final overlay = Overlay.of(context, rootOverlay: true);

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _TopCapsuleHudWidget(
        message: message,
        isError: isError,
        customIcon: customIcon,
        customIconColor: customIconColor,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
        duration: duration,
      ),
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void dismiss() {
    _dismissTimer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _TopCapsuleHudWidget extends StatefulWidget {
  final String message;
  final bool isError;
  final IconData? customIcon;
  final Color? customIconColor;
  final VoidCallback onDismiss;
  final Duration duration;

  const _TopCapsuleHudWidget({
    required this.message,
    required this.isError,
    this.customIcon,
    this.customIconColor,
    required this.onDismiss,
    required this.duration,
  });

  @override
  State<_TopCapsuleHudWidget> createState() => _TopCapsuleHudWidgetState();
}

class _TopCapsuleHudWidgetState extends State<_TopCapsuleHudWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.6),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();

    _timer = Timer(widget.duration, () async {
      if (mounted) {
        await _controller.reverse();
        if (mounted) {
          widget.onDismiss();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  IconData _resolveIcon() {
    if (widget.customIcon != null) return widget.customIcon!;
    if (widget.isError) return CupertinoIcons.exclamationmark_circle_fill;
    final lower = widget.message.toLowerCase();
    if (lower.contains('downloading') || lower.contains('preparing')) {
      return CupertinoIcons.arrow_down_circle_fill;
    }
    if (lower.contains('copied')) {
      return CupertinoIcons.doc_on_clipboard_fill;
    }
    return CupertinoIcons.checkmark_circle_fill;
  }

  Color _resolveIconColor(ThemeController theme) {
    if (widget.customIconColor != null) return widget.customIconColor!;
    if (widget.isError) return const Color(0xFFEF4444);
    final lower = widget.message.toLowerCase();
    if (lower.contains('downloading') || lower.contains('preparing')) {
      return theme.primaryColor;
    }
    return LiquidGlassTheme.accentEmerald;
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = ThemeController.instance;
    final isDark = theme.isDark;

    final capsuleBg = isDark
        ? const Color(0xD81E293B)
        : const Color(0xF2FFFFFF);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : const Color(0xFFE2E8F0);

    final icon = _resolveIcon();
    final iconColor = _resolveIconColor(theme);

    return Positioned(
      top: topPadding + 8,
      left: 16,
      right: 16,
      child: Center(
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Material(
              color: Colors.transparent,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.88,
                    ),
                    decoration: BoxDecoration(
                      color: capsuleBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: borderColor, width: 0.8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 16.5,
                          color: iconColor,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            widget.message,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: theme.textPrimary,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../api/api_client.dart';
import '../theme/liquid_glass_theme.dart';
import '../theme/theme_controller.dart';
import 'notification_alert_service.dart';

class InAppNotificationBannerOverlay extends StatelessWidget {
  const InAppNotificationBannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<InAppNotificationData?>(
      valueListenable: NotificationAlertService.instance.activeAlertNotifier,
      builder: (context, data, _) {
        if (data == null) {
          return const SizedBox.shrink();
        }

        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            top: true,
            bottom: false,
            child: Align(
              alignment: Alignment.topCenter,
              child: Material(
                type: MaterialType.transparency,
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: _NotificationBannerCard(data: data),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NotificationBannerCard extends StatefulWidget {
  final InAppNotificationData data;

  const _NotificationBannerCard({required this.data});

  @override
  State<_NotificationBannerCard> createState() => _NotificationBannerCardState();
}

class _NotificationBannerCardState extends State<_NotificationBannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  double _dragOffsetY = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _slideAnimation = Tween<double>(begin: -50.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismissWithAnimation() {
    _controller.reverse().then((_) {
      NotificationAlertService.instance.dismissAlert();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final isDark = theme.isDark;
    final data = widget.data;
    final avatarUrl = data.avatarUrl;
    final resolvedAvatar = avatarUrl.isNotEmpty ? ApiClient.resolveAvatarUrl(avatarUrl) : '';
    final screenWidth = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value + _dragOffsetY),
          child: Transform.scale(
            scale: _scaleAnimation.value,
            alignment: Alignment.topCenter,
            child: Opacity(
              opacity: _opacityAnimation.value.clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          NotificationAlertService.instance.openChat(data);
        },
        onVerticalDragUpdate: (details) {
          if (details.primaryDelta != null && details.primaryDelta! < 0) {
            setState(() {
              _dragOffsetY += details.primaryDelta!;
            });
          }
        },
        onVerticalDragEnd: (details) {
          if (_dragOffsetY < -20 || (details.primaryVelocity != null && details.primaryVelocity! < -150)) {
            _dismissWithAnimation();
          } else {
            setState(() {
              _dragOffsetY = 0.0;
            });
          }
        },
        child: Container(
          width: screenWidth > 460 ? 420 : screenWidth - 28,
          margin: const EdgeInsets.only(top: 8, bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.50 : 0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
                spreadRadius: 1,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xF0181A22)
                      : Colors.white.withOpacity(0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withOpacity(0.12)
                        : Colors.black.withOpacity(0.08),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LiquidGlassTheme.primaryButtonGradient,
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withOpacity(0.15)
                              : Colors.black.withOpacity(0.06),
                          width: 1.0,
                        ),
                      ),
                      child: resolvedAvatar.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                resolvedAvatar,
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Center(
                                  child: Text(
                                    data.displayName.isNotEmpty
                                        ? data.displayName[0].toUpperCase()
                                        : 'U',
                                    style: GoogleFonts.outfit(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                data.displayName.isNotEmpty
                                    ? data.displayName[0].toUpperCase()
                                    : 'U',
                                style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),

                    // Sender Name + Time + Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  data.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    decoration: TextDecoration.none,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '• now',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? Colors.white.withOpacity(0.45)
                                      : const Color(0xFF64748B),
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            data.content,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w400,
                              color: isDark
                                  ? Colors.white.withOpacity(0.75)
                                  : const Color(0xFF334155),
                              height: 1.25,
                              decoration: TextDecoration.none,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Minimal dismiss 'x' button
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _dismissWithAnimation,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? Colors.white.withOpacity(0.08)
                              : Colors.black.withOpacity(0.05),
                        ),
                        child: Center(
                          child: Icon(
                            CupertinoIcons.xmark,
                            size: 11,
                            color: isDark
                                ? Colors.white.withOpacity(0.6)
                                : const Color(0xFF64748B),
                          ),
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
    );
  }
}

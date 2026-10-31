import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/theme/theme_controller.dart';

/// Interactive hover & tap wrapper that displays the sleek SeenByHoverCard popup
class SeenHoverTarget extends StatefulWidget {
  final Widget child;
  final int groupId;
  final int messageId;
  final List<Map<String, dynamic>> seenByList;
  final int seenCount;
  final bool preferSide; // True for context menu side-flyout, false for chat bubble

  const SeenHoverTarget({
    super.key,
    required this.child,
    required this.groupId,
    required this.messageId,
    required this.seenByList,
    required this.seenCount,
    this.preferSide = false,
  });

  @override
  State<SeenHoverTarget> createState() => _SeenHoverTargetState();
}

class _SeenHoverTargetState extends State<SeenHoverTarget> {
  OverlayEntry? _overlayEntry;
  Timer? _closeTimer;
  bool _isHoveredTarget = false;
  bool _isHoveredCard = false;

  @override
  void dispose() {
    _closeTimer?.cancel();
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _cancelCloseTimer() {
    _closeTimer?.cancel();
    _closeTimer = null;
  }

  void _scheduleClose() {
    _cancelCloseTimer();
    _closeTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted && !_isHoveredTarget && !_isHoveredCard) {
        _removeOverlay();
      }
    });
  }

  void _showPopover() {
    _cancelCloseTimer();
    if (_overlayEntry != null) return;
    if (widget.seenCount <= 0 && widget.seenByList.isEmpty) return;

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final targetOffset = renderBox.localToGlobal(Offset.zero);
    final targetSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    const double popoverWidth = 205.0;
    const double popoverEstimatedHeight = 180.0;

    double left;
    double top;

    if (widget.preferSide) {
      // Place to right if space available, otherwise to the left
      if (targetOffset.dx + targetSize.width + popoverWidth + 10 <= screenSize.width) {
        left = targetOffset.dx + targetSize.width + 6;
      } else {
        left = targetOffset.dx - popoverWidth - 6;
      }
      top = targetOffset.dy.clamp(16.0, screenSize.height - popoverEstimatedHeight - 16);
    } else {
      // Place above target if space available, otherwise below
      if (targetOffset.dy - popoverEstimatedHeight - 8 >= 40) {
        top = targetOffset.dy - popoverEstimatedHeight - 6;
      } else {
        top = targetOffset.dy + targetSize.height + 6;
      }
      left = (targetOffset.dx + targetSize.width - popoverWidth).clamp(10.0, screenSize.width - popoverWidth - 10);
    }

    _overlayEntry = OverlayEntry(
      builder: (ctx) {
        return Stack(
          children: [
            // Tap outside barrier to dismiss on touch
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _removeOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              child: MouseRegion(
                onEnter: (_) {
                  _isHoveredCard = true;
                  _cancelCloseTimer();
                },
                onExit: (_) {
                  _isHoveredCard = false;
                  _scheduleClose();
                },
                child: Material(
                  color: Colors.transparent,
                  child: SeenByHoverCard(
                    groupId: widget.groupId,
                    messageId: widget.messageId,
                    initialSeenBy: widget.seenByList,
                    seenCount: widget.seenCount,
                    onClose: _removeOverlay,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_overlayEntry!);
  }

  void _togglePopover() {
    if (_overlayEntry != null) {
      _removeOverlay();
    } else {
      _showPopover();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: (widget.seenCount > 0 || widget.seenByList.isNotEmpty)
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        _isHoveredTarget = true;
        _showPopover();
      },
      onExit: (_) {
        _isHoveredTarget = false;
        _scheduleClose();
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _togglePopover,
        child: widget.child,
      ),
    );
  }
}

/// Compact floating popover card showing seen count and list of readers
class SeenByHoverCard extends StatefulWidget {
  final int groupId;
  final int messageId;
  final List<Map<String, dynamic>> initialSeenBy;
  final int seenCount;
  final VoidCallback? onClose;

  const SeenByHoverCard({
    super.key,
    required this.groupId,
    required this.messageId,
    required this.initialSeenBy,
    required this.seenCount,
    this.onClose,
  });

  @override
  State<SeenByHoverCard> createState() => _SeenByHoverCardState();
}

class _SeenByHoverCardState extends State<SeenByHoverCard> {
  late List<Map<String, dynamic>> _seenBy;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _seenBy = List.from(widget.initialSeenBy);
    if (widget.groupId > 0 && widget.messageId > 0 && _seenBy.isEmpty) {
      _loadReaders();
    }
  }

  Future<void> _loadReaders() async {
    setState(() => _isLoading = true);
    try {
      final readers = await ApiClient.instance.getGroupMessageReaders(widget.groupId, widget.messageId);
      if (mounted && readers.isNotEmpty) {
        setState(() {
          _seenBy = readers;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatReadTime(dynamic val) {
    if (val == null) return '';
    DateTime? dt;
    if (val is DateTime) {
      dt = val.toLocal();
    } else {
      dt = DateTime.tryParse(val.toString())?.toLocal();
    }
    if (dt == null) return '';
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final totalCount = _seenBy.length > widget.seenCount ? _seenBy.length : widget.seenCount;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Opacity(
          opacity: animValue,
          child: Transform.scale(
            scale: 0.94 + 0.06 * animValue,
            alignment: Alignment.center,
            child: child,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: 200,
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: theme.cardBg.withOpacity(0.96),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: theme.border.withOpacity(0.7),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6.5),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.done_all,
                        size: 14,
                        color: Color(0xFF67E8F9), // Electric cyan
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          totalCount > 0 ? 'Seen by $totalCount' : 'Seen',
                          style: GoogleFonts.inter(
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                            letterSpacing: -0.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 0.5,
                  thickness: 0.5,
                  color: theme.divider.withOpacity(0.5),
                ),

                // Readers list
                if (_isLoading && _seenBy.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: CupertinoActivityIndicator(radius: 7),
                    ),
                  )
                else if (_seenBy.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
                    child: Text(
                      'No readers yet',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: theme.textSecondary,
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      itemCount: _seenBy.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 0.5,
                        thickness: 0.4,
                        indent: 36,
                        color: theme.divider.withOpacity(0.25),
                      ),
                      itemBuilder: (ctx, i) {
                        final reader = _seenBy[i];
                        final name = (reader['display_name'] ?? reader['username'] ?? 'User').toString();
                        final avatarUrl = (reader['avatar_url'] ?? '').toString();
                        final timeStr = _formatReadTime(reader['read_at']);

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              // 22px avatar
                              Container(
                                width: 22,
                                height: 22,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF6366F1),
                                ),
                                child: ClipOval(
                                  child: avatarUrl.isNotEmpty
                                      ? Image.network(
                                          ApiClient.resolveAvatarUrl(avatarUrl),
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => _buildFallback(name),
                                        )
                                      : _buildFallback(name),
                                ),
                              ),
                              const SizedBox(width: 7),
                              // Name
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w500,
                                    color: theme.textPrimary,
                                    letterSpacing: -0.1,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (timeStr.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.done_all,
                                      size: 11,
                                      color: Color(0xFF67E8F9),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.inter(
                                        fontSize: 10.0,
                                        color: theme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildFallback(String name) {
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : 'U';
    return Center(
      child: Text(
        initial,
        style: GoogleFonts.outfit(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }
}

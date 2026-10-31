import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/services/media_download_service.dart';
import 'package:frontend/core/theme/liquid_glass_theme.dart';

class MediaViewerItem {
  final String id;
  final String mediaUrl;
  final String senderName;
  final DateTime timestamp;
  final String? caption;
  final bool isMe;
  final Map<String, dynamic>? rawMessage;

  const MediaViewerItem({
    required this.id,
    required this.mediaUrl,
    required this.senderName,
    required this.timestamp,
    this.caption,
    this.isMe = false,
    this.rawMessage,
  });
}

class MediaViewerScreen extends StatefulWidget {
  final List<MediaViewerItem> items;
  final int initialIndex;
  final void Function(Map<String, dynamic> rawMessage)? onForward;
  final void Function(Map<String, dynamic> rawMessage)? onDelete;

  const MediaViewerScreen({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onForward,
    this.onDelete,
  });

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;

  bool _showControls = true;
  double _dragOffsetY = 0.0;
  bool _isZoomed = false;

  late AnimationController _animController;
  Animation<double>? _resetDragAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.isEmpty ? 0 : widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _scrollToThumbnail(int index) {
    if (!_thumbnailScrollController.hasClients || widget.items.length <= 1) return;
    const itemWidth = 56.0;
    final screenWidth = MediaQuery.of(context).size.width;
    final targetOffset = (index * itemWidth) - (screenWidth / 2) + (itemWidth / 2);
    _thumbnailScrollController.animateTo(
      targetOffset.clamp(0.0, _thumbnailScrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
      _isZoomed = false;
    });
    _scrollToThumbnail(index);
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  String _formatFullDate(DateTime dt) {
    final now = DateTime.now();
    final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$h:$m $ampm';

    if (isToday) {
      return 'Today at $timeStr';
    }

    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final monthStr = months[dt.month - 1];
    return '$monthStr ${dt.day}, ${dt.year} at $timeStr';
  }

  void _copyLink(String url) {
    Clipboard.setData(ClipboardData(text: url));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No media to display', style: TextStyle(color: Colors.white))),
      );
    }

    final currentItem = widget.items[_currentIndex];
    final screenHeight = MediaQuery.of(context).size.height;
    final dragFraction = (_dragOffsetY.abs() / (screenHeight * 0.4)).clamp(0.0, 1.0);
    final backgroundOpacity = (1.0 - (dragFraction * 0.7)).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: Colors.black.withOpacity(backgroundOpacity),
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Interactive PageView with vertical swipe to dismiss
          GestureDetector(
            onVerticalDragUpdate: _isZoomed
                ? null
                : (details) {
                    setState(() {
                      _dragOffsetY += details.delta.dy;
                    });
                  },
            onVerticalDragEnd: _isZoomed
                ? null
                : (details) {
                    if (_dragOffsetY.abs() > 120 || details.primaryVelocity!.abs() > 800) {
                      Navigator.of(context).pop();
                    } else {
                      // Spring back to center
                      final start = _dragOffsetY;
                      _resetDragAnimation = Tween<double>(begin: start, end: 0.0).animate(
                        CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
                      )..addListener(() {
                          setState(() {
                            _dragOffsetY = _resetDragAnimation!.value;
                          });
                        });
                      _animController.forward(from: 0.0);
                    }
                  },
            child: Transform.translate(
              offset: Offset(0, _dragOffsetY),
              child: PageView.builder(
                controller: _pageController,
                physics: _isZoomed
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemCount: widget.items.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _ZoomableMediaPage(
                    item: widget.items[index],
                    onTap: _toggleControls,
                    onZoomChanged: (zoomed) {
                      if (_isZoomed != zoomed) {
                        setState(() {
                          _isZoomed = zoomed;
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ),

          // Top Header Bar
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            top: _showControls ? 0 : -100,
            left: 0,
            right: 0,
            child: _buildTopBar(currentItem),
          ),

          // Bottom Bar & Caption
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            bottom: _showControls ? 0 : -140,
            left: 0,
            right: 0,
            child: _buildBottomArea(currentItem),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(MediaViewerItem currentItem) {
    final topPadding = MediaQuery.of(context).padding.top;
    final resolvedUrl = ApiClient.resolveAvatarUrl(currentItem.mediaUrl);

    return Container(
      padding: EdgeInsets.only(top: topPadding + 6, bottom: 12, left: 12, right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withOpacity(0.75),
            Colors.black.withOpacity(0.40),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.20), width: 0.8),
              ),
              child: const Center(
                child: Icon(CupertinoIcons.chevron_back, color: Colors.white, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Sender Info & Timestamp
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        currentItem.isMe ? 'You' : currentItem.senderName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (widget.items.length > 1) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_currentIndex + 1} of ${widget.items.length}',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _formatFullDate(currentItem.timestamp),
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w400,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons: Download, Share, Copy link, Forward, Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_down_to_line, color: Colors.white, size: 20),
                tooltip: 'Save to Photos',
                onPressed: () {
                  final filename = currentItem.mediaUrl.split('/').last.split('?').first;
                  MediaDownloadService.instance.saveToGallery(
                    context,
                    url: currentItem.mediaUrl,
                    filename: filename.isNotEmpty ? filename : 'media.jpg',
                  );
                },
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.share, color: Colors.white, size: 20),
                tooltip: 'Share',
                onPressed: () {
                  final filename = currentItem.mediaUrl.split('/').last.split('?').first;
                  MediaDownloadService.instance.shareMedia(
                    context,
                    url: currentItem.mediaUrl,
                    filename: filename.isNotEmpty ? filename : 'media',
                  );
                },
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.link, color: Colors.white, size: 20),
                tooltip: 'Copy link',
                onPressed: () => _copyLink(resolvedUrl),
              ),
              if (widget.onForward != null && currentItem.rawMessage != null)
                IconButton(
                  icon: const Icon(CupertinoIcons.arrowshape_turn_up_right, color: Colors.white, size: 20),
                  tooltip: 'Forward',
                  onPressed: () {
                    final raw = currentItem.rawMessage!;
                    Navigator.of(context).pop();
                    widget.onForward!(raw);
                  },
                ),
              if (currentItem.isMe && widget.onDelete != null && currentItem.rawMessage != null)
                IconButton(
                  icon: const Icon(CupertinoIcons.delete, color: Color(0xFFF87171), size: 20),
                  tooltip: 'Delete',
                  onPressed: () {
                    final raw = currentItem.rawMessage!;
                    Navigator.of(context).pop();
                    widget.onDelete!(raw);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomArea(MediaViewerItem currentItem) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomPadding + 8, top: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withOpacity(0.85),
            Colors.black.withOpacity(0.50),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Caption if available
          if (currentItem.caption != null && currentItem.caption!.trim().isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.8),
                ),
                child: Text(
                  currentItem.caption!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.white,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],

          // Thumbnail gallery strip (if multiple photos in chat)
          if (widget.items.length > 1) ...[
            const SizedBox(height: 6),
            SizedBox(
              height: 52,
              child: ListView.separated(
                controller: _thumbnailScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: widget.items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, idx) {
                  final item = widget.items[idx];
                  final isSelected = idx == _currentIndex;
                  final thumbUrl = ApiClient.resolveAvatarUrl(item.mediaUrl);

                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(
                        idx,
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? LiquidGlassTheme.accentBlue
                              : Colors.white.withOpacity(0.20),
                          width: isSelected ? 2.5 : 0.8,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: LiquidGlassTheme.accentBlue.withOpacity(0.50),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                )
                              ]
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          thumbUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) {
                            if (progress == null) return child;
                            return Container(color: Colors.white10);
                          },
                          errorBuilder: (ctx, err, stack) => Container(
                            color: Colors.white10,
                            child: const Icon(CupertinoIcons.photo, color: Colors.white38, size: 16),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ZoomableMediaPage extends StatefulWidget {
  final MediaViewerItem item;
  final VoidCallback onTap;
  final ValueChanged<bool> onZoomChanged;

  const _ZoomableMediaPage({
    required this.item,
    required this.onTap,
    required this.onZoomChanged,
  });

  @override
  State<_ZoomableMediaPage> createState() => _ZoomableMediaPageState();
}

class _ZoomableMediaPageState extends State<_ZoomableMediaPage>
    with SingleTickerProviderStateMixin {
  late TransformationController _transformationController;
  late AnimationController _animationController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    _transformationController = TransformationController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );

    _transformationController.addListener(() {
      final scale = _transformationController.value.getMaxScaleOnAxis();
      widget.onZoomChanged(scale > 1.05);
    });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _handleDoubleTap(TapDownDetails details) {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    final targetScale = currentScale > 1.2 ? 1.0 : 2.5;

    final targetMatrix = Matrix4.identity();
    if (targetScale > 1.0) {
      final position = details.localPosition;
      targetMatrix
        ..translate(-position.dx * (targetScale - 1), -position.dy * (targetScale - 1))
        ..scale(targetScale);
    }

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: targetMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic))
      ..addListener(() {
        _transformationController.value = _zoomAnimation!.value;
      });

    _animationController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final resolvedUrl = ApiClient.resolveAvatarUrl(widget.item.mediaUrl);

    return GestureDetector(
      onTap: widget.onTap,
      onDoubleTapDown: _handleDoubleTap,
      child: Center(
        child: InteractiveViewer(
          transformationController: _transformationController,
          minScale: 1.0,
          maxScale: 4.5,
          panEnabled: true,
          scaleEnabled: true,
          child: Hero(
            tag: 'hero_media_${widget.item.id}_${widget.item.mediaUrl}',
            child: Image.network(
              resolvedUrl,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                final expected = progress.expectedTotalBytes;
                final downloaded = progress.cumulativeBytesLoaded;
                final fraction = expected != null && expected > 0
                    ? downloaded / expected
                    : null;

                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CupertinoActivityIndicator(color: Colors.white, radius: 14),
                      if (fraction != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          '${(fraction * 100).toInt()}%',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.exclamationmark_triangle,
                          color: Colors.amber,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load media',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          resolvedUrl,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

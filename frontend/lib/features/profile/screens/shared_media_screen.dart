import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/api/api_client.dart';
import '../../../core/services/media_download_service.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../models/user_model.dart';
import '../../media/screens/media_viewer_screen.dart';

class SharedMediaScreen extends StatefulWidget {
  final UserModel? user;
  final String? title;
  final List<Map<String, dynamic>> mediaItems;
  final List<Map<String, dynamic>> fileItems;
  final List<Map<String, dynamic>> linkItems;
  final Future<void> Function()? onRefresh;

  const SharedMediaScreen({
    super.key,
    this.user,
    this.title,
    required this.mediaItems,
    required this.fileItems,
    required this.linkItems,
    this.onRefresh,
  });

  @override
  State<SharedMediaScreen> createState() => _SharedMediaScreenState();
}

class _SharedMediaScreenState extends State<SharedMediaScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late List<Map<String, dynamic>> _media;
  late List<Map<String, dynamic>> _files;
  late List<Map<String, dynamic>> _links;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _media = List.from(widget.mediaItems);
    _files = List.from(widget.fileItems);
    _links = List.from(widget.linkItems);
  }

  @override
  void didUpdateWidget(covariant SharedMediaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.mediaItems != widget.mediaItems) {
      _media = List.from(widget.mediaItems);
    }
    if (oldWidget.fileItems != widget.fileItems) {
      _files = List.from(widget.fileItems);
    }
    if (oldWidget.linkItems != widget.linkItems) {
      _links = List.from(widget.linkItems);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _openMediaViewer(int initialIndex) {
    if (_media.isEmpty) return;
    final viewerItems = _media.map((m) {
      final url = (m['media_url'] as String? ?? '').trim();
      final senderName = (m['username'] as String?) ?? widget.user?.displayName ?? widget.title ?? 'Sender';
      final content = (m['content'] as String?) ?? '';
      return MediaViewerItem(
        id: '${m['id'] ?? url}',
        mediaUrl: ApiClient.resolveAvatarUrl(url),
        senderName: senderName,
        timestamp: DateTime.tryParse(m['created_at']?.toString() ?? '') ?? DateTime.now(),
        caption: content.isNotEmpty && content != 'Photo' ? content : null,
      );
    }).toList();

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => MediaViewerScreen(
          items: viewerItems,
          initialIndex: initialIndex.clamp(0, viewerItems.length - 1),
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied to clipboard', style: GoogleFonts.inter(fontSize: 13)),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: LiquidGlassTheme.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LiquidGlassTheme.bgSurface,
      body: Stack(
        children: [
          // Background ambient gradient
          Positioned(
            top: -50,
            left: -40,
            right: -40,
            height: 260,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    LiquidGlassTheme.accentBlue.withOpacity(LiquidGlassTheme.isDark ? 0.12 : 0.07),
                    LiquidGlassTheme.bgSurface.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                _buildTabs(),
                const SizedBox(height: 12),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildMediaTab(),
                      _buildFilesTab(),
                      _buildLinksTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
                border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
              ),
              child: Icon(
                CupertinoIcons.chevron_left,
                size: 18,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Media, Files & Links',
                  style: GoogleFonts.outfit(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlassTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.title ??
                      (widget.user != null
                          ? (widget.user!.displayName.isNotEmpty
                              ? widget.user!.displayName
                              : '@${widget.user!.username}')
                          : 'Shared Content'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final tabs = [
      'Media (${_media.length})',
      'Files (${_files.length})',
      'Links (${_links.length})',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: LiquidGlassTheme.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _tabController.index == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => _tabController.animateTo(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? LiquidGlassTheme.accentBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  tabs[index],
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? Colors.white : LiquidGlassTheme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // --- TAB 1: MEDIA GRID ---
  Widget _buildMediaTab() {
    if (_media.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.photo_on_rectangle,
        title: 'No Shared Media',
        subtitle: 'Photos and videos sent in this chat will appear here.',
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: LiquidGlassTheme.accentBlue,
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1.0,
        ),
        itemCount: _media.length,
        itemBuilder: (context, index) {
          final item = _media[index];
          final rawUrl = (item['media_url'] as String? ?? '').trim();
          final resolvedUrl = ApiClient.resolveAvatarUrl(rawUrl);

          return GestureDetector(
            onTap: () => _openMediaViewer(index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: LiquidGlassTheme.inputFill,
                    child: Image.network(
                      resolvedUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, err, stack) => Center(
                        child: Icon(
                          CupertinoIcons.photo,
                          size: 24,
                          color: LiquidGlassTheme.textMuted,
                        ),
                      ),
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              valueColor: AlwaysStoppedAnimation<Color>(LiquidGlassTheme.accentBlue),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.black.withOpacity(0.4), Colors.transparent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- TAB 2: FILES & VOICE NOTES ---
  Widget _buildFilesTab() {
    if (_files.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.doc_fill,
        title: 'No Shared Files',
        subtitle: 'Documents and voice notes sent in this chat will appear here.',
      );
    }

    return ListenableBuilder(
      listenable: MediaDownloadService.instance,
      builder: (context, _) {
        return RefreshIndicator(
          onRefresh: widget.onRefresh ?? () async {},
          color: LiquidGlassTheme.accentBlue,
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: _files.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
            itemBuilder: (context, index) {
              final file = _files[index];
              final mediaType = (file['media_type'] as String? ?? 'file').toLowerCase();
              final isVoice = mediaType == 'voice' || mediaType == 'audio';
              final content = (file['content'] as String? ?? '').trim();
              final url = (file['media_url'] as String? ?? '').trim();
              final filename =
                  content.isNotEmpty ? content : (url.isNotEmpty ? url.split('/').last : 'Document');

              final downloadService = MediaDownloadService.instance;
              final downloadState = downloadService.getState(url, filename: filename);
              final isDownloading = downloadState.status == DownloadStatus.downloading;
              final isDownloaded = downloadService.isDownloaded(url, filename: filename);

              return InkWell(
                onTap: () {
                  if (url.isNotEmpty) {
                    if (isDownloading) return;
                    downloadService.openMedia(context, url: url, filename: filename);
                  }
                },
                onLongPress: () {
                  if (url.isNotEmpty) {
                    downloadService.showMediaOptionsSheet(
                      context,
                      url: url,
                      filename: filename,
                    );
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: (isVoice ? LiquidGlassTheme.accentEmerald : const Color(0xFF0D9488))
                              .withOpacity(0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isVoice ? CupertinoIcons.mic_fill : CupertinoIcons.doc_fill,
                          size: 21,
                          color: isVoice ? LiquidGlassTheme.accentEmerald : const Color(0xFF0D9488),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: LiquidGlassTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDownloading
                                  ? 'Downloading ${(downloadState.progress * 100).toInt()}%'
                                  : isDownloaded
                                      ? 'Downloaded • Tap to open'
                                      : (isVoice ? 'Voice note' : 'Document file'),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: isDownloading
                                    ? LiquidGlassTheme.accentBlue
                                    : isDownloaded
                                        ? LiquidGlassTheme.accentEmerald
                                        : LiquidGlassTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isDownloading)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: downloadState.progress > 0.05 ? downloadState.progress : null,
                            strokeWidth: 2,
                            color: LiquidGlassTheme.accentBlue,
                          ),
                        )
                      else if (isDownloaded)
                        GestureDetector(
                          onTap: () {
                            if (url.isNotEmpty) {
                              downloadService.saveAs(context, url: url, filename: filename);
                            }
                          },
                          child: Tooltip(
                            message: 'Save As',
                            child: Icon(
                              CupertinoIcons.arrow_down_doc,
                              size: 20,
                              color: LiquidGlassTheme.accentEmerald,
                            ),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: () {
                            if (url.isNotEmpty) {
                              downloadService.saveAs(context, url: url, filename: filename);
                            }
                          },
                          child: Tooltip(
                            message: 'Save As',
                            child: Icon(
                              CupertinoIcons.arrow_down_circle,
                              size: 20,
                              color: LiquidGlassTheme.textSecondary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // --- TAB 3: LINKS ---
  Widget _buildLinksTab() {
    if (_links.isEmpty) {
      return _buildEmptyState(
        icon: CupertinoIcons.link,
        title: 'No Shared Links',
        subtitle: 'Web links shared in this conversation will be cataloged here.',
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh ?? () async {},
      color: LiquidGlassTheme.accentBlue,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _links.length,
        separatorBuilder: (context, index) =>
            Divider(height: 1, indent: 56, color: LiquidGlassTheme.dividerHairline),
        itemBuilder: (context, index) {
          final link = _links[index];
          final url = link['url'] as String? ?? '';
          final content = link['content'] as String? ?? url;

          return InkWell(
            onTap: () => _copyToClipboard(url, 'Link'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentBlue.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      CupertinoIcons.link,
                      size: 20,
                      color: LiquidGlassTheme.accentBlue,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: LiquidGlassTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: LiquidGlassTheme.accentBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    CupertinoIcons.doc_on_doc,
                    size: 18,
                    color: LiquidGlassTheme.textSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: LiquidGlassTheme.inputFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: LiquidGlassTheme.textSecondary.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: LiquidGlassTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: LiquidGlassTheme.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

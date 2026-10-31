import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/models/user_model.dart';
import '../../chat/services/media_upload_manager.dart';
import 'location_view.dart';
import 'media_review_modal.dart';

class MediaAttachmentPickerSheet extends StatefulWidget {
  final UserModel? currentUser;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onPickFile;
  final Function(String title, String address) onSendLocation;
  final Function(List<int> bytes, String filename) onSendPhotoBytes;
  final Function(List<LocalMediaAttachment> items, String caption)? onSendMultiMedia;
  final VoidCallback? onSendGift;
  final VoidCallback? onSendPoll;
  final VoidCallback? onSendChecklist;

  const MediaAttachmentPickerSheet({
    super.key,
    this.currentUser,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onPickFile,
    required this.onSendLocation,
    required this.onSendPhotoBytes,
    this.onSendMultiMedia,
    this.onSendGift,
    this.onSendPoll,
    this.onSendChecklist,
  });

  @override
  State<MediaAttachmentPickerSheet> createState() => _MediaAttachmentPickerSheetState();
}

class _MediaAttachmentPickerSheetState extends State<MediaAttachmentPickerSheet> {
  String _activeTab = 'Gallery';
  List<AssetEntity> _assets = [];
  final List<AssetEntity> _selectedAssets = [];
  bool _isLoadingPhotos = true;

  @override
  void initState() {
    super.initState();
    _loadDevicePhotos();
  }

  Future<void> _loadDevicePhotos() async {
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (permission.isAuth || permission.hasAccess) {
        final albums = await PhotoManager.getAssetPathList(
          type: RequestType.common, // photos and videos
          onlyAll: true,
        );
        if (albums.isNotEmpty) {
          final recentAssets = await albums.first.getAssetListPaged(page: 0, size: 80);
          if (mounted) {
            setState(() {
              _assets = recentAssets;
              _isLoadingPhotos = false;
            });
            return;
          }
        }
      }
    } catch (_) {
      // Permission or platform fallback
    }
    if (mounted) {
      setState(() => _isLoadingPhotos = false);
    }
  }

  void _toggleAssetSelection(AssetEntity asset) {
    setState(() {
      final index = _selectedAssets.indexWhere((a) => a.id == asset.id);
      if (index >= 0) {
        _selectedAssets.removeAt(index);
      } else {
        _selectedAssets.add(asset);
      }
    });
  }

  Future<void> _openCameraCapture() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null) return;

    final bytes = await photo.readAsBytes();
    final item = LocalMediaAttachment(
      id: 'cam_${DateTime.now().millisecondsSinceEpoch}',
      mediaType: 'image',
      mimeType: 'image/jpeg',
      fileName: photo.name,
      sizeBytes: bytes.length,
      bytes: bytes,
      localPath: photo.path,
      sortOrder: 0,
    );

    if (!mounted) return;
    Navigator.of(context).pop();

    if (widget.onSendMultiMedia != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => MediaReviewModal(
            initialItems: [item],
            onSend: (items, caption) {
              widget.onSendMultiMedia!(items, caption);
            },
          ),
        ),
      );
    } else {
      widget.onSendPhotoBytes(bytes, photo.name);
    }
  }

  Future<void> _pickMultipleFiles() async {
    final files = await FilePicker.pickFiles();
    if (files.isEmpty) return;

    final items = <LocalMediaAttachment>[];
    for (int i = 0; i < files.length; i++) {
      final f = files[i];
      final mType = MediaUploadManager.guessMediaType(f.name);
      final mime = MediaUploadManager.guessMimeType(f.name);
      Uint8List? bytes;
      try {
        bytes = await f.readAsBytes();
      } catch (_) {}
      items.add(LocalMediaAttachment(
        id: 'file_${DateTime.now().millisecondsSinceEpoch}_$i',
        mediaType: mType,
        mimeType: mime,
        fileName: f.name,
        sizeBytes: bytes?.length ?? f.lengthSync() ?? 0,
        localPath: f.path,
        bytes: bytes,
        sortOrder: i,
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (widget.onSendMultiMedia != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => MediaReviewModal(
            initialItems: items,
            onSend: (reviewedItems, caption) {
              widget.onSendMultiMedia!(reviewedItems, caption);
            },
          ),
        ),
      );
    } else if (items.isNotEmpty) {
      widget.onPickFile();
    }
  }

  Future<void> _proceedWithSelectedAssets({bool openReview = true}) async {
    if (_selectedAssets.isEmpty) return;

    final localAttachments = <LocalMediaAttachment>[];
    for (int i = 0; i < _selectedAssets.length; i++) {
      final asset = _selectedAssets[i];
      File? file;
      Uint8List? bytes;
      try {
        file = await asset.file;
        if (file != null) {
          bytes = await file.readAsBytes();
        }
      } catch (_) {}

      if (bytes == null || bytes.isEmpty) {
        try {
          bytes = await asset.originBytes;
        } catch (_) {}
      }

      if (bytes == null || bytes.isEmpty) {
        try {
          bytes = await asset.thumbnailDataWithSize(const ThumbnailSize(2048, 2048));
        } catch (_) {}
      }
      final isVideo = asset.type == AssetType.video;
      String name = (asset.title != null && asset.title!.trim().isNotEmpty)
          ? asset.title!.trim()
          : (isVideo ? 'video_$i.mp4' : 'photo_$i.jpg');
      if (!name.contains('.')) {
        name += isVideo ? '.mp4' : '.jpg';
      }

      localAttachments.add(LocalMediaAttachment(
        id: 'asset_${asset.id}_$i',
        mediaType: isVideo ? 'video' : 'image',
        mimeType: isVideo ? 'video/mp4' : 'image/jpeg',
        fileName: name,
        sizeBytes: bytes?.length ?? 0,
        width: asset.width,
        height: asset.height,
        durationMs: isVideo ? asset.duration * 1000 : null,
        localPath: file?.path,
        bytes: bytes,
        sortOrder: i,
      ));
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (widget.onSendMultiMedia != null) {
      if (openReview) {
        Navigator.of(context).push(
          CupertinoPageRoute(
            builder: (_) => MediaReviewModal(
              initialItems: localAttachments,
              onSend: (items, caption) {
                widget.onSendMultiMedia!(items, caption);
              },
            ),
          ),
        );
      } else {
        widget.onSendMultiMedia!(localAttachments, '');
      }
    } else if (localAttachments.isNotEmpty && localAttachments.first.bytes != null) {
      widget.onSendPhotoBytes(
        localAttachments.first.bytes!,
        localAttachments.first.fileName,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final bgPreset = theme.bgPreset;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: bgPreset.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        child: Column(
          children: [
            // Top Body Area: Gallery or Location
            Expanded(
              child: _activeTab == 'Location'
                  ? LocationView(
                      currentUser: widget.currentUser,
                      onClose: () => Navigator.pop(context),
                      onSendLocation: (title, address) {
                        Navigator.pop(context);
                        widget.onSendLocation(title, address);
                      },
                    )
                  : _buildGalleryView(),
            ),

            // Bottom Navbar Dock matching Telegram attachment tabs, or Minimized Selection Bar
            if (_selectedAssets.isNotEmpty)
              _buildSelectedFloatingBar()
            else
              _buildBottomDock(),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryView() {
    final theme = ThemeController.instance;
    final bgPreset = theme.bgPreset;

    return Column(
      children: [
        // Drag handle pill
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: bgPreset.textMuted.withOpacity(0.35),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Header: Close (X), Recents dropdown
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Close button (X)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: bgPreset.inputFill,
                    shape: BoxShape.circle,
                    border: Border.all(color: bgPreset.border, width: 0.8),
                  ),
                  child: Icon(
                    Icons.close,
                    color: bgPreset.textPrimary,
                    size: 20,
                  ),
                ),
              ),

              // Recents dropdown
              GestureDetector(
                onTap: widget.onPickGallery,
                behavior: HitTestBehavior.opaque,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Recents',
                      style: GoogleFonts.inter(
                        color: bgPreset.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      CupertinoIcons.chevron_down,
                      color: bgPreset.textSecondary,
                      size: 13,
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 36),
            ],
          ),
        ),

        // Device Photos Grid
        Expanded(
          child: _isLoadingPhotos
              ? const Center(
                  child: CupertinoActivityIndicator(color: Colors.white),
                )
              : GridView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1.0,
                  ),
                  itemCount: _assets.isEmpty ? 2 : _assets.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: _openCameraCapture,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: Colors.black,
                          child: Center(
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white.withOpacity(0.85), width: 2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                CupertinoIcons.camera,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (_assets.isEmpty) {
                      return GestureDetector(
                        onTap: widget.onPickGallery,
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          color: const Color(0xFF1E1E24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(CupertinoIcons.photo_on_rectangle, color: Color(0xFF60A5FA), size: 30),
                              const SizedBox(height: 6),
                              Text(
                                'Choose Photo',
                                style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final asset = _assets[index - 1];
                    final selectedIndex = _selectedAssets.indexWhere((a) => a.id == asset.id);
                    final isSelected = selectedIndex >= 0;

                    return _GalleryThumbnailTile(
                      key: ValueKey(asset.id),
                      asset: asset,
                      isSelected: isSelected,
                      selectedIndex: selectedIndex,
                      onTap: () => _toggleAssetSelection(asset),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSelectedFloatingBar() {
    final theme = ThemeController.instance;
    final bgPreset = theme.bgPreset;
    final accent = theme.current;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.surfaceBg,
        border: Border(
          top: BorderSide(
            color: bgPreset.border,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left: Clear selection icon & counter badge (icon only)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() => _selectedAssets.clear());
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgPreset.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgPreset.border, width: 0.8),
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        color: bgPreset.textSecondary,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.primary.withOpacity(bgPreset.isDark ? 0.22 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.primary.withOpacity(0.4), width: 1.0),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          CupertinoIcons.photo_fill_on_rectangle_fill,
                          color: accent.primary,
                          size: 15,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedAssets.length}',
                          style: GoogleFonts.inter(
                            color: accent.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Right: Review / Caption icon button & Send icon button (icon only)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Review & Add Caption (icon only)
                  GestureDetector(
                    onTap: () => _proceedWithSelectedAssets(openReview: true),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: bgPreset.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgPreset.border, width: 0.8),
                      ),
                      child: Icon(
                        Icons.edit_note_rounded,
                        color: bgPreset.textPrimary,
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send (icon only)
                  GestureDetector(
                    onTap: () => _proceedWithSelectedAssets(openReview: false),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.primary.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomDock() {
    final theme = ThemeController.instance;
    final bgPreset = theme.bgPreset;

    return Container(
      decoration: BoxDecoration(
        color: bgPreset.surfaceBg,
        border: Border(
          top: BorderSide(
            color: bgPreset.border,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 1. Gallery
              _buildNavbarTab(
                icon: CupertinoIcons.photo_on_rectangle,
                label: 'Gallery',
                isSelected: _activeTab == 'Gallery',
                onTap: () {
                  setState(() => _activeTab = 'Gallery');
                },
              ),

              // 2. Gift
              _buildNavbarTab(
                icon: CupertinoIcons.gift_fill,
                label: 'Gift',
                isSelected: _activeTab == 'Gift',
                onTap: () {
                  setState(() => _activeTab = 'Gift');
                  Navigator.pop(context);
                  widget.onSendGift?.call();
                },
              ),

              // 3. File (Supports multiple file picking)
              _buildNavbarTab(
                icon: CupertinoIcons.doc_fill,
                label: 'File',
                isSelected: _activeTab == 'File',
                onTap: () {
                  setState(() => _activeTab = 'File');
                  _pickMultipleFiles();
                },
              ),

              // 4. Location (Active tab)
              _buildNavbarTab(
                icon: CupertinoIcons.location_solid,
                label: 'Location',
                isSelected: _activeTab == 'Location',
                onTap: () {
                  setState(() => _activeTab = 'Location');
                },
              ),

              // 5. Poll
              _buildNavbarTab(
                icon: CupertinoIcons.chart_bar_fill,
                label: 'Poll',
                isSelected: _activeTab == 'Poll',
                onTap: () {
                  setState(() => _activeTab = 'Poll');
                  Navigator.pop(context);
                  widget.onSendPoll?.call();
                },
              ),

              // 6. Checklist
              _buildNavbarTab(
                icon: CupertinoIcons.checkmark_square_fill,
                label: 'Checklist',
                isSelected: _activeTab == 'Checklist',
                onTap: () {
                  setState(() => _activeTab = 'Checklist');
                  Navigator.pop(context);
                  widget.onSendChecklist?.call();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavbarTab({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = ThemeController.instance;
    final accent = theme.current;
    final bgPreset = theme.bgPreset;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected
                    ? accent.primary.withOpacity(bgPreset.isDark ? 0.35 : 0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: isSelected ? accent.primary : bgPreset.textMuted,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected ? accent.primary : bgPreset.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryThumbnailTile extends StatefulWidget {
  final AssetEntity asset;
  final bool isSelected;
  final int selectedIndex;
  final VoidCallback onTap;

  const _GalleryThumbnailTile({
    super.key,
    required this.asset,
    required this.isSelected,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  State<_GalleryThumbnailTile> createState() => _GalleryThumbnailTileState();
}

class _GalleryThumbnailTileState extends State<_GalleryThumbnailTile>
    with AutomaticKeepAliveClientMixin {
  static final Map<String, Uint8List> _thumbCache = {};
  Uint8List? _bytes;
  bool _isLoading = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final cached = _thumbCache[widget.asset.id];
    if (cached != null) {
      _bytes = cached;
      _isLoading = false;
    } else {
      _loadThumb();
    }
  }

  @override
  void didUpdateWidget(covariant _GalleryThumbnailTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      final cached = _thumbCache[widget.asset.id];
      if (cached != null) {
        _bytes = cached;
        _isLoading = false;
      } else {
        _loadThumb();
      }
    }
  }

  Future<void> _loadThumb() async {
    final data = await widget.asset.thumbnailDataWithSize(const ThumbnailSize.square(250));
    if (data != null) {
      _thumbCache[widget.asset.id] = data;
    }
    if (mounted) {
      setState(() {
        _bytes = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = ThemeController.instance;
    final accent = theme.current;

    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Stable background & cached thumbnail (no layout jump, gapless playback)
          Container(
            color: const Color(0xFF1E1E24),
            child: _bytes != null
                ? Image.memory(
                    _bytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  )
                : (_isLoading
                    ? const Center(child: CupertinoActivityIndicator(radius: 8))
                    : const SizedBox.shrink()),
          ),

          // 2. Selection overlay (tint and border overlay so base image never shifts)
          if (widget.isSelected) ...[
            Container(
              color: Colors.black.withOpacity(0.18),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: accent.primary,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
          ],

          // 3. Selection Badge with smooth animation
          Positioned(
            top: 6,
            right: 6,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutQuad,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? accent.primary
                    : Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSelected ? Colors.white : Colors.white.withOpacity(0.85),
                  width: 1.8,
                ),
              ),
              child: Center(
                child: widget.isSelected
                    ? Text(
                        '${widget.selectedIndex + 1}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
            ),
          ),

          // 4. Video duration indicator
          if (widget.asset.type == AssetType.video)
            Positioned(
              bottom: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${widget.asset.duration ~/ 60}:${(widget.asset.duration % 60).toString().padLeft(2, '0')}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}


import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/theme_controller.dart';
import '../../chat/services/media_upload_manager.dart';

class MediaReviewModal extends StatefulWidget {
  final List<LocalMediaAttachment> initialItems;
  final VoidCallback? onAddMore;
  final Function(List<LocalMediaAttachment> items, String caption) onSend;

  const MediaReviewModal({
    super.key,
    required this.initialItems,
    this.onAddMore,
    required this.onSend,
  });

  @override
  State<MediaReviewModal> createState() => _MediaReviewModalState();
}

class _MediaReviewModalState extends State<MediaReviewModal> {
  late List<LocalMediaAttachment> _items;
  int _currentIndex = 0;
  final TextEditingController _captionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _items = List<LocalMediaAttachment>.from(widget.initialItems);
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex >= _items.length) {
        _currentIndex = _items.length - 1;
      }
    });
  }

  void _submit() {
    if (_items.isEmpty) return;
    Navigator.of(context).pop();
    widget.onSend(_items, _captionController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final accent = theme.current;
    final bgPreset = theme.bgPreset;

    if (_items.isEmpty) {
      return const SizedBox.shrink();
    }

    final activeItem = _items[_currentIndex];

    return Scaffold(
      backgroundColor: bgPreset.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar: Close button, Counter (e.g. 1 / 4), Trash button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: bgPreset.surfaceBg,
                border: Border(
                  bottom: BorderSide(color: bgPreset.border, width: 0.8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgPreset.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgPreset.border, width: 0.8),
                      ),
                      child: Icon(Icons.close_rounded, color: bgPreset.textPrimary, size: 20),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.primary.withOpacity(bgPreset.isDark ? 0.2 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: accent.primary.withOpacity(0.35), width: 1.0),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${_items.length}',
                      style: GoogleFonts.inter(
                        color: accent.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _removeItem(_currentIndex),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: bgPreset.inputFill,
                        shape: BoxShape.circle,
                        border: Border.all(color: bgPreset.border, width: 0.8),
                      ),
                      child: Icon(CupertinoIcons.trash, color: Colors.redAccent.shade200, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            // Middle: Active Item Preview
            Expanded(
              child: Center(
                child: activeItem.isImage
                    ? _buildImagePreview(activeItem)
                    : _buildFilePreview(activeItem),
              ),
            ),

            // Thumbnail strip if more than 1 item
            if (_items.length > 1) ...[
              Container(
                height: 64,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _items.length,
                  separatorBuilder: (ctx, index) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    final isSelected = index == _currentIndex;

                    return GestureDetector(
                      onTap: () => setState(() => _currentIndex = index),
                      child: Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? accent.primary : bgPreset.border,
                            width: isSelected ? 2.5 : 1.0,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (item.isImage && item.bytes != null)
                                Image.memory(item.bytes!, fit: BoxFit.cover)
                              else if (item.isImage && item.localPath != null)
                                Image.file(File(item.localPath!), fit: BoxFit.cover)
                              else
                                Container(
                                  color: bgPreset.inputFill,
                                  child: Icon(CupertinoIcons.doc_fill, color: bgPreset.textMuted, size: 24),
                                ),
                              Positioned(
                                top: 2,
                                left: 2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.65),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${index + 1}',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],

            // Bottom bar: Caption input field and Send Button (icon-only, theme-styled)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: bgPreset.surfaceBg,
                border: Border(
                  top: BorderSide(color: bgPreset.border, width: 0.8),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: bgPreset.inputFill,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: bgPreset.border, width: 0.8),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: GoogleFonts.inter(color: bgPreset.textPrimary, fontSize: 14.5),
                        cursorColor: accent.primary,
                        decoration: InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: GoogleFonts.inter(color: bgPreset.textMuted, fontSize: 14.5),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: _submit,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [accent.primary, accent.primary.withOpacity(0.85)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accent.primary.withOpacity(0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview(LocalMediaAttachment item) {
    if (item.bytes != null) {
      return InteractiveViewer(
        child: Image.memory(
          item.bytes!,
          fit: BoxFit.contain,
        ),
      );
    }
    if (item.localPath != null) {
      return InteractiveViewer(
        child: Image.file(
          File(item.localPath!),
          fit: BoxFit.contain,
        ),
      );
    }
    return const Icon(CupertinoIcons.photo, color: Colors.white54, size: 64);
  }

  Widget _buildFilePreview(LocalMediaAttachment item) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF202026),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withOpacity(0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(CupertinoIcons.doc_fill, color: Color(0xFF60A5FA), size: 38),
          ),
          const SizedBox(height: 16),
          Text(
            item.fileName,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          Text(
            _formatBytes(item.sizeBytes),
            style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
          ),
        ],
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

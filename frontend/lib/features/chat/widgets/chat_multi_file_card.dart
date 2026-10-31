import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/services/media_download_service.dart';
import '../../../core/theme/liquid_glass_theme.dart';
import '../../../core/theme/theme_controller.dart';

/// Renders a list of documents or files inside a single chat bubble
class ChatMultiFileCard extends StatelessWidget {
  final List<dynamic> attachments;
  final bool isMe;
  final bool isRead;
  final String? caption;
  final dynamic timestamp;
  final Function(String url, String filename) onOpenFile;
  final Function(int index)? onRetry;

  const ChatMultiFileCard({
    super.key,
    required this.attachments,
    required this.isMe,
    required this.isRead,
    this.caption,
    this.timestamp,
    required this.onOpenFile,
    this.onRetry,
  });

  static String formatBytes(dynamic size) {
    int bytes = (size as num?)?.toInt() ?? 0;
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static IconData getFileIcon(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return CupertinoIcons.doc_fill;
    if (lower.endsWith('.zip') || lower.endsWith('.rar') || lower.endsWith('.7z')) {
      return CupertinoIcons.archivebox_fill;
    }
    if (lower.endsWith('.mp3') || lower.endsWith('.wav') || lower.endsWith('.m4a')) {
      return CupertinoIcons.music_note_2;
    }
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return CupertinoIcons.film_fill;
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx') || lower.endsWith('.csv')) {
      return CupertinoIcons.table_fill;
    }
    return CupertinoIcons.doc_text_fill;
  }

  static Color getFileColor(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return const Color(0xFFEF4444);
    if (lower.endsWith('.zip') || lower.endsWith('.rar')) return const Color(0xFFF59E0B);
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return const Color(0xFF10B981);
    if (lower.endsWith('.mp4') || lower.endsWith('.mov')) return const Color(0xFF8B5CF6);
    return const Color(0xFF3B82F6);
  }

  static String formatTime(dynamic ts) {
    if (ts == null) return '';
    try {
      DateTime dt = ts is DateTime ? ts : DateTime.parse(ts.toString()).toLocal();
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final bubbleStyle = theme.bubbleStyle;
    final bubbleColor = isMe ? LiquidGlassTheme.accentBlue : LiquidGlassTheme.bgCard;
    final borderColor = isMe ? null : LiquidGlassTheme.borderSubtle;
    final hasCaption = caption != null && caption!.trim().isNotEmpty && caption != 'File';

    return ListenableBuilder(
      listenable: MediaDownloadService.instance,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.76,
          ),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: bubbleStyle.getBorderRadius(isMe),
            border: borderColor != null ? Border.all(color: borderColor, width: 0.8) : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // List of file attachments
              for (int i = 0; i < attachments.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _buildFileItem(context, i),
              ],

              if (hasCaption) ...[
                const SizedBox(height: 8),
                Text(
                  caption!,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
                    height: 1.3,
                  ),
                ),
              ],

              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    formatTime(timestamp),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                    ),
                  ),
                  if (isMe) ...[
                    const SizedBox(width: 3),
                    Icon(
                      isRead ? Icons.done_all : Icons.done,
                      size: 13,
                      color: isRead ? const Color(0xFF67E8F9) : Colors.white.withOpacity(0.80),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFileItem(BuildContext context, int index) {
    final raw = attachments[index];
    final map = raw is Map<String, dynamic>
        ? raw
        : (raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{});

    final fileName = (map['file_name'] ?? 'Document').toString();
    final url = (map['url'] ?? map['media_url'] ?? '').toString();
    final sizeBytes = map['size_bytes'];
    final uploadStatus = map['upload_status'] ?? 'completed';
    final progress = (map['progress'] as num?)?.toDouble() ?? 1.0;
    final isUploading = uploadStatus == 'uploading' || uploadStatus == 'pending';
    final isFailed = uploadStatus == 'failed';
    final iconColor = getFileColor(fileName);

    final downloadService = MediaDownloadService.instance;
    final downloadState = downloadService.getState(url, filename: fileName);
    final isDownloading = downloadState.status == DownloadStatus.downloading;
    final isDownloaded = downloadService.isDownloaded(url, filename: fileName);

    return GestureDetector(
      onTap: () {
        if (isUploading) return;
        if (isFailed) {
          onRetry?.call(index);
        } else if (url.isNotEmpty) {
          if (isDownloading) return;
          // Open media (will download first if not yet cached)
          downloadService.openMedia(context, url: url, filename: fileName);
        }
      },
      onLongPress: () {
        if (!isUploading && !isFailed && url.isNotEmpty) {
          downloadService.showMediaOptionsSheet(
            context,
            url: url,
            filename: fileName,
            sizeBytes: (sizeBytes as num?)?.toInt(),
          );
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? Colors.white.withOpacity(0.16) : LiquidGlassTheme.inputFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMe ? Colors.white.withOpacity(0.2) : LiquidGlassTheme.borderSubtle,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // Icon or Spinner
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isMe ? Colors.white.withOpacity(0.2) : iconColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: isUploading
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          value: progress > 0.05 ? progress : null,
                          strokeWidth: 2,
                          color: isMe ? Colors.white : iconColor,
                        ),
                      )
                    : isFailed
                        ? const Icon(Icons.refresh, color: Colors.redAccent, size: 20)
                        : Icon(
                            getFileIcon(fileName),
                            color: isMe ? Colors.white : iconColor,
                            size: 20,
                          ),
              ),
            ),
            const SizedBox(width: 10),

            // Name and Size / Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isMe ? Colors.white : LiquidGlassTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isFailed
                        ? 'Failed • Tap to retry'
                        : isUploading
                            ? 'Uploading ${(progress * 100).toInt()}%'
                            : isDownloading
                                ? 'Downloading ${(downloadState.progress * 100).toInt()}%'
                                : isDownloaded
                                    ? 'Downloaded • ${formatBytes(sizeBytes)}'
                                    : formatBytes(sizeBytes),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: isFailed
                          ? Colors.redAccent
                          : isDownloading
                              ? (isMe ? Colors.white : LiquidGlassTheme.accentBlue)
                              : isDownloaded
                                  ? (isMe ? const Color(0xFF67E8F9) : LiquidGlassTheme.accentEmerald)
                                  : isMe
                                      ? Colors.white.withOpacity(0.75)
                                      : LiquidGlassTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),

            // Action / Download / Open indicator
            if (!isUploading && !isFailed) ...[
              if (isDownloading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    value: downloadState.progress > 0.05 ? downloadState.progress : null,
                    strokeWidth: 2,
                    color: isMe ? Colors.white : LiquidGlassTheme.accentBlue,
                  ),
                )
              else if (isDownloaded)
                GestureDetector(
                  onTap: () {
                    downloadService.saveAs(context, url: url, filename: fileName);
                  },
                  child: Tooltip(
                    message: 'Save As',
                    child: Icon(
                      CupertinoIcons.arrow_down_doc,
                      size: 16,
                      color: isMe ? const Color(0xFF67E8F9) : LiquidGlassTheme.accentEmerald,
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: () {
                    downloadService.saveAs(context, url: url, filename: fileName);
                  },
                  child: Tooltip(
                    message: 'Save As',
                    child: Icon(
                      CupertinoIcons.arrow_down_to_line,
                      size: 15,
                      color: isMe ? Colors.white.withOpacity(0.85) : LiquidGlassTheme.textMuted,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

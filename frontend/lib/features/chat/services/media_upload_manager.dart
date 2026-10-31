import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../../core/api/api_client.dart';
import '../../../models/chat_message.dart';

/// Represents a local media attachment queued or in-flight for upload
class LocalMediaAttachment {
  final String id;
  final String mediaType; // image, video, audio, voice, document
  final String mimeType;
  final String fileName;
  final int sizeBytes;
  final int? width;
  final int? height;
  final int? durationMs;
  final String? localPath;
  final Uint8List? bytes;
  String? remoteUrl;
  String? storageKey;
  double progress;
  String uploadStatus; // pending, uploading, completed, failed
  String? errorMessage;
  int sortOrder;

  LocalMediaAttachment({
    required this.id,
    required this.mediaType,
    required this.mimeType,
    required this.fileName,
    required this.sizeBytes,
    this.width,
    this.height,
    this.durationMs,
    this.localPath,
    this.bytes,
    this.remoteUrl,
    this.storageKey,
    this.progress = 0.0,
    this.uploadStatus = 'pending',
    this.errorMessage,
    required this.sortOrder,
  });

  bool get isCompleted => uploadStatus == 'completed';
  bool get isFailed => uploadStatus == 'failed';
  bool get isUploading => uploadStatus == 'uploading';
  bool get isImage => mediaType == 'image' || mediaType == 'photo';
  bool get isVideo => mediaType == 'video';
  bool get isVoice => mediaType == 'voice' || mediaType == 'audio';
  bool get isDocument => mediaType == 'document' || mediaType == 'file';

  MessageAttachment toMessageAttachment() {
    return MessageAttachment(
      mediaType: mediaType,
      mimeType: mimeType,
      fileName: fileName,
      sizeBytes: sizeBytes,
      width: width,
      height: height,
      durationMs: durationMs,
      storageKey: storageKey,
      url: remoteUrl ?? '',
      uploadStatus: uploadStatus,
      sortOrder: sortOrder,
      progress: progress,
      localPath: localPath,
      localBytes: bytes,
    );
  }

  Map<String, dynamic> toServerPayload() {
    return {
      'media_type': mediaType,
      'mime_type': mimeType,
      'file_name': fileName,
      'size_bytes': sizeBytes,
      if (width != null) 'width': width,
      if (height != null) 'height': height,
      if (durationMs != null) 'duration_ms': durationMs,
      if (storageKey != null) 'storage_key': storageKey,
      'url': remoteUrl ?? '',
      'upload_status': 'completed',
      'sort_order': sortOrder,
    };
  }
}

/// Bounded concurrency uploader to upload multiple attachments in parallel
class MediaUploadManager {
  MediaUploadManager._();
  static final MediaUploadManager instance = MediaUploadManager._();

  /// Default bounded concurrency (e.g. 2 or 3 parallel uploads)
  static const int defaultConcurrency = 3;

  /// Upload a list of attachments with bounded concurrency and progress callbacks
  Future<List<LocalMediaAttachment>> uploadAttachments({
    required List<LocalMediaAttachment> attachments,
    int maxConcurrency = defaultConcurrency,
    void Function(LocalMediaAttachment item, double overallProgress)? onProgress,
    void Function(LocalMediaAttachment item)? onItemComplete,
    void Function(LocalMediaAttachment item, Object error)? onItemFailed,
  }) async {
    final pendingItems = attachments.where((a) => !a.isCompleted).toList();
    if (pendingItems.isEmpty) return attachments;

    final totalCount = attachments.length;

    double computeOverall() {
      if (totalCount == 0) return 1.0;
      double sum = 0.0;
      for (final a in attachments) {
        sum += a.progress;
      }
      return (sum / totalCount).clamp(0.0, 1.0);
    }

    final queue = List<LocalMediaAttachment>.from(pendingItems);
    final activeFutures = <Future<void>>{};

    Future<void> runTask(LocalMediaAttachment item) async {
      item.uploadStatus = 'uploading';
      item.progress = 0.01;
      onProgress?.call(item, computeOverall());

      try {
        // Stream directly from filePath or bytes with live byte progress
        final url = await ApiClient.instance.uploadChatMedia(
          bytes: item.bytes,
          filePath: item.localPath,
          filename: item.fileName,
          onProgress: (sent, total) {
            if (total > 0) {
              final ratio = (sent / total).clamp(0.01, 0.99);
              item.progress = ratio;
              onProgress?.call(item, computeOverall());
            }
          },
        );

        item.remoteUrl = url;
        item.uploadStatus = 'completed';
        item.progress = 1.0;

        onItemComplete?.call(item);
        onProgress?.call(item, computeOverall());
      } catch (err) {
        item.uploadStatus = 'failed';
        item.errorMessage = err.toString();
        onItemFailed?.call(item, err);
        onProgress?.call(item, computeOverall());
      }
    }

    while (queue.isNotEmpty || activeFutures.isNotEmpty) {
      while (activeFutures.length < maxConcurrency && queue.isNotEmpty) {
        final item = queue.removeAt(0);
        late final Future<void> future;
        future = runTask(item).whenComplete(() {
          activeFutures.remove(future);
        });
        activeFutures.add(future);
      }
      if (activeFutures.isNotEmpty) {
        await Future.any(activeFutures);
      }
    }

    return attachments;
  }

  /// Helper to guess media type from filename
  static String guessMediaType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic')) {
      return 'image';
    }
    if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm')) {
      return 'video';
    }
    if (lower.endsWith('.mp3') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg')) {
      return 'audio';
    }
    return 'document';
  }

  /// Helper to guess mime type from filename
  static String guessMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc') || lower.endsWith('.docx')) return 'application/msword';
    if (lower.endsWith('.xls') || lower.endsWith('.xlsx')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/m4a';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return 'application/octet-stream';
  }
}

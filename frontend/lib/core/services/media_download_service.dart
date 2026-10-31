import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/api_client.dart';
import '../theme/liquid_glass_theme.dart';
import '../../widgets/top_capsule_hud.dart';

enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
}

class MediaDownloadState {
  final DownloadStatus status;
  final double progress; // 0.0 to 1.0
  final int receivedBytes;
  final int totalBytes;
  final String? localPath;
  final String? error;

  const MediaDownloadState({
    this.status = DownloadStatus.idle,
    this.progress = 0.0,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.localPath,
    this.error,
  });

  MediaDownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    int? receivedBytes,
    int? totalBytes,
    String? localPath,
    String? error,
  }) {
    return MediaDownloadState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      localPath: localPath ?? this.localPath,
      error: error ?? this.error,
    );
  }
}

class MediaDownloadService extends ChangeNotifier {
  static final MediaDownloadService instance = MediaDownloadService._internal();
  static Widget Function(String url, String filename)? imageViewerBuilder;
  MediaDownloadService._internal() {
    loadPreferences();
  }

  static const String _kWifiKey = 'privacy_media_wifi';
  static const String _kCellularKey = 'privacy_media_cellular';

  bool _autoDownloadWifi = true;
  bool _autoDownloadCellular = false;

  bool get autoDownloadWifi => _autoDownloadWifi;
  bool get autoDownloadCellular => _autoDownloadCellular;

  final ValueNotifier<bool> autoDownloadWifiNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> autoDownloadCellularNotifier = ValueNotifier<bool>(false);

  final Map<String, String> _knownDownloadedPaths = {};

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _autoDownloadWifi = prefs.getBool(_kWifiKey) ?? true;
      _autoDownloadCellular = prefs.getBool(_kCellularKey) ?? false;
      autoDownloadWifiNotifier.value = _autoDownloadWifi;
      autoDownloadCellularNotifier.value = _autoDownloadCellular;
      notifyListeners();

      if (!kIsWeb) {
        await getMediaDirectory();
        if (_mediaDirectoryPath != null) {
          final dir = Directory(_mediaDirectoryPath!);
          if (await dir.exists()) {
            await for (final entity in dir.list(followLinks: false)) {
              if (entity is File && await entity.length() > 0) {
                final name = entity.uri.pathSegments.last;
                _knownDownloadedPaths[name] = entity.path;
              }
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> setAutoDownloadWifi(bool val) async {
    _autoDownloadWifi = val;
    autoDownloadWifiNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kWifiKey, val);
    } catch (_) {}
  }

  Future<void> setAutoDownloadCellular(bool val) async {
    _autoDownloadCellular = val;
    autoDownloadCellularNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kCellularKey, val);
    } catch (_) {}
  }

  final Map<String, MediaDownloadState> _tasks = {};
  final http.Client _client = http.Client();

  MediaDownloadState getState(String url, {String? filename}) {
    if (_tasks.containsKey(url)) {
      final state = _tasks[url]!;
      if (kIsWeb) return state;
      if (state.status == DownloadStatus.completed && state.localPath != null) {
        if (File(state.localPath!).existsSync()) {
          return state;
        }
      } else {
        return state;
      }
    }
    if (kIsWeb) return const MediaDownloadState();
    // Check if file already exists locally
    final path = getLocalPathSync(url, filename ?? '');
    if (path != null) {
      final file = File(path);
      if (file.existsSync() && file.lengthSync() > 0) {
        final state = MediaDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
          localPath: path,
          receivedBytes: file.lengthSync(),
          totalBytes: file.lengthSync(),
        );
        _tasks[url] = state;
        return state;
      }
    }

    return const MediaDownloadState();
  }

  bool isDownloading(String url) {
    return _tasks[url]?.status == DownloadStatus.downloading;
  }

  bool isDownloaded(String url, {String? filename}) {
    if (kIsWeb) {
      return _tasks[url]?.status == DownloadStatus.completed;
    }
    final state = getState(url, filename: filename);
    return state.status == DownloadStatus.completed &&
        state.localPath != null &&
        File(state.localPath!).existsSync();
  }

  double getProgress(String url) {
    return _tasks[url]?.progress ?? 0.0;
  }

  String? getLocalPathSync(String url, String filename) {
    if (kIsWeb) return null;
    final resolvedUrl = ApiClient.resolveAvatarUrl(url);
    final cleanName = _sanitizeFilename(resolvedUrl, filename);
    if (_knownDownloadedPaths.containsKey(cleanName)) {
      final p = _knownDownloadedPaths[cleanName]!;
      if (File(p).existsSync()) return p;
    }
    if (_mediaDirectoryPath != null) {
      final path = '$_mediaDirectoryPath/$cleanName';
      if (File(path).existsSync()) return path;
      return null;
    }
    return null;
  }

  String? _mediaDirectoryPath;

  Future<String> getMediaDirectory() async {
    if (kIsWeb) return '';
    if (_mediaDirectoryPath != null) return _mediaDirectoryPath!;
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final mediaDir = Directory('${docDir.path}/ChatGo/Media');
      if (!await mediaDir.exists()) {
        await mediaDir.create(recursive: true);
      }
      _mediaDirectoryPath = mediaDir.path;
      return _mediaDirectoryPath!;
    } catch (_) {
      return '';
    }
  }

  String _sanitizeFilename(String url, String filename) {
    String name = filename.trim();
    if (name.isEmpty) {
      try {
        final uri = Uri.parse(url);
        name = uri.pathSegments.isNotEmpty ? uri.pathSegments.last : 'download';
      } catch (_) {
        name = 'download_${DateTime.now().millisecondsSinceEpoch}';
      }
    }
    // Remove query parameters from name if any
    if (name.contains('?')) {
      name = name.split('?').first;
    }
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  /// Downloads the file from [url] and saves it locally.
  /// If already downloaded locally, NEVER downloads again!
  Future<File?> downloadMedia({
    required String url,
    required String filename,
    void Function(double progress)? onProgress,
  }) async {
    if (url.trim().isEmpty) return null;

    final resolvedUrl = ApiClient.resolveAvatarUrl(url);

    if (kIsWeb) {
      _tasks[url] = const MediaDownloadState(
        status: DownloadStatus.downloading,
        progress: 0.2,
      );
      notifyListeners();
      try {
        final res = await http.get(Uri.parse(resolvedUrl));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          _tasks[url] = MediaDownloadState(
            status: DownloadStatus.completed,
            progress: 1.0,
            receivedBytes: res.bodyBytes.length,
            totalBytes: res.bodyBytes.length,
          );
          notifyListeners();
        } else {
          _tasks[url] = const MediaDownloadState(status: DownloadStatus.failed);
          notifyListeners();
        }
      } catch (_) {
        _tasks[url] = const MediaDownloadState(status: DownloadStatus.failed);
        notifyListeners();
      }
      return null;
    }

    final mediaDir = await getMediaDirectory();
    final cleanName = _sanitizeFilename(resolvedUrl, filename);
    final localPath = '$mediaDir/$cleanName';
    final targetFile = File(localPath);

    // CRITICAL: If already downloaded and valid, return immediately without network download!
    if (await targetFile.exists() && await targetFile.length() > 0) {
      _tasks[url] = MediaDownloadState(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: localPath,
        receivedBytes: await targetFile.length(),
        totalBytes: await targetFile.length(),
      );
      _knownDownloadedPaths[cleanName] = localPath;
      notifyListeners();
      return targetFile;
    }

    // Set initial downloading state
    _tasks[url] = MediaDownloadState(
      status: DownloadStatus.downloading,
      progress: 0.0,
      localPath: localPath,
    );
    notifyListeners();

    final tempFile = File('$localPath.download');
    try {
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      final request = http.Request('GET', Uri.parse(resolvedUrl));
      final response = await _client.send(request);

      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Server responded with HTTP ${response.statusCode}');
      }

      final totalBytes = response.contentLength ?? 0;
      int receivedBytes = 0;

      final sink = tempFile.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;

        double currentProgress = 0.0;
        if (totalBytes > 0) {
          currentProgress = (receivedBytes / totalBytes).clamp(0.0, 1.0);
        } else {
          currentProgress = 0.5; // indeterminate fallback
        }

        _tasks[url] = MediaDownloadState(
          status: DownloadStatus.downloading,
          progress: currentProgress,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          localPath: localPath,
        );
        onProgress?.call(currentProgress);
        notifyListeners();
      }

      await sink.flush();
      await sink.close();

      // Atomically move temp file to destination
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      await tempFile.rename(localPath);

      _tasks[url] = MediaDownloadState(
        status: DownloadStatus.completed,
        progress: 1.0,
        receivedBytes: receivedBytes,
        totalBytes: receivedBytes,
        localPath: localPath,
      );
      notifyListeners();
      return targetFile;
    } catch (e) {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }

      _tasks[url] = MediaDownloadState(
        status: DownloadStatus.failed,
        progress: 0.0,
        error: e.toString(),
      );
      notifyListeners();
      return null;
    }
  }

  /// Opens the downloaded media with the appropriate app or external viewer.
  Future<void> openMedia(
    BuildContext context, {
    required String url,
    required String filename,
  }) async {
    final lower = filename.toLowerCase();
    final isImg = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');

    // For images, immediately open in-app viewer if available
    if (isImg && context.mounted && imageViewerBuilder != null) {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => imageViewerBuilder!(url, filename),
        ),
      );
      return;
    }

    if (kIsWeb) {
      await saveAs(context, url: url, filename: filename);
      return;
    }

    File? file;
    final state = getState(url, filename: filename);

    if (state.status == DownloadStatus.completed &&
        state.localPath != null &&
        File(state.localPath!).existsSync()) {
      file = File(state.localPath!);
    } else {
      file = await downloadMedia(url: url, filename: filename);
    }

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        _showToast(context, 'Failed to download $filename', isError: true);
      }
      return;
    }

    try {
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        // Fallback to sharing the file if no direct handler found
        await Share.shareXFiles([XFile(file.path)], text: filename);
      }
    } catch (e) {
      if (e is MissingPluginException || e.toString().contains('MissingPluginException')) {
        if (context.mounted) {
          _showRestartNoticeDialog(context, file: file, filename: filename, url: url);
        }
      } else {
        try {
          await Share.shareXFiles([XFile(file.path)], text: filename);
        } catch (e2) {
          if (context.mounted) {
            _showToast(context, 'Could not open file: $e2', isError: true);
          }
        }
      }
    }
  }

  void _showRestartNoticeDialog(
    BuildContext context, {
    required File file,
    required String filename,
    required String url,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: LiquidGlassTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: LiquidGlassTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentEmerald.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      CupertinoIcons.checkmark_circle_fill,
                      color: LiquidGlassTheme.accentEmerald,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$filename Downloaded',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: LiquidGlassTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Saved locally to device',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: LiquidGlassTheme.accentEmerald,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.inputFill,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'App Rebuild Needed for Native Viewer',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: LiquidGlassTheme.accentBlue,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'To launch files directly in external viewers or the iOS Share Sheet, restart `flutter run` in your terminal so CocoaPods native plugins can link into the running app.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: LiquidGlassTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(CupertinoIcons.link, size: 16),
                      label: const Text('Copy Link'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LiquidGlassTheme.textPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: LiquidGlassTheme.borderSubtle),
                      ),
                      onPressed: () {
                        final resolved = ApiClient.resolveAvatarUrl(url);
                        Clipboard.setData(ClipboardData(text: resolved));
                        Navigator.of(ctx).pop();
                        _showToast(context, 'File link copied to clipboard');
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(CupertinoIcons.doc_on_clipboard, size: 16),
                      label: const Text('Copy Path'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: LiquidGlassTheme.accentBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: file.path));
                        Navigator.of(ctx).pop();
                        _showToast(context, 'Local path copied to clipboard');
                      },
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

  /// Opens a native Save As dialog allowing the user to select the destination
  /// location and filename.
  /// If the file is already downloaded locally, it NEVER downloads again!
  Future<bool> saveAs(
    BuildContext context, {
    required String url,
    required String filename,
  }) async {
    final resolvedUrl = ApiClient.resolveAvatarUrl(url);
    final cleanName = _sanitizeFilename(resolvedUrl, filename);
    String saveName = filename.isNotEmpty ? filename : cleanName;
    if (!saveName.contains('.')) {
      saveName = '$saveName${_guessExtension(resolvedUrl, cleanName)}';
    }

    if (kIsWeb) {
      try {
        if (context.mounted) {
          _showToast(context, 'Downloading $saveName...');
        }
        final res = await http.get(Uri.parse(resolvedUrl));
        if (res.statusCode >= 200 && res.statusCode < 300) {
          final bytes = res.bodyBytes;
          final mime = _lookupMimeType(saveName);
          await FilePicker.saveFile(
            dialogTitle: 'Save As',
            fileName: saveName,
            bytes: bytes,
            mimeType: mime,
          );
          _tasks[url] = MediaDownloadState(
            status: DownloadStatus.completed,
            progress: 1.0,
            receivedBytes: bytes.length,
            totalBytes: bytes.length,
          );
          notifyListeners();
          if (context.mounted) {
            _showToast(context, 'Saved as $saveName');
          }
          return true;
        } else {
          if (context.mounted) {
            _showToast(context, 'Failed to download file (${res.statusCode})', isError: true);
          }
          return false;
        }
      } catch (e) {
        if (context.mounted) {
          _showToast(context, 'Save error: $e', isError: true);
        }
        return false;
      }
    }

    File? file;
    final mediaDir = await getMediaDirectory();
    final localPath = '$mediaDir/$cleanName';
    final targetFile = File(localPath);

    // 1. Check local file on disk - DO NOT download again if already downloaded!
    if (await targetFile.exists() && await targetFile.length() > 0) {
      file = targetFile;
      _tasks[url] = MediaDownloadState(
        status: DownloadStatus.completed,
        progress: 1.0,
        localPath: localPath,
        receivedBytes: await targetFile.length(),
        totalBytes: await targetFile.length(),
      );
      _knownDownloadedPaths[cleanName] = localPath;
      notifyListeners();
    } else if (_knownDownloadedPaths.containsKey(cleanName)) {
      final known = File(_knownDownloadedPaths[cleanName]!);
      if (await known.exists() && await known.length() > 0) {
        file = known;
        _tasks[url] = MediaDownloadState(
          status: DownloadStatus.completed,
          progress: 1.0,
          localPath: known.path,
          receivedBytes: await known.length(),
          totalBytes: await known.length(),
        );
        notifyListeners();
      }
    }

    if (file == null) {
      // 2. Only download if not yet cached locally
      if (context.mounted) {
        _showToast(context, 'Downloading $filename...');
      }
      file = await downloadMedia(url: url, filename: filename);
    }

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        _showToast(context, 'Failed to download file', isError: true);
      }
      return false;
    }

    try {
      final bytes = await file.readAsBytes();
      final mime = _lookupMimeType(cleanName);
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Save As',
        fileName: filename.isNotEmpty ? filename : cleanName,
        bytes: bytes,
        mimeType: mime,
      );

      if (uri != null) {
        if (context.mounted) {
          _showToast(context, 'Saved as ${filename.isNotEmpty ? filename : cleanName}');
        }
        return true;
      }
      return false;
    } catch (e) {
      // Fallback if FilePicker.saveFile encounters issues or is cancelled
      try {
        await Share.shareXFiles([XFile(file.path)], text: filename);
        return true;
      } catch (_) {
        if (context.mounted) {
          _showToast(context, 'File saved in app storage: ${file.path}');
        }
        return true;
      }
    }
  }

  String _lookupMimeType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.gif')) return 'image/gif';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.m4a')) return 'audio/m4a';
    if (lower.endsWith('.txt')) return 'text/plain';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.zip')) return 'application/zip';
    if (lower.endsWith('.xlsx')) return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    if (lower.endsWith('.xls')) return 'application/vnd.ms-excel';
    if (lower.endsWith('.docx')) return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.pptx')) return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    if (lower.endsWith('.ppt')) return 'application/vnd.ms-powerpoint';
    if (lower.endsWith('.csv')) return 'text/csv';
    return 'application/octet-stream';
  }

  String _guessExtension(String url, String filename) {
    if (filename.contains('.')) return '.${filename.split('.').last}';
    final lower = url.toLowerCase();
    if (lower.contains('.png')) return '.png';
    if (lower.contains('.jpg') || lower.contains('.jpeg')) return '.jpg';
    if (lower.contains('.gif')) return '.gif';
    if (lower.contains('.webp')) return '.webp';
    if (lower.contains('.pdf')) return '.pdf';
    if (lower.contains('.mp4')) return '.mp4';
    if (lower.contains('.mov')) return '.mov';
    if (lower.contains('.mp3')) return '.mp3';
    if (lower.contains('.m4a')) return '.m4a';
    if (lower.contains('.xlsx')) return '.xlsx';
    if (lower.contains('.docx')) return '.docx';
    if (lower.contains('.zip')) return '.zip';
    return '.bin';
  }

  /// Saves the image or video to the device Photo Library / Camera Roll.
  Future<bool> saveToGallery(
    BuildContext context, {
    required String url,
    required String filename,
  }) async {
    if (kIsWeb) {
      return saveAs(context, url: url, filename: filename);
    }
    File? file;
    final state = getState(url, filename: filename);
    if (state.status == DownloadStatus.completed &&
        state.localPath != null &&
        File(state.localPath!).existsSync()) {
      file = File(state.localPath!);
    } else {
      _showToast(context, 'Downloading for photo library...');
      file = await downloadMedia(url: url, filename: filename);
    }

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        _showToast(context, 'Failed to download file', isError: true);
      }
      return false;
    }

    try {
      final perm = await PhotoManager.requestPermissionExtend();
      if (!perm.isAuth) {
        if (context.mounted) {
          _showToast(context, 'Photo library permission denied', isError: true);
        }
        return false;
      }

      final lower = filename.toLowerCase();
      final isVideo = lower.endsWith('.mp4') ||
          lower.endsWith('.mov') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mkv');

      if (isVideo) {
        await PhotoManager.editor.saveVideo(file, title: filename);
        if (context.mounted) {
          _showToast(context, 'Video saved to Photos');
        }
        return true;
      } else {
        final bytes = await file.readAsBytes();
        await PhotoManager.editor.saveImage(bytes, filename: filename);
        if (context.mounted) {
          _showToast(context, 'Image saved to Photos');
        }
        return true;
      }
    } catch (e) {
      if (context.mounted) {
        _showToast(context, 'Error saving to Photos: $e', isError: true);
      }
      return false;
    }
  }

  /// Shares the media using the platform share sheet.
  Future<void> shareMedia(
    BuildContext context, {
    required String url,
    required String filename,
  }) async {
    final resolvedUrl = ApiClient.resolveAvatarUrl(url);
    if (kIsWeb) {
      Clipboard.setData(ClipboardData(text: resolvedUrl));
      if (context.mounted) {
        _showToast(context, 'File link copied to clipboard');
      }
      return;
    }

    File? file;
    final state = getState(url, filename: filename);
    if (state.status == DownloadStatus.completed &&
        state.localPath != null &&
        File(state.localPath!).existsSync()) {
      file = File(state.localPath!);
    } else {
      _showToast(context, 'Preparing file to share...');
      file = await downloadMedia(url: url, filename: filename);
    }

    if (file == null || !await file.exists()) {
      if (context.mounted) {
        _showToast(context, 'Failed to download file for sharing', isError: true);
      }
      return;
    }

    try {
      await Share.shareXFiles([XFile(file.path)], text: filename);
    } catch (e) {
      if (e is MissingPluginException || e.toString().contains('MissingPluginException')) {
        if (context.mounted) {
          _showRestartNoticeDialog(context, file: file, filename: filename, url: url);
        }
      } else {
        if (context.mounted) {
          _showToast(context, 'Failed to share: $e', isError: true);
        }
      }
    }
  }

  /// Shows a rich bottom sheet with actions: Open, Share, Save to Photos, Copy Link, Delete.
  void showMediaOptionsSheet(
    BuildContext context, {
    required String url,
    required String filename,
    int? sizeBytes,
  }) {
    final state = getState(url, filename: filename);
    final downloaded = state.status == DownloadStatus.completed &&
        state.localPath != null &&
        File(state.localPath!).existsSync();

    final lower = filename.toLowerCase();
    final isMedia = lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: LiquidGlassTheme.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          border: Border.all(color: LiquidGlassTheme.borderSubtle, width: 0.8),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: LiquidGlassTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // Title and size
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: LiquidGlassTheme.accentBlue.withOpacity(0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      isMedia ? CupertinoIcons.film : CupertinoIcons.doc_fill,
                      color: LiquidGlassTheme.accentBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          filename,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: LiquidGlassTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          downloaded
                              ? 'Downloaded on this device'
                              : (sizeBytes != null && sizeBytes > 0
                                  ? _formatBytes(sizeBytes)
                                  : 'Tap to download'),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: downloaded
                                ? LiquidGlassTheme.accentEmerald
                                : LiquidGlassTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(height: 1, color: LiquidGlassTheme.dividerHairline),
              const SizedBox(height: 8),

              // Actions
              if (downloaded) ...[
                _buildActionTile(
                  icon: CupertinoIcons.arrow_up_right_square,
                  title: 'Open with App',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    openMedia(context, url: url, filename: filename);
                  },
                ),
              ] else ...[
                _buildActionTile(
                  icon: CupertinoIcons.arrow_down_to_line,
                  title: 'Download File',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    downloadMedia(url: url, filename: filename);
                  },
                ),
              ],

              if (isMedia)
                _buildActionTile(
                  icon: CupertinoIcons.photo,
                  title: 'Save to Photos',
                  onTap: () {
                    Navigator.of(ctx).pop();
                    saveToGallery(context, url: url, filename: filename);
                  },
                ),

              _buildActionTile(
                icon: CupertinoIcons.folder_badge_plus,
                title: 'Save As...',
                onTap: () {
                  Navigator.of(ctx).pop();
                  saveAs(context, url: url, filename: filename);
                },
              ),

              _buildActionTile(
                icon: CupertinoIcons.share,
                title: 'Share File',
                onTap: () {
                  Navigator.of(ctx).pop();
                  shareMedia(context, url: url, filename: filename);
                },
              ),

              _buildActionTile(
                icon: CupertinoIcons.link,
                title: 'Copy Link',
                onTap: () {
                  Navigator.of(ctx).pop();
                  final resolved = ApiClient.resolveAvatarUrl(url);
                  Clipboard.setData(ClipboardData(text: resolved));
                  _showToast(context, 'Link copied to clipboard');
                },
              ),

              if (downloaded)
                _buildActionTile(
                  icon: CupertinoIcons.trash,
                  title: 'Delete Downloaded File',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    await deleteDownloadedFile(url, filename);
                    if (context.mounted) {
                      _showToast(context, 'Removed local file');
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? const Color(0xFFEF4444) : LiquidGlassTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 14),
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> deleteDownloadedFile(String url, String filename) async {
    if (kIsWeb) {
      _tasks.remove(url);
      notifyListeners();
      return;
    }
    final path = getLocalPathSync(url, filename);
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        try {
          await f.delete();
        } catch (_) {}
      }
    }
    _tasks.remove(url);
    notifyListeners();
  }

  void _showToast(BuildContext context, String message, {bool isError = false}) {
    TopCapsuleHud.show(
      context,
      message: message,
      isError: isError,
    );
  }

  Future<int> getCachedMediaSizeBytes() async {
    if (kIsWeb) return 0;
    try {
      final dirPath = await getMediaDirectory();
      final dir = Directory(dirPath);
      if (!await dir.exists()) return 0;

      int total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          total += await entity.length();
        }
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  Future<void> clearMediaCache() async {
    if (kIsWeb) {
      _tasks.clear();
      notifyListeners();
      return;
    }
    try {
      final dirPath = await getMediaDirectory();
      final dir = Directory(dirPath);
      if (await dir.exists()) {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (entity is File) {
            try {
              await entity.delete();
            } catch (_) {}
          }
        }
      }
      _tasks.clear();
      notifyListeners();
    } catch (_) {}
  }

  String formatBytes(dynamic size) {
    int bytes = (size as num?)?.toInt() ?? 0;
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatBytes(dynamic size) => formatBytes(size);
}

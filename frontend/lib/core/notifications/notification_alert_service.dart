import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/user_model.dart';
import '../api/api_client.dart';
import '../storage/local_chat_storage.dart';
import '../websocket/chat_socket_service.dart';
import 'platform_notification.dart';

class InAppNotificationData {
  final int senderId;
  final String username;
  final String displayName;
  final String avatarUrl;
  final String content;
  final String mediaType;
  final DateTime timestamp;
  final Map<String, dynamic> rawEvent;

  InAppNotificationData({
    required this.senderId,
    required this.username,
    required this.displayName,
    required this.avatarUrl,
    required this.content,
    required this.mediaType,
    required this.timestamp,
    required this.rawEvent,
  });
}

class NotificationAlertService {
  static final NotificationAlertService instance = NotificationAlertService._internal();
  NotificationAlertService._internal();

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Widget Function(UserModel currentUser, UserModel partnerUser)? chatScreenBuilder;

  static const String _kBannerKey = 'privacy_alert_banner';
  static const String _kSoundKey = 'privacy_alert_sound';
  static const String _kHapticKey = 'privacy_alert_haptic';
  static const String _kPreviewKey = 'privacy_alert_preview';

  UserModel? currentUser;
  int? activeChatUserId;

  bool _isBannerEnabled = true;
  bool _isSoundEnabled = true;
  bool _isHapticEnabled = true;
  bool _showPreview = true;

  bool get isBannerEnabled => _isBannerEnabled;
  bool get isSoundEnabled => _isSoundEnabled;
  bool get isHapticEnabled => _isHapticEnabled;
  bool get showPreview => _showPreview;

  final ValueNotifier<bool> bannerEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> soundEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> hapticEnabledNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> previewEnabledNotifier = ValueNotifier<bool>(true);

  StreamSubscription? _socketSubscription;
  Timer? _dismissTimer;

  final ValueNotifier<InAppNotificationData?> activeAlertNotifier =
      ValueNotifier<InAppNotificationData?>(null);

  Future<void> loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isBannerEnabled = prefs.getBool(_kBannerKey) ?? true;
      _isSoundEnabled = prefs.getBool(_kSoundKey) ?? true;
      _isHapticEnabled = prefs.getBool(_kHapticKey) ?? true;
      _showPreview = prefs.getBool(_kPreviewKey) ?? true;

      bannerEnabledNotifier.value = _isBannerEnabled;
      soundEnabledNotifier.value = _isSoundEnabled;
      hapticEnabledNotifier.value = _isHapticEnabled;
      previewEnabledNotifier.value = _showPreview;
    } catch (_) {}
  }

  Future<void> setBannerEnabled(bool val) async {
    _isBannerEnabled = val;
    bannerEnabledNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kBannerKey, val);
    } catch (_) {}
  }

  Future<void> setSoundEnabled(bool val) async {
    _isSoundEnabled = val;
    soundEnabledNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSoundKey, val);
    } catch (_) {}
  }

  Future<void> setHapticEnabled(bool val) async {
    _isHapticEnabled = val;
    hapticEnabledNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kHapticKey, val);
    } catch (_) {}
  }

  Future<void> setPreviewEnabled(bool val) async {
    _showPreview = val;
    previewEnabledNotifier.value = val;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPreviewKey, val);
    } catch (_) {}
  }

  void init({UserModel? user}) {
    if (user != null) {
      currentUser = user;
    }

    loadPreferences();

    // Request web notification permissions if running on web
    requestSystemNotificationPermission();

    _socketSubscription?.cancel();
    _socketSubscription = ChatSocketService.instance.messageStream.listen(_handleIncomingSocketEvent);
  }

  void setCurrentUser(UserModel user) {
    currentUser = user;
  }

  void _handleIncomingSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type != 'chat_message') return;

    final rawSenderId = event['sender_id'];
    final senderId = rawSenderId is int
        ? rawSenderId
        : int.tryParse(rawSenderId?.toString() ?? '') ?? 0;

    if (senderId <= 0) return;

    // 1. Ignore messages sent by current user
    if (currentUser != null && senderId == currentUser!.id) {
      return;
    }

    // 2. Suppress alert if user is currently inside this chat
    if (activeChatUserId != null && activeChatUserId == senderId) {
      return;
    }

    // 3. Suppress alert if conversation is muted
    if (LocalChatStorage.instance.isConversationMuted(senderId)) {
      return;
    }

    final rawContent = event['content']?.toString() ?? '';
    final mediaType = event['media_type']?.toString() ?? 'text';
    final username = event['username']?.toString() ?? 'User';
    final avatarUrl = event['sender_avatar']?.toString() ?? '';

    // 4. Format clean preview label
    String formattedPreview;
    if (mediaType == 'voice' || mediaType == 'audio') {
      final dur = (event['duration_ms'] as num?)?.toInt() ?? 0;
      if (dur > 0) {
        final sec = (dur / 1000).round();
        formattedPreview = '🎙️ Voice message (${sec}s)';
      } else {
        formattedPreview = '🎙️ Voice message';
      }
    } else if (mediaType == 'image' || mediaType == 'photo') {
      formattedPreview = rawContent.isNotEmpty && rawContent != 'Photo' ? '🖼️ $rawContent' : '🖼️ Photo';
    } else if (mediaType == 'album') {
      formattedPreview = rawContent.isNotEmpty ? '🖼️ $rawContent' : '🖼️ Photo album';
    } else if (mediaType == 'video') {
      formattedPreview = rawContent.isNotEmpty ? '🎬 $rawContent' : '🎬 Video clip';
    } else if (mediaType == 'file' || mediaType == 'document' || mediaType == 'mixed') {
      formattedPreview = '📄 ${rawContent.isNotEmpty ? rawContent : 'File attachment'}';
    } else if (mediaType == 'location' || rawContent.contains('📍')) {
      formattedPreview = rawContent.isNotEmpty ? rawContent : '📍 Shared location';
    } else {
      formattedPreview = rawContent.isNotEmpty ? rawContent : 'New message';
    }

    final displayContent = _showPreview ? formattedPreview : 'New message';

    final notificationData = InAppNotificationData(
      senderId: senderId,
      username: username,
      displayName: username,
      avatarUrl: avatarUrl,
      content: displayContent,
      mediaType: mediaType,
      timestamp: DateTime.now(),
      rawEvent: event,
    );

    triggerAlert(notificationData);
  }

  void triggerAlert(InAppNotificationData data) {
    _dismissTimer?.cancel();

    // 1. Haptic alert
    if (isHapticEnabled) {
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    }

    // 2. Cross-platform System Sound chime
    if (isSoundEnabled) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }

    // 3. Trigger browser desktop notification if applicable
    final resolvedAvatar = data.avatarUrl.isNotEmpty ? ApiClient.resolveAvatarUrl(data.avatarUrl) : null;
    showSystemNotification(
      data.displayName,
      data.content,
      iconUrl: resolvedAvatar,
    );

    // 4. Display in-app floating banner if enabled
    if (isBannerEnabled) {
      activeAlertNotifier.value = data;

      // Auto dismiss after 4.2 seconds
      _dismissTimer = Timer(const Duration(milliseconds: 4200), () {
        dismissAlert();
      });
    }
  }

  void dismissAlert() {
    _dismissTimer?.cancel();
    activeAlertNotifier.value = null;
  }

  void openChat(InAppNotificationData data) {
    dismissAlert();

    final partnerUser = UserModel(
      id: data.senderId,
      uuid: data.rawEvent['sender_uuid']?.toString() ?? '',
      username: data.username,
      email: '',
      displayName: data.displayName.isNotEmpty ? data.displayName : data.username,
      avatarUrl: data.avatarUrl,
      isOnline: true,
      createdAt: DateTime.now(),
    );

    if (currentUser != null && chatScreenBuilder != null) {
      navigatorKey.currentState?.push(
        CupertinoPageRoute(
          builder: (_) => chatScreenBuilder!(currentUser!, partnerUser),
        ),
      );
    }
  }

  void dispose() {
    _dismissTimer?.cancel();
    _socketSubscription?.cancel();
  }
}

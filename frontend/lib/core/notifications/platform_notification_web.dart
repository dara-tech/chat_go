import 'dart:js_interop';
import 'package:web/web.dart' as web;

void showPlatformSystemNotification(String title, String body, {String? iconUrl}) {
  try {
    if (web.Notification.permission == 'granted') {
      web.Notification(
        title,
        web.NotificationOptions(
          body: body,
          icon: iconUrl ?? '',
        ),
      );
    }
  } catch (_) {}
}

void requestPlatformNotificationPermission() {
  try {
    if (web.Notification.permission == 'default') {
      web.Notification.requestPermission().toDart;
    }
  } catch (_) {}
}

import 'platform_notification_stub.dart'
    if (dart.library.js_interop) 'platform_notification_web.dart';

void showSystemNotification(String title, String body, {String? iconUrl}) {
  showPlatformSystemNotification(title, body, iconUrl: iconUrl);
}

void requestSystemNotificationPermission() {
  requestPlatformNotificationPermission();
}

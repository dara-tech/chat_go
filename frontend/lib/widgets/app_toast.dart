import 'package:flutter/widgets.dart';
import 'top_capsule_hud.dart';

enum ToastType { info, success, warning, error }

/// Telegram / Dynamic Island style sleek top capsule HUD
class AppToast {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    ToastType type = ToastType.info,
    Duration duration = const Duration(milliseconds: 2200),
  }) {
    TopCapsuleHud.show(
      context,
      message: message,
      isError: type == ToastType.error,
      duration: duration,
    );
  }

  static void dismiss() {
    TopCapsuleHud.dismiss();
  }
}

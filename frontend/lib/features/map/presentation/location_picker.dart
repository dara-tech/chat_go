import 'package:flutter/cupertino.dart';
import 'package:frontend/models/user_model.dart';
import '../domain/map_location.dart';
import 'map_screen.dart';

class LocationPicker {
  /// Opens the full-screen map picker and returns the selected location or null if cancelled
  static Future<MapLocation?> show(
    BuildContext context, {
    MapLocation? initialLocation,
    UserModel? currentUser,
    UserModel? partnerUser,
    String? partnerName,
    String? senderName,
    String? senderAvatarUrl,
    String? senderUsername,
    DateTime? sharedAt,
  }) async {
    return Navigator.of(context).push<MapLocation>(
      CupertinoPageRoute(
        builder: (_) => MapScreen(
          initialLocation: initialLocation,
          currentUser: currentUser,
          partnerUser: partnerUser,
          partnerName: partnerName,
          senderName: senderName,
          senderAvatarUrl: senderAvatarUrl,
          senderUsername: senderUsername,
          sharedAt: sharedAt,
          isPickerMode: true,
        ),
      ),
    );
  }
}

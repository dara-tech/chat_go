import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static final LocationService instance = LocationService._internal();

  LocationService._internal();

  static const String _kAllowGpsKey = 'privacy_allow_gps';
  static const String _kPreciseLocationKey = 'privacy_precise_location';

  bool _allowGps = true;
  bool _preciseLocation = true;
  bool _isLoaded = false;

  final ValueNotifier<bool> allowGpsNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> preciseLocationNotifier = ValueNotifier<bool>(true);

  bool get allowGps => _allowGps;
  bool get preciseLocation => _preciseLocation;

  Future<void> init() async {
    if (_isLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _allowGps = prefs.getBool(_kAllowGpsKey) ?? true;
      _preciseLocation = prefs.getBool(_kPreciseLocationKey) ?? true;
      allowGpsNotifier.value = _allowGps;
      preciseLocationNotifier.value = _preciseLocation;
      _isLoaded = true;
    } catch (_) {
      _isLoaded = true;
    }
  }

  Future<void> setAllowGps(bool allowed) async {
    _allowGps = allowed;
    allowGpsNotifier.value = allowed;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kAllowGpsKey, allowed);
    } catch (_) {}
  }

  Future<void> setPreciseLocation(bool precise) async {
    _preciseLocation = precise;
    preciseLocationNotifier.value = precise;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPreciseLocationKey, precise);
    } catch (_) {}
  }

  /// Fetches real device GPS position if allowed by privacy settings
  Future<Position?> getCurrentPosition() async {
    await init();
    if (!_allowGps) return null;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      final accuracy = _preciseLocation
          ? LocationAccuracy.best
          : LocationAccuracy.medium;

      return await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: accuracy,
          timeLimit: const Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('Error obtaining GPS location: $e');
      return null;
    }
  }

  /// Reverse geocode coordinates to a human-readable address
  Future<String?> reverseGeocode(double lat, double lon) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon&zoom=18&addressdetails=1',
      );
      final response = await http.get(
        uri,
        headers: {'User-Agent': 'ChatGoApp/1.0 (Privacy-Conscious Messenger)'},
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final displayName = data['display_name'] as String?;
        final address = data['address'] as Map<String, dynamic>?;

        if (address != null) {
          final road = address['road'] ?? address['pedestrian'] ?? address['suburb'] ?? '';
          final city = address['city'] ?? address['town'] ?? address['municipality'] ?? address['state'] ?? '';
          final country = address['country'] ?? '';
          final parts = [road, city, country].where((s) => s.toString().isNotEmpty).toList();
          if (parts.isNotEmpty) {
            return parts.join(', ');
          }
        }
        return displayName;
      }
    } catch (_) {}
    return null;
  }
}

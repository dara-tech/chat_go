import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:frontend/core/location/location_service.dart' as core;
import '../domain/map_location.dart';

class MapLocationService {
  static final MapLocationService instance = MapLocationService._internal();
  MapLocationService._internal();

  final core.LocationService _coreService = core.LocationService.instance;
  StreamSubscription<Position>? _positionStreamSub;
  final _liveLocationController = StreamController<MapLocation>.broadcast();

  Stream<MapLocation> get liveLocationStream => _liveLocationController.stream;

  bool get allowGps => _coreService.allowGps;
  bool get preciseLocation => _coreService.preciseLocation;

  Future<void> init() async {
    await _coreService.init();
  }

  /// Get current GPS location mapped to domain MapLocation
  Future<MapLocation?> getCurrentLocation() async {
    final pos = await _coreService.getCurrentPosition();
    if (pos == null) return null;

    final addr = await _coreService.reverseGeocode(pos.latitude, pos.longitude);

    return MapLocation(
      latitude: pos.latitude,
      longitude: pos.longitude,
      accuracy: pos.accuracy,
      timestamp: pos.timestamp,
      name: addr != null ? addr.split(',').first.trim() : 'Current Location',
      address: addr,
    );
  }

  /// Reverse geocode coordinates
  Future<String?> reverseGeocode(double lat, double lon) async {
    return _coreService.reverseGeocode(lat, lon);
  }

  /// Starts continuous GPS tracking for live location sharing
  Future<bool> startLiveTracking({
    required Function(MapLocation location) onUpdate,
    int distanceFilterMeters = 5,
  }) async {
    await init();
    if (!allowGps) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }
    }

    await stopLiveTracking();

    final locationSettings = LocationSettings(
      accuracy: preciseLocation ? LocationAccuracy.high : LocationAccuracy.medium,
      distanceFilter: distanceFilterMeters,
    );

    _positionStreamSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((position) {
      final loc = MapLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        timestamp: position.timestamp,
      );
      _liveLocationController.add(loc);
      onUpdate(loc);
    }, onError: (err) {
      debugPrint('[MapLocationService] Live tracking error: $err');
    });

    return true;
  }

  /// Stops continuous GPS tracking
  Future<void> stopLiveTracking() async {
    await _positionStreamSub?.cancel();
    _positionStreamSub = null;
  }
}

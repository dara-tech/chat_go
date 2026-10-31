import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/location_service.dart';
import '../data/routing_service.dart';
import '../domain/map_location.dart';
import '../domain/route_model.dart';
import '../widgets/cartodb_map_engine.dart';

class MapViewState {
  final MapLocation center;
  final int zoom;
  final MapTileStyle mapStyle;
  final MapLocation? myGpsLocation;
  final MapLocation? selectedLocation;
  final RouteModel? activeRoute;
  final bool isLocating;
  final bool isRouting;
  final bool isLiveSharing;
  final LiveLocationSession? activeLiveSession;

  const MapViewState({
    required this.center,
    this.zoom = 15,
    this.mapStyle = MapTileStyle.voyager,
    this.myGpsLocation,
    this.selectedLocation,
    this.activeRoute,
    this.isLocating = false,
    this.isRouting = false,
    this.isLiveSharing = false,
    this.activeLiveSession,
  });

  MapViewState copyWith({
    MapLocation? center,
    int? zoom,
    MapTileStyle? mapStyle,
    MapLocation? myGpsLocation,
    MapLocation? selectedLocation,
    RouteModel? activeRoute,
    bool? isLocating,
    bool? isRouting,
    bool? isLiveSharing,
    LiveLocationSession? activeLiveSession,
    bool clearRoute = false,
  }) {
    return MapViewState(
      center: center ?? this.center,
      zoom: zoom ?? this.zoom,
      mapStyle: mapStyle ?? this.mapStyle,
      myGpsLocation: myGpsLocation ?? this.myGpsLocation,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      activeRoute: clearRoute ? null : (activeRoute ?? this.activeRoute),
      isLocating: isLocating ?? this.isLocating,
      isRouting: isRouting ?? this.isRouting,
      isLiveSharing: isLiveSharing ?? this.isLiveSharing,
      activeLiveSession: activeLiveSession ?? this.activeLiveSession,
    );
  }
}

class MapController extends ChangeNotifier {
  MapViewState _state = const MapViewState(
    center: MapLocation.phnomPenh,
    zoom: 15,
  );

  MapViewState get state => _state;

  StreamSubscription<MapLocation>? _liveSub;

  MapController({MapLocation? initialLocation, int initialZoom = 15}) {
    if (initialLocation != null) {
      _state = _state.copyWith(
        center: initialLocation,
        selectedLocation: initialLocation,
        zoom: initialZoom,
      );
    }
  }

  /// Change map style between voyager and dark
  void toggleMapStyle() {
    final nextStyle = _state.mapStyle == MapTileStyle.voyager
        ? MapTileStyle.dark
        : MapTileStyle.voyager;
    _state = _state.copyWith(mapStyle: nextStyle);
    notifyListeners();
  }

  /// Zoom in
  void zoomIn() {
    if (_state.zoom < 19) {
      _state = _state.copyWith(zoom: _state.zoom + 1);
      notifyListeners();
    }
  }

  /// Zoom out
  void zoomOut() {
    if (_state.zoom > 3) {
      _state = _state.copyWith(zoom: _state.zoom - 1);
      notifyListeners();
    }
  }

  /// Center moved by user dragging
  void updateCenter(MapLocation loc) {
    _state = _state.copyWith(center: loc);
    notifyListeners();
  }

  /// Select a location and resolve address if needed
  Future<void> selectLocation(MapLocation loc, {bool calculateRouteToGps = false}) async {
    _state = _state.copyWith(
      center: loc,
      selectedLocation: loc,
      clearRoute: !calculateRouteToGps,
    );
    notifyListeners();

    // If place has no reverse geocoded address, resolve it asynchronously
    if (loc.address == null || loc.address!.isEmpty) {
      final addr = await MapLocationService.instance.reverseGeocode(
        loc.latitude,
        loc.longitude,
      );
      if (addr != null && _state.selectedLocation?.latitude == loc.latitude) {
        _state = _state.copyWith(
          selectedLocation: loc.copyWith(
            name: addr.split(',').first.trim(),
            address: addr,
          ),
        );
        notifyListeners();
      }
    }

    if (calculateRouteToGps && _state.myGpsLocation != null) {
      await calculateRoute(
        origin: _state.myGpsLocation!,
        destination: loc,
      );
    }
  }

  /// Detect and center onto user's current GPS position
  Future<void> detectAndCenterGps() async {
    _state = _state.copyWith(isLocating: true);
    notifyListeners();

    final loc = await MapLocationService.instance.getCurrentLocation();
    if (loc != null) {
      _state = _state.copyWith(
        myGpsLocation: loc,
        center: loc,
        isLocating: false,
      );
    } else {
      _state = _state.copyWith(isLocating: false);
    }
    notifyListeners();
  }

  /// Calculate route from origin to destination
  Future<void> calculateRoute({
    required MapLocation origin,
    required MapLocation destination,
  }) async {
    _state = _state.copyWith(isRouting: true);
    notifyListeners();

    final route = await RoutingService.instance.calculateRoute(
      origin: origin,
      destination: destination,
    );

    _state = _state.copyWith(
      activeRoute: route,
      isRouting: false,
    );
    notifyListeners();
  }

  /// Clear active route
  void clearRoute() {
    _state = _state.copyWith(clearRoute: true);
    notifyListeners();
  }

  /// Toggle live location sharing
  Future<void> toggleLiveSharing({
    required int userId,
    required String username,
    String? avatarUrl,
    Duration duration = const Duration(minutes: 15),
  }) async {
    if (_state.isLiveSharing) {
      // Stop live sharing
      await MapLocationService.instance.stopLiveTracking();
      await _liveSub?.cancel();
      _liveSub = null;
      _state = _state.copyWith(isLiveSharing: false, activeLiveSession: null);
      notifyListeners();
      return;
    }

    // Start live sharing
    final started = await MapLocationService.instance.startLiveTracking(
      onUpdate: (loc) {
        _state = _state.copyWith(
          myGpsLocation: loc,
          activeLiveSession: LiveLocationSession(
            sessionId: 'live_${userId}_${DateTime.now().millisecondsSinceEpoch}',
            userId: userId,
            username: username,
            avatarUrl: avatarUrl,
            location: loc,
            startedAt: DateTime.now(),
            expiresAt: DateTime.now().add(duration),
            isSharing: true,
          ),
        );
        notifyListeners();
      },
    );

    if (started) {
      _state = _state.copyWith(
        isLiveSharing: true,
        activeLiveSession: LiveLocationSession(
          sessionId: 'live_${userId}_${DateTime.now().millisecondsSinceEpoch}',
          userId: userId,
          username: username,
          avatarUrl: avatarUrl,
          location: _state.myGpsLocation ?? MapLocation.phnomPenh,
          startedAt: DateTime.now(),
          expiresAt: DateTime.now().add(duration),
          isSharing: true,
        ),
      );
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    super.dispose();
  }
}

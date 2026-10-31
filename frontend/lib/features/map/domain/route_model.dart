import 'map_location.dart';

/// Single step in a turn-by-turn route
class RouteStep {
  final String instruction;
  final double distanceMeters;
  final double durationSeconds;
  final String? maneuverType;
  final String? modifier;
  final MapLocation location;

  const RouteStep({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    this.maneuverType,
    this.modifier,
    required this.location,
  });

  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }
}

/// Model representing a calculated route from an origin to a destination
class RouteModel {
  final MapLocation origin;
  final MapLocation destination;
  final double distanceMeters;
  final double durationSeconds;
  final List<MapLocation> polyline;
  final List<RouteStep> steps;

  const RouteModel({
    required this.origin,
    required this.destination,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.polyline,
    this.steps = const [],
  });

  /// Human-readable total distance (e.g. "4.2 km" or "850 m")
  String get formattedDistance {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  /// Human-readable duration (e.g. "12 min" or "1 hr 15 min")
  String get formattedDuration {
    final minutes = (durationSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final remMin = minutes % 60;
    if (remMin == 0) {
      return '$hours hr';
    }
    return '$hours hr $remMin min';
  }
}

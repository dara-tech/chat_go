import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/map_location.dart';
import '../domain/route_model.dart';

class RoutingService {
  static final RoutingService instance = RoutingService._internal();
  RoutingService._internal();

  /// Calculates a driving route between origin and destination using OSRM
  Future<RouteModel?> calculateRoute({
    required MapLocation origin,
    required MapLocation destination,
  }) async {
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}'
        '?overview=full&geometries=geojson&steps=true',
      );

      final response = await http
          .get(url, headers: {'User-Agent': 'ChatGoApp/1.0 (Location Route Calculator)'})
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List<dynamic>?;
        if (routes != null && routes.isNotEmpty) {
          final firstRoute = routes[0] as Map<String, dynamic>;
          final distance = (firstRoute['distance'] as num?)?.toDouble() ?? 0.0;
          final duration = (firstRoute['duration'] as num?)?.toDouble() ?? 0.0;

          // Parse geometry coordinates
          final geometry = firstRoute['geometry'] as Map<String, dynamic>?;
          final coordinates = geometry?['coordinates'] as List<dynamic>? ?? [];
          final polyline = coordinates.map((coord) {
            final lon = (coord[0] as num).toDouble();
            final lat = (coord[1] as num).toDouble();
            return MapLocation(latitude: lat, longitude: lon);
          }).toList();

          // Parse steps
          final legs = firstRoute['legs'] as List<dynamic>? ?? [];
          final steps = <RouteStep>[];
          if (legs.isNotEmpty) {
            final rawSteps = legs[0]['steps'] as List<dynamic>? ?? [];
            for (final s in rawSteps) {
              final stepMap = s as Map<String, dynamic>;
              final maneuver = stepMap['maneuver'] as Map<String, dynamic>?;
              final maneuverType = maneuver?['type'] as String?;
              final modifier = maneuver?['modifier'] as String?;
              final stepLoc = maneuver?['location'] as List<dynamic>?;
              final stepLat = (stepLoc != null && stepLoc.length > 1)
                  ? (stepLoc[1] as num).toDouble()
                  : origin.latitude;
              final stepLon = (stepLoc != null && stepLoc.isNotEmpty)
                  ? (stepLoc[0] as num).toDouble()
                  : origin.longitude;

              String instruction = '';
              final name = stepMap['name'] as String? ?? '';
              if (maneuverType == 'depart') {
                instruction = name.isNotEmpty ? 'Head on $name' : 'Head towards destination';
              } else if (maneuverType == 'arrive') {
                instruction = 'Arrive at destination';
              } else if (modifier != null) {
                final action = modifier.replaceAll('_', ' ');
                instruction = name.isNotEmpty
                    ? 'Turn $action onto $name'
                    : 'Turn $action';
              } else {
                instruction = name.isNotEmpty ? 'Continue onto $name' : 'Continue straight';
              }

              steps.add(
                RouteStep(
                  instruction: instruction,
                  distanceMeters: (stepMap['distance'] as num?)?.toDouble() ?? 0.0,
                  durationSeconds: (stepMap['duration'] as num?)?.toDouble() ?? 0.0,
                  maneuverType: maneuverType,
                  modifier: modifier,
                  location: MapLocation(latitude: stepLat, longitude: stepLon),
                ),
              );
            }
          }

          return RouteModel(
            origin: origin,
            destination: destination,
            distanceMeters: distance,
            durationSeconds: duration,
            polyline: polyline.isNotEmpty
                ? polyline
                : [origin, destination],
            steps: steps,
          );
        }
      }
    } catch (e) {
      debugPrint('[RoutingService] Failed to fetch OSRM route: $e');
    }

    // Fallback: straight line route
    return RouteModel(
      origin: origin,
      destination: destination,
      distanceMeters: _calculateHaversineDistance(origin, destination),
      durationSeconds: (_calculateHaversineDistance(origin, destination) / 10.0), // ~36 km/h avg
      polyline: [origin, destination],
      steps: [
        RouteStep(
          instruction: 'Proceed directly towards destination',
          distanceMeters: _calculateHaversineDistance(origin, destination),
          durationSeconds: (_calculateHaversineDistance(origin, destination) / 10.0),
          location: origin,
        ),
      ],
    );
  }

  /// Calculates straight-line distance in meters using Haversine formula
  double _calculateHaversineDistance(MapLocation loc1, MapLocation loc2) {
    const earthRadius = 6371000.0; // meters
    final dLat = _degreesToRadians(loc2.latitude - loc1.latitude);
    final dLon = _degreesToRadians(loc2.longitude - loc1.longitude);

    final a = (dLat / 2).abs() * (dLat / 2).abs() +
        (loc1.latitude * 3.141592653589793 / 180.0) *
            (loc2.latitude * 3.141592653589793 / 180.0) *
            (dLon / 2).abs() *
            (dLon / 2).abs();
    final c = 2 * (a < 1 ? a : 1);
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * 3.141592653589793 / 180.0;
  }
}

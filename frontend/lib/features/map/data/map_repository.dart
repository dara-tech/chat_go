import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../domain/map_location.dart';

class MapRepository {
  static final MapRepository instance = MapRepository._internal();
  MapRepository._internal();

  /// Default popular landmarks for quick picking
  static const List<MapLocation> defaultLandmarks = [
    MapLocation(
      latitude: 11.5794,
      longitude: 104.9261,
      name: 'Wat Phnom Historical Sanctuary',
      address: 'Street 96, Daun Penh, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5636,
      longitude: 104.9318,
      name: 'Royal Palace of Cambodia',
      address: 'Samdach Sothearos Blvd, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5564,
      longitude: 104.9282,
      name: 'Independence Monument',
      address: 'Preah Sihanouk Blvd, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5710,
      longitude: 104.9305,
      name: 'Sisowath Quay Riverside',
      address: 'Sisowath Quay, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5518,
      longitude: 104.9265,
      name: 'Boeung Keng Kang 1 (BKK1)',
      address: 'Street 51 / 302, Chamkarmon, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5739,
      longitude: 104.9205,
      name: 'Vattanac Capital Tower',
      address: 'Monivong Blvd, Sangkat Wat Phnom, Phnom Penh',
    ),
    MapLocation(
      latitude: 11.5478,
      longitude: 104.9340,
      name: 'Aeon Mall Phnom Penh',
      address: '#132, Samdach Sothearos Blvd, Phnom Penh',
    ),
  ];

  /// Search places or addresses using OpenStreetMap Nominatim
  Future<List<MapLocation>> searchPlaces(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return defaultLandmarks;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&q=${Uri.encodeComponent(cleanQuery)}&addressdetails=1&limit=10',
      );

      final res = await http.get(
        uri,
        headers: {'User-Agent': 'ChatGoApp/1.0 (Place Search)'},
      ).timeout(const Duration(seconds: 5));

      if (res.statusCode == 200) {
        final List<dynamic> list = jsonDecode(res.body);
        return list.map((item) {
          final lat = double.tryParse(item['lat']?.toString() ?? '') ?? 11.5621;
          final lon = double.tryParse(item['lon']?.toString() ?? '') ?? 104.9282;
          final displayName = item['display_name'] as String? ?? 'Selected Location';
          final name = item['name'] as String? ?? displayName.split(',').first.trim();

          return MapLocation(
            latitude: lat,
            longitude: lon,
            name: name.isNotEmpty ? name : displayName,
            address: displayName,
          );
        }).toList();
      }
    } catch (e) {
      debugPrint('[MapRepository] Place search error: $e');
    }

    // Filter local fallback list if query fails or network offline
    final qLower = cleanQuery.toLowerCase();
    return defaultLandmarks.where((l) {
      return (l.name?.toLowerCase().contains(qLower) ?? false) ||
          (l.address?.toLowerCase().contains(qLower) ?? false);
    }).toList();
  }
}

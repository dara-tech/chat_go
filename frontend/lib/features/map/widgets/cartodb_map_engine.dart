import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/map_location.dart';

enum MapTileStyle {
  voyager,
  dark,
}

class MapMarkerData {
  final String id;
  final MapLocation location;
  final Widget child;
  final Offset anchor; // (0.5, 1.0) for bottom pin, (0.5, 0.5) for center circle

  const MapMarkerData({
    required this.id,
    required this.location,
    required this.child,
    this.anchor = const Offset(0.5, 0.5),
  });
}

/// Unified, reusable high-performance CartoDB Map Engine
/// Supports interactive drag, pinch-to-zoom, route polylines, and arbitrary markers.
class CartoDbMapEngine extends StatefulWidget {
  final double centerLatitude;
  final double centerLongitude;
  final int zoom;
  final bool showLabels;
  final MapTileStyle mapStyle;
  final bool isInteractive;
  final List<MapMarkerData> markers;
  final List<MapLocation> routePolyline;
  final Color polylineColor;
  final double polylineWidth;
  final ValueChanged<MapLocation>? onTapCoordinate;
  final ValueChanged<int>? onZoomChanged;
  final ValueChanged<MapLocation>? onCenterMoved;
  final String apiKey;

  const CartoDbMapEngine({
    super.key,
    required this.centerLatitude,
    required this.centerLongitude,
    this.zoom = 15,
    this.showLabels = true,
    this.mapStyle = MapTileStyle.voyager,
    this.isInteractive = true,
    this.markers = const [],
    this.routePolyline = const [],
    this.polylineColor = const Color(0xFF007AFF),
    this.polylineWidth = 4.5,
    this.onTapCoordinate,
    this.onZoomChanged,
    this.onCenterMoved,
    this.apiKey = 'cb1_4x5a_1_c399d7d028c3eddda3b3ba10',
  });

  @override
  State<CartoDbMapEngine> createState() => _CartoDbMapEngineState();
}

class _CartoDbMapEngineState extends State<CartoDbMapEngine> {
  static const double tileSize = 256.0;

  late double _currentLat;
  late double _currentLon;
  late int _currentZoom;
  Offset _panOffset = Offset.zero;

  // Scale gesture state
  double _scaleStartZoom = 15.0;
  Offset _scaleStartOffset = Offset.zero;

  @override
  void initState() {
    super.initState();
    _currentLat = widget.centerLatitude;
    _currentLon = widget.centerLongitude;
    _currentZoom = widget.zoom.clamp(3, 19);
  }

  @override
  void didUpdateWidget(covariant CartoDbMapEngine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centerLatitude != widget.centerLatitude ||
        oldWidget.centerLongitude != widget.centerLongitude) {
      setState(() {
        _currentLat = widget.centerLatitude;
        _currentLon = widget.centerLongitude;
        _panOffset = Offset.zero;
      });
    }
    if (oldWidget.zoom != widget.zoom) {
      setState(() {
        _currentZoom = widget.zoom.clamp(3, 19);
      });
    }
  }

  // --- Web Mercator Math ---
  static double lonToGlobalPixel(double lon, int zoom) {
    final n = 1 << zoom;
    return ((lon + 180.0) / 360.0 * n) * tileSize;
  }

  static double latToGlobalPixel(double lat, int zoom) {
    final n = 1 << zoom;
    final latRad = lat * math.pi / 180.0;
    final clampedLatRad = latRad.clamp(-1.4844, 1.4844);
    final y = (1.0 - math.log(math.tan(clampedLatRad) + 1.0 / math.cos(clampedLatRad)) / math.pi) / 2.0 * n;
    return y * tileSize;
  }

  static double globalPixelToLon(double px, int zoom) {
    final n = 1 << zoom;
    return (px / (n * tileSize)) * 360.0 - 180.0;
  }

  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2.0;

  static double globalPixelToLat(double py, int zoom) {
    final n = 1 << zoom;
    final y = 1.0 - 2.0 * (py / (n * tileSize));
    final latRad = math.atan(_sinh(math.pi * y));
    return latRad * 180.0 / math.pi;
  }

  String _getLayerName() {
    if (widget.mapStyle == MapTileStyle.voyager) {
      return widget.showLabels ? 'voyager' : 'voyager_nolabels';
    } else {
      return widget.showLabels ? 'dark_all' : 'dark_nolabels';
    }
  }

  void _handleTapUp(TapUpDetails details, double width, double height) {
    if (widget.onTapCoordinate == null) return;
    final centerX = width / 2.0 + _panOffset.dx;
    final centerY = height / 2.0 + _panOffset.dy;

    final centerPixelX = lonToGlobalPixel(_currentLon, _currentZoom);
    final centerPixelY = latToGlobalPixel(_currentLat, _currentZoom);

    final tapGlobalPixelX = centerPixelX + (details.localPosition.dx - centerX);
    final tapGlobalPixelY = centerPixelY + (details.localPosition.dy - centerY);

    final tappedLon = globalPixelToLon(tapGlobalPixelX, _currentZoom);
    final tappedLat = globalPixelToLat(tapGlobalPixelY, _currentZoom);

    widget.onTapCoordinate!(MapLocation(
      latitude: tappedLat,
      longitude: tappedLon,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (width <= 0 || height <= 0) {
          return const SizedBox.shrink();
        }

        final centerX = width / 2.0 + _panOffset.dx;
        final centerY = height / 2.0 + _panOffset.dy;

        final centerPixelX = lonToGlobalPixel(_currentLon, _currentZoom);
        final centerPixelY = latToGlobalPixel(_currentLat, _currentZoom);

        final minGlobalPixelX = centerPixelX - centerX;
        final maxGlobalPixelX = centerPixelX + (width - centerX);
        final minGlobalPixelY = centerPixelY - centerY;
        final maxGlobalPixelY = centerPixelY + (height - centerY);

        final minTileX = (minGlobalPixelX / tileSize).floor() - 1;
        final maxTileX = (maxGlobalPixelX / tileSize).floor() + 1;
        final minTileY = (minGlobalPixelY / tileSize).floor() - 1;
        final maxTileY = (maxGlobalPixelY / tileSize).floor() + 1;

        final maxCoord = (1 << _currentZoom) - 1;

        final tiles = <Widget>[];
        final subdomains = ['a', 'b', 'c', 'd'];
        final layerName = _getLayerName();

        for (int tx = minTileX; tx <= maxTileX; tx++) {
          for (int ty = minTileY; ty <= maxTileY; ty++) {
            if (ty < 0 || ty > maxCoord) continue;

            final wrappedTx = ((tx % (maxCoord + 1)) + (maxCoord + 1)) % (maxCoord + 1);
            final s = subdomains[(tx.abs() + ty.abs()) % 4];
            final tileUrl =
                'https://$s.basemaps.cartocdn.com/rastertiles/$layerName/$_currentZoom/$wrappedTx/$ty@2x.png?key=${widget.apiKey}';

            final leftPos = centerX + (tx * tileSize - centerPixelX);
            final topPos = centerY + (ty * tileSize - centerPixelY);

            tiles.add(
              Positioned(
                left: leftPos,
                top: topPos,
                width: tileSize,
                height: tileSize,
                child: Image.network(
                  tileUrl,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                  errorBuilder: (ctx, err, stack) => Container(
                    color: widget.mapStyle == MapTileStyle.voyager
                        ? const Color(0xFFE8ECEF)
                        : const Color(0xFF161E2E),
                  ),
                ),
              ),
            );
          }
        }

        // Overlay: Route Polyline
        Widget? polylineWidget;
        if (widget.routePolyline.isNotEmpty) {
          polylineWidget = CustomPaint(
            size: Size(width, height),
            painter: _RoutePolylinePainter(
              polyline: widget.routePolyline,
              centerX: centerX,
              centerY: centerY,
              centerPixelX: centerPixelX,
              centerPixelY: centerPixelY,
              zoom: _currentZoom,
              color: widget.polylineColor,
              strokeWidth: widget.polylineWidth,
            ),
          );
        }

        // Overlay: Markers positioned at exact screen coordinates
        final markerWidgets = <Widget>[];
        for (final m in widget.markers) {
          final targetGlobalX = lonToGlobalPixel(m.location.longitude, _currentZoom);
          final targetGlobalY = latToGlobalPixel(m.location.latitude, _currentZoom);
          final screenX = centerX + (targetGlobalX - centerPixelX);
          final screenY = centerY + (targetGlobalY - centerPixelY);

          markerWidgets.add(
            Positioned(
              left: screenX,
              top: screenY,
              child: FractionalTranslation(
                translation: Offset(-m.anchor.dx, -m.anchor.dy),
                child: m.child,
              ),
            ),
          );
        }

        final stackContent = Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            Container(
              color: widget.mapStyle == MapTileStyle.voyager
                  ? const Color(0xFFE8ECEF)
                  : const Color(0xFF121620),
            ),
            ...tiles,
            ?polylineWidget,
            ...markerWidgets,
          ],
        );

        if (!widget.isInteractive) {
          return stackContent;
        }

        return GestureDetector(
          onTapUp: (details) => _handleTapUp(details, width, height),
          onScaleStart: (details) {
            _scaleStartZoom = _currentZoom.toDouble();
            _scaleStartOffset = _panOffset;
          },
          onScaleUpdate: (details) {
            setState(() {
              _panOffset = _scaleStartOffset + details.focalPointDelta;

              // Handle pinch-to-zoom
              if (details.scale != 1.0) {
                final scaleDelta = math.log(details.scale) / math.ln2;
                final newZoom = (_scaleStartZoom + scaleDelta).round().clamp(3, 19);
                if (newZoom != _currentZoom) {
                  _currentZoom = newZoom;
                  widget.onZoomChanged?.call(newZoom);
                }
              }
            });

            // Report new center coordinate periodically
            final curCenterPixelX = centerPixelX - _panOffset.dx;
            final curCenterPixelY = centerPixelY - _panOffset.dy;
            final curLon = globalPixelToLon(curCenterPixelX, _currentZoom);
            final curLat = globalPixelToLat(curCenterPixelY, _currentZoom);
            widget.onCenterMoved?.call(MapLocation(latitude: curLat, longitude: curLon));
          },
          child: stackContent,
        );
      },
    );
  }
}

class _RoutePolylinePainter extends CustomPainter {
  final List<MapLocation> polyline;
  final double centerX;
  final double centerY;
  final double centerPixelX;
  final double centerPixelY;
  final int zoom;
  final Color color;
  final double strokeWidth;

  _RoutePolylinePainter({
    required this.polyline,
    required this.centerX,
    required this.centerY,
    required this.centerPixelX,
    required this.centerPixelY,
    required this.zoom,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polyline.length < 2) return;

    final path = Path();
    bool isFirst = true;

    for (final loc in polyline) {
      final globalX = _CartDbMath.lonToGlobalPixel(loc.longitude, zoom);
      final globalY = _CartDbMath.latToGlobalPixel(loc.latitude, zoom);
      final screenX = centerX + (globalX - centerPixelX);
      final screenY = centerY + (globalY - centerPixelY);

      if (isFirst) {
        path.moveTo(screenX, screenY);
        isFirst = false;
      } else {
        path.lineTo(screenX, screenY);
      }
    }

    // Outer glow / shadow
    final haloPaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, haloPaint);

    // Inner route line
    final linePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _RoutePolylinePainter oldDelegate) {
    return oldDelegate.polyline != polyline ||
        oldDelegate.centerX != centerX ||
        oldDelegate.centerY != centerY ||
        oldDelegate.zoom != zoom ||
        oldDelegate.color != color;
  }
}

class _CartDbMath {
  static const double tileSize = 256.0;

  static double lonToGlobalPixel(double lon, int zoom) {
    final n = 1 << zoom;
    return ((lon + 180.0) / 360.0 * n) * tileSize;
  }

  static double latToGlobalPixel(double lat, int zoom) {
    final n = 1 << zoom;
    final latRad = lat * math.pi / 180.0;
    final clampedLatRad = latRad.clamp(-1.4844, 1.4844);
    final y = (1.0 - math.log(math.tan(clampedLatRad) + 1.0 / math.cos(clampedLatRad)) / math.pi) / 2.0 * n;
    return y * tileSize;
  }
}

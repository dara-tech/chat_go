import 'dart:math' as math;
import 'package:flutter/material.dart';

class CartoDbLocation {
  final double latitude;
  final double longitude;

  const CartoDbLocation(this.latitude, this.longitude);

  static const CartoDbLocation defaultPhnomPenh = CartoDbLocation(11.5621, 104.9282);

  static CartoDbLocation parse(String content) {
    final geoMatch = RegExp(r'geo:(-?\d+\.?\d*),(-?\d+\.?\d*)').firstMatch(content);
    if (geoMatch != null) {
      final lat = double.tryParse(geoMatch.group(1) ?? '');
      final lon = double.tryParse(geoMatch.group(2) ?? '');
      if (lat != null && lon != null) {
        return CartoDbLocation(lat, lon);
      }
    }
    return defaultPhnomPenh;
  }
}

enum CartoMapStyle {
  voyager,
  dark,
}

/// A fast, native Flutter widget that renders real CartoDB raster tiles
/// using the user's authenticated CartoDB API key.
class CartoDbMapView extends StatefulWidget {
  final double latitude;
  final double longitude;
  final int zoom;
  final bool showLabels;
  final CartoMapStyle mapStyle;
  final bool isInteractive;
  final Offset offset;
  final ValueChanged<Offset>? onPanUpdate;
  final String apiKey;

  const CartoDbMapView({
    super.key,
    required this.latitude,
    required this.longitude,
    this.zoom = 15,
    this.showLabels = false,
    this.mapStyle = CartoMapStyle.voyager,
    this.isInteractive = false,
    this.offset = Offset.zero,
    this.onPanUpdate,
    this.apiKey = 'cb1_4x5a_1_c399d7d028c3eddda3b3ba10',
  });

  @override
  State<CartoDbMapView> createState() => _CartoDbMapViewState();
}

// Backward-compatible alias
typedef CartoDbDarkMapView = CartoDbMapView;

class _CartoDbMapViewState extends State<CartoDbMapView> {
  static const double tileSize = 256.0;

  static double _lonToGlobalPixel(double lon, int zoom) {
    final n = 1 << zoom;
    return ((lon + 180.0) / 360.0 * n) * tileSize;
  }

  static double _latToGlobalPixel(double lat, int zoom) {
    final n = 1 << zoom;
    final latRad = lat * math.pi / 180.0;
    final clampedLatRad = latRad.clamp(-1.4844, 1.4844);
    final y = (1.0 - math.log(math.tan(clampedLatRad) + 1.0 / math.cos(clampedLatRad)) / math.pi) / 2.0 * n;
    return y * tileSize;
  }

  String _getLayerName() {
    if (widget.mapStyle == CartoMapStyle.voyager) {
      return widget.showLabels ? 'voyager' : 'voyager_nolabels';
    } else {
      return widget.showLabels ? 'dark_all' : 'dark_nolabels';
    }
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

        final centerX = width / 2.0 + widget.offset.dx;
        final centerY = height / 2.0 + widget.offset.dy;

        final centerPixelX = _lonToGlobalPixel(widget.longitude, widget.zoom);
        final centerPixelY = _latToGlobalPixel(widget.latitude, widget.zoom);

        final minGlobalPixelX = centerPixelX - centerX;
        final maxGlobalPixelX = centerPixelX + (width - centerX);
        final minGlobalPixelY = centerPixelY - centerY;
        final maxGlobalPixelY = centerPixelY + (height - centerY);

        final minTileX = (minGlobalPixelX / tileSize).floor() - 1;
        final maxTileX = (maxGlobalPixelX / tileSize).floor() + 1;
        final minTileY = (minGlobalPixelY / tileSize).floor() - 1;
        final maxTileY = (maxGlobalPixelY / tileSize).floor() + 1;

        final maxCoord = (1 << widget.zoom) - 1;

        final tiles = <Widget>[];
        final subdomains = ['a', 'b', 'c', 'd'];
        final layerName = _getLayerName();

        for (int tx = minTileX; tx <= maxTileX; tx++) {
          for (int ty = minTileY; ty <= maxTileY; ty++) {
            if (ty < 0 || ty > maxCoord) continue;

            final wrappedTx = ((tx % (maxCoord + 1)) + (maxCoord + 1)) % (maxCoord + 1);
            final s = subdomains[(tx.abs() + ty.abs()) % 4];
            final tileUrl =
                'https://$s.basemaps.cartocdn.com/rastertiles/$layerName/${widget.zoom}/$wrappedTx/$ty@2x.png?key=${widget.apiKey}';

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
                    color: widget.mapStyle == CartoMapStyle.voyager
                        ? const Color(0xFFE8ECEF)
                        : const Color(0xFF161E2E),
                  ),
                ),
              ),
            );
          }
        }

        Widget mapStack = Stack(
          fit: StackFit.expand,
          children: [
            Container(
              color: widget.mapStyle == CartoMapStyle.voyager
                  ? const Color(0xFFE8ECEF)
                  : const Color(0xFF121620),
            ),
            ...tiles,
          ],
        );

        if (widget.isInteractive && widget.onPanUpdate != null) {
          return GestureDetector(
            onPanUpdate: (details) {
              widget.onPanUpdate!(widget.offset + details.delta);
            },
            child: mapStack,
          );
        }

        return mapStack;
      },
    );
  }
}

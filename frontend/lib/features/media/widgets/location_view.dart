import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/core/location/location_service.dart';
import 'package:frontend/core/theme/theme_controller.dart';
import 'package:frontend/models/user_model.dart';
import 'package:frontend/features/settings/screens/privacy_settings_screen.dart';
import 'package:frontend/features/map/domain/map_location.dart';
import 'package:frontend/features/map/presentation/location_picker.dart';
import 'cartodb_map_view.dart';

class PlaceItem {
  final String title;
  final String address;
  final IconData icon;
  final Color iconColor;
  final double distanceMetres;
  final double latitude;
  final double longitude;

  const PlaceItem({
    required this.title,
    required this.address,
    required this.icon,
    required this.iconColor,
    required this.distanceMetres,
    this.latitude = 11.5621,
    this.longitude = 104.9282,
  });
}

class LocationView extends StatefulWidget {
  final UserModel? currentUser;
  final Function(String title, String address) onSendLocation;
  final VoidCallback onClose;

  const LocationView({
    super.key,
    required this.currentUser,
    required this.onSendLocation,
    required this.onClose,
  });

  @override
  State<LocationView> createState() => _LocationViewState();
}

class _LocationViewState extends State<LocationView>
    with SingleTickerProviderStateMixin {
  Offset _mapOffset = Offset.zero;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  int _mapStyleIndex = 0; // 0: Auto from theme, 1: Alternate

  double _currentLat = 11.5621;
  double _currentLon = 104.9282;
  int _accuracyMeters = 20;
  String _currentPlaceName = '📍 Shared Location (Phnom Penh, Cambodia)';
  bool _isLocating = false;
  bool _gpsAllowed = true;

  late AnimationController _recenterAnimController;
  Animation<Offset>? _recenterAnimation;

  static const List<PlaceItem> _defaultPlaces = [
    PlaceItem(
      title: 'Doors Music & Tapas',
      address: "No 18' Street 47 & 84",
      icon: CupertinoIcons.music_note_2,
      iconColor: Color(0xFFF97316),
      distanceMetres: 120,
      latitude: 11.5794,
      longitude: 104.9261,
    ),
    PlaceItem(
      title: 'Metro Hassakan (Metro Cafe)',
      address: '#271, St. 148 and Sisowath Quay',
      icon: CupertinoIcons.sparkles,
      iconColor: Color(0xFFF59E0B),
      distanceMetres: 240,
      latitude: 11.5683,
      longitude: 104.9312,
    ),
    PlaceItem(
      title: 'Backyard Cafe',
      address: '11B Street 246',
      icon: CupertinoIcons.heart_fill,
      iconColor: Color(0xFFF97316),
      distanceMetres: 380,
      latitude: 11.5510,
      longitude: 104.9300,
    ),
    PlaceItem(
      title: 'Kravanh Restaurant',
      address: '#112, Sothearos Blvd',
      icon: CupertinoIcons.star_fill,
      iconColor: Color(0xFFEA580C),
      distanceMetres: 510,
      latitude: 11.5535,
      longitude: 104.9318,
    ),
    PlaceItem(
      title: 'Brown Coffee & Bakery',
      address: 'Street 51, BKK1, Phnom Penh',
      icon: CupertinoIcons.drop_fill,
      iconColor: Color(0xFF10B981),
      distanceMetres: 640,
      latitude: 11.5518,
      longitude: 104.9265,
    ),
    PlaceItem(
      title: 'Phnom Penh Riverside Walk',
      address: 'Sisowath Quay, Phnom Penh',
      icon: CupertinoIcons.compass_fill,
      iconColor: Color(0xFF0284C7),
      distanceMetres: 800,
      latitude: 11.5710,
      longitude: 104.9305,
    ),
    PlaceItem(
      title: 'Vattanac Capital Tower',
      address: 'Monivong Blvd, Sangkat Wat Phnom',
      icon: CupertinoIcons.building_2_fill,
      iconColor: Color(0xFF8B5CF6),
      distanceMetres: 1100,
      latitude: 11.5739,
      longitude: 104.9205,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _recenterAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _detectCurrentGpsLocation();
  }

  Future<void> _detectCurrentGpsLocation({bool animateRecenter = false}) async {
    final locService = LocationService.instance;
    await locService.init();

    if (!locService.allowGps) {
      if (mounted) {
        setState(() {
          _gpsAllowed = false;
          _isLocating = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLocating = true;
        _gpsAllowed = true;
      });
    }

    final pos = await locService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _currentLat = pos.latitude;
        _currentLon = pos.longitude;
        _accuracyMeters = pos.accuracy.round() > 0 ? pos.accuracy.round() : 15;
        _isLocating = false;
        if (animateRecenter) {
          _mapOffset = Offset.zero;
        }
      });

      final address = await locService.reverseGeocode(pos.latitude, pos.longitude);
      if (address != null && mounted) {
        setState(() {
          _currentPlaceName = '📍 $address';
        });
      }
    } else if (mounted) {
      setState(() {
        _isLocating = false;
      });
    }
  }

  Future<void> _openPrivacySettings() async {
    await Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => const PrivacySettingsScreen(),
      ),
    );
    _detectCurrentGpsLocation(animateRecenter: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _recenterAnimController.dispose();
    super.dispose();
  }

  void _recenterMap() {
    _recenterAnimation = Tween<Offset>(begin: _mapOffset, end: Offset.zero).animate(
      CurvedAnimation(parent: _recenterAnimController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _mapOffset = _recenterAnimation!.value;
        });
      });
    _recenterAnimController.forward(from: 0.0);
  }

  void _cycleMapStyle() {
    setState(() {
      _mapStyleIndex = (_mapStyleIndex + 1) % 2;
    });
  }

  List<PlaceItem> get _filteredPlaces {
    if (_searchQuery.trim().isEmpty) return _defaultPlaces;
    final q = _searchQuery.toLowerCase().trim();
    return _defaultPlaces.where((p) {
      return p.title.toLowerCase().contains(q) || p.address.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openFullScreenMap() async {
    final picked = await LocationPicker.show(
      context,
      initialLocation: MapLocation(
        latitude: _currentLat,
        longitude: _currentLon,
        name: _currentPlaceName.replaceAll('📍', '').trim(),
      ),
      currentUser: widget.currentUser,
      senderName: widget.currentUser?.displayName,
      senderAvatarUrl: widget.currentUser?.avatarUrl,
      senderUsername: widget.currentUser?.username,
    );
    if (picked != null) {
      widget.onSendLocation(
        picked.displayName,
        '${picked.address ?? ''}\ngeo:${picked.latitude},${picked.longitude}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ThemeController.instance;
    final accent = theme.current;
    final bgPreset = theme.bgPreset;

    final defaultMapStyle = bgPreset.isDark ? CartoMapStyle.dark : CartoMapStyle.voyager;
    final activeMapStyle = _mapStyleIndex == 0
        ? defaultMapStyle
        : (defaultMapStyle == CartoMapStyle.voyager ? CartoMapStyle.dark : CartoMapStyle.voyager);

    return Column(
      children: [
        // Upper Map View
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Real CartoDB Tiles Map Canvas
              CartoDbMapView(
                latitude: _currentLat,
                longitude: _currentLon,
                zoom: 15,
                mapStyle: activeMapStyle,
                showLabels: false,
                isInteractive: true,
                offset: _mapOffset,
                onPanUpdate: (newOffset) {
                  setState(() {
                    _mapOffset = newOffset;
                  });
                },
              ),

              // Center User Location Pin Marker (No shadows)
              Center(
                child: _buildCenterUserMarker(accent),
              ),

              // Map Top Overlay Bar (X, Title / Search input, Search button)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: _buildTopOverlay(bgPreset, accent),
              ),

              // Floating Controls on Right (Fullscreen, Layers, Recenter GPS - No shadows)
              Positioned(
                bottom: 14,
                right: 14,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildFloatingCircleButton(
                      icon: CupertinoIcons.fullscreen,
                      onTap: _openFullScreenMap,
                      bgPreset: bgPreset,
                      accent: accent,
                    ),
                    const SizedBox(height: 10),
                    _buildFloatingCircleButton(
                      icon: CupertinoIcons.map,
                      onTap: _cycleMapStyle,
                      bgPreset: bgPreset,
                      accent: accent,
                    ),
                    const SizedBox(height: 10),
                    _buildFloatingCircleButton(
                      icon: CupertinoIcons.location_fill,
                      onTap: () {
                        _recenterMap();
                        _detectCurrentGpsLocation(animateRecenter: true);
                      },
                      bgPreset: bgPreset,
                      accent: accent,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Lower Places List & Send Action (Matches Theme Background)
        Expanded(
          flex: 6,
          child: Container(
            color: bgPreset.surfaceBg,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Primary Action: "Send My Current Location" (or Privacy GPS notice)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: !_gpsAllowed
                        ? _openPrivacySettings
                        : () {
                            widget.onSendLocation(
                              _currentPlaceName,
                              'Accurate to $_accuracyMeters metres\ngeo:$_currentLat,$_currentLon',
                            );
                          },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: !_gpsAllowed ? bgPreset.inputFill : accent.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Icon(
                                !_gpsAllowed
                                    ? CupertinoIcons.location_slash_fill
                                    : CupertinoIcons.location_solid,
                                color: !_gpsAllowed ? bgPreset.textMuted : Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  !_gpsAllowed
                                      ? 'GPS Disabled in Privacy Settings'
                                      : 'Send My Current Location',
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: bgPreset.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  !_gpsAllowed
                                      ? 'Tap to allow GPS in Security & Privacy'
                                      : (_isLocating
                                          ? 'Detecting precise GPS position...'
                                          : 'Accurate to $_accuracyMeters metres'),
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    color: !_gpsAllowed
                                        ? accent.primary
                                        : bgPreset.textSecondary,
                                    fontWeight: !_gpsAllowed
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Section Header: "OR CHOOSE A PLACE"
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                  child: Text(
                    'OR CHOOSE A PLACE',
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: bgPreset.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),

                // Nearby places list
                ..._filteredPlaces.map((place) => _buildPlaceTile(place, bgPreset)),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopOverlay(AppBackgroundPreset bgPreset, AppThemeColor accent) {
    return Row(
      children: [
        // Close (X) button
        GestureDetector(
          onTap: widget.onClose,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgPreset.surfaceBg.withOpacity(0.90),
              shape: BoxShape.circle,
              border: Border.all(color: bgPreset.border, width: 0.8),
            ),
            child: Center(
              child: Icon(CupertinoIcons.xmark, color: bgPreset.textPrimary, size: 18),
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Center Title or Search Field
        Expanded(
          child: _isSearching
              ? Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: bgPreset.surfaceBg.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: bgPreset.border, width: 0.8),
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    style: GoogleFonts.inter(color: bgPreset.textPrimary, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search nearby places...',
                      hintStyle: GoogleFonts.inter(color: bgPreset.textMuted, fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 9),
                    ),
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                      });
                    },
                  ),
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: bgPreset.surfaceBg.withOpacity(0.90),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: bgPreset.border, width: 0.8),
                    ),
                    child: Text(
                      'Location',
                      style: GoogleFonts.inter(
                        color: bgPreset.textPrimary,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),

        // Search Icon Button
        GestureDetector(
          onTap: () {
            setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) {
                _searchQuery = '';
                _searchController.clear();
              }
            });
          },
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bgPreset.surfaceBg.withOpacity(0.90),
              shape: BoxShape.circle,
              border: Border.all(color: bgPreset.border, width: 0.8),
            ),
            child: Center(
              child: Icon(
                _isSearching ? CupertinoIcons.clear : CupertinoIcons.search,
                color: bgPreset.textPrimary,
                size: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingCircleButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppBackgroundPreset bgPreset,
    required AppThemeColor accent,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: bgPreset.surfaceBg.withOpacity(0.92),
          shape: BoxShape.circle,
          border: Border.all(color: bgPreset.border, width: 1),
        ),
        child: Center(
          child: Icon(icon, color: accent.primary, size: 21),
        ),
      ),
    );
  }

  Widget _buildCenterUserMarker(AppThemeColor accent) {
    final avatarUrl = widget.currentUser?.avatarUrl;
    final username = widget.currentUser?.username ?? 'U';

    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Heading Beam pointing down
        Positioned(
          top: 36,
          child: CustomPaint(
            size: const Size(64, 48),
            painter: _HeadingBeamPainter(beamColor: accent.primary),
          ),
        ),

        // Location Dot (No shadow)
        Positioned(
          top: 38,
          child: Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: accent.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.2),
            ),
          ),
        ),

        // User Avatar Circle (No shadow)
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
          ),
          child: ClipOval(
            child: (avatarUrl != null && avatarUrl.trim().isNotEmpty)
                ? Image.network(
                    ApiClient.resolveAvatarUrl(avatarUrl),
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => _buildFallbackAvatar(username, accent),
                  )
                : _buildFallbackAvatar(username, accent),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar(String username, AppThemeColor accent) {
    return Container(
      color: accent.primary,
      child: Center(
        child: Text(
          username.isNotEmpty ? username[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceTile(PlaceItem place, AppBackgroundPreset bgPreset) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onSendLocation(
            '📍 ${place.title}',
            '${place.address}\ngeo:${place.latitude},${place.longitude}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: place.iconColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(place.icon, color: Colors.white, size: 20),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.title,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: bgPreset.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      place.address,
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: bgPreset.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeadingBeamPainter extends CustomPainter {
  final Color beamColor;

  _HeadingBeamPainter({required this.beamColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          beamColor.withOpacity(0.50),
          beamColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _HeadingBeamPainter oldDelegate) =>
      oldDelegate.beamColor != beamColor;
}

import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:frontend/core/api/api_client.dart';
import 'package:frontend/features/profile/screens/user_profile_screen.dart';
import 'package:frontend/models/user_model.dart';
import '../domain/map_location.dart';
import '../widgets/cartodb_map_engine.dart';
import '../widgets/map_controls.dart';
import '../widgets/map_markers.dart';
import 'map_controller.dart';
import 'map_search.dart';

class MapScreen extends StatefulWidget {
  final MapLocation? initialLocation;
  final UserModel? currentUser;
  final UserModel? partnerUser;
  final String? partnerName;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? senderUsername;
  final DateTime? sharedAt;
  final bool isPickerMode;
  final ValueChanged<MapLocation>? onLocationSelected;

  const MapScreen({
    super.key,
    this.initialLocation,
    this.currentUser,
    this.partnerUser,
    this.partnerName,
    this.senderName,
    this.senderAvatarUrl,
    this.senderUsername,
    this.sharedAt,
    this.isPickerMode = false,
    this.onLocationSelected,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapController _controller;
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    _controller = MapController(
      initialLocation: widget.initialLocation ?? MapLocation.phnomPenh,
    );
    _controller.detectAndCenterGps();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _shareLocation(MapLocation loc) {
    if (widget.onLocationSelected != null) {
      widget.onLocationSelected!(loc);
    }
    Navigator.of(context).pop(loc);
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    final a = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $a';
  }

  @override
  Widget build(BuildContext context) {
    final effectiveName = widget.senderName?.isNotEmpty == true
        ? widget.senderName!
        : (widget.partnerName?.isNotEmpty == true
            ? widget.partnerName!
            : (widget.currentUser?.displayName.isNotEmpty == true
                ? widget.currentUser!.displayName
                : 'Shared Location'));

    final effectiveAvatar = widget.senderAvatarUrl?.isNotEmpty == true
        ? widget.senderAvatarUrl!
        : (widget.currentUser?.avatarUrl ?? '');

    final effectiveUsername = widget.senderUsername?.isNotEmpty == true
        ? widget.senderUsername!
        : (widget.currentUser?.username ?? '');

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final state = _controller.state;
        final selected = state.selectedLocation ?? state.center;
        final isDark = state.mapStyle == MapTileStyle.dark;

        // Build markers
        final markers = <MapMarkerData>[];

        // 1. Current GPS position with profile avatar & pulsing beacon
        if (state.myGpsLocation != null) {
          markers.add(
            MapMarkerData(
              id: 'my_gps',
              location: state.myGpsLocation!,
              anchor: const Offset(0.5, 0.5),
              child: UserGpsMarker(
                avatarUrl: widget.currentUser?.avatarUrl,
                username: widget.currentUser?.username,
              ),
            ),
          );
        }

        // 2. Selected Place Marker (User Profile Avatar Marker matching screenshot!)
        if (effectiveAvatar.isNotEmpty) {
          markers.add(
            MapMarkerData(
              id: 'selected_pin',
              location: selected,
              anchor: const Offset(0.5, 0.9),
              child: UserAvatarMapMarker(
                username: effectiveUsername,
                avatarUrl: effectiveAvatar,
                label: selected.name,
                dotColor: const Color(0xFF6366F1), // Matching screenshot purple dot
                size: 48,
              ),
            ),
          );
        } else {
          markers.add(
            MapMarkerData(
              id: 'selected_pin',
              location: selected,
              anchor: const Offset(0.5, 1.0),
              child: DestinationPinMarker(
                label: selected.name,
                pinColor: const Color(0xFFFF3B30),
              ),
            ),
          );
        }

        // 3. Live sharing marker
        if (state.activeLiveSession != null) {
          markers.add(
            MapMarkerData(
              id: 'live_user',
              location: state.activeLiveSession!.location,
              anchor: const Offset(0.5, 0.9),
              child: UserAvatarMapMarker(
                username: state.activeLiveSession!.username,
                avatarUrl: state.activeLiveSession!.avatarUrl,
                isLive: true,
                size: 48,
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF10141D) : const Color(0xFFF1F5F9),
          body: Stack(
            fit: StackFit.expand,
            children: [
              // 1. High-Performance Reusable CartoDB Map Viewport
              CartoDbMapEngine(
                centerLatitude: state.center.latitude,
                centerLongitude: state.center.longitude,
                zoom: state.zoom,
                mapStyle: state.mapStyle,
                isInteractive: true,
                markers: markers,
                routePolyline: state.activeRoute?.polyline ?? const [],
                polylineColor: const Color(0xFF007AFF),
                polylineWidth: 5.0,
                onTapCoordinate: (loc) {
                  _controller.selectLocation(loc);
                },
                onZoomChanged: (z) {
                  // zoom handled
                },
                onCenterMoved: (loc) {
                  _controller.updateCenter(loc);
                },
              ),

              // 2. Top Floating Search Bar & Back Button
              Positioned(
                top: MediaQuery.of(context).padding.top + 10,
                left: 16,
                right: 16,
                child: MapSearchBar(
                  onBack: () => Navigator.of(context).pop(),
                  onPlaceSelected: (place) {
                    _controller.selectLocation(place);
                  },
                ),
              ),

              // 3. Floating Map Controls (Zoom, Map Style, Recenter GPS, Directions)
              Positioned(
                right: 16,
                bottom: 285,
                child: MapControlsBar(
                  isDarkStyle: isDark,
                  isLocating: state.isLocating,
                  hasDirections: state.activeRoute != null,
                  onZoomIn: _controller.zoomIn,
                  onZoomOut: _controller.zoomOut,
                  onToggleStyle: _controller.toggleMapStyle,
                  onRecenterGps: _controller.detectAndCenterGps,
                  onDirections: state.selectedLocation != null && state.myGpsLocation != null
                      ? () {
                          if (state.activeRoute != null) {
                            _controller.clearRoute();
                          } else {
                            _controller.calculateRoute(
                              origin: state.myGpsLocation!,
                              destination: state.selectedLocation!,
                            );
                          }
                        }
                      : null,
                ),
              ),

              // 4. Bottom Liquid Glass Details & Profile Sheet
              Positioned(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 12,
                child: _buildLocationDetailsCard(
                  context,
                  state,
                  selected,
                  effectiveName,
                  effectiveAvatar,
                  effectiveUsername,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLocationDetailsCard(
    BuildContext context,
    MapViewState state,
    MapLocation selected,
    String effectiveName,
    String effectiveAvatar,
    String effectiveUsername,
  ) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.75),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.18),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Profile Header Row
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.2),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 6,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: effectiveAvatar.isNotEmpty
                          ? Image.network(
                              ApiClient.resolveAvatarUrl(effectiveAvatar),
                              fit: BoxFit.cover,
                              errorBuilder: (ctx, err, stack) =>
                                  _buildFallbackProfileAvatar(effectiveName),
                            )
                          : _buildFallbackProfileAvatar(effectiveName),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                effectiveName,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withOpacity(0.25),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: const Color(0xFF6366F1).withOpacity(0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                'Profile',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFFA5B4FC),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.sharedAt != null
                              ? 'Shared at ${_formatTime(widget.sharedAt)}'
                              : (effectiveUsername.isNotEmpty
                                  ? '@$effectiveUsername'
                                  : 'Location on map'),
                          style: GoogleFonts.outfit(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (widget.partnerUser != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 34,
                      onPressed: () {
                        Navigator.of(context).push(
                          CupertinoPageRoute(
                            builder: (_) => UserProfileScreen(
                              userId: widget.partnerUser!.id,
                              initialUser: widget.partnerUser,
                              currentUser: widget.currentUser ?? widget.partnerUser!,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          CupertinoIcons.person_fill,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 12),
              Divider(color: Colors.white.withOpacity(0.12), height: 1),
              const SizedBox(height: 10),

              // 2. Title and Resolved Address
              Text(
                selected.displayName,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              Text(
                selected.address ?? selected.coordinateString,
                style: GoogleFonts.outfit(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              // 3. Route Preview Info (if route calculated)
              if (state.activeRoute != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                CupertinoIcons.car_detailed,
                                color: Color(0xFF34C759),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${state.activeRoute!.formattedDistance} • ${state.activeRoute!.formattedDuration}',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (state.activeRoute!.steps.isNotEmpty)
                            CupertinoButton(
                              padding: EdgeInsets.zero,
                              minSize: 24,
                              onPressed: () {
                                setState(() => _showSteps = !_showSteps);
                              },
                              child: Text(
                                _showSteps ? 'Hide steps' : 'View steps',
                                style: GoogleFonts.outfit(
                                  color: const Color(0xFF007AFF),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (_showSteps && state.activeRoute!.steps.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Divider(color: Colors.white.withOpacity(0.1)),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 120),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: state.activeRoute!.steps.length,
                            itemBuilder: (context, idx) {
                              final st = state.activeRoute!.steps[idx];
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Text(
                                      '${idx + 1}.',
                                      style: GoogleFonts.outfit(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        st.instruction,
                                        style: GoogleFonts.outfit(
                                          color: Colors.white,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      st.formattedDistance,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white60,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 14),

              // 4. Action Buttons
              Row(
                children: [
                  // Directions Button
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: state.myGpsLocation == null
                          ? () => _controller.detectAndCenterGps()
                          : () {
                              if (state.activeRoute != null) {
                                _controller.clearRoute();
                              } else {
                                _controller.calculateRoute(
                                  origin: state.myGpsLocation!,
                                  destination: selected,
                                );
                              }
                            },
                      child: state.isRouting
                          ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  state.activeRoute != null
                                      ? CupertinoIcons.clear
                                      : CupertinoIcons.arrow_turn_up_right,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  state.activeRoute != null ? 'Clear Route' : 'Directions',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Share Location Button
                  Expanded(
                    child: CupertinoButton(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      color: const Color(0xFF007AFF),
                      borderRadius: BorderRadius.circular(16),
                      onPressed: () => _shareLocation(selected),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            CupertinoIcons.paperplane_fill,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Share Location',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackProfileAvatar(String name) {
    return Container(
      color: const Color(0xFF6366F1),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

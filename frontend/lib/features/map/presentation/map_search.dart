import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../data/map_repository.dart';
import '../domain/map_location.dart';

/// Floating glass search bar for place finding & geocoding
class MapSearchBar extends StatefulWidget {
  final ValueChanged<MapLocation> onPlaceSelected;
  final VoidCallback? onBack;

  const MapSearchBar({
    super.key,
    required this.onPlaceSelected,
    this.onBack,
  });

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounceTimer;

  bool _isSearching = false;
  List<MapLocation> _searchResults = [];
  bool _isDropdownOpen = false;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged(String query) {
    _debounceTimer?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isDropdownOpen = false;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _isDropdownOpen = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 350), () async {
      final results = await MapRepository.instance.searchPlaces(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    });
  }

  void _selectPlace(MapLocation place) {
    _focusNode.unfocus();
    _controller.text = place.displayName;
    setState(() {
      _isDropdownOpen = false;
    });
    widget.onPlaceSelected(place);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top Search Bar
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.onBack != null)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 36,
                      onPressed: widget.onBack,
                      child: const Icon(
                        CupertinoIcons.back,
                        color: Colors.white,
                        size: 22,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(left: 4, right: 6),
                      child: Icon(
                        CupertinoIcons.search,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 15,
                      ),
                      cursorColor: const Color(0xFF007AFF),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 6,
                        ),
                        hintText: 'Search places, streets, addresses...',
                        hintStyle: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                      ),
                      onChanged: _onQueryChanged,
                      onSubmitted: (_) {
                        if (_searchResults.isNotEmpty) {
                          _selectPlace(_searchResults.first);
                        }
                      },
                    ),
                  ),
                  if (_isSearching)
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: CupertinoActivityIndicator(
                        color: Colors.white70,
                        radius: 8,
                      ),
                    )
                  else if (_controller.text.isNotEmpty)
                    CupertinoButton(
                      padding: EdgeInsets.zero,
                      minSize: 32,
                      onPressed: () {
                        _controller.clear();
                        _onQueryChanged('');
                      },
                      child: const Icon(
                        CupertinoIcons.clear_circled_solid,
                        color: Colors.white54,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),

        // Dropdown Suggestions
        if (_isDropdownOpen && _searchResults.isNotEmpty) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.18),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: _searchResults.length,
                  separatorBuilder: (context, index) => Divider(
                    height: 1,
                    color: Colors.white.withOpacity(0.1),
                  ),
                  itemBuilder: (context, index) {
                    final place = _searchResults[index];
                    return InkWell(
                      onTap: () => _selectPlace(place),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF007AFF).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                CupertinoIcons.location_fill,
                                color: Color(0xFF007AFF),
                                size: 16,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    place.displayName,
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (place.address != null &&
                                      place.address != place.displayName) ...[
                                    const SizedBox(height: 2),
                                    Text(
                                      place.address!,
                                      style: GoogleFonts.outfit(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

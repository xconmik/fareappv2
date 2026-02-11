import 'dart:ui';

import 'package:flutter/material.dart';

import 'category_with_places.dart';
import '../services/ride_matching_service.dart';
import '../services/google_places_service.dart';
import '../config/app_config.dart';
import 'ride_status_screen.dart';
import '../theme/responsive.dart';

class LocationSearchScreen extends StatelessWidget {
  const LocationSearchScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const CategoryWithPlacesScreen();
  }
}

class LocationSearchSheet extends StatefulWidget {
  const LocationSearchSheet({Key? key, this.controller}) : super(key: key);

  final ScrollController? controller;

  @override
  State<LocationSearchSheet> createState() => _LocationSearchSheetState();
}

class _LocationSearchSheetState extends State<LocationSearchSheet> {
  late TextEditingController _searchController;
  late GooglePlacesService _placesService;
  List<PlacePrediction> _autocompleteResults = [];
  bool _showAutocomplete = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _initPlacesService();
  }

  void _initPlacesService() async {
    try {
      final apiKey = await AppConfig.getGoogleMapsApiKey();
      _placesService = GooglePlacesService(apiKey: apiKey);
    } catch (e) {
      print('Error initializing Places service: $e');
      _placesService = GooglePlacesService(apiKey: 'AIzaSyD7eRiM0iLc8DJt3DqdjMhiI8A6BmzBQyY');
    }
  }

  Future<void> _handleSearchChanged(String value) async {
    final query = value.trim();
    setState(() {
      if (query.isEmpty) {
        _showAutocomplete = false;
        _autocompleteResults = [];
        return;
      }
      _showAutocomplete = true;
    });

    if (query.isNotEmpty) {
      try {
        final results = await _placesService.getAutocompletePredictions(
          input: query,
          latitude: null,
          longitude: null,
        );
        if (mounted) {
          setState(() {
            _autocompleteResults = results;
          });
        }
      } catch (e) {
        print('Error searching places: $e');
      }
    }
  }

  Future<void> _handleSearchResultTap(PlacePrediction result) async {
    try {
      // Get place details to get coordinates
      final details = await _placesService.getPlaceDetails(
        placeId: result.placeId,
      );

      if (details != null && mounted) {
        // Pass the location back to home screen and close search sheet
        Navigator.pop(context, details);
      }
    } catch (e) {
      print('Error getting place details: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      top: false,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(
          0,
          r.space(24),
          0,
          0,
        ),
        child: Column(
          children: [
            Container(
              width: r.space(36),
              height: r.space(4),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            SizedBox(height: r.space(12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(r.radius(16)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(8)),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(r.radius(16)),
                    border: Border.all(color: Colors.white.withOpacity(0.16)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.white70, size: r.icon(18)),
                      SizedBox(width: r.space(8)),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _handleSearchChanged,
                          style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                          decoration: InputDecoration(
                            hintText: 'Search destination',
                            hintStyle: TextStyle(color: Colors.white54, fontSize: r.font(12)),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white70, size: r.icon(18)),
                        onPressed: () {
                          _searchController.clear();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: r.space(14)),
            if (_showAutocomplete && _autocompleteResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  controller: widget.controller,
                  itemCount: _autocompleteResults.length,
                  itemBuilder: (context, index) {
                    final result = _autocompleteResults[index];
                    return ListTile(
                      title: Text(
                        result.mainText,
                        style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
                      ),
                      subtitle: result.secondaryText != null
                          ? Text(
                              result.secondaryText!,
                              style: TextStyle(color: Colors.white38, fontSize: r.font(10)),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => _handleSearchResultTap(result),
                    );
                  },
                ),
              )
            else if (!_showAutocomplete)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Recents',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: r.font(12)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

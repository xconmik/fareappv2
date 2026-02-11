import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/category_place_models.dart';
import '../services/ride_matching_service.dart';
import '../services/google_places_service.dart';
import '../config/app_config.dart';
import 'ride_status_screen.dart';
import 'booking_details_screen.dart';
import '../theme/responsive.dart';

class CategoryWithPlacesScreen extends StatefulWidget {
  const CategoryWithPlacesScreen({
    Key? key,
    this.initialCategoryIndex = 0,
    this.categories,
  }) : super(key: key);

  final int initialCategoryIndex;
  final List<CategoryModel>? categories;

  @override
  State<CategoryWithPlacesScreen> createState() => _CategoryWithPlacesScreenState();
}

class _CategoryWithPlacesScreenState extends State<CategoryWithPlacesScreen> {
  int _activeCategoryIndex = 0;
  late final List<CategoryModel> _categories;
  GoogleMapController? _mapController;
  bool _hasLocationPermission = false;
  bool _mapFailed = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _query = '';
  bool _mapReady = false;
  Set<Marker> _pendingFitMarkers = const {};
  late GooglePlacesService _placesService;
  List<PlacePrediction> _autocompleteResults = [];
  List<PlaceModel> _recentSearches = [];
  List<PlaceModel> _dynamicPlaces = [];
  bool _showAutocomplete = false;
  bool _searchFocused = false;
  bool _loadingPlaces = false;
  Position? _userLocation;
  
  // Category to search keyword mapping
  static const Map<String, String> categoryKeywords = {
    'Food': 'restaurant',
    'School': 'school',
    'Mall': 'shopping mall',
    'Cafe': 'cafe',
    'Mart': 'convenience store',
    'Hospital': 'hospital',
    'Park': 'park',
    'Office': 'office building',
    'Airport': 'airport',
    'Hotel': 'hotel',
    'Gym': 'gym fitness center',
    'Cinema': 'cinema movie theater',
  };
  static const bool _useMapId = false;
  static const String _cloudMapId = '5c554f4f892ef6db87f0d2c1';
  static const String _mapStyle = '''[
  {
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#1f1f23"
      }
    ]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#8e8e93"
      }
    ]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [
      {
        "visibility": "off"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#2b2b30"
      }
    ]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [
      {
        "color": "#27272b"
      }
    ]
  },
  {
    "featureType": "road.highway",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#d0a92b"
      }
    ]
  },
  {
    "featureType": "transit",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#3a3a3e"
      }
    ]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [
      {
        "color": "#0f1114"
      }
    ]
  },
  {
    "featureType": "poi",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#2c2c2f"
      }
    ]
  },
  {
    "featureType": "poi.business",
    "elementType": "labels.text.fill",
    "stylers": [
      {
        "color": "#e1c46a"
      }
    ]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry.fill",
    "stylers": [
      {
        "color": "#1f2428"
      }
    ]
  }
]''';

  Future<void> _handlePlaceSelected(PlaceModel place) async {
    _addToRecents(place);
    
    // Show the place on map immediately
    final marker = Marker(
      markerId: const MarkerId('selected_place'),
      position: _placeLatLng(place, 0),
      infoWindow: InfoWindow(
        title: place.title,
        snippet: place.subtitle,
      ),
    );
    
    final markers = {marker};
    await _fitMarkers(markers);
    
    // Give user time to see the location on map
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (!mounted) {
      return;
    }
    
    // Extract distance as km
    final distanceText = place.distance != null 
      ? double.tryParse(place.distance!.replaceAll(' km', '')) 
      : null;
    
    final requestId = await RideMatchingService().createRideRequest(
      pickupName: 'Current Location',
      destinationName: place.title,
      pickupLat: _userLocation?.latitude,
      pickupLng: _userLocation?.longitude,
      destinationLat: place.latitude,
      destinationLng: place.longitude,
      distanceKm: distanceText,
      destinationStatus: place.status,
    );
    if (!mounted) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailsScreen(requestId: requestId)),
    );
  }

  Future<void> _fetchNearbyPlaces(String categoryLabel) async {
    print('[Category] _fetchNearbyPlaces called for category: $categoryLabel');
    
    if (_userLocation == null) {
      print('[Category] User location is null, waiting for location...');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Getting your location...')),
      );
      return;
    }

    print('[Category] User location: ${_userLocation!.latitude}, ${_userLocation!.longitude}');

    setState(() {
      _loadingPlaces = true;
      _dynamicPlaces = [];
    });

    try {
      final keyword = categoryKeywords[categoryLabel] ?? categoryLabel.toLowerCase();
      print('[Category] Using keyword: $keyword for category: $categoryLabel');
      
      final results = await _placesService.searchNearbyPlaces(
        latitude: _userLocation!.latitude,
        longitude: _userLocation!.longitude,
        keyword: keyword,
        radius: 15000,
      );

      print('[Category] API returned ${results.length} places');

      if (mounted) {
        setState(() {
          _dynamicPlaces = results
              .map((r) => PlaceModel(
                    title: r.name,
                    subtitle: r.address ?? '',
                    status: r.openNow ? 'Open' : null,
                    distance: r.rating != null ? '★ ${r.rating!.toStringAsFixed(1)}' : '',
                    latitude: r.latitude,
                    longitude: r.longitude,
                  ))
              .toList();
          _loadingPlaces = false;
        });

        print('[Category] State updated with ${_dynamicPlaces.length} places');

        // Update markers on map
        if (_dynamicPlaces.isNotEmpty) {
          final markers = _buildMarkers(_dynamicPlaces);
          _fitMarkers(markers);
        }
      }
    } catch (e) {
      print('[Category] ERROR fetching nearby places: $e');
      if (mounted) {
        setState(() {
          _loadingPlaces = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load places: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    // Load only categories, not places (will be fetched dynamically)
    _categories = widget.categories ?? _loadCategoriesOnly();
    if (_categories.isNotEmpty) {
      _activeCategoryIndex = widget.initialCategoryIndex.clamp(0, _categories.length - 1);
    }
    _initPlacesService();
    _initLocation(); // This will also fetch places once location is available
    _searchFocusNode.addListener(_handleSearchFocus);
  }

  List<CategoryModel> _loadCategoriesOnly() {
    // Return only categories without any places
    const categories = [
      {'icon': 'food', 'label': 'Food', 'places': []},
      {'icon': 'school', 'label': 'School', 'places': []},
      {'icon': 'mall', 'label': 'Mall', 'places': []},
      {'icon': 'cafe', 'label': 'Cafe', 'places': []},
      {'icon': 'mart', 'label': 'Mart', 'places': []},
      {'icon': 'hospital', 'label': 'Hospital', 'places': []},
      {'icon': 'park', 'label': 'Park', 'places': []},
      {'icon': 'office', 'label': 'Office', 'places': []},
      {'icon': 'airport', 'label': 'Airport', 'places': []},
      {'icon': 'hotel', 'label': 'Hotel', 'places': []},
      {'icon': 'gym', 'label': 'Gym', 'places': []},
      {'icon': 'cinema', 'label': 'Cinema', 'places': []},
    ];
    return categories.map((c) => CategoryModel(
      label: c['label'] as String,
      iconKey: c['icon'] as String,
      places: const [],
    )).toList();
  }

  void _handleSearchFocus() {
    setState(() {
      _searchFocused = _searchFocusNode.hasFocus;
      if (_searchFocused) {
        _showAutocomplete = true;
      } else {
        _showAutocomplete = false;
      }
    });
  }

  void _initPlacesService() async {
    try {
      final apiKey = await AppConfig.getGoogleMapsApiKey();
      _placesService = GooglePlacesService(apiKey: apiKey);
    } catch (e) {
      print('Error initializing Places service: $e');
      // Fallback to unrestricted hardcoded key
      _placesService = GooglePlacesService(apiKey: 'AIzaSyD7eRiM0iLc8DJt3DqdjMhiI8A6BmzBQyY');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  void _handleSearchChanged(String value) async {
    setState(() {
      _query = value.trim();
      // Keep showing if focused or if there's text
      if (_searchFocused || _query.isNotEmpty) {
        _showAutocomplete = true;
      } else {
        _showAutocomplete = false;
      }
    });

    if (_query.isEmpty) {
      setState(() {
        _autocompleteResults = [];
      });
      // Show all real places in current category
      final markers = _buildMarkers(_dynamicPlaces);
      _fitMarkers(markers);
      return;
    }

    // Show loading indicator while fetching
    if (mounted) {
      setState(() {
        _loadingPlaces = true;
      });
    }

    // Fetch autocomplete predictions from Google Places API
    try {
      final predictions = await _placesService.getAutocompletePredictions(
        input: _query,
        latitude: _userLocation?.latitude,
        longitude: _userLocation?.longitude,
      );
      
      if (mounted) {
        setState(() {
          _autocompleteResults = predictions;
          _loadingPlaces = false;
        });
      }
    } catch (e) {
      print('Error fetching autocomplete: $e');
      if (mounted) {
        setState(() {
          _loadingPlaces = false;
          _autocompleteResults = [];
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error searching: $e')),
        );
      }
    }
  }

  void _addToRecents(PlaceModel place) {
    setState(() {
      _recentSearches.removeWhere((p) => p.title == place.title);
      _recentSearches.insert(0, place);
      if (_recentSearches.length > 5) {
        _recentSearches = _recentSearches.sublist(0, 5);
      }
    });
  }

  Future<void> _handlePlacePredictionSelected(PlacePrediction prediction) async {
    try {
      // Get place details from Google Places API
      final details = await _placesService.getPlaceDetails(placeId: prediction.placeId);
      
      if (details != null && details.latitude != null && details.longitude != null) {
        final place = PlaceModel(
          title: details.name ?? prediction.mainText,
          subtitle: prediction.secondaryText,
          status: null,
          distance: 'Via Maps',
          latitude: details.latitude,
          longitude: details.longitude,
        );
        
        setState(() {
          _searchController.text = place.title;
          _query = place.title;
          _autocompleteResults = [];
          _showAutocomplete = false;
        });
        
        // Unfocus the search field to hide keyboard
        _searchFocusNode.unfocus();
        
        // Create marker for selected place and animate to it
        final marker = Marker(
          markerId: const MarkerId('selected_place'),
          position: LatLng(details.latitude!, details.longitude!),
          infoWindow: InfoWindow(
            title: place.title,
            snippet: place.subtitle,
          ),
        );
        
        final markers = {marker};
        _fitMarkers(markers);
        
        // Show the place details
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          _handlePlaceSelected(place);
        }
      }
    } catch (e) {
      print('Error selecting place: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load place details: $e')),
      );
    }
  }

  List<PlaceModel> _filterPlaces(List<CategoryModel> categories, String query) {
    if (query.isEmpty) {
      return categories[_activeCategoryIndex].places;
    }

    final lower = query.toLowerCase();
    return categories
        .expand((category) => category.places)
        .where((place) => place.title.toLowerCase().contains(lower) || place.subtitle.toLowerCase().contains(lower))
        .toList();
  }

  LatLng _placeLatLng(PlaceModel place, int index) {
    // Use real coordinates if available from API
    if (place.latitude != null && place.longitude != null) {
      return LatLng(place.latitude!, place.longitude!);
    }
    
    // Fall back to mock coordinates based on place name hash
    const baseLat = 12.8797;
    const baseLng = 121.7740;
    final hash = place.title.codeUnits.fold<int>(0, (sum, code) => sum + code);
    final latOffset = ((hash % 80) - 40) / 10000.0;
    final lngOffset = (((hash ~/ 3) % 80) - 40) / 10000.0;
    final nudge = index * 0.0003;
    return LatLng(baseLat + latOffset + nudge, baseLng + lngOffset - nudge);
  }

  Set<Marker> _buildMarkers(List<PlaceModel> places) {
    return {
      for (var i = 0; i < places.length; i++)
        Marker(
          markerId: MarkerId('${places[i].title}-$i'),
          position: _placeLatLng(places[i], i),
          infoWindow: InfoWindow(title: places[i].title, snippet: places[i].subtitle),
        ),
    };
  }

  Future<void> _fitMarkers(Set<Marker> markers) async {
    if (markers.isEmpty) {
      return;
    }

    if (!_mapReady || _mapController == null) {
      _pendingFitMarkers = markers;
      return;
    }

    var minLat = markers.first.position.latitude;
    var maxLat = markers.first.position.latitude;
    var minLng = markers.first.position.longitude;
    var maxLng = markers.first.position.longitude;

    for (final marker in markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 60),
      );
    } catch (_) {
      // Ignore camera errors while map is still rendering.
    }
  }

  Future<void> _initLocation() async {
    try {
      print('Starting location initialization...');
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      print('Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        print('Location service not enabled, opening settings...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        await Geolocator.openLocationSettings();
        return;
      }

      var permission = await Geolocator.checkPermission();
      print('Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        print('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        print('Permission after request: $permission');
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        print('Location permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied. Using default location.')),
          );
        }
        // Use default location (Cabanatuan City)
        _useDefaultLocation();
        return;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _hasLocationPermission = true;
      });

      print('Permission granted, getting position...');
      await _centerOnUser();
    } catch (e) {
      print('Error in _initLocation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
      // Use default location on error
      _useDefaultLocation();
    }
  }

  void _useDefaultLocation() {
    // Default location: Cabanatuan City, Philippines
    _userLocation = Position(
      latitude: 12.8797,
      longitude: 121.7740,
      timestamp: DateTime.now(),
      accuracy: 100,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

    if (mounted) {
      setState(() {
        _hasLocationPermission = true;
      });
      
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          const LatLng(12.8797, 121.7740),
          15.5,
        ),
      );

      // Fetch places for the first category with default location
      if (_categories.isNotEmpty) {
        _fetchNearbyPlaces(_categories[_activeCategoryIndex].label);
      }
    }
  }

  Future<void> _centerOnUser() async {
    try {
      print('Getting current position with timeout...');
      
      final position = await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
        forceAndroidLocationManager: false,
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Location request timed out, using default');
          _useDefaultLocation();
          throw TimeoutException('Location request timed out');
        },
      );

      print('Got position: ${position.latitude}, ${position.longitude}');
      _userLocation = position;
      
      if (_mapController != null) {
        await _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(position.latitude, position.longitude),
            15.5,
          ),
        );
      }
      
      // Fetch places for the first category now that we have location
      if (_categories.isNotEmpty && mounted) {
        await _fetchNearbyPlaces(_categories[_activeCategoryIndex].label);
      }
    } on TimeoutException {
      print('Timeout getting location');
      // Already handled in timeout callback
    } catch (e) {
      print('Error getting user location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e. Using default location.')),
        );
      }
      // Use default location on error
      _useDefaultLocation();
    }
  }

  Future<void> _scheduleMapHealthCheck() async {
    await Future.delayed(const Duration(milliseconds: 900));
    try {
      await _mapController?.getVisibleRegion();
      await _mapController?.getZoomLevel();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _mapFailed = true;
      });
    }
  }

  Widget _buildLiveMap(Set<Marker> markers) {
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(12.8797, 121.7740),
        zoom: 15.0,
      ),
      markers: markers,
      cloudMapId: _useMapId ? _cloudMapId : null,
      onMapCreated: (controller) {
        _mapController = controller;
        _mapReady = true;
        if (!_useMapId) {
          _mapController?.setMapStyle(_mapStyle);
        }
        _scheduleMapHealthCheck();
        if (_hasLocationPermission) {
          _centerOnUser();
        }
        if (_pendingFitMarkers.isNotEmpty) {
          _fitMarkers(_pendingFitMarkers);
          _pendingFitMarkers = const {};
        }
      },
      zoomControlsEnabled: false,
      myLocationButtonEnabled: true,
      myLocationEnabled: _hasLocationPermission,
      mapType: MapType.normal,
    );
  }

  Widget _buildMapPlaceholder() {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    final scale = (width / 375).clamp(0.85, 1.2);
    final grid = 8.0 * scale;
    final topCircle = width * 0.45;
    final bottomCircle = width * 0.55;

    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF1B1B1B),
                Color(0xFF111111),
                Color(0xFF202020),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
        ),
        Positioned(
          top: -grid * 5,
          right: -grid * 4,
          child: Container(
            width: topCircle,
            height: topCircle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -grid * 7.5,
          left: -grid * 5,
          child: Container(
            width: bottomCircle,
            height: bottomCircle,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          top: height * 0.15,
          left: grid * 2,
          right: grid * 2,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: grid * 1.75, vertical: grid * 1.25),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(grid * 1.75),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: [
                Icon(Icons.map, color: Colors.white54, size: grid * 2.25),
                SizedBox(width: grid * 1.25),
                Expanded(
                  child: Text(
                    'Map preview disabled (quota off)',
                    style: TextStyle(color: Colors.white54, fontSize: grid * 1.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final width = r.width;
    final chipBase = width < 360 ? 64.0 : 72.0;
    final chipSize = chipBase * r.scale;
    if (_categories.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF0E0E0E),
        body: SafeArea(
          child: Center(
            child: Text('No categories available.', style: TextStyle(color: Colors.white54)),
          ),
        ),
      );
    }

    final activeCategory = _categories[_activeCategoryIndex];
    // Always use real dynamic places (never fallback to mock)
    final places = _query.isEmpty
        ? _dynamicPlaces
        : _dynamicPlaces
            .where((place) {
              final lower = _query.toLowerCase();
              return place.title.toLowerCase().contains(lower) || 
                     place.subtitle.toLowerCase().contains(lower);
            })
            .toList();
    
    final markers = _buildMarkers(places);
    _pendingFitMarkers = markers;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildLiveMap(markers),
          if (_mapFailed) Positioned.fill(child: _buildMapPlaceholder()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, r.space(320), 0, 0),
              child: Column(
                children: [
                  Container(
                    width: r.space(32),
                    height: r.space(2),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  SizedBox(height: r.space(12)),
                  // Search field with autocomplete
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.space(16)),
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(r.radius(16)),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: r.space(10), vertical: r.space(6)),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(r.radius(16)),
                                border: Border.all(color: Colors.white.withOpacity(0.16)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.location_on, color: Colors.white70, size: r.icon(16)),
                                  SizedBox(width: r.space(6)),
                                  Expanded(
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      onChanged: _handleSearchChanged,
                                      style: TextStyle(color: Colors.white, fontSize: r.font(11), fontWeight: FontWeight.w600),
                                      decoration: InputDecoration(
                                        hintText: 'Search destination',
                                        hintStyle: TextStyle(color: Colors.white54, fontSize: r.font(11)),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.close, color: Colors.white70, size: r.icon(16)),
                                    onPressed: () => Navigator.maybePop(context),
                                    padding: EdgeInsets.zero,
                                    constraints: BoxConstraints(minWidth: r.space(32), minHeight: r.space(32)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Autocomplete/Recents dropdown
                        if (_showAutocomplete)
                          Padding(
                            padding: EdgeInsets.only(top: r.space(8)),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1F1F1F),
                                  borderRadius: BorderRadius.circular(r.radius(12)),
                                  border: Border.all(color: Colors.white10),
                                ),
                                constraints: BoxConstraints(maxHeight: r.space(280)),
                                child: _loadingPlaces && _query.isNotEmpty
                                    ? Center(
                                        child: Padding(
                                          padding: EdgeInsets.all(r.space(16)),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              CircularProgressIndicator(color: const Color(0xFFE2C26D)),
                                              SizedBox(height: r.space(8)),
                                              Text(
                                                'Searching...',
                                                style: TextStyle(color: Colors.white54, fontSize: r.font(12)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : (_query.isEmpty && _recentSearches.isEmpty)
                                        ? Padding(
                                            padding: EdgeInsets.all(r.space(16)),
                                            child: Text(
                                              'No recent searches',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: r.font(12),
                                              ),
                                            ),
                                          )
                                        : (_query.isNotEmpty && _autocompleteResults.isEmpty)
                                            ? Padding(
                                                padding: EdgeInsets.all(r.space(16)),
                                                child: Text(
                                                  'No results found for "$_query"',
                                                  style: TextStyle(
                                                    color: Colors.white54,
                                                    fontSize: r.font(12),
                                                  ),
                                                ),
                                              )
                                            : ListView.builder(
                                                shrinkWrap: true,
                                                itemCount: _query.isEmpty ? _recentSearches.length : _autocompleteResults.length,
                                        itemBuilder: (context, index) {
                                          if (_query.isEmpty) {
                                            // Show recent searches
                                            final place = _recentSearches[index];
                                            return InkWell(
                                              onTap: () {
                                                setState(() {
                                                  _showAutocomplete = false;
                                                  _searchController.text = place.title;
                                                  _query = place.title;
                                                });
                                                _handlePlaceSelected(place);
                                              },
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(12)),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.history, color: Colors.white54, size: r.icon(16)),
                                                    SizedBox(width: r.space(8)),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            place.title,
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontSize: r.font(12),
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                          if (place.subtitle.isNotEmpty) ...[
                                                            SizedBox(height: r.space(4)),
                                                            Text(
                                                              place.subtitle,
                                                              style: TextStyle(
                                                                color: Colors.white54,
                                                                fontSize: r.font(10),
                                                              ),
                                                            ),
                                                          ],
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          } else {
                                            // Show autocomplete predictions
                                            final prediction = _autocompleteResults[index];
                                            return InkWell(
                                              onTap: () => _handlePlacePredictionSelected(prediction),
                                              child: Padding(
                                                padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(12)),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      prediction.mainText,
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontSize: r.font(12),
                                                        fontWeight: FontWeight.w600,
                                                      ),
                                                    ),
                                                    if (prediction.secondaryText.isNotEmpty) ...[
                                                      SizedBox(height: r.space(4)),
                                                      Text(
                                                        prediction.secondaryText,
                                                        style: TextStyle(
                                                          color: Colors.white54,
                                                          fontSize: r.font(10),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                        },
                                      ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: r.space(16)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: r.space(16)),
                          child: SizedBox(
                            height: chipSize + r.space(4),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: List.generate(
                                  _categories.length,
                                  (index) {
                                    final isActive = index == _activeCategoryIndex;
                                    final item = _categories[index];

                                    return Padding(
                                      padding: EdgeInsets.only(right: r.space(10)),
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _activeCategoryIndex = index;
                                            _showAutocomplete = false;
                                            _autocompleteResults = [];
                                            _searchController.clear();
                                            _query = '';
                                          });
                                          _fetchNearbyPlaces(item.label);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 250),
                                          width: chipSize,
                                          height: chipSize,
                                          decoration: BoxDecoration(
                                            color: isActive ? const Color(0xFFE2C26D) : const Color(0xFF1F1F1F),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isActive ? const Color(0xFFF6D98F) : Colors.white10,
                                              width: r.space(1.2),
                                            ),
                                            boxShadow: isActive
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(0xFFE2C26D).withOpacity(0.35),
                                                      blurRadius: 16,
                                                      offset: const Offset(0, 6),
                                                    ),
                                                  ]
                                                : [],
                                          ),
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                item.icon,
                                                color: isActive ? Colors.black : Colors.white70,
                                                size: r.icon(20),
                                              ),
                                              SizedBox(height: r.space(6)),
                                              Text(
                                                item.label,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  color: isActive ? Colors.black : Colors.white70,
                                                  fontSize: r.font(10),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: r.space(12)),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 350),
                            switchInCurve: Curves.easeOut,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              final offsetAnimation = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
                                  .animate(animation);
                              return FadeTransition(
                                opacity: animation,
                                child: SlideTransition(position: offsetAnimation, child: child),
                              );
                            },
                            child: Container(
                              key: ValueKey(_activeCategoryIndex),
                              padding: EdgeInsets.only(
                                left: r.space(16),
                                right: r.space(16),
                                top: r.space(2),
                                bottom: 0,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF161616),
                                borderRadius: BorderRadius.only(
                                  topLeft: Radius.circular(r.radius(18)),
                                  topRight: Radius.circular(r.radius(18)),
                                ),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: _loadingPlaces
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircularProgressIndicator(color: const Color(0xFFE2C26D)),
                                          SizedBox(height: r.space(12)),
                                          Text(
                                            'Finding places nearby...',
                                            style: TextStyle(color: Colors.white54, fontSize: r.font(12)),
                                          ),
                                        ],
                                      ),
                                    )
                                  : places.isEmpty
                                      ? Center(
                                          child: Text(
                                            _query.isEmpty 
                                              ? 'No places found. Make sure location is enabled.'
                                              : 'No results found for "$_query".',
                                            style: TextStyle(color: Colors.white54, fontSize: r.font(12)),
                                            textAlign: TextAlign.center,
                                          ),
                                        )
                                      : ListView.separated(
                                          itemCount: places.length + 1,
                                          separatorBuilder: (_, __) => SizedBox(height: r.space(10)),
                                          itemBuilder: (context, index) {
                                            if (index == places.length) {
                                              return TextButton(
                                                style: TextButton.styleFrom(
                                                  foregroundColor: Colors.white70,
                                                  padding: EdgeInsets.symmetric(vertical: r.space(10)),
                                                ),
                                                onPressed: () => Navigator.pushNamed(context, '/location_map_selection'),
                                                child: Text('Choose on map', style: TextStyle(fontSize: r.font(12))),
                                              );
                                            }

                                            final place = places[index];
                                            return _PlaceTile(
                                              title: place.title,
                                              subtitle: place.subtitle,
                                              distance: place.distance,
                                              status: place.status,
                                              onTap: () => _handlePlaceSelected(place),
                                            );
                                          },
                                        ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? status;
  final String distance;
  final VoidCallback? onTap;

  const _PlaceTile({
    required this.title,
    required this.subtitle,
    required this.status,
    required this.distance,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isOpen = status == 'Open';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 0),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFE2C26D), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                      if (status != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          status!,
                          style: TextStyle(
                            color: isOpen ? const Color(0xFFE2C26D) : Colors.white38,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Text(distance, style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}


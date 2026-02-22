import 'dart:ui';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

import '../models/category_place_models.dart';
import '../services/ride_matching_service.dart';
import '../services/google_places_service.dart';
import '../config/app_config.dart';
import 'booking_details_screen.dart';
import '../theme/motion_presets.dart';
import '../theme/responsive.dart';

class CategoryWithPlacesScreen extends StatefulWidget {
  const CategoryWithPlacesScreen({
    super.key,
    this.initialCategoryIndex = 0,
    this.categories,
    this.placesOnly = false,
    this.placesScrollController,
    this.externalSearchQuery,
    this.externalSearchSubmitRequestId = 0,
    this.onBookingVisibilityChanged,
    this.embeddedMapCenterProvider,
    this.onEmbeddedAdjustingChanged,
    this.onEmbeddedAdjustTargetChanged,
    this.onEmbeddedPickupPointChanged,
    this.onEmbeddedDestinationPointChanged,
    this.onEmbeddedAdjustPickupModeChanged,
  });

  final int initialCategoryIndex;
  final List<CategoryModel>? categories;
  final bool placesOnly;
  final ScrollController? placesScrollController;
  final String? externalSearchQuery;
  final int externalSearchSubmitRequestId;
  final ValueChanged<bool>? onBookingVisibilityChanged;
  final Future<LatLng?> Function()? embeddedMapCenterProvider;
  final ValueChanged<bool>? onEmbeddedAdjustingChanged;
  final ValueChanged<LatLng>? onEmbeddedAdjustTargetChanged;
  final ValueChanged<LatLng?>? onEmbeddedPickupPointChanged;
  final ValueChanged<LatLng?>? onEmbeddedDestinationPointChanged;
  final ValueChanged<bool?>? onEmbeddedAdjustPickupModeChanged;

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
  final Map<String, List<PlaceModel>> _nearbyPlacesCache = {};
  final Map<String, DateTime> _nearbyPlacesCacheTime = {};
  final Set<String> _nearbyPrefetchInFlight = <String>{};
  Timer? _searchDebounce;
  Timer? _prefetchDebounce;
  int _nearbyFetchToken = 0;
  int _autocompleteFetchToken = 0;
  String? _activeRequestId;
  GoogleMapController? _pickerMapController;
  LatLng _pickerMapCenter = const LatLng(14.5995, 120.9842);
  bool _showMapPickerSheet = false;
  bool _showAutocomplete = false;
  bool _searchFocused = false;
  bool _loadingPlaces = false;
  bool _loadingAutocomplete = false;
  bool _showBookingSheet = false;
  bool _bookingTransitioning = false;
  Position? _userLocation;

  static const Duration _nearbyCacheTtl = Duration(minutes: 3);
  static const Duration _autocompleteDebounce = Duration(milliseconds: 320);
  static const Duration _prefetchDebounceDuration = Duration(milliseconds: 450);
  static final Duration _bookingPanelShiftDuration = kAppMotion.panelSlide;

  String _formatDistanceKm(double? latitude, double? longitude) {
    if (_userLocation == null || latitude == null || longitude == null) {
      return '';
    }

    final meters = Geolocator.distanceBetween(
      _userLocation!.latitude,
      _userLocation!.longitude,
      latitude,
      longitude,
    );

    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  String _buildRatingDistance(double? rating, double? latitude, double? longitude) {
    final ratingText = rating != null ? '★ ${rating.toStringAsFixed(1)}' : '';
    final kmText = _formatDistanceKm(latitude, longitude);
    if (ratingText.isNotEmpty && kmText.isNotEmpty) {
      return '$ratingText · $kmText';
    }
    return ratingText.isNotEmpty ? ratingText : kmText;
  }

  String _removeStreetFromAddress(String? address) {
    if (address == null) {
      return '';
    }

    final trimmed = address.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final parts = trimmed
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.length <= 1) {
      return trimmed;
    }

    return parts.sublist(1).join(', ');
  }

  String _buildNearbyCacheKey(String categoryLabel) {
    if (_userLocation == null) {
      return 'no_loc|$categoryLabel';
    }
    final lat = (_userLocation!.latitude * 100).round() / 100;
    final lng = (_userLocation!.longitude * 100).round() / 100;
    return '$categoryLabel|$lat|$lng';
  }

  bool _isNearbyCacheFresh(String cacheKey) {
    final cachedAt = _nearbyPlacesCacheTime[cacheKey];
    if (cachedAt == null) {
      return false;
    }
    return DateTime.now().difference(cachedAt) <= _nearbyCacheTtl;
  }

  void _schedulePrefetchNearbyAroundActiveCategory() {
    _prefetchDebounce?.cancel();
    _prefetchDebounce = Timer(_prefetchDebounceDuration, () {
      _prefetchNearbyAroundActiveCategory();
    });
  }

  void _prefetchNearbyAroundActiveCategory() {
    if (_categories.isEmpty || _userLocation == null) {
      return;
    }

    final candidates = <int>{
      _activeCategoryIndex - 1,
      _activeCategoryIndex + 1,
      _activeCategoryIndex + 2,
    };

    for (final index in candidates) {
      if (index < 0 || index >= _categories.length) {
        continue;
      }
      _prefetchNearbyPlaces(_categories[index].label);
    }
  }

  Future<void> _prefetchNearbyPlaces(String categoryLabel) async {
    if (_userLocation == null) {
      return;
    }

    final cacheKey = _buildNearbyCacheKey(categoryLabel);
    if (_isNearbyCacheFresh(cacheKey) || _nearbyPrefetchInFlight.contains(cacheKey)) {
      return;
    }

    _nearbyPrefetchInFlight.add(cacheKey);
    try {
      final keyword = categoryKeywords[categoryLabel] ?? categoryLabel.toLowerCase();
      final results = await _placesService.searchNearbyPlaces(
        latitude: _userLocation!.latitude,
        longitude: _userLocation!.longitude,
        keyword: keyword,
        radius: 15000,
      ).timeout(const Duration(seconds: 10));

      final mappedPlaces = results
          .map((r) => PlaceModel(
                title: r.name,
                subtitle: _removeStreetFromAddress(r.address),
                status: r.openNow ? 'Open' : 'Closed',
                distance: _buildRatingDistance(r.rating, r.latitude, r.longitude),
                latitude: r.latitude,
                longitude: r.longitude,
              ))
          .toList(growable: false);

      _nearbyPlacesCache[cacheKey] = mappedPlaces;
      _nearbyPlacesCacheTime[cacheKey] = DateTime.now();
    } catch (_) {
      // Ignore background prefetch failures.
    } finally {
      _nearbyPrefetchInFlight.remove(cacheKey);
    }
  }
  
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
    if (_bookingTransitioning) {
      return;
    }

    setState(() {
      _bookingTransitioning = true;
      _showBookingSheet = false;
      _showAutocomplete = false;
    });
    widget.onBookingVisibilityChanged?.call(true);

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
    
    if (!mounted) {
      return;
    }
    
    // Extract distance as km
    final kmMatch = RegExp(r'([0-9]+(?:\.[0-9]+)?)\s*km', caseSensitive: false)
      .firstMatch(place.distance);
    final distanceText = kmMatch != null ? double.tryParse(kmMatch.group(1)!) : null;
    
    String? requestId;
    try {
      requestId = await RideMatchingService().createRideRequest(
        pickupName: 'Current Location',
        destinationName: place.title,
        pickupLat: _userLocation?.latitude,
        pickupLng: _userLocation?.longitude,
        destinationLat: place.latitude,
        destinationLng: place.longitude,
        distanceKm: distanceText,
        destinationStatus: place.status,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _bookingTransitioning = false;
      });
      widget.onBookingVisibilityChanged?.call(false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to start booking: $error')),
      );
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _activeRequestId = requestId;
      _bookingTransitioning = false;
      _showBookingSheet = requestId != null;
    });
    widget.onBookingVisibilityChanged?.call(_showBookingSheet);
  }

  void _closeInlineBooking() {
    widget.onEmbeddedAdjustingChanged?.call(false);
    setState(() {
      _showBookingSheet = false;
      _activeRequestId = null;
      _bookingTransitioning = false;
    });
    widget.onBookingVisibilityChanged?.call(false);
  }

  Widget _buildTransitioningCategoryContent({
    required Widget child,
  }) {
    final hideCategoryContent = _bookingTransitioning || _showBookingSheet;
    return AnimatedSlide(
      offset: hideCategoryContent ? const Offset(0, 0.16) : Offset.zero,
      duration: _bookingPanelShiftDuration,
      curve: Curves.easeInOutCubicEmphasized,
      child: AnimatedOpacity(
        opacity: hideCategoryContent ? 0.0 : 1.0,
        duration: kAppMotion.panelFade,
        curve: Curves.easeInOutCubic,
        child: child,
      ),
    );
  }

  Widget _buildInlineBookingOverlay() {
    return IgnorePointer(
      ignoring: !_showBookingSheet || _activeRequestId == null,
      child: AnimatedOpacity(
        opacity: _showBookingSheet && _activeRequestId != null ? 1.0 : 0.0,
        duration: kAppMotion.bookingFade,
        curve: Curves.easeInOutCubic,
        child: AnimatedSlide(
          offset: _showBookingSheet && _activeRequestId != null
              ? Offset.zero
              : const Offset(0, 0.16),
          duration: kAppMotion.bookingSlide,
          curve: Curves.easeInOutCubicEmphasized,
          child: _activeRequestId == null
              ? const SizedBox.shrink()
              : BookingDetailsScreen(
                  requestId: _activeRequestId,
                  embedded: true,
                  onCloseRequested: _closeInlineBooking,
                  embeddedMapCenterProvider: widget.embeddedMapCenterProvider,
                  onEmbeddedAdjustingChanged: widget.onEmbeddedAdjustingChanged,
                  onEmbeddedAdjustTargetChanged: widget.onEmbeddedAdjustTargetChanged,
                  onEmbeddedPickupPointChanged: widget.onEmbeddedPickupPointChanged,
                  onEmbeddedDestinationPointChanged: widget.onEmbeddedDestinationPointChanged,
                  onEmbeddedAdjustPickupModeChanged: widget.onEmbeddedAdjustPickupModeChanged,
                ),
        ),
      ),
    );
  }

  Future<void> _fetchNearbyPlaces(String categoryLabel) async {
    debugPrint('[Category] _fetchNearbyPlaces called for category: $categoryLabel');
    
    if (_userLocation == null) {
      debugPrint('[Category] User location is null, waiting for location...');
      if (mounted) {
        setState(() {
          _loadingPlaces = true;
        });
      }
      return;
    }

    debugPrint('[Category] User location: ${_userLocation!.latitude}, ${_userLocation!.longitude}');

    final cacheKey = _buildNearbyCacheKey(categoryLabel);
    final cachedPlaces = _nearbyPlacesCache[cacheKey];
    final hasCachedPlaces = cachedPlaces != null && cachedPlaces.isNotEmpty;

    if (hasCachedPlaces && mounted) {
      setState(() {
        _dynamicPlaces = cachedPlaces;
        _loadingPlaces = false;
      });
      _fitMarkers(_buildMarkers(cachedPlaces));
    }

    if (cachedPlaces != null && _isNearbyCacheFresh(cacheKey)) {
      _schedulePrefetchNearbyAroundActiveCategory();
      return;
    }

    final fetchToken = ++_nearbyFetchToken;
    if (mounted && !hasCachedPlaces) {
      setState(() {
        _loadingPlaces = true;
      });
    }

    try {
      final keyword = categoryKeywords[categoryLabel] ?? categoryLabel.toLowerCase();
      debugPrint('[Category] Using keyword: $keyword for category: $categoryLabel');
      
      final results = await _placesService.searchNearbyPlaces(
        latitude: _userLocation!.latitude,
        longitude: _userLocation!.longitude,
        keyword: keyword,
        radius: 15000,
      ).timeout(const Duration(seconds: 10));

      if (!mounted || fetchToken != _nearbyFetchToken) {
        return;
      }

      debugPrint('[Category] API returned ${results.length} places');

      final mappedPlaces = results
          .map((r) => PlaceModel(
                title: r.name,
                subtitle: _removeStreetFromAddress(r.address),
                status: r.openNow ? 'Open' : 'Closed',
                distance: _buildRatingDistance(r.rating, r.latitude, r.longitude),
                latitude: r.latitude,
                longitude: r.longitude,
              ))
          .toList(growable: false);

      _nearbyPlacesCache[cacheKey] = mappedPlaces;
      _nearbyPlacesCacheTime[cacheKey] = DateTime.now();

      setState(() {
        _dynamicPlaces = mappedPlaces;
        _loadingPlaces = false;
      });

      debugPrint('[Category] State updated with ${_dynamicPlaces.length} places');

      if (_dynamicPlaces.isNotEmpty) {
        final markers = _buildMarkers(_dynamicPlaces);
        _fitMarkers(markers);
      }
      _schedulePrefetchNearbyAroundActiveCategory();
    } catch (e) {
      debugPrint('[Category] ERROR fetching nearby places: $e');
      if (mounted && fetchToken == _nearbyFetchToken) {
        setState(() {
          _loadingPlaces = false;
        });
        if (cachedPlaces != null && cachedPlaces.isNotEmpty) {
          setState(() {
            _dynamicPlaces = cachedPlaces;
          });
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load places: $e')),
          );
        }
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
      _loadingPlaces = true;
    }
    _initPlacesService();
    _initLocation(); // This will also fetch places once location is available
    _searchFocusNode.addListener(_handleSearchFocus);
    if (widget.externalSearchQuery != null) {
      _query = widget.externalSearchQuery!.trim();
      _searchController.text = _query;
    }
  }

  @override
  void didUpdateWidget(covariant CategoryWithPlacesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextExternalQuery = widget.externalSearchQuery?.trim();
    final prevExternalQuery = oldWidget.externalSearchQuery?.trim();
    if (nextExternalQuery != null && nextExternalQuery != prevExternalQuery) {
      if (_searchController.text != nextExternalQuery) {
        _searchController.text = nextExternalQuery;
      }
      _handleSearchChanged(nextExternalQuery);
    }
    if (widget.externalSearchSubmitRequestId != oldWidget.externalSearchSubmitRequestId) {
      _selectFirstFilteredPlace();
    }
  }

  Future<void> _selectFirstFilteredPlace() async {
    final lower = _query.toLowerCase();
    final filtered = _query.isEmpty
        ? _dynamicPlaces
        : _dynamicPlaces
            .where((place) =>
                place.title.toLowerCase().contains(lower) ||
                place.subtitle.toLowerCase().contains(lower))
            .toList();

    if (_query.isEmpty) {
      if (filtered.isNotEmpty) {
        await _handlePlaceSelected(filtered.first);
      }
      return;
    }

    var predictions = _autocompleteResults;
    if (predictions.isEmpty) {
      try {
        predictions = await _placesService.getAutocompletePredictions(
          input: _query,
          latitude: _userLocation?.latitude,
          longitude: _userLocation?.longitude,
          restrictToCabanatuan: true,
          strictCityFilter: true,
        );
      } catch (_) {
        predictions = const [];
      }
    }

    if (predictions.isNotEmpty) {
      await _handlePlacePredictionSelected(predictions.first);
      return;
    }

    if (filtered.isNotEmpty) {
      await _handlePlaceSelected(filtered.first);
    }
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
      debugPrint('Error initializing Places service: $e');
      // Fallback to unrestricted hardcoded key
      _placesService = GooglePlacesService(apiKey: 'AIzaSyD7eRiM0iLc8DJt3DqdjMhiI8A6BmzBQyY');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _prefetchDebounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _mapController?.dispose();
    _pickerMapController?.dispose();
    super.dispose();
  }

  void _openInlineMapPicker() {
    final fallback = _userLocation != null
        ? LatLng(_userLocation!.latitude, _userLocation!.longitude)
        : const LatLng(14.5995, 120.9842);
    setState(() {
      _pickerMapCenter = fallback;
      _showMapPickerSheet = true;
    });
  }

  void _closeInlineMapPicker() {
    setState(() {
      _showMapPickerSheet = false;
    });
  }

  Future<void> _confirmInlineMapPicker() async {
    final selectedPlace = PlaceModel(
      title: 'Pinned location',
      subtitle: 'Pinned on map',
      status: null,
      distance: '',
      latitude: _pickerMapCenter.latitude,
      longitude: _pickerMapCenter.longitude,
    );

    _closeInlineMapPicker();
    await _handlePlaceSelected(selectedPlace);
  }

  Widget _buildInlineMapPickerOverlay(Responsive r) {
    return IgnorePointer(
      ignoring: !_showMapPickerSheet,
      child: AnimatedOpacity(
        opacity: _showMapPickerSheet ? 1.0 : 0.0,
        duration: kAppMotion.overlayFade,
        curve: Curves.easeInOutCubic,
        child: AnimatedSlide(
          offset: _showMapPickerSheet ? Offset.zero : const Offset(0, 0.08),
          duration: kAppMotion.overlaySlide,
          curve: Curves.easeInOutCubicEmphasized,
          child: Container(
            color: const Color(0xFF121212),
            child: Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _pickerMapCenter,
                      zoom: 15,
                    ),
                    cloudMapId: _useMapId ? _cloudMapId : null,
                    style: _useMapId ? null : _mapStyle,
                    onMapCreated: (controller) {
                      _pickerMapController = controller;
                    },
                    onCameraMove: (position) {
                      _pickerMapCenter = position.target;
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    tiltGesturesEnabled: false,
                  ),
                ),
                const IgnorePointer(
                  child: Center(
                    child: Icon(Icons.location_on, color: Colors.redAccent, size: 36),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: r.space(12), vertical: r.space(8)),
                    child: Row(
                      children: [
                        Text(
                          'Choose location',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: r.font(12),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(Icons.close, color: Colors.white70, size: r.icon(18)),
                          onPressed: _closeInlineMapPicker,
                        ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(left: r.space(12), right: r.space(12), bottom: r.space(10)),
                    child: Container(
                      padding: EdgeInsets.only(left: r.space(12), right: r.space(12), top: r.space(12), bottom: r.space(10)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(r.radius(16)),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: double.infinity,
                            height: r.space(40),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFC9B469),
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r.radius(10)),
                                ),
                              ),
                              onPressed: _confirmInlineMapPicker,
                              child: const Text('Use this location'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleSearchChanged(String value) {
    final query = value.trim();

    setState(() {
      _query = query;
      // Keep showing if focused or if there's text
      if (_searchFocused || _query.isNotEmpty) {
        _showAutocomplete = true;
      } else {
        _showAutocomplete = false;
      }
    });

    _searchDebounce?.cancel();

    if (query.isEmpty) {
      _autocompleteFetchToken++;
      setState(() {
        _autocompleteResults = [];
        _loadingAutocomplete = false;
      });
      // Show all real places in current category
      final markers = _buildMarkers(_dynamicPlaces);
      _fitMarkers(markers);
      return;
    }

    setState(() {
      _loadingAutocomplete = true;
    });

    final fetchToken = ++_autocompleteFetchToken;
    final scheduledQuery = query;
    _searchDebounce = Timer(_autocompleteDebounce, () async {
      try {
        final predictions = await _placesService.getAutocompletePredictions(
          input: scheduledQuery,
          latitude: _userLocation?.latitude,
          longitude: _userLocation?.longitude,
          restrictToCabanatuan: true,
          strictCityFilter: true,
        );

        if (!mounted || fetchToken != _autocompleteFetchToken) {
          return;
        }

        setState(() {
          _autocompleteResults = predictions;
          _loadingAutocomplete = false;
        });
      } catch (e) {
        debugPrint('Error fetching autocomplete: $e');
        if (!mounted || fetchToken != _autocompleteFetchToken) {
          return;
        }
        setState(() {
          _loadingAutocomplete = false;
          _autocompleteResults = [];
        });
      }
    });
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
          subtitle: _removeStreetFromAddress(prediction.secondaryText),
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
        
        if (mounted) {
          _handlePlaceSelected(place);
        }
      }
    } catch (e) {
      debugPrint('Error selecting place: $e');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load place details: $e')),
      );
    }
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
      debugPrint('Starting location initialization...');
      
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      debugPrint('Location service enabled: $serviceEnabled');
      
      if (!serviceEnabled) {
        debugPrint('Location service not enabled, opening settings...');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services')),
          );
        }
        await Geolocator.openLocationSettings();
        _useDefaultLocation();
        return;
      }

      var permission = await Geolocator.checkPermission();
      debugPrint('Current permission: $permission');
      
      if (permission == LocationPermission.denied) {
        debugPrint('Requesting location permission...');
        permission = await Geolocator.requestPermission();
        debugPrint('Permission after request: $permission');
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied');
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

      debugPrint('Permission granted, getting position...');
      await _centerOnUser();
    } catch (e) {
      debugPrint('Error in _initLocation: $e');
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
        _schedulePrefetchNearbyAroundActiveCategory();
      }
    }
  }

  Future<void> _centerOnUser() async {
    try {
      debugPrint('Getting current position with timeout...');
      
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          debugPrint('Location request timed out, using default');
          _useDefaultLocation();
          throw TimeoutException('Location request timed out');
        },
      );

      debugPrint('Got position: ${position.latitude}, ${position.longitude}');
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
        _schedulePrefetchNearbyAroundActiveCategory();
      }
    } on TimeoutException {
      debugPrint('Timeout getting location');
      // Already handled in timeout callback
    } catch (e) {
      debugPrint('Error getting user location: $e');
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
      style: _useMapId ? null : _mapStyle,
      onMapCreated: (controller) {
        _mapController = controller;
        _mapReady = true;
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
              color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
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
              color: Colors.white.withValues(alpha: 0.04),
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

  Widget _buildPlacesPanel(
    Responsive r,
    List<PlaceModel> places, {
    ScrollController? listController,
    bool roundedTopOnly = true,
    List<PlacePrediction> autocompletePredictions = const [],
  }) {
    return AnimatedSwitcher(
      duration: kAppMotion.switcher,
      switchInCurve: Curves.easeInOutCubic,
      switchOutCurve: Curves.easeInOutCubic,
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
          color: Colors.transparent,
          borderRadius: roundedTopOnly
              ? BorderRadius.only(
                  topLeft: Radius.circular(r.radius(18)),
                  topRight: Radius.circular(r.radius(18)),
                )
              : BorderRadius.circular(r.radius(18)),
          border: Border.all(color: Colors.transparent),
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
            : places.isEmpty && autocompletePredictions.isNotEmpty
                ? ListView.separated(
                    controller: listController,
                    itemCount: autocompletePredictions.length,
                    separatorBuilder: (context, index) => SizedBox(height: r.space(10)),
                    itemBuilder: (context, index) {
                      final prediction = autocompletePredictions[index];
                      return _PlaceTile(
                        title: prediction.mainText,
                        subtitle: _removeStreetFromAddress(prediction.secondaryText),
                        distance: 'Via Maps',
                        status: null,
                        onTap: () => _handlePlacePredictionSelected(prediction),
                      );
                    },
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
                : Builder(
                    builder: (context) {
                      final cabanatuanPlaces = places.where(_isCabanatuanPlace).toList(growable: false);
                      final otherPlaces = places.where((place) => !_isCabanatuanPlace(place)).toList(growable: false);
                      final showSections = cabanatuanPlaces.isNotEmpty && otherPlaces.isNotEmpty;

                      final children = <Widget>[];

                      void addPlaces(List<PlaceModel> sectionPlaces) {
                        for (var i = 0; i < sectionPlaces.length; i++) {
                          final place = sectionPlaces[i];
                          children.add(
                            _PlaceTile(
                              title: place.title,
                              subtitle: place.subtitle,
                              distance: place.distance,
                              status: place.status,
                              onTap: () => _handlePlaceSelected(place),
                            ),
                          );
                          if (i < sectionPlaces.length - 1) {
                            children.add(SizedBox(height: r.space(10)));
                          }
                        }
                      }

                      if (showSections) {
                        children.add(_buildPlacesSectionHeader(r, 'Cabanatuan'));
                        children.add(SizedBox(height: r.space(8)));
                        addPlaces(cabanatuanPlaces);
                        children.add(SizedBox(height: r.space(14)));
                        children.add(_buildPlacesSectionHeader(r, 'Outside of your area'));
                        children.add(SizedBox(height: r.space(8)));
                        addPlaces(otherPlaces);
                      } else {
                        addPlaces(places);
                      }

                      children.add(SizedBox(height: r.space(10)));
                      children.add(
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: EdgeInsets.symmetric(vertical: r.space(10)),
                          ),
                          onPressed: _openInlineMapPicker,
                          child: Text('Choose on map', style: TextStyle(fontSize: r.font(12))),
                        ),
                      );

                      return ListView(
                        controller: listController,
                        children: children,
                      );
                    },
                  ),
      ),
    );
  }

  bool _isCabanatuanPlace(PlaceModel place) {
    final searchable = '${place.title} ${place.subtitle}'.toLowerCase();
    return searchable.contains('cabanatuan');
  }

  Widget _buildPlacesSectionHeader(Responsive r, String label) {
    return Text(
      label,
      style: TextStyle(
        color: Colors.white70,
        fontSize: r.font(11),
        fontWeight: FontWeight.w700,
      ),
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

    // Always use real dynamic places (never fallback to mock)
    final localFiltered = _query.isEmpty
      ? _dynamicPlaces
      : _dynamicPlaces
        .where((place) {
          final lower = _query.toLowerCase();
          return place.title.toLowerCase().contains(lower) || 
             place.subtitle.toLowerCase().contains(lower);
        })
        .toList();

    final places = _query.isEmpty ? localFiltered : <PlaceModel>[];

    final autocompleteFallback = widget.placesOnly &&
      _query.isNotEmpty &&
      places.isEmpty &&
      _autocompleteResults.isNotEmpty;
    
    final markers = _buildMarkers(places);
    _pendingFitMarkers = markers;

    if (widget.placesOnly) {
      return Stack(
        children: [
          _buildTransitioningCategoryContent(
            child: Container(
              color: Colors.transparent,
              child: _buildPlacesPanel(
                r,
                places,
                listController: widget.placesScrollController,
                roundedTopOnly: false,
                autocompletePredictions:
                    autocompleteFallback ? _autocompleteResults : const [],
              ),
            ),
          ),
          Positioned.fill(child: _buildInlineBookingOverlay()),
          Positioned.fill(child: _buildInlineMapPickerOverlay(r)),
        ],
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          _buildTransitioningCategoryContent(
            child: Stack(
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
                                      color: Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(r.radius(16)),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
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
                                      child: _loadingAutocomplete && _query.isNotEmpty
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
                                                  _dynamicPlaces = [];
                                                  _loadingPlaces = true;
                                                });
                                                _fetchNearbyPlaces(item.label);
                                              },
                                              child: AnimatedContainer(
                                                duration: kAppMotion.chipMorph,
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
                                                            color: const Color(0xFFE2C26D).withValues(alpha: 0.35),
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
                                child: _buildPlacesPanel(r, places),
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
          ),
          Positioned.fill(child: _buildInlineBookingOverlay()),
          Positioned.fill(child: _buildInlineMapPickerOverlay(r)),
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
    final normalized = distance.replaceAll('•', '·').trim();
    final parts = normalized.split('·').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    String topMetric = '';
    String bottomMetric = '';

    if (parts.length >= 2) {
      topMetric = parts.first;
      bottomMetric = parts[1];
    } else if (parts.length == 1) {
      if (parts.first.toLowerCase().contains('km')) {
        bottomMetric = parts.first;
      } else {
        topMetric = parts.first;
      }
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.transparent, width: 0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.location_on, color: Color(0xFFE2C26D), size: 18),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 102,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (status != null && status!.isNotEmpty)
                    Expanded(
                      child: Text(
                        status!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: isOpen ? Colors.white : Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (status != null && status!.isNotEmpty) const SizedBox(width: 8),
                  SizedBox(
                    width: 44,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          topMetric,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          bottomMetric,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


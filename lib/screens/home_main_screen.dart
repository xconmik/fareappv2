import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import 'category_with_places.dart';
import '../models/category_place_models.dart';
import '../theme/motion_presets.dart';
import '../widgets/fare_logo.dart';
import '../widgets/app_side_menu.dart';

class HomeMainScreen extends StatefulWidget {
  const HomeMainScreen({super.key});

  @override
  State<HomeMainScreen> createState() => _HomeMainScreenState();
}

class _HomeMainScreenState extends State<HomeMainScreen>
  with TickerProviderStateMixin {
  final ScrollController _categoryScrollController = ScrollController();
  final DraggableScrollableController _draggableSheetController = DraggableScrollableController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  int _activeCategoryIndex = 0;
  int? _chipPulseIndex;
  bool _isCategoryExpanded = false;
  GoogleMapController? _mapController;
  bool _hasLocationPermission = false;
  final bool _showMap = true;
  static const bool _useMapId = false;
  static const String _cloudMapId = '5c554f4f892ef6db87f0d2c1';
  bool _mapFailed = false;
  static final Duration _animDuration = kAppMotion.sheet;
  static final Duration _collapseAnimDuration = kAppMotion.sheetCollapse;
  static const Curve _animCurve = Curves.easeInOutCubicEmphasized;
  static const Curve _collapseAnimCurve = Curves.easeOutCubic;
  static const double _minSheetSize = 0.26;
  static const double _adjustSheetSize = 0.42;
  static const double _maxSheetSize = 0.95;
  static const double _categoryRevealThreshold = 0.75;
  static const double _categoryCollapseThreshold = 0.70;
  bool _isAutoCollapsingSheet = false;
  bool _isOpeningSearch = false;
  bool _isBookingVisible = false;
  bool _isEmbeddedAdjusting = false;
  LatLng? _embeddedAdjustPin;
  LatLng? _embeddedPickupPoint;
  LatLng? _embeddedDestinationPoint;
  bool? _embeddedAdjustingPickup;
  String? _directionsApiKey;
  List<LatLng> _routePoints = const [];
  LatLng? _vehicleMarkerPosition;
  int _vehicleAnimationRunId = 0;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;
  LatLng _latestMapCenter = const LatLng(12.8797, 121.7740);
  String _userName = 'there';
  String _searchQuery = '';
  int _searchSubmitRequestId = 0;

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

  final List<CategoryModel> categories = buildDefaultCategories();

  @override
  void initState() {
    super.initState();
    _getUserName();
    _initLocation();
    _initDirectionsApiKey();
    _draggableSheetController.addListener(_onSheetDragged);
  }

  @override
  void dispose() {
    _vehicleAnimationRunId++;
    _draggableSheetController.removeListener(_onSheetDragged);
    _categoryScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initDirectionsApiKey() async {
    try {
      final apiKey = (await AppConfig.getGoogleMapsApiKey()).trim();
      if (!mounted) {
        return;
      }
      setState(() {
        _directionsApiKey = apiKey.isNotEmpty ? apiKey : null;
      });
      _refreshRouteForPickupDestination();
    } catch (_) {
      // Keep map usable even if key fetch fails.
    }
  }

  Future<List<LatLng>> fetchRouteFromApi(LatLng origin, LatLng destination) async {
    var apiKey = _directionsApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      apiKey = (await AppConfig.getGoogleMapsApiKey()).trim();
      if (apiKey.isNotEmpty && mounted) {
        setState(() {
          _directionsApiKey = apiKey;
        });
      }
    }

    if (apiKey == null || apiKey.isEmpty) {
      return const [];
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/directions/json',
      {
        'origin': '${origin.latitude},${origin.longitude}',
        'destination': '${destination.latitude},${destination.longitude}',
        'mode': 'driving',
        'key': apiKey,
      },
    );

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      return const [];
    }

    final payload = jsonDecode(response.body) as Map<String, dynamic>;
    if ((payload['status'] as String?) != 'OK') {
      return const [];
    }

    final routes = payload['routes'] as List<dynamic>?;
    if (routes == null || routes.isEmpty) {
      return const [];
    }

    final route = routes.first as Map<String, dynamic>;
    final pointsEncoded =
        (route['overview_polyline'] as Map<String, dynamic>?)?['points'] as String?;
    if (pointsEncoded == null || pointsEncoded.isEmpty) {
      return const [];
    }

    final decoded = PolylinePoints().decodePolyline(pointsEncoded);
    return decoded
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
  }

  void drawRoute(List<LatLng> routePoints) {
    if (!mounted) {
      return;
    }
    setState(() {
      _routePoints = routePoints;
      _vehicleMarkerPosition = routePoints.isNotEmpty ? routePoints.first : null;
    });
  }

  Future<void> animateVehicleAlongRoute(List<LatLng> routePoints) async {
    if (routePoints.length < 2 || !mounted) {
      return;
    }

    final runId = ++_vehicleAnimationRunId;
    const frameDelay = Duration(milliseconds: 28);

    for (var i = 0; i < routePoints.length - 1; i++) {
      if (!mounted || runId != _vehicleAnimationRunId) {
        return;
      }

      final start = routePoints[i];
      final end = routePoints[i + 1];
      const steps = 12;
      for (var step = 0; step <= steps; step++) {
        if (!mounted || runId != _vehicleAnimationRunId) {
          return;
        }

        final t = step / steps;
        final position = LatLng(
          start.latitude + (end.latitude - start.latitude) * t,
          start.longitude + (end.longitude - start.longitude) * t,
        );

        setState(() {
          _vehicleMarkerPosition = position;
        });

        await Future.delayed(frameDelay);
      }
    }
  }

  void fitCameraToRouteBounds(List<LatLng> routePoints) {
    if (routePoints.isEmpty || _mapController == null) {
      return;
    }

    var minLat = routePoints.first.latitude;
    var maxLat = routePoints.first.latitude;
    var minLng = routePoints.first.longitude;
    var maxLng = routePoints.first.longitude;

    for (final point in routePoints) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 72));
  }

  Future<void> _refreshRouteForPickupDestination() async {
    final origin = _embeddedPickupPoint;
    final destination = _embeddedDestinationPoint;

    if (!_isBookingVisible || origin == null || destination == null) {
      _vehicleAnimationRunId++;
      if (_routePoints.isNotEmpty || _vehicleMarkerPosition != null) {
        setState(() {
          _routePoints = const [];
          _vehicleMarkerPosition = null;
        });
      }
      _lastRouteOrigin = null;
      _lastRouteDestination = null;
      return;
    }

    if (_lastRouteOrigin == origin && _lastRouteDestination == destination) {
      return;
    }

    _lastRouteOrigin = origin;
    _lastRouteDestination = destination;

    final routePoints = await fetchRouteFromApi(origin, destination);
    if (!mounted) {
      return;
    }

    if (routePoints.isEmpty) {
      setState(() {
        _routePoints = [origin, destination];
        _vehicleMarkerPosition = origin;
      });
      return;
    }

    drawRoute(routePoints);
    fitCameraToRouteBounds(routePoints);
    unawaited(animateVehicleAlongRoute(routePoints));
  }

  void _onSheetDragged() {
    if (_isAutoCollapsingSheet || !_draggableSheetController.isAttached) {
      return;
    }

    if (_isEmbeddedAdjusting) {
      final currentSize = _draggableSheetController.size;
      if (currentSize > _minSheetSize + 0.01) {
        _snapToCollapsed();
      }
      return;
    }

    final currentSize = _draggableSheetController.size;
    final shouldShowCategory = currentSize >= _categoryRevealThreshold;

    if (_isCategoryExpanded && currentSize < _categoryCollapseThreshold) {
      setState(() {
        _isCategoryExpanded = false;
        _searchQuery = '';
      });
      _searchController.clear();
      _searchFocusNode.unfocus();
      _snapToCollapsed();
      return;
    }

    if (!_isCategoryExpanded && shouldShowCategory) {
      setState(() {
        _isCategoryExpanded = true;
      });
    }
  }

  Future<void> _snapToCollapsed() async {
    if (!_draggableSheetController.isAttached) {
      return;
    }

    _isAutoCollapsingSheet = true;
    try {
      await _draggableSheetController.animateTo(
        _minSheetSize,
        duration: _collapseAnimDuration,
        curve: _collapseAnimCurve,
      );
    } finally {
      _isAutoCollapsingSheet = false;
    }
  }

  Future<void> _snapToAdjustSheet() async {
    if (!_draggableSheetController.isAttached) {
      return;
    }

    _isAutoCollapsingSheet = true;
    try {
      await _draggableSheetController.animateTo(
        _adjustSheetSize,
        duration: _collapseAnimDuration,
        curve: _collapseAnimCurve,
      );
    } finally {
      _isAutoCollapsingSheet = false;
    }
  }

  Future<void> _getUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.displayName != null && user.displayName!.isNotEmpty) {
        final firstName = user.displayName!.split(' ').first;
        setState(() {
          _userName = firstName;
        });
      } else if (user != null && user.email != null) {
        final firstName = user.email!.split('@').first;
        setState(() {
          _userName = firstName;
        });
      }
    } catch (e) {
      debugPrint('Error getting user name: $e');
    }
  }

  Future<void> _expandToCategory({int? initialIndex}) async {
    setState(() {
      if (initialIndex != null) {
        _activeCategoryIndex = initialIndex;
      }
    });
    if (!_draggableSheetController.isAttached) {
      return;
    }
    await _draggableSheetController.animateTo(
      _maxSheetSize,
      duration: _animDuration,
      curve: _animCurve,
    );

    if (!mounted) {
      return;
    }

    if (!_isCategoryExpanded) {
      setState(() {
        _isCategoryExpanded = true;
      });
    }
  }

  Future<void> _openLocationSearch() async {
    if (_isOpeningSearch) {
      return;
    }

    _isOpeningSearch = true;
    try {
      if (!_isCategoryExpanded) {
        await _expandToCategory();
      } else if (_draggableSheetController.isAttached &&
          _draggableSheetController.size < _maxSheetSize - 0.01) {
        await _draggableSheetController.animateTo(
          _maxSheetSize,
          duration: _animDuration,
          curve: _animCurve,
        );
      }

      if (!mounted) {
        return;
      }

      if (!mounted) {
        return;
      }

      FocusScope.of(context).requestFocus(_searchFocusNode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        if (!_searchFocusNode.hasFocus) {
          FocusScope.of(context).requestFocus(_searchFocusNode);
        }
      });
    } finally {
      _isOpeningSearch = false;
    }
  }

  void _handleHomeSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  void _clearHomeSearch() {
    final hasText = _searchController.text.trim().isNotEmpty;

    _searchController.clear();
    setState(() {
      _searchQuery = '';
    });

    if (hasText) {
      _searchFocusNode.requestFocus();
      return;
    }

    _searchFocusNode.unfocus();
    _snapToCollapsed();
    if (mounted) {
      setState(() {
        _isCategoryExpanded = false;
      });
    }
  }

  void _handleHomeSearchSubmitted(String value) {
    setState(() {
      _searchQuery = value.trim();
      _searchSubmitRequestId++;
    });
    _searchFocusNode.unfocus();
  }

  Future<void> _initLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _hasLocationPermission = true;
    });

    await _centerOnUser();
  }

  Future<void> _centerOnUser() async {
    final position = await Geolocator.getCurrentPosition();
    await _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(position.latitude, position.longitude),
        15.5,
      ),
    );
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

  Widget _buildLiveMap() {
    final markers = <Marker>{
      if (_embeddedPickupPoint != null && !(_isEmbeddedAdjusting && _embeddedAdjustingPickup == true))
        Marker(
          markerId: const MarkerId('embedded_pickup_pin'),
          position: _embeddedPickupPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup'),
        ),
      if (_embeddedDestinationPoint != null && !(_isEmbeddedAdjusting && _embeddedAdjustingPickup == false))
        Marker(
          markerId: const MarkerId('embedded_destination_pin'),
          position: _embeddedDestinationPoint!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      if (_isEmbeddedAdjusting && _embeddedAdjustPin != null)
        Marker(
          markerId: const MarkerId('embedded_adjust_pin'),
          position: _embeddedAdjustPin!,
          draggable: true,
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _embeddedAdjustingPickup == true
                ? BitmapDescriptor.hueGreen
                : BitmapDescriptor.hueRed,
          ),
          onDragEnd: (position) {
            if (!mounted) {
              return;
            }
            setState(() {
              _embeddedAdjustPin = position;
              _latestMapCenter = position;
            });
          },
        ),
      if (_vehicleMarkerPosition != null)
        Marker(
          markerId: const MarkerId('embedded_vehicle_pin'),
          position: _vehicleMarkerPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Vehicle'),
        ),
    };

    final polylines = <Polyline>{
      if (_routePoints.length >= 2)
        Polyline(
          polylineId: const PolylineId('embedded_route'),
          points: _routePoints,
          color: Colors.white.withValues(alpha: 0.8),
          width: 5,
        ),
    };

    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(12.8797, 121.7740),
        zoom: 15.0,
      ),
      cloudMapId: _useMapId ? _cloudMapId : null,
      style: _useMapId ? null : _mapStyle,
      onMapCreated: (controller) {
        _mapController = controller;
        _scheduleMapHealthCheck();
        if (_hasLocationPermission) {
          _centerOnUser();
        }
      },
      onCameraMove: (position) {
        _latestMapCenter = position.target;
      },
      onTap: _isEmbeddedAdjusting
          ? (position) {
              setState(() {
                _embeddedAdjustPin = position;
                _latestMapCenter = position;
              });
            }
          : null,
      gestureRecognizers: _isEmbeddedAdjusting
          ? <Factory<OneSequenceGestureRecognizer>>{
              Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
            }
          : <Factory<OneSequenceGestureRecognizer>>{},
      markers: markers,
      polylines: polylines,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: true,
      myLocationEnabled: _hasLocationPermission,
      mapType: MapType.normal,
    );
  }

  Future<LatLng?> _provideEmbeddedMapCenter() async {
    if (_isEmbeddedAdjusting && _embeddedAdjustPin != null) {
      return _embeddedAdjustPin;
    }

    if (_mapController == null) {
      return _latestMapCenter;
    }

    try {
      final region = await _mapController!.getVisibleRegion();
      final center = LatLng(
        (region.northeast.latitude + region.southwest.latitude) / 2,
        (region.northeast.longitude + region.southwest.longitude) / 2,
      );
      _latestMapCenter = center;
      return center;
    } catch (_) {
      return _latestMapCenter;
    }
  }

  Future<void> _focusMapForEmbeddedAdjust(LatLng target) async {
    if (mounted) {
      setState(() {
        _embeddedAdjustPin = target;
        _latestMapCenter = target;
      });
    } else {
      _embeddedAdjustPin = target;
      _latestMapCenter = target;
    }

    try {
      await _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(target, 16.5),
      );
    } catch (_) {
      // Keep flow alive even if map controller is temporarily unavailable.
    }

    if (!_draggableSheetController.isAttached) {
      return;
    }

    if (_draggableSheetController.size <= _adjustSheetSize + 0.005) {
      return;
    }
    await _snapToAdjustSheet();
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
              color: Colors.white.withValues(alpha: 0.08),
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
            padding: EdgeInsets.only(
              left: grid * 1.75,
              right: grid * 1.75,
              top: grid * 1.25,
            ),
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
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: grid * 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedContent(
    double grid,
    double searchHeight,
    double chipSize,
    double scale,
    double bodySize,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: grid * 4,
          height: grid * 0.5,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(grid * 12),
          ),
        ),
        SizedBox(height: grid * 1.5),
        AnimatedOpacity(
          opacity: 1.0,
          duration: _animDuration,
          curve: _animCurve,
          child: AnimatedScale(
            scale: 1.0,
            duration: _animDuration,
            curve: _animCurve,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(grid * 2),
              child: BackdropFilter(
                filter:
                    ImageFilter.blur(sigmaX: grid * 1.5, sigmaY: grid * 1.5),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(grid * 2),
                    color: Colors.white.withValues(alpha: 0.05),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: grid * 2.25,
                        offset: Offset(0, grid * 1.25),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    height: searchHeight,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _openLocationSearch,
                      child: Container(
                        padding: EdgeInsets.only(
                          left: grid * 2.25,
                          right: grid * 2.25,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2A),
                          borderRadius: BorderRadius.circular(grid * 1.25),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search,
                                color: Colors.white, size: grid * 2.5),
                            SizedBox(width: grid * 2.5),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: _openLocationSearch,
                                child: Text(
                                  'Hi $_userName, where to?',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: bodySize,
                                    fontFamily: 'SF Pro Display',
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: grid * 2.25),
        AnimatedOpacity(
          opacity: 1.0,
          duration: _animDuration,
          curve: _animCurve,
          child: AnimatedSlide(
            offset: Offset.zero,
            duration: _animDuration,
            curve: _animCurve,
            child: SizedBox(
              height: chipSize,
              child: ListView.separated(
                controller: _categoryScrollController,
                scrollDirection: Axis.horizontal,
                itemBuilder: (context, index) => GestureDetector(
                  onTap: () {
                    setState(() {
                      _activeCategoryIndex = index;
                      _chipPulseIndex = index;
                    });
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) {
                        return;
                      }
                      setState(() {
                        _chipPulseIndex = null;
                      });
                    });
                    _expandToCategory(initialIndex: index);
                  },
                  child: AnimatedScale(
                    duration: kAppMotion.chipScale,
                    curve: Curves.easeInOutCubicEmphasized,
                    scale: _chipPulseIndex == index ? 1.06 : 1.0,
                    child: AnimatedOpacity(
                      duration: kAppMotion.chipFade,
                      curve: Curves.easeInOutCubic,
                      opacity: _chipPulseIndex == index ? 1.0 : 0.92,
                      child: _CategoryChip(
                        item: categories[index],
                        isActive: index == _activeCategoryIndex,
                        size: chipSize,
                        scale: scale,
                      ),
                    ),
                  ),
                ),
                separatorBuilder: (context, index) => SizedBox(width: grid * 1.25),
                itemCount: categories.length,
              ),
            ),
          ),
        ),
        SizedBox(height: grid * 1.5),
        AnimatedOpacity(
          opacity: 1.0,
          duration: _animDuration,
          curve: _animCurve,
          child: AnimatedSlide(
            offset: Offset.zero,
            duration: _animDuration,
            curve: _animCurve,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recents',
                    style: TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w600,
                      fontSize: bodySize,
                    ),
                  ),
                ),
                SizedBox(height: grid * 0.75),
                Center(
                  child: Text(
                    'No recent searches yet.\nDrag up or tap search to find places.',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: bodySize,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCollapsedSheet(
    double grid,
    double searchHeight,
    double chipSize,
    double scale,
    double bodySize,
    ScrollController controller,
  ) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(
        left: grid * 2,
        right: grid * 2,
        top: grid * 2,
        bottom: grid * 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF202020),
        borderRadius: BorderRadius.circular(grid * 2.75),
        border: Border.all(color: Colors.white12),
      ),
      child: SingleChildScrollView(
        controller: controller,
        child: _buildCollapsedContent(
          grid,
          searchHeight,
          chipSize,
          scale,
          bodySize,
        ),
      ),
    );
  }

  Widget _buildStickyHomeHeader(
    double grid,
    double searchHeight,
    double chipSize,
    double scale,
    double bodySize,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: grid * 4,
          height: grid * 0.5,
          decoration: BoxDecoration(
            color: Colors.white30,
            borderRadius: BorderRadius.circular(grid * 12),
          ),
        ),
        SizedBox(height: grid * 1.5),
        ClipRRect(
          borderRadius: BorderRadius.circular(grid * 2),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: grid * 1.5, sigmaY: grid * 1.5),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(grid * 2),
                color: Colors.white.withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: grid * 2.25,
                    offset: Offset(0, grid * 1.25),
                  ),
                ],
              ),
              child: SizedBox(
                height: searchHeight,
                child: Container(
                  padding: EdgeInsets.only(
                    left: grid * 2.25,
                    right: grid * 1.1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(grid * 1.25),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.white, size: grid * 2.5),
                      SizedBox(width: grid * 1.25),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          onChanged: _handleHomeSearchChanged,
                          onSubmitted: _handleHomeSearchSubmitted,
                          textInputAction: TextInputAction.search,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: bodySize,
                            fontFamily: 'SF Pro Display',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Hi $_userName, where to?',
                            hintStyle: TextStyle(
                              color: Colors.white54,
                              fontWeight: FontWeight.w700,
                              fontSize: bodySize,
                              fontFamily: 'SF Pro Display',
                            ),
                            isCollapsed: true,
                            contentPadding: EdgeInsets.zero,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: Colors.white70, size: grid * 2.2),
                        onPressed: _clearHomeSearch,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: grid * 2.25),
        SizedBox(
          height: chipSize,
          child: ListView.separated(
            controller: _categoryScrollController,
            scrollDirection: Axis.horizontal,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                setState(() {
                  _activeCategoryIndex = index;
                  _chipPulseIndex = index;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _chipPulseIndex = null;
                  });
                });
              },
              child: AnimatedScale(
                duration: kAppMotion.chipScale,
                curve: Curves.easeInOutCubicEmphasized,
                scale: _chipPulseIndex == index ? 1.06 : 1.0,
                child: AnimatedOpacity(
                  duration: kAppMotion.chipFade,
                  curve: Curves.easeInOutCubic,
                  opacity: _chipPulseIndex == index ? 1.0 : 0.92,
                  child: _CategoryChip(
                    item: categories[index],
                    isActive: index == _activeCategoryIndex,
                    size: chipSize,
                    scale: scale,
                  ),
                ),
              ),
            ),
            separatorBuilder: (context, index) => SizedBox(width: grid * 1.25),
            itemCount: categories.length,
          ),
        ),
      ],
    );
  }

  Widget _buildExpandedSheet(
    double grid,
    double searchHeight,
    double chipSize,
    double scale,
    double bodySize,
    ScrollController controller,
  ) {
    final hideHeaderForBooking = _isBookingVisible;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      padding: EdgeInsets.only(
        left: _isBookingVisible ? 0 : grid * 2,
        right: _isBookingVisible ? 0 : grid * 2,
        top: _isBookingVisible ? 0 : grid * 2,
        bottom: _isBookingVisible ? 0 : grid * 2,
      ),
      decoration: BoxDecoration(
        color: _isBookingVisible ? Colors.transparent : const Color(0xFF202020),
        borderRadius: BorderRadius.circular(_isBookingVisible ? 0 : grid * 2.75),
        border: Border.all(
          color: _isBookingVisible ? Colors.transparent : Colors.white12,
        ),
      ),
      child: Column(
        children: [
          AnimatedPadding(
            duration: kAppMotion.panelSlide,
            curve: Curves.easeInOutCubicEmphasized,
            padding: EdgeInsets.only(top: hideHeaderForBooking ? grid * 1.1 : 0),
            child: AnimatedSlide(
              offset: hideHeaderForBooking ? const Offset(0, 0.22) : Offset.zero,
              duration: kAppMotion.panelSlide,
              curve: Curves.easeInOutCubicEmphasized,
              child: AnimatedOpacity(
                opacity: hideHeaderForBooking ? 0.0 : 1.0,
                duration: kAppMotion.panelFade,
                curve: Curves.easeInOutCubic,
                child: Column(
                  children: [
                    _buildStickyHomeHeader(grid, searchHeight, chipSize, scale, bodySize),
                    SizedBox(height: grid * 1.5),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: CategoryWithPlacesScreen(
              key: ValueKey('category_$_activeCategoryIndex'),
              initialCategoryIndex: _activeCategoryIndex,
              placesOnly: true,
              placesScrollController: controller,
              externalSearchQuery: _searchQuery,
              externalSearchSubmitRequestId: _searchSubmitRequestId,
              embeddedMapCenterProvider: _provideEmbeddedMapCenter,
              onEmbeddedAdjustTargetChanged: (target) {
                _focusMapForEmbeddedAdjust(target);
              },
              onEmbeddedPickupPointChanged: (pickupPoint) {
                if (!mounted || _embeddedPickupPoint == pickupPoint) {
                  return;
                }
                setState(() {
                  _embeddedPickupPoint = pickupPoint;
                });
                _refreshRouteForPickupDestination();
              },
              onEmbeddedDestinationPointChanged: (destinationPoint) {
                if (!mounted || _embeddedDestinationPoint == destinationPoint) {
                  return;
                }
                setState(() {
                  _embeddedDestinationPoint = destinationPoint;
                });
                _refreshRouteForPickupDestination();
              },
              onEmbeddedAdjustPickupModeChanged: (isPickupMode) {
                if (!mounted || _embeddedAdjustingPickup == isPickupMode) {
                  return;
                }
                setState(() {
                  _embeddedAdjustingPickup = isPickupMode;
                });
              },
              onEmbeddedAdjustingChanged: (isAdjusting) {
                if (!mounted || _isEmbeddedAdjusting == isAdjusting) {
                  return;
                }
                setState(() {
                  _isEmbeddedAdjusting = isAdjusting;
                  if (!isAdjusting) {
                    _embeddedAdjustPin = null;
                    _embeddedAdjustingPickup = null;
                  }
                });
                if (isAdjusting) {
                  _snapToAdjustSheet();
                }
              },
              onBookingVisibilityChanged: (isVisible) {
                if (_isBookingVisible == isVisible || !mounted) {
                  return;
                }
                setState(() {
                  _isBookingVisible = isVisible;
                  if (!isVisible) {
                    _vehicleAnimationRunId++;
                    _embeddedAdjustPin = null;
                    _embeddedPickupPoint = null;
                    _embeddedDestinationPoint = null;
                    _embeddedAdjustingPickup = null;
                    _routePoints = const [];
                    _vehicleMarkerPosition = null;
                    _lastRouteOrigin = null;
                    _lastRouteDestination = null;
                  }
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final width = size.width;
    final scale = (width / 375).clamp(0.85, 1.2);
    final grid = 8.0 * scale;
    final minTap = (grid * 6).clamp(48.0, 72.0);
    final searchHeight = grid * 7.25;
    final chipSize = grid * 9.5 * 0.85;
    final titleSize = grid * 2.0;
    final bodySize = grid * 1.5;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          _showMap ? _buildLiveMap() : _buildMapPlaceholder(),
          if (_mapFailed) Positioned.fill(child: _buildMapPlaceholder()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: grid * 2, right: grid * 2, top: grid),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FareLogo(height: titleSize * 2.5),
                  SizedBox(
                    width: minTap,
                    height: minTap,
                    child: IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: grid * 2.4),
                      onPressed: () => showAppSideMenu(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: DraggableScrollableSheet(
              controller: _draggableSheetController,
              initialChildSize: _isEmbeddedAdjusting ? _adjustSheetSize : _minSheetSize,
              minChildSize: _isEmbeddedAdjusting ? _adjustSheetSize : _minSheetSize,
              maxChildSize: _isEmbeddedAdjusting ? _adjustSheetSize : _maxSheetSize,
              snap: !_isEmbeddedAdjusting,
              snapAnimationDuration: _collapseAnimDuration,
              snapSizes: _isEmbeddedAdjusting
                  ? const [_adjustSheetSize]
                  : const [_minSheetSize, _maxSheetSize],
              builder: (context, controller) {
                if (_isCategoryExpanded || _isBookingVisible || _isEmbeddedAdjusting) {
                  return _buildExpandedSheet(
                    grid,
                    searchHeight,
                    chipSize,
                    scale,
                    bodySize,
                    controller,
                  );
                }

                return _buildCollapsedSheet(
                  grid,
                  searchHeight,
                  chipSize,
                  scale,
                  bodySize,
                  controller,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final CategoryModel item;
  final bool isActive;
  final double size;
  final double scale;

  const _CategoryChip({
    required this.item,
    required this.size,
    required this.scale,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final grid = 8.0 * scale;

    return AnimatedContainer(
      duration: kAppMotion.chipMorph,
      curve: Curves.easeInOutCubicEmphasized,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? const Color(0xFF3A3A3A) : const Color(0xFF2A2A2A),
          width: grid * 0.15,
        ),
        boxShadow: [],
      ),
      child: AnimatedScale(
        duration: kAppMotion.chipScale,
        curve: Curves.easeInOutCubicEmphasized,
        scale: isActive ? 1.0 : 0.95,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.icon,
              color: isActive ? Colors.white : Colors.white70,
              size: grid * 1.8,
            ),
            SizedBox(height: grid * 0.5),
            Text(
              item.label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white70,
                fontSize: grid * 1.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

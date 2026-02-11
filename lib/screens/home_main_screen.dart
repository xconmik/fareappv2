import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'category_with_places.dart';
import 'location_search_screen.dart';
import '../widgets/fare_logo.dart';

class HomeMainScreen extends StatefulWidget {
  const HomeMainScreen({Key? key}) : super(key: key);

  @override
  State<HomeMainScreen> createState() => _HomeMainScreenState();
}

class _HomeMainScreenState extends State<HomeMainScreen> {
  final ScrollController _categoryScrollController = ScrollController();
  int _activeCategoryIndex = 0;
  bool _isSearchOpen = false;
  GoogleMapController? _mapController;
  bool _hasLocationPermission = false;
  final bool _showMap = true;
  static const bool _useMapId = false;
  static const String _cloudMapId = '5c554f4f892ef6db87f0d2c1';
  bool _mapFailed = false;
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

  void _openCategoryScreen(BuildContext context, {int initialCategoryIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryWithPlacesScreen(initialCategoryIndex: initialCategoryIndex),
      ),
    );
  }

  Future<void> _openSearchSheet(BuildContext context) async {
    if (_isSearchOpen) {
      return;
    }
    setState(() {
      _isSearchOpen = true;
    });
    final result = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      barrierColor: Colors.black54,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.8,
          minChildSize: 0.8,
          maxChildSize: 0.8,
          builder: (context, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              child: LocationSearchSheet(controller: controller),
            );
          },
        );
      },
    );
    
    if (!mounted) {
      return;
    }
    
    setState(() {
      _isSearchOpen = false;
    });

    // Handle search result - animate map to selected location
    if (result != null) {
      try {
        if (result.latitude != null && result.longitude != null && _mapController != null) {
          await _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(
              LatLng(result.latitude!, result.longitude!),
              15.5,
            ),
          );
        }
      } catch (e) {
        print('Error animating to search result: $e');
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
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

    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
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
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(12.8797, 121.7740),
        zoom: 15.0,
      ),
      cloudMapId: _useMapId ? _cloudMapId : null,
      onMapCreated: (controller) {
        _mapController = controller;
        if (!_useMapId) {
          _mapController?.setMapStyle(_mapStyle);
        }
        _scheduleMapHealthCheck();
        if (_hasLocationPermission) {
          _centerOnUser();
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

  List<_CategoryItem> categories = [
    _CategoryItem(icon: Icons.fastfood, label: 'Food'),
    _CategoryItem(icon: Icons.school, label: 'School'),
    _CategoryItem(icon: Icons.store_mall_directory, label: 'Mall'),
    _CategoryItem(icon: Icons.local_cafe, label: 'Cafe'),
    _CategoryItem(icon: Icons.local_grocery_store, label: 'Mart'),
    _CategoryItem(icon: Icons.local_hospital, label: 'Hospital'),
    _CategoryItem(icon: Icons.park, label: 'Park'),
    _CategoryItem(icon: Icons.business_center, label: 'Office'),
    _CategoryItem(icon: Icons.flight, label: 'Airport'),
    _CategoryItem(icon: Icons.hotel, label: 'Hotel'),
    _CategoryItem(icon: Icons.fitness_center, label: 'Gym'),
    _CategoryItem(icon: Icons.movie, label: 'Cinema'),
  ];



  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final size = media.size;
    final width = size.width;
    final scale = (width / 375).clamp(0.85, 1.2);
    final grid = 8.0 * scale;
    final minTap = (grid * 6).clamp(48.0, 72.0);
    final isWide = width >= 600;
    final searchHeight = grid * 7.25;
    final chipSize = grid * 9.5;
    final titleSize = grid * 2.0;
    final bodySize = grid * 1.5;
    final captionSize = grid * 1.25;

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          _showMap ? _buildLiveMap() : _buildMapPlaceholder(),
          if (_mapFailed) Positioned.fill(child: _buildMapPlaceholder()),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: grid * 2, vertical: grid),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  FareLogo(height: titleSize * 2.5),
                  SizedBox(
                    width: minTap,
                    height: minTap,
                    child: IconButton(
                      icon: Icon(Icons.menu, color: Colors.white, size: grid * 2.4),
                      onPressed: () => Navigator.pushNamed(context, '/settings'),
                    ),
                  ),
                ],
              ),
            ),
          ),
            if (!_isSearchOpen)
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.zero,
                  padding: EdgeInsets.symmetric(horizontal: grid * 2, vertical: grid * 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF202020),
                    borderRadius: BorderRadius.circular(grid * 2.75),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
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
                                color: Colors.white.withOpacity(0.05),
                                border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.0),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.35),
                                    blurRadius: grid * 2.25,
                                    offset: Offset(0, grid * 1.25),
                                  ),
                                ],
                              ),
                              child: SizedBox(
                                height: searchHeight,
                                child: GestureDetector(
                                  onTap: () => _openSearchSheet(context),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(horizontal: grid * 2.25),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(grid * 1.25),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.search, color: Colors.white, size: grid * 2.5),
                                        SizedBox(width: grid * 2.5),
                                        Expanded(
                                          child: Text(
                                            'Hi Erlon, where to?',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: bodySize,
                                              fontFamily: 'SF Pro Display',
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
                                });
                                _categoryScrollController.animateTo(
                                  (index * (chipSize + grid)).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.ease,
                                );
                                _openCategoryScreen(context, initialCategoryIndex: index);
                              },
                              child: _CategoryChip(
                                item: categories[index],
                                isActive: index == _activeCategoryIndex,
                                size: chipSize,
                                scale: scale,
                              ),
                            ),
                            separatorBuilder: (context, index) => SizedBox(width: grid * 1.25),
                            itemCount: categories.length,
                          ),
                        ),
                        SizedBox(height: grid * 1.5),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Recents', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: bodySize)),
                            ),
                            SizedBox(height: grid * 0.75),
                            Center(
                              child: Text(
                                'No recent searches yet.\nUse the search button to find places.',
                                style: TextStyle(color: Colors.white54, fontSize: bodySize),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _CategoryItem {
  final IconData icon;
  final String label;

  const _CategoryItem({required this.icon, required this.label});
}

class _CategoryChip extends StatelessWidget {
  final _CategoryItem item;
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
      duration: const Duration(milliseconds: 250),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? Colors.amber : const Color(0xFF2A2A2A),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.amberAccent : Colors.white.withOpacity(0.14),
          width: grid * 0.225,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: grid * 1.5,
                )
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            color: isActive ? Colors.black : Colors.white70,
            size: grid * 2.5,
          ),
          SizedBox(height: grid * 0.75),
          Text(
            item.label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white70,
              fontSize: grid * 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

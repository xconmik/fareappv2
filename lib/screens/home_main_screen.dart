import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'category_with_places.dart';
import 'location_search_screen.dart';

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
  final bool _showMap = false;
  static const bool _useMapId = true;
  static const String _cloudMapId = '118c30a958d1028bec3bbb7e';
  bool _mapFailed = false;
  static const String _mapStyle = '''{
  "variant": "dark",
  "styles": [
    {
      "id": "pointOfInterest.emergency.fire",
      "label": {
        "visible": true
      }
    },
    {
      "id": "pointOfInterest.emergency.hospital",
      "geometry": {
        "visible": true
      }
    },
    {
      "id": "pointOfInterest.emergency.police",
      "label": {
        "visible": true
      }
    },
    {
      "id": "pointOfInterest.landmark",
      "label": {
        "visible": true
      }
    },
    {
      "id": "pointOfInterest.lodging",
      "label": {
        "visible": true
      }
    },
    {
      "id": "political.city",
      "label": {
        "visible": true
      }
    },
    {
      "id": "political.neighborhood",
      "label": {
        "visible": false
      }
    }
  ]
}''';

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
    await showModalBottomSheet<void>(
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
        zoom: 5.6,
      ),
      cloudMapId: _useMapId ? _cloudMapId : null,
      cameraTargetBounds: CameraTargetBounds(
        LatLngBounds(
          southwest: const LatLng(4.2158, 116.9542),
          northeast: const LatLng(21.3219, 126.6052),
        ),
      ),
      minMaxZoomPreference: const MinMaxZoomPreference(5.0, 18.0),
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
      compassEnabled: false,
      mapToolbarEnabled: false,
    );
  }

  Widget _buildMapPlaceholder() {
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
          top: -40,
          right: -30,
          child: Container(
            width: 180,
            height: 180,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFD4AF37).withOpacity(0.08),
            ),
          ),
        ),
        Positioned(
          bottom: -60,
          left: -40,
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
        ),
        Positioned(
          top: 120,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF232323),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: const [
                Icon(Icons.map, color: Colors.white54, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Map preview disabled (quota off)',
                    style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.w600),
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

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: Stack(
        children: [
          _showMap ? _buildLiveMap() : _buildMapPlaceholder(),
          if (_mapFailed) Positioned.fill(child: _buildMapPlaceholder()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Home', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                  IconButton(
                    icon: const Icon(Icons.menu, color: Colors.white),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
          ),
          if (!_isSearchOpen)
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                margin: const EdgeInsets.all(16.0),
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: const Color(0xFF202020),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                  Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white30,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(color: Colors.white.withOpacity(0.18), width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.35),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          height: 80,
                          child: Stack(
                            children: [
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 43,
                                height: 38,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                      colors: [
                                        Color(0xFFC9A24D),
                                        Color(0xFFE4C46F),
                                        Color(0xFFF2D58A),
                                      ],
                                      stops: [0.0, 0.55, 1.0],
                                    ),
                                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(10)),
                                  ),
                                  child: const Center(
                                    child: Text(
                                      '51 drivers available nearby',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                        fontSize: 11,
                                        letterSpacing: 0.2,
                                        fontFamily: 'SF Pro Display',
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                left: 0,
                                right: 0,
                                top: 0,
                                height: 55,
                                child: GestureDetector(
                                  onTap: () => _openSearchSheet(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 18),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF2A2A2A),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(Icons.search, color: Colors.white, size: 20),
                                          SizedBox(width: 20),
                                          Text(
                                            'Hi Erlon, where to?',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              fontFamily: 'SF Pro Display',
                                            ),
                                          ),
                                        ],
                                      ),
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
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 96,
                    child: ListView.separated(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      itemBuilder: (context, index) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _activeCategoryIndex = index;
                          });
                          // Scroll to the tapped category
                          _categoryScrollController.animateTo(
                            (index * 88.0).clamp(0.0, _categoryScrollController.position.maxScrollExtent),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.ease,
                          );
                          _openCategoryScreen(context, initialCategoryIndex: index);
                        },
                        child: _CategoryChip(
                          item: categories[index],
                          isActive: index == _activeCategoryIndex,
                        ),
                      ),
                      separatorBuilder: (context, index) => const SizedBox(width: 10),
                      itemCount: categories.length,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Recents', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.white70),
                    title: const Text('Wesleyan University Philippines', style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Mabini Extension', style: TextStyle(color: Colors.white54)),
                    trailing: const Text('5 km', style: TextStyle(color: Colors.white54)),
                    onTap: () => _openCategoryScreen(context),
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

class _CategoryItem {
  final IconData icon;
  final String label;

  const _CategoryItem({required this.icon, required this.label});
}

class _CategoryChip extends StatelessWidget {
  final _CategoryItem item;
  final bool isActive;

  const _CategoryChip({required this.item, this.isActive = false});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 78,
      height: 78,
      decoration: BoxDecoration(
        color: isActive ? Colors.amber : const Color(0xFF2A2A2A),
        shape: BoxShape.circle,
        border: Border.all(
          color: isActive ? Colors.amberAccent : Colors.white.withOpacity(0.14),
          width: 1.8,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: Colors.amber.withOpacity(0.3),
                  blurRadius: 12,
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
            size: 21,
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(
              color: isActive ? Colors.black : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

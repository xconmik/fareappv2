import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../theme/responsive.dart';
import '../services/ride_matching_service.dart';
import '../widgets/fare_map.dart';
import '../widgets/app_side_menu.dart';

enum LocationEditMode {
  pickup,
  destination,
}

class LocationMapSelectionScreen extends StatefulWidget {
  final LocationEditMode mode;
  final String requestId;
  final String currentName;
  final double? currentLat;
  final double? currentLng;

  const LocationMapSelectionScreen({
    Key? key,
    this.mode = LocationEditMode.destination,
    required this.requestId,
    required this.currentName,
    this.currentLat,
    this.currentLng,
  }) : super(key: key);

  @override
  State<LocationMapSelectionScreen> createState() => _LocationMapSelectionScreenState();
}

class _LocationMapSelectionScreenState extends State<LocationMapSelectionScreen> {
  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);
  GoogleMapController? _mapController;
  late TextEditingController _locationController;
  late double? _selectedLat;
  late double? _selectedLng;
  late LatLng _mapCenter;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _locationController = TextEditingController(text: widget.currentName);
    final hasLat = widget.currentLat != null && widget.currentLng != null;
    _mapCenter = hasLat
        ? LatLng(widget.currentLat!, widget.currentLng!)
        : _defaultCenter;
    _selectedLat = _mapCenter.latitude;
    _selectedLng = _mapCenter.longitude;
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _locationController.dispose();
    super.dispose();
  }

  String get _editTitle => widget.mode == LocationEditMode.pickup ? 'Edit Pickup' : 'Edit Destination';
  String get _adjustTitle => widget.mode == LocationEditMode.pickup ? 'Adjust pickup' : 'Adjust destination';

  Future<void> _saveLocation() async {
    if (_locationController.text.isEmpty) {
      return;
    }

    setState(() => _isSaving = true);
    try {
      final service = RideMatchingService();
      if (widget.mode == LocationEditMode.pickup) {
        await service.updatePickupLocation(
          requestId: widget.requestId,
          name: _locationController.text,
          lat: _selectedLat ?? widget.currentLat ?? 0,
          lng: _selectedLng ?? widget.currentLng ?? 0,
        );
      } else {
        await service.updateDestinationLocation(
          requestId: widget.requestId,
          name: _locationController.text,
          lat: _selectedLat ?? widget.currentLat ?? 0,
          lng: _selectedLng ?? widget.currentLng ?? 0,
        );
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        return;
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          Positioned.fill(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _mapCenter,
                    zoom: 15,
                  ),
                  cloudMapId: consoleCloudMapId,
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onCameraMove: (position) {
                    _mapCenter = position.target;
                  },
                  onCameraIdle: () {
                    _selectedLat = _mapCenter.latitude;
                    _selectedLng = _mapCenter.longitude;
                  },
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  compassEnabled: false,
                  tiltGesturesEnabled: false,
                ),
                const IgnorePointer(
                  child: Center(
                    child: Icon(Icons.location_on, color: Colors.redAccent, size: 36),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.only(left: r.space(12), right: r.space(12), top: r.space(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _editTitle,
                    style: TextStyle(color: Colors.white60, fontSize: r.font(12), fontWeight: FontWeight.w600),
                  ),
                  Container(
                    width: r.space(34),
                    height: r.space(34),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.menu, color: Colors.white70, size: r.icon(18)),
                      onPressed: () => showAppSideMenu(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(left: r.space(12), right: r.space(12)),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(r.radius(18)),
                  border: Border.all(color: Colors.white12),
                ),
                child: Padding(
                  padding: EdgeInsets.only(left: r.space(14), right: r.space(14), top: r.space(14)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _adjustTitle.replaceFirst(_adjustTitle[0], _adjustTitle[0].toUpperCase()),
                            style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                          ),
                          const Spacer(),
                          IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.close, color: Colors.white54, size: r.icon(16)),
                            onPressed: () => Navigator.pop(context),
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      SizedBox(height: r.space(12)),
                      Text(
                        'Zoom and pan in the map, or edit the location name below',
                        style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                      ),
                      SizedBox(height: r.space(12)),
                      TextField(
                        controller: _locationController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Location name',
                          hintStyle: const TextStyle(color: Colors.white38),
                          prefixIcon: const Icon(Icons.location_on, color: Colors.white54),
                          filled: true,
                          fillColor: const Color(0xFF262626),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.radius(10)),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.radius(10)),
                            borderSide: const BorderSide(color: Colors.white12),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(r.radius(10)),
                            borderSide: const BorderSide(color: Colors.white38),
                          ),
                        ),
                      ),
                      SizedBox(height: r.space(12)),
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
                            disabledBackgroundColor: Colors.grey,
                          ),
                          onPressed: _isSaving ? null : _saveLocation,
                          child: _isSaving
                              ? SizedBox(
                                  width: r.space(18),
                                  height: r.space(18),
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                                  ),
                                )
                              : const Text('Confirm'),
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
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/responsive.dart';
import '../theme/motion_presets.dart';
import '../widgets/fare_map.dart';
import '../widgets/app_side_menu.dart';
import '../services/ride_matching_service.dart';
import 'location_map_selection_screen.dart';

class BookingDetailsScreen extends StatefulWidget {
  final String? requestId;
  final bool embedded;
  final VoidCallback? onCloseRequested;
  final Future<LatLng?> Function()? embeddedMapCenterProvider;
  final ValueChanged<bool>? onEmbeddedAdjustingChanged;
  final ValueChanged<LatLng>? onEmbeddedAdjustTargetChanged;
  final ValueChanged<LatLng?>? onEmbeddedPickupPointChanged;
  final ValueChanged<LatLng?>? onEmbeddedDestinationPointChanged;
  final ValueChanged<bool?>? onEmbeddedAdjustPickupModeChanged;

  const BookingDetailsScreen({
    super.key,
    this.requestId,
    this.embedded = false,
    this.onCloseRequested,
    this.embeddedMapCenterProvider,
    this.onEmbeddedAdjustingChanged,
    this.onEmbeddedAdjustTargetChanged,
    this.onEmbeddedPickupPointChanged,
    this.onEmbeddedDestinationPointChanged,
    this.onEmbeddedAdjustPickupModeChanged,
  });

  @override
  State<BookingDetailsScreen> createState() => _BookingDetailsScreenState();
}

enum _BookingPanelMode {
  details,
  adjustPickup,
  adjustDestination,
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  int? _passengersOverride;
  _BookingPanelMode _panelMode = _BookingPanelMode.details;
  GoogleMapController? _mapController;
  LatLng? _mapCenter;
  double? _selectedLat;
  double? _selectedLng;
  String _adjustLocationName = '';
  bool _isConfirmingAdjust = false;
  LatLng? _lastReportedEmbeddedPickup;
  LatLng? _lastReportedEmbeddedDestination;

  void _closeBookingView() {
    if (widget.embedded) {
      widget.onEmbeddedAdjustingChanged?.call(false);
      widget.onEmbeddedAdjustPickupModeChanged?.call(null);
    }
    if (widget.embedded) {
      widget.onCloseRequested?.call();
      return;
    }
    Navigator.pop(context);
  }

  @override
  void dispose() {
    if (widget.embedded) {
      widget.onEmbeddedAdjustingChanged?.call(false);
      widget.onEmbeddedAdjustPickupModeChanged?.call(null);
    }
    _mapController?.dispose();
    super.dispose();
  }

  void _enterAdjustMode({
    required _BookingPanelMode mode,
    required String currentName,
    required double? currentLat,
    required double? currentLng,
    required LatLng fallback,
  }) {
    setState(() {
      _panelMode = mode;
      _adjustLocationName = currentName.trim().isNotEmpty
          ? currentName.trim()
          : (mode == _BookingPanelMode.adjustPickup ? 'Pickup' : 'Destination');
      _mapCenter = currentLat != null && currentLng != null ? LatLng(currentLat, currentLng) : fallback;
      _selectedLat = _mapCenter!.latitude;
      _selectedLng = _mapCenter!.longitude;
    });
    if (widget.embedded) {
      widget.onEmbeddedAdjustingChanged?.call(true);
      widget.onEmbeddedAdjustPickupModeChanged?.call(mode == _BookingPanelMode.adjustPickup);
      if (_mapCenter != null) {
        widget.onEmbeddedAdjustTargetChanged?.call(_mapCenter!);
      }
    }
  }

  void _exitAdjustMode() {
    if (mounted) {
      setState(() => _panelMode = _BookingPanelMode.details);
    }
    if (widget.embedded) {
      widget.onEmbeddedAdjustingChanged?.call(false);
      widget.onEmbeddedAdjustPickupModeChanged?.call(null);
    }
  }

  Future<void> _confirmAdjust(LocationEditMode mode) async {
    if (_isConfirmingAdjust) {
      return;
    }
    final requestId = widget.requestId;
    if (requestId == null) {
      return;
    }

    final name = _adjustLocationName;

    double? lat = _selectedLat;
    double? lng = _selectedLng;
    if (widget.embedded && widget.embeddedMapCenterProvider != null) {
      try {
        final center = await widget.embeddedMapCenterProvider!.call();
        if (center != null) {
          lat = center.latitude;
          lng = center.longitude;
        }
      } catch (_) {
        // Keep current selection fallback.
      }
    }
    if (lat == null || lng == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to determine map center. Try again.')),
        );
      }
      return;
    }

    final service = RideMatchingService();
    setState(() {
      _isConfirmingAdjust = true;
    });
    try {
      if (mode == LocationEditMode.pickup) {
        await service.updatePickupLocation(
          requestId: requestId,
          name: name,
          lat: lat,
          lng: lng,
        );
      } else {
        await service.updateDestinationLocation(
          requestId: requestId,
          name: name,
          lat: lat,
          lng: lng,
        );
      }
      if (!mounted) {
        return;
      }
      _exitAdjustMode();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update location: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isConfirmingAdjust = false;
        });
      }
    }
  }

  void _openLocationEditor({
    required _BookingPanelMode panelMode,
    required String currentName,
    required double? currentLat,
    required double? currentLng,
    required LatLng fallback,
  }) {
    _enterAdjustMode(
      mode: panelMode,
      currentName: currentName,
      currentLat: currentLat,
      currentLng: currentLng,
      fallback: fallback,
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    
    if (widget.requestId == null) {
      if (widget.embedded) {
        return Container(
          color: const Color(0xFF1C1C1E),
          alignment: Alignment.center,
          child: Text(
            'No booking details available',
            style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
          ),
        );
      }

      return Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1C1C1E),
          elevation: 0,
          title: const Text('Booking', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child: Text(
            'No booking details available',
            style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
          ),
        ),
      );
    }
    
    final bookingContent = StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('ride_requests').doc(widget.requestId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }

          final data = snapshot.data!.data();
          if (data == null) {
            return Center(
              child: Text(
                'Booking not found',
                style: TextStyle(color: Colors.white70, fontSize: r.font(12)),
              ),
            );
          }

          final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
          final destination = data['destination'] as Map<String, dynamic>? ?? {};
          final routeSummary = data['routeSummary'] as String? ?? 'Ready at the pickup spot';
          final fare = data['fare'] as num? ?? 0;
          final status = data['status'] as String? ?? 'pending';
          final passengers = data['passengers'] as int? ?? 2;
          final displayPassengers = (_passengersOverride ?? passengers).clamp(1, 3);
          final canDecrease = displayPassengers > 1;
          final canIncrease = displayPassengers < 3;
          final etaMinutes = data['etaMinutes'] as num?;
          final distanceKm = data['distanceKm'] as num?;
          final etaText = etaMinutes != null ? '${etaMinutes.toStringAsFixed(0)} min' : '-- min';
          final distanceText = distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '-- km';
          final pickupName = pickup['name'] as String? ?? pickup['title'] as String? ?? 'Pickup';
          final destinationName = destination['name'] as String? ?? destination['title'] as String? ?? 'Destination';
          final pickupLat = (pickup['lat'] as num?)?.toDouble();
          final pickupLng = (pickup['lng'] as num?)?.toDouble();
          final destinationLat = (destination['lat'] as num?)?.toDouble();
          final destinationLng = (destination['lng'] as num?)?.toDouble();
          final hasPickup = pickupLat != null && pickupLng != null;
          final hasDestination = destinationLat != null && destinationLng != null;
          final pickupPoint = hasPickup ? LatLng(pickupLat, pickupLng) : null;
          final destinationPoint = hasDestination ? LatLng(destinationLat, destinationLng) : null;

          if (widget.embedded) {
            if (_lastReportedEmbeddedPickup != pickupPoint) {
              _lastReportedEmbeddedPickup = pickupPoint;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                widget.onEmbeddedPickupPointChanged?.call(pickupPoint);
              });
            }
            if (_lastReportedEmbeddedDestination != destinationPoint) {
              _lastReportedEmbeddedDestination = destinationPoint;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) {
                  return;
                }
                widget.onEmbeddedDestinationPointChanged?.call(destinationPoint);
              });
            }
          }
          final isAdjusting = _panelMode != _BookingPanelMode.details;
          final adjustMode = _panelMode == _BookingPanelMode.adjustPickup
              ? LocationEditMode.pickup
              : LocationEditMode.destination;
          final adjustTitle = _panelMode == _BookingPanelMode.adjustPickup
              ? 'Adjust pickup'
              : 'Adjust destination';
          const fallbackTarget = LatLng(14.5995, 120.9842);
          final mapTarget = hasPickup && hasDestination
              ? LatLng(
                  (pickupLat + destinationLat) / 2,
                  (pickupLng + destinationLng) / 2,
                )
              : hasPickup
                  ? pickupPoint!
                  : hasDestination
                      ? destinationPoint!
                      : fallbackTarget;
          final adjustTarget = _mapCenter ?? mapTarget;
          final markers = <Marker>{
            if (!isAdjusting && pickupPoint != null)
              Marker(
                markerId: const MarkerId('pickup'),
                position: pickupPoint,
                infoWindow: InfoWindow(title: pickupName),
              ),
            if (!isAdjusting && destinationPoint != null)
              Marker(
                markerId: const MarkerId('destination'),
                position: destinationPoint,
                infoWindow: InfoWindow(title: destinationName),
              ),
            if (isAdjusting)
              Marker(
                markerId: const MarkerId('adjust_pin'),
                position: adjustTarget,
                draggable: true,
                onDragEnd: (position) {
                  if (!mounted) {
                    return;
                  }
                  setState(() {
                    _mapCenter = position;
                    _selectedLat = position.latitude;
                    _selectedLng = position.longitude;
                  });
                },
              ),
          };
          final polylines = <Polyline>{
            if (!isAdjusting && pickupPoint != null && destinationPoint != null)
              Polyline(
                polylineId: const PolylineId('route'),
                color: Colors.white.withValues(alpha: 0.6),
                width: 4,
                points: [
                  pickupPoint,
                  destinationPoint,
                ],
              ),
          };
          Widget buildStopRow({
            required String label,
            required String name,
            VoidCallback? onTap,
          }) {
            return InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(r.radius(10)),
              child: Padding(
                padding: EdgeInsets.only(top: r.space(4)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.location_on, color: Colors.white54, size: r.icon(14)),
                    SizedBox(width: r.space(8)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: r.space(2)),
                          if (onTap != null)
                            Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white38, size: r.icon(10)),
                                SizedBox(width: r.space(4)),
                                Text(
                                  label,
                                  style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                                ),
                              ],
                            )
                          else
                            Text(
                              label,
                              style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return Stack(
            children: [
              if (!widget.embedded)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F0F10),
                    ),
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: isAdjusting ? adjustTarget : mapTarget,
                        zoom: isAdjusting ? 16 : (hasPickup || hasDestination ? 14 : 5),
                      ),
                      markers: markers,
                      polylines: polylines,
                      style: fareMapStyle,
                      onMapCreated: (controller) {
                        _mapController = controller;
                      },
                      onCameraMove: _panelMode == _BookingPanelMode.details
                          ? null
                          : (position) {
                              _mapCenter = position.target;
                            },
                      onCameraIdle: _panelMode == _BookingPanelMode.details
                          ? null
                          : () {
                              if (_mapCenter == null) {
                                return;
                              }
                              _selectedLat = _mapCenter!.latitude;
                              _selectedLng = _mapCenter!.longitude;
                            },
                      onTap: _panelMode == _BookingPanelMode.details
                          ? null
                          : (position) {
                              if (!mounted) {
                                return;
                              }
                              setState(() {
                                _mapCenter = position;
                                _selectedLat = position.latitude;
                                _selectedLng = position.longitude;
                              });
                            },
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      tiltGesturesEnabled: false,
                    ),
                  ),
                ),
              if (!widget.embedded && !isAdjusting)
                Positioned(
                  top: r.space(16),
                  left: r.space(16),
                  child: Text(
                    status == 'assigned' ? 'Booked' : 'Book',
                    style: TextStyle(color: Colors.white70, fontSize: r.font(12), fontWeight: FontWeight.w600),
                  ),
                ),
              if (!widget.embedded && !isAdjusting)
                Positioned(
                  top: r.space(12),
                  right: r.space(12),
                  child: Container(
                    width: r.space(36),
                    height: r.space(36),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.menu, color: Colors.white70, size: r.icon(18)),
                      onPressed: () => showAppSideMenu(context),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: widget.embedded ? 0 : r.space(12),
                    right: widget.embedded ? 0 : r.space(12),
                    bottom: widget.embedded ? 0 : 0,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A1A),
                      borderRadius: widget.embedded
                          ? BorderRadius.only(
                              topLeft: Radius.circular(r.radius(16)),
                              topRight: Radius.circular(r.radius(16)),
                            )
                          : BorderRadius.circular(r.radius(18)),
                      border: Border.all(
                        color: widget.embedded ? Colors.transparent : Colors.white12,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: widget.embedded ? r.space(14) : r.space(14),
                        right: widget.embedded ? r.space(14) : r.space(14),
                        top: widget.embedded ? r.space(12) : r.space(14),
                        bottom: widget.embedded
                            ? MediaQuery.of(context).padding.bottom + r.space(10)
                            : r.space(10),
                      ),
                      child: AnimatedSwitcher(
                          duration: kAppMotion.switcher,
                          switchInCurve: Curves.easeInOutCubic,
                          switchOutCurve: Curves.easeInOutCubic,
                          transitionBuilder: (child, animation) {
                            final offset = Tween<Offset>(
                              begin: const Offset(0, 0.04),
                              end: Offset.zero,
                            ).animate(animation);
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(position: offset, child: child),
                            );
                          },
                          child: KeyedSubtree(
                            key: ValueKey<bool>(isAdjusting),
                            child: isAdjusting
                          ? SingleChildScrollView(
                            child: _buildAdjustPanel(r, adjustTitle, adjustMode),
                          )
                          : (widget.embedded
                              ? SingleChildScrollView(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                          Row(
                            children: [
                              Text(
                                etaText,
                                style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: r.space(8)),
                              Text(
                                distanceText,
                                style: TextStyle(color: Colors.white70, fontSize: r.font(11)),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _closeBookingView,
                                icon: Icon(Icons.close, color: Colors.white70, size: r.icon(16)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          SizedBox(height: r.space(2)),
                          Text(routeSummary, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF202020),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: r.space(12),
                                right: r.space(12),
                                top: widget.embedded ? r.space(10) : r.space(12),
                                bottom: widget.embedded ? r.space(10) : r.space(12),
                              ),
                              child: Column(
                                children: [
                                  buildStopRow(
                                    label: 'Pickup',
                                    name: pickupName,
                                    onTap: () => _openLocationEditor(
                                      panelMode: _BookingPanelMode.adjustPickup,
                                      currentName: pickupName,
                                      currentLat: (pickup['lat'] as num?)?.toDouble(),
                                      currentLng: (pickup['lng'] as num?)?.toDouble(),
                                      fallback: fallbackTarget,
                                    ),
                                  ),
                                  SizedBox(height: r.space(10)),
                                  buildStopRow(
                                    label: 'Destination',
                                    name: destinationName,
                                    onTap: () => _openLocationEditor(
                                      panelMode: _BookingPanelMode.adjustDestination,
                                      currentName: destinationName,
                                      currentLat: (destination['lat'] as num?)?.toDouble(),
                                      currentLng: (destination['lng'] as num?)?.toDouble(),
                                      fallback: fallbackTarget,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Row(
                            children: [
                              Text('Passengers', style: TextStyle(color: Colors.white70, fontSize: r.font(11), fontWeight: FontWeight.w600)),
                              const Spacer(),
                              InkWell(
                                onTap: canDecrease
                                    ? () async {
                                          final newCount = displayPassengers - 1;
                                          setState(() {
                                            _passengersOverride = newCount;
                                          });
                                          await RideMatchingService().updatePassengers(
                                            requestId: widget.requestId!,
                                            passengers: newCount,
                                          );
                                        }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: r.space(26),
                                  height: r.space(26),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: canDecrease ? Colors.white54 : Colors.white24,
                                    size: r.icon(14),
                                  ),
                                ),
                              ),
                              SizedBox(width: r.space(8)),
                              Text(
                                '$displayPassengers',
                                style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: r.space(8)),
                              InkWell(
                                onTap: canIncrease
                                    ? () async {
                                          final newCount = displayPassengers + 1;
                                          setState(() {
                                            _passengersOverride = newCount;
                                          });
                                          await RideMatchingService().updatePassengers(
                                            requestId: widget.requestId!,
                                            passengers: newCount,
                                          );
                                        }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: r.space(26),
                                  height: r.space(26),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: canIncrease ? Colors.white54 : Colors.white24,
                                    size: r.icon(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  double? customFare;
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: const Color(0xFF1A1A1A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(r.radius(16)),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.only(left: r.space(16), right: r.space(16), top: r.space(16)),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Price',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: r.font(13),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: Icon(Icons.close, color: Colors.white54, size: r.icon(16)),
                                                  onPressed: () => Navigator.pop(context),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: r.space(12)),
                                            TextField(
                                              style: TextStyle(color: Colors.white, fontSize: r.font(12)),
                                              decoration: InputDecoration(
                                                hintText: 'Enter Amount...',
                                                hintStyle: TextStyle(color: Colors.white38, fontSize: r.font(12)),
                                                filled: true,
                                                fillColor: const Color(0xFF262626),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white12),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white12),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white38),
                                                ),
                                                contentPadding: EdgeInsets.only(
                                                  left: r.space(12),
                                                  right: r.space(12),
                                                  top: r.space(10),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                customFare = double.tryParse(value);
                                              },
                                            ),
                                            SizedBox(height: r.space(12)),
                                            Text(
                                              'Know fare est dispatch ideal from time',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: r.font(10),
                                              ),
                                            ),
                                            SizedBox(height: r.space(12)),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _buildFareOption(r, 50.0),
                                                _buildFareOption(r, 60.0),
                                                _buildFareOption(r, 70.0),
                                              ],
                                            ),
                                            SizedBox(height: r.space(16)),
                                            SizedBox(
                                              width: double.infinity,
                                              height: r.space(44),
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF3A3A3C),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(r.radius(10)),
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  if (customFare != null && customFare! > 0) {
                                                    await RideMatchingService().updateFare(
                                                      requestId: widget.requestId!,
                                                      fare: customFare!,
                                                    );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    Navigator.pop(context);
                                                  } else {
                                                    return;
                                                  }
                                                },
                                                child: const Text('Confirm'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(r.radius(8)),
                                child: Padding(
                                  padding: EdgeInsets.only(top: r.space(2)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₱ ${fare.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: r.font(16),
                                        ),
                                      ),
                                      SizedBox(height: r.space(2)),
                                      Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: r.font(11),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: widget.embedded ? r.space(116) : null,
                                height: r.space(36),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: status == 'searching'
                                        ? const Color(0xFF2C2C2E)
                                        : const Color(0xFF3A3A3C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(r.radius(12)),
                                    ),
                                  ),
                                  onPressed: status == 'searching'
                                      ? () async {
                                          if (widget.requestId == null) {
                                            return;
                                          }
                                          await RideMatchingService().acceptRideRequest(widget.requestId!);
                                        }
                                      : null,
                                  child: Text(status == 'assigned' ? 'Confirmed' : 'Book'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                                )
                              : Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                          Row(
                            children: [
                              Text(
                                etaText,
                                style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w700),
                              ),
                              SizedBox(width: r.space(8)),
                              Text(
                                distanceText,
                                style: TextStyle(color: Colors.white70, fontSize: r.font(11)),
                              ),
                              const Spacer(),
                              IconButton(
                                onPressed: _closeBookingView,
                                icon: Icon(Icons.close, color: Colors.white70, size: r.icon(16)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                          SizedBox(height: r.space(2)),
                          Text(routeSummary, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF202020),
                              borderRadius: BorderRadius.circular(r.radius(12)),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: r.space(12),
                                right: r.space(12),
                                top: widget.embedded ? r.space(10) : r.space(12),
                                bottom: widget.embedded ? r.space(10) : r.space(12),
                              ),
                              child: Column(
                                children: [
                                  buildStopRow(
                                    label: 'Pickup',
                                    name: pickupName,
                                    onTap: () => _openLocationEditor(
                                      panelMode: _BookingPanelMode.adjustPickup,
                                      currentName: pickupName,
                                      currentLat: (pickup['lat'] as num?)?.toDouble(),
                                      currentLng: (pickup['lng'] as num?)?.toDouble(),
                                      fallback: fallbackTarget,
                                    ),
                                  ),
                                  SizedBox(height: r.space(10)),
                                  buildStopRow(
                                    label: 'Destination',
                                    name: destinationName,
                                    onTap: () => _openLocationEditor(
                                      panelMode: _BookingPanelMode.adjustDestination,
                                      currentName: destinationName,
                                      currentLat: (destination['lat'] as num?)?.toDouble(),
                                      currentLng: (destination['lng'] as num?)?.toDouble(),
                                      fallback: fallbackTarget,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Row(
                            children: [
                              Text('Passengers', style: TextStyle(color: Colors.white70, fontSize: r.font(11), fontWeight: FontWeight.w600)),
                              const Spacer(),
                              InkWell(
                                onTap: canDecrease
                                    ? () async {
                                          final newCount = displayPassengers - 1;
                                          setState(() {
                                            _passengersOverride = newCount;
                                          });
                                          await RideMatchingService().updatePassengers(
                                            requestId: widget.requestId!,
                                            passengers: newCount,
                                          );
                                        }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: r.space(26),
                                  height: r.space(26),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    Icons.remove,
                                    color: canDecrease ? Colors.white54 : Colors.white24,
                                    size: r.icon(14),
                                  ),
                                ),
                              ),
                              SizedBox(width: r.space(8)),
                              Text(
                                '$displayPassengers',
                                style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                              ),
                              SizedBox(width: r.space(8)),
                              InkWell(
                                onTap: canIncrease
                                    ? () async {
                                          final newCount = displayPassengers + 1;
                                          setState(() {
                                            _passengersOverride = newCount;
                                          });
                                          await RideMatchingService().updatePassengers(
                                            requestId: widget.requestId!,
                                            passengers: newCount,
                                          );
                                        }
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  width: r.space(26),
                                  height: r.space(26),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF262626),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    Icons.add,
                                    color: canIncrease ? Colors.white54 : Colors.white24,
                                    size: r.icon(14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: widget.embedded ? r.space(8) : r.space(10)),
                          Row(
                            children: [
                              InkWell(
                                onTap: () {
                                  double? customFare;
                                  showDialog(
                                    context: context,
                                    builder: (context) => Dialog(
                                      backgroundColor: const Color(0xFF1A1A1A),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(r.radius(16)),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.only(left: r.space(16), right: r.space(16), top: r.space(16)),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Price',
                                                  style: TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: r.font(13),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                IconButton(
                                                  padding: EdgeInsets.zero,
                                                  constraints: const BoxConstraints(),
                                                  icon: Icon(Icons.close, color: Colors.white54, size: r.icon(16)),
                                                  onPressed: () => Navigator.pop(context),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: r.space(12)),
                                            TextField(
                                              style: TextStyle(color: Colors.white, fontSize: r.font(12)),
                                              decoration: InputDecoration(
                                                hintText: 'Enter Amount...',
                                                hintStyle: TextStyle(color: Colors.white38, fontSize: r.font(12)),
                                                filled: true,
                                                fillColor: const Color(0xFF262626),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white12),
                                                ),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white12),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(r.radius(8)),
                                                  borderSide: const BorderSide(color: Colors.white38),
                                                ),
                                                contentPadding: EdgeInsets.only(
                                                  left: r.space(12),
                                                  right: r.space(12),
                                                  top: r.space(10),
                                                ),
                                              ),
                                              onChanged: (value) {
                                                customFare = double.tryParse(value);
                                              },
                                            ),
                                            SizedBox(height: r.space(12)),
                                            Text(
                                              'Know fare est dispatch ideal from time',
                                              style: TextStyle(
                                                color: Colors.white54,
                                                fontSize: r.font(10),
                                              ),
                                            ),
                                            SizedBox(height: r.space(12)),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                _buildFareOption(r, 50.0),
                                                _buildFareOption(r, 60.0),
                                                _buildFareOption(r, 70.0),
                                              ],
                                            ),
                                            SizedBox(height: r.space(16)),
                                            SizedBox(
                                              width: double.infinity,
                                              height: r.space(44),
                                              child: ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(0xFF3A3A3C),
                                                  foregroundColor: Colors.white,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius: BorderRadius.circular(r.radius(10)),
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  if (customFare != null && customFare! > 0) {
                                                    await RideMatchingService().updateFare(
                                                      requestId: widget.requestId!,
                                                      fare: customFare!,
                                                    );
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    Navigator.pop(context);
                                                  } else {
                                                    return;
                                                  }
                                                },
                                                child: const Text('Confirm'),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(r.radius(8)),
                                child: Padding(
                                  padding: EdgeInsets.only(top: r.space(2)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '₱ ${fare.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: r.font(16),
                                        ),
                                      ),
                                      SizedBox(height: r.space(2)),
                                      Text(
                                        'Tap to change',
                                        style: TextStyle(
                                          color: Colors.blueAccent,
                                          fontSize: r.font(11),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              SizedBox(
                                width: widget.embedded ? r.space(116) : null,
                                height: r.space(36),
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: status == 'searching'
                                        ? const Color(0xFF2C2C2E)
                                        : const Color(0xFF3A3A3C),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(r.radius(12)),
                                    ),
                                  ),
                                  onPressed: status == 'searching'
                                      ? () async {
                                          if (widget.requestId == null) {
                                            return;
                                          }
                                          await RideMatchingService().acceptRideRequest(widget.requestId!);
                                        }
                                      : null,
                                  child: Text(status == 'assigned' ? 'Confirmed' : 'Book'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      )))),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

    if (widget.embedded) {
      return bookingContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: bookingContent,
    );
  }

  Widget _buildFareOption(Responsive r, double amount) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: r.space(4)),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Colors.white24),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(r.radius(8)),
            ),
            padding: EdgeInsets.only(top: r.space(8)),
          ),
          onPressed: () async {
            if (widget.requestId == null) {
              Navigator.pop(context);
              return;
            }

            await RideMatchingService().updateFare(
              requestId: widget.requestId!,
              fare: amount,
            );

            if (!mounted) {
              return;
            }

            Navigator.pop(context);
          },
          child: Text(
            '₱${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: r.font(12),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAdjustPanel(Responsive r, String title, LocationEditMode mode) {
    final verticalGap = widget.embedded ? r.space(8) : r.space(12);
    final actionHeight = widget.embedded ? r.space(36) : r.space(40);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title.replaceFirst(title[0], title[0].toUpperCase()),
              style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(Icons.close, color: Colors.white54, size: r.icon(16)),
              onPressed: _exitAdjustMode,
            ),
          ],
        ),
        SizedBox(height: r.space(12)),
        Text(
          widget.embedded
              ? 'Drag or tap the pin on the map, then confirm.'
              : 'Drag the pin to the exact point or tap the map, then confirm.',
          style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
        ),
        SizedBox(height: verticalGap),
        SizedBox(
          width: double.infinity,
          height: actionHeight,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3A3A3C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r.radius(10)),
              ),
            ),
            onPressed: _isConfirmingAdjust ? null : () => _confirmAdjust(mode),
            child: _isConfirmingAdjust
                ? SizedBox(
                    width: r.space(16),
                    height: r.space(16),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Confirm'),
          ),
        ),
      ],
    );
  }
}
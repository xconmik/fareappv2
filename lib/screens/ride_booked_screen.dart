import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../services/ride_matching_service.dart';
import '../theme/motion_presets.dart';
import '../theme/responsive.dart';
import '../widgets/fare_map.dart';
import '../widgets/app_side_menu.dart';

class RideBookedScreen extends StatefulWidget {
  const RideBookedScreen({Key? key, required this.requestId}) : super(key: key);

  final String requestId;

  @override
  State<RideBookedScreen> createState() => _RideBookedScreenState();
}

class _RideBookedScreenState extends State<RideBookedScreen> {
  static const Duration _snakeFrameInterval = Duration(milliseconds: 85);
  static const double _snakeStep = 0.028;
  static const double _snakeSegmentLength = 0.24;

  Timer? _simTimer;
  Timer? _routeSnakeTimer;
  double _simProgress = 0.0;
  final ValueNotifier<double> _routeSnakeProgress = ValueNotifier<double>(_snakeSegmentLength);
  LatLng? _simStart;
  LatLng? _simEnd;
  LatLng? _simulatedDriverPosition;
  LatLng? _routeSnakeStart;
  LatLng? _routeSnakeEnd;

  @override
  void dispose() {
    _simTimer?.cancel();
    _routeSnakeTimer?.cancel();
    _routeSnakeProgress.dispose();
    super.dispose();
  }

  void _startRouteSnakeAnimation({required LatLng start, required LatLng end}) {
    final sameRoute = _routeSnakeStart == start && _routeSnakeEnd == end;
    _routeSnakeStart = start;
    _routeSnakeEnd = end;

    if (!sameRoute) {
      _routeSnakeProgress.value = _snakeSegmentLength;
    }

    if (_routeSnakeTimer != null) {
      return;
    }

    _routeSnakeTimer = Timer.periodic(_snakeFrameInterval, (_) {
      if (!mounted || _routeSnakeTimer == null) {
        return;
      }
      final next = _routeSnakeProgress.value + _snakeStep;
      _routeSnakeProgress.value =
          next >= 1.0 + _snakeSegmentLength ? _snakeSegmentLength : next;
    });
  }

  void _stopRouteSnakeAnimation() {
    _routeSnakeTimer?.cancel();
    _routeSnakeTimer = null;
    _routeSnakeStart = null;
    _routeSnakeEnd = null;
    _routeSnakeProgress.value = _snakeSegmentLength;
  }

  LatLng _lerpLatLng(LatLng start, LatLng end, double t) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * t,
      start.longitude + (end.longitude - start.longitude) * t,
    );
  }

  List<List<LatLng>> _buildSnakeSegments(LatLng start, LatLng end, double progress) {
    final tailT = progress - _snakeSegmentLength;
    final headT = progress;

    if (headT <= 1.0) {
      return [
        [
          _lerpLatLng(start, end, tailT.clamp(0.0, 1.0)),
          _lerpLatLng(start, end, headT.clamp(0.0, 1.0)),
        ],
      ];
    }

    final wrappedHead = headT - 1.0;
    return [
      [
        _lerpLatLng(start, end, tailT.clamp(0.0, 1.0)),
        _lerpLatLng(start, end, 1.0),
      ],
      [
        _lerpLatLng(start, end, 0.0),
        _lerpLatLng(start, end, wrappedHead.clamp(0.0, 1.0)),
      ],
    ];
  }

  void _startSimulation({required LatLng start, required LatLng end}) {
    if (_simTimer != null) {
      return;
    }

    _simStart = start;
    _simEnd = end;
    _simProgress = 0.0;
    _simulatedDriverPosition = start;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
      _simTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted || _simStart == null || _simEnd == null) {
          return;
        }
        setState(() {
          _simProgress += 0.04;
          if (_simProgress >= 1.0) {
            _simProgress = 0.0;
          }
          final lat = _simStart!.latitude + (_simEnd!.latitude - _simStart!.latitude) * _simProgress;
          final lng = _simStart!.longitude + (_simEnd!.longitude - _simStart!.longitude) * _simProgress;
          _simulatedDriverPosition = LatLng(lat, lng);
        });
      });
    });
  }

  void _stopSimulation() {
    _simTimer?.cancel();
    _simTimer = null;
    _simulatedDriverPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final service = RideMatchingService();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: Stack(
        children: [
          // Static black map - only changes markers/polylines on small updates
          Positioned.fill(
            child: _buildMap(context, service),
          ),
          // Dynamic header and container - only these rebuild on data changes
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: service.watchRideRequest(widget.requestId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final data = snapshot.data!.data();
              if (data == null) {
                return const Center(
                  child: Text('Booking not found', style: TextStyle(color: Colors.white70)),
                );
              }

              return _buildDynamicContent(context, data, service);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, RideMatchingService service) {
    const fallbackTarget = LatLng(14.5995, 120.9842);

    return ValueListenableBuilder<double>(
      valueListenable: _routeSnakeProgress,
      builder: (context, snakeProgress, _) {
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: service.watchRideRequest(widget.requestId),
          builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const FareMap(
            target: fallbackTarget,
            zoom: 5,
            markers: {},
            polylines: {},
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            compassEnabled: false,
            tiltGesturesEnabled: false,
          );
        }

        final data = snapshot.data!.data() ?? {};
        final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
        final destination = data['destination'] as Map<String, dynamic>? ?? {};
        final status = data['status'] as String? ?? 'searching';
        final driverLat = (data['driverLat'] as num?)?.toDouble();
        final driverLng = (data['driverLng'] as num?)?.toDouble();

        final pickupName = pickup['name'] as String? ?? pickup['title'] as String? ?? 'Pickup';
        final destinationName = destination['name'] as String? ?? destination['title'] as String? ?? 'Destination';
        final pickupLat = (pickup['lat'] as num?)?.toDouble();
        final pickupLng = (pickup['lng'] as num?)?.toDouble();
        final destinationLat = (destination['lat'] as num?)?.toDouble();
        final destinationLng = (destination['lng'] as num?)?.toDouble();
        final hasPickup = pickupLat != null && pickupLng != null;
        final hasDestination = destinationLat != null && destinationLng != null;
        final hasDriverLocation = driverLat != null && driverLng != null;
        final isAssigned = status == 'assigned';

        final mapTarget = hasPickup && hasDestination
            ? LatLng(
                (pickupLat! + destinationLat!) / 2,
                (pickupLng! + destinationLng!) / 2,
              )
            : hasPickup
                ? LatLng(pickupLat!, pickupLng!)
                : hasDestination
                    ? LatLng(destinationLat!, destinationLng!)
                    : fallbackTarget;

        if (hasPickup && hasDestination) {
          _startRouteSnakeAnimation(
            start: LatLng(pickupLat!, pickupLng!),
            end: LatLng(destinationLat!, destinationLng!),
          );
        } else {
          _stopRouteSnakeAnimation();
        }

        if (isAssigned && !hasDriverLocation && hasPickup && hasDestination) {
          _startSimulation(
            start: LatLng(pickupLat!, pickupLng!),
            end: LatLng(destinationLat!, destinationLng!),
          );
        } else if (!isAssigned || hasDriverLocation) {
          _stopSimulation();
        }

        final driverPosition = hasDriverLocation
            ? LatLng(driverLat!, driverLng!)
            : _simulatedDriverPosition;

        final snakeSegments = hasPickup && hasDestination
            ? _buildSnakeSegments(
                LatLng(pickupLat!, pickupLng!),
                LatLng(destinationLat!, destinationLng!),
                snakeProgress,
              )
            : const <List<LatLng>>[];

        final markers = <Marker>{
          if (hasPickup)
            Marker(
              markerId: const MarkerId('pickup'),
              position: LatLng(pickupLat!, pickupLng!),
              infoWindow: InfoWindow(title: pickupName),
            ),
          if (hasDestination)
            Marker(
              markerId: const MarkerId('destination'),
              position: LatLng(destinationLat!, destinationLng!),
              infoWindow: InfoWindow(title: destinationName),
            ),
          if (isAssigned && driverPosition != null)
            Marker(
              markerId: const MarkerId('driver'),
              position: driverPosition,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'Driver'),
            ),
        };

        final polylines = <Polyline>{
          if (hasPickup && hasDestination)
            Polyline(
              polylineId: const PolylineId('route'),
              color: Colors.white.withValues(alpha: 0.35),
              width: 5,
              points: [
                LatLng(pickupLat!, pickupLng!),
                LatLng(destinationLat!, destinationLng!),
              ],
            ),
          for (var i = 0; i < snakeSegments.length; i++)
            Polyline(
              polylineId: PolylineId('route_snake_glow_$i'),
              color: Colors.white.withValues(alpha: 0.42),
              width: 10,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              points: snakeSegments[i],
            ),
          for (var i = 0; i < snakeSegments.length; i++)
            Polyline(
              polylineId: PolylineId('route_snake_core_$i'),
              color: Colors.white,
              width: 6,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              points: snakeSegments[i],
            ),
        };

        return FareMap(
          target: mapTarget,
          zoom: hasPickup || hasDestination ? 14 : 5,
          markers: markers,
          polylines: polylines,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
          mapToolbarEnabled: false,
          compassEnabled: false,
          tiltGesturesEnabled: false,
        );
          },
        );
      },
    );
  }

  Widget _buildDynamicContent(
    BuildContext context,
    Map<String, dynamic> data,
    RideMatchingService service,
  ) {
    final r = Responsive.of(context);
    final pickup = data['pickup'] as Map<String, dynamic>? ?? {};
    final destination = data['destination'] as Map<String, dynamic>? ?? {};
    final fare = data['fare'] as num? ?? 0;
    final status = data['status'] as String? ?? 'searching';
    final etaMinutes = data['etaMinutes'] as num?;
    final distanceKm = data['distanceKm'] as num?;
    final driverName = data['driverName'] as String?;
    final driverRating = (data['driverRating'] as num?)?.toDouble();
    final driverStickerNo = data['driverStickerNo'] as String?;

    final pickupName = pickup['name'] as String? ?? pickup['title'] as String? ?? 'Pickup';
    final destinationName = destination['name'] as String? ?? destination['title'] as String? ?? 'Destination';
    final isAssigned = status == 'assigned';

    final etaText = etaMinutes != null ? '${etaMinutes.toStringAsFixed(0)} min' : '-- min';
    final distanceText = distanceKm != null ? '${distanceKm.toStringAsFixed(1)} km' : '-- km';
    final displayDriverName = driverName ?? 'Assigned Driver';
    final displayDriverRating = driverRating ?? 5.0;
    final displayStickerNo = driverStickerNo ?? 'STRK-05';

    return Stack(
      children: [
        SafeArea(
          child: Padding(
            padding: EdgeInsets.only(left: r.space(16), right: r.space(16), top: r.space(12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isAssigned ? 'Driver OTW' : 'Ride Booked',
                  style: TextStyle(color: Colors.white70, fontSize: r.font(12), fontWeight: FontWeight.w600),
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
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(r.radius(18)),
                topRight: Radius.circular(r.radius(18)),
              ),
              border: Border.all(color: Colors.white12),
            ),
            child: Padding(
              padding: EdgeInsets.only(top: r.space(14)),
              child: AnimatedSwitcher(
                duration: kAppMotion.switcher,
                transitionBuilder: (child, animation) {
                  final inTween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero);
                  final outTween = Tween<Offset>(begin: Offset.zero, end: const Offset(-1, 0));
                  final tween = animation.status == AnimationStatus.reverse ? outTween : inTween;
                  return SlideTransition(position: animation.drive(tween), child: child);
                },
                child: ConstrainedBox(
                  key: ValueKey('${status}_${fare}_${etaMinutes ?? '--'}_${distanceKm ?? '--'}'),
                  constraints: BoxConstraints(maxHeight: r.space(280)),
                  child: Padding(
                    padding: EdgeInsets.only(left: r.space(20), right: r.space(20)),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                      isAssigned
                          ? (etaMinutes != null
                              ? 'Arriving in ${etaMinutes.toStringAsFixed(0)} min'
                              : 'Arriving soon')
                          : 'Your ride is booked!',
                      style: TextStyle(color: Colors.white, fontSize: r.font(14), fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: r.space(3)),
                    Text(
                      isAssigned
                          ? 'Don\'t forget your belongings'
                          : 'We will find you a driver as fast as possible',
                      style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                    ),
                    if (isAssigned) ...[
                      SizedBox(height: r.space(12)),
                      Container(
                        padding: EdgeInsets.only(left: r.space(10), right: r.space(10), top: r.space(10)),
                        decoration: BoxDecoration(
                          color: const Color(0xFF232323),
                          borderRadius: BorderRadius.circular(r.radius(12)),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: r.space(34),
                              height: r.space(34),
                              decoration: const BoxDecoration(
                                color: Color(0xFF3A3A3A),
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: r.space(10)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayDriverName,
                                    style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                                  ),
                                  SizedBox(height: r.space(2)),
                                  Row(
                                    children: [
                                      Icon(Icons.star, color: const Color(0xFFC9B469), size: r.icon(12)),
                                      SizedBox(width: r.space(4)),
                                      Text(
                                        displayDriverRating.toStringAsFixed(1),
                                        style: TextStyle(color: Colors.white70, fontSize: r.font(10)),
                                      ),
                                      SizedBox(width: r.space(8)),
                                      Text(
                                        'Sticker No: $displayStickerNo',
                                        style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: r.space(12)),
                    Container(
                      padding: EdgeInsets.only(left: r.space(12), right: r.space(12), top: r.space(12)),
                      decoration: BoxDecoration(
                        color: const Color(0xFF232323),
                        borderRadius: BorderRadius.circular(r.radius(12)),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pickupName,
                            style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: r.space(2)),
                          Text(
                            isAssigned && etaMinutes != null
                                ? 'Your driver arrives in ${etaMinutes.toStringAsFixed(0)} min'
                                : 'Pickup',
                            style: TextStyle(color: Colors.white54, fontSize: r.font(10)),
                          ),
                          SizedBox(height: r.space(10)),
                          Text(
                            destinationName,
                            style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: r.space(2)),
                          Text('Destination', style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
                        ],
                      ),
                    ),
                    SizedBox(height: r.space(12)),
                    Row(
                      children: [
                        Text(
                          'Pay',
                          style: TextStyle(color: Colors.white70, fontSize: r.font(12), fontWeight: FontWeight.w600),
                        ),
                        SizedBox(width: r.space(6)),
                        Icon(Icons.chevron_right, color: Colors.white54, size: r.icon(14)),
                        const Spacer(),
                        Text(
                          '₱ ${fare.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.white, fontSize: r.font(12), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    if (etaMinutes != null || distanceKm != null) ...[
                      SizedBox(height: r.space(10)),
                      Row(
                        children: [
                          Text(etaText, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
                          SizedBox(width: r.space(12)),
                          Text(distanceText, style: TextStyle(color: Colors.white54, fontSize: r.font(10))),
                        ],
                      ),
                    ],
                    SizedBox(height: r.space(12)),
                    SizedBox(
                      width: double.infinity,
                      height: r.space(40),
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(r.radius(12))),
                        ),
                        onPressed: isAssigned
                            ? () {}
                            : () async {
                                await service.cancelRideRequest(widget.requestId);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                }
                              },
                        child: Text(isAssigned ? 'Report Issue' : 'Cancel'),
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
      ],
    );
  }
}

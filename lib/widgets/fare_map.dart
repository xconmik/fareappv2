import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Shared dark style and Cloud Map ID used across the app.
const String fareMapStyle = '''[
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
const String consoleCloudMapId = '5c554f4f892ef6db87f0d2c1';

class FareMap extends StatefulWidget {
  const FareMap({
    Key? key,
    required this.target,
    this.zoom = 14,
    this.markers = const <Marker>{},
    this.polylines = const <Polyline>{},
    this.myLocationEnabled = false,
    this.myLocationButtonEnabled = false,
    this.zoomControlsEnabled = false,
    this.mapToolbarEnabled = false,
    this.compassEnabled = false,
    this.tiltGesturesEnabled = false,
    this.onMapCreated,
    this.cloudMapId = consoleCloudMapId,
  }) : super(key: key);

  final LatLng target;
  final double zoom;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool myLocationEnabled;
  final bool myLocationButtonEnabled;
  final bool zoomControlsEnabled;
  final bool mapToolbarEnabled;
  final bool compassEnabled;
  final bool tiltGesturesEnabled;
  final void Function(GoogleMapController controller)? onMapCreated;
  final String? cloudMapId;

  @override
  State<FareMap> createState() => _FareMapState();
}

class _FareMapState extends State<FareMap> {
  

  GoogleMapController? _controller;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: widget.target,
        zoom: widget.zoom,
      ),
      markers: widget.markers,
      polylines: widget.polylines,
      zoomControlsEnabled: widget.zoomControlsEnabled,
      myLocationButtonEnabled: widget.myLocationButtonEnabled,
      myLocationEnabled: widget.myLocationEnabled,
      mapToolbarEnabled: widget.mapToolbarEnabled,
      compassEnabled: widget.compassEnabled,
      tiltGesturesEnabled: widget.tiltGesturesEnabled,
      mapType: MapType.normal,
      cloudMapId: widget.cloudMapId,
      onMapCreated: (controller) {
        _controller = controller;
        // apply dark style when not using cloud map style
        if (widget.cloudMapId == null) {
          _controller?.setMapStyle(fareMapStyle);
        }
        widget.onMapCreated?.call(controller);
      },
    );
  }
}

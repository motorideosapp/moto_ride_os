
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapView extends StatelessWidget {
  final Completer<GoogleMapController> mapController;
  final String? mapStyle;
  final CameraPosition initialCameraPosition;
  final Set<Marker> markers;
  final Set<Polyline> polylines;
  final bool isFullScreen;
  final void Function(GoogleMapController) onMapCreated;
  final void Function() onCameraMoveStarted;

  const MapView({
    super.key,
    required this.mapController,
    this.mapStyle,
    required this.initialCameraPosition,
    required this.markers,
    required this.polylines,
    required this.isFullScreen,
    required this.onMapCreated,
    required this.onCameraMoveStarted,
  });

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      mapType: MapType.normal,
      initialCameraPosition: initialCameraPosition,
      onMapCreated: onMapCreated,
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      markers: markers,
      polylines: polylines,
      zoomControlsEnabled: false, // Kontroller harici olarak yönetilecek
      scrollGesturesEnabled: isFullScreen,
      tiltGesturesEnabled: isFullScreen,
      rotateGesturesEnabled: isFullScreen,
      onCameraMoveStarted: onCameraMoveStarted,
    );
  }
}

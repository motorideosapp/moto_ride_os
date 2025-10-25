import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:moto_ride_os/services/roads_service.dart';
import 'package:moto_ride_os/widgets/maneuver_panel.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Custom data class to hold navigation instructions
// Yeni, güncel class tanımı:
class NavigationInstruction {
  final String instruction;
  final LatLng location;
  final String maneuver; // Eklendi

  NavigationInstruction({
    required this.instruction,
    required this.location,
    required this.maneuver, // Eklendi
  });
}

// A custom data class to hold search result data
class SearchResultItem {
  final Location location;
  final Placemark placemark;

  SearchResultItem({required this.location, required this.placemark});
}

// Helper function to load and resize asset images for map markers to prevent crashes.
Future<Uint8List> getBytesFromAsset(String path, int width) async {
  ByteData data = await rootBundle.load(path);
  ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
  ui.FrameInfo fi = await codec.getNextFrame();
  return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
}

class NavigationWidget extends StatefulWidget {
  final bool isFullScreen;
  final Position? currentPosition;

  const NavigationWidget({
    super.key,
    this.isFullScreen = false,
    this.currentPosition,
  });

  @override
  State<NavigationWidget> createState() => _NavigationWidgetState();
}

class _NavigationWidgetState extends State<NavigationWidget> {
  final Completer<GoogleMapController> _controller = Completer();
  String? _mapStyle;
  final Set<Marker> _markers = {};
  BitmapDescriptor? _customIcon;
  final TextEditingController _searchController = TextEditingController();
  List<SearchResultItem> _searchResults = [];
  bool _isRecalculating = false;
  // IMPORTANT: REPLACE "YOUR_GOOGLE_API_KEY" with your actual Google Cloud API key
  final RoadsService _roadsService = RoadsService('AIzaSyC9A7yEkm1hANYgtkqn4QQ71HTMGznKILc');
  int? _speedLimit;
  bool _isSpeeding = false;
  Timer? _speedLimitTimer;
  Timer? _listeningTimer;
  bool _followUser = true;

  // Route information
  String? _remainingDistance;
  String? _estimatedArrivalTime;

  // Maneuver Info for the new panel
  IconData? _currentManeuverIcon;
  String? _nextManeuverInstruction;
  String? _distanceToNextManeuver;

  // Speech to text
  final SpeechToText _speech = SpeechToText();
  bool _isListening = false;

  // Text to speech
  final FlutterTts _flutterTts = FlutterTts();

  // Static variables to persist route state across widget rebuilds
  static final Set<Polyline> _persistedPolylines = {};
  static Marker? _persistedDestinationMarker;
  static String? _persistedRemainingDistance;
  static String? _persistedEstimatedArrivalTime;

  // Navigation Instructions
  static List<NavigationInstruction> _navigationInstructions = [];
  static int _currentInstructionIndex = 0;


  @override
  void initState() {
    super.initState();
    _loadCustomIcon();
    _speech.initialize();
    _initializeTts();

    if (_persistedDestinationMarker != null) {
      _markers.add(_persistedDestinationMarker!);
      _remainingDistance = _persistedRemainingDistance;
      _estimatedArrivalTime = _persistedEstimatedArrivalTime;
    }
    _speedLimitTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (widget.currentPosition != null) {
        _updateSpeedLimit(widget.currentPosition!);
      }
    });
  }

  void _initializeTts() async {
    final prefs = await SharedPreferences.getInstance();
    final voiceJson = prefs.getString('selected_voice');

    await _flutterTts.setLanguage("tr-TR"); // Default language

    if (voiceJson != null) {
      try {
        final voiceData = json.decode(voiceJson);
        final voiceName = voiceData['name'];
        final voiceLocale = voiceData['locale'];
        if (voiceName != null && voiceLocale != null) {
          await _flutterTts.setVoice({"name": voiceName, "locale": voiceLocale});
        }
      } catch (e) {
        print("Error setting selected voice: $e");
      }
    }
  }

  @override
  void dispose() {
    _speech.stop();
    _speedLimitTimer?.cancel();
    _listeningTimer?.cancel();
    _flutterTts.stop();
    super.dispose();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateMapStyleForTheme();
  }

  // Calculates a dynamic zoom level based on the current speed.
  double _calculateDynamicZoom(double speedKmh) {
    if (speedKmh < 10) return 19.5; // Very close when slow or stopped
    if (speedKmh < 30) return 18.5;
    if (speedKmh < 50) return 17.5;
    if (speedKmh < 80) return 16.5;
    return 15.5; // Further out at high speeds
  }

  // Adjusts map tilt for a better perspective at speed.
  double _calculateDynamicTilt(double speedKmh) {
    if (speedKmh < 10) return 30.0;
    double tilt = 45.0 + (speedKmh / 5);
    return tilt.clamp(30.0, 65.0); // Clamps the tilt value between 30 and 65 degrees
  }

  // Finds the closest point on the route polyline to the user's current location.
  LatLng _getSnappedPointOnRoute(Position currentPosition) {
    if (_persistedPolylines.isEmpty) {
      return LatLng(currentPosition.latitude, currentPosition.longitude);
    }

    final routePoints = _persistedPolylines.first.points;
    LatLng closestPoint = routePoints[0];
    double minDistance = double.infinity;

    for (final point in routePoints) {
      final double distance = Geolocator.distanceBetween(
          currentPosition.latitude, currentPosition.longitude,
          point.latitude, point.longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestPoint = point;
      }
    }
    return closestPoint;
  }

  @override
  void didUpdateWidget(NavigationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentPosition != null && widget.currentPosition != oldWidget.currentPosition) {
      final currentPos = widget.currentPosition!;
      final speedKmh = currentPos.speed * 3.6;

      // Determine the position to display on the map (snapped or raw)
      LatLng displayPosition;
      if (_persistedPolylines.isNotEmpty) {
        // If there's a route, snap the user's location to the nearest point on the polyline
        displayPosition = _getSnappedPointOnRoute(currentPos);
      } else {
        // Otherwise, use the raw GPS location
        displayPosition = LatLng(currentPos.latitude, currentPos.longitude);
      }

      // Update the user's marker on the map
      _updateMarkerSet(displayPosition, currentPos.heading);

      // If follow mode is enabled, animate the camera
      if (_followUser) {
        final double dynamicZoom = _calculateDynamicZoom(speedKmh);
        final double dynamicTilt = _calculateDynamicTilt(speedKmh);
        _animateToPosition(
            displayPosition,
            zoom: dynamicZoom,
            bearing: currentPos.heading,
            tilt: dynamicTilt
        );
      }

      setState(() {
        if (_persistedPolylines.isNotEmpty) {
          _updateRouteInfo();
          _checkNextInstruction(currentPos);
        }
      });

      _checkAndRecalculateRoute(currentPos);
      _checkSpeeding(currentPos);
    }
  }


  Future<void> _updateSpeedLimit(Position position) async {
    final speedLimit = await _roadsService.getSpeedLimit(position.latitude, position.longitude);
    if (mounted && speedLimit != null) {
      setState(() {
        _speedLimit = speedLimit;
      });
    }
  }

  void _checkSpeeding(Position position) {
    if (_speedLimit != null) {
      final currentSpeed = position.speed * 3.6;
      if (currentSpeed > _speedLimit! && !_isSpeeding) {
        setState(() { _isSpeeding = true; });
      } else if (currentSpeed <= _speedLimit! && _isSpeeding) {
        setState(() { _isSpeeding = false; });
      }
    }
  }


  Future<void> _updateMapStyleForTheme() async {
    if (!mounted) return;
    final theme = Theme.of(context).brightness;
    final stylePath = theme == Brightness.dark ? 'assets/map_styles/dark_mode.json' : 'assets/map_styles/light_mode.json';
    try {
      final newStyle = await rootBundle.loadString(stylePath);
      if (_mapStyle != newStyle) {
        _mapStyle = newStyle;
        if (_controller.isCompleted) {
          final controller = await _controller.future;
          await controller.setMapStyle(_mapStyle);
        }
        if (mounted) { setState(() {}); }
      }
    } catch (e) {
      print('Error loading map style: $e');
    }
  }

  Future<void> _loadCustomIcon() async {
    if (_customIcon != null) return;
    try {
      final Uint8List iconBytes = await getBytesFromAsset('assets/images/ridepin1.png', 150);
      _customIcon = BitmapDescriptor.fromBytes(iconBytes);
      if (mounted && widget.currentPosition != null) {
        setState(() {
          final pos = widget.currentPosition!;
          _updateMarkerSet(LatLng(pos.latitude, pos.longitude), pos.heading);
        });
      }
    } catch (e) {
      print('Error loading custom icon: $e');
    }
  }

  void _updateMarkerSet(LatLng position, double bearing) {
    if (_customIcon == null) return;
    _markers.removeWhere((m) => m.markerId.value == 'current_location');
    _markers.add(Marker(
      markerId: const MarkerId('current_location'),
      position: position,
      icon: _customIcon!,
      rotation: bearing,
      anchor: const Offset(0.5, 0.5),
      flat: true,
      zIndex: 2,
    ));
  }

  Future<void> _animateToPosition(LatLng target, {double? zoom, double? bearing, double? tilt}) async {
    if (!_controller.isCompleted) return;
    final GoogleMapController controller = await _controller.future;
    final double newZoom = zoom ?? await controller.getZoomLevel();
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: target,
        zoom: newZoom,
        tilt: tilt ?? 15.0,
        bearing: bearing ?? 0.0,
      ),
    ));
  }

  IconData _getManeuverIcon(String maneuver) {
    switch (maneuver) {
      case 'turn-sharp-left':
      case 'turn-left':
      case 'ramp-left':
      case 'fork-left':
        return Icons.turn_left;
      case 'turn-sharp-right':
      case 'turn-right':
      case 'ramp-right':
      case 'fork-right':
        return Icons.turn_right;
      case 'uturn-right':
      case 'uturn-left':
        return Icons.u_turn_left;
      case 'straight':
        return Icons.straight;
      case 'roundabout-left':
        return Icons.roundabout_left;
      case 'roundabout-right':
        return Icons.roundabout_right;
      case 'merge':
        return Icons.merge_type;
      default:
        return Icons.straight; // Default icon
    }
  }


  Future<void> _checkAndRecalculateRoute(Position currentPosition) async {
    if (_persistedPolylines.isEmpty || _isRecalculating || _persistedDestinationMarker == null) return;

    setState(() { _isRecalculating = true; });

    bool isOffRoute = true;
    const double offRouteThreshold = 50.0; // meters

    for (final point in _persistedPolylines.first.points) {
      final double distance = Geolocator.distanceBetween(
          currentPosition.latitude, currentPosition.longitude, point.latitude, point.longitude);
      if (distance < offRouteThreshold) {
        isOffRoute = false;
        break;
      }
    }

    if (isOffRoute) {
      print("User is off-route. Recalculating...");
      await _flutterTts.speak("Yeni rota belirlendi");
      await _drawRoute(_persistedDestinationMarker!.position);
    }

    Timer(const Duration(seconds: 5), () {
      if(mounted) { setState(() { _isRecalculating = false; }); }
    });
  }

  // Yeni, tam teşekküllü manevra kontrol metodu:
  void _checkNextInstruction(Position currentPosition) {
    if (_navigationInstructions.isEmpty || _currentInstructionIndex >= _navigationInstructions.length) {
      if (_nextManeuverInstruction != null) {
        setState(() {
          _currentManeuverIcon = null;
          _nextManeuverInstruction = null;
          _distanceToNextManeuver = null;
        });
      }
      return;
    }

    final nextInstruction = _navigationInstructions[_currentInstructionIndex];
    final distanceToNext = Geolocator.distanceBetween(
      currentPosition.latitude, currentPosition.longitude,
      nextInstruction.location.latitude, nextInstruction.location.longitude,
    );

    // Update UI continuously
    setState(() {
      _distanceToNextManeuver = distanceToNext < 1000
          ? '${distanceToNext.round()} m'
          : '${(distanceToNext / 1000).toStringAsFixed(1)} km';
      _currentManeuverIcon = _getManeuverIcon(nextInstruction.maneuver);
      _nextManeuverInstruction = nextInstruction.instruction;
    });

    // Check if it's time to trigger the instruction and move to the next one
    if (distanceToNext < 35) { // 35 meters threshold to trigger
      _flutterTts.speak(nextInstruction.instruction);
      _currentInstructionIndex++;

      if (_currentInstructionIndex >= _navigationInstructions.length) {
        // Reached the destination
        setState(() {
          _currentManeuverIcon = Icons.location_on;
          _nextManeuverInstruction = 'Varış noktasına ulaştınız';
          _distanceToNextManeuver = '';
        });
      }
    }
  }


  void _onMapCreated(GoogleMapController controller) async {
    _controller.complete(controller);
    if (_mapStyle != null) {
      await controller.setMapStyle(_mapStyle);
    }
    if (widget.currentPosition != null) {
      final pos = widget.currentPosition!;
      final latlng = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _updateMarkerSet(latlng, pos.heading);
        _animateToPosition(latlng, zoom: 17.0);
      });
    }
  }

  void _recenterMap() {
    if (widget.currentPosition != null) {
      final currentPos = widget.currentPosition!;
      final speedKmh = currentPos.speed * 3.6;
      final latlng = LatLng(currentPos.latitude, currentPos.longitude);

      setState(() { _followUser = true; });

      _animateToPosition(
          latlng,
          zoom: _calculateDynamicZoom(speedKmh),
          bearing: currentPos.heading,
          tilt: _calculateDynamicTilt(speedKmh)
      );
    }
  }

  void _listen() async {
    _listeningTimer?.cancel();
    var status = await Permission.microphone.status;
    if (status.isDenied) {
      final result = await Permission.microphone.request();
      if (result.isPermanentlyDenied) { await openAppSettings(); return; }
      if (!result.isGranted) { return; }
    }

    if (_isListening) {
      setState(() => _isListening = false);
      _speech.stop();
      _listeningTimer?.cancel();
      return;
    }

    bool available = await _speech.initialize(
      onError: (val) {
        print('onError: $val');
        if (mounted) { setState(() => _isListening = false); }
      },
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (val) {
          if (mounted) { setState(() { _searchController.text = val.recognizedWords; }); }
        },
        localeId: "tr_TR",
      );
      _listeningTimer = Timer(const Duration(seconds: 8), () {
        if (mounted && _isListening) {
          setState(() => _isListening = false);
          _speech.stop();
          if (_searchController.text.isNotEmpty) { _search(); }
        }
      });
    } else {
      print("The user has denied the use of speech recognition.");
      if (mounted) { setState(() => _isListening = false); }
    }
  }

  void _search() async {
    FocusScope.of(context).unfocus();
    if (_searchController.text.isNotEmpty) {
      try {
        List<Location> locations = await locationFromAddress('${_searchController.text}, Türkiye');
        List<SearchResultItem> results = [];
        for (var location in locations) {
          List<Placemark> placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
          if (placemarks.isNotEmpty) {
            results.add(SearchResultItem(location: location, placemark: placemarks.first));
          }
        }
        setState(() { _searchResults = results; });
      } catch (e) {
        print("Error searching for location: $e");
      }
    }
  }

  void _clearRoute() {
    FocusScope.of(context).unfocus();
    setState(() {
      _persistedPolylines.clear();
      _persistedDestinationMarker = null;
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _searchController.clear();
      _searchResults.clear();
      _remainingDistance = null;
      _estimatedArrivalTime = null;
      _persistedRemainingDistance = null;
      _persistedEstimatedArrivalTime = null;
      _navigationInstructions.clear();
      _currentInstructionIndex = 0;
      _followUser = true;

      // Clear maneuver info
      _currentManeuverIcon = null;
      _nextManeuverInstruction = null;
      _distanceToNextManeuver = null;
    });
  }

  String _stripHtml(String htmlString) {
    return htmlString.replaceAll(RegExp(r"<[^>]*>"), ' ');
  }

  Future<void> _drawRoute(LatLng destination) async {
    FocusScope.of(context).unfocus();
    if (widget.currentPosition == null) return;

    // IMPORTANT: REPLACE "YOUR_GOOGLE_API_KEY" with your actual Google Cloud API key
    const String googleApiKey = 'AIzaSyC9A7yEkm1hANYgtkqn4QQ71HTMGznKILc';
    final LatLng origin = LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$googleApiKey&language=tr';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        if (jsonResponse['routes'] != null && jsonResponse['routes'].isNotEmpty) {
          final route = jsonResponse['routes'][0];
          final leg = route['legs'][0];
          final steps = leg['steps'] as List;

          final polylinePoints = PolylinePoints();
          final List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(route['overview_polyline']['points']);
          final List<LatLng> polylineCoordinates = decodedPoints.map((point) => LatLng(point.latitude, point.longitude)).toList();

          _navigationInstructions.clear();
          _currentInstructionIndex = 0;
          for (var step in steps) {
            _navigationInstructions.add(NavigationInstruction(
              instruction: _stripHtml(step['html_instructions']),
              location: LatLng(step['end_location']['lat'], step['end_location']['lng']),
              maneuver: step['maneuver'] ?? 'straight', // Get maneuver data
            ));
          }

          _persistedPolylines.clear();
          _persistedPolylines.add(Polyline(
            polylineId: const PolylineId('route'),
            points: polylineCoordinates,
            color: Colors.blue,
            width: 5,
          ));

          _persistedDestinationMarker = Marker(markerId: const MarkerId('destination'), position: destination);
          _updateRouteInfo();
          await _flutterTts.speak("Rota oluşturuldu");

          setState(() {
            _markers.removeWhere((m) => m.markerId.value == 'destination');
            _markers.add(_persistedDestinationMarker!);
            _searchResults = [];
            _searchController.clear();
            _followUser = true; // Engage follow mode when route is created
          });

          final GoogleMapController controller = await _controller.future;
          controller.animateCamera(CameraUpdate.newLatLngBounds(
            LatLngBounds(
              southwest: LatLng(
                  origin.latitude < destination.latitude ? origin.latitude : destination.latitude,
                  origin.longitude < destination.longitude ? origin.longitude : destination.longitude),
              northeast: LatLng(
                  origin.latitude > destination.latitude ? origin.latitude : destination.latitude,
                  origin.longitude > destination.longitude ? origin.longitude : destination.longitude),
            ),
            100.0,
          ));
        }
      } else {
        print("Error fetching directions: ${response.body}");
      }
    } catch(e){
      print("Error in _drawRoute: $e");
    }
  }

  void _updateRouteInfo() {
    if (widget.currentPosition == null || _persistedPolylines.isEmpty) return;

    final routePoints = _persistedPolylines.first.points;
    int closestPointIndex = 0;
    double minDistance = double.infinity;

    for (int i = 0; i < routePoints.length; i++) {
      final double distance = Geolocator.distanceBetween(
          widget.currentPosition!.latitude, widget.currentPosition!.longitude,
          routePoints[i].latitude, routePoints[i].longitude);
      if (distance < minDistance) {
        minDistance = distance;
        closestPointIndex = i;
      }
    }

    double remainingDistanceValue = 0;
    for (int i = closestPointIndex; i < routePoints.length - 1; i++) {
      remainingDistanceValue += Geolocator.distanceBetween(
          routePoints[i].latitude, routePoints[i].longitude,
          routePoints[i + 1].latitude, routePoints[i + 1].longitude);
    }

    final currentSpeedKmh = widget.currentPosition!.speed > 1 ? widget.currentPosition!.speed * 3.6 : 50;
    final remainingTimeHours = remainingDistanceValue / 1000 / currentSpeedKmh;
    final remainingTimeMinutes = remainingTimeHours * 60;
    final arrivalTime = DateTime.now().add(Duration(minutes: remainingTimeMinutes.round()));

    if (mounted) {
      setState(() {
        _remainingDistance = (remainingDistanceValue / 1000).toStringAsFixed(1);
        _estimatedArrivalTime = "${arrivalTime.hour.toString().padLeft(2, '0')}:${arrivalTime.minute.toString().padLeft(2, '0')}";
        _persistedRemainingDistance = _remainingDistance;
        _persistedEstimatedArrivalTime = _estimatedArrivalTime;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final speed = widget.currentPosition != null ? (widget.currentPosition!.speed * 3.6).toStringAsFixed(0) : '0';

    return Container(
      decoration: BoxDecoration(
        color: isDarkMode ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.8),
        borderRadius: const BorderRadius.all(Radius.circular(20)),
        border: Border.all(
            color: isDarkMode ? Colors.cyanAccent.withOpacity(0.3) : Colors.blue.withOpacity(0.5),
            width: 1.5),
        boxShadow: [BoxShadow(color: isDarkMode ? Colors.cyanAccent.withOpacity(0.1) : Colors.blue.withOpacity(0.2), blurRadius: 10.0, spreadRadius: 2.0,)],
      ),
      child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.isFullScreen ? 0.0 : 18.0),
          child: widget.currentPosition == null
              ? Center(child: CircularProgressIndicator(color: isDarkMode ? Colors.cyanAccent : Colors.blue, strokeWidth: 2.0,))
              : Stack(
            children: [
            GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: CameraPosition(target: LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude), zoom: 19.0, tilt: 45.0,),
            onMapCreated: _onMapCreated,
            myLocationEnabled: false,
            myLocationButtonEnabled: false,
            markers: _markers,
            polylines: _persistedPolylines,
            zoomControlsEnabled: widget.isFullScreen,
            scrollGesturesEnabled: widget.isFullScreen,
            tiltGesturesEnabled: widget.isFullScreen,
            rotateGesturesEnabled: widget.isFullScreen,
            onCameraMoveStarted: () {
              if (_followUser) {
                setState(() {
                  _followUser = false;
                });
              }
            },
          ),
          if (widget.isFullScreen)
      Positioned(
      bottom: 20, left: 0, right: 0,
      child: Center(
        child: Column(
          children: [
            Text(speed, style: TextStyle(color: _isSpeeding ? Colors.red : Colors.white.withOpacity(0.8), fontSize: 52, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 10.0, color: Colors.black, offset: Offset(0, 0))])),
            Text('km/h', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 20, shadows: const [Shadow(blurRadius: 8.0, color: Colors.black, offset: Offset(0, 0))])),
            if (_speedLimit != null)
              Text('Limit: $_speedLimit', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16, shadows: const [Shadow(blurRadius: 5.0, color: Colors.black, offset: Offset(0, 0))])),
          ],
        ),
      ),
    ),
    if (widget.isFullScreen)
    Positioned(
    top: 10, left: 80, right: 80,
    child: Material(
    color: Colors.transparent,
    child: Column(
    children: [
    Container(
    decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10),),
    child: Row(
    children: [
    Expanded(child: TextField(controller: _searchController, decoration: InputDecoration(hintText: _isListening ? 'Dinliyorum...' : 'Adres Ara...', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 15)), onSubmitted: (_) => _search(),)),
    IconButton(icon: Icon(_isListening ? Icons.mic_off : Icons.mic), color: _isListening ? Colors.red : (isDarkMode ? Colors.white : Colors.black), onPressed: _listen),
    if (_persistedPolylines.isNotEmpty)
    IconButton(icon: const Icon(Icons.close), onPressed: _clearRoute)
    else
    IconButton(icon: const Icon(Icons.search), onPressed: _search),
    ],
    ),
    ),
    if (_searchResults.isNotEmpty)
    Container(
    height: 200,
    decoration: BoxDecoration(color: isDarkMode ? Colors.black.withOpacity(0.8) : Colors.white.withOpacity(0.9), borderRadius: BorderRadius.circular(10),),
    child: ListView.builder(
    itemCount: _searchResults.length,
    itemBuilder: (context, index) {
    final result = _searchResults[index];
    final placemark = result.placemark;
    final name = placemark.name ?? '';
    final street = placemark.street ?? '';
    final subLocality = placemark.subLocality ?? '';
    final locality = placemark.locality ?? '';
    final adminArea = placemark.administrativeArea ?? '';
    final title = name.isNotEmpty && name != street ? name : street;
    final subtitleParts = [subLocality, locality, adminArea].where((s) => s.isNotEmpty && s != title).toSet().toList();
    final subtitle = subtitleParts.join(', ');
    return ListTile(
    title: Text(title),
      subtitle: Text(subtitle),
      onTap: () => _drawRoute(LatLng(result.location.latitude, result.location.longitude)),
    );
    },
    ),
    ),
    ],
    ),
    ),
    ),
              // The new Maneuver Panel will go here
              if (widget.isFullScreen && _persistedPolylines.isNotEmpty && _nextManeuverInstruction != null)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ManeuverPanel(
                      maneuverIcon: _currentManeuverIcon,
                      distanceToNextManeuver: _distanceToNextManeuver,
                      nextManeuverInstruction: _nextManeuverInstruction,
                      remainingDistance: _remainingDistance,
                      estimatedArrivalTime: _estimatedArrivalTime,
                    ),
                  ),
                ),
              if (!widget.isFullScreen)
                Positioned(
                  bottom: 8, right: 8,
                  child: FloatingActionButton.small(
                    heroTag: null,
                    onPressed: _recenterMap,
                    backgroundColor: isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.8),
                    foregroundColor: isDarkMode ? Colors.white : Colors.black,
                    child: const Icon(Icons.my_location, size: 20),
                  ),
                ),
            ],
          ),
      ),
    );
  }
}
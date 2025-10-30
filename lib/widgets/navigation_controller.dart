
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as maps_toolkit;
import 'package:moto_ride_os/models/navigation.dart';
import 'package:moto_ride_os/widgets/map_view.dart';
import 'package:moto_ride_os/widgets/route_info_panel.dart';
import 'package:moto_ride_os/widgets/search_panel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';

// Kalıcı olması gereken durumlar
final Set<Marker> _persistentMarkers = {};
final Set<Polyline> _persistentPolylines = {};
List<NavigationInstruction> _persistentNavigationInstructions = [];
int _persistentCurrentInstructionIndex = 0;
bool _persistentIsNavigating = false;

// Rota bilgileri
IconData? _persistentManeuverIcon;
String? _persistentDistanceToNextManeuver;
String? _persistentNextManeuverInstruction;
String? _persistentRemainingDistance;
String? _persistentEstimatedArrivalTime;

class NavigationController extends StatefulWidget {
  final bool isFullScreen;
  final Position? currentPosition;

  const NavigationController({
    super.key,
    this.isFullScreen = false,
    this.currentPosition,
  });

  @override
  State<NavigationController> createState() => _NavigationControllerState();
}

class _NavigationControllerState extends State<NavigationController> {
  // Harita
  final Completer<GoogleMapController> _mapController = Completer();
  String? _mapStyle;
  bool _followUser = true;
  bool _isAnimatingCamera = false;

  // Servisler ve API Anahtarı
  late FlutterTts _flutterTts;
  late SpeechToText _speechToText;
  String? _googleApiKey;
  final Completer<void> _apiKeyCompleter = Completer();

  // Geçici Durum
  bool _isRecalculating = false;
  bool _isTtsSpeaking = false;

  // Arama ve Sesli Komut
  final TextEditingController _searchController = TextEditingController();
  List<SearchResultItem> _searchResults = [];
  bool _isListening = false;
  Timer? _searchDebounce;
  Timer? _countdownTimer;
  int _voiceSearchCountdown = 8;

  // << YENİ: Favori ve Son Gidilenler >>
  List<Map<String, dynamic>> _recentRoutes = [];
  LatLng? _homeLocation;
  LatLng? _workLocation;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _loadMapStyle();
    _loadApiKey();
    // << YENİ >>
    _loadRecentRoutes();
    _loadFavoriteLocations();

    if (widget.currentPosition != null) {
      _updateUserMarker(widget.currentPosition!, isPersistent: false);
    }
  }

  // << YENİ: Ayarlar'dan adres güncellendiğinde çağrılabilmesi için >>
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadFavoriteLocations();
  }


  @override
  void didUpdateWidget(covariant NavigationController oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.currentPosition != null) {
      _updateUserMarker(widget.currentPosition!, isPersistent: true);
    }

    if (oldWidget.currentPosition == null &&
        widget.currentPosition != null &&
        !_persistentIsNavigating) {
      _animateToPosition(widget.currentPosition!);
    }

    if (widget.currentPosition != null && _followUser) {
      if (_persistentIsNavigating) {
        _animateToPosition(widget.currentPosition!, isNavigating: true);
        _checkAndRecalculateRoute();
        _checkNextInstruction();
      } else if (_followUser) {
        _animateToPosition(widget.currentPosition!);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _countdownTimer?.cancel();
    _searchController.dispose();
    _flutterTts.stop();
    _speechToText.stop();
    super.dispose();
  }

  Future<void> _initializeServices() async {
    _flutterTts = FlutterTts();
    _speechToText = SpeechToText();

    try {
      final prefs = await SharedPreferences.getInstance();
      final voiceName = prefs.getString('selected_voice_name');
      final voiceLocale = prefs.getString('selected_voice_locale');

      if (voiceName != null && voiceLocale != null) {
        await _flutterTts.setVoice({"name": voiceName, "locale": voiceLocale});
      } else {
        await _flutterTts.setLanguage("tr-TR");
      }
    } catch (e) {
      await _flutterTts.setLanguage("tr-TR");
    }

    _flutterTts.setSpeechRate(0.5);
    _flutterTts.setVolume(1.0);

    _flutterTts.setCompletionHandler(() {
      if (mounted) setState(() => _isTtsSpeaking = false);
    });

    _flutterTts.setErrorHandler((msg) {
      if (mounted) setState(() => _isTtsSpeaking = false);
    });
  }

  Future<void> _loadApiKey() async {
    try {
      final String configString = await rootBundle.loadString('assets/config.json');
      final Map<String, dynamic> config = json.decode(configString);
      final apiKey = config['googleApiKey'];

      if (apiKey != null && !apiKey.contains('LÜTFEN')) {
        if (mounted) setState(() => _googleApiKey = apiKey);
      }
    } catch (e) {
      // Handle error
    } finally {
      if (!_apiKeyCompleter.isCompleted) {
        _apiKeyCompleter.complete();
      }
    }
  }

  // << YENİ FONKSİYONLAR >>
  Future<void> _loadRecentRoutes() async {
    final prefs = await SharedPreferences.getInstance();
    final recentRoutesJson = prefs.getStringList('recent_routes') ?? [];
    if(mounted){
      setState(() {
        _recentRoutes = recentRoutesJson.map((e) => json.decode(e) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveRouteToRecents(LatLng destination, String name) async {
    final prefs = await SharedPreferences.getInstance();

    final newRoute = {
      'name': name,
      'latitude': destination.latitude,
      'longitude': destination.longitude
    };

    _recentRoutes.removeWhere((route) => route['name'] == name);
    _recentRoutes.insert(0, newRoute);
    if (_recentRoutes.length > 3) {
      _recentRoutes = _recentRoutes.sublist(0, 3);
    }

    final recentRoutesJson = _recentRoutes.map((e) => json.encode(e)).toList();
    await prefs.setStringList('recent_routes', recentRoutesJson);

    if(mounted){
      setState(() {});
    }
  }

  Future<void> _loadFavoriteLocations() async {
    final prefs = await SharedPreferences.getInstance();
    final homeLat = prefs.getDouble('home_address_lat');
    final homeLon = prefs.getDouble('home_address_lon');
    final workLat = prefs.getDouble('work_address_lat');
    final workLon = prefs.getDouble('work_address_lon');

    if (mounted) {
      setState(() {
        _homeLocation = (homeLat != null && homeLon != null) ? LatLng(homeLat, homeLon) : null;
        _workLocation = (workLat != null && workLon != null) ? LatLng(workLat, workLon) : null;
      });
    }
  }

  Future<void> _drawRouteToFavorite(String addressType) async {
    FocusScope.of(context).unfocus();
    // Favori adresleri yeniden yükle, Ayarlar'dan yeni eklenmiş olabilir.
    await _loadFavoriteLocations();

    final prefs = await SharedPreferences.getInstance();
    final location = addressType == 'home' ? _homeLocation : _workLocation;
    final name = prefs.getString('${addressType}_address_name');

    if (location != null && name != null) {
      if (mounted) {
        setState(() {
          _searchController.text = name;
        });
      }
      await _drawRoute(location);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${addressType == 'home' ? 'Ev' : 'İş'} adresi ayarlanmamış.')),
      );
    }
  }

  Future<void> _onSelectRecent(Map<String, dynamic> route) async {
    FocusScope.of(context).unfocus();
    if(mounted) {
      setState(() {
        _searchController.text = route['name'] ?? 'Seçilen Konum';
        _searchResults.clear();
      });
    }
    final destination = LatLng(route['latitude'], route['longitude']);
    await _drawRoute(destination);
  }


  Future<void> _loadMapStyle() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stylePath = isDark ? 'assets/map_styles/dark_mode.json' : 'assets/map_styles/light_mode.json';
    try {
      final style = await rootBundle.loadString(stylePath);
      if (mounted) {
        setState(() => _mapStyle = style);
        if(_mapController.isCompleted) {
          final controller = await _mapController.future;
          controller.setMapStyle(style);
        }
      }
    } catch (e) {
      // Stil yüklenemezse ne yapılacağı burada ele alınabilir.
    }
  }

  void _updateUserMarker(Position position, {bool isPersistent = true}) {
    if (!mounted) return;
    final userMarker = Marker(
      markerId: const MarkerId('user_location'),
      position: LatLng(position.latitude, position.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      rotation: position.heading,
      flat: true,
      anchor: const Offset(0.5, 0.5),
    );

    if (isPersistent) {
      _persistentMarkers.removeWhere((m) => m.markerId.value == 'user_location');
      _persistentMarkers.add(userMarker);
    }
    if(mounted) setState(() {});
  }

  Future<void> _animateToPosition(Position position, {bool isNavigating = false}) async {
    if (!mounted || !_mapController.isCompleted) return;
    final controller = await _mapController.future;

    double zoomLevel = 15.0;
    if (isNavigating) {
      final speedKmh = position.speed * 3.6;
      if (speedKmh < 30) zoomLevel = 18.0;
      else if (speedKmh < 60) zoomLevel = 17.0;
      else if (speedKmh < 90) zoomLevel = 16.0;
      else zoomLevel = 15.5;
    }

    final cameraUpdate = CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: zoomLevel,
        bearing: position.heading,
        tilt: isNavigating ? 50.0 : 0.0,
      ),
    );

    if (mounted) setState(() => _isAnimatingCamera = true);
    await controller.animateCamera(cameraUpdate);
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _isAnimatingCamera = false);
    });
  }

  void _onSearch(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (query.trim().isEmpty) {
      if (mounted) setState(() => _searchResults.clear());
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      try {
        List<Location> locations = await locationFromAddress(query);
        if (!mounted) return;
        List<SearchResultItem> results = [];
        if (locations.isNotEmpty) {
          for (var loc in locations) {
            final placemarks = await placemarkFromCoordinates(loc.latitude, loc.longitude);
            if (placemarks.isNotEmpty) {
              results.add(SearchResultItem(location: loc, placemark: placemarks.first));
            }
          }
        }
        if(mounted) setState(() => _searchResults = results);
      } catch (e) {
        if(mounted) setState(() => _searchResults.clear());
      }
    });
  }

  void _listenToSpeech() async {
    if (_isListening) {
      await _speechToText.stop();
      _countdownTimer?.cancel();
      if(mounted) setState(() => _isListening = false);
      return;
    }

    bool available = await _speechToText.initialize(
      onError: (error) => setState(() => _isListening = false),
      onStatus: (status) {
        if (status == 'notListening' || status == 'done') {
          _countdownTimer?.cancel();
          if (mounted) setState(() => _isListening = false);
          if (_searchController.text.isNotEmpty) {
            _onSearch(_searchController.text);
          }
        }
      },
    );

    if (available) {
      if(mounted) {
        setState(() {
          _isListening = true;
          _searchController.clear();
          _searchResults.clear();
          _voiceSearchCountdown = 8;
        });
      }

      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (_voiceSearchCountdown <= 0) {
          timer.cancel();
          _speechToText.stop();
        } else {
          if(mounted) setState(() => _voiceSearchCountdown--);
        }
      });

      _speechToText.listen(
        onResult: (result) {
          if (mounted) setState(() => _searchController.text = result.recognizedWords);
        },
        listenFor: const Duration(seconds: 8),
        localeId: "tr-TR",
      );
    } else {
      if (mounted) setState(() => _isListening = false);
    }
  }


  void _clearRoute() {
    if (!mounted) return;
    setState(() {
      _persistentPolylines.clear();
      _persistentMarkers.removeWhere((m) => m.markerId.value == 'destination');
      _persistentNavigationInstructions.clear();
      _searchResults.clear();
      _searchController.clear();
      _persistentIsNavigating = false;
      _persistentCurrentInstructionIndex = 0;
      _followUser = true;
      _persistentManeuverIcon = null;
      _persistentDistanceToNextManeuver = null;
      _persistentNextManeuverInstruction = null;
      _persistentRemainingDistance = null;
      _persistentEstimatedArrivalTime = null;
    });
    if (widget.currentPosition != null) {
      _animateToPosition(widget.currentPosition!, isNavigating: false);
    }
  }

  void _onSelectItem(SearchResultItem item) async {
    FocusScope.of(context).unfocus();
    if (!mounted) return;

    final destinationName = item.placemark.name ?? 'Seçilen Konum';
    setState(() {
      _searchController.text = destinationName;
      _searchResults.clear();
    });

    await _drawRoute(LatLng(item.location.latitude, item.location.longitude));
  }

  Future<void> _drawRoute(LatLng destination) async {
    try {
      await _apiKeyCompleter.future;
      if (widget.currentPosition == null || _googleApiKey == null) return;
      if (mounted) setState(() {
        _persistentIsNavigating = true;
        _followUser = true;
      });

      // << DEĞİŞİKLİK: Rota çizildiğinde son gidilenlere kaydet >>
      await _saveRouteToRecents(destination, _searchController.text);

      final LatLng origin = LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
      final String url = 'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&mode=driving&language=tr&key=$_googleApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty && mounted) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          final newDistance = leg['distance']['text'];
          final newDuration = leg['duration']['text'];

          final points = route['overview_polyline']['points'];
          final List<LatLng> polylineCoordinates = _decodePolyline(points);
          final Polyline polyline = Polyline(polylineId: const PolylineId('route'), color: Colors.blue, points: polylineCoordinates, width: 5);
          final List<dynamic> steps = leg['steps'];
          _persistentNavigationInstructions = steps.map((step) => NavigationInstruction(
            instruction: step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), ' '),
            location: LatLng(step['end_location']['lat'], step['end_location']['lng']),
            maneuver: step['maneuver'] ?? 'straight',
          )).toList();

          if(mounted){
            setState(() {
              _persistentRemainingDistance = newDistance;
              _persistentEstimatedArrivalTime = newDuration;
              _persistentPolylines.clear();
              _persistentPolylines.add(polyline);
              _persistentMarkers.removeWhere((m) => m.markerId.value == 'destination');
              _persistentMarkers.add(Marker(markerId: const MarkerId('destination'), position: destination, icon: BitmapDescriptor.defaultMarker));
              _persistentCurrentInstructionIndex = 0;
            });
          }

          if (mounted) {
            _flutterTts.speak("Rota oluşturuldu. Tahmini süre: $newDuration");
            _checkNextInstruction();
          }
        }
      }
    } catch (e) {
      if(mounted) _clearRoute();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _checkAndRecalculateRoute() {
    if (!_persistentIsNavigating || _isRecalculating || widget.currentPosition == null || _persistentPolylines.isEmpty) return;
    final userLocation = maps_toolkit.LatLng(widget.currentPosition!.latitude, widget.currentPosition!.longitude);
    final routePoints = _persistentPolylines.first.points.map((p) => maps_toolkit.LatLng(p.latitude, p.longitude)).toList();
    if (!maps_toolkit.PolygonUtil.isLocationOnPath(userLocation, routePoints, false, tolerance: 75)) {
      if (mounted) setState(() => _isRecalculating = true);
      _flutterTts.speak("Rotadan çıkıldı. Yeni rota hesaplanıyor.");
      final destination = _persistentMarkers.firstWhere((m) => m.markerId.value == 'destination').position;
      _drawRoute(destination).whenComplete(() {
        if (mounted) setState(() => _isRecalculating = false);
      });
    }
  }

  void _checkNextInstruction() {
    if (!_persistentIsNavigating || _persistentNavigationInstructions.isEmpty || widget.currentPosition == null) return;
    if (_persistentCurrentInstructionIndex >= _persistentNavigationInstructions.length) {
      _flutterTts.speak("Hedefe vardınız.");
      _clearRoute();
      return;
    }

    final nextInstruction = _persistentNavigationInstructions[_persistentCurrentInstructionIndex];
    final distance = Geolocator.distanceBetween(widget.currentPosition!.latitude, widget.currentPosition!.longitude, nextInstruction.location.latitude, nextInstruction.location.longitude);

    if (mounted) {
      setState(() {
        _persistentDistanceToNextManeuver = distance < 1000 ? "${distance.round()} m" : "${(distance / 1000).toStringAsFixed(1)} km";
        _persistentNextManeuverInstruction = _getSimplifiedInstruction(nextInstruction);
        _persistentManeuverIcon = _getManeuverIcon(nextInstruction.maneuver);
      });
    }

    if (distance < 500 && distance > 450 && !_isTtsSpeaking) {
      _flutterTts.speak("500 metre sonra ${_getSimplifiedInstruction(nextInstruction, forTTS: true)}");
    } else if (distance < 200 && distance > 150 && !_isTtsSpeaking) {
      _flutterTts.speak("200 metre sonra ${_getSimplifiedInstruction(nextInstruction, forTTS: true)}");
    }

    if (distance < 50) {
      _flutterTts.speak(_getSimplifiedInstruction(nextInstruction, forTTS: true));
      if (mounted) setState(() => _persistentCurrentInstructionIndex++);
    }
  }

  String _getSimplifiedInstruction(NavigationInstruction instruction, {bool forTTS = false}) {
    final maneuver = instruction.maneuver.toLowerCase();
    if (maneuver.contains('turn-sharp-left')) return forTTS ? "keskin sola dön" : "Keskin Sola Dön";
    if (maneuver.contains('turn-slight-left')) return forTTS ? "hafif sola dön" : "Hafif Sola Dön";
    if (maneuver.contains('ramp-left')) return forTTS ? "sola rampa gir" : "Sola Rampa";
    if (maneuver.contains('fork-left')) return forTTS ? "yol ayrımında soldan devam et" : "Soldan Devam";
    if (maneuver.contains('turn-left')) return forTTS ? "sola dön" : "Sola Dön";

    if (maneuver.contains('turn-sharp-right')) return forTTS ? "keskin sağa dön" : "Keskin Sağa Dön";
    if (maneuver.contains('turn-slight-right')) return forTTS ? "hafif sağa dön" : "Hafif Sağa Dön";
    if (maneuver.contains('ramp-right')) return forTTS ? "sağa rampa gir" : "Sağa Rampa";
    if (maneuver.contains('fork-right')) return forTTS ? "yol ayrımında sağdan devam et" : "Sağdan Devam";
    if (maneuver.contains('turn-right')) return forTTS ? "sağa dön" : "Sağa Dön";

    if (maneuver.contains('uturn')) return forTTS ? "u dönüşü yap" : "U Dönüşü Yap";
    if (maneuver.contains('roundabout-left')) return forTTS ? "dönel kavşaktan sola çık" : "Dönel Kavşak (Sol)";
    if (maneuver.contains('roundabout-right')) return forTTS ? "dönel kavşaktan sağa çık" : "Dönel Kavşak (Sağ)";
    if (maneuver.contains('roundabout')) return forTTS ? "dönel kavşağı kullan" : "Dönel Kavşak";

    if (maneuver.contains('straight')) return forTTS ? "düz git" : "Düz Git";
    if (maneuver.contains('merge')) return forTTS ? "yola katıl" : "Yola Katıl";

    String cleanInstruction = instruction.instruction.replaceAll(RegExp(r'<[^>]*>'), ' ');
    return cleanInstruction.length > 30 ? '${cleanInstruction.substring(0, 27)}...' : cleanInstruction;
  }

  IconData _getManeuverIcon(String maneuver) {
    maneuver = maneuver.toLowerCase();
    if (maneuver.contains('turn-sharp-left')) return Icons.turn_sharp_left;
    if (maneuver.contains('turn-slight-left')) return Icons.turn_slight_left;
    if (maneuver.contains('turn-left')) return Icons.turn_left;
    if (maneuver.contains('turn-sharp-right')) return Icons.turn_sharp_right;
    if (maneuver.contains('turn-slight-right')) return Icons.turn_slight_right;
    if (maneuver.contains('turn-right')) return Icons.turn_right;
    if (maneuver.contains('uturn')) return Icons.u_turn_left;
    if (maneuver.contains('roundabout')) return Icons.roundabout_right;
    if (maneuver.contains('straight')) return Icons.straight;
    return Icons.directions;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final newBrightness = MediaQuery.of(context).platformBrightness;
      if (mounted) {
        final currentMapIsDark = _mapStyle?.contains('dark') ?? isDarkMode;
        if ((newBrightness == Brightness.dark && !currentMapIsDark) ||
            (newBrightness == Brightness.light && currentMapIsDark)) {
          _loadMapStyle();
        }
      }
    });

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        MapView(
          mapController: _mapController,
          mapStyle: _mapStyle,
          initialCameraPosition: CameraPosition(
            target: LatLng(widget.currentPosition?.latitude ?? 41.0082, widget.currentPosition?.longitude ?? 28.9784),
            zoom: _persistentIsNavigating ? 18.0 : 15.0,
          ),
          markers: _persistentMarkers,
          polylines: _persistentPolylines,
          isFullScreen: widget.isFullScreen,
          onMapCreated: (GoogleMapController controller) {
            if (mounted && !_mapController.isCompleted) {
              _mapController.complete(controller);
              if (_mapStyle != null) {
                controller.setMapStyle(_mapStyle);
              }
            }
            if (widget.currentPosition != null) {
              _animateToPosition(widget.currentPosition!, isNavigating: _persistentIsNavigating);
            }
          },
          onCameraMoveStarted: () {
            if (_isAnimatingCamera) return;
            if (mounted && _followUser) {
              setState(() => _followUser = false);
            }
          },
        ),

        if (!widget.isFullScreen && _persistentIsNavigating)
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isDarkMode ? Colors.black.withOpacity(0.7) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_persistentManeuverIcon != null) Icon(_persistentManeuverIcon, color: isDarkMode ? Colors.cyanAccent : Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  if (_persistentDistanceToNextManeuver != null)
                    Text(
                      _persistentDistanceToNextManeuver!,
                      style: TextStyle(color: theme.textTheme.bodyLarge?.color, fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ),

        if (widget.isFullScreen)
          SearchPanel(
            searchController: _searchController,
            isListening: _isListening,
            voiceSearchCountdown: _voiceSearchCountdown,
            hasRoute: _persistentIsNavigating,
            searchResults: _searchResults,
            recentRoutes: _recentRoutes, // << YENİ
            isHomeSet: _homeLocation != null, // << YENİ
            isWorkSet: _workLocation != null, // << YENİ
            onSearch: _onSearch,
            onListen: _listenToSpeech,
            onClearRoute: _clearRoute,
            onSelectItem: _onSelectItem,
            onSelectRecent: _onSelectRecent, // << YENİ
            onFavoriteTap: _drawRouteToFavorite, // << YENİ
          ),

        if (widget.isFullScreen && _persistentIsNavigating)
          RouteInfoPanel(
            maneuverIcon: _persistentManeuverIcon,
            distanceToNextManeuver: _persistentDistanceToNextManeuver,
            nextManeuverInstruction: _persistentNextManeuverInstruction,
            remainingDistance: _persistentRemainingDistance,
            estimatedArrivalTime: _persistentEstimatedArrivalTime,
          ),

        if (!_followUser)
          Positioned(
            bottom: widget.isFullScreen ? (MediaQuery.of(context).viewInsets.bottom > 0 ? 20 : 100) : 20,
            right: 20,
            child: FloatingActionButton(
              onPressed: () {
                if (mounted) setState(() => _followUser = true);
                if (widget.currentPosition != null) {
                  _animateToPosition(widget.currentPosition!, isNavigating: _persistentIsNavigating);
                }
              },
              child: const Icon(Icons.my_location),
            ),
          ),

        if (_isRecalculating)
          Positioned.fill(
              child: Container(color: Colors.black.withOpacity(0.5), child: const Center(child: CircularProgressIndicator()))),
      ],
    );
  }
}

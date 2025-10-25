import 'dart:async';
import 'dart:collection';
import 'package:call_log/call_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_ride_os/screens/settings_screen.dart';
import 'package:moto_ride_os/services/call_service.dart';
import 'package:moto_ride_os/widgets/call_panel_widget.dart';
import 'package:moto_ride_os/widgets/music/music_library_panel.dart';
import 'package:moto_ride_os/widgets/music_player_widget.dart';
import 'package:moto_ride_os/widgets/navigation_widget.dart';
import 'package:moto_ride_os/widgets/notifications_widget.dart';
import 'package:moto_ride_os/widgets/speedometer_widget.dart';
import 'package:moto_ride_os/widgets/theme_switcher.dart';
import 'package:moto_ride_os/widgets/weather_widget.dart';
import 'package:moto_ride_os/services/weather_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'dart:convert';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _showRecentCalls = false;
  bool _showMusicLibrary = false;
  bool _showDialpad = false;
  bool _isMapExpanded = false;

  Iterable<CallLogEntry> _callLogEntries = [];
  String _dialedNumber = "";

  StreamSubscription<Position>? _positionStreamSubscription;
  Position? _currentPosition;

  Map<String, dynamic> _weatherData = {};
  bool _isWeatherLoading = true;
  late WeatherService _weatherService;
  String? _apiKey;

  final CallService _callService = CallService();
  bool _isCallIncoming = false;
  Map<String, String> _callerInfo = {};

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    WakelockPlus.enable();

    _callService.startListening(
      onCallUpdate: (Map<String, String> callerInfo) {
        if (!mounted) return;
        setState(() {
          _isCallIncoming = true;
          _callerInfo = callerInfo;
        });
      },
      onEnded: () {
        if (!mounted) return;
        setState(() {
          _isCallIncoming = false;
          _callerInfo = {};
        });
      },
    );
  }

  Future<void> _loadApiKey() async {
    final String configString =
    await rootBundle.loadString('assets/config.json');
    final Map<String, dynamic> config = json.decode(configString);
    if (mounted) {
      setState(() {
        _apiKey = config['apiKey'];
      });
    }
  }

  void _initializeDashboard() async {
    await _loadApiKey();
    if (mounted && _apiKey != null) {
      _weatherService = WeatherService(_apiKey!);
      _fetchWeatherData();
    }
    _setOrientation();
    _startLocationServices();
  }

  void _setOrientation() {
    SystemChrome.setPreferredOrientations(
        [DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
  }

  void _fetchWeatherData() async {
    if (mounted) setState(() => _isWeatherLoading = true);
    final data = await _weatherService.getWeatherData();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isWeatherLoading = false;
      });
    }
  }

  Future<void> _startLocationServices() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final LocationSettings locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position? position) {
          if (position != null && mounted) {
            setState(() => _currentPosition = position);
          }
        });
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _callService.stopListening();
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
    super.dispose();
  }

  void _closeAllPanels() {
    if (!mounted) return;
    setState(() {
      if (_showRecentCalls) _showRecentCalls = false;
      if (_showDialpad) _showDialpad = false;
      if (_showMusicLibrary) _showMusicLibrary = false;
    });
  }

  void _openSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _toggleMapExpanded() {
    if (mounted) setState(() => _isMapExpanded = !_isMapExpanded);
  }

  void _toggleMusicLibrary() {
    final bool wasOpen = _showMusicLibrary;
    _closeAllPanels();
    if (!wasOpen && mounted) setState(() => _showMusicLibrary = true);
  }

  void _toggleRecentCalls() async {
    final bool wasOpen = _showRecentCalls;
    _closeAllPanels();
    if (wasOpen) return;

    final Iterable<CallLogEntry> allEntries = await CallLog.get();
    if (!mounted) return;
    final uniqueEntries = <String, CallLogEntry>{};
    for (var entry in allEntries) {
      final key = entry.name ?? entry.formattedNumber;
      if (key != null && key.isNotEmpty && !uniqueEntries.containsKey(key)) {
        uniqueEntries[key] = entry;
      }
    }
    if (mounted) {
      setState(() {
        _callLogEntries = uniqueEntries.values;
        _showRecentCalls = true;
      });
    }
  }

  void _toggleDialpad() {
    final bool wasOpen = _showDialpad;
    _closeAllPanels();
    if (wasOpen) {
      return;
    }
    if (mounted) {
      setState(() {
        _dialedNumber = "";
        _showDialpad = true;
      });
    }
  }

  void _onDialpadButtonPressed(String value) {
    if (value == "backspace") {
      if (_dialedNumber.isNotEmpty && mounted) {
        setState(() => _dialedNumber =
            _dialedNumber.substring(0, _dialedNumber.length - 1));
      }
    } else if (_dialedNumber.length < 15 && mounted) {
      setState(() => _dialedNumber += value);
    }
  }

  void _callDialedNumber() async {
    if (_dialedNumber.isNotEmpty) {
      final Uri url = Uri(scheme: 'tel', path: _dialedNumber);
      if (await canLaunchUrl(url)) await launchUrl(url);
      _toggleDialpad();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_apiKey == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _buildDashboardLayout(
                  constraints: constraints,
                ),
                _buildRecentCallsPanel(constraints),
                _buildDialpadPanel(constraints),
                _buildMusicLibraryPanel(constraints),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDashboardLayout({required BoxConstraints constraints}) {
    return _DashboardLayout(
      constraints: constraints,
      currentPosition: _currentPosition,
      isWeatherLoading: _isWeatherLoading,
      weatherData: _weatherData,
      isMapExpanded: _isMapExpanded,
      onMapTap: _toggleMapExpanded,
      onPhoneTap: _toggleRecentCalls,
      onDialpadTap: _toggleDialpad,
      onMusicTap: _toggleMusicLibrary,
      onSettingsTap: _openSettingsScreen,
      isCallIncoming: _isCallIncoming,
      callerInfo: _callerInfo,
    );
  }

  Widget _buildRecentCallsPanel(BoxConstraints constraints) {
    const double padding = 16.0;
    final double panelWidth = constraints.maxWidth * 0.28;
    final double panelHeight = constraints.maxHeight - (padding * 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _showRecentCalls ? padding : constraints.maxHeight,
      right: padding,
      width: panelWidth,
      height: panelHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              blurRadius: 25.0,
            )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Son Aramalar',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).iconTheme.color),
                    onPressed: _toggleRecentCalls,
                  ),
                ],
              ),
            ),
            Expanded(
              child: _callLogEntries.isEmpty
                  ? Center(
                  child: Text('Arama kaydı bulunamadı.',
                      style: TextStyle(
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color)))
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
                itemCount: _callLogEntries.length > 5
                    ? 5
                    : _callLogEntries.length,
                itemBuilder: (context, index) {
                  final entry = _callLogEntries.elementAt(index);
                  return ListTile(
                    leading: Icon(_getCallTypeIcon(entry.callType),
                        color: Theme.of(context).iconTheme.color),
                    title: Text(
                      entry.name ?? entry.formattedNumber ?? 'Bilinmeyen',
                      style: TextStyle(
                          color:
                          Theme.of(context).textTheme.bodyLarge?.color,
                          fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () async {
                      if (entry.number != null) {
                        final Uri url =
                        Uri(scheme: 'tel', path: entry.number);
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        }
                        _toggleRecentCalls();
                      }
                    },
                  );
                },
              ),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: Icon(Icons.contacts_rounded,
                          color: Theme.of(context).iconTheme.color, size: 32),
                      onPressed: () async {
                        final Uri url =
                        Uri(scheme: 'content', path: 'contacts/people');
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url);
                        } else {
                          if (kDebugMode) {
                            print('Kişiler uygulaması açılamadı.');
                          }
                        }
                      }),
                  IconButton(
                    icon: Icon(Icons.dialpad_rounded,
                        color: Theme.of(context).iconTheme.color, size: 32),
                    onPressed: _toggleDialpad,
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDialpadPanel(BoxConstraints constraints) {
    const double padding = 16.0;
    final double panelWidth = constraints.maxWidth * 0.28;
    final double panelHeight = constraints.maxHeight - (padding * 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: _showDialpad ? padding : constraints.maxHeight,
      right: padding,
      width: panelWidth,
      height: panelHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              blurRadius: 25.0,
            )
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 70,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              alignment: Alignment.center,
              child: Text(
                  _dialedNumber.isEmpty ? "Numara Girin" : _dialedNumber,
                  style: TextStyle(
                      color: _dialedNumber.isEmpty
                          ? Theme.of(context).textTheme.bodyMedium?.color
                          : Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            Expanded(
              child: GridView.count(
                padding: const EdgeInsets.all(16),
                crossAxisCount: 3,
                childAspectRatio: 1.5,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  ...[
                    '1', '2', '3', '4', '5', '6', '7', '8', '9', '*', '0', '#'
                  ]
                      .map((e) =>
                      _buildDialButton(e, () => _onDialpadButtonPressed(e)))
                      .toList(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                      icon: const Icon(Icons.cancel_rounded,
                          color: Colors.redAccent, size: 32),
                      onPressed: _toggleDialpad),
                  FloatingActionButton(
                    onPressed: _callDialedNumber,
                    backgroundColor: Colors.green,
                    child: const Icon(Icons.call, color: Colors.white),
                  ),
                  IconButton(
                    icon: Icon(Icons.backspace_rounded,
                        color: Theme.of(context).iconTheme.color, size: 32),
                    onPressed: () => _onDialpadButtonPressed("backspace"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicLibraryPanel(BoxConstraints constraints) {
    const double padding = 16.0;
    final double panelWidth = constraints.maxWidth * 0.28;
    final double panelHeight = constraints.maxHeight - (padding * 2);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      top: padding,
      right: _showMusicLibrary ? padding : -(panelWidth + padding * 2),
      width: panelWidth,
      height: panelHeight,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          border: Border.all(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).primaryColor.withOpacity(0.2),
              blurRadius: 25.0,
            )
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Müzik Arşivi',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close,
                        color: Theme.of(context).iconTheme.color),
                    onPressed: _toggleMusicLibrary,
                  ),
                ],
              ),
            ),
            const Expanded(
              child: MusicLibraryPanel(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialButton(String text, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(50),
      child: Center(
        child: Text(text,
            style: TextStyle(
                fontSize: 28,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w400)),
      ),
    );
  }

  IconData _getCallTypeIcon(CallType? callType) {
    switch (callType) {
      case CallType.incoming:
        return Icons.call_received_rounded;
      case CallType.outgoing:
        return Icons.call_made_rounded;
      case CallType.missed:
        return Icons.call_missed_rounded;
      default:
        return Icons.phone_rounded;
    }
  }
}

class _DashboardLayout extends StatelessWidget {
  final BoxConstraints constraints;
  final Position? currentPosition;
  final bool isWeatherLoading;
  final Map<String, dynamic> weatherData;
  final bool isMapExpanded;
  final VoidCallback onMapTap;
  final VoidCallback onPhoneTap;
  final VoidCallback onDialpadTap;
  final VoidCallback onMusicTap;
  final VoidCallback onSettingsTap;
  final bool isCallIncoming;
  final Map<String, String> callerInfo;

  const _DashboardLayout({
    required this.constraints,
    required this.currentPosition,
    required this.isWeatherLoading,
    required this.weatherData,
    required this.isMapExpanded,
    required this.onMapTap,
    required this.onPhoneTap,
    required this.onDialpadTap,
    required this.onMusicTap,
    required this.onSettingsTap,
    required this.isCallIncoming,
    required this.callerInfo,
  });

  @override
  Widget build(BuildContext context) {
    const double padding = 16.0;
    final double speed = (currentPosition?.speed ?? 0.0) * 3.6;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(padding),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              alignment: Alignment.topLeft,
              children: <Widget>[
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          child: Row(
            key: ValueKey<bool>(isMapExpanded),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: isMapExpanded ? 7 : 3,
                child: Stack(
                  children: [
                    GestureDetector(
                      onTap: isMapExpanded ? null : onMapTap,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.0),
                        child: AbsorbPointer(
                          absorbing: !isMapExpanded,
                          child: NavigationWidget(
                            isFullScreen: isMapExpanded,
                            currentPosition: currentPosition,
                          ),
                        ),
                      ),
                    ),
                    if (isMapExpanded)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(50),
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: onMapTap,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: padding),
              if (!isMapExpanded)
                Expanded(
                  flex: 4,
                  child: SpeedometerWidget(speed: speed),
                ),
              if (!isMapExpanded) const SizedBox(width: padding),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8.0,
                      runSpacing: 4.0,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        WeatherWidget(
                          isLoading: isWeatherLoading,
                          temperature: weatherData['temperature'] ?? '--',
                          condition:
                          weatherData['condition'] ?? 'Yükleniyor...',
                          weatherIcon: weatherData['weatherIcon'] ??
                              Icons.cloud_off,
                          isCompact: true,
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: onSettingsTap,
                        ),
                        const ThemeSwitcher(),
                      ],
                    ),
                    Expanded(
                      child: isCallIncoming
                          ? CallPanelWidget(
                        callerNumber:
                        callerInfo['number'] ?? 'Numara Yok',
                        callerName: callerInfo['name'] ?? 'Aranıyor...',
                      )
                          : SingleChildScrollView(
                        child: GestureDetector(
                          onTap: onMusicTap,
                          child: const MusicPlayerWidget(),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 90,
                      child: NotificationsWidget(
                        onPhoneTap: onPhoneTap,
                        onMessageTap: () {
                          if (kDebugMode) print("Mesaj butonu tıklandı");
                        },
                        onDialpadTap: onDialpadTap,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

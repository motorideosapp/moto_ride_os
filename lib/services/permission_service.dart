import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:moto_ride_os/models/permission_status.dart';
import 'package:permission_handler/permission_handler.dart' hide PermissionStatus;

/// Uygulama için gerekli olan tüm izinleri ve servis durumlarını yöneten servis.
class PermissionService {
  final _controller = StreamController<PermissionStatus>.broadcast();
  Stream<PermissionStatus> get statusStream => _controller.stream;

  PermissionService() {
    _checkInitialStatus();
    _listenToChanges();
  }

  Future<void> _checkInitialStatus() async {
    final status = await _getAllStatus();
    _controller.add(status);
  }

  void _listenToChanges() {
    Geolocator.getServiceStatusStream().listen((_) => _checkInitialStatus());
    Connectivity().onConnectivityChanged.listen((_) => _checkInitialStatus());
  }

  Future<PermissionStatus> _getAllStatus() async {
    final isPhonePermissionGranted = await Permission.phone.isGranted;
    final isContactsPermissionGranted = await Permission.contacts.isGranted;
    final isBluetoothScanGranted = await Permission.bluetoothScan.isGranted;
    final isBluetoothConnectGranted = await Permission.bluetoothConnect.isGranted;

    final results = await Future.wait([
      Geolocator.isLocationServiceEnabled(),
      Permission.location.isGranted,
      _checkInternetConnection(),
      Permission.microphone.isGranted,
      Permission.audio.isGranted,
    ]);

    return PermissionStatus(
      isLocationServiceEnabled: results[0] as bool,
      isLocationPermissionGranted: results[1] as bool,
      isInternetConnected: results[2] as bool,
      isBluetoothEnabled: isBluetoothScanGranted && isBluetoothConnectGranted, // Her iki Bluetooth izni de verilmeli
      isMicrophoneGranted: results[3] as bool,
      isAudioAccessGranted: results[4] as bool,
      isPhoneStateGranted: isPhonePermissionGranted,
      isCallLogGranted: isPhonePermissionGranted, // Genellikle aynı izne bağlıdır
      isContactsGranted: isContactsPermissionGranted,
    );
  }

  /// Gerekli olan tüm izinleri kullanıcıdan ister.
  Future<void> requestAllPermissions() async {
    await [
      Permission.location,
      Permission.microphone,
      Permission.audio,
      Permission.phone,
      Permission.contacts,
      Permission.bluetoothScan,    // Modern Bluetooth izni
      Permission.bluetoothConnect, // Modern Bluetooth izni
    ].request();

    _checkInitialStatus();
  }

  Future<bool> _checkInternetConnection() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult.contains(ConnectivityResult.mobile) ||
        connectivityResult.contains(ConnectivityResult.wifi);
  }

  void dispose() {
    _controller.close();
  }
}

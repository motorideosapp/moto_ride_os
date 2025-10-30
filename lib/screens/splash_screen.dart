import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moto_ride_os/models/permission_status.dart';
import 'package:moto_ride_os/screens/dashboard_screen.dart';
import 'package:moto_ride_os/services/permission_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late final PermissionService _permissionService;
  StreamSubscription<PermissionStatus>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _permissionService = PermissionService();
    _listenToPermissionStatus();
  }

  void _listenToPermissionStatus() {
    _statusSubscription = _permissionService.statusStream.listen((status) {
      if (status.allGranted) {
        _navigateToDashboard();
      }
    });
  }

  void _navigateToDashboard() {
    _statusSubscription?.cancel();
    if (!mounted || !ModalRoute.of(context)!.isCurrent) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => DashboardScreen()),
    );
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    _permissionService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      body: StreamBuilder<PermissionStatus>(
        stream: _permissionService.statusStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData || snapshot.data!.allGranted) {
            return const Center(child: CircularProgressIndicator());
          }
          return _buildPermissionRequestUI(snapshot.data!);
        },
      ),
    );
  }

  Widget _buildPermissionRequestUI(PermissionStatus status) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 150, color: Colors.white70),
          const SizedBox(height: 32),
          const Text(
            'Uygulama İzinleri',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            "Moto Ride OS'un tüm özelliklerini kullanabilmek için lütfen gerekli izinleri verin.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 40),
          _buildStatusRow(
              status.isLocationServiceEnabled ? 'Konum Servisi (GPS)' : 'Konum servisini (GPS) açmanız gerekiyor',
              status.isLocationServiceEnabled
          ),
          const SizedBox(height: 12),
          _buildStatusRow(
              status.isInternetConnected ? 'İnternet Bağlantısı' : 'İnternet bağlantısını açmanız gerekiyor',
              status.isInternetConnected
          ),
          const Divider(color: Colors.white24, height: 30, thickness: 1),
          _buildStatusRow('Konum İzni', status.isLocationPermissionGranted),
          const SizedBox(height: 12),
          _buildStatusRow('Bluetooth', status.isBluetoothEnabled),
          const SizedBox(height: 12),
          _buildStatusRow('Mikrofon Erişimi', status.isMicrophoneGranted),
          const SizedBox(height: 12),
          _buildStatusRow('Müzik ve Ses Erişimi', status.isAudioAccessGranted),
          const SizedBox(height: 12),
          _buildStatusRow('Telefon ve Arama Yönetimi', status.isPhoneStateGranted),
          const SizedBox(height: 12),
          _buildStatusRow('Arama Kaydı Erişimi', status.isCallLogGranted),
          const SizedBox(height: 12),
          _buildStatusRow('Kişi Listesi Erişimi', status.isContactsGranted),
          const SizedBox(height: 50), // Buton ile liste arasına boşluk ekledim
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              padding: const EdgeInsets.symmetric(vertical: 15),
              textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _permissionService.requestAllPermissions(),
            child: const Text('İzinleri Ver'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusRow(String text, bool isGranted) {
    return Row(
      children: [
        Icon(
          isGranted ? Icons.check_circle_rounded : Icons.cancel_rounded,
          color: isGranted ? Colors.greenAccent.shade700 : Colors.redAccent,
          size: 22,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: isGranted ? Colors.white : Colors.redAccent,
              fontSize: 16,
              fontWeight: isGranted ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

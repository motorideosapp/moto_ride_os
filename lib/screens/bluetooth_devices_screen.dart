import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class BluetoothDevicesScreen extends StatefulWidget {
  const BluetoothDevicesScreen({super.key});

  @override
  State<BluetoothDevicesScreen> createState() => _BluetoothDevicesScreenState();
}

class _BluetoothDevicesScreenState extends State<BluetoothDevicesScreen> {
  StreamSubscription<List<ScanResult>>? _scanResultsSubscription;
  final List<BluetoothDevice> _devices = [];
  final Set<DeviceIdentifier> _seenIds = {};
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    _scanResultsSubscription?.cancel();
    super.dispose();
  }

  void _addDevice(BluetoothDevice device) {
    if (device.platformName.isNotEmpty && _seenIds.add(device.remoteId)) {
      if (mounted) {
        setState(() {
          _devices.add(device);
        });
      }
    }
  }

  Future<void> _startScan() async {
    if (_isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
      _seenIds.clear();
    });

    try {
      // 1. Get already paired devices (including Classic Bluetooth like headsets)
      var bondedDevices = await FlutterBluePlus.bondedDevices;
      for (BluetoothDevice device in bondedDevices) {
        _addDevice(device);
      }

      // 2. Start scanning for new BLE devices
      _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          _addDevice(r.device);
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    } catch (e) {
      print("Tarama sırasında hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  // REVISED: The function no longer tries to connect. It confirms the selection.
  void _selectDevice(BluetoothDevice device) {
    FlutterBluePlus.stopScan();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${device.platformName} ses cihazı olarak seçildi.')),
    );

    // In a real app, you might save this device preference here.
    // For now, we just return to the previous screen.
    Navigator.pop(context);
  }

  // REVISED: The entire tile is now tappable, there is no separate button.
  Widget _buildDeviceTile(BluetoothDevice device) {
    return ListTile(
      title: Text(device.platformName),
      subtitle: Text(device.remoteId.toString()),
      leading: const Icon(Icons.bluetooth),
      onTap: () => _selectDevice(device), // Tapping the tile selects the device.
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bluetooth Cihazları'),
        actions: [
          _isScanning
              ? const Padding(
            padding: EdgeInsets.only(right: 20.0),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white,)),
          )
              : IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _startScan,
          ),
        ],
      ),
      body: _devices.isEmpty
          ? Center(
        child: _isScanning
            ? const Text('Cihazlar aranıyor...')
            : const Text('Cihaz bulunamadı. Cihazınızı eşleştirip tekrar deneyin.'),
      )
          : ListView.builder(
        itemCount: _devices.length,
        itemBuilder: (context, index) {
          return _buildDeviceTile(_devices[index]);
        },
      ),
    );
  }
}

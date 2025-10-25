import 'package:flutter/material.dart';
import 'package:moto_ride_os/screens/bluetooth_devices_screen.dart';
import 'package:moto_ride_os/screens/voice_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _openBluetoothScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BluetoothDevicesScreen()),
    );
  }

  void _openVoiceSettingsScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
    );
  }

  // Function to show the About Dialog
  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Moto Ride OS',
      applicationVersion: '1.0.0+1',
      applicationIcon: Image.asset('assets/images/logo.png', width: 48, height: 48),
      applicationLegalese: '© 2024 Moto Ride OS',
      children: <Widget>[
        const SizedBox(height: 24),
        const Text('Bu uygulama, sürüş deneyiminizi daha güvenli ve keyifli hale getirmek için tasarlanmıştır.'),
      ],
    );
  }

  // Function to show the Permissions Info Dialog
  void _showPermissionsInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('İzinler Hakkında'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text('Uygulamanın tüm özelliklerini kullanabilmek için bazı izinlere ihtiyaç duyulmaktadır:', style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Konum', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Navigasyon, rota takibi ve hız göstergesi için gereklidir.'),
                SizedBox(height: 8),
                Text('Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Kask interkomu, OBD2 cihazları ve diğer aksesuarlarla bağlantı kurmak için gereklidir.'),
                SizedBox(height: 8),
                Text('Mikrofon', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Sesli komutlar ve telefon görüşmeleri yapabilmek için gereklidir.'),
                SizedBox(height: 8),
                Text('Telefon ve Arama Yönetimi', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Gelen aramaları ekranda göstermek ve yönetmek için gereklidir.'),
                SizedBox(height: 8),
                Text('Arama Kaydı ve Kişi Listesi', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Gelen aramalarda arayan kişinin ismini gösterebilmek için gereklidir.'),
                SizedBox(height: 8),
                Text('Müzik ve Ses Erişimi', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Cihazınızdaki müziklere erişmek ve çalmak için gereklidir.'),
                SizedBox(height: 8),
                Text('İnternet', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Harita, hava durumu ve diğer çevrimiçi servisler için gereklidir.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Kapat'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Bluetooth Cihazları'),
            onTap: () => _openBluetoothScreen(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Navigasyon Ses Ayarları'),
            onTap: () => _openVoiceSettingsScreen(context),
          ),
          ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Spotify Hesabını Bağla'),
            onTap: () {
              // TODO: Spotify bağlantı sayfasına yönlendir.
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('İzinler Hakkında'),
            onTap: () => _showPermissionsInfoDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Kullanım Kılavuzu'),
            onTap: () {
              // TODO: Kullanım kılavuzu sayfasını aç.
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Uygulama Hakkında'),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.message),
            title: const Text('WhatsApp Hesabını Bağla'),
            subtitle: const Text('Yakında'),
            onTap: null,
          ),
        ],
      ),
    );
  }
}

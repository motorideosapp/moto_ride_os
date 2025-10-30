
import 'package:flutter/material.dart';
import 'package:moto_ride_os/screens/address_search_screen.dart';
import 'package:moto_ride_os/screens/bluetooth_devices_screen.dart';
import 'package:moto_ride_os/screens/voice_settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// << DEĞİŞİKLİK: Widget, durumu yönetebilmesi için StatefulWidget'a dönüştürüldü >>
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // << YENİ: Kayıtlı adresleri tutacak durum değişkenleri >>
  String? _homeAddress;
  String? _workAddress;

  @override
  void initState() {
    super.initState();
    // << YENİ: Sayfa açıldığında kayıtlı adresleri yükle >>
    _loadSavedAddresses();
  }

  // << YENİ FONKSİYON: Cihaz hafızasından adresleri okur >>
  Future<void> _loadSavedAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _homeAddress = prefs.getString('home_address_name');
      _workAddress = prefs.getString('work_address_name');
    });
  }

  // << YENİ FONKSİYON: Adres arama sayfasına yönlendirir >>
  void _navigateToAddressSearch(String addressType) async {
    // Adres arama sayfasından bir sonuç dönerse, adres listesini yenile
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) => AddressSearchScreen(addressType: addressType)),
    );

    if (result == true && mounted) {
      _loadSavedAddresses();
    }
  }

  void _openBluetoothScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BluetoothDevicesScreen()),
    );
  }

  void _openVoiceSettingsScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const VoiceSettingsScreen()),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Moto Ride OS',
      applicationVersion: '1.0.0+1',
      applicationIcon: Image.asset('assets/images/logo.png', width: 48, height: 48),
      applicationLegalese: '© 2024 Moto Ride OS',
      children: <Widget>[
        const SizedBox(height: 24),
        const Text(
            'Bu uygulama, sürüş deneyiminizi daha güvenli ve keyifli hale getirmek için tasarlanmıştır.'),
      ],
    );
  }

  void _showPermissionsInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('İzinler Hakkında'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(
                    'Uygulamanın tüm özelliklerini kullanabilmek için bazı izinlere ihtiyaç duyulmaktadır:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Konum', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'Navigasyon, rota takibi ve hız göstergesi için gereklidir.'),
                SizedBox(height: 8),
                Text('Bluetooth', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'Kask interkomu, OBD2 cihazları ve diğer aksesuarlarla bağlantı kurmak için gereklidir.'),
                SizedBox(height: 8),
                Text('Mikrofon', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(
                    'Sesli komutlar ve telefon görüşmeleri yapabilmek için gereklidir.'),
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
            onTap: _openBluetoothScreen,
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Navigasyon Ses Ayarları'),
            onTap: _openVoiceSettingsScreen,
          ),

          // << YENİ BÖLÜM BAŞLANGICI >>
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Kayıtlı Adreslerim',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Ev Adresi'),
            subtitle: Text(_homeAddress ?? 'Eklemek için dokunun'),
            onTap: () => _navigateToAddressSearch('home'),
          ),
          ListTile(
            leading: const Icon(Icons.work),
            title: const Text('İş Adresi'),
            subtitle: Text(_workAddress ?? 'Eklemek için dokunun'),
            onTap: () => _navigateToAddressSearch('work'),
          ),
          // << YENİ BÖLÜM SONU >>

          const Divider(),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('İzinler Hakkında'),
            onTap: () => _showPermissionsInfoDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Uygulama Hakkında'),
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }
}

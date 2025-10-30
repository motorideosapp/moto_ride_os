
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddressSearchScreen extends StatefulWidget {
  final String addressType; // 'home' veya 'work'

  const AddressSearchScreen({super.key, required this.addressType});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Location> _searchResults = [];
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearch(String query) {
    if (_searchDebounce?.isActive ?? false) _searchDebounce!.cancel();
    if (query.trim().length < 3) {
      setState(() => _searchResults.clear());
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 600), () async {
      try {
        List<Location> locations = await locationFromAddress(query);
        if (mounted) {
          setState(() => _searchResults = locations);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _searchResults.clear());
        }
      }
    });
  }

  Future<void> _onSelectItem(Location location) async {
    final prefs = await SharedPreferences.getInstance();
    Placemark? placemark;

    try {
      final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
      if (placemarks.isNotEmpty) {
        placemark = placemarks.first;
      }
    } catch (e) {
      // Placemark alınamazsa sorun değil, sadece koordinatları kaydederiz.
    }

    final name = placemark?.name ?? 'Seçilen Konum';
    final addressData = {
      'name': name,
      'latitude': location.latitude,
      'longitude': location.longitude,
    };

    // İlgili adres tipine göre verileri SharedPreferences'e kaydet
    await prefs.setString('${widget.addressType}_address_name', name);
    await prefs.setDouble('${widget.addressType}_address_lat', location.latitude);
    await prefs.setDouble('${widget.addressType}_address_lon', location.longitude);

    // Ayarlar ekranına başarılı sonucunu döndürerek geri dön
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String title = widget.addressType == 'home' ? 'Ev Adresini Ayarla' : 'İş Adresini Ayarla';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Adres arayın...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: _onSearch,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final location = _searchResults[index];
                return FutureBuilder<Placemark>(
                  future: _getPlacemark(location),
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final placemark = snapshot.data!;
                      final name = placemark.name ?? '';
                      final street = placemark.street ?? '';
                      final titleText = name.isNotEmpty && name != street ? name : street;
                      final subtitleText = [placemark.subLocality, placemark.locality, placemark.administrativeArea]
                          .where((s) => s != null && s.isNotEmpty && s != titleText)
                          .toSet()
                          .join(', ');

                      return ListTile(
                        title: Text(titleText.isNotEmpty ? titleText : 'Bilinmeyen Konum'),
                        subtitle: Text(subtitleText),
                        onTap: () => _onSelectItem(location),
                      );
                    } else {
                      // Yüklenirken boş bir tile gösterilebilir
                      return const ListTile(title: Text('Konum bilgisi alınıyor...'));
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Tekrar tekrar çağrılmasını önlemek için yardımcı bir fonksiyon
  Future<Placemark> _getPlacemark(Location location) async {
    final placemarks = await placemarkFromCoordinates(location.latitude, location.longitude);
    return placemarks.first;
  }
}


import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// Arama sonucu verilerini tutmak için özel veri sınıfı
class SearchResultItem {
  final Location location;
  final Placemark placemark;

  SearchResultItem({required this.location, required this.placemark});
}

// Navigasyon talimatlarını tutmak için özel veri sınıfı
class NavigationInstruction {
  final String instruction;
  final LatLng location;
  final String maneuver;

  NavigationInstruction({
    required this.instruction,
    required this.location,
    required this.maneuver,
  });
}

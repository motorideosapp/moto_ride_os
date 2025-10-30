import 'dart:convert';
import 'package:http/http.dart' as http;

class RoadsService {
  final String _apiKey;

  RoadsService(this._apiKey);

  Future<int?> getSpeedLimit(double lat, double lng) async {
    final url = Uri.parse(
        'https://roads.googleapis.com/v1/speedLimits?path=$lat,$lng&key=$_apiKey');

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['speedLimits'] != null && data['speedLimits'].isNotEmpty) {
          // The API returns speed limits in kph
          return data['speedLimits'][0]['speedLimit'] as int?;
        }
      }
    } catch (e) {
      print("Error getting speed limit: $e");
    }
    return null;
  }
}

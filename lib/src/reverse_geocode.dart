import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

class ReverseGeocoder {
  final Dio _dio = Dio();
  static const String _base = 'https://photon.komoot.io/reverse';

  Future<String?> describe(LatLng point) async {
    try {
      final res = await _dio.get(
        _base,
        queryParameters: {'lat': point.latitude, 'lon': point.longitude},
        options: Options(
          sendTimeout: const Duration(seconds: 8),
          receiveTimeout: const Duration(seconds: 8),
        ),
      );
      final features = res.data['features'] as List?;
      if (features == null || features.isEmpty) return null;
      final props = features.first['properties'] as Map<String, dynamic>;
      return _format(props);
    } catch (_) {
      return null;
    }
  }

  String? _format(Map<String, dynamic> p) {
    final parts = <String>[];
    void add(String? v) {
      if (v != null && v.isNotEmpty && !parts.contains(v)) parts.add(v);
    }

    add(p['name'] as String?);
    final street = p['street'] as String?;
    if (street != null) {
      final hn = p['housenumber'] as String?;
      add(hn != null ? '$street $hn' : street);
    }
    add(p['district'] as String?);
    add(p['city'] as String?);
    add(p['state'] as String?);
    add(p['country'] as String?);

    if (parts.isEmpty) return null;
    return parts.take(4).join(', ');
  }
}

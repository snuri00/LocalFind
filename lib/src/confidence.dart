import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

enum ConfidenceLevel { veryHigh, high, medium, low }

class GeoEstimate {
  final LatLng primary;
  final List<LatLng> candidates;
  final List<double> probs;
  final ConfidenceLevel level;
  final double radiusKm;

  const GeoEstimate({
    required this.primary,
    required this.candidates,
    required this.probs,
    required this.level,
    required this.radiusKm,
  });

  String get levelLabel {
    switch (level) {
      case ConfidenceLevel.veryHigh:
        return 'Very high (pinpoint)';
      case ConfidenceLevel.high:
        return 'High';
      case ConfidenceLevel.medium:
        return 'Medium';
      case ConfidenceLevel.low:
        return 'Low';
    }
  }
}

double haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _rad(b.latitude - a.latitude);
  final dLon = _rad(b.longitude - a.longitude);
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return 2 * r * math.asin(math.min(1.0, math.sqrt(h)));
}

double _rad(double deg) => deg * math.pi / 180.0;

GeoEstimate buildEstimate(List<LatLng> coords, List<double> probs) {
  final primary = coords.first;
  var massWeight = 0.0;
  var massDist = 0.0;
  for (var i = 0; i < coords.length; i++) {
    final d = haversineKm(coords[i], primary);
    massWeight += probs[i];
    massDist += probs[i] * d;
  }
  final spreadKm = massWeight > 0 ? massDist / massWeight : 0.0;

  ConfidenceLevel level;
  if (spreadKm < 1.0) {
    level = ConfidenceLevel.veryHigh;
  } else if (spreadKm < 25.0) {
    level = ConfidenceLevel.high;
  } else if (spreadKm < 200.0) {
    level = ConfidenceLevel.medium;
  } else {
    level = ConfidenceLevel.low;
  }

  return GeoEstimate(
    primary: primary,
    candidates: coords,
    probs: probs,
    level: level,
    radiusKm: math.max(spreadKm, 0.05),
  );
}

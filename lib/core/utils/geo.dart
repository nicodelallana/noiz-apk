import 'dart:math' as math;

/// Great-circle distance in kilometres between two coordinates (Haversine).
double haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const p = math.pi / 180;
  final a = 0.5 -
      math.cos((lat2 - lat1) * p) / 2 +
      math.cos(lat1 * p) *
          math.cos(lat2 * p) *
          (1 - math.cos((lon2 - lon1) * p)) /
          2;
  return 12742 * math.asin(math.sqrt(a));
}

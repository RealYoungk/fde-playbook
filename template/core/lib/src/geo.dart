import 'dart:math' as math;

class LatLng {
  const LatLng(this.lat, this.lng);
  final double lat;
  final double lng;

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};
  @override
  String toString() => '(${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)})';
}

/// 두 좌표 사이 직선거리(km).
double haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = _rad(b.lat - a.lat);
  final dLng = _rad(b.lng - a.lng);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_rad(a.lat)) *
          math.cos(_rad(b.lat)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * r * math.asin(math.sqrt(h));
}

/// 직선거리를 도보 시간(분)으로 환산.
/// [detourFactor]: 직선 대비 실제 도로 우회 계수. 도심 1.2~1.4가 흔한 가정.
/// 이 값은 가정이므로 DECISIONS.md에 근거와 함께 기록할 것.
double walkMinutes(
  double km, {
  double speedKmh = 4.5,
  double detourFactor = 1.3,
}) => km * detourFactor / speedKmh * 60;

/// 차량 이동 시간(분) 근사. 도로 데이터가 없을 때의 대체 가정.
double driveMinutes(
  double km, {
  double speedKmh = 30,
  double detourFactor = 1.4,
}) => km * detourFactor / speedKmh * 60;

LatLng centroid(Iterable<LatLng> points) {
  var lat = 0.0, lng = 0.0, n = 0;
  for (final p in points) {
    lat += p.lat;
    lng += p.lng;
    n++;
  }
  return n == 0 ? const LatLng(0, 0) : LatLng(lat / n, lng / n);
}

double _rad(double d) => d * math.pi / 180;

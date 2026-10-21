/// Seguimiento GPS de carrera, caminata o bicicleta al aire libre: suma la
/// distancia entre puntos, descarta lecturas imprecisas o saltos imposibles
/// y estima el MET según la velocidad (Compendio de Actividades Físicas).
library;

import 'dart:math';

/// Actividad al aire libre con GPS.
enum OutdoorMode {
  run('gps_correr', 'Carrera al aire libre', 'Correr', 7.5),
  walk('gps_caminar', 'Caminata al aire libre', 'Caminar', 3.5),
  bike('gps_bici', 'Bicicleta al aire libre', 'Bicicleta', 16);

  const OutdoorMode(this.id, this.label, this.short, this.maxSpeedMs);

  final String id;
  final String label;
  final String short;

  /// Más rápido que esto (m/s) entre dos puntos es un salto del GPS.
  final double maxSpeedMs;
}

/// Una lectura de ubicación.
class GeoPoint {
  const GeoPoint(this.lat, this.lon, {this.accuracy = 5, required this.time});

  final double lat;
  final double lon;

  /// Radio de error en metros.
  final double accuracy;
  final DateTime time;
}

/// Distancia en metros entre dos puntos (fórmula del semiverseno).
double metersBetween(GeoPoint a, GeoPoint b) {
  const r = 6371000.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(b.lat - a.lat), dLon = rad(b.lon - a.lon);
  final h = pow(sin(dLat / 2), 2) + cos(rad(a.lat)) * cos(rad(b.lat)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(min(1.0, sqrt(h)));
}

/// El recorrido: puntos aceptados (por tramos, cortados en cada pausa) y la
/// distancia total.
class GpsTrack {
  GpsTrack(this.mode);

  final OutdoorMode mode;
  final List<List<GeoPoint>> segments = [[]];
  double meters = 0;

  /// Precisión (m) de la última lectura recibida, se use o no.
  double? lastAccuracy;

  /// Lecturas con un error mayor a esto no se usan.
  static const maxAccuracy = 35.0;

  GeoPoint? get _last => segments.last.isEmpty ? null : segments.last.last;

  /// Suma la lectura si es confiable. Devuelve si se usó.
  bool add(GeoPoint p) {
    lastAccuracy = p.accuracy;
    if (p.accuracy > maxAccuracy) return false;
    final last = _last;
    if (last == null) {
      segments.last.add(p);
      return true;
    }
    final d = metersBetween(last, p);
    final dt = p.time.difference(last.time).inMilliseconds / 1000;
    if (dt <= 0) return false;
    if (d / dt > mode.maxSpeedMs) return false;
    // Quieto o temblor del GPS: no suma hasta moverse más que el error.
    if (d < max(3.0, (p.accuracy + last.accuracy) / 4)) return false;
    meters += d;
    segments.last.add(p);
    return true;
  }

  /// Pausa: el próximo punto empieza un tramo nuevo (no suma el trayecto
  /// hecho en pausa).
  void breakSegment() {
    if (segments.last.isNotEmpty) segments.add([]);
  }

  Iterable<GeoPoint> get points => segments.expand((s) => s);
}

/// MET según la velocidad promedio (km/h).
double metFor(OutdoorMode mode, double kmh) {
  const run = [(6.4, 6.0), (8.0, 8.3), (9.7, 9.8), (11.3, 11.0), (12.9, 11.8), (14.5, 12.8), (16.1, 14.5)];
  const walk = [(3.2, 2.8), (4.0, 3.0), (4.8, 3.5), (5.6, 4.3), (6.4, 5.0), (7.2, 7.0)];
  const bike = [(10.0, 4.0), (16.0, 6.8), (19.0, 8.0), (22.5, 10.0), (25.5, 12.0)];
  final table = switch (mode) {
    OutdoorMode.run => run,
    OutdoorMode.walk => walk,
    OutdoorMode.bike => bike,
  };
  if (kmh <= table.first.$1) return table.first.$2;
  if (kmh >= table.last.$1) return table.last.$2;
  for (var i = 0; i + 1 < table.length; i++) {
    final (x0, y0) = table[i];
    final (x1, y1) = table[i + 1];
    if (kmh <= x1) return y0 + (y1 - y0) * (kmh - x0) / (x1 - x0);
  }
  return table.last.$2;
}

/// Ritmo "m:ss min/km" (o '–' si aún no hay distancia).
String paceLabel(double meters, Duration moving) {
  if (meters < 50 || moving.inSeconds == 0) return '–';
  final secPerKm = moving.inSeconds / (meters / 1000);
  final m = secPerKm ~/ 60, s = (secPerKm % 60).round();
  return s == 60 ? '${m + 1}:00' : '$m:${s.toString().padLeft(2, '0')}';
}

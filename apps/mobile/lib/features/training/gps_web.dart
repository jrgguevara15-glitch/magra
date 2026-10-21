import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'gps_location.dart';
import 'gps_track.dart';

/// GPS del navegador con la API de geolocalización directamente: el permiso
/// lo pide el propio navegador al empezar, y una falta de señal pasajera no
/// corta el seguimiento.
Stream<GeoPoint> webLocations() {
  int? watchId;
  late final StreamController<GeoPoint> out;
  out = StreamController<GeoPoint>(
    onListen: () {
      try {
        watchId = web.window.navigator.geolocation.watchPosition(
          ((web.GeolocationPosition p) {
            final c = p.coords;
            out.add(GeoPoint(c.latitude, c.longitude, accuracy: c.accuracy, time: DateTime.now()));
          }).toJS,
          ((web.GeolocationPositionError e) {
            out.addError(e.code == 1
                ? const GpsException(gpsDeniedMessage, fatal: true)
                : const GpsException(gpsNoSignalMessage));
          }).toJS,
          web.PositionOptions(enableHighAccuracy: true, maximumAge: 0, timeout: 20000),
        );
      } catch (_) {
        out.addError(const GpsException('Este navegador no permite usar la ubicación.', fatal: true));
      }
    },
    onCancel: () {
      final id = watchId;
      if (id != null) web.window.navigator.geolocation.clearWatch(id);
    },
  );
  return out.stream;
}

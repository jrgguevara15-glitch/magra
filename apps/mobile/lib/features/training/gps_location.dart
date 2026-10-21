import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_track.dart';
import 'gps_web_stub.dart' if (dart.library.js_interop) 'gps_web.dart';

/// Un problema con el GPS. Si [fatal], no llegarán más lecturas (sin permiso
/// o sin GPS); si no, es pasajero (sin señal por un momento) y se sigue
/// escuchando.
class GpsException implements Exception {
  const GpsException(this.message, {this.fatal = false});

  final String message;
  final bool fatal;

  @override
  String toString() => message;
}

const gpsDeniedMessage = 'MAGRA no tiene permiso de ubicación. En iPhone: Ajustes → '
    'Privacidad y seguridad → Localización → activa «Localización» y en «Sitios web '
    'de Safari» (o Chrome) elige «Al usar la app». Luego recarga la página y vuelve a '
    'tocar Empezar. En el navegador, permite la ubicación con el candado junto a la '
    'dirección.';

const gpsNoSignalMessage = 'Sin señal GPS por ahora. Sal a un lugar abierto; seguimos buscando.';

/// Abre el flujo de ubicaciones (pide permiso si hace falta).
typedef LocationStream = Stream<GeoPoint> Function();

final locationStreamProvider = Provider<LocationStream>((ref) => kIsWeb ? webLocations : deviceLocations);

/// GPS de la app instalada (iOS/Android).
Stream<GeoPoint> deviceLocations() async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const GpsException('Activa la ubicación (GPS) del teléfono.', fatal: true);
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw const GpsException(gpsDeniedMessage, fatal: true);
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
  ).map((p) => GeoPoint(p.latitude, p.longitude, accuracy: p.accuracy, time: DateTime.now())).handleError(
        (Object e) => throw e is PermissionDeniedException
            ? const GpsException(gpsDeniedMessage, fatal: true)
            : const GpsException(gpsNoSignalMessage),
      );
}

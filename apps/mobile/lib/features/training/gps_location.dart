import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_track.dart';

/// El GPS no está disponible o el usuario no dio permiso.
class GpsException implements Exception {
  const GpsException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Abre el flujo de ubicaciones (pide permiso si hace falta).
typedef LocationStream = Stream<GeoPoint> Function();

final locationStreamProvider = Provider<LocationStream>((ref) => deviceLocations);

Stream<GeoPoint> deviceLocations() async* {
  if (!await Geolocator.isLocationServiceEnabled()) {
    throw const GpsException('Activa la ubicación (GPS) del teléfono.');
  }
  var permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    throw const GpsException(
        'MAGRA necesita permiso de ubicación para medir la distancia. Actívalo en '
        'los ajustes del navegador o del teléfono.');
  }
  yield* Geolocator.getPositionStream(
    locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 3),
  ).map((p) => GeoPoint(p.latitude, p.longitude, accuracy: p.accuracy, time: p.timestamp));
}

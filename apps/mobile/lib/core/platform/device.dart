import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'device_stub.dart' if (dart.library.js_interop) 'device_web.dart' as impl;

/// Preferencias guardadas en este dispositivo (avisos activados, avisos ya
/// descartados). En el navegador viven en localStorage.
abstract interface class LocalPrefs {
  String? read(String key);
  void write(String key, String value);
}

class MemoryPrefs implements LocalPrefs {
  final Map<String, String> values = {};

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) => values[key] = value;
}

/// Notificaciones del sistema. En el navegador solo funcionan con MAGRA
/// abierta; con la app instalada llegarán aunque esté cerrada (M14).
abstract interface class SystemAlerts {
  /// 'granted', 'denied', 'default' o 'unsupported'.
  String get permission;
  Future<String> request();
  void show(String title, String body);
}

class NoSystemAlerts implements SystemAlerts {
  @override
  String get permission => 'unsupported';

  @override
  Future<String> request() async => 'unsupported';

  @override
  void show(String title, String body) {}
}

final localPrefsProvider = Provider<LocalPrefs>((ref) => impl.devicePrefs());
final systemAlertsProvider = Provider<SystemAlerts>((ref) => impl.deviceAlerts());

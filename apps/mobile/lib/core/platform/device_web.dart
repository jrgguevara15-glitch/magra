import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'device.dart';

LocalPrefs devicePrefs() => _WebPrefs();
SystemAlerts deviceAlerts() => _WebAlerts();

class _WebPrefs implements LocalPrefs {
  final _fallback = MemoryPrefs();

  @override
  String? read(String key) {
    try {
      return web.window.localStorage.getItem(key);
    } catch (_) {
      return _fallback.read(key);
    }
  }

  @override
  void write(String key, String value) {
    try {
      web.window.localStorage.setItem(key, value);
    } catch (_) {
      _fallback.write(key, value);
    }
  }
}

class _WebAlerts implements SystemAlerts {
  bool get _supported {
    try {
      return (web.window as JSObject).has('Notification');
    } catch (_) {
      return false;
    }
  }

  @override
  String get permission => _supported ? web.Notification.permission : 'unsupported';

  @override
  Future<String> request() async {
    if (!_supported) return 'unsupported';
    try {
      final r = await web.Notification.requestPermission().toDart;
      return r.toDart;
    } catch (_) {
      return permission;
    }
  }

  @override
  void show(String title, String body) {
    if (permission != 'granted') return;
    try {
      web.Notification(title, web.NotificationOptions(body: body, icon: 'icons/Icon-192.png', tag: title));
    } catch (_) {}
  }
}

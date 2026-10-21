import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/data/db_errors.dart';
import '../../core/data/providers.dart';
import '../../core/format.dart';
import '../../core/formulas/formulas.dart';
import '../../core/theme.dart';
import '../today/activity_log.dart';
import 'gps_location.dart';
import 'gps_track.dart';

Future<void> openOutdoor(BuildContext context, {required DateTime day, required double weightKg}) =>
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => OutdoorPage(day: day, weightKg: weightKg),
    ));

enum _Status { idle, running, paused }

/// Carrera, caminata o bicicleta al aire libre con GPS: distancia, tiempo,
/// ritmo y recorrido; al terminar se guarda como ejercicio del día.
class OutdoorPage extends ConsumerStatefulWidget {
  const OutdoorPage({super.key, required this.day, required this.weightKg});

  final DateTime day;
  final double weightKg;

  @override
  ConsumerState<OutdoorPage> createState() => _OutdoorPageState();
}

class _OutdoorPageState extends ConsumerState<OutdoorPage> {
  OutdoorMode _mode = OutdoorMode.run;
  _Status _status = _Status.idle;
  GpsTrack _track = GpsTrack(OutdoorMode.run);
  final _clock = Stopwatch();
  StreamSubscription<GeoPoint>? _sub;
  Timer? _tick;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _track = GpsTrack(_mode);
      _status = _Status.running;
      _error = null;
    });
    _clock
      ..reset()
      ..start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    _sub = ref.read(locationStreamProvider)().listen(
      (p) {
        if (!mounted) return;
        setState(() {
          _error = null;
          if (_status == _Status.running) {
            _track.add(p);
          } else {
            _track.lastAccuracy = p.accuracy;
          }
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        final gps = e is GpsException ? e : const GpsException(gpsNoSignalMessage);
        setState(() => _error = gps.message);
        if (gps.fatal) {
          _sub?.cancel();
          _clock.stop();
        }
      },
    );
  }

  void _pause() {
    _clock.stop();
    _track.breakSegment();
    setState(() => _status = _Status.paused);
  }

  void _resume() {
    _clock.start();
    setState(() => _status = _Status.running);
  }

  double get _km => _track.meters / 1000;
  double get _kmh => _clock.elapsed.inSeconds == 0 ? 0 : _km / (_clock.elapsed.inSeconds / 3600);

  ExerciseEntry _entry() {
    final minutes = max(1, (_clock.elapsed.inSeconds / 60).round());
    final met = metFor(_mode, _kmh);
    final activity = Activity(_mode.id, '${_mode.label} · ${fmt(_km, 2)} km', met);
    return ExerciseEntry(
      date: widget.day,
      activityId: activity.id,
      name: activity.name,
      met: met,
      minutes: minutes,
      kcalNet: netBurnKcal(activity, minutes.toDouble(), widget.weightKg),
      distanceKm: _km,
    );
  }

  Future<void> _finish() async {
    _clock.stop();
    _sub?.cancel();
    _tick?.cancel();
    if (_track.meters < 50 && _clock.elapsed.inSeconds < 60) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(exerciseLogRepositoryProvider).add(_entry());
      ref.invalidate(exerciseLogProvider(widget.day));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Guardaste ${_mode.label.toLowerCase()}: ${fmt(_km, 2)} km.')));
      Navigator.of(context).pop();
    } catch (err) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = saveErrorMessage(err, migration: '0014_gps_steps.sql');
        });
      }
    }
  }

  Future<void> _confirmFinish() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('¿Terminar?'),
        content: Text('${fmt(_km, 2)} km en ${_time(_clock.elapsed)}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Seguir')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Terminar y guardar')),
        ],
      ),
    );
    if (ok == true) await _finish();
  }

  String _signalText() {
    final acc = _track.lastAccuracy;
    if (acc == null) return 'Buscando señal GPS…';
    if (acc > GpsTrack.maxAccuracy) {
      return 'Señal débil (±${acc.round()} m). Los km empiezan a contar cuando la '
          'precisión baje de ${GpsTrack.maxAccuracy.round()} m: sal a un lugar abierto. '
          'En un computador no hay GPS, úsalo en el teléfono.';
    }
    return 'Señal GPS lista (±${acc.round()} m). Empieza a moverte.';
  }

  static String _time(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final idle = _status == _Status.idle;
    final kcal = idle ? 0.0 : _entry().kcalNet * min(1.0, _clock.elapsed.inSeconds / 60);
    return Scaffold(
      appBar: AppBar(title: const Text('Al aire libre con GPS')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SegmentedButton<OutdoorMode>(
                  showSelectedIcon: false,
                  segments: [
                    for (final m in OutdoorMode.values) ButtonSegment(value: m, label: Text(m.short)),
                  ],
                  selected: {_mode},
                  onSelectionChanged: idle ? (s) => setState(() => _mode = s.first) : null,
                ),
                const SizedBox(height: 16),
                Text(fmt(_km, 2), textAlign: TextAlign.center,
                    style: theme.textTheme.displayMedium?.copyWith(color: MagraColors.lime, fontWeight: FontWeight.w800)),
                Text('kilómetros', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Stat(_time(_clock.elapsed), 'tiempo'),
                    _mode == OutdoorMode.bike
                        ? _Stat(fmt(_kmh, 1), 'km/h')
                        : _Stat(paceLabel(_track.meters, _clock.elapsed), 'min/km'),
                    _Stat(fmt(kcal), 'kcal'),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    color: MagraColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: MagraColors.outlineSoft),
                  ),
                  child: _track.points.length < 2
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              idle ? 'Tu recorrido aparecerá aquí.' : _signalText(),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        )
                      : CustomPaint(painter: _RoutePainter(_track), size: Size.infinite),
                ),
                if (_status == _Status.paused) ...[
                  const SizedBox(height: 8),
                  Text('En pausa: el tiempo y la distancia no corren.',
                      textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 16),
                if (idle)
                  FilledButton.icon(
                    onPressed: _start,
                    icon: const Icon(Icons.play_arrow),
                    label: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Empezar ${_mode.short.toLowerCase()}'),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : (_status == _Status.running ? _pause : _resume),
                          icon: Icon(_status == _Status.running ? Icons.pause : Icons.play_arrow),
                          label: Text(_status == _Status.running ? 'Pausar' : 'Reanudar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _confirmFinish,
                          icon: const Icon(Icons.flag_outlined),
                          label: const Text('Terminar'),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Text(
                  kIsWeb
                      ? 'Mantén la pantalla encendida y MAGRA abierta mientras corres: '
                          'el navegador no lee el GPS con la pantalla bloqueada (la app '
                          'instalada sí podrá). Tu ubicación no se guarda, solo los km.'
                      : 'Tu ubicación solo se usa para medir la distancia; no se guarda.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'Calorías con MET según tu velocidad promedio (Compendio de '
                  'Actividad Física) y tu peso de ${fmt(widget.weightKg, 1)} kg.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(value, style: theme.textTheme.headlineSmall),
          Text(label, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Dibuja el recorrido (sin mapa de fondo) ajustado al recuadro.
class _RoutePainter extends CustomPainter {
  _RoutePainter(this.track);

  final GpsTrack track;

  @override
  void paint(Canvas canvas, Size size) {
    final pts = track.points.toList();
    final lat0 = pts.first.lat * pi / 180;
    Offset xy(GeoPoint p) => Offset(p.lon * cos(lat0), -p.lat);
    final all = [for (final p in pts) xy(p)];
    var minX = all.first.dx, maxX = minX, minY = all.first.dy, maxY = minY;
    for (final o in all) {
      minX = min(minX, o.dx);
      maxX = max(maxX, o.dx);
      minY = min(minY, o.dy);
      maxY = max(maxY, o.dy);
    }
    final w = max(maxX - minX, 1e-9), h = max(maxY - minY, 1e-9);
    final scale = min((size.width - 32) / w, (size.height - 32) / h);
    final ox = (size.width - w * scale) / 2, oy = (size.height - h * scale) / 2;
    Offset map(GeoPoint p) {
      final o = xy(p);
      return Offset(ox + (o.dx - minX) * scale, oy + (o.dy - minY) * scale);
    }

    final paint = Paint()
      ..color = MagraColors.lime
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    for (final seg in track.segments) {
      if (seg.length < 2) continue;
      final path = Path()..moveTo(map(seg.first).dx, map(seg.first).dy);
      for (final p in seg.skip(1)) {
        path.lineTo(map(p).dx, map(p).dy);
      }
      canvas.drawPath(path, paint);
    }
    canvas.drawCircle(map(pts.first), 6, Paint()..color = MagraColors.cyan);
    canvas.drawCircle(map(pts.last), 7, Paint()..color = MagraColors.lime);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => true;
}
